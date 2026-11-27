import 'package:flutter/material.dart';

import '../../../core/contracts/domain_enums.dart';

/// Chuyển đổi mã trạng thái bàn giao sang nhãn tiếng Việt.
String handoverStatusLabelVi(HandoverStatus status) {
  switch (status) {
    case HandoverStatus.pending:
      return 'Chờ nộp minh chứng';
    case HandoverStatus.awaitingReceiverConfirmation:
      return 'Chờ bên nhận xác nhận';
    case HandoverStatus.confirmed:
      return 'Đã xác nhận nhận sách';
    case HandoverStatus.disputed:
      return 'Đã từ chối / Khiếu nại';
  }
}

/// Màu sắc nhận diện trạng thái bàn giao.
Color handoverStatusColor(HandoverStatus status) {
  switch (status) {
    case HandoverStatus.pending:
      return const Color(0xFFD97706); // Warning amber
    case HandoverStatus.awaitingReceiverConfirmation:
      return const Color(0xFF2563EB); // Primary/info blue
    case HandoverStatus.confirmed:
      return const Color(0xFF16A34A); // Success green
    case HandoverStatus.disputed:
      return const Color(0xFFDC2626); // Error red
  }
}
