// Relationship list with search and person-level navigation.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/inyeon_controller.dart';
import 'common_widgets.dart';
import 'person_detail_page.dart';

class PeoplePage extends ConsumerStatefulWidget {
  const PeoplePage({super.key});

  @override
  ConsumerState<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends ConsumerState<PeoplePage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inyeonControllerProvider);
    final people = state.people.where((person) {
      if (_query.trim().isEmpty) {
        return true;
      }
      final q = _query.toLowerCase();
      return person.name.toLowerCase().contains(q) ||
          person.relationship.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: '이름 또는 관계로 검색',
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 16),
        const SectionHeader(title: '인연 목록'),
        if (people.isEmpty)
          const EmptyStateCard(message: '아직 기록된 인연이 없어요')
        else
          ...people.map(
            (person) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                leading: CircleAvatar(
                  child: Text(
                    person.name.isNotEmpty ? person.name.substring(0, 1) : '?',
                  ),
                ),
                title: Text(person.name),
                subtitle: Text(person.relationship),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PersonDetailPage(personId: person.id),
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
