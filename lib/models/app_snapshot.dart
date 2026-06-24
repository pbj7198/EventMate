// Simple persistence bundle for people and records.
import 'occasion_record.dart';
import 'person.dart';

class AppSnapshot {
  const AppSnapshot({required this.people, required this.records});

  final List<Person> people;
  final List<OccasionRecord> records;

  AppSnapshot copyWith({List<Person>? people, List<OccasionRecord>? records}) {
    return AppSnapshot(
      people: people ?? this.people,
      records: records ?? this.records,
    );
  }
}
