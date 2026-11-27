import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/auth/auth_session_providers.dart';
import 'package:studyshare/core/backend/workflow_rpc.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/mock/mock_fixtures.dart';
import 'package:studyshare/features/listings/data/listing_preview_repository.dart';
import 'package:studyshare/features/listings/providers/listing_providers.dart';

void main() {
  const repository = ListingPreviewRepository();

  test('SCR-06 đọc đủ dữ liệu công khai từ mock qua cùng read model', () async {
    final cards = await repository.searchPublished();
    expect(cards.map((c) => c.offerType).toSet(), OfferType.values.toSet());
    for (final card in cards) {
      final details = (await repository.getPublishedDetails(card.listingId))!;
      expect(details.card.condition, isNotEmpty);
      expect(details.ownerId, MockFixtures.userA);
      expect(details.ownerName, 'Bạn A (demo)');
      expect(details.materialDescription, isNotEmpty);
      expect(details.description, isNotEmpty);
      expect(details.meetingArea, isNotEmpty);
      expect(details.images.length, inInclusiveRange(1, 5));
      expect(
        details.images.map((i) => i.id).toSet().length,
        details.images.length,
      );
      expect(
        details.images.every((i) => i.url?.startsWith('https://') == true),
        isTrue,
      );
      expect(card.coverUrl, details.images.first.url);
      expect(details.card.coverUrl, card.coverUrl);
    }
  });

  test(
    'Chính sách BORROW kiểm tra biên 1–30 ngày; SELL/DONATE không có policy',
    () async {
      final borrow = (await repository.getPublishedDetails('list-borrow-01'))!;
      final policy = borrow.borrowPolicy!;
      expect(policy.requesterProposesDays, isTrue);
      expect(policy.ownerMustAcceptRequestedDays, isTrue);
      expect(policy.allowsExtension, isFalse);
      for (final days in [1, 7, 30]) {
        expect(policy.acceptsDays(days), isTrue);
      }
      for (final days in [null, -1, 0, 31]) {
        expect(policy.acceptsDays(days), isFalse);
      }
      for (final id in ['list-sell-01', 'list-donate-01']) {
        expect(
          (await repository.getPublishedDetails(id))!.borrowPolicy,
          isNull,
        );
      }
    },
  );

  test(
    'Mock khóa CTA theo owner, PENDING của viewer và giao dịch active',
    () async {
      const owner = ListingPreviewRepository(demoViewerId: MockFixtures.userA);
      const requester = ListingPreviewRepository(
        demoViewerId: MockFixtures.userB,
      );
      final own = (await owner.getPublishedDetails('list-donate-01'))!;
      expect(own.requestBlockedReason, 'OWNER');
      expect(own.card.isRequestable, isFalse);
      final pending = (await requester.getPublishedDetails('list-donate-01'))!;
      expect(pending.requestBlockedReason, 'REQUEST_PENDING');
      expect(pending.card.isRequestable, isFalse);
      final available = (await repository.getPublishedDetails(
        'list-donate-01',
      ))!;
      expect(available.requestBlockedReason, isEmpty);
      expect(available.card.isRequestable, isTrue);
      final reserved = (await repository.getPublishedDetails(
        'list-borrow-01',
      ))!;
      expect(reserved.requestBlockedReason, 'RESERVED');
      expect(reserved.card.isRequestable, isFalse);
    },
  );

  test('ID không có tin công khai trả null, không đọc nhầm Material', () async {
    expect(await repository.getPublishedDetails('not-found'), isNull);
    expect(await repository.getPublishedDetails('mat-sell-01'), isNull);
  });

  test(
    'Provider chi tiết loại trạng thái viewer cũ khi đổi tài khoản demo',
    () async {
      final container = ProviderContainer(
        overrides: [
          workflowRpcProvider.overrideWithValue(null),
          sessionBoundaryProvider.overrideWithValue(MockFixtures.userB),
        ],
      );
      addTearDown(container.dispose);
      final provider = listingDetailsProvider('list-donate-01');
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      expect(
        (await container.read(provider.future))!.requestBlockedReason,
        'REQUEST_PENDING',
      );

      container.updateOverrides([
        workflowRpcProvider.overrideWithValue(null),
        sessionBoundaryProvider.overrideWithValue(MockFixtures.userA),
      ]);
      expect(
        (await container.read(provider.future))!.requestBlockedReason,
        'OWNER',
      );
    },
  );
}
