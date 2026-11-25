import 'package:flutter/material.dart';

import '../../../core/contracts/domain_enums.dart';

/// Chuyển đổi mã trạng thái giao hộ sang nhãn tiếng Việt thân thiện.
String deliveryStatusLabelVi(DeliveryTaskStatus status) {
  switch (status) {
    case DeliveryTaskStatus.open:
      return 'Đang mở tìm người giao';
    case DeliveryTaskStatus.assigned:
      return 'Đã chọn người giao';
    case DeliveryTaskStatus.pickedUp:
      return 'Đã lấy tài liệu';
    case DeliveryTaskStatus.deliveryPendingConfirmation:
      return 'Chờ người nhận xác nhận';
    case DeliveryTaskStatus.completed:
      return 'Giao thành công';
    case DeliveryTaskStatus.failed:
      return 'Giao thất bại';
    case DeliveryTaskStatus.cancelled:
      return 'Đã hủy nhiệm vụ';
  }
}

/// Màu sắc nhận diện trạng thái giao hộ theo Semantic Token.
Color deliveryStatusColor(DeliveryTaskStatus status) {
  switch (status) {
    case DeliveryTaskStatus.open:
      return const Color(0xFF2563EB); // Info blue
    case DeliveryTaskStatus.assigned:
      return const Color(0xFFD97706); // Amber
    case DeliveryTaskStatus.pickedUp:
      return const Color(0xFF7C3AED); // Purple
    case DeliveryTaskStatus.deliveryPendingConfirmation:
      return const Color(0xFF0284C7); // Sky
    case DeliveryTaskStatus.completed:
      return const Color(0xFF16A34A); // Success green
    case DeliveryTaskStatus.failed:
    case DeliveryTaskStatus.cancelled:
      return const Color(0xFFDC2626); // Error red
  }
}

/// Các tab phân loại nhiệm vụ giao hộ tại màn hình SCR-15.
enum DeliveryTab {
  available, // Có thể nhận (OPEN)
  applied,   // Tôi đã ứng tuyển
  active,    // Đang thực hiện
  history,   // Lịch sử kết thúc
}

String deliveryTabLabelVi(DeliveryTab tab) {
  switch (tab) {
    case DeliveryTab.available:
      return 'Có thể nhận';
    case DeliveryTab.applied:
      return 'Đã ứng tuyển';
    case DeliveryTab.active:
      return 'Đang giao';
    case DeliveryTab.history:
      return 'Lịch sử';
  }
}
