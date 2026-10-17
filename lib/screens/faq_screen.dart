import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/copyright_footer.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const _items = <List<String>>[
    [
      'Bagaimana cara mencari destinasi wisata di aplikasi ini?',
      'Gunakan ikon pencarian di bagian atas untuk mencari berdasarkan nama, lokasi, atau sejarah. Anda juga bisa memfilter lewat kategori, atau membuka tab peta untuk melihat lokasi destinasi.'
    ],
    [
      'Apakah informasi jam buka dan harga tiket masuk akurat?',
      'Informasi disusun oleh Dinas Pariwisata, namun jam buka dan harga tiket dapat berubah. Sebaiknya konfirmasi terlebih dahulu ke pengelola destinasi sebelum berkunjung.'
    ],
    [
      'Apakah ada rekomendasi rute atau paket wisata?',
      'Gunakan tab peta untuk melihat letak antar destinasi dan merencanakan rute kunjungan. Informasi paket wisata akan ditambahkan pada pembaruan berikutnya.'
    ],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: const Text('FAQ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                for (final qa in _items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.white,
                      elevation: 2,
                      borderRadius: BorderRadius.circular(6),
                      child: Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          title: Text(qa[0],
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          expandedAlignment: Alignment.centerLeft,
                          iconColor: AppColors.green,
                          children: [
                            Text(qa[1], style: const TextStyle(fontSize: 12.5)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const CopyrightFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
