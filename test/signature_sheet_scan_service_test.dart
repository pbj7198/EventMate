import 'package:flutter_test/flutter_test.dart';

import 'package:inyeon_jangbu/services/signature_sheet_scan_service.dart';

void main() {
  test('extractPersonImportDrafts finds names and phones from OCR text', () {
    const rawText = '''
홍길동 010-1234-5678
박영희 010 9876 5432
김민수
''';

    final candidates = extractPersonImportDrafts(rawText);

    expect(candidates.length, 3);
    expect(candidates[0].name, '홍길동');
    expect(candidates[0].phoneNumber, '01012345678');
    expect(candidates[1].name, '박영희');
    expect(candidates[1].phoneNumber, '01098765432');
    expect(candidates[2].name, '김민수');
    expect(candidates[2].phoneNumber, isNull);
  });

  test('photo text from posters does not become fake names', () {
    const rawText = '''
그만 먹으라고
주문내역과 리뷰 캡처
사진 글자 스캔
아직 스캔한 사진이 없어요
''';

    expect(extractPersonImportDrafts(rawText), isEmpty);
  });

  test('spaced Korean names are normalized', () {
    const rawText = '''
박 병 수
이  순  자 010-5555-6666
''';

    final candidates = extractPersonImportDrafts(rawText);

    expect(candidates.length, 2);
    expect(candidates[0].name, '박병수');
    expect(candidates[1].name, '이순자');
    expect(candidates[1].phoneNumber, '01055556666');
  });
}
