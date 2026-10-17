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
    final featured = state.allDestinations.take(3).toList();
    final list = state.destinations;

    return ListView(
      padding: const EdgeInsets.only(top: 20, bottom: 24),
      children: [
        if (featured.isNotEmpty && state.query.isEmpty)
          SizedBox(
            child: Column(
              children: [
                SizedBox(
                  height: 187,
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
          ),
        const SizedBox(height: 20),
        const CategoryChips(),
        const SizedBox(height: 14),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('Destinasi tidak ditemukan.')),
          ),
        for (final d in list)
          DestinationCard(
            destination: d,
            onTap: () => openDetail(context, d),
          ),
        const CopyrightFooter(),
      ],
    );
  }
}

void openDetail(BuildContext context, Destination d) {
  final all = context.read<AppState>().allDestinations;
  final index = all.indexWhere((x) => x.id == d.id);
  Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DetailScreen(initialIndex: index < 0 ? 0 : index)));
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
