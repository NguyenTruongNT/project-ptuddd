// Issue chỉ có OPEN/RESOLVED; xử lý tranh chấp thật cần các bên đồng thuận ở server.
import '../domain_enums.dart';

class Issue {
  const Issue({
    required this.id,
    required this.transactionId,
    required this.reporterId,
    required this.reason,
    required this.status,
    this.handoverId,
  });

  final String id;
  final String transactionId;
  final String reporterId;
  final String reason;
  final String? handoverId;
  final IssueStatus status;
}
