# Guriang Garut — Aplikasi Wisata (Flutter + Supabase)

Dibuat dari desain Figma "ui-parawisata": Masuk, Daftar, Home, Peta Budaya,
Favorit, Detail + Pemutar Audio, Profil, Pengaturan Privasi, dan FAQ.

## Cara menjalankan

1. Pasang Flutter SDK (>= 3.19) dan Android Studio/SDK.
2. Di dalam folder proyek ini, buat folder platform (android, ios, dll):

       flutter create . --project-name guriang_garut --org com.example

   (Perintah ini tidak menimpa folder `lib/` dan `pubspec.yaml` yang sudah ada.
   Bila `pubspec.yaml` terganti, kembalikan dependensinya dari berkas ini.)
3. Ambil paket dan jalankan:

       flutter pub get
       flutter run --dart-define-from-file=.env

4. Buat APK:

       flutter build apk --release --dart-define-from-file=.env

   Hasil: `build/app/outputs/flutter-apk/app-release.apk`

## Aplikasi Guriang Garut di browser

Versi web menjalankan aplikasi Flutter yang sama dengan APK, termasuk katalog
destinasi dan navigasi. Browser menyimpan data lokalnya sendiri; akun dan
sinkronisasi Supabase memerlukan konfigurasi `.env`. Peta web menyediakan
tampilan terrain 3D dan peta standar 2D. Setelah APK release dibuat, jalankan script berikut dari
PowerShell untuk membangun website dan menyalin APK ke folder unduhannya:

       .\tools\build_website.ps1

Script ini juga memakai `.env` untuk mengaktifkan Supabase bila file tersedia.
Publikasikan seluruh isi `build/web`. Pengunjung akan melihat halaman pembuka
dengan pilihan **Buka Website** atau **Unduh Aplikasi Android**, lalu bisa
membaca penjelasan fitur, destinasi, cerita, dan FAQ sebelum memilih. Aplikasi
web baru dimuat setelah tombol **Buka Website** dipilih. APK tersedia di
`downloads/guriang-garut.apk`.


## Database SQLite (lokal/offline)

File `guriang_garut.db` dibuat otomatis saat aplikasi pertama dibuka
(`lib/db/database_helper.dart`).

| Tabel          | Kolom utama                                                                 |
|----------------|-----------------------------------------------------------------------------|
| `users`        | id, name, email (unik), salt, password_hash (SHA-256 + salt), created_at, auth_uid |
| `destinations` | id, name, category, location, description, history, latitude, longitude, image_url, video_url |
| `favorites`    | user_id, destination_id (kunci gabungan, hapus berantai)                    |

### Melihat struktur database secara manual

Buka database kosong di DB Browser for SQLite, pilih tab **Execute SQL**, buka
file `database_manual.sql`, lalu jalankan dengan tombol **▶**. Script membuat
struktur tabel dan contoh destinasi beserta kategorinya untuk dipelajari.
Tabel `users` berisi cache profil akun aplikasi dan tidak menyimpan kredensial
Supabase. File SQL ini adalah salinan inspeksi dan tidak menggantikan database
aktif aplikasi yang tersimpan di perangkat.

Destinasi diisi otomatis (seed), termasuk contoh Warisan Budaya Tak Benda Garut
seperti Lais, Surak Ibra, dan Badeng. Untuk menambah atau mengubah data, edit
daftar `data` di `_seed` atau `_seedIntangibleHeritage` sesuai jenis datanya.
Versi database 6 menambahkan data budaya; versi 8 menambahkan cache UID Supabase
dan jalur fallback media pada instalasi lama tanpa menghapus akun maupun daftar
favorit. Koordinat destinasi bersifat perkiraan;
verifikasi sebelum digunakan untuk navigasi.

### Kategori budaya

Pilih kategori **Budaya** untuk menampilkan subkategori **Cagar Budaya** dan
**Warisan Budaya Tak Benda** di baris kedua. Saat menambahkan data budaya di
`_seed`, isi `category` dengan salah satu nama subkategori tersebut. Data lama
berkategori `Budaya` otomatis diperlakukan sebagai **Cagar Budaya**.

## Audio dan video (offline, dari assets)

File audio/video **tidak disimpan di dalam database**; database hanya menyimpan
path-nya (kolom `audio_asset` dan `video_asset` di tabel `destinations`).

