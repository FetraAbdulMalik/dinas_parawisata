import 'package:flutter/material.dart';

import '../theme.dart';

/// Menampilkan foto destinasi; bila kosong/gagal dimuat, tampil placeholder hijau.
class DestinationImage extends StatelessWidget {
  final String url;
  final String fallbackAsset;
  final double? width;
  final double? height;
  final double radius;

  const DestinationImage({
    super.key,
    required this.url,
    this.fallbackAsset = '',
    this.width,
    this.height,
    this.radius = 8,
  });

  Widget _placeholder() => Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF5E9B3C), AppColors.green],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(Icons.landscape, color: Colors.white70, size: 32),
        ),
      );

  @override
  Widget build(BuildContext context) {
    Widget assetImage(String asset) => Image.asset(
          asset,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        );

    final image = url.startsWith('assets/')
        ? assetImage(url)
        : url.isNotEmpty
            ? Image.network(
                url,
                width: width,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallbackAsset.isNotEmpty
                    ? assetImage(fallbackAsset)
                    : _placeholder(),
              )
            : fallbackAsset.isNotEmpty
                ? assetImage(fallbackAsset)
                : _placeholder();

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: image,
    );
  }
}
