// Form payload used when adding or editing a record.
import 'enums.dart';

class RecordInput {
  const RecordInput({
    this.recordId,
    this.personId,
    required this.personName,
    required this.relationship,
    required this.eventType,
    required this.date,
    required this.amount,
    required this.transactionType,
    this.location,
    this.memo,
    this.phoneNumber,
  });

  final String? recordId;
  final String? personId;
  final String personName;
  final String relationship;
  final EventType eventType;
  final DateTime date;
  final int amount;
  final TransactionType transactionType;
  final String? location;
  final String? memo;
  final String? phoneNumber;
}
