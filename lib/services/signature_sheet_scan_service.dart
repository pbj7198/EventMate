// OCR service for photographed sheets, posters, and other text-heavy images.
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  })  : _imagePicker = imagePicker ?? ImagePicker(),
        _ocrChannel =
            ocrChannel ?? const MethodChannel('com.qkrqu.inyeon_jangbu/ocr');

  final ImagePicker _imagePicker;
  final MethodChannel _ocrChannel;

  @override
  Future<SignatureSheetScanResult?> scanFromCamera() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
    );
    if (file == null) {
      return null;
    }

    final recognizedText = await _recognizeText(file.path);
    return SignatureSheetScanResult(
      rawText: recognizedText,
      candidates: extractPersonImportDrafts(recognizedText),
    );
  }

  Future<String> _recognizeText(String imagePath) async {
    try {
      final recognizedText = await _ocrChannel.invokeMethod<String>(
        'recognizeText',
        <String, Object>{
          'imagePath': imagePath,
        },
      );
      return recognizedText?.trim() ?? '';
    } on PlatformException catch (error) {
      throw SignatureSheetScanException(
        '사진의 글자를 읽지 못했어요. 잠시 후 다시 시도해 주세요.',
        error,
      );
    } catch (error) {
      throw SignatureSheetScanException(
        '사진의 글자를 읽지 못했어요. 잠시 후 다시 시도해 주세요.',
        error,
      );
    }
  }
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

String? _extractPhoneNumber(String line) {
  final match = _phonePattern.firstMatch(line);
  if (match == null) {
    return null;
  }
  return match.group(1)?.replaceAll(RegExp(r'[\s-]'), '');
}

List<PersonImportDraft> _extractNamesFromLine(String line, String? phone) {
  final normalized = line.replaceAll(_phonePattern, ' ');
  final tokens = normalized.split(RegExp(r'[\s,·•|/:]+'));

  final names = <String>{};
  for (final token in tokens) {
    final compact = token.replaceAll(RegExp(r'[^가-힣]'), '');
    if (_looksLikeKoreanName(compact)) {
      names.add(compact);
    }
  }

  if (names.isEmpty) {
    return const [];
  }

  final hasListContext =
      phone != null ||
      names.length == 1 ||
      normalized.contains(RegExp(r'[:·•|/]'));
  if (!hasListContext) {
    return const [];
  }

  return names
      .map(
        (name) => PersonImportDraft(
          name: name,
          phoneNumber: phone,
          sourceLine: line,
        ),
      )
      .toList();
}

bool _looksLikeKoreanName(String value) {
  if (!RegExp(r'^[가-힣]{2,4}$').hasMatch(value)) {
    return false;
  }

  if (_noiseWords.contains(value)) {
    return false;
  }

  return _koreanSurnamePrefixes.any(value.startsWith);
}

const _noiseWords = <String>{
  '이름',
  '성함',
  '명단',
  '전화',
  '연락처',
  '번호',
  '관계',
  '가족',
  '친구',
  '회사',
  '지인',
  '친척',
  '기타',
  '메모',
  '예식',
  '장례',
  '돌잔치',
  '생일',
  '개업',
  '감사',
  '참석',
  '대기',
  '초기화',
  '추출',
  '사진',
  '글자',
  '스캔',
  '현재',
  '상태',
  '조회수',
  '유튜브',
  '아직',
  '없어요',
};

const _koreanSurnamePrefixes = <String>{
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
  '유',
  '홍',
  '전',
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
  '염',
  '위',
  '표',
  '기',
  '길',
  '목',
  '형',
  '국',
  '맹',
  '예',
  '도',
  '연',
  '석',
  '변',
  '여',
  '추',
  '소',
  '설',
  '선',
  '별',
  '미',
  '마',
  '남궁',
  '선우',
  '제갈',
  '황보',
  '사공',
  '서문',
  '동방',
  '어금',
  '독고',
};
