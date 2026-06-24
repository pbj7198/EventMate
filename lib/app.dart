// Root application widget and top-level shell wiring.
import 'package:flutter/material.dart';

import 'theme.dart';
import 'ui/shell_page.dart';

class InyeonApp extends StatelessWidget {
  const InyeonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '인연장부',
      debugShowCheckedModeBanner: false,
      theme: buildInyeonTheme(),
      home: const ShellPage(),
    );
  }
}
