import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/contracts/command_result.dart';
import '../../../core/errors/app_error.dart';

// Gọi một RPC Supabase theo tên + tham số có tên; test thay bằng hàm giả.
typedef RpcInvoker = Future<Object?> Function(
  String function,
  Map<String, dynamic> params,
);

/// Cổng gọi RPC dùng chung cho Transaction, Payment và Issue.
///
/// - Actor luôn do server lấy từ `auth.uid()`; client không gửi actorId.
/// - Lệnh ghi trả phong bì `{ok, data, event_id}` hoặc `{ok:false, code, message}`.
/// - Mất mạng/timeout của lệnh ghi KHÔNG được coi là thành công: trả
///   `TIMEOUT_UNKNOWN` để UI giữ idempotency key và retry.
/// - Kết quả về sau khi phiên đã đổi người dùng bị bỏ, không hiển thị chéo.
class SupabaseRpcGateway {
  SupabaseRpcGateway({
    required this._invoke,
    required this._sessionValid,
    this.queryTimeout = const Duration(seconds: 20),
    this.commandTimeout = const Duration(seconds: 25),
  });

  factory SupabaseRpcGateway.fromClient(SupabaseClient client, String actor) =>
      SupabaseRpcGateway(
        invoke: (function, params) => client.rpc(function, params: params),
        sessionValid: () =>
            actor.isNotEmpty && client.auth.currentUser?.id == actor,
      );

  final RpcInvoker _invoke;
  final bool Function() _sessionValid;
  final Duration queryTimeout;
  final Duration commandTimeout;

  static const _unknownResultMessage =
      'Chưa rõ kết quả. Đang tải lại trạng thái từ máy chủ.';

  void _requireSession() {
    if (!_sessionValid()) {
      throw const AppError(DomainErrorCode.authRequired, '');
    }
  }

  /// Truy vấn đọc. Lỗi được đổi thành [AppError] an toàn, không lộ payload.
  Future<T> query<T>(
    String function,
    Map<String, dynamic> params,
    T Function(Object? raw) parse,
  ) async {
    _requireSession();
    final Object? raw;
    try {
      raw = await _invoke(function, params).timeout(queryTimeout);
    } on AppError {
      rethrow;
    } catch (e) {
      throw AppError(_transportCode(e), '');
    }
    _requireSession();
    try {
      return parse(raw);
    } on AppError {
      rethrow;
    } catch (_) {
      // Server trả dữ liệu lạ: báo lỗi an toàn thay vì hiển thị sai trạng thái.
      throw const AppError(DomainErrorCode.conflict, '');
    }
  }

  /// Lệnh ghi. Thành công chỉ khi server trả `ok: true` kèm `event_id`.
  Future<CommandResult<T>> command<T>(
    String function,
    Map<String, dynamic> params,
    T Function(Map<String, dynamic> data) parse,
  ) async {
    try {
      _requireSession();
    } on AppError catch (e) {
      return CommandError(e.code, _fallbackMessage(e.code));
    }
    final Object? raw;
    try {
      raw = await _invoke(function, params).timeout(commandTimeout);
    } on PostgrestException catch (e) {
      final code = _postgrestCode(e);
      return CommandError(code, _fallbackMessage(code));
    } catch (_) {
      // Không biết server đã ghi hay chưa: giữ key để retry, không báo thành công.
      return const CommandError(
        DomainErrorCode.timeoutUnknown,
        _unknownResultMessage,
      );
    }
    if (!_sessionValid()) {
      return CommandError(
        DomainErrorCode.authRequired,
        _fallbackMessage(DomainErrorCode.authRequired),
      );
    }
    try {
      final envelope = asJsonMap(raw);
      if (envelope['ok'] != true) {
        final code = DomainErrorCode.fromWire(
          envelope['code'] as String? ?? '',
        );
        final message = envelope['message'];
        return CommandError(
          code,
          message is String && message.trim().isNotEmpty
              ? message
              : _fallbackMessage(code),
        );
      }
      final eventId = envelope['event_id'] as String?;
      if (eventId == null || eventId.isEmpty) {
        // Thiếu ACK từ server thì không được coi là thành công.
        return const CommandError(
          DomainErrorCode.timeoutUnknown,
          _unknownResultMessage,
        );
      }
      return CommandOk(parse(asJsonMap(envelope['data'])), eventId);
    } catch (_) {
      // Server có thể đã ghi nhưng phản hồi không đọc được: tải lại để đối chiếu.
      return const CommandError(
        DomainErrorCode.timeoutUnknown,
        _unknownResultMessage,
      );
    }
  }

  static DomainErrorCode _transportCode(Object e) {
    if (e is PostgrestException) return _postgrestCode(e);
    return DomainErrorCode.networkUnavailable;
  }

  static DomainErrorCode _postgrestCode(PostgrestException e) {
    for (final code in DomainErrorCode.values) {
      if (e.message == code.wire || e.code == code.wire) return code;
    }
    // JWT hết hạn/không hợp lệ: yêu cầu đăng nhập lại.
    if (e.code == 'PGRST301' || e.code == 'PGRST302') {
      return DomainErrorCode.authRequired;
    }
    return DomainErrorCode.forbidden;
  }

  static String _fallbackMessage(DomainErrorCode code) => switch (code) {
    DomainErrorCode.authRequired =>
      'Phiên đăng nhập đã hết. Hãy đăng nhập lại.',
    DomainErrorCode.forbidden => 'Bạn không có quyền thực hiện thao tác này.',
    DomainErrorCode.networkUnavailable => 'Không có kết nối mạng. Hãy thử lại.',
    DomainErrorCode.timeoutUnknown => _unknownResultMessage,
    _ => 'Không thể thực hiện thao tác. Đang tải lại trạng thái từ máy chủ.',
  };
}

// ---------- Tiện ích đọc JSON từ RPC ----------

Map<String, dynamic> asJsonMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  throw const FormatException('RPC không trả object JSON.');
}

List<Map<String, dynamic>> asJsonList(Object? raw) {
  if (raw == null) return const [];
  if (raw is! List) throw const FormatException('RPC không trả mảng JSON.');
  return [for (final item in raw) asJsonMap(item)];
}

DateTime parseServerTime(Object? raw) => DateTime.parse(raw as String).toUtc();

DateTime? parseOptionalServerTime(Object? raw) =>
    raw == null ? null : parseServerTime(raw);

int? parseOptionalInt(Object? raw) => raw == null ? null : (raw as num).toInt();

/// Bỏ qua mã hành động lạ: server có thể bổ sung gợi ý mới, UI cũ không vỡ.
Set<T> parseAllowedActions<T>(Object? raw, T Function(String wire) fromWire) {
  final result = <T>{};
  for (final item in (raw as List?) ?? const []) {
    try {
      result.add(fromWire(item as String));
    } on FormatException {
      continue;
    }
  }
  return Set.unmodifiable(result);
}
