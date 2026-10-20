import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/destination.dart';
import '../providers/app_state.dart';
import '../widgets/category_chips.dart';
import '../widgets/destination_card.dart';
import '../widgets/copyright_footer.dart';
import '../widgets/destination_image.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PageController _featuredController =
      PageController(viewportFraction: 0.9);
  int _featuredIndex = 0;

  @override
  void dispose() {
    _featuredController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final featured = state.popularDestinations.take(3).toList();
    final list = state.destinations;
    return ListView(
      padding: const EdgeInsets.only(top: 20, bottom: 24),
      children: [
        if (featured.isNotEmpty && state.query.isEmpty)
          Column(
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).width >= 900 ? 340 : 187,
                child: PageView.builder(
                  controller: _featuredController,
                  itemCount: featured.length,
                  onPageChanged: (index) =>
                      setState(() => _featuredIndex = index),
                  itemBuilder: (_, i) =>
                      _FeaturedCard(destination: featured[i]),
                ),
              ),
              if (featured.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < featured.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _featuredIndex ? 18 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _featuredIndex
                                ? const Color(0xFF246B0B)
                                : const Color(0xFFB8C4B3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        if (featured.isNotEmpty &&
            state.query.isEmpty &&
            MediaQuery.sizeOf(context).width < 900)
          const SizedBox(height: 18),
        const CategoryChips(),
        const SizedBox(height: 14),
        _destinationList(list),
        if (state.query.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _MostSearchedPanel(
              destinations: state.hasSearchStatistics
                  ? state.mostSearchedDestinations.take(5).toList()
                  : state.popularDestinations.take(5).toList(),
              hasSearchStatistics: state.hasSearchStatistics,
              searchCountFor: state.searchCountFor,
              onTap: (destination) => openDetail(context, destination),
            ),
          ),
        const CopyrightFooter(),
      ],
    );
  }

  Widget _destinationList(List<Destination> destinations) {
    if (destinations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('Destinasi tidak ditemukan.')),
      );
    }
    return ResponsiveDestinationGrid(
      destinations: destinations,
      onTap: (destination) => openDetail(context, destination),
      ratings: context.read<AppState>().destinationRatingStats,
    );
  }
}

class _MostSearchedPanel extends StatelessWidget {
  final List<Destination> destinations;
  final bool hasSearchStatistics;
  final int Function(int destinationId) searchCountFor;
  final ValueChanged<Destination> onTap;

  const _MostSearchedPanel({
    required this.destinations,
    required this.hasSearchStatistics,
    required this.searchCountFor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Destinasi Paling Dicari',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            hasSearchStatistics
                ? 'Berdasarkan pencarian pengunjung'
                : 'Rekomendasi destinasi untuk dijelajahi',
            style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < destinations.length; i++)
            _PopularDestinationTile(
              rank: i + 1,
              destination: destinations[i],
              searchCount:
                  hasSearchStatistics ? searchCountFor(destinations[i].id) : 0,
              onTap: () => onTap(destinations[i]),
            ),
          if (destinations.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Belum ada data pencarian. Destinasi yang dibuka dari hasil pencarian akan muncul di sini.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }
}

class _PopularDestinationTile extends StatelessWidget {
  final int rank;
  final Destination destination;
  final int searchCount;
  final VoidCallback onTap;

  const _PopularDestinationTile({
    required this.rank,
    required this.destination,
    required this.searchCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '$rank.',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF246B0B),
                  ),
                ),
              ),
              DestinationImage(
                url: destination.imageUrl,
                fallbackAsset: destination.imageAsset,
                width: 48,
                height: 48,
                radius: 6,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      searchCount > 0
                          ? '$searchCount pencarian'
                          : destination.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

void openDetail(BuildContext context, Destination d) {
  final state = context.read<AppState>();
  if (state.query.trim().isNotEmpty) {
    unawaited(_recordSearchResultOpen(context, state, d.id));
  }
  final all = state.allDestinations;
  final index = all.indexWhere((x) => x.id == d.id);
  Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DetailScreen(initialIndex: index < 0 ? 0 : index)));
}

Future<void> _recordSearchResultOpen(
  BuildContext context,
  AppState state,
  int destinationId,
) async {
  try {
    await state.recordDestinationSearch(destinationId);
  } on Exception catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gagal mencatat pencarian destinasi: $error')),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final Destination destination;
  const _FeaturedCard({required this.destination});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openDetail(context, destination),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DestinationImage(
                url: destination.imageUrl,
                fallbackAsset: destination.imageAsset,
                radius: 0,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                right: 56,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      destination.name.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 12, color: Colors.white),
                        const SizedBox(width: 2),
                        Text(destination.location,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const Positioned(
                right: 10,
                bottom: 10,
                child:
                    Icon(Icons.play_circle_fill, color: Colors.white, size: 37),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
