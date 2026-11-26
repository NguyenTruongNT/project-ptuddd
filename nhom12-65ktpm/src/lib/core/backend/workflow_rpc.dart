import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_session_providers.dart';
import '../contracts/command_result.dart';
import '../errors/app_error.dart';

// null chỉ dành cho demo được chọn tường minh, không phải fallback khi lỗi mạng.
final workflowRpcProvider = Provider<WorkflowRpc?>((ref) {
  final actor = ref.watch(sessionBoundaryProvider);
  final client = ref.watch(supabaseClientProvider);
  if (actor == 'demo' && client == null) return null;
  if (client == null || actor.isEmpty || actor == 'demo') {
    throw const AppError(
      DomainErrorCode.authRequired,
      'Vui lòng đăng nhập để tiếp tục.',
    );
  }
  return WorkflowRpc(client, actor);
});

/// Gọi RPC theo phiên đã tạo repository. Không truyền actor/trạng thái từ client.
class WorkflowRpc {
  WorkflowRpc(
    this.client,
    this.actor, {
    this.timeout = const Duration(seconds: 20),
  });

  final SupabaseClient client;
  final String actor;
  final Duration timeout;

  void _session() {
    if (actor.isEmpty ||
        client.auth.currentUser?.id != actor ||
        client.auth.currentSession == null) {
      throw const AppError(
        DomainErrorCode.authRequired,
        'Phiên đăng nhập đã thay đổi. Vui lòng đăng nhập lại.',
      );
    }
  }

  Future<Object?> _call(String name, Map<String, dynamic> params) async {
    _session();
    if (client.auth.currentSession!.isExpired) {
      await client.auth.refreshSession().timeout(timeout);
      _session();
    }
    // Cố định JWT của actor cho request này. Auth có thể đổi trong lúc HTTP
    // đang chờ; không để request bị gửi bằng JWT của tài khoản vừa đăng nhập.
    final token = client.auth.currentSession!.accessToken;
    try {
      final result = await client
          .rpc(name, params: params)
          .setHeader('Authorization', 'Bearer $token')
          .timeout(timeout);
      _session();
      return result;
    } on PostgrestException catch (error) {
      // Chỉ log tên RPC/mã lỗi ở debug, không log JWT, tham số hoặc payload riêng tư.
      if (kDebugMode) {
        debugPrint('StudyShare RPC $name: ${error.code ?? 'UNKNOWN'}');
      }
      rethrow;
    }
  }

  Future<T> read<T>(
    String name,
    Map<String, dynamic> params,
    T Function(Object?) decode,
  ) async {
    try {
      return decode(await _call(name, params));
    } catch (error) {
      _session();
      throw _error(error, command: false);
    }
  }

  Future<CommandResult<T>> command<T>(
    String name,
    Map<String, dynamic> params,
    T Function(Object?) decode, {
    String? validationMessage,
  }) async {
    try {
      _session();
      if (validationMessage != null) {
        return CommandError(DomainErrorCode.invalidInput, validationMessage);
      }
      final raw = await _call(name, params);
      if (raw is! Map<String, dynamic> || raw['ok'] is! bool) {
        throw const FormatException('Invalid command envelope');
      }
      if (raw['ok'] == false) {
        final code = DomainErrorCode.fromWire(raw['code'] as String? ?? '');
        return CommandError(code, workflowErrorMessage(code));
      }
      final eventId = raw['event_id'];
      if (eventId is! String || eventId.isEmpty || raw['data'] == null) {
        throw const FormatException('Missing server acknowledgement');
      }
      return CommandOk(decode(raw['data']), eventId);
    } catch (error) {
      final AppError safe;
      try {
        _session();
        safe = _error(error, command: true);
      } on AppError catch (sessionError) {
        return CommandError(sessionError.code, sessionError.safeMessage);
      }
      return CommandError(safe.code, safe.safeMessage);
    }
  }

