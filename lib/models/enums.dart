// Shared enums and labels used across records, forms, and summaries.
import 'package:flutter/material.dart';

enum TransactionType { given, received }

enum EventType { wedding, funeral, firstBirthday, birthday, opening, other }

const relationshipOptions = <String>['가족', '친척', '친구', '회사', '지인', '기타'];

extension TransactionTypeX on TransactionType {
  String get label => switch (this) {
    TransactionType.given => '내가 줌',
    TransactionType.received => '내가 받음',
  };

  Color get color => switch (this) {
    TransactionType.given => const Color(0xFFB35B3E),
    TransactionType.received => const Color(0xFF2F7D67),
  };
}

extension EventTypeX on EventType {
  String get label => switch (this) {
    EventType.wedding => '결혼식',
    EventType.funeral => '장례식',
    EventType.firstBirthday => '돌잔치',
    EventType.birthday => '생일',
    EventType.opening => '개업식',
    EventType.other => '기타',
  };
}

TransactionType transactionTypeFromString(String value) {
  return TransactionType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => TransactionType.given,
  );
}

EventType eventTypeFromString(String value) {
  return EventType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => EventType.other,
  );
}
