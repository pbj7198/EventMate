import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:inyeon_jangbu/services/ocr_image_preprocessor.dart';

void main() {
  test('creates overlapping enlarged variants for small text', () async {
    final directory = await Directory.systemTemp.createTemp('inyeon_ocr_test');
    addTearDown(() => directory.delete(recursive: true));

    final source = img.Image(width: 1000, height: 1600);
    img.fill(source, color: img.ColorRgb8(245, 245, 245));
    final sourceFile = File('${directory.path}/source.jpg');
    await sourceFile.writeAsBytes(img.encodeJpg(source));

    final preprocessor = AdaptiveOcrImagePreprocessor(
      temporaryDirectoryProvider: () async => directory,
    );
    final paths = await preprocessor.prepare(sourceFile.path);

    expect(paths, hasLength(5));
    expect(paths.map(File.new).every((file) => file.existsSync()), isTrue);

    final bottomRight = img.decodeJpg(
      await File(paths.last).readAsBytes(),
    )!;
    expect(bottomRight.height, 1280);
    expect(bottomRight.width, greaterThan(700));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
