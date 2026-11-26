import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studyshare/core/preferences/app_preferences.dart';
import 'package:studyshare/main.dart' as application;
import 'package:studyshare/core/backend/workflow_rpc.dart';
import 'package:studyshare/core/contracts/command_inputs.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/contracts/material_workspace.dart';
import 'package:studyshare/core/contracts/models/material.dart' as model;
import 'package:studyshare/features/materials/data/material_draft_store.dart';
import 'package:studyshare/features/materials/data/supabase_material_workspace.dart';
import 'package:studyshare/features/listings/data/supabase_listing_workspace.dart';
import 'package:studyshare/features/listings/presentation/listing_details_page.dart';
import 'package:studyshare/features/listings/presentation/listing_form_page.dart';
import 'package:studyshare/l10n/app_localizations.dart';

import '../test/support/material_image_fixtures.dart';

Future<void> visible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 30),
  );
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await visible(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 30),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android local: SQLite nháp, SELL công bố, ảnh, ẩn và hiện lại', (
    tester,
  ) async {
    const url = String.fromEnvironment('SUPABASE_URL');
    expect(url, 'http://127.0.0.1:54321');
    await application.main();
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final previousLeaves = container.read(appPreferencesProvider).showLeaves;
    final preferenceStore = container.read(preferencesStoreProvider)!;
    final previousPreferencesJson = preferenceStore.getString(
      'ui.preferences.v1',
    );
    addTearDown(() async {
      // Widget tree đã dispose ở teardown; khôi phục trực tiếp store đã giữ.
      if (previousPreferencesJson == null) {
        await preferenceStore.remove('ui.preferences.v1');
      } else {
        await preferenceStore.setString(
          'ui.preferences.v1',
          previousPreferencesJson,
        );
      }
    });
    await container.read(appPreferencesProvider.notifier).setLeaves(false);
    await tester.pumpAndSettle();
    final client = Supabase.instance.client;
    await client.auth.signOut();
    await client.auth.signInWithPassword(
      email: const String.fromEnvironment('LISTING_ANDROID_EMAIL'),
      password: const String.fromEnvironment('LISTING_ANDROID_PASSWORD'),
    );
    final actor = client.auth.currentUser!.id;
    final workspace = SupabaseMaterialWorkspace(client, actor);
    final photo = await workspace.uploadImage(
      MaterialPhoto(
        localId: const Uuid().v4(),
        name: 'cover.jpg',
        mimeType: 'image/jpeg',
        bytes: materialJpegFixture(),
      ),
    );
    final name = 'Android ngày 3 ${const Uuid().v4().substring(0, 8)}';
    final created = await workspace.createMaterial(
      CreateMaterialInput(
        title: name,
        subject: 'Toán',
        condition: 'Tốt',
        imageIds: [photo.id],
      ),
      idempotencyKey: const Uuid().v4(),
    );
    expect(created, isA<CommandOk<model.Material>>());
    final material = (created as CommandOk<model.Material>).data;
    await tester.pumpAndSettle();
    final t = AppLocalizations.of(tester.element(find.byType(NavigationBar)))!;
    await tap(tester, find.text(t.navPublish).last);
    await tap(tester, find.byKey(const ValueKey('listing-create')));
    await tap(tester, find.text(name));
    expect(find.byType(ListingFormPage), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('listing-offer-SELL')));
    await visible(tester, find.byKey(const ValueKey('listing-price')));
    await tester.enterText(
      find.byKey(const ValueKey('listing-price')),
      '100000',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tap(tester, find.text(t.listingLocal));
    final disk = await MaterialDraftStore().read('listing-drafts:$actor');
    expect((disk![material.id] as Map)['price'], '100000');
    await tap(tester, find.byKey(const ValueKey('listing-publish')));
    await tap(tester, find.byKey(const ValueKey('confirm-action')));
    expect(find.byType(ListingDetailsPage), findsOneWidget);
    final repo = SupabaseListingWorkspace(WorkflowRpc(client, actor));
    final listing = await repo.getManaged(materialId: material.id);
    expect(listing!.listing.status, ListingStatus.published);
    expect(
      (await repo.getPublishedDetails(listing.listing.id))!.images.single.url,
      isNotNull,
    );
    await tap(tester, find.text(t.listingManage));
    await tap(tester, find.text(t.listingHide));
    await tap(tester, find.byKey(const ValueKey('confirm-action')));
    expect(
      (await repo.getManaged(materialId: material.id))!.listing.status,
      ListingStatus.hidden,
    );
    expect(await repo.getPublishedDetails(listing.listing.id), isNull);
    await tap(tester, find.text(t.listingShow));
    await tap(tester, find.byKey(const ValueKey('confirm-action')));
    expect(
      (await repo.getManaged(materialId: material.id))!.listing.status,
      ListingStatus.published,
    );
    await client.auth.signOut();
    await container
        .read(appPreferencesProvider.notifier)
        .setLeaves(previousLeaves);
  });
}
