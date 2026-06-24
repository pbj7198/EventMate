// Bottom navigation shell that keeps the app focused on summary, ledger, and stats.
import 'package:flutter/material.dart';

import 'calendar_page.dart';
import 'home_page.dart';
import 'ledger_page.dart';
import 'record_form_page.dart';
import 'signature_sheet_scan_page.dart';
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

  void _openScanSheet() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SignatureSheetScanPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomePage(),
      const CalendarPage(),
      const LedgerPage(),
      const StatsPage(),
    ];

    final titles = ['홈', '달력', '장부', '통계'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: [
          IconButton(
            tooltip: '명단 스캔',
            onPressed: _openScanSheet,
            icon: const Icon(Icons.document_scanner_outlined),
          ),
          IconButton(
            tooltip: '기록 추가',
            onPressed: _openAddRecord,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
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
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '달력',
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
