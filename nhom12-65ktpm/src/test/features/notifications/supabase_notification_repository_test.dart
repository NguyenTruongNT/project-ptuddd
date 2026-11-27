import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:studyshare/core/auth/auth_session_providers.dart';
import 'package:studyshare/core/backend/workflow_rpc.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/models/notification_item.dart';
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/core/mock/mock_notification_query_repository.dart';
import 'package:studyshare/features/notifications/data/mock_notification_repository.dart';
import 'package:studyshare/features/notifications/data/supabase_notification_repository.dart';
import 'package:studyshare/features/notifications/providers/notification_providers.dart';

import '../../support/workflow_rpc_fixture.dart';

const _noticeId = '0b9a2f3e-1111-4c2d-9e8f-000000000001';

Map<String, dynamic> _row({String? readAt, String entityType = 'TRANSACTION'}) => {
  'id': _noticeId,
  'recipient_id': workflowActorA,
  'type': 'PAYMENT_REPORTED',
  'entity_type': entityType,
  'entity_id': 'a5100000-0000-4000-8000-0000000000aa',
  'preview_safe': 'Sách kiểm tra: B báo đã chuyển khoản.',
  'created_at': '2026-11-25T03:00:00.123456+00:00',
  'read_at': readAt,
};

Future<(WorkflowTestBackend, WorkflowRpc)> _backend() async {
  final backend = WorkflowTestBackend()..allowedTables.add('notifications');
  await backend.login();
  addTearDown(backend.dispose);
  return (backend, WorkflowRpc(backend.client, workflowActorA));
}

