// Home dashboard that surfaces this month's records and quick totals.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../state/inyeon_controller.dart';
import '../utils/formatters.dart';
import '../utils/record_summaries.dart';
import 'common_widgets.dart';
import 'person_detail_page.dart';
import 'record_form_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key, required this.onAddRecord});

  final VoidCallback onAddRecord;

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

    return RefreshIndicator(
      onRefresh: () => ref.read(inyeonControllerProvider.notifier).load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            '이번 달 인연 흐름을 한눈에 확인하세요.',
            style: Theme.of(context).textTheme.titleMedium,
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
                icon: Icons.send_outlined,
                accentColor: const Color(0xFFB35B3E),
              ),
              SummaryCard(
                title: '총 받은 금액',
                value: formatWon(received),
                icon: Icons.mark_email_read_outlined,
                accentColor: const Color(0xFF2F7D67),
              ),
              SummaryCard(
                title: '이번 달 기록',
                value: '${monthRecords.length}건',
                icon: Icons.event_note_outlined,
              ),
              SummaryCard(
                title: '등록된 인연',
                value: '${state.people.length}명',
                icon: Icons.groups_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionHeader(
            title: '이번 달 경조사 목록',
            actionLabel: '기록 추가',
            onActionTap: onAddRecord,
          ),
          if (monthRecords.isEmpty)
            EmptyStateCard(
              message: '아직 기록된 인연이 없어요.\n빠른 기록으로 첫 경조사를 남겨보세요.',
              actionLabel: '기록 추가',
              onActionTap: onAddRecord,
            )
          else
            ...monthRecords.map(
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
          const SizedBox(height: 8),
          SectionHeader(title: '최근 인연'),
          if (state.people.isEmpty)
            const EmptyStateCard(message: '아직 기록된 인연이 없어요')
          else
            ...state.people
                .take(3)
                .map(
                  (person) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: Text(person.name),
                      subtitle: Text(person.relationship),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                PersonDetailPage(personId: person.id),
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
