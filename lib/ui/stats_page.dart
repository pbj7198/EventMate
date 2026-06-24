// Statistics page summarizing amounts by type, relationship, and month.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../state/inyeon_controller.dart';
import '../utils/formatters.dart';
import '../utils/record_summaries.dart';
import 'common_widgets.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inyeonControllerProvider);
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final records = state.records;
    final given = totalAmount(records, transactionType: TransactionType.given);
    final received = totalAmount(
      records,
      transactionType: TransactionType.received,
    );
    final byEvent = totalsByEventType(records);
    final byRelationship = totalsByRelationship(records);
    final byMonth = monthlySummaries(records);
    final sortedEventEntries = byEvent.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedRelationshipEntries = byRelationship.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedMonthEntries = byMonth.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 170,
          children: [
            SummaryCard(
              title: '전체 준 금액',
              value: formatWon(given),
              icon: Icons.south_west_outlined,
            ),
            SummaryCard(
              title: '전체 받은 금액',
              value: formatWon(received),
              icon: Icons.north_east_outlined,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: '행사 종류별 금액'),
        if (sortedEventEntries.isEmpty)
          const EmptyStateCard(message: '아직 기록된 인연이 없어요')
        else
          ...sortedEventEntries.map(
            (entry) => _MetricRow(
              label: entry.key,
              value: formatWon(entry.value),
            ),
          ),
        const SizedBox(height: 20),
        const SectionHeader(title: '관계별 금액'),
        if (sortedRelationshipEntries.isEmpty)
          const EmptyStateCard(message: '아직 기록된 인연이 없어요')
        else
          ...sortedRelationshipEntries.map(
            (entry) =>
                _MetricRow(label: entry.key, value: formatWon(entry.value)),
          ),
        const SizedBox(height: 20),
        const SectionHeader(title: '월별 금액 요약'),
        if (byMonth.isEmpty)
          const EmptyStateCard(message: '아직 기록된 인연이 없어요')
        else
          ...sortedMonthEntries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.value.monthLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _MetricRow(
                      label: '준 금액',
                      value: formatWon(entry.value.given),
                    ),
                    _MetricRow(
                      label: '받은 금액',
                      value: formatWon(entry.value.received),
                    ),
                    _MetricRow(
                      label: '순액',
                      value: formatWon(entry.value.total),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
