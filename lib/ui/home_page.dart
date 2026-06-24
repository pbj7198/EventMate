// Home dashboard focused on quick context and recent activity.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../state/inyeon_controller.dart';
import '../utils/formatters.dart';
import '../utils/record_summaries.dart';
import 'common_widgets.dart';
import 'record_form_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inyeonControllerProvider);
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final thisMonth = DateTime.now();
    final monthRecords = recordsInMonth(state.records, thisMonth);
    final given = totalAmount(
      state.records,
      transactionType: TransactionType.given,
    );
    final received = totalAmount(
      state.records,
      transactionType: TransactionType.received,
    );
    final recentRecords = [...state.records]..sort((a, b) => b.date.compareTo(a.date));

    return RefreshIndicator(
      onRefresh: () => ref.read(inyeonControllerProvider.notifier).load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            '이번 달 인연과 경조사를 빠르게 확인해보세요.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SummaryCard(
                  title: '총 준 금액',
                  value: formatWon(given),
                  icon: Icons.send_outlined,
                  accentColor: const Color(0xFFB35B3E),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SummaryCard(
                  title: '총 받은 금액',
                  value: formatWon(received),
                  icon: Icons.mark_email_read_outlined,
                  accentColor: const Color(0xFF2F7D67),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: '이번 달 경조사'),
          if (monthRecords.isEmpty)
            const EmptyStateCard(message: '아직 기록된 인연이 없어요')
          else
            ...monthRecords.take(3).map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RecordTile(
                  record: record,
                  compact: true,
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
          const SizedBox(height: 8),
          const SectionHeader(title: '최근 기록'),
          if (recentRecords.isEmpty)
            const EmptyStateCard(message: '아직 기록된 인연이 없어요')
          else
            ...recentRecords.take(2).map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RecordTile(
                  record: record,
                  compact: true,
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
      ),
    );
  }
}
