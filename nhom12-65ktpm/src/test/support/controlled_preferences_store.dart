import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ControlledPreferencesStore extends Fake implements SharedPreferences {
  final values = <String, Object>{};
  final writes = <({String value, Completer<bool> result})>[];

  @override
  String? getString(String key) => values[key] as String?;
  @override
  bool? getBool(String key) => values[key] as bool?;
  @override
  Future<bool> setString(String key, String value) async {
    final result = Completer<bool>();
    writes.add((value: value, result: result));
    final saved = await result.future;
    if (saved) values[key] = value;
    return saved;
  }
}
