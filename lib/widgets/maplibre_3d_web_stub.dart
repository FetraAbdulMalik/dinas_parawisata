import 'package:flutter/material.dart';

class MapLibre3DWebView extends StatelessWidget {
  final String channel;
  final String html;
  final List<Map<String, Object>> destinations;
  final double? selectedLatitude;
  final double? selectedLongitude;
  final String focusKey;
  final ValueChanged<int> onDestinationTap;
  final bool isInteractive;

  const MapLibre3DWebView({
    super.key,
    required this.channel,
    required this.html,
    required this.destinations,
    required this.selectedLatitude,
    required this.selectedLongitude,
    required this.focusKey,
    required this.onDestinationTap,
    this.isInteractive = true,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
