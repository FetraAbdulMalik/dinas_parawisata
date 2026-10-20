import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme.dart';
import '../utils/confirmation_dialog.dart';
import '../widgets/category_chips.dart';
import '../widgets/destination_card.dart';
import '../widgets/copyright_footer.dart';
import 'home_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.favorites;

    Future<void> removeFavorite(int destinationId, String name) async {
      final confirmed = await showConfirmationDialog(
        context: context,
        title: 'Hapus dari favorit?',
        message: 'Hapus $name dari daftar favorit?',
      );
      if (!confirmed || !context.mounted) return;
      await context.read<AppState>().toggleFavorite(destinationId);
    }

    if (list.isEmpty) {
      return const Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          SizedBox(height: 14),
          CategoryChips(),
          SizedBox(height: 14),
          Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Belum ada destinasi favorit.\nTekan ikon hati pada halaman destinasi untuk menyimpan.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          CopyrightFooter(),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 14, bottom: 24),
      children: [
        const CategoryChips(),
        const SizedBox(height: 14),
        ResponsiveDestinationGrid(
          destinations: list,
          onTap: (destination) => openDetail(context, destination),
          ratings: state.destinationRatingStats,
          trailingBuilder: (destination) => IconButton(
            icon: const Icon(Icons.favorite, color: AppColors.green, size: 36),
            onPressed: () => removeFavorite(destination.id, destination.name),
          ),
        ),
        const CopyrightFooter(),
      ],
    );
  }
}
