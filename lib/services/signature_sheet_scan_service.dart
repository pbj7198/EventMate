// OCR service for sign-in sheets and other photographed name lists.
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
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
  MlKitSignatureSheetScanService({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

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

    final bitmap = await _normalizePickedImage(file);
    final recognizedText = await _recognizeTextWithFallback(bitmap);
    return SignatureSheetScanResult(
      rawText: recognizedText,
      candidates: extractPersonImportDrafts(recognizedText),
    );
  }

  Future<String> _recognizeTextWithFallback(NormalizedOcrImage bitmap) async {
    final scripts = <TextRecognitionScript>[
      TextRecognitionScript.korean,
      TextRecognitionScript.latin,
    ];

    Object? lastError;
    for (final script in scripts) {
      TextRecognizer? recognizer;
      try {
        // Constructing the native recognizer can fail before processImage is
        // called, so creation belongs inside the guarded fallback path.
        recognizer = TextRecognizer(script: script);
        final inputImage = InputImage.fromBitmap(
          bitmap: bitmap.rgbaBytes,
          width: bitmap.width,
          height: bitmap.height,
        );
        final result = await recognizer.processImage(inputImage);
        return result.text;
      } catch (error) {
        lastError = error;
      } finally {
        if (recognizer != null) {
          try {
            await recognizer.close();
          } catch (_) {
            // A failed native initialization may not have a detector to close.
          }
        }
      }
    }

    throw SignatureSheetScanException(
      '사진을 인식하지 못했어요. 문서를 평평하게 놓고 글자가 화면을 채우도록 다시 촬영해 주세요.',
      lastError,
    );
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
    required this.rgbaBytes,
    required this.width,
    required this.height,
  });

  final Uint8List rgbaBytes;
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

  // Passing a raw bitmap bypasses Android's camera JPEG/EXIF file decoder,
  // which can throw native ML Kit errors for otherwise readable photos.
  return NormalizedOcrImage(
    rgbaBytes: normalized.getBytes(order: image.ChannelOrder.rgba),
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
  return RegExp(r'^[가-힣]{2,4}$').hasMatch(text);
}
