// Ledger page that shows people-level give/receive totals at a glance.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../state/inyeon_controller.dart';
import '../utils/formatters.dart';
import '../utils/record_summaries.dart';
import 'common_widgets.dart';
import 'person_detail_page.dart';

class LedgerPage extends ConsumerStatefulWidget {
  const LedgerPage({super.key, required this.onAddRecord});

  final VoidCallback onAddRecord;

  @override
  ConsumerState<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends ConsumerState<LedgerPage> {
  String _query = '';
  LedgerFilter _filter = LedgerFilter.all;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inyeonControllerProvider);
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final summaries = personLedgerSummaries(state.records).where((item) {
      final matchesQuery = _query.trim().isEmpty ||
          item.personName.contains(_query.trim()) ||
          item.relationship.contains(_query.trim());
      final matchesFilter = switch (_filter) {
        LedgerFilter.all => true,
        LedgerFilter.given => item.given > 0,
        LedgerFilter.received => item.received > 0,
      };
      return matchesQuery && matchesFilter;
    }).toList();

    final given = totalAmount(state.records, transactionType: TransactionType.given);
    final received = totalAmount(
      state.records,
      transactionType: TransactionType.received,
    );
    final net = received - given;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text(
          '누구에게 얼마를 주고, 얼마를 받았는지 한눈에 보세요.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 170,
          children: [
            SummaryCard(
              title: '준 금액',
              value: formatWon(given),
              icon: Icons.trending_down,
              accentColor: const Color(0xFFB35B3E),
            ),
            SummaryCard(
              title: '받은 금액',
              value: formatWon(received),
              icon: Icons.trending_up,
              accentColor: const Color(0xFF2F7D67),
            ),
            SummaryCard(
              title: '순액',
              value: net >= 0 ? '+${formatWon(net)}' : formatWon(net),
              icon: Icons.account_balance_wallet_outlined,
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: '이름 또는 관계로 검색',
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 12),
        SegmentedButton<LedgerFilter>(
          segments: const [
            ButtonSegment(value: LedgerFilter.all, label: Text('전체')),
            ButtonSegment(value: LedgerFilter.given, label: Text('준 사람')),
            ButtonSegment(value: LedgerFilter.received, label: Text('받은 사람')),
          ],
          selected: {_filter},
          onSelectionChanged: (value) {
            setState(() => _filter = value.first);
          },
        ),
        const SizedBox(height: 16),
        SectionHeader(
          title: '인연 장부',
          actionLabel: '기록 추가',
          onActionTap: widget.onAddRecord,
        ),
        if (summaries.isEmpty)
          EmptyStateCard(
            message: '아직 기록된 인연이 없어요.\n기록 추가로 첫 장부를 남겨보세요.',
            actionLabel: '기록 추가',
            onActionTap: widget.onAddRecord,
          )
        else
          ...summaries.map(
            (summary) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                leading: CircleAvatar(
                  child: Text(
                    summary.personName.isNotEmpty
                        ? summary.personName.substring(0, 1)
                        : '?',
                  ),
                ),
                title: Text(summary.personName),
                subtitle: Text(summary.relationship),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '준 ${formatWon(summary.given)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '받음 ${formatWon(summary.received)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PersonDetailPage(personId: summary.personId),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

enum LedgerFilter { all, given, received }
