import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/auth/auth_session_providers.dart';

/// Dịch vụ tải ảnh minh chứng lên bucket private `studyshare-handover-evidence`
/// và lấy Signed URL ngắn hạn để người nhận kiểm tra trước khi xác nhận.
class HandoverEvidenceStorage {
  const HandoverEvidenceStorage(this.client);

  static const bucketId = 'studyshare-handover-evidence';
  static const signedUrlTtl = Duration(seconds: 300);
  static const _uuid = Uuid();

  final SupabaseClient? client;

  bool get isCloudEnabled => client != null && client!.auth.currentUser != null;

  /// Tải bytes ảnh lên thư mục riêng `<auth.uid()>/<handoverId>/<uuid>.jpg`.
  /// Trả về `private_path` trên Storage để ghi nhận qua RPC `submit_handover_evidence`.
  Future<String> uploadEvidenceBytes({
    required String handoverId,
    required Uint8List bytes,
    String extension = 'jpg',
  }) async {
    final sb = client;
    final user = sb?.auth.currentUser;
    if (sb == null || user == null) {
      // Chế độ Demo offline/mock: trả về đường dẫn giả lập.
      return 'demo/${user?.id ?? 'demo-user'}/$handoverId/${_uuid.v4()}.$extension';
    }

    final safeExt = extension.toLowerCase() == 'png'
        ? 'png'
        : (extension.toLowerCase() == 'webp' ? 'webp' : 'jpg');
    final storagePath = '${user.id}/$handoverId/${_uuid.v4()}.$safeExt';

    await sb.storage.from(bucketId).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$safeExt',
            upsert: false,
          ),
        );

    return storagePath;
  }

  /// Tạo Signed URL ngắn hạn (5 phút) cho một đường dẫn ảnh private.
  /// Ném lỗi nếu chưa đăng nhập hoặc Storage từ chối truy cập.
  Future<String> createSignedUrl(String privatePath) async {
    final sb = client;
    if (sb == null || sb.auth.currentUser == null) {
      throw StateError('Chưa đăng nhập để tạo liên kết ảnh minh chứng.');
    }
    return sb.storage
        .from(bucketId)
        .createSignedUrl(privatePath, signedUrlTtl.inSeconds);
  }
}

final handoverEvidenceStorageProvider = Provider<HandoverEvidenceStorage>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return HandoverEvidenceStorage(client);
});
