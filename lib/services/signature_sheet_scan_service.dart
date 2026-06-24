// OCR service for sign-in sheets and other photographed name lists.
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';

import '../models/person_import_draft.dart';

abstract class SignatureSheetScanService {
  Future<SignatureSheetScanResult?> scanFromCamera();
}

class SignatureSheetScanResult {
  const SignatureSheetScanResult({
    required this.rawText,
    required this.candidates,
  });

  final String rawText;
  final List<PersonImportDraft> candidates;
}

class SignatureSheetScanException implements Exception {
  const SignatureSheetScanException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class MlKitSignatureSheetScanService implements SignatureSheetScanService {
  MlKitSignatureSheetScanService({
    ImagePicker? imagePicker,
    MethodChannel? ocrChannel,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _ocrChannel =
           ocrChannel ?? const MethodChannel('com.qkrqu.inyeon_jangbu/ocr');

  final ImagePicker _imagePicker;
  final MethodChannel _ocrChannel;

  @override
  Future<SignatureSheetScanResult?> scanFromCamera() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2400,
      maxHeight: 2400,
    );
    if (file == null) {
      return null;
    }

    final normalizedImage = await _normalizePickedImage(file);
    final recognizedText = await _recognizeText(normalizedImage);
    return SignatureSheetScanResult(
      rawText: recognizedText,
      candidates: extractPersonImportDrafts(recognizedText),
    );
  }

  Future<String> _recognizeText(NormalizedOcrImage image) async {
    try {
      final recognizedText = await _ocrChannel.invokeMethod<String>(
        'recognizeText',
        <String, Object>{'bytes': image.jpegBytes},
      );
      return recognizedText?.trim() ?? '';
    } on PlatformException catch (error) {
      throw SignatureSheetScanException(
        '사진의 글자를 읽지 못했어요. 잠시 후 다시 시도해 주세요.',
        error,
      );
    }
  }

  Future<NormalizedOcrImage> _normalizePickedImage(XFile file) async {
    try {
      return normalizeOcrImageBytes(await file.readAsBytes());
    } catch (error) {
      throw SignatureSheetScanException(
        '촬영한 사진을 읽지 못했어요. 카메라를 다시 열어 촬영해 주세요.',
        error,
      );
    }
  }
}

class NormalizedOcrImage {
  const NormalizedOcrImage({
    required this.jpegBytes,
    required this.width,
    required this.height,
  });

