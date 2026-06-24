import 'package:flutter_test/flutter_test.dart';

import 'package:inyeon_jangbu/models/enums.dart';
import 'package:inyeon_jangbu/models/occasion_record.dart';
import 'package:inyeon_jangbu/models/person.dart';

void main() {
  test('person and record serialize round-trip', () {
    final person = Person(
      id: 'p1',
      name: '김민수',
      relationship: '친구',
      phoneNumber: '010-1234-5678',
      memo: '대학 동기',
      createdAt: DateTime.parse('2026-06-01T10:00:00.000'),
    );
    final record = OccasionRecord(
      id: 'r1',
      personId: 'p1',
      personName: '김민수',
      relationship: '친구',
      eventType: EventType.wedding,
      date: DateTime.parse('2026-06-24T10:00:00.000'),
      amount: 100000,
      transactionType: TransactionType.given,
      location: '서울 웨딩홀',
      memo: '축하',
      createdAt: DateTime.parse('2026-06-24T10:00:00.000'),
      updatedAt: DateTime.parse('2026-06-24T10:00:00.000'),
    );

    expect(Person.fromMap(person.toMap()).toMap(), person.toMap());
    expect(OccasionRecord.fromMap(record.toMap()).toMap(), record.toMap());
  });
}
