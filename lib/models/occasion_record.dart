// Occasion record model for a single event transaction.
import 'enums.dart';

class OccasionRecord {
  const OccasionRecord({
    required this.id,
    required this.personId,
    required this.personName,
    required this.relationship,
    required this.eventType,
    required this.date,
    required this.amount,
    required this.transactionType,
    this.location,
    this.memo,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String personId;
  final String personName;
  final String relationship;
  final EventType eventType;
  final DateTime date;
  final int amount;
  final TransactionType transactionType;
  final String? location;
  final String? memo;
  final DateTime createdAt;
  final DateTime updatedAt;

  OccasionRecord copyWith({
    String? id,
    String? personId,
    String? personName,
    String? relationship,
    EventType? eventType,
    DateTime? date,
    int? amount,
    TransactionType? transactionType,
    String? location,
    String? memo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OccasionRecord(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      personName: personName ?? this.personName,
      relationship: relationship ?? this.relationship,
      eventType: eventType ?? this.eventType,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      transactionType: transactionType ?? this.transactionType,
      location: location ?? this.location,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personId': personId,
      'personName': personName,
      'relationship': relationship,
      'eventType': eventType.name,
      'date': date.toIso8601String(),
      'amount': amount,
      'transactionType': transactionType.name,
      'location': location,
      'memo': memo,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory OccasionRecord.fromMap(Map<String, dynamic> map) {
    return OccasionRecord(
      id: map['id'] as String,
      personId: map['personId'] as String,
      personName: map['personName'] as String? ?? '',
      relationship: map['relationship'] as String? ?? '기타',
      eventType: eventTypeFromString(map['eventType'] as String? ?? 'other'),
      date: DateTime.parse(map['date'] as String),
      amount: (map['amount'] as num).toInt(),
      transactionType: transactionTypeFromString(
        map['transactionType'] as String? ?? 'given',
      ),
      location: map['location'] as String?,
      memo: map['memo'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
