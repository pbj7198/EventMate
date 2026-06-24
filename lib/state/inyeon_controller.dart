// Riverpod StateNotifier that coordinates load, save, and local mutations.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/app_snapshot.dart';
import '../models/occasion_record.dart';
import '../models/person.dart';
import '../models/record_input.dart';
import '../repositories/inyeon_repository.dart';
import '../repositories/shared_preferences_inyeon_repository.dart';
import '../utils/formatters.dart';
import 'inyeon_state.dart';

final repositoryProvider = Provider<InyeonRepository>((ref) {
  return SharedPreferencesInyeonRepository();
});

final inyeonControllerProvider =
    StateNotifierProvider<InyeonController, InyeonState>((ref) {
      return InyeonController(ref.read(repositoryProvider));
    });

class InyeonController extends StateNotifier<InyeonState> {
  InyeonController(this._repository) : super(const InyeonState.loading()) {
    unawaited(load());
  }

  final InyeonRepository _repository;
  final _uuid = const Uuid();

  Future<void> load() async {
    try {
      final snapshot = await _repository.load();
      state = state.copyWith(
        isLoading: false,
        people: snapshot.people,
        records: snapshot.records,
        errorMessage: null,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '데이터를 불러오지 못했어요: $error',
      );
    }
  }

  Future<void> saveRecord(RecordInput input) async {
    final now = DateTime.now();
    final people = [...state.people];
    final records = [...state.records];

    final normalizedName = input.personName.trim();
    final normalizedRelationship = input.relationship.trim();
    final existingPersonIndex = _findPersonIndex(
      people,
      personId: input.personId,
      name: normalizedName,
      relationship: normalizedRelationship,
    );

    final personId = existingPersonIndex == -1
        ? input.personId ?? _uuid.v4()
        : people[existingPersonIndex].id;

    final person = Person(
      id: personId,
      name: normalizedName,
      relationship: normalizedRelationship,
      phoneNumber: nullIfBlank(input.phoneNumber),
      memo: nullIfBlank(input.memo),
      createdAt: existingPersonIndex == -1
          ? now
          : people[existingPersonIndex].createdAt,
    );

    if (existingPersonIndex == -1) {
      people.add(person);
    } else {
      people[existingPersonIndex] = person;
    }

    final recordId = input.recordId ?? _uuid.v4();
    final existingRecordIndex = records.indexWhere(
      (record) => record.id == recordId,
    );
    final record = OccasionRecord(
      id: recordId,
      personId: personId,
      personName: normalizedName,
      relationship: normalizedRelationship,
      eventType: input.eventType,
      date: input.date,
      amount: input.amount,
      transactionType: input.transactionType,
      location: nullIfBlank(input.location),
      memo: nullIfBlank(input.memo),
      createdAt: existingRecordIndex == -1
          ? now
          : records[existingRecordIndex].createdAt,
      updatedAt: now,
    );

    if (existingRecordIndex == -1) {
      records.add(record);
    } else {
      records[existingRecordIndex] = record;
    }

    await _save(AppSnapshot(people: people, records: records));
  }

  Future<void> deleteRecord(String recordId) async {
    final records = [...state.records]
      ..removeWhere((record) => record.id == recordId);
    await _save(AppSnapshot(people: state.people, records: records));
  }

  Person? personById(String personId) {
    for (final person in state.people) {
      if (person.id == personId) {
        return person;
      }
    }
    return null;
  }

  List<OccasionRecord> recordsForPerson(String personId) {
    return state.records.where((record) => record.personId == personId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> _save(AppSnapshot snapshot) async {
    try {
      await _repository.save(snapshot);
      state = state.copyWith(
        isLoading: false,
        people: snapshot.people,
        records: snapshot.records,
        errorMessage: null,
      );
    } catch (error) {
      state = state.copyWith(errorMessage: '저장에 실패했어요: $error');
    }
  }

  int _findPersonIndex(
    List<Person> people, {
    String? personId,
    required String name,
    required String relationship,
  }) {
    if (personId != null) {
      final byId = people.indexWhere((person) => person.id == personId);
      if (byId != -1) {
        return byId;
      }
    }
    return people.indexWhere(
      (person) =>
          person.name.trim().toLowerCase() == name.toLowerCase() &&
          person.relationship.trim() == relationship,
    );
  }
}
