// Ledger page that focuses on searchable relationship browsing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/inyeon_controller.dart';
import '../utils/formatters.dart';
import '../utils/record_summaries.dart';
import 'common_widgets.dart';
import 'person_detail_page.dart';

enum LedgerSortMode {
  latest,
  givenDesc,
  receivedDesc,
  totalDesc,
  name,
}

extension LedgerSortModeX on LedgerSortMode {
  String get label => switch (this) {
        LedgerSortMode.latest => '최근순',
        LedgerSortMode.givenDesc => '보낸 금액 많은 순',
        LedgerSortMode.receivedDesc => '받은 금액 많은 순',
        LedgerSortMode.totalDesc => '총액 많은 순',
        LedgerSortMode.name => '이름순',
      };
}

class LedgerPage extends ConsumerStatefulWidget {
  const LedgerPage({super.key});

  @override
  ConsumerState<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends ConsumerState<LedgerPage> {
  String _query = '';
  LedgerSortMode _sortMode = LedgerSortMode.latest;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inyeonControllerProvider);
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final summaries = personLedgerSummaries(state.records).where((item) {
      if (_query.trim().isEmpty) {
        return true;
      }
      final q = _query.trim().toLowerCase();
      return item.personName.toLowerCase().contains(q) ||
          item.relationship.toLowerCase().contains(q) ||
          item.lastEventLabel.toLowerCase().contains(q);
    }).toList();

    summaries.sort((a, b) {
      return switch (_sortMode) {
        LedgerSortMode.latest => b.lastRecordDate.compareTo(a.lastRecordDate),
        LedgerSortMode.givenDesc => b.given.compareTo(a.given),
        LedgerSortMode.receivedDesc => b.received.compareTo(a.received),
        LedgerSortMode.totalDesc =>
          (b.given + b.received).compareTo(a.given + a.received),
        LedgerSortMode.name => a.personName.compareTo(b.personName),
      };
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text(
          '인연별로 준 것과 받은 것을 구분해서 보세요.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '정렬을 바꾸면 보낸 금액이 큰 사람, 받은 금액이 큰 사람을 바로 볼 수 있어요.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: '이름, 관계, 행사 종류 검색',
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<LedgerSortMode>(
          initialValue: _sortMode,
          decoration: const InputDecoration(labelText: '정렬'),
          items: LedgerSortMode.values
              .map(
                (mode) => DropdownMenuItem(
                  value: mode,
                  child: Text(mode.label),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _sortMode = value);
            }
          },
        ),
        const SizedBox(height: 16),
        const SectionHeader(title: '인연 목록'),
        if (summaries.isEmpty)
          const EmptyStateCard(message: '아직 기록된 인연이 없어요')
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
                subtitle: Text(
                  '${summary.relationship} · 최근 ${formatDate(summary.lastRecordDate)} · ${summary.lastEventLabel}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '보낸 ${summary.givenCount}건 · 받은 ${summary.receivedCount}건',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.end,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${summary.recordCount}건 · ${formatWon(summary.given + summary.received)}',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          PersonDetailPage(personId: summary.personId),
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