  // ACK Listing chưa có TransactionEvent: dùng receipt server thật.
  Future<CommandResult<T>> receiptCommand<T>(
    String name,
    Map<String, dynamic> params,
    T Function(Object?) decode,
  ) async {
    try {
      final raw = await _call(name, params);
      if (raw is! Map<String, dynamic> ||
          raw['ok'] != true ||
          raw['command_id'] is! String ||
          raw['server_revision'] is! num ||
          raw['data'] == null) {
        throw const FormatException('Missing command receipt');
      }
      return CommandOk.receipt(
        decode(raw['data']),
        commandId: raw['command_id'] as String,
        serverRevision: (raw['server_revision'] as num).toInt(),
      );
    } catch (error) {
      try {
        _session();
      } on AppError catch (e) {
        return CommandError(e.code, e.safeMessage);
      }
      final safe = _error(error, command: true);
      return CommandError(safe.code, safe.safeMessage);
    }
  }

  AppError _error(Object error, {required bool command}) {
    if (error is AppError) return error;
    DomainErrorCode code;
    if (error is AuthException) {
      code = DomainErrorCode.authRequired;
    } else if (error is PostgrestException && error.code == 'P0001') {
      // SQL chỉ được trả mã nghiệp vụ đã chốt. Mã lạ dùng thông báo an toàn,
      // không suy diễn thành xung đột và không đưa message SQL thô lên UI.
      code = DomainErrorCode.fromWire(error.message);
    } else if (error is PostgrestException) {
      code = switch (error.code) {
        '42501' => DomainErrorCode.forbidden,
        'PGRST301' || 'PGRST302' || 'PGRST303' => DomainErrorCode.authRequired,
        // Thiếu hàm/bảng/cột hoặc chữ ký không khớp là lỗi triển khai backend,
        // không phải xung đột dữ liệu của người dùng; tải lại không tự sửa được.
        'PGRST200' ||
        'PGRST202' ||
        'PGRST203' ||
        'PGRST204' ||
        '42P01' ||
        '42703' ||
        '42883' => DomainErrorCode.backendUnavailable,
        '23505' || '40001' || '40P01' => DomainErrorCode.conflict,
        '22P02' ||
        '22023' ||
        '22003' ||
        '23514' ||
        '23502' => DomainErrorCode.invalidInput,
        '57014' =>
          command
              ? DomainErrorCode.timeoutUnknown
              : DomainErrorCode.networkUnavailable,
        _ => DomainErrorCode.unexpectedError,
      };
    } else if (error is TimeoutException || error is http.ClientException) {
      code = command
          ? DomainErrorCode.timeoutUnknown
          : DomainErrorCode.networkUnavailable;
    } else {
      // Sau khi đã gửi command mà ACK không đọc được, giữ key để đối soát lại.
      code = command
          ? DomainErrorCode.timeoutUnknown
          : DomainErrorCode.unexpectedError;
    }
    return AppError(code, workflowErrorMessage(code));
  }
}

String workflowErrorMessage(DomainErrorCode code) => switch (code) {
  DomainErrorCode.authRequired =>
    'Phiên đăng nhập đã hết hạn hoặc thay đổi. Vui lòng đăng nhập lại.',
  DomainErrorCode.forbidden => 'Bạn không có quyền thực hiện thao tác này.',
  DomainErrorCode.invalidInput =>
    'Thông tin chưa hợp lệ. Vui lòng kiểm tra lại.',
  DomainErrorCode.invalidTransactionTransition =>
    'Trạng thái đã thay đổi hoặc thao tác này không còn phù hợp. Hãy tải lại.',
  DomainErrorCode.issueBlockingAction =>
    'Giao dịch còn sự cố đang mở. Hãy giải quyết trước khi tiếp tục.',
  DomainErrorCode.cancellationObligationPending =>
    'Chưa thể hủy vì còn nghĩa vụ bàn giao, trả sách hoặc hoàn tiền.',
  DomainErrorCode.paymentNotConfirmed =>
    'Người bán chưa xác nhận nhận đủ tiền.',
  DomainErrorCode.networkUnavailable =>
    'Không thể tải dữ liệu. Kiểm tra kết nối và thử lại.',
  DomainErrorCode.backendUnavailable =>
    'Chức năng tạm thời chưa sẵn sàng. Vui lòng thử lại sau.',
  DomainErrorCode.unexpectedError =>
    'Không thể hoàn tất thao tác. Vui lòng thử lại sau.',
  DomainErrorCode.timeoutUnknown => 'Chưa rõ máy chủ đã ghi nhận hay chưa. Hãy thử lại cùng thao tác để đối soát, không gửi yêu cầu mới.',
  _ => 'Dữ liệu hoặc phương án đã thay đổi. Hãy tải lại và kiểm tra trước khi tiếp tục.',
};
