import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/destination.dart';
import '../providers/app_state.dart';
import '../screens/login_screen.dart';
import '../theme.dart';
import 'destination_image.dart';

class DestinationCard extends StatelessWidget {
  final Destination destination;
  final VoidCallback onTap;
  final Widget? trailing;
  final double averageRating;
  final int reviewCount;
  final bool showFavoriteButton;

  const DestinationCard({
    super.key,
    required this.destination,
    required this.onTap,
    this.trailing,
    this.averageRating = 0,
    this.reviewCount = 0,
    this.showFavoriteButton = true,
  });

  Future<void> _toggleFavorite(BuildContext context) async {
    final state = context.read<AppState>();
    if (state.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Masuk untuk menyimpan destinasi ke favorit.'),
          action: SnackBarAction(
            label: 'Masuk',
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const LoginScreen())),
          ),
        ),
      );
      return;
    }
    try {
      await state.toggleFavorite(destination.id);
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memperbarui favorit: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isFavorite = state.favoriteIds.contains(destination.id);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 3),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Hero(
                  tag: 'destination-image-${destination.id}',
                  child: DestinationImage(
                    url: destination.imageUrl,
                    fallbackAsset: destination.imageAsset,
                    width: 65,
                    height: 65,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        destination.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 13, color: AppColors.muted),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              destination.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.muted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            destination.ticketPrice.trim().isEmpty
                                ? 'Harga belum tersedia'
                                : destination.ticketPrice.trim(),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 15, color: Color(0xFFF4B400)),
                              Text(
                                reviewCount > 0
                                    ? '${averageRating.toStringAsFixed(1)} ($reviewCount)'
                                    : 'Belum ada rating',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (showFavoriteButton)
                  IconButton(
                    tooltip:
                        isFavorite ? 'Hapus dari favorit' : 'Tambah ke favorit',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _toggleFavorite(context),
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? AppColors.green : AppColors.text,
                    ),
                  ),
                trailing ?? const Icon(Icons.chevron_right, size: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ResponsiveDestinationGrid extends StatelessWidget {
  final List<Destination> destinations;
  final ValueChanged<Destination> onTap;
  final Widget? Function(Destination destination)? trailingBuilder;
  final Map<int, (double, int)> ratings;

  const ResponsiveDestinationGrid({
    super.key,
    required this.destinations,
    required this.onTap,
    this.trailingBuilder,
    this.ratings = const {},
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth.clamp(0.0, 1200.0).toDouble();
        const columns = 1;
        const spacing = 6.0;
        final cardWidth = (contentWidth - spacing * (columns - 1)) / columns;
        return Center(
          child: SizedBox(
            width: contentWidth,
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final destination in destinations)
                  SizedBox(
                    width: cardWidth,
                    child: DestinationCard(
                      destination: destination,
                      onTap: () => onTap(destination),
                      trailing: trailingBuilder?.call(destination),
                      averageRating: ratings[destination.id]?.$1 ?? 0,
                      reviewCount: ratings[destination.id]?.$2 ?? 0,
                      showFavoriteButton: trailingBuilder == null,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
