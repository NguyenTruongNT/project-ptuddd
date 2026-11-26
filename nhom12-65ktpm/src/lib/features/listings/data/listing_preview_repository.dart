import '../../../core/contracts/command_inputs.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/listing_workspace.dart';
import '../../../core/contracts/models/listing.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/mock/mock_listing_query_repository.dart';
import '../../../core/mock/mock_fixtures.dart';

// Demo chỉ đọc, không tạo ACK hoặc giao dịch giả. Backend lỗi không vào đây.
class ListingPreviewRepository extends MockListingQueryRepository
    implements ListingWorkspaceRepository {
  const ListingPreviewRepository();
  @override
  Future<ManagedListing?> getManaged({
    String? listingId,
    String? materialId,
  }) async => null;
  @override
  Future<ListingPage<ManagedListing>> searchMine({
    String status = 'all',
    String query = '',
    int offset = 0,
    int limit = 20,
  }) async => const ListingPage([], hasMore: false);
  @override
  Future<CommandResult<ManagedListing>> execute(ListingCommand command) async =>
      const CommandError(DomainErrorCode.forbidden, 'Chế độ mô phỏng chỉ đọc.');
  @override
  Future<CommandResult<ManagedListing>?> getCommandResult(
    ListingCommand command,
  ) async => null;
  @override
  Future<ListingDetails?> getPublishedDetails(String listingId) async {
    final card = await getPublishedCard(listingId);
    if (card == null) return null;
    final m = MockFixtures.materials.firstWhere((m) => m.id == card.materialId);
    return ListingDetails(
      card: card,
      ownerId: m.ownerId,
      ownerName: 'Demo',
      materialDescription: m.description,
    );
  }

  @override
  Future<ListingPage<ListingCardModel>> searchPage({
    String keyword = '',
    int offset = 0,
    int limit = 20,
  }) async {
    final items = await searchPublished(keyword: keyword);
    return ListingPage(
      items.skip(offset).take(limit).toList(),
      hasMore: items.length > offset + limit,
    );
  }

  @override
  Future<CommandResult<Listing>> createListing(
    CreateListingInput input, {
    required String idempotencyKey,
  }) async =>
      const CommandError(DomainErrorCode.forbidden, 'Chế độ mô phỏng chỉ đọc.');
  @override
  Future<CommandResult<Listing>> publishListing(
    String listingId, {
    required String idempotencyKey,
  }) async =>
      const CommandError(DomainErrorCode.forbidden, 'Chế độ mô phỏng chỉ đọc.');
}
