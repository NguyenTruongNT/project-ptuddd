import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

// Android: SQLite trong sandbox ứng dụng, ảnh được lưu cùng payload nháp.
// Web chỉ phục vụ preview; quota errors được trả về UI, không giả lưu thành công.
class MaterialDraftStore {
  Database? _database;
  Future<Database> _db() async => _database ??= await openDatabase(
    path.join(await getDatabasesPath(), 'studyshare_material_drafts.db'),
    version: 1,
    onCreate: (db, _) => db.execute(
      'CREATE TABLE drafts (draft_key TEXT PRIMARY KEY, payload TEXT NOT NULL)',
    ),
  );
  Future<Map<String, dynamic>?> read(String key) async {
    String? raw;
    if (kIsWeb) {
      raw = (await SharedPreferences.getInstance()).getString(
        'material-draft:$key',
      );
    } else {
      final rows = await (await _db()).query(
        'drafts',
        where: 'draft_key = ?',
        whereArgs: [key],
        limit: 1,
      );
      raw = rows.firstOrNull?['payload'] as String?;
    }
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> write(String key, Map<String, dynamic> value) async {
    final raw = jsonEncode(value);
    if (kIsWeb) {
      final ok = await (await SharedPreferences.getInstance()).setString(
        'material-draft:$key',
        raw,
      );
      if (!ok) throw StateError('DRAFT_WRITE_FAILED');
    } else {
      await (await _db()).insert('drafts', {
        'draft_key': key,
        'payload': raw,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> remove(String key) async {
    if (kIsWeb) {
      await (await SharedPreferences.getInstance()).remove(
        'material-draft:$key',
      );
    } else {
      await (await _db()).delete(
        'drafts',
        where: 'draft_key = ?',
        whereArgs: [key],
      );
    }
  }
}
