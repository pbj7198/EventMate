// OCR service for sign-in sheets and other photographed name lists.
import 'dart:io';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

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

class MlKitSignatureSheetScanService implements SignatureSheetScanService {
  MlKitSignatureSheetScanService({ImagePicker? imagePicker})
      : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  @override
  Future<SignatureSheetScanResult?> scanFromCamera() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (file == null) {
      return null;
    }

    // Persist the captured image into the app's own temporary directory.
    // Samsung/Android camera flows can hand back a cache-backed file that is
    // no longer readable by the time ML Kit starts processing it.
    final persistedImage = await _persistPickedImage(file);

    final recognizer = TextRecognizer(script: TextRecognitionScript.korean);
    try {
      final inputImage = InputImage.fromFilePath(persistedImage.path);
      final recognizedText = await recognizer.processImage(inputImage);
      final candidates = extractPersonImportDrafts(recognizedText.text);
      return SignatureSheetScanResult(
        rawText: recognizedText.text,
        candidates: candidates,
      );
    } finally {
      unawaited(recognizer.close());
    }
  }

  Future<File> _persistPickedImage(XFile file) async {
    final tempDir = await getTemporaryDirectory();
    final target = File(
      '${tempDir.path}/signature_sheet_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    final bytes = await file.readAsBytes();
    return target.writeAsBytes(bytes, flush: true);
  }
}

final signatureSheetScanServiceProvider =
    Provider<SignatureSheetScanService>((ref) {
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

final _phonePattern = RegExp(
  r'(01[016789][-\s]?\d{3,4}[-\s]?\d{4})',
);

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
      PersonImportDraft(
        name: name,
        phoneNumber: phone,
        sourceLine: line,
      ),
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
  return RegExp(r'^[가-힣]{2,4}$').hasMatch(text);
}
