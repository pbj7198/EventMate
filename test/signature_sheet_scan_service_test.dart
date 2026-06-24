import 'package:flutter_test/flutter_test.dart';

import 'package:inyeon_jangbu/services/signature_sheet_scan_service.dart';

void main() {
  test('extractPersonImportDrafts finds names and phones from raw OCR text', () {
    const rawText = '''
      김민수 010-1234-5678
      박영희
      홍길동 010 9876 5432
    ''';

    final candidates = extractPersonImportDrafts(rawText);

    expect(candidates.length, 3);
    expect(candidates[0].name, '김민수');
    expect(candidates[0].phoneNumber, '01012345678');
    expect(candidates[1].name, '박영희');
    expect(candidates[1].phoneNumber, isNull);
    expect(candidates[2].name, '홍길동');
    expect(candidates[2].phoneNumber, '01098765432');
  });

  test('photo text from the attached screenshots does not become fake names', () {
    const rawText = '그만 먹으라고 괴물쥐 유튜브 조회수 47만회 2일';

    expect(extractPersonImportDrafts(rawText), isEmpty);
  });

  test('app screenshot text also stays out of the person candidate list', () {
    const rawText = '''
      사진 글자 스캔
      사진 속 글자를 추출하고, 사람 이름으로 보이는 항목은 인연 후보로 정리해드려요.
      아직 스캔한 사진이 없어요.
    ''';

    expect(extractPersonImportDrafts(rawText), isEmpty);
  });
}
