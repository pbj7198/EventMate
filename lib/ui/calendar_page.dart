// Calendar page that shows occasion records by date.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/enums.dart';
import '../models/occasion_record.dart';
import '../state/inyeon_controller.dart';
import '../utils/formatters.dart';
import '../utils/record_summaries.dart';
import 'common_widgets.dart';
import 'record_form_page.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inyeonControllerProvider);
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final records = state.records;
    final selectedRecords = _recordsForDay(records, _selectedDay);
    final monthRecords = _recordsForMonth(records, _focusedDay);
    final monthGiven = totalAmount(
      monthRecords,
      transactionType: TransactionType.given,
    );
    final monthReceived = totalAmount(
      monthRecords,
      transactionType: TransactionType.received,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text(
          '달력에서 날짜를 눌러 해당 일의 경조사를 바로 확인하세요.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '이번 달에 어떤 날이 바빴는지 한눈에 볼 수 있어요.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        SummaryCard(
          title: '이번 달 요약',
          value: formatWon(monthGiven + monthReceived),
          icon: Icons.calendar_month_outlined,
          subtitle: '준 ${formatWon(monthGiven)} · 받은 ${formatWon(monthReceived)}',
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: TableCalendar<OccasionRecord>(
            firstDay: DateTime(2000, 1, 1),
            lastDay: DateTime(2100, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {
              CalendarFormat.month: '월',
              CalendarFormat.twoWeeks: '2주',
              CalendarFormat.week: '주',
            },
            eventLoader: (day) => _recordsForDay(records, day),
            calendarBuilders: CalendarBuilders<OccasionRecord>(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) {
                  return null;
                }
                final givenCount = events
                    .where((record) => record.transactionType == TransactionType.given)
                    .length;
                final receivedCount = events.length - givenCount;
                return Positioned(
                  bottom: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (givenCount > 0)
                        _Dot(color: const Color(0xFFB35B3E), count: givenCount),
                      if (receivedCount > 0) ...[
                        const SizedBox(width: 4),
                        _Dot(
                          color: const Color(0xFF2F7D67),
                          count: receivedCount,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              setState(() => _focusedDay = focusedDay);
            },
            headerStyle: const HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(fontWeight: FontWeight.w600),
              weekendStyle: TextStyle(fontWeight: FontWeight.w600),
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(shape: BoxShape.circle),
              outsideDaysVisible: false,
              markerSize: 6,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SectionHeader(
          title: formatDate(_selectedDay),
          actionLabel: '기록 추가',
          onActionTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RecordFormPage()),
            );
          },
        ),
        if (selectedRecords.isEmpty)
          const EmptyStateCard(message: '이 날짜에는 기록이 없어요')
        else
          ...selectedRecords.map(
            (record) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RecordTile(
                record: record,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RecordFormPage(initialRecord: record),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  List<OccasionRecord> _recordsForDay(
    Iterable<OccasionRecord> records,
    DateTime day,
  ) {
    return records.where((record) => isSameDay(record.date, day)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<OccasionRecord> _recordsForMonth(
    Iterable<OccasionRecord> records,
    DateTime day,
  ) {
    return records
        .where((record) =>
            record.date.year == day.year && record.date.month == day.month)
        .toList();
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.color,
    required this.count,
  });

  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
