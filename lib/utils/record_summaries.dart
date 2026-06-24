// Pure summary helpers used by the dashboard and stats screens.
import '../models/enums.dart';
import '../models/occasion_record.dart';
import 'formatters.dart';

class PersonLedgerSummary {
  PersonLedgerSummary({
    required this.personId,
    required this.personName,
    required this.relationship,
    required this.given,
    required this.received,
    required this.recordCount,
    required this.lastRecordDate,
    required this.lastEventType,
  });

  final String personId;
  final String personName;
  final String relationship;
  final int given;
  final int received;
  final int recordCount;
  final DateTime lastRecordDate;
  final EventType lastEventType;

  int get net => received - given;
}

class MonthlySummary {
  MonthlySummary({
    required this.monthLabel,
    required this.given,
    required this.received,
  });

  final String monthLabel;
  final int given;
  final int received;

  int get total => given + received;
}

List<OccasionRecord> recordsInMonth(
  Iterable<OccasionRecord> records,
  DateTime month,
) {
  return records
      .where(
        (record) =>
            record.date.year == month.year && record.date.month == month.month,
      )
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
}

int totalAmount(
  Iterable<OccasionRecord> records, {
  TransactionType? transactionType,
}) {
  return records
      .where(
        (record) =>
            transactionType == null ||
            record.transactionType == transactionType,
      )
      .fold<int>(0, (sum, record) => sum + record.amount);
}

Map<EventType, int> totalsByEventType(Iterable<OccasionRecord> records) {
  final result = <EventType, int>{};
  for (final record in records) {
    result[record.eventType] = (result[record.eventType] ?? 0) + record.amount;
  }
  return result;
}

Map<String, int> totalsByRelationship(Iterable<OccasionRecord> records) {
  final result = <String, int>{};
  for (final record in records) {
    result[record.relationship] =
        (result[record.relationship] ?? 0) + record.amount;
  }
  return result;
}

Map<String, MonthlySummary> monthlySummaries(Iterable<OccasionRecord> records) {
  final result = <String, MonthlySummary>{};
  for (final record in records) {
    final monthKey =
        '${record.date.year}-${record.date.month.toString().padLeft(2, '0')}';
    final existing = result[monthKey];
    final isGiven = record.transactionType == TransactionType.given;
    result[monthKey] = MonthlySummary(
      monthLabel: formatMonth(record.date),
      given: (existing?.given ?? 0) + (isGiven ? record.amount : 0),
      received: (existing?.received ?? 0) + (isGiven ? 0 : record.amount),
    );
  }
  return result;
}

List<PersonLedgerSummary> personLedgerSummaries(
  Iterable<OccasionRecord> records,
) {
  final result = <String, PersonLedgerSummary>{};
  for (final record in records) {
    final existing = result[record.personId];
    final isGiven = record.transactionType == TransactionType.given;
    result[record.personId] = PersonLedgerSummary(
      personId: record.personId,
      personName: record.personName,
      relationship: record.relationship,
      given: (existing?.given ?? 0) + (isGiven ? record.amount : 0),
      received: (existing?.received ?? 0) + (isGiven ? 0 : record.amount),
      recordCount: (existing?.recordCount ?? 0) + 1,
      lastRecordDate:
          existing == null || record.date.isAfter(existing.lastRecordDate)
          ? record.date
          : existing.lastRecordDate,
      lastEventType:
          existing == null || record.date.isAfter(existing.lastRecordDate)
          ? record.eventType
          : existing.lastEventType,
    );
  }
  final list = result.values.toList();
  list.sort((a, b) {
    final activityCompare = b.lastRecordDate.compareTo(a.lastRecordDate);
    if (activityCompare != 0) return activityCompare;
    return a.personName.compareTo(b.personName);
  });
  return list;
}
