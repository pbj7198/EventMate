// On-device OCR engines used by the sign-in sheet scanner.
//
// This file keeps OCR engine setup separate from parsing and UI concerns so the
// scanning service can remain testable and future engines can be swapped in.

import 'dart:io';

import 'package:fast_paddle_ocr/ocr.dart' as fast_paddle_ocr;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import 'ocr_image_preprocessor.dart';

abstract class SignatureSheetOcrEngine {
  Future<String> recognizeText(String imagePath);
}

typedef TextRecognizerFactory = TextRecognizer Function(
  TextRecognitionScript script,
);

class MlKitSignatureSheetOcrEngine implements SignatureSheetOcrEngine {
  MlKitSignatureSheetOcrEngine({
    TextRecognizerFactory? recognizerFactory,
  }) : _recognizerFactory =
           recognizerFactory ?? ((script) => TextRecognizer(script: script));

  final TextRecognizerFactory _recognizerFactory;

  @override
  Future<String> recognizeText(String imagePath) async {
    final image = InputImage.fromFilePath(imagePath);
    final koreanRecognizer = _recognizerFactory(TextRecognitionScript.korean);
    TextRecognizer? latinRecognizer;

    try {
      final koreanResult = await koreanRecognizer.processImage(image);
      final koreanText = koreanResult.text.trim();
      if (koreanText.isNotEmpty) {
        return koreanText;
      }

      latinRecognizer = _recognizerFactory(TextRecognitionScript.latin);
      final latinResult = await latinRecognizer.processImage(image);
      return latinResult.text.trim();
    } finally {
      koreanRecognizer.close();
      latinRecognizer?.close();
    }
  }
}

class FastPaddleSignatureSheetOcrEngine implements SignatureSheetOcrEngine {
  FastPaddleSignatureSheetOcrEngine({
    KoreanOcrModelBundle? modelBundle,
    fast_paddle_ocr.Ocr? ocr,
    OcrImagePreprocessor? imagePreprocessor,
  }) : _modelBundle = modelBundle ?? const KoreanOcrModelBundle(),
       _ocr = ocr ?? fast_paddle_ocr.Ocr(),
       _imagePreprocessor =
           imagePreprocessor ?? const AdaptiveOcrImagePreprocessor();

  final KoreanOcrModelBundle _modelBundle;
  final fast_paddle_ocr.Ocr _ocr;
  final OcrImagePreprocessor _imagePreprocessor;
  Future<void>? _loadFuture;

  bool get isAndroid => Platform.isAndroid;

  @override
  Future<String> recognizeText(String imagePath) async {
    if (!isAndroid) {
      throw UnsupportedError('Fast Paddle OCR is only available on Android.');
    }

    await _ensureLoaded();
    final imagePaths = await _imagePreprocessor.prepare(imagePath);
    final recognizedLines = <String>[];
    final seen = <String>{};

    try {
      for (final path in imagePaths) {
        final text = (await _ocr.ocrFromImage(path))?.trim() ?? '';
        for (final line in text.split(RegExp(r'[\r\n]+'))) {
          final normalized = line.trim();
          if (normalized.isNotEmpty && seen.add(normalized)) {
            recognizedLines.add(normalized);
          }
        }
      }
    } finally {
      for (final path in imagePaths.where((path) => path != imagePath)) {
        try {
          await File(path).delete();
        } on FileSystemException {
          // Temporary variants may already have been removed by the OS.
        }
      }
    }
    return recognizedLines.join('\n');
  }

  Future<void> _ensureLoaded() {
    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    final paths = await _modelBundle.prepare();
    await _ocr.loadModel(
      detParam: paths.detParam,
      detModel: paths.detModel,
      recParam: paths.recParam,
      recModel: paths.recModel,
      // 640px detector input preserves small handwriting better than the
      // plugin default of 320px.
      sizeid: 4,
      cpugpu: 0,
    );
  }
}

class KoreanOcrModelBundle {
  const KoreanOcrModelBundle({
    this.assetPrefix = 'assets/ocr_models/korean',
  });

  final String assetPrefix;

  Future<KoreanOcrModelPaths> prepare() async {
    final directory = await getApplicationDocumentsDirectory();
    final modelDirectory = Directory(
      '${directory.path}/ocr_models/korean',
    );

    if (!await modelDirectory.exists()) {
      await modelDirectory.create(recursive: true);
    }

    final detParam = await _copyAsset(
      'det.ncnn.param',
      modelDirectory,
    );
    final detModel = await _copyAsset(
      'det.ncnn.bin',
      modelDirectory,
    );
    final recParam = await _copyAsset(
      'rec.ncnn.param',
      modelDirectory,
    );
    final recModel = await _copyAsset(
      'rec.ncnn.bin',
      modelDirectory,
    );

    return KoreanOcrModelPaths(
      detParam: detParam,
      detModel: detModel,
      recParam: recParam,
      recModel: recModel,
    );
  }

  Future<String> _copyAsset(String fileName, Directory targetDirectory) async {
    final targetFile = File('${targetDirectory.path}/$fileName');
    if (await targetFile.exists() && await targetFile.length() > 0) {
      return targetFile.path;
    }

    final assetPath = '$assetPrefix/$fileName';
    final data = await rootBundle.load(assetPath);
    await targetFile.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    return targetFile.path;
  }
}

class KoreanOcrModelPaths {
  const KoreanOcrModelPaths({
    required this.detParam,
    required this.detModel,
    required this.recParam,
    required this.recModel,
  });

  final String detParam;
  final String detModel;
  final String recParam;
  final String recModel;
}

SignatureSheetOcrEngine createDefaultSignatureSheetOcrEngine() {
  if (Platform.isAndroid) {
    return _HybridAndroidSignatureSheetOcrEngine();
  }
  return MlKitSignatureSheetOcrEngine();
}

class _HybridAndroidSignatureSheetOcrEngine
    implements SignatureSheetOcrEngine {
  _HybridAndroidSignatureSheetOcrEngine({
    SignatureSheetOcrEngine? primary,
    SignatureSheetOcrEngine? fallback,
  }) : _primary = primary ?? FastPaddleSignatureSheetOcrEngine(),
       _fallback = fallback ?? MlKitSignatureSheetOcrEngine();

  final SignatureSheetOcrEngine _primary;
  final SignatureSheetOcrEngine _fallback;

  @override
  Future<String> recognizeText(String imagePath) async {
    final recognizedLines = <String>[];
    final seen = <String>{};

    try {
      final text = await _primary.recognizeText(imagePath);
      _appendUniqueLines(text, recognizedLines, seen);
    } catch (error, stackTrace) {
      debugPrint('Fast Paddle OCR failed, falling back to ML Kit: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      final text = await _fallback.recognizeText(imagePath);
      _appendUniqueLines(text, recognizedLines, seen);
    } catch (error, stackTrace) {
      if (recognizedLines.isEmpty) {
        rethrow;
      }
      debugPrint('ML Kit OCR failed after Paddle OCR succeeded: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    return recognizedLines.join('\n');
  }
}

void _appendUniqueLines(
  String text,
  List<String> output,
  Set<String> seen,
) {
  for (final line in text.split(RegExp(r'[\r\n]+'))) {
    final normalized = line.trim();
    if (normalized.isNotEmpty && seen.add(normalized)) {
      output.add(normalized);
    }
  }
}
