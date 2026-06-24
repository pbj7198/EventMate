// Statistics page focused on practical, decision-friendly insights.
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
    final received = totalAmount(records, transactionType: TransactionType.received);
    final net = received - given;
    final recordCount = records.length;
    final people = personLedgerSummaries(records);
    final byRelationship = totalsByRelationship(records);
    final byEvent = totalsByEventType(records);
    final byMonth = monthlySummaries(records);

    final topPeople = [...people]
      ..sort((a, b) => (b.given + b.received).compareTo(a.given + a.received));
    final topRelationships = byRelationship.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final monthEntries = byMonth.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final eventEntries = byEvent.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final monthHint = monthEntries.isEmpty
        ? '아직 기록된 인연이 없어요'
        : '${monthEntries.first.value.monthLabel} 기준';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text(
          '실제로 가장 많이 보는 지표는 사람, 월별 흐름, 그리고 순액입니다.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '행사 종류별 금액은 보조 정보로 두고, 먼저 돈의 흐름이 보이게 정리했어요.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 170,
          children: [
            SummaryCard(
              title: '총 준 금액',
              value: formatWon(given),
              icon: Icons.south_west_outlined,
              subtitle: '내가 먼저 보낸 금액',
              accentColor: const Color(0xFFB35B3E),
            ),
            SummaryCard(
              title: '총 받은 금액',
              value: formatWon(received),
              icon: Icons.north_east_outlined,
              subtitle: '내가 돌려받은 금액',
              accentColor: const Color(0xFF2F7D67),
            ),
            SummaryCard(
              title: '순액',
              value: formatWon(net),
              icon: Icons.balance_outlined,
              subtitle: net >= 0 ? '받은 금액이 더 많아요' : '준 금액이 더 많아요',
            ),
            SummaryCard(
              title: '기록 수',
              value: '$recordCount건',
              icon: Icons.event_note_outlined,
              subtitle: monthHint,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: '가장 많이 오간 인연'),
        if (topPeople.isEmpty)
          const EmptyStateCard(message: '아직 기록된 인연이 없어요')
        else
          ...topPeople.take(3).map(
            (summary) => _InsightCard(
              title: summary.personName,
              subtitle:
                  '${summary.relationship} · ${summary.recordCount}건 · 최근 ${formatDate(summary.lastRecordDate)}',
              leadingLabel: summary.net >= 0 ? '받음 우세' : '줌 우세',
              leadingValue: formatWon(summary.net.abs()),
              trailingLines: [
                '준 금액  ${formatWon(summary.given)}',
                '받은 금액 ${formatWon(summary.received)}',
                '최근 행사  ${summary.lastEventLabel}',
              ],
            ),
          ),
        const SizedBox(height: 20),
        const SectionHeader(title: '관계별 금액'),
        if (topRelationships.isEmpty)
          const EmptyStateCard(message: '아직 기록된 인연이 없어요')
        else
          ...topRelationships.map(
            (entry) => _AmountBarRow(
              label: entry.key,
              value: entry.value,
              maxValue: topRelationships.first.value,
            ),
          ),
        const SizedBox(height: 20),
        const SectionHeader(title: '월별 흐름'),
        if (monthEntries.isEmpty)
          const EmptyStateCard(message: '아직 기록된 인연이 없어요')
        else
          ...monthEntries.map(
            (entry) => _MonthlyFlowCard(
              monthLabel: entry.value.monthLabel,
              given: entry.value.given,
              received: entry.value.received,
              maxValue: monthEntries
                  .map((item) => item.value.total)
                  .fold<int>(0, (max, value) => value > max ? value : max)
                  .clamp(1, 1 << 31),
            ),
          ),
        const SizedBox(height: 20),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('보조 보기: 행사 종류별 금액'),
          subtitle: const Text('필요할 때만 펼쳐서 확인해요'),
          childrenPadding: const EdgeInsets.only(top: 8),
          children: [
            if (eventEntries.isEmpty)
              const EmptyStateCard(message: '아직 기록된 인연이 없어요')
            else
              ...eventEntries.map(
                (entry) => _MetricRow(
                  label: entry.key,
                  value: formatWon(entry.value),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.subtitle,
    required this.leadingLabel,
    required this.leadingValue,
    required this.trailingLines,
  });

  final String title;
  final String subtitle;
  final String leadingLabel;
  final String leadingValue;
  final List<String> trailingLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    leadingLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    leadingValue,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...trailingLines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(line),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountBarRow extends StatelessWidget {
  const _AmountBarRow({
    required this.label,
    required this.value,
    required this.maxValue,
  });

  final String label;
  final int value;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue == 0 ? 0.0 : value / maxValue;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                formatWon(value),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: ratio,
              backgroundColor: Colors.black12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyFlowCard extends StatelessWidget {
  const _MonthlyFlowCard({
    required this.monthLabel,
    required this.given,
    required this.received,
    required this.maxValue,
  });

  final String monthLabel;
  final int given;
  final int received;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    final total = given + received;
    final givenRatio = maxValue == 0 ? 0.0 : given / maxValue;
    final receivedRatio = maxValue == 0 ? 0.0 : received / maxValue;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  monthLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(formatWon(total), style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          _TinyBar(
            label: '준 금액',
            value: given,
            ratio: givenRatio,
            color: const Color(0xFFB35B3E),
          ),
          const SizedBox(height: 10),
          _TinyBar(
            label: '받은 금액',
            value: received,
            ratio: receivedRatio,
            color: const Color(0xFF2F7D67),
          ),
        ],
      ),
    );
  }
}

class _TinyBar extends StatelessWidget {
  const _TinyBar({
    required this.label,
    required this.value,
    required this.ratio,
    required this.color,
  });

  final String label;
  final int value;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(formatWon(value)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: ratio,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
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
