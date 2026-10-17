import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_user.dart';
import '../models/destination.dart';

/// Database SQLite lokal: users, destinations, favorites.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'guriang_garut.db');
    return openDatabase(
      path,
      version: 8,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db
              .execute('ALTER TABLE destinations ADD COLUMN audio_asset TEXT');
          await db
              .execute('ALTER TABLE destinations ADD COLUMN video_asset TEXT');
          final rows = await db.query('destinations', columns: ['id', 'name']);
          for (final r in rows) {
            final slug = _slug(r['name'] as String);
            await db.update(
              'destinations',
              {
                'audio_asset': 'assets/audio/$slug.mp3',
                'video_asset': 'assets/video/$slug.mp4',
              },
              where: 'id = ?',
              whereArgs: [r['id']],
            );
          }
        }
        if (oldVersion < 3) {
          await _syncStoryAssets(db);
        }
        if (oldVersion < 4) {
          await db.update(
            'destinations',
            {'image_url': 'assets/images/candi_cangkuang.jpg'},
            where: 'name = ?',
            whereArgs: ['Candi Cangkuang'],
          );
        }
        if (oldVersion < 5) {
          await db.update(
            'destinations',
            {'category': 'Cagar Budaya'},
            where: 'category = ?',
            whereArgs: ['Budaya'],
          );
        }
        if (oldVersion < 6) {
          await _seedIntangibleHeritage(db);
        }
        if (oldVersion < 8) {
          await db.execute('ALTER TABLE users ADD COLUMN auth_uid TEXT');
          await db.execute('''
            CREATE UNIQUE INDEX users_auth_uid
            ON users (auth_uid)
            WHERE auth_uid IS NOT NULL
          ''');
          await db
              .execute('ALTER TABLE destinations ADD COLUMN image_asset TEXT');
          await db.execute(
            "UPDATE destinations SET image_asset = image_url, image_url = '' "
            "WHERE image_url LIKE 'assets/%'",
          );
          await db
              .execute('ALTER TABLE destinations ADD COLUMN video_url TEXT');
        }
      },
    );
  }

  /// "Candi Cangkuang" -> "candi_cangkuang" (nama file di folder assets).
  String _slug(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        salt TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        created_at TEXT NOT NULL,
        auth_uid TEXT UNIQUE
      )
    ''');
    await db.execute('''
      CREATE TABLE destinations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        location TEXT NOT NULL,
        description TEXT NOT NULL,
        history TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        image_url TEXT,
        image_asset TEXT,
        audio_asset TEXT,
        video_asset TEXT,
        video_url TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE favorites (
        user_id INTEGER NOT NULL,
        destination_id INTEGER NOT NULL,
        PRIMARY KEY (user_id, destination_id),
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (destination_id) REFERENCES destinations (id) ON DELETE CASCADE
      )
    ''');
    await _seed(db);
    await _seedIntangibleHeritage(db);
    await _syncStoryAssets(db);
  }

  Future<void> _syncStoryAssets(Database db) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final storyAssets = manifest
        .listAssets()
        .where((asset) => asset.startsWith('assets/stories/'))
        .toSet();
    final destinations =
        await db.query('destinations', columns: ['id', 'name']);

    for (final destination in destinations) {
      final id = destination['id'] as int;
      final name = destination['name'] as String;
      final storyPath = 'assets/stories/${_slug(name)}.txt';
      if (!storyAssets.contains(storyPath)) continue;

      final story = (await rootBundle.loadString(storyPath)).trim();
      if (story.isEmpty) continue;
      await db.update(
        'destinations',
        {'history': story},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> _seed(Database db) async {
    // Koordinat bersifat perkiraan; sesuaikan bila perlu.
    // Isi image_url dengan tautan foto agar gambar tampil di aplikasi.
    final data = <Map<String, Object?>>[
      {
        'name': 'Candi Cangkuang',
        'category': 'Cagar Budaya',
        'location': 'Leles, Garut',
        'image_url': 'assets/images/candi_cangkuang.jpg',
        'description':
            'Candi Cangkuang adalah candi Hindu yang berdiri di sebuah pulau kecil di tengah Situ Cangkuang. Pengunjung menyeberang dengan rakit bambu menuju kompleks candi dan kampung adat Pulo.',
        'history':
            'Candi ini ditemukan kembali pada tahun 1966 dan dipugar pada tahun 1970-an. Di dekatnya terdapat makam Embah Dalem Arief Muhammad yang dipercaya sebagai tokoh penyebar agama Islam di wilayah ini.',
        'latitude': -7.1033,
        'longitude': 107.9172,
      },
      {
        'name': 'Situ Cangkuang',
        'category': 'Alam',
        'location': 'Leles, Garut',
        'description':
            'Danau yang tenang dengan pemandangan perbukitan di sekelilingnya. Pengunjung dapat berkeliling dengan rakit dan menikmati suasana pedesaan Sunda.',
        'history':
            'Situ Cangkuang menjadi bagian dari kawasan cagar budaya bersama Candi Cangkuang dan Kampung Pulo.',
        'latitude': -7.1050,
        'longitude': 107.9150,
      },
      {
        'name': 'Kawah Talaga Bodas',
        'category': 'Alam',
        'location': 'Wanaraja, Garut',
        'description':
            'Kawah gunung berapi dengan danau berwarna putih kehijauan. Uap belerang dan pemandangan pegunungannya menjadikan tempat ini favorit untuk berfoto.',
        'history':
            'Talaga Bodas merupakan kawah dari gunung api yang masih menunjukkan aktivitas panas bumi, sehingga pengunjung perlu mengikuti arahan petugas.',
        'latitude': -7.210076888841531,
        'longitude': 108.06684691092859,
      },
      {
        'name': 'Gunung Papandayan',
        'category': 'Alam',
        'location': 'Cisurupan, Garut',
        'description':
            'Gunung dengan kawah belerang aktif, hutan mati, dan padang edelweis. Jalur pendakiannya relatif ramah untuk pemula.',
        'history':
            'Papandayan pernah mengalami letusan besar pada tahun 1772 yang mengubah bentuk lereng dan kawahnya.',
        'latitude': -7.318516284955626,
        'longitude': 107.73117807675776,
      },
      {
        'name': 'Situ Bagendit',
        'category': 'Alam',
        'image_url': 'assets/images/situ_bangendit.jpg',
        'location': 'Banyuresmi, Garut',
        'description':
            'Danau luas dengan taman dan area bermain keluarga. Pengunjung dapat menaiki perahu dan menikmati kuliner di sekitarnya.',
        'history':
            'Situ Bagendit dikenal lewat legenda rakyat Sunda tentang Nyi Endit yang menjadi asal-usul danau ini.',
        'latitude': -7.160024003191133,
        'longitude': 107.94168923810281,
      },
      {
        'name': 'Kampung Pulo',
        'category': 'Cagar Budaya',
        'location': 'Leles, Garut',
        'description':
            'Kampung adat yang terdiri dari enam rumah dan satu mushola. Jumlah bangunan dan penghuninya dijaga sesuai adat turun-temurun.',
        'history':
            'Kampung Pulo berada di pulau kecil di Situ Cangkuang dan menjadi bagian penting dari sejarah penyebaran Islam di Garut.',
        'latitude': -7.1028,
        'longitude': 107.9181,
      },
      {
        'name': 'Pemandian Air Panas Cipanas',
        'category': 'Alam',
        'location': 'Tarogong Kaler, Garut',
        'description':
            'Kawasan pemandian air panas alami dari kaki Gunung Guntur yang terkenal sebagai tempat bersantai sejak masa kolonial.',
        'history':
            'Sumber air panas Cipanas telah dimanfaatkan sebagai tempat peristirahatan sejak zaman Hindia Belanda.',
        'latitude': -7.181298380110905,
        'longitude': 107.87672405325715,
      },
      {
        'name': 'Pantai Santolo',
        'category': 'Alam',
        'location': 'Cikelet, Garut',
        'description':
            'Pantai selatan Garut dengan pasir lembut, ombak besar, dan deretan warung ikan bakar. Cocok untuk menikmati matahari terbenam.',
        'history':
            'Santolo juga dikenal sebagai kampung nelayan dengan pelabuhan kecil yang ramai pada pagi hari.',
        'latitude': -7.6678,
        'longitude': 107.7219,
      },
    ];
    final batch = db.batch();
    for (final row in data) {
      // Nama file mengikuti nama destinasi, mis. assets/audio/candi_cangkuang.mp3
      final slug = _slug(row['name'] as String);
      final imageUrl = row['image_url'] as String?;
      if (imageUrl != null && imageUrl.startsWith('assets/')) {
        row['image_asset'] = imageUrl;
        row['image_url'] = '';
      }
      row['audio_asset'] = 'assets/audio/$slug.mp3';
      row['video_asset'] = 'assets/video/$slug.mp4';
      row['video_url'] = '';
      batch.insert('destinations', row);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _seedIntangibleHeritage(Database db) async {
    final data = <Map<String, Object?>>[
      {
        'name': 'Lais',
        'category': 'Warisan Budaya Tak Benda',
        'location': 'Cibatu, Garut',
        'description':
            'Lais adalah seni pertunjukan akrobatik tradisional Garut. Penampil melakukan berbagai gerakan di atas tali yang dibentangkan di antara dua batang bambu tinggi, diiringi musik dan suasana pertunjukan rakyat.',
        'history':
            'Kesenian Lais tumbuh dan diwariskan oleh masyarakat Garut, khususnya di wilayah Cibatu. Pertunjukan ini menjadi bagian dari hiburan rakyat dan ditampilkan pada acara budaya atau perayaan masyarakat.',
        'latitude': -7.0830,
        'longitude': 107.9840,
      },
      {
        'name': 'Surak Ibra',
        'category': 'Warisan Budaya Tak Benda',
        'location': 'Wanaraja, Garut',
        'description':
            'Surak Ibra adalah seni pertunjukan tradisional dari Garut yang menampilkan gerak berkelompok, iringan musik, dan seruan khas. Pertunjukan ini melibatkan kebersamaan para pemain dan biasanya dipentaskan dalam kegiatan budaya masyarakat.',
        'history':
            'Surak Ibra diwariskan oleh masyarakat Wanaraja dan dikenal sebagai salah satu kesenian khas Kabupaten Garut. Tradisi pertunjukannya terus dijaga melalui kelompok seni dan kegiatan kebudayaan setempat.',
        'latitude': -7.1740,
        'longitude': 107.9560,
      },
      {
        'name': 'Badeng',
        'category': 'Warisan Budaya Tak Benda',
        'location': 'Sanding, Malangbong, Garut',
        'description':
            'Badeng adalah seni pertunjukan tradisional masyarakat Sanding, Malangbong. Kesenian ini memadukan musik, nyanyian, dan gerak sebagai bagian dari ekspresi budaya masyarakat setempat.',
        'history':
            'Kesenian Badeng diwariskan secara turun-temurun di wilayah Sanding, Malangbong. Pementasan dan kelompok seni setempat berperan dalam menjaga keberlanjutan tradisi ini.',
        'latitude': -7.0200,
        'longitude': 108.0900,
      },
    ];

    for (final row in data) {
      final existing = await db.query(
        'destinations',
        columns: ['id'],
        where: 'name = ?',
        whereArgs: [row['name']],
        limit: 1,
      );
      if (existing.isNotEmpty) continue;

      final slug = _slug(row['name'] as String);
      row['audio_asset'] = 'assets/audio/$slug.mp3';
      row['video_asset'] = 'assets/video/$slug.mp4';
      await db.insert('destinations', row);
    }
  }

  // ---------- Destinasi ----------
  Future<List<Destination>> getDestinations() async {
    final db = await database;
    final rows = await db.query('destinations', orderBy: 'id ASC');
    return rows.map(Destination.fromMap).toList();
  }

  Future<void> cacheDestinations(List<Destination> destinations) async {
    final db = await database;
    final batch = db.batch();
    for (final destination in destinations) {
      final row = destination.toMap();
      batch.insert(
        'destinations',
        row,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      batch.update(
        'destinations',
        row,
        where: 'id = ?',
        whereArgs: [destination.id],
      );
    }
    await batch.commit(noResult: true);
  }

  // ---------- Pengguna ----------
  String _hash(String salt, String password) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  String _newSalt() {
    final rnd = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
  }

  /// Mengembalikan pengguna baru, atau null jika email sudah terdaftar.
  Future<AppUser?> registerUser(
      String name, String email, String password) async {
    final db = await database;
    final salt = _newSalt();
    try {
      final id = await db.insert('users', {
        'name': name,
        'email': email.toLowerCase(),
        'salt': salt,
        'password_hash': _hash(salt, password),
        'created_at': DateTime.now().toIso8601String(),
      });
      return AppUser(id: id, name: name, email: email.toLowerCase());
    } on DatabaseException {
      return null;
    }
  }

  Future<AppUser?> authenticate(String email, String password) async {
    final db = await database;
    final rows = await db.query('users',
        where: 'email = ?', whereArgs: [email.toLowerCase()], limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final ok = _hash(row['salt'] as String, password) == row['password_hash'];
    return ok ? AppUser.fromMap(row) : null;
  }

  Future<AppUser?> getUserById(int id) async {
    final db = await database;
    final rows =
        await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  Future<AppUser> cacheSupabaseUser({
    required String authUid,
    required String name,
    required String email,
  }) async {
    final db = await database;
    final normalizedEmail = email.toLowerCase();
    return db.transaction((txn) async {
      final byUid = await txn.query(
        'users',
        where: 'auth_uid = ?',
        whereArgs: [authUid],
        limit: 1,
      );
      if (byUid.isNotEmpty) {
        final id = byUid.first['id'] as int;
        await txn.update(
          'users',
          {'name': name, 'email': normalizedEmail},
          where: 'id = ?',
          whereArgs: [id],
        );
        return AppUser(
          id: id,
          name: name,
          email: normalizedEmail,
          authUid: authUid,
        );
      }

      final legacyUser = await txn.query(
        'users',
        where: 'email = ?',
        whereArgs: [normalizedEmail],
        limit: 1,
      );
      if (legacyUser.isNotEmpty) {
        final id = legacyUser.first['id'] as int;
        await txn.update(
          'users',
          {'auth_uid': authUid, 'name': name},
          where: 'id = ?',
          whereArgs: [id],
        );
        return AppUser(
          id: id,
          name: name,
          email: normalizedEmail,
          authUid: authUid,
        );
      }

      final salt = _newSalt();
      final id = await txn.insert('users', {
        'name': name,
        'email': normalizedEmail,
        'salt': salt,
        'password_hash': _hash(salt, _newSalt()),
        'created_at': DateTime.now().toIso8601String(),
        'auth_uid': authUid,
      });
      return AppUser(
        id: id,
        name: name,
        email: normalizedEmail,
        authUid: authUid,
      );
    });
  }

  Future<void> linkAuthUid(int id, String authUid) async {
    final db = await database;
    await db.update(
      'users',
      {'auth_uid': authUid},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateLocalPassword(int id, String password) async {
    final db = await database;
    final salt = _newSalt();
    await db.update(
      'users',
      {'salt': salt, 'password_hash': _hash(salt, password)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateName(int id, String name) async {
    final db = await database;
    await db.update('users', {'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> changePassword(int id, String oldPw, String newPw) async {
    final db = await database;
    final rows =
        await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return false;
    final row = rows.first;
    if (_hash(row['salt'] as String, oldPw) != row['password_hash']) {
      return false;
    }
    final salt = _newSalt();
    await db.update(
        'users', {'salt': salt, 'password_hash': _hash(salt, newPw)},
        where: 'id = ?', whereArgs: [id]);
    return true;
  }

  Future<void> deleteUser(int id) async {
    final db = await database;
    await db.delete('favorites', where: 'user_id = ?', whereArgs: [id]);
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Favorit ----------
  Future<Set<int>> getFavoriteIds(int userId) async {
    final db = await database;
    final rows =
        await db.query('favorites', where: 'user_id = ?', whereArgs: [userId]);
    return rows.map((r) => r['destination_id'] as int).toSet();
  }

  Future<void> addFavorite(int userId, int destinationId) async {
    final db = await database;
    await db.insert(
        'favorites', {'user_id': userId, 'destination_id': destinationId},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> removeFavorite(int userId, int destinationId) async {
    final db = await database;
    await db.delete('favorites',
        where: 'user_id = ? AND destination_id = ?',
        whereArgs: [userId, destinationId]);
  }
}
