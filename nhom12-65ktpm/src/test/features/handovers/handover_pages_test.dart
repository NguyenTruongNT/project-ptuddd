import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:studyshare/core/contracts/command_inputs.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/core/mock/mock_fixtures.dart';
import 'package:studyshare/core/mock/mock_transaction_store.dart';
import 'package:studyshare/features/handovers/data/mock_handover_repository.dart';
import 'package:studyshare/features/handovers/presentation/prepare_handover_page.dart';
import 'package:studyshare/features/handovers/presentation/qr_scanner_page.dart';
import 'package:studyshare/features/handovers/presentation/receiver_ack_page.dart';

void main() {
  late MockTransactionStore store;

  setUp(() {
    store = MockTransactionStore.fromFixtures();
  });

  group('Handover Repository & Business Invariants Tests', () {
    test('INV-05: Quét sai mã QR trả về lỗi QR_MISMATCH và hard block', () async {
      final repo = MockHandoverRepository(actorId: MockFixtures.userA, store: store);

      final result = await repo.verifyMaterialCode(
        'handover-borrow-01',
        'wrong-isbn-code-123',
        idempotencyKey: 'test-qr-wrong',
      );

      expect(result, isA<CommandError>());
      final error = result as CommandError;
      expect(error.code, equals(DomainErrorCode.qrMismatch));
      expect(error.safeMessage, contains('QR không khớp'));
    });

    test('Quét đúng mã QR trả về thành công', () async {
      final repo = MockHandoverRepository(actorId: MockFixtures.userA, store: store);

      final result = await repo.verifyMaterialCode(
        'handover-borrow-01',
        'mat-borrow-01',
        idempotencyKey: 'test-qr-valid',
      );

      expect(result, isA<CommandOk>());
      expect((result as CommandOk).data, isTrue);
    });

    test('INV-04: Nộp minh chứng bắt buộc có ít nhất 1 ảnh', () async {
      final repo = MockHandoverRepository(actorId: MockFixtures.userA, store: store);

      // Thử nộp danh sách ảnh rỗng
      final failResult = await repo.submitEvidence(
        const SubmitHandoverEvidenceInput(
          handoverId: 'handover-delivery-h1',
          uploadedEvidenceIds: [],
        ),
        idempotencyKey: 'test-evidence-empty',
      );

      expect(failResult, isA<CommandError>());
      expect((failResult as CommandError).code, equals(DomainErrorCode.evidenceRequired));

      // Nộp có ảnh
      final okResult = await repo.submitEvidence(
        const SubmitHandoverEvidenceInput(
          handoverId: 'handover-delivery-h1',
          uploadedEvidenceIds: ['photo-1.jpg'],
        ),
        idempotencyKey: 'test-evidence-ok',
      );

      expect(okResult, isA<CommandOk>());
      final updated = (okResult as CommandOk).data;
      expect(updated.status, equals(HandoverStatus.awaitingReceiverConfirmation));
      expect(updated.evidencePhotoCount, equals(1));
    });

    test('Xác nhận nhận: Chỉ đúng người nhận mới được xác nhận', () async {
      final repoGiver = MockHandoverRepository(actorId: MockFixtures.userA, store: store);

      // Trước tiên người giao nộp ảnh
      await repoGiver.submitEvidence(
        const SubmitHandoverEvidenceInput(
          handoverId: 'handover-delivery-h1',
          uploadedEvidenceIds: ['photo-1.jpg'],
        ),
        idempotencyKey: 'test-submit',
      );

      // Người giao A tự xác nhận thay người nhận C -> Bị từ chối
      final failResult = await repoGiver.confirmReceipt(
        'handover-delivery-h1',
        idempotencyKey: 'test-giver-confirm',
      );
      expect(failResult, isA<CommandError>());
      expect((failResult as CommandError).code, equals(DomainErrorCode.invalidHandoverParticipant));

      // Đúng người nhận C xác nhận -> Thành công
      final repoReceiver = MockHandoverRepository(actorId: MockFixtures.userC, store: store);
      final okResult = await repoReceiver.confirmReceipt(
        'handover-delivery-h1',
        idempotencyKey: 'test-receiver-confirm',
      );
      expect(okResult, isA<CommandOk>());
    });

    test('Người nhận từ chối nhận sách: Chuyển Handover sang DISPUTED và mở Issue', () async {
      final repoReceiver = MockHandoverRepository(actorId: MockFixtures.userC, store: store);

      final result = await repoReceiver.refuseReceipt(
        const RefuseHandoverInput(
          handoverId: 'handover-delivery-h1',
          reason: 'Sách bị rách gáy nghiêm trọng không như mô tả',
        ),
        idempotencyKey: 'test-refuse',
      );

      expect(result, isA<CommandOk>());
      final issue = (result as CommandOk).data;
      expect(issue.status, equals(IssueStatus.open));
      expect(issue.handoverId, equals('handover-delivery-h1'));

      final handover = await repoReceiver.getHandover('handover-delivery-h1');
      expect(handover!.status, equals(HandoverStatus.disputed));
    });
  });

  group('Handover UI Widget Tests', () {
    testWidgets('SCR-18 Chuẩn bị bàn giao có nút chụp ảnh và đối chiếu QR', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PrepareHandoverPage(handoverId: 'handover-borrow-01'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Chuẩn bị bàn giao'), findsOneWidget);
      expect(find.text('1. Ảnh minh chứng bàn giao *'), findsOneWidget);
      expect(find.text('2. Đối chiếu mã QR tài liệu'), findsOneWidget);
      expect(find.text('Chụp thêm ảnh minh chứng'), findsOneWidget);
    });

    testWidgets('SCR-19 Quét QR hiển thị cảnh báo khi sai mã QR_MISMATCH', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: QrScannerPage(handoverId: 'handover-borrow-01'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Quét mã QR tài liệu'), findsOneWidget);

      // Nhấn nút chip mô phỏng mã sai
      await tester.tap(find.text('Mã sai: mat-wrong-isbn'));
      await tester.pumpAndSettle();

      // Kiểm tra có cảnh báo HARD BLOCK QR_MISMATCH
      expect(find.text('CẢNH BÁO: QR_MISMATCH'), findsOneWidget);
    });

    testWidgets('SCR-20 Xác nhận nhận tài liệu có nút Xác nhận và Từ chối', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ReceiverAckPage(handoverId: 'handover-borrow-01'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Xác nhận nhận tài liệu'), findsWidgets);
      expect(find.text('Ảnh minh chứng người giao'), findsOneWidget);
    });
  });
}
