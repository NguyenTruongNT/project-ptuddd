import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';

class UserProfile {
  const UserProfile({required this.userId, required this.displayName});
  final String userId;
  final String displayName;
}

abstract interface class ProfileRepository {
  Future<UserProfile> getOrCreateMyProfile(AuthIdentity identity);
  Future<UserProfile> updateMyDisplayName(String displayName);
}

/// Chỉ truy cập profile của auth.uid(); RLS và column grants kiểm tra tiếp ở DB.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this.client);
  final SupabaseClient client;

  String get _userId {
    final session = client.auth.currentSession;
    if (session == null || session.isExpired) {
      throw AuthSessionMissingException();
    }
    return session.user.id;
  }

  @override
  Future<UserProfile> getOrCreateMyProfile(AuthIdentity identity) async {
    final id = _userId;
    if (identity.id != id) throw const AuthException('Profile access denied');
    var row = await client
        .from('profiles')
        .select('user_id,display_name')
        .eq('user_id', id)
        .maybeSingle();
    if (row == null) {
      final name = identity.displayName?.trim() ?? '';
      // Metadata chỉ gợi ý tên, không suy ra quyền hoặc role.
      await client
          .from('profiles')
          .upsert(
            {
              'user_id': id,
              'display_name': name.isNotEmpty && name.length <= 100
                  ? name
                  : 'StudyShare',
            },
            onConflict: 'user_id',
            ignoreDuplicates: true,
          );
      row = await client
          .from('profiles')
          .select('user_id,display_name')
          .eq('user_id', id)
          .single();
    }
    return UserProfile(
      userId: row['user_id'] as String,
      displayName: row['display_name'] as String,
    );
  }

  @override
  Future<UserProfile> updateMyDisplayName(String displayName) async {
    final name = displayName.trim();
    if (name.isEmpty || name.length > 100) throw ArgumentError('displayName');
    final row = await client
        .from('profiles')
        .update({'display_name': name})
        .eq('user_id', _userId)
        .select('user_id,display_name')
        .single();
    return UserProfile(
      userId: row['user_id'] as String,
      displayName: row['display_name'] as String,
    );
  }
}
