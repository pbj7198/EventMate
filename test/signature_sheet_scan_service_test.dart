import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import 'package:inyeon_jangbu/services/signature_sheet_scan_service.dart';

void main() {
  test(
    'extractPersonImportDrafts finds names and phones from raw OCR text',
    () {
      const rawText = '''
    서명
    김민수 010-1234-5678
    박영희
    총무
    이준호 010 9876 5432
    ''';

      final candidates = extractPersonImportDrafts(rawText);

      expect(candidates.length, 3);
      expect(candidates[0].name, '김민수');
      expect(candidates[0].phoneNumber, '01012345678');
      expect(candidates[1].name, '박영희');
      expect(candidates[1].phoneNumber, isNull);
      expect(candidates[2].name, '이준호');
      expect(candidates[2].phoneNumber, '01098765432');
    },
  );

  test('normalizeOcrImageBytes decodes and limits large camera images', () {
    final source = image.Image(width: 3000, height: 1800);
    final bytes = Uint8List.fromList(image.encodeJpg(source));

    final normalized = normalizeOcrImageBytes(bytes);

    expect(normalized.width, 1600);
    expect(normalized.height, lessThanOrEqualTo(1600));
    expect(
      normalized.rgbaBytes.length,
      normalized.width * normalized.height * 4,
    );
  });

  test('normalizeOcrImageBytes rejects invalid camera data', () {
    expect(
      () => normalizeOcrImageBytes(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });
}
