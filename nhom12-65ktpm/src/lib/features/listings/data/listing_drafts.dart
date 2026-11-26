import '../../materials/data/material_draft_store.dart';

// Nội dung nhỏ và command chưa rõ ACK nằm trong SQLite riêng theo tài khoản.
class ListingDrafts {
  ListingDrafts(this.store);
  final MaterialDraftStore store;
  String _key(String actor) => 'listing-drafts:$actor';
  Future<Map<String, dynamic>> all(String actor) async =>
      await store.read(_key(actor)) ?? {};
  Future<Map<String, dynamic>?> read(String actor, String id) async {
    final value = (await all(actor))[id];
    return value == null ? null : Map<String, dynamic>.from(value as Map);
  }

  Future<void> save(String actor, String id, Map<String, dynamic> value) async {
    final values = await all(actor);
    values[id] = value;
    await store.write(_key(actor), values);
  }

  Future<void> remove(String actor, String id) async {
    final values = await all(actor);
    values.remove(id);
    await store.write(_key(actor), values);
  }
}
