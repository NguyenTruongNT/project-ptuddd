import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Trạng thái cục bộ của bản nháp ảnh minh chứng theo CONTRACTS.md §10.
/// Không phải trạng thái Domain trên server.
enum HandoverDraftUploadState {
  draftLocal('DRAFT_LOCAL'),
  queuedUpload('QUEUED_UPLOAD'),
  failedUpload('FAILED_UPLOAD'),
  syncedEvidence('SYNCED_EVIDENCE');

  const HandoverDraftUploadState(this.wire);
  final String wire;

  static HandoverDraftUploadState fromWire(String raw) {
    for (final v in values) {
      if (v.wire == raw) return v;
    }
    return HandoverDraftUploadState.draftLocal;
  }
}

class HandoverLocalDraft {
  const HandoverLocalDraft({
    required this.draftId,
    required this.ownerUserId,
    required this.handoverId,
    required this.localPhotoPaths,
    required this.uploadState,
    required this.lastUpdatedAt,
  });

  final String draftId;
  final String ownerUserId;
  final String handoverId;
  final List<String> localPhotoPaths;
  final HandoverDraftUploadState uploadState;
  final DateTime lastUpdatedAt;
}

/// Kho lưu nháp SQLite (sqflite) cho ảnh minh chứng khi mất mạng / chờ retry.
/// Ràng buộc chặt theo `owner_user_id` để đổi tài khoản không lộ nháp cũ.
class HandoverDraftStore {
  HandoverDraftStore._();
  static final HandoverDraftStore instance = HandoverDraftStore._();

  Database? _db;

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'studyshare_handover_drafts.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE handover_drafts (
            draft_id TEXT PRIMARY KEY,
            owner_user_id TEXT NOT NULL,
            handover_id TEXT NOT NULL,
            local_photo_paths TEXT NOT NULL,
            upload_state TEXT NOT NULL,
            last_updated_at TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Future<void> saveDraft({
    required String ownerUserId,
    required String handoverId,
    required List<String> localPhotoPaths,
    required HandoverDraftUploadState uploadState,
  }) async {
    final db = await _database();
    final draftId = '$ownerUserId|$handoverId';
    await db.insert(
      'handover_drafts',
      {
        'draft_id': draftId,
        'owner_user_id': ownerUserId,
        'handover_id': handoverId,
        'local_photo_paths': jsonEncode(localPhotoPaths),
        'upload_state': uploadState.wire,
        'last_updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<HandoverLocalDraft?> loadDraft({
    required String ownerUserId,
    required String handoverId,
  }) async {
    final db = await _database();
    final rows = await db.query(
      'handover_drafts',
      where: 'draft_id = ? AND owner_user_id = ?',
      whereArgs: ['$ownerUserId|$handoverId', ownerUserId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final paths = (jsonDecode(row['local_photo_paths'] as String) as List)
        .map((e) => e.toString())
        .toList();
    return HandoverLocalDraft(
      draftId: row['draft_id'] as String,
      ownerUserId: row['owner_user_id'] as String,
      handoverId: row['handover_id'] as String,
      localPhotoPaths: paths,
      uploadState: HandoverDraftUploadState.fromWire(row['upload_state'] as String),
      lastUpdatedAt: DateTime.parse(row['last_updated_at'] as String),
    );
  }

  Future<void> deleteDraft({
    required String ownerUserId,
    required String handoverId,
  }) async {
    final db = await _database();
    await db.delete(
      'handover_drafts',
      where: 'draft_id = ? AND owner_user_id = ?',
      whereArgs: ['$ownerUserId|$handoverId', ownerUserId],
    );
  }
}