1. Taruh file di folder proyek:
   - audio (.mp3) → `assets/audio/`
   - video (.mp4) → `assets/video/`
2. Nama file = nama destinasi huruf kecil, spasi jadi garis bawah. Contoh:

       assets/audio/candi_cangkuang.mp3      assets/video/candi_cangkuang.mp4
       assets/audio/situ_cangkuang.mp3       assets/video/situ_cangkuang.mp4
       assets/audio/kawah_talaga_bodas.mp3   assets/video/kawah_talaga_bodas.mp4
       assets/audio/gunung_papandayan.mp3    assets/video/gunung_papandayan.mp4
       assets/audio/situ_bagendit.mp3        assets/video/situ_bagendit.mp4
       assets/audio/kampung_pulo.mp3         assets/video/kampung_pulo.mp4
       assets/audio/pemandian_air_panas_cipanas.mp3   (dan .mp4)
       assets/audio/pantai_santolo.mp3                (dan .mp4)

3. Jalankan ulang aplikasi (`flutter run`). Tidak perlu mengubah kode.
   File yang belum ada dilewati: tanpa audio, deskripsi dan cerita destinasi
   dibacakan otomatis saat halaman detail dibuka; tanpa video, tampil foto
   destinasi.

Untuk destinasi baru, tambahkan barisnya di `_seed` lalu isi `audio_asset` dan
`video_asset` dengan path file. Bila aplikasi sudah terpasang dengan database
lama, hapus datanya (uninstall) atau naikkan `version` dan tambahkan migrasi.

Saran: kompres video (mis. 480p/720p, di bawah ~10 MB per file) agar APK tidak
terlalu besar.

## Cerita destinasi dari Word

Cerita dapat dikelola sebagai file teks terpisah, tanpa menempelkan teks panjang
ke kode:

1. Buka dokumen di Microsoft Word, pilih **Save As**, lalu pilih format
   **Plain Text (.txt)**.
2. Jika diminta memilih encoding, pilih **UTF-8**.
3. Simpan file ke `assets/stories/` dengan nama destinasi huruf kecil dan spasi
   diganti garis bawah. Contoh:

       Candi Cangkuang                 -> assets/stories/candi_cangkuang.txt
       Pemandian Air Panas Cipanas     -> assets/stories/pemandian_air_panas_cipanas.txt

4. Jalankan aplikasi. Saat database dibuat atau diperbarui, aplikasi menyalin
   file cerita yang cocok ke kolom `history` destinasi. Cerita tersimpan di
   database dan muncul di halaman detail serta digunakan untuk suara otomatis.
   Jika file `.txt` belum tersedia, cerita `history` yang sudah ada tetap
   digunakan.

Folder `assets/stories/` sudah terdaftar di `pubspec.yaml`. Untuk mengubah
cerita setelah aplikasi pernah dijalankan, naikkan versi database di
`lib/db/database_helper.dart` dan tambahkan sinkronisasi migrasi untuk versi
tersebut, atau hapus data aplikasi (ini juga menghapus akun dan favorit lokal).

## Catatan

- **Foto destinasi**: kolom `image_url` di data seed masih kosong, sehingga
  tampil placeholder hijau. Isi dengan tautan foto (https) agar gambar tampil.
- **Koordinat** destinasi bersifat perkiraan; cek ulang di peta sebelum rilis.
- **Peta 3D** menampilkan relief terrain Garut dengan MapLibre GL JS di dalam
  aplikasi. Tampilan 2D memakai OpenStreetMap melalui `flutter_map`; peta daring
  memerlukan koneksi internet.
- Tombol arah pada setiap destinasi membuka rute dari lokasi pengguna ke
  destinasi tersebut di Google Maps. Jika aplikasi Google Maps terpasang,
  tautannya akan membukanya; selain itu tautan dibuka di browser.
- **Pemutar audio** memakai MP3 destinasi dan tetap berjalan saat aplikasi
  diminimalkan atau layar dikunci. Kontrol pemutaran tersedia di notifikasi
  media/layar kunci. Jika aplikasi ditutup paksa, Android dapat menghentikan
  pemutaran. Teks yang belum memiliki MP3 memakai text-to-speech perangkat;
  TTS memerlukan data suara Bahasa Indonesia dan bukan pemutar latar belakang.
- Ikon, jarak, dan warna mengikuti desain; avatar profil memakai inisial nama
  karena gambar avatar Figma adalah ilustrasi.
