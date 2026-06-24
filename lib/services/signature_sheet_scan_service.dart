// OCR service for photographed sheets, posters, and other text-heavy images.
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class OcrRecognitionResponse {
  const OcrRecognitionResponse({
    required this.status,
    required this.text,
    this.message,
    this.details,
  });

  final SignatureSheetScanStatus status;
  final String text;
  final String? message;
  final Object? details;

  factory OcrRecognitionResponse.fromMap(Map<Object?, Object?> response) {
    final statusValue = response['status']?.toString();
    final text = response['text']?.toString() ?? '';
    final message = response['message']?.toString();
    final details = response['details'];

    switch (statusValue) {
      case 'success':
        return OcrRecognitionResponse(
          status: SignatureSheetScanStatus.success,
          text: text,
          message: message,
          details: details,
        );
      case 'no_text':
        return OcrRecognitionResponse(
          status: SignatureSheetScanStatus.noText,
          text: '',
          message: message,
          details: details,
        );
      default:
        throw SignatureSheetScanException(
          message ?? 'OCR response was invalid.',
          details,
        );
    }
  }
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
      imageQuality: 100,
    );
    if (file == null) {
      return null;
    }

    final response = await _recognizeText(file.path);
    if (response.status == SignatureSheetScanStatus.noText) {
      return SignatureSheetScanResult(
        status: SignatureSheetScanStatus.noText,
        rawText: '',
        candidates: const [],
        message:
            response.message ??
            '사진에서 읽을 수 있는 글자를 찾지 못했어요. 글자가 화면을 더 크게 채우도록 다시 촬영해 주세요.',
      );
    }

    final rawText = response.text.trim();
    return SignatureSheetScanResult(
      status: SignatureSheetScanStatus.success,
      rawText: rawText,
      candidates: extractPersonImportDrafts(rawText),
    );
  }

  Future<OcrRecognitionResponse> _recognizeText(String imagePath) async {
    try {
      final response = await _ocrChannel.invokeMapMethod<Object?, Object?>(
        'recognizeText',
        <String, Object>{'imagePath': imagePath},
      );

      if (response == null) {
        return const OcrRecognitionResponse(
          status: SignatureSheetScanStatus.noText,
          text: '',
          message: 'OCR returned no result.',
        );
      }

      return OcrRecognitionResponse.fromMap(response);
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
  '유튜브',
  '서명',
  '선물',
  '신랑',
  '신부',
  '안내',
  '조회수',
  '예약',
  '응모',
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