void main() {
  test('Đọc hộp thư: lọc theo người nhận, mới nhất trước, giải mã DTO', () async {
    final (backend, rpc) = await _backend();
    backend.onRpc = (_) => workflowResponse([
      _row(),
      _row(readAt: '2026-11-25T04:00:00+00:00', entityType: 'SOMETHING_NEW'),
    ]);

    final items =
        await SupabaseNotificationQueryRepository(rpc).getMyNotifications();

    final request = backend.requests.single;
    expect(request.method, 'GET');
    expect(request.url.path, '/rest/v1/notifications');
    final query = request.url.queryParameters;
    expect(query['recipient_id'], 'eq.$workflowActorA');
    expect(query['order'], startsWith('created_at.desc'));
    expect(query['order'], contains(',id.desc'));
    expect(query['limit'], '$notificationFetchLimit');
    expect(request.headers['Authorization'], startsWith('Bearer '));

    expect(items.first.type, 'PAYMENT_REPORTED');
    expect(items.first.entityType, NotificationEntityType.transaction);
    expect(items.first.createdAt, DateTime.utc(2026, 11, 25, 3, 0, 0, 123, 456));
    expect(items.first.isRead, isFalse);
    // Loại tài nguyên mới chưa biết vẫn hiển thị được.
    expect(items.last.entityType, NotificationEntityType.unknown);
    expect(items.last.readAt, DateTime.utc(2026, 11, 25, 4));
  });

  test('Dữ liệu sai hợp đồng không bị biến thành hộp thư rỗng', () async {
    final (backend, rpc) = await _backend();
    backend.onRpc = (_) => workflowResponse([
      {..._row(), 'created_at': '2026-11-25T03:00:00'},
    ]);
    await expectLater(
      SupabaseNotificationQueryRepository(rpc).getMyNotifications(),
      throwsA(isA<AppError>()),
    );
  });

  test('Đánh dấu đã đọc chỉ gửi read_at theo giờ server, kèm điều kiện chưa đọc', () async {
    final (backend, rpc) = await _backend();
    backend.onRpc = (_) =>
        workflowResponse([_row(readAt: '2026-11-25T05:00:00+00:00')]);

    final result = await SupabaseNotificationRepository(rpc)
        .markRead(_noticeId, idempotencyKey: 'k1');

    expect(result, isA<CommandOk<AppNotification>>());
    expect((result as CommandOk<AppNotification>).data.isRead, isTrue);
    final request = backend.requests.single;
    expect(request.method, 'PATCH');
    expect(jsonDecode(request.body), {'read_at': 'now'});
    final query = request.url.queryParameters;
    expect(query['id'], 'eq.$_noticeId');
    expect(query['recipient_id'], 'eq.$workflowActorA');
    expect(query['read_at'], 'is.null');
  });

  test('Đã đọc từ trước: đọc lại bản ghi, không ghi đè mốc cũ', () async {
    final (backend, rpc) = await _backend();
    backend.onRpc = (request) => request.method == 'PATCH'
        ? workflowResponse([])
        : workflowResponse([_row(readAt: '2026-11-25T04:00:00+00:00')]);

    final result = await SupabaseNotificationRepository(rpc)
        .markRead(_noticeId, idempotencyKey: 'k1');

    expect((result as CommandOk<AppNotification>).data.readAt,
        DateTime.utc(2026, 11, 25, 4));
    expect(backend.requests.map((r) => r.method), ['PATCH', 'GET']);
  });

  test('Không có quyền và ID sai định dạng trả cùng một lỗi chung', () async {
    final (backend, rpc) = await _backend();
    backend.onRpc = (_) => workflowResponse([]);
    final repo = SupabaseNotificationRepository(rpc);

    final hidden = await repo.markRead(_noticeId, idempotencyKey: 'k1');
    final requestsAfterHidden = backend.requests.length;
    final malformed = await repo.markRead('notice-a-01', idempotencyKey: 'k2');

    for (final result in [hidden, malformed]) {
      final error = result as CommandError<AppNotification>;
      expect(error.code, DomainErrorCode.forbidden);
      expect(error.safeMessage, notificationUnavailableMessage);
    }
    // ID sai định dạng bị chặn ở client, không gửi request.
    expect(backend.requests.length, requestsAfterHidden);
  });

  test('Mất mạng khi ghi: chưa rõ kết quả, không coi là thành công', () async {
    final (backend, rpc) = await _backend();
    backend.onRpc = (_) => throw http.ClientException('offline');

    final result = await SupabaseNotificationRepository(rpc)
        .markAllRead(idempotencyKey: 'k1');

    expect((result as CommandError<int>).code, DomainErrorCode.timeoutUnknown);
  });

  test('Đánh dấu tất cả trả số dòng server đã đổi', () async {
    final (backend, rpc) = await _backend();
    backend.onRpc = (_) => workflowResponse([
      {'id': _noticeId},
      {'id': '0b9a2f3e-1111-4c2d-9e8f-000000000002'},
    ]);

    final result = await SupabaseNotificationRepository(rpc)
        .markAllRead(idempotencyKey: 'k1');

    expect((result as CommandOk<int>).data, 2);
    final query = backend.requests.single.url.queryParameters;
    expect(query['recipient_id'], 'eq.$workflowActorA');
    expect(query['read_at'], 'is.null');
  });

  group('Provider chọn nguồn dữ liệu', () {
    test('Demo tường minh dùng mock chung store', () async {
      final c = ProviderContainer(overrides: [
        sessionBoundaryProvider.overrideWithValue('demo'),
        supabaseClientProvider.overrideWithValue(null),
      ]);
      addTearDown(c.dispose);
      expect(c.read(notificationQueryRepositoryProvider),
          isA<MockNotificationQueryRepository>());
      expect(c.read(notificationRepositoryProvider),
          isA<MockNotificationRepository>());
      // Demo xem bằng A: có một thông báo chưa đọc từ fixture.
      await c.read(myNotificationsProvider.future);
      expect(c.read(unreadNotificationCountProvider), 1);
    });

    test('Phiên thật đọc bảng notifications qua Supabase', () async {
      final (backend, _) = await _backend();
      backend.onRpc = (_) => workflowResponse([_row()]);
      final c = ProviderContainer(overrides: [
        sessionBoundaryProvider.overrideWithValue(workflowActorA),
        supabaseClientProvider.overrideWithValue(backend.client),
      ]);
      addTearDown(c.dispose);
      expect(c.read(notificationQueryRepositoryProvider),
          isA<SupabaseNotificationQueryRepository>());
      expect(c.read(notificationRepositoryProvider),
          isA<SupabaseNotificationRepository>());
      expect((await c.read(myNotificationsProvider.future)).single.id, _noticeId);
      expect(c.read(unreadNotificationCountProvider), 1);
    });

    test('Chưa đăng nhập: lỗi phiên, không rơi về mock', () async {
      final c = ProviderContainer(overrides: [
        sessionBoundaryProvider.overrideWithValue(''),
        supabaseClientProvider.overrideWithValue(null),
      ]);
      addTearDown(c.dispose);
      await expectLater(
        c.read(myNotificationsProvider.future),
        // Riverpod bọc lỗi trong ProviderException; mã lỗi gốc vẫn giữ nguyên.
        throwsA(predicate<Object>(
          (e) => e.toString().contains('AUTH_REQUIRED'),
          'requires authentication',
        )),
      );
      expect(c.read(unreadNotificationCountProvider), isNull);
    });
  });
}
