import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/destination.dart';
import '../supabase_config.dart';

class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  static const imageBucket = 'destination-images';
  static const videoBucket = 'destination-videos';

  bool initialized = false;
  String? initializationError;

  SupabaseClient get client => Supabase.instance.client;
  User? get currentUser => initialized ? client.auth.currentUser : null;
  String? get currentUid => currentUser?.id;

  Future<bool> initialize() async {
    if (SupabaseConfig.publishableKey.isEmpty) {
      initializationError = 'Kunci Supabase belum terbaca. Jalankan aplikasi '
          'dengan --dart-define-from-file=.env atau buat ulang APK dengan '
          'opsi tersebut.';
      return false;
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.projectUrl,
        publishableKey: SupabaseConfig.publishableKey,
      );
      initialized = true;
      initializationError = null;
      return true;
    } on Exception catch (error) {
      initializationError = 'Gagal memulai Supabase: $error';
      return false;
    }
  }

  Future<List<Destination>> getDestinations() async {
    final rows =
        await client.from('destinations').select().order('id', ascending: true);
    return rows
        .map((row) => Destination.fromMap(Map<String, Object?>.from(row)))
        .toList();
  }

  Future<void> upsertUserProfile({
    required User user,
    required String name,
  }) async {
    await client.from('profiles').upsert({
      'id': user.id,
      'email': user.email?.toLowerCase(),
      'full_name': name,
      'last_sign_in_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> logUserEvent(User user, String event) async {
    await client.from('user_activity_logs').insert({
      'user_id': user.id,
      'event': event,
    });
  }

  Future<bool> userIsAdmin(String uid) async {
    final rows =
        await client.from('profiles').select('is_admin').eq('id', uid).limit(1);
    return rows.isNotEmpty && rows.first['is_admin'] == true;
  }

  Future<void> deleteUserData(String uid) async {
    if (currentUid != uid) {
      throw StateError('Akun Supabase yang aktif tidak cocok.');
    }
    final response = await client.functions.invoke('delete-account');
    if (response.status < 200 || response.status >= 300) {
      throw StateError(
        'Penghapusan akun ditolak server (${response.status}).',
      );
    }
  }

  Future<void> publishDestinations(List<Destination> destinations) async {
    for (var start = 0; start < destinations.length; start += 500) {
      final end = (start + 500).clamp(0, destinations.length);
      await client.from('destinations').upsert(
            destinations
                .sublist(start, end)
                .map((item) => item.toMap())
                .toList(),
            onConflict: 'id',
          );
    }
  }

  Future<List<Destination>> uploadDestinationMedia(
    List<Destination> destinations,
  ) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final availableAssets = manifest.listAssets().toSet();
    final uploaded = <Destination>[];

    for (final destination in destinations) {
      var updated = destination;
      if (destination.imageAsset.isNotEmpty &&
          availableAssets.contains(destination.imageAsset)) {
        final bytes = await _loadAsset(destination.imageAsset);
        final path = '${destination.id}/${_fileName(destination.imageAsset)}';
        await client.storage.from(imageBucket).uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                upsert: true,
                contentType: _contentType(destination.imageAsset),
              ),
            );
        updated = updated.copyWith(
          imageUrl: client.storage.from(imageBucket).getPublicUrl(path),
        );
      }

      if (destination.videoAsset.isNotEmpty &&
          availableAssets.contains(destination.videoAsset)) {
        final bytes = await _loadAsset(destination.videoAsset);
        final path = '${destination.id}/${_fileName(destination.videoAsset)}';
        await client.storage.from(videoBucket).uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'video/mp4',
              ),
            );
        updated = updated.copyWith(
          videoUrl: client.storage.from(videoBucket).getPublicUrl(path),
        );
      }
      uploaded.add(updated);
    }

    await publishDestinations(uploaded);
    return uploaded;
  }

  Future<Uint8List> _loadAsset(String path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  String _fileName(String assetPath) => assetPath.split('/').last;

  String _contentType(String path) {
    final extension = path.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}
