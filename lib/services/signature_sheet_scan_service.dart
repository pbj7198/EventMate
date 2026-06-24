// OCR service for photographed sheets, posters, and other text-heavy images.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../models/person_import_draft.dart';

enum SignatureSheetScanStatus { success, noText }

abstract class SignatureSheetScanService {
  Future<SignatureSheetScanResult?> scanFromCamera();
}

class SignatureSheetScanResult {
  const SignatureSheetScanResult({
    required this.status,
    required this.rawText,
    required this.candidates,
    this.message,
  });

  final SignatureSheetScanStatus status;
  final String rawText;
  final List<PersonImportDraft> candidates;
  final String? message;

  bool get hasRecognizedText => rawText.trim().isNotEmpty;
}

class SignatureSheetScanException implements Exception {
  const SignatureSheetScanException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

typedef TextRecognizerFactory =
    TextRecognizer Function(TextRecognitionScript script);

class MlKitSignatureSheetScanService implements SignatureSheetScanService {
  MlKitSignatureSheetScanService({
    ImagePicker? imagePicker,
    TextRecognizerFactory? recognizerFactory,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _recognizerFactory =
           recognizerFactory ?? ((script) => TextRecognizer(script: script));

  final ImagePicker _imagePicker;
  final TextRecognizerFactory _recognizerFactory;

  @override
  Future<SignatureSheetScanResult?> scanFromCamera() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
    );
    if (file == null) {
      return null;
    }

    final rawText = await _recognizeText(file.path);
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) {
      return const SignatureSheetScanResult(
        status: SignatureSheetScanStatus.noText,
        rawText: '',
        candidates: [],
        message: '사진에서 읽을 수 있는 글자를 찾지 못했어요. 글자가 화면을 더 크게 채우도록 다시 촬영해 주세요.',
      );
    }

    return SignatureSheetScanResult(
      status: SignatureSheetScanStatus.success,
      rawText: trimmed,
      candidates: extractPersonImportDrafts(trimmed),
      message: '사진에서 글자를 읽었어요.',
    );
  }

  Future<String> _recognizeText(String imagePath) async {
    final koreanRecognizer = _recognizerFactory(TextRecognitionScript.korean);
    TextRecognizer? latinRecognizer;

    try {
      final image = InputImage.fromFilePath(imagePath);
      final koreanText = await koreanRecognizer.processImage(image);
      final text = koreanText.text.trim();
      if (text.isNotEmpty) {
        return text;
      }

      latinRecognizer = _recognizerFactory(TextRecognitionScript.latin);
      final latinText = await latinRecognizer.processImage(image);
      return latinText.text.trim();
    } catch (error) {
      throw SignatureSheetScanException(
        '사진의 글자를 읽지 못했어요. 잠시 후 다시 시도해 주세요.',
        error,
      );
    } finally {
      koreanRecognizer.close();
      latinRecognizer?.close();
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
final _delimiterPattern = RegExp(r'[\s,·•/:|]+');
final _hangulOnlyPattern = RegExp(r'[^가-힣]');

String? _extractPhoneNumber(String line) {
  final match = _phonePattern.firstMatch(line);
  if (match == null) {
    return null;
  }
  return match.group(1)?.replaceAll(RegExp(r'[\s-]'), '');
}

List<PersonImportDraft> _extractNamesFromLine(String line, String? phone) {
  final normalized = line.replaceAll(_phonePattern, ' ');
  final tokens = normalized.split(_delimiterPattern);

  final names = <String>{};
  for (final token in tokens) {
    final compact = token.replaceAll(_hangulOnlyPattern, '');
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
      normalized.contains(RegExp(r'[:/|]'));
  if (!hasListContext) {
    return const [];
  }

  return names
      .map(
        (name) =>
            PersonImportDraft(name: name, phoneNumber: phone, sourceLine: line),
      )
      .toList();
}

bool _looksLikeKoreanName(String value) {
  if (!RegExp(r'^[가-힣]{2,3}$').hasMatch(value)) {
    return false;
  }

  if (_noiseWords.contains(value)) {
    return false;
  }

  if (RegExp(r'^(.)\1+$').hasMatch(value)) {
    return false;
  }

  return _koreanSurnamePrefixes.any(value.startsWith);
}

const _noiseWords = <String>{
  '가족',
  '관계',
  '결혼',
  '그만',
  '기타',
  '돌잔치',
  '먹으라고',
  '명단',
  '방문',
  '생일',
  '서명',
  '선물',
  '신랑',
  '신부',
  '안내',
  '예약',
  '응모',
  '유튜브',
  '조회수',
  '축의금',
  '회사',
  '친구',
  '친척',
  '행사',
  '환영',
};

const _koreanSurnamePrefixes = <String>{
  '강',
  '고',
  '곽',
  '권',
  '김',
  '나',
  '남',
  '노',
  '문',
  '박',
  '배',
  '백',
  '변',
  '서',
  '석',
  '손',
  '송',
  '신',
  '심',
  '안',
  '양',
  '오',
  '우',
  '유',
  '윤',
  '이',
  '임',
  '장',
  '전',
  '정',
  '조',
  '주',
  '차',
  '최',
  '추',
  '하',
  '한',
  '허',
  '홍',
  '황',
};
