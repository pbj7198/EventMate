// OCR-assisted import flow for photographed sign-in sheets and text-heavy photos.
//
// The service keeps camera capture, OCR engine selection, and person parsing
// separate so the OCR backend can change without affecting the rest of the app.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/person_import_draft.dart';
import 'signature_sheet_ocr_engines.dart';

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

class HybridSignatureSheetScanService implements SignatureSheetScanService {
  HybridSignatureSheetScanService({
    ImagePicker? imagePicker,
    SignatureSheetOcrEngine? ocrEngine,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _ocrEngine = ocrEngine ?? createDefaultSignatureSheetOcrEngine();

  final ImagePicker _imagePicker;
  final SignatureSheetOcrEngine _ocrEngine;

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
        message:
            '사진에서 읽을 수 있는 글자를 찾지 못했어요. 글자가 화면을 가득 채우도록 다시 찍어주세요.',
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
    try {
      final text = await _ocrEngine.recognizeText(imagePath);
      return text.trim();
    } catch (error, stackTrace) {
      debugPrint('OCR engine failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw SignatureSheetScanException(
        '사진의 글자를 읽지 못했어요. 잠시 후 다시 시도해 주세요.',
        error,
      );
    }
  }
}

final signatureSheetScanServiceProvider =
    Provider<SignatureSheetScanService>((ref) {
      return HybridSignatureSheetScanService();
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
    final draftNames = _extractNamesFromLine(line, phone);
    for (final draft in draftNames) {
      final key = '${draft.name}|${draft.phoneNumber ?? ''}';
      if (seen.add(key)) {
        candidates.add(draft);
      }
    }
  }

  return candidates;
}

final _phonePattern = RegExp(r'(01[016789][-\s]?\d{3,4}[-\s]?\d{4})');
final _splitPattern = RegExp(r'[\s,·•:;|/\\\-\[\]\(\){}<>]+');
final _nonHangulPattern = RegExp(r'[^가-힣]');

String? _extractPhoneNumber(String line) {
  final match = _phonePattern.firstMatch(line);
  if (match == null) {
    return null;
  }
  return match.group(1)?.replaceAll(RegExp(r'[\s-]'), '');
}

List<PersonImportDraft> _extractNamesFromLine(String line, String? phone) {
  final normalized = line.replaceAll(_phonePattern, ' ');
  final tokens = normalized
      .split(_splitPattern)
      .map((token) => token.replaceAll(_nonHangulPattern, ''))
      .where((token) => token.isNotEmpty)
      .toList();

  final names = <String>{};

  for (final token in tokens) {
    if (_looksLikeKoreanName(token)) {
      names.add(token);
    }
  }

  if (names.isEmpty) {
    final collapsed = tokens.join();
    if (_looksLikeKoreanName(collapsed) &&
        _isLikelyNameLine(line, phone, tokens)) {
      names.add(collapsed);
    }
  }

  if (names.isEmpty || !_isLikelyPersonContext(line, phone, names)) {
    return const [];
  }

  return names
      .map(
        (name) =>
            PersonImportDraft(name: name, phoneNumber: phone, sourceLine: line),
      )
      .toList();
}

bool _isLikelyNameLine(String line, String? phone, List<String> tokens) {
  if (phone != null) {
    return true;
  }

  if (tokens.length == 1) {
    return true;
  }

  final collapsedLength = line.replaceAll(RegExp(r'\s+'), '').length;
  return tokens.length <= 3 && collapsedLength <= 12;
}

bool _isLikelyPersonContext(
  String line,
  String? phone,
  Set<String> names,
) {
  if (phone != null) {
    return true;
  }

  if (names.length == 1) {
    return true;
  }

  if (RegExp(r'[,|/]').hasMatch(line) && names.length <= 3) {
    return true;
  }

  return false;
}

bool _looksLikeKoreanName(String value) {
  if (!RegExp(r'^[가-힣]{2,4}$').hasMatch(value)) {
    return false;
  }

  if (_noiseWords.contains(value)) {
    return false;
  }

  if (RegExp(r'^(.)\1+$').hasMatch(value)) {
    return false;
  }

  return true;
}

const _noiseWords = <String>{
  '가족',
  '친척',
  '친구',
  '회사',
  '지인',
  '기타',
  '관계',
  '이름',
  '성함',
  '메모',
  '결혼',
  '결혼식',
  '장례',
  '장례식',
  '돌잔치',
  '생일',
  '개업',
  '축하',
  '감사',
  '응원',
  '서명',
  '명단',
  '참석',
  '인원',
};
