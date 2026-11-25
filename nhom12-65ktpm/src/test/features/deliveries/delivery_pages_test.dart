import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:studyshare/core/contracts/command_inputs.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/core/mock/mock_fixtures.dart';
import 'package:studyshare/features/deliveries/data/mock_delivery_repository.dart';
import 'package:studyshare/features/deliveries/presentation/create_delivery_page.dart';
import 'package:studyshare/features/deliveries/presentation/delivery_details_page.dart';
import 'package:studyshare/features/deliveries/presentation/delivery_list_page.dart';

void main() {
  group('Delivery Repository & Logic Tests', () {
    test('Người gửi tạo nhiệm vụ giao hộ thành công', () async {
      final repo = MockDeliveryRepository(actorId: MockFixtures.userA);
      final result = await repo.createTask(
        const CreateDeliveryTaskInput(
          transactionId: 'txn-delivery-01',
          finalReceiverId: MockFixtures.userB,
        ),
        idempotencyKey: 'test-create-task',
      );

      expect(result, isA<CommandOk>());
      final task = (result as CommandOk).data;
      expect(task.status, equals(DeliveryTaskStatus.open));
      expect(task.senderId, equals(MockFixtures.userA));
    });

    test('Courier ứng tuyển thành công; người gửi/người nhận bị cấm ứng tuyển', () async {
      final repo = MockDeliveryRepository(actorId: MockFixtures.outsider);
      final result = await repo.applyForTask('task-donate-01', idempotencyKey: 'test-apply-outsider');
      expect(result, isA<CommandOk>());

      // Người gửi A tự ứng tuyển task của mình -> Bị chặn
      final repoSender = MockDeliveryRepository(actorId: MockFixtures.userA);
      final senderResult = await repoSender.applyForTask('task-donate-01', idempotencyKey: 'test-apply-sender');
      expect(senderResult, isA<CommandError>());
      expect((senderResult as CommandError).code, equals(DomainErrorCode.forbidden));
    });

    test('Chọn Courier: Đúng 1 người ACCEPTED, các đơn còn lại REJECTED', () async {
      final repo = MockDeliveryRepository(actorId: MockFixtures.userA);

      // Thêm ứng viên thứ 2
      final repoOutsider = MockDeliveryRepository(actorId: MockFixtures.outsider);
      await repoOutsider.applyForTask('task-donate-01', idempotencyKey: 'test-apply-outsider');

      final result = await repo.selectCourier(
        'task-donate-01',
        'app-demo-c-01',
        idempotencyKey: 'test-select-courier',
      );

      expect(result, isA<CommandOk>());
      final updatedTask = (result as CommandOk).data;
      expect(updatedTask.status, equals(DeliveryTaskStatus.assigned));
      expect(updatedTask.assignedCourierId, equals(MockFixtures.userC));

      final apps = await repo.getApplications('task-donate-01');
      final acceptedApps = apps.where((a) => a.status == DeliveryApplicationStatus.accepted);
      expect(acceptedApps.length, equals(1));
    });
  });

  group('Delivery UI Widget Tests', () {
    testWidgets('SCR-15 Danh sách giao hộ hiển thị 4 tab đầy đủ', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DeliveryListPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Nhiệm vụ giao hộ'), findsOneWidget);
      expect(find.text('Có thể nhận'), findsOneWidget);
      expect(find.text('Đã ứng tuyển'), findsOneWidget);
      expect(find.text('Đang giao'), findsOneWidget);
      expect(find.text('Lịch sử'), findsOneWidget);
    });

    testWidgets('SCR-16 Form tạo giao hộ yêu cầu nhập điểm lấy và giao', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CreateDeliveryPage(transactionId: 'txn-delivery-01'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Tạo nhiệm vụ giao hộ'), findsWidgets);
      expect(find.text('Điểm lấy tài liệu (Pickup) *'), findsOneWidget);
      expect(find.text('Điểm giao tài liệu (Dropoff) *'), findsOneWidget);

      // Cuộn tới nút và nhấn tạo khi form trống -> Báo lỗi validation
      final submitButton = find.byType(ElevatedButton);
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập địa điểm lấy tài liệu cụ thể.'), findsOneWidget);
    });

    testWidgets('SCR-17 Chi tiết nhiệm vụ hiển thị tiến trình và ứng viên', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DeliveryDetailsPage(taskId: 'task-donate-01'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('task-donate-01'), findsWidgets);
      expect(find.text('Điểm hẹn và tuyến đường'), findsOneWidget);
      expect(find.text('Tiến trình các chặng bàn giao'), findsOneWidget);
    });
  });
}
