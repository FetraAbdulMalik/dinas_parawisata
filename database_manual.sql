-- Database SQLite untuk dibuka dan dipelajari melalui DB Browser.
-- Ini adalah salinan inspeksi, bukan database aktif yang dipakai aplikasi.
-- Akun users tidak diisi karena harus berasal dari pendaftaran sungguhan.

PRAGMA foreign_keys = ON;
PRAGMA user_version = 8;

BEGIN TRANSACTION;

CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  salt TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  auth_uid TEXT UNIQUE
);

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
);

CREATE TABLE favorites (
  user_id INTEGER NOT NULL,
  destination_id INTEGER NOT NULL,
  PRIMARY KEY (user_id, destination_id),
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  FOREIGN KEY (destination_id) REFERENCES destinations (id) ON DELETE CASCADE
);

-- Kategori adalah kolom pada destinations, bukan tabel terpisah.
-- Deskripsi/cerita sengaja tidak disertakan karena file ini untuk melihat
-- struktur dan kategori; gunakan aplikasi untuk data destinasi lengkap.
INSERT INTO destinations
  (name, category, location, description, latitude, longitude)
VALUES
  ('Candi Cangkuang', 'Cagar Budaya', 'Leles, Garut', '', -7.1033, 107.9172),
  ('Situ Cangkuang', 'Danau', 'Leles, Garut', '', -7.1050, 107.9150),
  ('Kawah Talaga Bodas', 'Kawah', 'Wanaraja, Garut', '', -7.2092, 107.7347),
  ('Gunung Papandayan', 'Gunung', 'Cisurupan, Garut', '', -7.3195, 107.7306),
  ('Situ Bagendit', 'Danau', 'Banyuresmi, Garut', '', -7.1672, 107.9494),
  ('Kampung Pulo', 'Cagar Budaya', 'Leles, Garut', '', -7.1028, 107.9181),
  ('Pemandian Air Panas Cipanas', 'Alam', 'Tarogong Kaler, Garut', '', -7.1850, 107.8020),
  ('Pantai Santolo', 'Laut', 'Cikelet, Garut', '', -7.6678, 107.7219),
  ('Lais', 'Warisan Budaya Tak Benda', 'Cibatu, Garut', '', -7.0830, 107.9840),
  ('Surak Ibra', 'Warisan Budaya Tak Benda', 'Wanaraja, Garut', '', -7.1740, 107.9560),
  ('Badeng', 'Warisan Budaya Tak Benda', 'Sanding, Malangbong, Garut', '', -7.0200, 108.0900);

COMMIT;

-- Contoh melihat akun tanpa kolom kredensial:
-- SELECT id, name, email, created_at FROM users;
--
-- Contoh melihat jumlah destinasi tiap kategori:
-- SELECT category, COUNT(*) AS jumlah_destinasi
-- FROM destinations
-- GROUP BY category
-- ORDER BY category;
