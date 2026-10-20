import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/destination.dart';
import '../models/destination_review.dart';
import '../supabase_config.dart';
import '../utils/destination_image_assets.dart';

class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  static const imageBucket = 'destination-images';
  static const videoBucket = 'destination-videos';
  static const profileAvatarBucket = 'profile-avatars';

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

  Future<Map<int, int>> getDestinationSearchCounts() async {
    final rows = await client
        .from('destination_search_stats')
        .select('destination_id, search_count');
    return {
      for (final row in rows)
        (row['destination_id'] as num).toInt():
            (row['search_count'] as num).toInt(),
    };
  }

  Future<int> recordDestinationSearch(int destinationId) async {
    final result = await client.rpc(
      'record_destination_search',
      params: {'p_destination_id': destinationId},
    );
    if (result is! num) {
      throw StateError(
          'Supabase mengembalikan jumlah pencarian yang tidak valid.');
    }
    return result.toInt();
  }

  Future<Map<int, (double, int)>> getDestinationRatingStats() async {
    final rows =
        await client.from('destination_rating_stats').select().limit(1000);
    return {
      for (final row in rows)
        (row['destination_id'] as num).toInt(): (
          (row['average_rating'] as num).toDouble(),
          (row['review_count'] as num).toInt(),
        ),
    };
  }

  Future<List<DestinationReview>> getDestinationReviews(
    int destinationId,
  ) async {
    final rows = await client
        .from('destination_reviews')
        .select('destination_id, user_id, rating, review, created_at')
        .eq('destination_id', destinationId)
        .order('updated_at', ascending: false)
        .limit(5);
    return rows
        .map((row) => DestinationReview.fromMap(
              Map<String, Object?>.from(row),
            ))
        .toList();
  }

  Future<DestinationReview?> getUserDestinationReview({
    required int destinationId,
    required String userId,
  }) async {
    final rows = await client
        .from('destination_reviews')
        .select('destination_id, user_id, rating, review, created_at')
        .eq('destination_id', destinationId)
        .eq('user_id', userId)
        .limit(1);
    if (rows.isEmpty) return null;
    return DestinationReview.fromMap(Map<String, Object?>.from(rows.first));
  }

  Future<DestinationReview> upsertDestinationReview({
    required String userId,
    required int destinationId,
    required int rating,
    required String review,
  }) async {
    final row = await client
        .from('destination_reviews')
        .upsert(
          {
            'user_id': userId,
            'destination_id': destinationId,
            'rating': rating,
            'review': review,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'destination_id,user_id',
        )
        .select('destination_id, user_id, rating, review, created_at')
        .single();
    return DestinationReview.fromMap(Map<String, Object?>.from(row));
  }

  Future<void> deleteDestinationReview({
    required int destinationId,
    required String userId,
  }) async {
    await client
        .from('destination_reviews')
        .delete()
        .eq('destination_id', destinationId)
        .eq('user_id', userId);
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

  Future<Destination> createDestination(Destination destination) async {
    final values = destination.toMap()..remove('id');
    final row =
        await client.from('destinations').insert(values).select().single();
    return Destination.fromMap(Map<String, Object?>.from(row));
  }

  Future<void> updateDestination(Destination destination) async {
    final values = destination.toMap()..remove('id');
    final rows = await client
        .from('destinations')
        .update(values)
        .eq('id', destination.id)
        .select('id');
    if (rows.isEmpty) {
      throw Exception(
        'Destinasi tidak ditemukan atau akun tidak memiliki izin mengubah.',
      );
    }
  }

  Future<void> deleteDestination(int id) async {
    final deleted =
        await client.from('destinations').delete().eq('id', id).select('id');
    if (deleted.isEmpty) {
      throw Exception(
        'Destinasi tidak ditemukan atau akun tidak memiliki izin menghapus.',
      );
    }
  }

  Future<String> uploadDestinationImage({
    required int destinationId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final extension = _mediaExtension(fileName);
    final contentType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw const FormatException(
          'Foto harus berformat JPG, PNG, atau WebP.'),
    };
    return _uploadDestinationMedia(
      bucket: imageBucket,
      destinationId: destinationId,
      prefix: 'cover',
      extension: extension,
      bytes: bytes,
      contentType: contentType,
    );
  }

  Future<String> uploadDestinationVideo({
    required int destinationId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final extension = _mediaExtension(fileName);
    if (extension != 'mp4') {
      throw const FormatException('Video harus berformat MP4.');
    }
    return _uploadDestinationMedia(
      bucket: videoBucket,
      destinationId: destinationId,
      prefix: 'video',
      extension: extension,
      bytes: bytes,
      contentType: 'video/mp4',
    );
  }

  Future<String> _uploadDestinationMedia({
    required String bucket,
    required int destinationId,
    required String prefix,
    required String extension,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final path =
        'admin/$destinationId/$prefix-${DateTime.now().microsecondsSinceEpoch}.$extension';
    await client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );
    return client.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> deleteDestinationMedia({
    required String bucket,
    required String url,
  }) async {
    final uri = Uri.tryParse(url);
    final marker = '/storage/v1/object/public/$bucket/';
    final pathIndex = uri?.path.indexOf(marker) ?? -1;
    if (uri == null || pathIndex < 0) return;
    final expectedOrigin = Uri.parse(
      client.storage.from(bucket).getPublicUrl('destination-media-check'),
    ).origin;
    if (uri.origin != expectedOrigin) return;
    final path = uri.path.substring(pathIndex + marker.length);
    if (path.isEmpty) return;
    await client.storage.from(bucket).remove([path]);
  }

  Future<void> updateDestinationPracticalInfo(Destination destination) async {
    await client.from('destinations').update({
      'opening_hours': destination.openingHours,
      'ticket_price': destination.ticketPrice,
      'facilities': destination.facilities,
      'contact': destination.contact,
      'no_sk_bupati': destination.noSkBupati,
      'practical_info_updated_at':
          destination.practicalInfoUpdatedAt?.toUtc().toIso8601String(),
    }).eq('id', destination.id);
  }

  Future<String> uploadProfileAvatar({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (currentUid != userId) {
      throw StateError('Akun Supabase yang aktif tidak cocok.');
    }

    const path = 'avatar';
    await client.storage.from(profileAvatarBucket).uploadBinary(
          '$userId/$path',
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: contentType,
          ),
        );

    final publicUrl =
        client.storage.from(profileAvatarBucket).getPublicUrl('$userId/$path');
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<List<Destination>> uploadDestinationMedia(
    List<Destination> destinations,
  ) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final availableAssets = manifest.listAssets().toSet();
    final uploaded = <Destination>[];

    for (final destination in destinations) {
      var updated = destination;
      final destinationSlug = destinationImageSlug(destination.name);
      final imageAsset = findDestinationImageAsset(
        destination.name,
        availableAssets,
        fallbackAsset: destination.imageAsset,
      );
      if (imageAsset != null) {
        final bytes = await _loadAsset(imageAsset);
        final extension = _fileName(imageAsset).split('.').last.toLowerCase();
        final path = '$destinationSlug.$extension';
        await client.storage.from(imageBucket).uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                upsert: true,
                contentType: _contentType(imageAsset),
              ),
            );
        updated = updated.copyWith(
          imageUrl: client.storage.from(imageBucket).getPublicUrl(path),
          imageAsset: imageAsset,
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

  String _mediaExtension(String fileName) {
    final separator = fileName.lastIndexOf('.');
    if (separator < 0 || separator == fileName.length - 1) {
      throw const FormatException('Nama file media tidak memiliki ekstensi.');
    }
    return fileName.substring(separator + 1).toLowerCase();
  }

  String _contentType(String path) {
    final extension = path.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}
