// Produces OCR-friendly crops so small handwriting is not lost when a full
// camera frame is resized by the text detector.

import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

typedef OcrTemporaryDirectoryProvider = Future<Directory> Function();

abstract class OcrImagePreprocessor {
  Future<List<String>> prepare(String imagePath);
}

class AdaptiveOcrImagePreprocessor implements OcrImagePreprocessor {
  const AdaptiveOcrImagePreprocessor({
    OcrTemporaryDirectoryProvider? temporaryDirectoryProvider,
  }) : _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory;

  final OcrTemporaryDirectoryProvider _temporaryDirectoryProvider;

  @override
  Future<List<String>> prepare(String imagePath) async {
    final sourceBytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) {
      return [imagePath];
    }

    final source = img.bakeOrientation(decoded);
    final tempDirectory = await _temporaryDirectoryProvider();
    final outputDirectory = Directory(
      '${tempDirectory.path}/inyeon_ocr_variants',
    );
    await outputDirectory.create(recursive: true);

    final variants = <_OcrCrop>[
      const _OcrCrop('full', 0, 0, 1, 1, enhance: false),
      const _OcrCrop('top_left', 0, 0, 0.62, 0.62),
      const _OcrCrop('top_right', 0.38, 0, 0.62, 0.62),
      const _OcrCrop('bottom_left', 0, 0.38, 0.62, 0.62),
      const _OcrCrop('bottom_right', 0.38, 0.38, 0.62, 0.62),
    ];

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final paths = <String>[];
    for (final variant in variants) {
      final prepared = _prepareVariant(source, variant);
      final output = File(
        '${outputDirectory.path}/ocr_${stamp}_${variant.name}.jpg',
      );
      await output.writeAsBytes(img.encodeJpg(prepared, quality: 95));
      paths.add(output.path);
    }
    return paths;
  }

  img.Image _prepareVariant(img.Image source, _OcrCrop crop) {
    final x = (source.width * crop.left).round().clamp(0, source.width - 1);
    final y = (source.height * crop.top).round().clamp(0, source.height - 1);
    final width = (source.width * crop.width)
        .round()
        .clamp(1, source.width - x);
    final height = (source.height * crop.height)
        .round()
        .clamp(1, source.height - y);

    var result = img.copyCrop(
      source,
      x: x,
      y: y,
      width: width,
      height: height,
    );

    if (crop.enhance) {
      result = img.grayscale(result);
      result = img.adjustColor(result, contrast: 1.45);
    }

    final longestSide = result.width > result.height
        ? result.width
        : result.height;
    if (longestSide < 1280) {
      final scale = 1280 / longestSide;
      result = img.copyResize(
        result,
        width: (result.width * scale).round(),
        height: (result.height * scale).round(),
        interpolation: img.Interpolation.cubic,
      );
    }
    return result;
  }
}

class _OcrCrop {
  const _OcrCrop(
    this.name,
    this.left,
    this.top,
    this.width,
    this.height, {
    this.enhance = true,
  });

  final String name;
  final double left;
  final double top;
  final double width;
  final double height;
  final bool enhance;
}
