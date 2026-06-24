// Ledger page that focuses on searchable relationship browsing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../state/inyeon_controller.dart';
import '../utils/formatters.dart';
import '../utils/record_summaries.dart';
import 'common_widgets.dart';
import 'person_detail_page.dart';

class LedgerPage extends ConsumerStatefulWidget {
  const LedgerPage({super.key});

  @override
  ConsumerState<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends ConsumerState<LedgerPage> {
  String _query = '';

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
          item.lastEventType.label.toLowerCase().contains(q);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text(
          '이름이나 관계를 검색해서 인연 장부를 바로 찾아보세요.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: '이름, 관계, 행사 종류 검색',
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 16),
        const SectionHeader(title: '인연 장부'),
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
                  '${summary.relationship} · 최근 ${formatDate(summary.lastRecordDate)} · ${summary.lastEventType.label}',
                ),
                trailing: Text(
                  '${summary.recordCount}건',
                  style: const TextStyle(fontWeight: FontWeight.w700),
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
