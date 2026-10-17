import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../db/database_helper.dart';
import '../models/app_user.dart';
import '../models/destination.dart';
import '../services/supabase_service.dart';
import '../utils/password_policy.dart';

class AppState extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final SupabaseService _supabase = SupabaseService.instance;

  static const culturalHeritageCategories = {
    'Cagar Budaya',
    'Warisan Budaya Tak Benda',
  };

  bool ready = false;
  bool supabaseReady = false;
  bool isContentAdmin = false;
  String? serviceMessage;
  AppUser? user;
  List<Destination> _all = [];
  Set<int> favoriteIds = {};
  String category = 'Semua';
  String? cultureType;
  String query = '';

  List<Destination> get allDestinations => _all;
  List<Destination> get destinations => _filter(_all);
  List<Destination> get favorites =>
      _filter(_all.where((d) => favoriteIds.contains(d.id)).toList());
  List<String> get categories {
    final available = _all.map((d) => d.category).toSet();
    final categories = available
        .where((c) => !culturalHeritageCategories.contains(c) && c != 'Budaya')
        .toSet();
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
          _all = remoteDestinations;
          await _db.cacheDestinations(remoteDestinations);
        }
      } on PostgrestException catch (error) {
        serviceMessage = 'Gagal memuat destinasi Supabase: ${error.message}';
      } on Exception catch (error) {
        serviceMessage = 'Gagal memuat destinasi Supabase: $error';
      }
    } else {
      serviceMessage = _supabase.initializationError;
    }

    final prefs = await SharedPreferences.getInstance();
    final authUser = _supabase.currentUser;
    if (supabaseReady && authUser != null) {
      user = await _db.cacheSupabaseUser(
        authUid: authUser.id,
        name: _supabaseName(authUser),
        email: authUser.email ?? '',
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

  Future<void> _startSession(AppUser appUser) async {
    user = appUser;
    favoriteIds = await _db.getFavoriteIds(appUser.id);
    category = 'Semua';
    cultureType = null;
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
    user = AppUser(
      id: currentUser.id,
      name: normalizedName,
      email: currentUser.email,
      authUid: currentUser.authUid,
    );
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

  void setCategory(String value) {
    category = value;
    cultureType = null;
    notifyListeners();
  }

  void setCultureType(String? type) {
    cultureType = type;
    notifyListeners();
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }
}
