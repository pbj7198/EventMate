// Person detail page showing all linked records and relationship metadata.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../models/person.dart';
import '../state/inyeon_controller.dart';
import '../utils/formatters.dart';
import '../utils/record_summaries.dart';
import 'common_widgets.dart';
import 'record_form_page.dart';

class PersonDetailPage extends ConsumerWidget {
  const PersonDetailPage({super.key, required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(inyeonControllerProvider.notifier);
    final state = ref.watch(inyeonControllerProvider);
    final Person? person = controller.personById(personId);
    final records = controller.recordsForPerson(personId);

    if (person == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('인연 상세')),
        body: const Center(child: Text('인연 정보를 찾을 수 없어요')),
      );
    }

    final given = totalAmount(records, transactionType: TransactionType.given);
    final received = totalAmount(
      records,
      transactionType: TransactionType.received,
    );
    final givenCount = records
        .where((record) => record.transactionType == TransactionType.given)
        .length;
    final receivedCount = records
        .where((record) => record.transactionType == TransactionType.received)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('인연 상세')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Tag(person.relationship),
                    if ((person.phoneNumber ?? '').isNotEmpty)
                      _Tag(person.phoneNumber!),
                  ],
                ),
                if ((person.memo ?? '').isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(person.memo!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 170,
            children: [
              SummaryCard(
                title: '내가 준 금액',
                value: formatWon(given),
                icon: Icons.payments_outlined,
                subtitle: '$givenCount건',
              ),
              SummaryCard(
                title: '내가 받은 금액',
                value: formatWon(received),
                icon: Icons.savings_outlined,
                subtitle: '$receivedCount건',
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionHeader(
            title: '관련 경조사 기록',
            actionLabel: '기록 추가',
            onActionTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RecordFormPage(initialPersonId: person.id),
                ),
              );
            },
          ),
          if (records.isEmpty)
            const EmptyStateCard(message: '아직 이 인연과 연결된 기록이 없어요')
          else
            ...records.map(
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
                  onDelete: () async {
                    final ok = await _confirmDelete(context, record.personName);
                    if (ok == true) {
                      await controller.deleteRecord(record.id);
                    }
                  },
                ),
              ),
            ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              state.errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기록 삭제'),
        content: Text('$name의 기록을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }
}
