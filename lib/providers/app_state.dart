import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../db/database_helper.dart';
import '../models/app_user.dart';
import '../models/destination.dart';
import '../models/destination_review.dart';
import '../services/supabase_service.dart';
import '../utils/password_policy.dart';

class AppState extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final SupabaseService _supabase = SupabaseService.instance;

  static const culturalHeritageCategories = {
    'Cagar Budaya',
    'Warisan Budaya Tak Benda',
  };
  static const naturalFeatureCategories = {
    'Gunung',
    'Danau',
    'Kawah',
    'Laut',
    'Air Terjun',
    'Lubuk',
  };

  bool ready = false;
  bool supabaseReady = false;
  bool isContentAdmin = false;
  String? serviceMessage;
  AppUser? user;
  List<Destination> _all = [];
  Map<int, int> _destinationSearchCounts = {};
  Map<int, (double, int)> _destinationRatingStats = {};
  final Map<int, List<DestinationReview>> _destinationReviews = {};
  final Map<int, DestinationReview> _myDestinationReviews = {};
  Set<int> favoriteIds = {};
  String category = 'Semua';
  String? cultureType;
  String? natureType;
  String query = '';
  int? lastCreatedDestinationId;

  List<Destination> get allDestinations => _all;
  List<Destination> get popularDestinations => _sortBySearchCount(_all);
  List<Destination> get destinations => _filter(popularDestinations);
  List<Destination> get favorites => _filter(_sortBySearchCount(
      _all.where((d) => favoriteIds.contains(d.id)).toList()));
  bool get hasSearchStatistics =>
      _destinationSearchCounts.values.any((count) => count > 0);
  List<Destination> get mostSearchedDestinations => _sortBySearchCount(
        _all
            .where((destination) =>
                (_destinationSearchCounts[destination.id] ?? 0) > 0)
            .toList(),
      );
  int searchCountFor(int destinationId) =>
      _destinationSearchCounts[destinationId] ?? 0;
  Map<int, (double, int)> get destinationRatingStats =>
      Map.unmodifiable(_destinationRatingStats);
  (double, int) ratingFor(int destinationId) =>
      _destinationRatingStats[destinationId] ?? (0, 0);
  List<DestinationReview> reviewsFor(int destinationId) =>
      _destinationReviews[destinationId] ?? const [];
  DestinationReview? myReviewFor(int destinationId) =>
      _myDestinationReviews[destinationId];
  String? get currentAuthUserId => _supabase.currentUid;
  bool get canSubmitCloudReview =>
      supabaseReady && _supabase.currentUid != null;

  List<Destination> _sortBySearchCount(List<Destination> destinations) {
    final sorted = List<Destination>.of(destinations);
    sorted.sort((a, b) {
      final bySearchCount = (_destinationSearchCounts[b.id] ?? 0)
          .compareTo(_destinationSearchCounts[a.id] ?? 0);
      return bySearchCount != 0 ? bySearchCount : a.id.compareTo(b.id);
    });
    return sorted;
  }

  List<String> get categories {
    final available = _all.map((d) => d.category).toSet();
    final categories = available
        .where((c) =>
            !culturalHeritageCategories.contains(c) &&
            !naturalFeatureCategories.contains(c) &&
            c != 'Budaya' &&
            c != 'Alam')
        .toSet();
    if (available.contains('Alam') ||
        available.any(naturalFeatureCategories.contains)) {
      categories.add('Alam');
    }
    if (available.any(culturalHeritageCategories.contains) ||
        available.contains('Budaya')) {
      categories.add('Budaya');
    }
    return ['Semua', ...categories];
  }

  List<Destination> _filter(List<Destination> src) {
    final q = query.trim().toLowerCase();
    return src.where((d) {
      if (category == 'Budaya') {
        if (!culturalHeritageCategories.contains(d.category) &&
            d.category != 'Budaya') {
          return false;
        }
        if (cultureType != null &&
            d.category != cultureType &&
            !(cultureType == 'Cagar Budaya' && d.category == 'Budaya')) {
          return false;
        }
      } else if (category == 'Alam') {
        if (d.category != 'Alam' &&
            !naturalFeatureCategories.contains(d.category)) {
          return false;
        }
        if (natureType != null && d.category != natureType) return false;
      } else if (category != 'Semua' && d.category != category) {
        return false;
      }
      if (q.isEmpty) return true;
      return d.name.toLowerCase().contains(q) ||
          d.location.toLowerCase().contains(q) ||
          d.description.toLowerCase().contains(q) ||
          d.history.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> init() async {
    _all = await _db.getDestinations();
    supabaseReady = _supabase.initialized;
    if (supabaseReady) {
      try {
        final remoteDestinations = await _supabase.getDestinations();
        if (remoteDestinations.isNotEmpty) {
          final localImageAssets = {
            for (final destination in _all)
              if (destination.imageAsset.isNotEmpty)
                destination.name: destination.imageAsset,
          };
          _all = remoteDestinations.map((destination) {
            var d = destination.imageAsset.isEmpty &&
                    localImageAssets.containsKey(destination.name)
                ? destination.copyWith(
                    imageAsset: localImageAssets[destination.name])
                : destination;
            final override = DatabaseHelper.activeCoordinates[d.name];
            if (override != null) {
              d = d.copyWith(latitude: override.$1, longitude: override.$2);
            }
            return d;
          }).toList();
          await _db.cacheDestinations(_all);
        }
      } on PostgrestException catch (error) {
        serviceMessage = 'Gagal memuat destinasi Supabase: ${error.message}';
      } on Exception catch (error) {
        serviceMessage = 'Gagal memuat destinasi Supabase: $error';
      }
    } else {
      serviceMessage = _supabase.initializationError;
    }

    if (supabaseReady) {
      try {
        _destinationSearchCounts = await _supabase.getDestinationSearchCounts();
      } on PostgrestException catch (error) {
        serviceMessage =
            'Gagal memuat jumlah pencarian destinasi: ${error.message}';
      } on Exception catch (error) {
        serviceMessage = 'Gagal memuat jumlah pencarian destinasi: $error';
      }
    }

    if (supabaseReady) {
      try {
        _destinationRatingStats = await _supabase.getDestinationRatingStats();
      } on PostgrestException catch (error) {
        serviceMessage = 'Gagal memuat rating destinasi: ${error.message}';
      } on Exception catch (error) {
        serviceMessage = 'Gagal memuat rating destinasi: $error';
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final authUser = _supabase.currentUser;
    if (supabaseReady && authUser != null) {
      user = await _db.cacheSupabaseUser(
        authUid: authUser.id,
        name: _supabaseName(authUser),
        email: authUser.email ?? '',
        avatarUrl: _supabaseAvatarUrl(authUser),
      );
      await prefs.setInt('user_id', user!.id);
      favoriteIds = await _db.getFavoriteIds(user!.id);
      await _refreshAdminStatus();
    } else {
      final localId = prefs.getInt('user_id');
      if (localId != null) {
        user = await _db.getUserById(localId);
        if (user != null) favoriteIds = await _db.getFavoriteIds(user!.id);
      }
    }
    ready = true;
    notifyListeners();
  }

  String _supabaseName(User authUser) {
    final name = authUser.userMetadata?['full_name'];
    if (name is String && name.trim().isNotEmpty) return name.trim();
    return authUser.email?.split('@').first ?? 'Pengguna';
  }

  String? _supabaseAvatarUrl(User authUser) {
    final avatarUrl = authUser.userMetadata?['avatar_url'];
    return avatarUrl is String && avatarUrl.trim().isNotEmpty
        ? avatarUrl.trim()
        : null;
  }

  Future<void> _startSession(AppUser appUser) async {
    user = appUser;
    favoriteIds = await _db.getFavoriteIds(appUser.id);
    category = 'Semua';
    cultureType = null;
    natureType = null;
    query = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', appUser.id);
    notifyListeners();
  }

  Future<void> _refreshAdminStatus() async {
    try {
      final uid = _supabase.currentUid;
      isContentAdmin = uid != null && await _supabase.userIsAdmin(uid);
    } on PostgrestException catch (error) {
      serviceMessage = 'Gagal memeriksa akses administrator: ${error.message}';
    } on Exception catch (error) {
      serviceMessage = 'Gagal memeriksa akses administrator: $error';
    }
  }

  Future<void> _writeSupabaseLog(User authUser, String event) async {
    try {
      await _supabase.logUserEvent(authUser, event);
    } on PostgrestException catch (error) {
      serviceMessage = 'Log aktivitas gagal disimpan: ${error.message}';
      notifyListeners();
    } on Exception catch (error) {
      serviceMessage = 'Log aktivitas gagal disimpan: $error';
      notifyListeners();
    }
  }

  Future<void> _saveSupabaseProfile(
    User authUser,
    String name,
    String event,
  ) async {
    try {
      await _supabase.upsertUserProfile(user: authUser, name: name);
      await _supabase.logUserEvent(authUser, event);
    } on PostgrestException catch (error) {
      serviceMessage =
          'Profil aktif, tetapi sinkronisasi Supabase gagal: ${error.message}';
      notifyListeners();
    } on Exception catch (error) {
      serviceMessage = 'Profil aktif, tetapi sinkronisasi gagal: $error';
      notifyListeners();
    }
  }

  String _authErrorMessage(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('already registered') ||
        message.contains('already been registered')) {
      return 'Email sudah terdaftar.';
    }
    if (message.contains('invalid login credentials')) {
      return 'Email atau kata sandi salah.';
    }
    if (message.contains('password should be at least') ||
        message.contains('weak password')) {
      return 'Kata sandi terlalu lemah.';
    }
    if (message.contains('email not confirmed')) {
      return 'Email belum diverifikasi. Periksa kotak masuk Anda.';
    }
    return 'Supabase gagal memproses akun: ${error.message}';
  }

  Future<String?> login(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!_supabase.initialized) {
      final localUser = await _db.authenticate(normalizedEmail, password);
      if (localUser == null) {
        return serviceMessage ??
            'Supabase belum dikonfigurasi dan akun ini tidak tersedia secara lokal.';
      }
      if (localUser.authUid != null) {
        return 'Supabase belum tersedia. Periksa koneksi internet lalu coba lagi.';
      }
      await _startSession(localUser);
      serviceMessage =
          'Mode offline: akun ini hanya tersedia di perangkat ini.';
      notifyListeners();
      return null;
    }

    try {
      final response = await _supabase.client.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );
      final authUser = response.user;
      if (authUser == null) return 'Supabase tidak mengembalikan data akun.';
      await _activateSupabaseUser(authUser, event: 'login');
      return null;
    } on AuthException catch (error) {
      if (_isNetworkError(error)) {
        final localUser = await _db.authenticate(normalizedEmail, password);
        if (localUser != null && localUser.authUid == null) {
          await _startSession(localUser);
          serviceMessage =
              'Mode offline: akun dan data hanya tersedia di perangkat ini.';
          notifyListeners();
          return null;
        }
      }

      if (_isInvalidCredentials(error)) {
        final legacyUser = await _db.authenticate(normalizedEmail, password);
        if (legacyUser != null && legacyUser.authUid == null) {
          return _migrateLegacyUser(legacyUser, password);
        }
      }
      return _authErrorMessage(error);
    }
  }

  bool _isNetworkError(AuthException error) =>
      error is AuthRetryableFetchException ||
      error.message.toLowerCase().contains('network');

  bool _isInvalidCredentials(AuthException error) {
    final message = error.message.toLowerCase();
    return message.contains('invalid login credentials') ||
        message.contains('user not found');
  }

  Future<String?> register(String name, String email, String password) async {
    final passwordError = validatePassword(password);
    if (passwordError != null) return passwordError;
    if (!_supabase.initialized) {
      return serviceMessage ??
          'Supabase belum dikonfigurasi. Pendaftaran memerlukan koneksi Supabase.';
    }

    try {
      final response = await _supabase.client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {'full_name': name.trim()},
      );
      final authUser = response.user;
      if (authUser == null) return 'Supabase tidak mengembalikan data akun.';
      if (response.session == null) {
        return 'Akun berhasil dibuat. Verifikasi email Anda sebelum masuk.';
      }
      await _activateSupabaseUser(
        authUser,
        event: 'register',
        nameOverride: name.trim(),
      );
      return null;
    } on AuthException catch (error) {
      return _authErrorMessage(error);
    } on StateError catch (error) {
      return error.message.toString();
    } on Exception catch (error) {
      return 'Gagal menghapus akun Supabase: $error';
    }
  }

  Future<String?> _migrateLegacyUser(AppUser localUser, String password) async {
    try {
      final registration = await _supabase.client.auth.signUp(
        email: localUser.email,
        password: password,
        data: {'full_name': localUser.name},
      );
      final registeredUser = registration.user;
      if (registeredUser == null) {
        return 'Supabase tidak mengembalikan data akun.';
      }
      if (registration.session == null) {
        return 'Akun lokal ditemukan dan registrasi Supabase dimulai. '
            'Verifikasi email Anda, lalu masuk kembali.';
      }
      await _db.linkAuthUid(localUser.id, registeredUser.id);
      await _activateSupabaseUser(
        registeredUser,
        event: 'legacy_account_migrated',
        nameOverride: localUser.name,
      );
      return null;
    } on AuthException catch (error) {
      if (!_isInvalidCredentials(error) &&
          !error.message.toLowerCase().contains('already registered')) {
        return _authErrorMessage(error);
      }
    }

    try {
      final loginResponse = await _supabase.client.auth.signInWithPassword(
        email: localUser.email,
        password: password,
      );
      final authUser = loginResponse.user;
      if (authUser == null) return 'Supabase tidak mengembalikan data akun.';
      await _db.linkAuthUid(localUser.id, authUser.id);
      await _activateSupabaseUser(
        authUser,
        event: 'legacy_account_migrated',
        nameOverride: localUser.name,
      );
      return null;
    } on AuthException catch (error) {
      return 'Akun lama tidak dapat dipindahkan otomatis: ${error.message}';
    }
  }

  Future<void> _activateSupabaseUser(
    User authUser, {
    required String event,
    String? nameOverride,
  }) async {
    final name = nameOverride?.trim().isNotEmpty == true
        ? nameOverride!.trim()
        : _supabaseName(authUser);
    final appUser = await _db.cacheSupabaseUser(
      authUid: authUser.id,
      name: name,
      email: authUser.email ?? '',
      avatarUrl: _supabaseAvatarUrl(authUser),
    );
    await _startSession(appUser);
    await _refreshAdminStatus();
    unawaited(_saveSupabaseProfile(authUser, name, event));
  }

  Future<void> logout() async {
    final authUser = _supabase.currentUser;
    if (authUser != null) {
      await _writeSupabaseLog(authUser, 'logout');
      await _supabase.client.auth.signOut();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    user = null;
    favoriteIds = {};
    isContentAdmin = false;
    serviceMessage = _supabase.initializationError;
    notifyListeners();
  }

  Future<bool> toggleFavorite(int destinationId) async {
    final currentUser = user;
    if (currentUser == null) return false;
    if (favoriteIds.contains(destinationId)) {
      favoriteIds.remove(destinationId);
      await _db.removeFavorite(currentUser.id, destinationId);
    } else {
      favoriteIds.add(destinationId);
      await _db.addFavorite(currentUser.id, destinationId);
    }
    notifyListeners();
    return true;
  }

  Future<void> updateName(String name) async {
    final currentUser = user;
    if (currentUser == null) return;
    final normalizedName = name.trim();
    await _db.updateName(currentUser.id, normalizedName);
    user = currentUser.copyWith(name: normalizedName);
    final authUser = _supabase.currentUser;
    if (authUser != null && currentUser.authUid == authUser.id) {
      try {
        await _supabase.client.auth.updateUser(
          UserAttributes(data: {'full_name': normalizedName}),
        );
      } on AuthException catch (error) {
        serviceMessage = _authErrorMessage(error);
      } on Exception catch (error) {
        serviceMessage = 'Gagal memperbarui nama di Supabase: $error';
      }
      unawaited(
        _saveSupabaseProfile(authUser, normalizedName, 'profile_updated'),
      );
    }
    notifyListeners();
  }

  Future<void> updateProfilePhoto({
    required Uint8List bytes,
    required String contentType,
  }) async {
    final currentUser = user;
    if (currentUser == null) {
      throw StateError('Masuk ke akun terlebih dahulu untuk mengubah foto.');
    }

    final authUser = _supabase.currentUser;
    if (currentUser.authUid == null ||
        authUser == null ||
        currentUser.authUid != authUser.id) {
      await _db.updateProfilePhoto(currentUser.id, bytes);
      user = currentUser.copyWith(
        avatarBytes: bytes,
        clearAvatarUrl: true,
      );
      serviceMessage =
          'Foto tersimpan di perangkat ini dan belum disinkronkan ke cloud.';
      notifyListeners();
      return;
    }

    final avatarUrl = await _supabase.uploadProfileAvatar(
      userId: authUser.id,
      bytes: bytes,
      contentType: contentType,
    );
    await _supabase.client.auth.updateUser(
      UserAttributes(data: {'avatar_url': avatarUrl}),
    );

    await _db.updateProfilePhoto(currentUser.id, bytes);
    user = currentUser.copyWith(
      avatarUrl: avatarUrl,
      avatarBytes: bytes,
    );
    serviceMessage = null;
    notifyListeners();
  }

  Future<bool> changePassword(String oldPw, String newPw) async {
    final currentUser = user;
    if (currentUser == null || validatePassword(newPw) != null) return false;
    if (currentUser.authUid != null) {
      try {
        await _supabase.client.auth.signInWithPassword(
          email: currentUser.email,
          password: oldPw,
        );
        await _supabase.client.auth.updateUser(
          UserAttributes(password: newPw),
        );
        await _db.updateLocalPassword(currentUser.id, newPw);
        return true;
      } on AuthException catch (error) {
        serviceMessage = _authErrorMessage(error);
        notifyListeners();
        return false;
      }
    }
    return _db.changePassword(currentUser.id, oldPw, newPw);
  }

  Future<String?> deleteAccount() async {
    final currentUser = user;
    if (currentUser == null) return null;
    final authUser = _supabase.currentUser;
    if (authUser != null && currentUser.authUid == authUser.id) {
      try {
        await _supabase.deleteUserData(authUser.id);
        await _supabase.client.auth.signOut();
      } on PostgrestException catch (error) {
        return 'Gagal menghapus data Supabase: ${error.message}';
      } on AuthException catch (error) {
        return _authErrorMessage(error);
      }
    }
    await _db.deleteUser(currentUser.id);
    await logout();
    return null;
  }

  Future<void> publishLocalDestinations() async {
    if (!supabaseReady || !isContentAdmin) {
      throw StateError('Akun ini tidak memiliki izin mengelola destinasi.');
    }
    final published =
        await _supabase.uploadDestinationMedia(await _db.getDestinations());
    await _db.cacheDestinations(published);
    _all = published;
    notifyListeners();
  }

  void _requireDestinationAdmin() {
    if (!supabaseReady || !isContentAdmin) {
      throw Exception('Akun ini tidak memiliki izin mengelola destinasi.');
    }
  }

  void _validateDestinationName(String name, {int? excludingId}) {
    final normalizedName = name.trim().toLowerCase();
    if (_all.any((destination) =>
        destination.id != excludingId &&
        destination.name.trim().toLowerCase() == normalizedName)) {
      throw Exception('Nama destinasi tersebut sudah digunakan.');
    }
  }

  Future<Destination> createDestination(
    Destination draft, {
    Uint8List? imageBytes,
    String? imageFileName,
    Uint8List? videoBytes,
    String? videoFileName,
  }) async {
    _requireDestinationAdmin();
    _validateDestinationName(draft.name);
    if ((imageBytes == null) != (imageFileName == null) ||
        (videoBytes == null) != (videoFileName == null)) {
      throw const FormatException('Data media destinasi tidak lengkap.');
    }

    final created = await _supabase.createDestination(draft);
    final uploadedMedia = <(String, String)>[];
    try {
      var saved = created;
      if (imageBytes != null && imageFileName != null) {
        final url = await _supabase.uploadDestinationImage(
          destinationId: created.id,
          fileName: imageFileName,
          bytes: imageBytes,
        );
        uploadedMedia.add((SupabaseService.imageBucket, url));
        saved = saved.copyWith(imageUrl: url);
      }
      if (videoBytes != null && videoFileName != null) {
        final url = await _supabase.uploadDestinationVideo(
          destinationId: created.id,
          fileName: videoFileName,
          bytes: videoBytes,
        );
        uploadedMedia.add((SupabaseService.videoBucket, url));
        saved = saved.copyWith(videoUrl: url);
      }
      if (saved.imageUrl != created.imageUrl ||
          saved.videoUrl != created.videoUrl) {
        await _supabase.updateDestination(saved);
      }
      await _db.cacheDestinations([saved]);
      _all = [..._all, saved];
      category = 'Semua';
      cultureType = null;
      natureType = null;
      query = '';
      lastCreatedDestinationId = saved.id;
      serviceMessage = null;
      notifyListeners();
      return saved;
    } on Exception catch (error) {
      final cleanupErrors = <String>[];
      for (final media in uploadedMedia) {
        try {
          await _supabase.deleteDestinationMedia(
            bucket: media.$1,
            url: media.$2,
          );
        } on Exception catch (cleanupError) {
          cleanupErrors.add(cleanupError.toString());
        }
      }
      try {
        await _supabase.deleteDestination(created.id);
      } on Exception catch (cleanupError) {
        cleanupErrors.add(cleanupError.toString());
      }
      if (cleanupErrors.isNotEmpty) {
        throw StateError(
          'Pembuatan destinasi gagal: $error. '
          'Pembersihan data sementara juga gagal: ${cleanupErrors.join('; ')}',
        );
      }
      rethrow;
    }
  }

  Future<void> updateDestination(
    Destination updated, {
    Uint8List? imageBytes,
    String? imageFileName,
    Uint8List? videoBytes,
    String? videoFileName,
    bool removeImage = false,
    bool removeVideo = false,
  }) async {
    _requireDestinationAdmin();
    _validateDestinationName(updated.name, excludingId: updated.id);
    if ((imageBytes == null) != (imageFileName == null) ||
        (videoBytes == null) != (videoFileName == null)) {
      throw const FormatException('Data media destinasi tidak lengkap.');
    }

    final previousIndex =
        _all.indexWhere((destination) => destination.id == updated.id);
    if (previousIndex < 0) throw Exception('Destinasi tidak ditemukan.');
    final previous = _all[previousIndex];
    var saved = updated;
    final uploadedMedia = <(String, String)>[];
    try {
      if (removeImage) {
        saved = saved.copyWith(imageUrl: '', imageAsset: '');
      } else if (imageBytes != null && imageFileName != null) {
        final url = await _supabase.uploadDestinationImage(
          destinationId: updated.id,
          fileName: imageFileName,
          bytes: imageBytes,
        );
        uploadedMedia.add((SupabaseService.imageBucket, url));
        saved = saved.copyWith(imageUrl: url, imageAsset: '');
      }
      if (removeVideo) {
        saved = saved.copyWith(videoUrl: '', videoAsset: '');
      } else if (videoBytes != null && videoFileName != null) {
        final url = await _supabase.uploadDestinationVideo(
          destinationId: updated.id,
          fileName: videoFileName,
          bytes: videoBytes,
        );
        uploadedMedia.add((SupabaseService.videoBucket, url));
        saved = saved.copyWith(videoUrl: url, videoAsset: '');
      }
      await _supabase.updateDestination(saved);
    } on Exception catch (error) {
      final cleanupErrors = <String>[];
      for (final media in uploadedMedia) {
        try {
          await _supabase.deleteDestinationMedia(
            bucket: media.$1,
            url: media.$2,
          );
        } on Exception catch (cleanupError) {
          cleanupErrors.add(cleanupError.toString());
        }
      }
      if (cleanupErrors.isNotEmpty) {
        throw StateError(
          'Pembaruan destinasi gagal: $error. '
          'Pembersihan media sementara juga gagal: ${cleanupErrors.join('; ')}',
        );
      }
      rethrow;
    }

    await _db.cacheDestinations([saved]);
    final index = _all.indexWhere((destination) => destination.id == saved.id);
    if (index < 0) {
      _all = [..._all, saved];
    } else {
      _all[index] = saved;
    }

    final cleanupErrors = <String>[];
    if (previous.imageUrl.isNotEmpty && previous.imageUrl != saved.imageUrl) {
      try {
        await _supabase.deleteDestinationMedia(
          bucket: SupabaseService.imageBucket,
          url: previous.imageUrl,
        );
      } on Exception catch (error) {
        cleanupErrors.add(error.toString());
      }
    }
    if (previous.videoUrl.isNotEmpty && previous.videoUrl != saved.videoUrl) {
      try {
        await _supabase.deleteDestinationMedia(
          bucket: SupabaseService.videoBucket,
          url: previous.videoUrl,
        );
      } on Exception catch (error) {
        cleanupErrors.add(error.toString());
      }
    }
    serviceMessage = cleanupErrors.isEmpty
        ? null
        : 'Destinasi disimpan, tetapi media lama gagal dibersihkan: '
            '${cleanupErrors.join('; ')}';
    notifyListeners();
  }

  Future<void> deleteDestination(int id) async {
    _requireDestinationAdmin();
    final index = _all.indexWhere((destination) => destination.id == id);
    if (index < 0) throw Exception('Destinasi tidak ditemukan.');
    final destination = _all[index];

    await _supabase.deleteDestination(id);
    await _db.deleteDestination(id);
    _all = _all.where((item) => item.id != id).toList();
    favoriteIds = {...favoriteIds}..remove(id);

    final cleanupErrors = <String>[];
    for (final media in [
      (SupabaseService.imageBucket, destination.imageUrl),
      (SupabaseService.videoBucket, destination.videoUrl),
    ]) {
      if (media.$2.isEmpty) continue;
      try {
        await _supabase.deleteDestinationMedia(
          bucket: media.$1,
          url: media.$2,
        );
      } on Exception catch (error) {
        cleanupErrors.add(error.toString());
      }
    }
    serviceMessage = cleanupErrors.isEmpty
        ? null
        : 'Destinasi terhapus, tetapi media lama gagal dibersihkan: '
            '${cleanupErrors.join('; ')}';
    notifyListeners();
  }

  Future<void> updateDestinationPracticalInfo({
    required int destinationId,
    required String openingHours,
    required String ticketPrice,
    required String facilities,
    required String contact,
    required String noSkBupati,
  }) async {
    if (!supabaseReady || !isContentAdmin) {
      throw StateError('Akun ini tidak memiliki izin mengelola destinasi.');
    }
    final index =
        _all.indexWhere((destination) => destination.id == destinationId);
    if (index == -1) {
      throw StateError('Destinasi tidak ditemukan.');
    }

    final updated = _all[index].copyWith(
      openingHours: openingHours.trim(),
      ticketPrice: ticketPrice.trim(),
      facilities: facilities.trim(),
      contact: contact.trim(),
      noSkBupati: noSkBupati.trim(),
      practicalInfoUpdatedAt: DateTime.now().toUtc(),
    );
    await _supabase.updateDestinationPracticalInfo(updated);
    await _db.cacheDestinations([updated]);
    _all[index] = updated;
    notifyListeners();
  }

  Future<void> recordDestinationSearch(int destinationId) async {
    if (!supabaseReady) return;
    final searchCount = await _supabase.recordDestinationSearch(destinationId);
    _destinationSearchCounts[destinationId] = searchCount;
    notifyListeners();
  }

  Future<void> loadDestinationReviews(int destinationId) async {
    if (!supabaseReady) return;
    final reviews = await _supabase.getDestinationReviews(destinationId);
    _destinationReviews[destinationId] = reviews;
    final userId = _supabase.currentUid;
    if (userId != null) {
      final myReview = await _supabase.getUserDestinationReview(
        destinationId: destinationId,
        userId: userId,
      );
      if (myReview == null) {
        _myDestinationReviews.remove(destinationId);
      } else {
        _myDestinationReviews[destinationId] = myReview;
      }
    }
    notifyListeners();
  }

  Future<void> submitDestinationReview({
    required int destinationId,
    required int rating,
    required String review,
  }) async {
    final userId = _supabase.currentUid;
    if (!supabaseReady || userId == null) {
      throw StateError('Masuk dengan akun online untuk memberi rating.');
    }
    if (rating < 1 || rating > 5) {
      throw ArgumentError.value(rating, 'rating', 'Harus antara 1 dan 5.');
    }
    if (review.trim().length > 1000) {
      throw ArgumentError.value(
        review.length,
        'review',
        'Ulasan maksimal 1000 karakter.',
      );
    }

    final savedReview = await _supabase.upsertDestinationReview(
      userId: userId,
      destinationId: destinationId,
      rating: rating,
      review: review.trim(),
    );
    _myDestinationReviews[destinationId] = savedReview;
    _destinationReviews.remove(destinationId);
    _destinationRatingStats = await _supabase.getDestinationRatingStats();
    _destinationReviews[destinationId] =
        await _supabase.getDestinationReviews(destinationId);
    notifyListeners();
  }

  Future<void> deleteDestinationReview(int destinationId) async {
    final userId = _supabase.currentUid;
    if (!supabaseReady || userId == null) {
      throw StateError('Masuk dengan akun online untuk menghapus ulasan.');
    }

    await _supabase.deleteDestinationReview(
      destinationId: destinationId,
      userId: userId,
    );
    _myDestinationReviews.remove(destinationId);
    _destinationReviews[destinationId] = [
      for (final review in _destinationReviews[destinationId] ?? const [])
        if (review.userId != userId) review,
    ];
    notifyListeners();

    try {
      _destinationRatingStats = await _supabase.getDestinationRatingStats();
      _destinationReviews[destinationId] =
          await _supabase.getDestinationReviews(destinationId);
      notifyListeners();
    } on Exception catch (error) {
      throw StateError(
        'Ulasan sudah dihapus, tetapi ringkasan belum berhasil diperbarui: $error',
      );
    }
  }

  void setCategory(String value) {
    category = value;
    cultureType = null;
    natureType = null;
    notifyListeners();
  }

  void setCultureType(String? type) {
    cultureType = type;
    notifyListeners();
  }

  void setNatureType(String? type) {
    natureType = type;
    notifyListeners();
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }
}
