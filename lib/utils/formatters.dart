// Formatting helpers for dates, currency, and text cleanup.
import 'package:intl/intl.dart';

final _wonFormatter = NumberFormat.currency(
  locale: 'ko_KR',
  symbol: '₩',
  decimalDigits: 0,
);

final _monthFormatter = DateFormat('yyyy.MM');
final _dateFormatter = DateFormat('yyyy.MM.dd');

String formatWon(int amount) => _wonFormatter.format(amount);

String formatMonth(DateTime date) => _monthFormatter.format(date);

String formatDate(DateTime date) => _dateFormatter.format(date);

String? nullIfBlank(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
