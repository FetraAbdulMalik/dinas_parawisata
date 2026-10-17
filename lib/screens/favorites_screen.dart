import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme.dart';
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

    return ListView(
      padding: const EdgeInsets.only(top: 14, bottom: 24),
      children: [
        const CategoryChips(),
        const SizedBox(height: 14),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'Belum ada destinasi favorit.\nTekan ikon hati pada halaman destinasi untuk menyimpan.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        for (final d in list)
          DestinationCard(
            destination: d,
            onTap: () => openDetail(context, d),
            trailing: IconButton(
              icon: const Icon(Icons.favorite, color: AppColors.green, size: 36),
              onPressed: () => context.read<AppState>().toggleFavorite(d.id),
            ),
          ),
        const CopyrightFooter(),
      ],
    );
  }
}
