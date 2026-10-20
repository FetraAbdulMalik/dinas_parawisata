import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_user.dart';
import '../models/destination.dart';
import '../utils/destination_image_assets.dart';

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
      version: 17,
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
        if (oldVersion < 9) {
          await db.execute(
              'ALTER TABLE destinations ADD COLUMN opening_hours TEXT');
          await db
              .execute('ALTER TABLE destinations ADD COLUMN ticket_price TEXT');
          await db
              .execute('ALTER TABLE destinations ADD COLUMN facilities TEXT');
          await db.execute('ALTER TABLE destinations ADD COLUMN contact TEXT');
          await db.execute(
              'ALTER TABLE destinations ADD COLUMN practical_info_updated_at TEXT');
        }
        if (oldVersion < 12) {
          await _syncDestinationImageAssets(db);
        }
        if (oldVersion < 14) {
          await _syncCoordinates(db);
        }
        if (oldVersion < 15) {
          await db.execute('ALTER TABLE users ADD COLUMN avatar_image BLOB');
        }
        if (oldVersion < 16) {
          await db.execute(
              "ALTER TABLE destinations ADD COLUMN no_sk_bupati TEXT NOT NULL DEFAULT ''");
        }
        if (oldVersion < 17) {
          await db.execute('''
            UPDATE destinations
            SET category = CASE name
              WHEN 'Situ Cangkuang' THEN 'Danau'
              WHEN 'Kawah Talaga Bodas' THEN 'Kawah'
              WHEN 'Gunung Papandayan' THEN 'Gunung'
              WHEN 'Situ Bagendit' THEN 'Danau'
              WHEN 'Pantai Santolo' THEN 'Laut'
              ELSE category
            END
            WHERE category = 'Alam'
          ''');
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
        auth_uid TEXT UNIQUE,
        avatar_image BLOB
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
        video_url TEXT,
        opening_hours TEXT,
        ticket_price TEXT,
        facilities TEXT,
        contact TEXT,
        no_sk_bupati TEXT NOT NULL DEFAULT '',
        practical_info_updated_at TEXT
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
    await _syncDestinationImageAssets(db);
  }

  Future<void> _syncDestinationImageAssets(Database db) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final imageAssets = manifest.listAssets().toSet();
    final destinations =
        await db.query('destinations', columns: ['id', 'name', 'image_asset']);

    for (final destination in destinations) {
      final id = destination['id'] as int;
      final name = destination['name'] as String;
      final matchingAsset = findDestinationImageAsset(
        name,
        imageAssets,
        fallbackAsset: destination['image_asset'] as String? ?? '',
      );
      if (matchingAsset == null) continue;
      if (destination['image_asset'] == matchingAsset) continue;
      await db.update(
        'destinations',
        {'image_asset': matchingAsset},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> _syncCoordinates(Database db) async {
    const coords = <String, (double, double)>{
      'Gunung Papandayan': (-7.318686547827731, 107.7309635000461),
      'Candi Cangkuang': (-7.10286040248776, 107.9182992265749),
      'Situ Cangkuang': (-7.105450788232365, 107.9214014057605),
      'Kampung Pulo': (-7.1030359595169825, 107.91812910325642),
      'Pantai Santolo': (-7.660882685878713, 107.68492656654034),
      'Kawah Talaga Bodas': (-7.210427606848121, 108.06521220797536),
      'Situ Bagendit': (-7.16079045488683, 107.94142101721326),
      'Pemandian Air Panas Cipanas': (-7.181298380110905, 107.87672405325715),
      'Lais': (-7.098201366335401, 107.98433183899857),
      'Badeng': (-7.088133643492038, 108.06296099928333),
      'Surak Ibra': (-7.172884647723464, 107.98143637352516),
    };
    for (final entry in coords.entries) {
      await db.update(
        'destinations',
        {
          'latitude': entry.value.$1,
          'longitude': entry.value.$2,
        },
        where: 'name = ?',
        whereArgs: [entry.key],
      );
    }
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
    // Isi image_asset dengan path foto lokal untuk setiap destinasi.
    final data = <Map<String, Object?>>[
      {
        'name': 'Candi Cangkuang',
        'category': 'Cagar Budaya',
        'location': 'Leles, Garut',
        'image_asset': 'assets/images/candi_cangkuang.jpg',
        'description':
            'Candi Cangkuang adalah candi Hindu yang berdiri di sebuah pulau kecil di tengah Situ Cangkuang. Pengunjung menyeberang dengan rakit bambu menuju kompleks candi dan kampung adat Pulo.',
        'history':
            'Candi ini ditemukan kembali pada tahun 1966 dan dipugar pada tahun 1970-an. Di dekatnya terdapat makam Embah Dalem Arief Muhammad yang dipercaya sebagai tokoh penyebar agama Islam di wilayah ini.',
        'latitude': -7.10286040248776,
        'longitude': 107.9182992265749,
      },
      {
        'name': 'Situ Cangkuang',
        'category': 'Danau',
        'location': 'Leles, Garut',
        'image_asset': 'assets/images/situ_cangkuang.jpg',
        'description':
            'Danau yang tenang dengan pemandangan perbukitan di sekelilingnya. Pengunjung dapat berkeliling dengan rakit dan menikmati suasana pedesaan Sunda.',
        'history':
            'Situ Cangkuang menjadi bagian dari kawasan cagar budaya bersama Candi Cangkuang dan Kampung Pulo.',
        'latitude': -7.105450788232365,
        'longitude': 107.9214014057605,
      },
      {
        'name': 'Kawah Talaga Bodas',
        'category': 'Kawah',
        'location': 'Wanaraja, Garut',
        'image_asset': 'assets/images/talaga_bodas.jpg',
        'description':
            'Kawah gunung berapi dengan danau berwarna putih kehijauan. Uap belerang dan pemandangan pegunungannya menjadikan tempat ini favorit untuk berfoto.',
        'history':
            'Talaga Bodas merupakan kawah dari gunung api yang masih menunjukkan aktivitas panas bumi, sehingga pengunjung perlu mengikuti arahan petugas.',
        'latitude': -7.210427606848121,
        'longitude': 108.06521220797536,
      },
      {
        'name': 'Gunung Papandayan',
        'category': 'Gunung',
        'location': 'Cisurupan, Garut',
        'image_asset': 'assets/images/gunung_papandayan.jpg',
        'description':
            'Gunung dengan kawah belerang aktif, hutan mati, dan padang edelweis. Jalur pendakiannya relatif ramah untuk pemula.',
        'history':
            'Papandayan pernah mengalami letusan besar pada tahun 1772 yang mengubah bentuk lereng dan kawahnya.',
        'latitude': -7.318686547827731,
        'longitude': 107.7309635000461,
      },
      {
        'name': 'Situ Bagendit',
        'category': 'Danau',
        'image_asset': 'assets/images/situ_bangendit.jpg',
        'location': 'Banyuresmi, Garut',
        'description':
            'Danau luas dengan taman dan area bermain keluarga. Pengunjung dapat menaiki perahu dan menikmati kuliner di sekitarnya.',
        'history':
            'Situ Bagendit dikenal lewat legenda rakyat Sunda tentang Nyi Endit yang menjadi asal-usul danau ini.',
        'latitude': -7.16079045488683,
        'longitude': 107.94142101721326,
      },
      {
        'name': 'Kampung Pulo',
        'category': 'Cagar Budaya',
        'location': 'Leles, Garut',
        'image_asset': 'assets/images/kampung_pulo.jpg',
        'description':
            'Kampung adat yang terdiri dari enam rumah dan satu mushola. Jumlah bangunan dan penghuninya dijaga sesuai adat turun-temurun.',
        'history':
            'Kampung Pulo berada di pulau kecil di Situ Cangkuang dan menjadi bagian penting dari sejarah penyebaran Islam di Garut.',
        'latitude': -7.1030359595169825,
        'longitude': 107.91812910325642,
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
        'category': 'Laut',
        'location': 'Cikelet, Garut',
        'image_asset': 'assets/images/pantai_santolo.jpeg',
        'description':
            'Pantai selatan Garut dengan pasir lembut, ombak besar, dan deretan warung ikan bakar. Cocok untuk menikmati matahari terbenam.',
        'history':
            'Santolo juga dikenal sebagai kampung nelayan dengan pelabuhan kecil yang ramai pada pagi hari.',
        'latitude': -7.6511427,
        'longitude': 107.6757856,
      },
    ];
    final batch = db.batch();
    for (final row in data) {
      // Nama file mengikuti nama destinasi, mis. assets/audio/candi_cangkuang.mp3
      final slug = _slug(row['name'] as String);
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
        'image_asset': 'assets/images/lais.jpg',
        'description':
            'Lais adalah seni pertunjukan akrobatik tradisional Garut. Penampil melakukan berbagai gerakan di atas tali yang dibentangkan di antara dua batang bambu tinggi, diiringi musik dan suasana pertunjukan rakyat.',
        'history':
            'Kesenian Lais tumbuh dan diwariskan oleh masyarakat Garut, khususnya di wilayah Cibatu. Pertunjukan ini menjadi bagian dari hiburan rakyat dan ditampilkan pada acara budaya atau perayaan masyarakat.',
        'latitude': -7.098201366335401,
        'longitude': 107.98433183899857,
      },
      {
        'name': 'Surak Ibra',
        'category': 'Warisan Budaya Tak Benda',
        'location': 'Wanaraja, Garut',
        'image_asset': 'assets/images/surak_ibra.jpg',
        'description':
            'Surak Ibra adalah seni pertunjukan tradisional dari Garut yang menampilkan gerak berkelompok, iringan musik, dan seruan khas. Pertunjukan ini melibatkan kebersamaan para pemain dan biasanya dipentaskan dalam kegiatan budaya masyarakat.',
        'history':
            'Surak Ibra diwariskan oleh masyarakat Wanaraja dan dikenal sebagai salah satu kesenian khas Kabupaten Garut. Tradisi pertunjukannya terus dijaga melalui kelompok seni dan kegiatan kebudayaan setempat.',
        'latitude': -7.1729044,
        'longitude': 107.9814359,
      },
      {
        'name': 'Badeng',
        'category': 'Warisan Budaya Tak Benda',
        'location': 'Sanding, Malangbong, Garut',
        'image_asset': 'assets/images/badeng.jpg',
        'description':
            'Badeng adalah seni pertunjukan tradisional masyarakat Sanding, Malangbong. Kesenian ini memadukan musik, nyanyian, dan gerak sebagai bagian dari ekspresi budaya masyarakat setempat.',
        'history':
            'Kesenian Badeng diwariskan secara turun-temurun di wilayah Sanding, Malangbong. Pementasan dan kelompok seni setempat berperan dalam menjaga keberlanjutan tradisi ini.',
        'latitude': -7.088133643492038,
        'longitude': 108.06296099928333,
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
  static const Map<String, (double, double)> activeCoordinates = {
    'Gunung Papandayan': (-7.318686547827731, 107.7309635000461),
    'Candi Cangkuang': (-7.10286040248776, 107.9182992265749),
    'Situ Cangkuang': (-7.105450788232365, 107.9214014057605),
    'Kampung Pulo': (-7.1030359595169825, 107.91812910325642),
    'Pantai Santolo': (-7.660882685878713, 107.68492656654034),
    'Kawah Talaga Bodas': (-7.210427606848121, 108.06521220797536),
    'Situ Bagendit': (-7.16079045488683, 107.94142101721326),
    'Pemandian Air Panas Cipanas': (-7.181298380110905, 107.87672405325715),
    'Lais': (-7.098201366335401, 107.98433183899857),
    'Badeng': (-7.088133643492038, 108.06296099928333),
    'Surak Ibra': (-7.172884647723464, 107.98143637352516),
  };

  Future<List<Destination>> getDestinations() async {
    final db = await database;
    final rows = await db.query('destinations', orderBy: 'id ASC');
    return rows.map((r) {
      final d = Destination.fromMap(r);
      final override = activeCoordinates[d.name];
      if (override != null) {
        return d.copyWith(latitude: override.$1, longitude: override.$2);
      }
      return d;
    }).toList();
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

  Future<void> deleteDestination(int id) async {
    final db = await database;
    await db.delete('destinations', where: 'id = ?', whereArgs: [id]);
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
    String? avatarUrl,
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
          avatarUrl: avatarUrl,
          avatarBytes: byUid.first['avatar_image'] as Uint8List?,
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
          avatarUrl: avatarUrl,
          avatarBytes: legacyUser.first['avatar_image'] as Uint8List?,
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
        avatarUrl: avatarUrl,
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

  Future<void> updateProfilePhoto(int id, Uint8List bytes) async {
    final db = await database;
    await db.update(
      'users',
      {'avatar_image': bytes},
      where: 'id = ?',
      whereArgs: [id],
    );
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
