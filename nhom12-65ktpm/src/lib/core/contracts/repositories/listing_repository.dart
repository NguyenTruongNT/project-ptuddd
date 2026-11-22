import '../command_inputs.dart';
import '../command_result.dart';
import '../models/listing.dart';

abstract interface class ListingQueryRepository {
  // Listing PUBLISHED có Material RESERVED vẫn hiện, nhưng isRequestable=false.
  Future<List<ListingCardModel>> searchPublished({String keyword = ''});
  Future<ListingCardModel?> getPublishedCard(String listingId);
}

abstract interface class ListingRepository {
  Future<CommandResult<Listing>> createListing(
    CreateListingInput input, {required String idempotencyKey});
  Future<CommandResult<Listing>> publishListing(
    String listingId, {required String idempotencyKey});
}
