// Repository contract and persistence snapshot definition.
import '../models/app_snapshot.dart';

abstract class InyeonRepository {
  Future<AppSnapshot> load();
  Future<void> save(AppSnapshot snapshot);
}