  final Uint8List jpegBytes;
  final int width;
  final int height;
}

NormalizedOcrImage normalizeOcrImageBytes(
  Uint8List bytes, {
  int maxDimension = 1600,
}) {
  image.Image? decoded;
  try {
    decoded = image.decodeImage(bytes);
  } catch (error) {
    throw FormatException('Unsupported image data', error);
  }
  if (decoded == null) {
    throw const FormatException('Unsupported image data');
  }

  var normalized = image.bakeOrientation(decoded);
  final longestSide = normalized.width > normalized.height
      ? normalized.width
      : normalized.height;
  if (longestSide > maxDimension) {
    if (normalized.width >= normalized.height) {
      normalized = image.copyResize(normalized, width: maxDimension);
    } else {
      normalized = image.copyResize(normalized, height: maxDimension);
    }
  }

  // Re-encoding applies EXIF orientation and strips camera-specific metadata.
  // Native code returns only the recognized text, avoiding fragile block data.
  return NormalizedOcrImage(
    jpegBytes: Uint8List.fromList(image.encodeJpg(normalized, quality: 90)),
    width: normalized.width,
    height: normalized.height,
  );
}

final signatureSheetScanServiceProvider = Provider<SignatureSheetScanService>((
  ref,
) {
  return MlKitSignatureSheetScanService();
});

List<PersonImportDraft> extractPersonImportDrafts(String rawText) {
  final lines = rawText
      .split(RegExp(r'[\r\n]+'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  final candidates = <PersonImportDraft>[];
  final seen = <String>{};

  for (final line in lines) {
    final phone = _extractPhoneNumber(line);
    for (final name in _extractNamesFromLine(line, phone)) {
      final key = '${name.name}|${name.phoneNumber ?? ''}';
      if (seen.add(key)) {
        candidates.add(name);
      }
    }
  }

  return candidates;
}

final _phonePattern = RegExp(r'(01[016789][-\s]?\d{3,4}[-\s]?\d{4})');

final _stopWords = <String>{
  '서명',
  '성명',
  '이름',
  '명단',
  '축의',
  '축하',
  '조의',
  '관계',
  '메모',
  '비고',
  '직책',
  '회사',
  '가족',
  '친척',
  '친구',
  '지인',
  '기타',
  '신랑',
  '신부',
  '총무',
  '참석',
  '감사',
  '환영',
  '일시',
  '장소',
  '연락',
  '전화',
};

String? _extractPhoneNumber(String line) {
  final match = _phonePattern.firstMatch(line);
  if (match == null) {
    return null;
  }
  return match.group(1)?.replaceAll(RegExp(r'[\s-]'), '');
}

List<PersonImportDraft> _extractNamesFromLine(String line, String? phone) {
  final normalized = line.replaceAll(_phonePattern, ' ');
  final tokens = normalized.split(RegExp(r'[\s,·•/|]+'));
  final koreanTokens = tokens
      .map((token) => token.replaceAll(RegExp(r'[^가-힣]'), ''))
      .where((token) => token.isNotEmpty)
      .toList();
  final hasListContext =
      phone != null ||
      koreanTokens.length == 1 ||
      koreanTokens.any(_stopWords.contains);
  if (!hasListContext) {
    return const [];
  }

  final candidates = <PersonImportDraft>[];

  void addCandidate(String value) {
    final name = value.trim();
    if (name.isEmpty) {
      return;
    }
    if (!_looksLikeKoreanName(name)) {
      return;
    }
    if (_stopWords.contains(name)) {
      return;
    }
    candidates.add(
      PersonImportDraft(name: name, phoneNumber: phone, sourceLine: line),
    );
  }

  for (final token in tokens) {
    final compact = token.replaceAll(RegExp(r'[^가-힣]'), '');
    if (compact.length >= 2 && compact.length <= 4) {
      addCandidate(compact);
    }
  }

  final compactLine = normalized.replaceAll(RegExp(r'[^가-힣]'), '');
  if (compactLine.length >= 2 && compactLine.length <= 4) {
    addCandidate(compactLine);
  }

  return candidates;
}

bool _looksLikeKoreanName(String value) {
  final text = value.replaceAll(' ', '');
  if (!RegExp(r'^[가-힣]{2,4}$').hasMatch(text)) {
    return false;
  }

  return _koreanSurnames.any(text.startsWith);
}

const _koreanSurnames = <String>{
  '김',
  '이',
  '박',
  '최',
  '정',
  '강',
  '조',
  '윤',
  '장',
  '임',
  '한',
  '오',
  '서',
  '신',
  '권',
  '황',
  '안',
  '송',
  '전',
  '홍',
  '유',
  '고',
  '문',
  '양',
  '손',
  '배',
  '백',
  '허',
  '남',
  '심',
  '노',
  '하',
  '곽',
  '성',
  '차',
  '주',
  '우',
  '구',
  '민',
  '진',
  '지',
  '엄',
  '채',
  '원',
  '천',
  '방',
  '공',
  '현',
  '함',
  '변',
  '염',
  '여',
  '추',
  '도',
  '소',
  '석',
  '선',
  '설',
  '마',
  '길',
  '연',
  '위',
  '표',
  '명',
  '기',
  '반',
  '왕',
  '금',
  '옥',
  '육',
  '인',
  '맹',
  '제',
  '모',
  '탁',
  '국',
  '어',
  '은',
  '편',
  '용',
  '예',
  '경',
  '봉',
  '사',
  '부',
  '가',
  '복',
  '태',
  '목',
  '형',
  '두',
  '감',
  '음',
  '빈',
  '동',
  '온',
  '호',
  '남궁',
  '황보',
  '제갈',
  '사공',
  '선우',
  '서문',
  '독고',
  '동방',
};
