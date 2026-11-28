import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../support/workflow_rpc_fixture.dart';

/// Bảng `notifications` giả CÓ TRẠNG THÁI cho test repository Supabase.
/// Hiểu đúng phần PostgREST mà repository dùng: lọc eq/is/not.is/in, sắp xếp
/// created_at,id và offset/limit. PATCH ghi vào "DB" trước, sau đó
/// [onAfterWrite] có thể ném lỗi để mô phỏng DB đã ghi nhưng client mất ACK.
class NotificationDbFixture {
  NotificationDbFixture();

  final Map<String, Map<String, dynamic>> rows = {};
  int _seq = 0;

  /// Gọi sau khi PATCH đã áp dụng; ném lỗi để giả mất ACK.
  void Function(http.Request request, int patchNumber)? onAfterWrite;

  /// Gọi trước khi PATCH áp dụng; ném lỗi để giả request không tới server.
  void Function(http.Request request, int patchNumber)? onBeforeWrite;

  int patches = 0;

  String add({String recipient = workflowActorA, bool read = false}) {
    _seq++;
    final id =
        '0b9a2f3e-2222-4c2d-9e8f-${_seq.toString().padLeft(12, '0')}';
    rows[id] = {
      'id': id,
      'recipient_id': recipient,
      'type': 'PAYMENT_REPORTED',
      'entity_type': 'TRANSACTION',
      'entity_id': 'a5100000-0000-4000-8000-0000000000aa',
      'preview_safe': 'Thông báo #$_seq',
      // Mỗi dòng sau mới hơn dòng trước một phút.
      'created_at': DateTime.utc(2026, 11, 25)
          .add(Duration(minutes: _seq))
          .toIso8601String(),
      'read_at': read ? '2026-11-25T00:00:00Z' : null,
    };
    return id;
  }

  bool isRead(String id) => rows[id]!['read_at'] != null;

  List<String> get unreadIds => [
    for (final row in rows.values)
      if (row['read_at'] == null) row['id'] as String,
  ];

  FutureOr<http.Response> handle(http.Request request) {
    final query = request.url.queryParameters;
    var matched = rows.values.where((row) => _matches(row, query)).toList();
    if (request.method == 'PATCH') {
      final number = ++patches;
      onBeforeWrite?.call(request, number);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      for (final row in matched) {
        if (body['read_at'] == 'now') row['read_at'] = '2026-11-25T12:00:00Z';
      }
      onAfterWrite?.call(request, number);
      return workflowResponse([for (final row in matched) _select(row, query)]);
    }
    matched.sort((a, b) {
      final byTime =
          (b['created_at'] as String).compareTo(a['created_at'] as String);
      final ascending = (query['order'] ?? '').startsWith('created_at.asc');
      return ascending ? -byTime : byTime;
    });
    final offset = int.tryParse(query['offset'] ?? '') ?? 0;
    final limit = int.tryParse(query['limit'] ?? '');
    matched = matched.skip(offset).toList();
    if (limit != null) matched = matched.take(limit).toList();
    return workflowResponse([for (final row in matched) _select(row, query)]);
  }

  static bool _matches(Map<String, dynamic> row, Map<String, String> query) {
    for (final MapEntry(:key, :value) in query.entries) {
      if (const {'select', 'order', 'offset', 'limit'}.contains(key)) continue;
      final cell = row[key];
      if (value == 'is.null') {
        if (cell != null) return false;
      } else if (value == 'not.is.null') {
        if (cell == null) return false;
      } else if (value.startsWith('eq.')) {
        if (cell != value.substring(3)) return false;
      } else if (value.startsWith('in.(')) {
        final ids = value
            .substring(4, value.length - 1)
            .split(',')
            .map((v) => v.replaceAll('"', ''))
            .toSet();
        if (!ids.contains(cell)) return false;
      } else {
        throw StateError('Bộ lọc chưa hỗ trợ: $key=$value');
      }
    }
    return true;
  }

  static Map<String, dynamic> _select(
    Map<String, dynamic> row,
    Map<String, String> query,
  ) {
    final columns = (query['select'] ?? '*').split(',');
    if (columns.contains('*')) return Map.of(row);
    return {for (final column in columns) column: row[column]};
  }
}
