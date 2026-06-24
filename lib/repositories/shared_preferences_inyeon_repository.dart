// SharedPreferences-backed repository for the MVP's local persistence.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/seed_data.dart';
import '../models/app_snapshot.dart';
import '../models/occasion_record.dart';
import '../models/person.dart';
import 'inyeon_repository.dart';

class SharedPreferencesInyeonRepository implements InyeonRepository {
  SharedPreferencesInyeonRepository({this._preferences});

  static const _peopleKey = 'inyeon.people';
  static const _recordsKey = 'inyeon.records';

  final SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    return _preferences ?? SharedPreferences.getInstance();
  }

  @override
  Future<AppSnapshot> load() async {
    final prefs = await _prefs();
    final peopleJson = prefs.getString(_peopleKey);
    final recordsJson = prefs.getString(_recordsKey);

    if (peopleJson == null || recordsJson == null) {
      final seed = createSeedSnapshot();
      await save(seed);
      return seed;
    }

    final people = (jsonDecode(peopleJson) as List<dynamic>)
        .map((item) => Person.fromMap(item as Map<String, dynamic>))
        .toList();
    final records = (jsonDecode(recordsJson) as List<dynamic>)
        .map((item) => OccasionRecord.fromMap(item as Map<String, dynamic>))
        .toList();

    if (people.isEmpty && records.isEmpty) {
      final seed = createSeedSnapshot();
      await save(seed);
      return seed;
    }

    return AppSnapshot(people: people, records: records);
  }

  @override
  Future<void> save(AppSnapshot snapshot) async {
    final prefs = await _prefs();
    await prefs.setString(
      _peopleKey,
      jsonEncode(snapshot.people.map((person) => person.toMap()).toList()),
    );
    await prefs.setString(
      _recordsKey,
      jsonEncode(snapshot.records.map((record) => record.toMap()).toList()),
    );
  }
}
