import '../errors/app_error.dart';

// Thành công của command phải kèm ACK từ server; không tự tạo ACK ở UI.
sealed class CommandResult<T> {
  const CommandResult();
}

final class CommandOk<T> extends CommandResult<T> {
  const CommandOk(this.data, this.serverEventId)
    : commandId = null,
      serverRevision = null;

  // Material chưa có Transaction: ACK dùng receipt, không tạo event giả.
  const CommandOk.receipt(
    this.data, {
    required this.commandId,
    required this.serverRevision,
  }) : serverEventId = null;

  final T data;
  final String? serverEventId;
  final String? commandId;
  final int? serverRevision;
}

final class CommandError<T> extends CommandResult<T> {
  const CommandError(this.code, this.safeMessage);

  final DomainErrorCode code;
  final String safeMessage;
}
