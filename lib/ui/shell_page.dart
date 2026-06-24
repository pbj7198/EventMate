// Bottom navigation shell that hosts the three main top-level tabs.
import 'package:flutter/material.dart';

import 'home_page.dart';
import 'people_page.dart';
import 'record_form_page.dart';
import 'stats_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _index = 0;

  void _openAddRecord() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RecordFormPage()));
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(onAddRecord: _openAddRecord),
      PeoplePage(onAddRecord: _openAddRecord),
      const StatsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('인연장부'),
        actions: [
          IconButton(
            tooltip: '기록 추가',
            onPressed: _openAddRecord,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddRecord,
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('빠른 기록'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            selectedIcon: Icon(Icons.people_alt),
            label: '인연',
          ),
          NavigationDestination(
            icon: Icon(Icons.query_stats_outlined),
            selectedIcon: Icon(Icons.query_stats),
            label: '통계',
          ),
        ],
      ),
    );
  }
}
