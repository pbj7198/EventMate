import 'package:flutter_test/flutter_test.dart';

import 'package:inyeon_jangbu/data/seed_data.dart';
import 'package:inyeon_jangbu/models/app_snapshot.dart';
import 'package:inyeon_jangbu/models/enums.dart';
import 'package:inyeon_jangbu/models/record_input.dart';
import 'package:inyeon_jangbu/repositories/inyeon_repository.dart';
import 'package:inyeon_jangbu/state/inyeon_controller.dart';

class MemoryRepository implements InyeonRepository {
  MemoryRepository(this._snapshot);

  AppSnapshot _snapshot;

  @override
  Future<AppSnapshot> load() async => _snapshot;

  @override
  Future<void> save(AppSnapshot snapshot) async {
    _snapshot = snapshot;
  }
}

void main() {
  test('saveRecord updates people and records together', () async {
    final repository = MemoryRepository(createSeedSnapshot());
    final controller = InyeonController(repository);

    await controller.load();
    final beforePeople = controller.state.people.length;
    final beforeRecords = controller.state.records.length;

    await controller.saveRecord(
      RecordInput(
        personName: '홍길동',
        relationship: '지인',
        eventType: EventType.other,
        customEventType: '상견례',
        date: DateTime(2026, 6, 24),
        amount: 45000,
        transactionType: TransactionType.given,
        location: '서울 식당',
        memo: '첫 기록',
        phoneNumber: '010-0000-1111',
      ),
    );

    expect(controller.state.people.length, beforePeople + 1);
    expect(controller.state.records.length, beforeRecords + 1);
    expect(controller.state.records.last.personName, '홍길동');
    expect(controller.state.records.last.eventTypeLabel, '상견례');
  });
}
