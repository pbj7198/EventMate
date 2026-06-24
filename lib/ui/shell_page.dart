// Bottom navigation shell that keeps the app focused on summary, ledger, and stats.
import 'package:flutter/material.dart';

import 'home_page.dart';
import 'ledger_page.dart';
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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RecordFormPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(onAddRecord: _openAddRecord),
      LedgerPage(onAddRecord: _openAddRecord),
      const StatsPage(),
    ];

    final titles = ['인연장부', '장부', '통계'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
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
        label: const Text('기록 추가'),
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
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: '장부',
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
