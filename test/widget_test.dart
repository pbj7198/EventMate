import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:inyeon_jangbu/app.dart';
import 'package:inyeon_jangbu/data/seed_data.dart';
import 'package:inyeon_jangbu/models/app_snapshot.dart';
import 'package:inyeon_jangbu/repositories/inyeon_repository.dart';
import 'package:inyeon_jangbu/state/inyeon_controller.dart';

class MemoryRepository implements InyeonRepository {
  MemoryRepository(this._snapshot);

  AppSnapshot _snapshot;

  @override
  Future<AppSnapshot> load() async => _snapshot;

  @override
  Future<void> save(AppSnapshot snapshot) async {
    _snapshot = snapshot;
  }
}

void main() {
  testWidgets('home renders seeded data', (tester) async {
    final repository = MemoryRepository(createSeedSnapshot());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repository)],
        child: const InyeonApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('인연장부'), findsOneWidget);
    expect(find.text('이번 달 인연 흐름을 간단히 확인하세요.'), findsOneWidget);
    expect(find.text('장부'), findsOneWidget);
  });
}
