import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/destination.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import '../utils/google_maps_route.dart';
import '../widgets/category_chips.dart';
import '../widgets/copyright_footer.dart';
import '../widgets/destination_card.dart';
import '../widgets/maplibre_3d_web_stub.dart'
    if (dart.library.html) '../widgets/maplibre_3d_web.dart';
import 'home_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _controller = MapController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  WebViewController? _webViewController;
  int? _selectedId;
  bool _is3DMode = true;
  bool _isWebViewReady = false;
  final String _webMapChannel =
      'guriang-map-${DateTime.now().microsecondsSinceEpoch}';

  static const _garut = LatLng(-7.2, 107.85);

  @override
  void initState() {
    super.initState();
    _initWebController();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _expandCultureSheet() async {
    if (!_sheetController.isAttached) return;
    await _sheetController.animateTo(
      0.65,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _initWebController() {
    if (kIsWeb) return;
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'MapBridge',
        onMessageReceived: (message) {
          final id = int.tryParse(message.message);
          if (id == null) return;
          final destinations = context.read<AppState>().allDestinations;
          for (final destination in destinations) {
            if (destination.id == id) {
              _openDirections(destination);
              return;
            }
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            setState(() => _isWebViewReady = true);
            _update3DMarkers();
          },
        ),
      )
      ..loadHtmlString(_buildCesium3DHtml());
  }

  void _update3DMarkers() {
    if (!_isWebViewReady || _webViewController == null) return;
    final state = context.read<AppState>();
    final dests = state.destinations
        .map((d) => {
              'id': d.id,
              'name': d.name,
              'category': d.category,
              'lat': d.latitude,
              'lng': d.longitude,
              'isCulture': _isCultureCategory(d.category),
            })
        .toList();

    final jsonStr = jsonEncode(dests);
    _webViewController!.runJavaScript('updateDestinations($jsonStr);');
  }

  void _select(Destination d) {
    setState(() => _selectedId = d.id);
    if (_is3DMode && _webViewController != null) {
      _webViewController!
          .runJavaScript('flyToDestination(${d.latitude}, ${d.longitude});');
    } else {
      _controller.move(LatLng(d.latitude, d.longitude), 13);
    }
  }

  Future<void> _openDirections(Destination destination) async {
    final uri = googleMapsDirectionsUri(destination);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Maps tidak dapat dibuka.')),
      );
    }
  }

  bool _isCultureCategory(String category) =>
      category == 'Budaya' ||
      category == 'Cagar Budaya' ||
      category == 'Warisan Budaya Tak Benda';

  List<Map<String, Object>> _mapDestinations(List<Destination> destinations) =>
      destinations
          .map((d) => {
                'id': d.id,
                'name': d.name,
                'category': d.category,
                'lat': d.latitude,
                'lng': d.longitude,
                'isCulture': _isCultureCategory(d.category),
              })
          .toList();

  String _buildCesium3DHtml({
    String? webChannel,
    List<Map<String, Object>> initialDestinations = const [],
  }) {
    final channel = webChannel ?? '';
    final initialDestinationsJson =
        jsonEncode(initialDestinations).replaceAll('<', r'\u003C');
    return '''
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Guriang Garut 3D Map</title>
  <script src="https://unpkg.com/maplibre-gl@3.6.2/dist/maplibre-gl.js"></script>
  <link href="https://unpkg.com/maplibre-gl@3.6.2/dist/maplibre-gl.css" rel="stylesheet" />
  <style>
    body, html { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background: #0b1329; font-family: sans-serif; }
    #map { width: 100%; height: 100%; }
    .destination-marker {
      display: flex;
      flex-direction: column;
      align-items: center;
      cursor: pointer;
    }
    .destination-label {
      max-width: 180px;
      margin-bottom: 3px;
      padding: 4px 8px;
      overflow: hidden;
      border: 1px solid rgba(255, 255, 255, 0.9);
      border-radius: 6px;
      background: rgba(15, 23, 42, 0.92);
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.45);
      color: white;
      font-size: 11px;
      font-weight: 700;
      line-height: 1.3;
      text-align: center;
      text-overflow: ellipsis;
      white-space: nowrap;
      pointer-events: none;
    }
    .custom-marker {
      color: white;
      border-radius: 50%;
      width: 30px;
      height: 30px;
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 4px 10px rgba(0,0,0,0.5);
      border: 1px solid white;
      font-size: 15px;
      cursor: pointer;
      transition: transform 0.2s;
    }
    .nature-marker { background: #1b5e20; }
    .culture-marker { background: #7b1fa2; }
    .destination-marker:hover .custom-marker {
      transform: scale(1.3);
      background: #e53935;
    }
    .badge-3d {
      position: absolute;
      top: 10px;
      left: 10px;
      background: rgba(15, 23, 42, 0.75);
      backdrop-filter: blur(8px);
      color: #4ade80;
      padding: 6px 12px;
      border-radius: 20px;
      font-size: 11px;
      font-weight: bold;
      letter-spacing: 0.5px;
      border: 1px solid rgba(74, 222, 128, 0.3);
      pointer-events: none;
      z-index: 10;
    }
  </style>
</head>
<body>
  <div class="badge-3d">🌐 3D TERRAIN • GARUT</div>
  <div id="map"></div>

  <script>
    const map = new maplibregl.Map({
      container: 'map',
      style: {
        version: 8,
        sources: {
          'osm-tiles': {
            type: 'raster',
            tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],
            tileSize: 256,
            attribution: '© OpenStreetMap contributors'
          },
          'terrainSource': {
            type: 'raster-dem',
            tiles: ['https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png'],
            encoding: 'terrarium',
            tileSize: 256
          }
        },
        layers: [
          {
            id: 'osm-layer',
            type: 'raster',
            source: 'osm-tiles',
            minzoom: 0,
            maxzoom: 19
          }
        ],
        terrain: {
          source: 'terrainSource',
          exaggeration: 1.8
        },
        sky: {
          'sky-color': '#199EF3',
          'sky-horizon-blend': 0.5,
          'horizon-color': '#ffffff',
          'horizon-fog-blend': 0.5,
          'fog-color': '#0000ff',
          'fog-ground-blend': 0.5
        }
      },
      center: [107.85, -7.2],
      zoom: 10.2,
      pitch: 58,
      bearing: -15,
      maxPitch: 85
    });

    let currentMarkers = [];

    function updateDestinations(dests) {
      currentMarkers.forEach(m => m.remove());
      currentMarkers = [];

      dests.forEach(d => {
        const el = document.createElement('div');
        el.className = 'destination-marker';

        const label = document.createElement('div');
        label.className = 'destination-label';
        label.textContent = d.name;
        el.appendChild(label);

        const pin = document.createElement('div');
        pin.className = 'custom-marker ' +
          (d.isCulture ? 'culture-marker' : 'nature-marker');
        pin.textContent = d.isCulture ? '🏛️' : '🌿';
        el.appendChild(pin);

        el.onclick = () => {
          if (window.MapBridge) {
            MapBridge.postMessage(String(d.id));
          } else {
            const directions = new URL('https://www.google.com/maps/dir/');
            directions.searchParams.set('api', '1');
            directions.searchParams.set('destination', d.lat + ',' + d.lng);
            directions.searchParams.set('travelmode', 'driving');
            window.top.location.href = directions.toString();
          }
        };

        const marker = new maplibregl.Marker({ element: el, anchor: 'bottom' })
          .setLngLat([d.lng, d.lat])
          .addTo(map);

        currentMarkers.push(marker);
      });
    }

    function flyToDestination(lat, lng) {
      map.flyTo({
        center: [lng, lat],
        zoom: 13.5,
        pitch: 65,
        bearing: 25,
        duration: 2500,
        essential: true
      });
    }

    const webChannel = '$channel';
    const initialDestinations = $initialDestinationsJson;
    if (webChannel) {
      map.on('load', () => {
        updateDestinations(initialDestinations);
        window.parent.postMessage(
          JSON.stringify({channel: webChannel, kind: 'ready'}),
          window.location.origin
        );
      });
      window.addEventListener('message', event => {
        if (event.source !== window.parent || typeof event.data !== 'string') return;
        let message;
        try {
          message = JSON.parse(event.data);
        } catch (_) {
          return;
        }
        if (message.channel !== webChannel) return;
        if (message.kind === 'state') {
          updateDestinations(message.destinations);
          if (message.latitude != null && message.longitude != null) {
            flyToDestination(message.latitude, message.longitude);
          }
        }
      });
    }
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = state.destinations;
    Destination? selected;
    for (final destination in list) {
      if (destination.id == _selectedId) {
        selected = destination;
        break;
      }
    }

    // Sinkronkan marker 3D jika data berubah
    if (_is3DMode && _isWebViewReady) {
      _update3DMarkers();
    }

    return Stack(
      children: [
        Positioned.fill(
          child: _is3DMode
              ? kIsWeb
                  ? MapLibre3DWebView(
                      key: ValueKey(_webMapChannel),
                      channel: _webMapChannel,
                      destinations: _mapDestinations(list),
                      html: _buildCesium3DHtml(
                        webChannel: _webMapChannel,
                        initialDestinations: _mapDestinations(list),
                      ),
                      selectedLatitude: selected?.latitude,
                      selectedLongitude: selected?.longitude,
                    )
                  : _webViewController != null
                      ? WebViewWidget(controller: _webViewController!)
                      : const SizedBox.shrink()
              : FlutterMap(
                  mapController: _controller,
                  options: const MapOptions(
                    initialCenter: _garut,
                    initialZoom: 9.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.guriang_garut',
                    ),
                    MarkerLayer(
                      markers: [
                        for (final d in list)
                          Marker(
                            point: LatLng(d.latitude, d.longitude),
                            width: 44,
                            height: 44,
                            child: GestureDetector(
                              onTap: () async {
                                _select(d);
                                await _openDirections(d);
                              },
                              child: Icon(
                                _isCultureCategory(d.category)
                                    ? Icons.account_balance
                                    : Icons.park,
                                size: _selectedId == d.id ? 44 : 34,
                                color: _selectedId == d.id
                                    ? Colors.red
                                    : _isCultureCategory(d.category)
                                        ? const Color(0xFF7B1FA2)
                                        : AppColors.green,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const RichAttributionWidget(
                      attributions: [TextSourceAttribution('© OpenStreetMap')],
                    ),
                  ],
                ),
        ),
        Positioned(
          top: 8,
          left: 12,
          right: 12,
          child: Material(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(14),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'Peta:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const Spacer(),
                  ChoiceChip(
                    label: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.public, size: 16),
                        SizedBox(width: 3),
                        Text('3D'),
                      ],
                    ),
                    tooltip: '3D Terrain',
                    selected: _is3DMode,
                    selectedColor: AppColors.green.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: _is3DMode ? AppColors.green : Colors.black87,
                      fontWeight:
                          _is3DMode ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => setState(() => _is3DMode = true),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_outlined, size: 16),
                        SizedBox(width: 3),
                        Text('2D'),
                      ],
                    ),
                    tooltip: '2D Standar',
                    selected: !_is3DMode,
                    selectedColor: AppColors.green.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: !_is3DMode ? AppColors.green : Colors.black87,
                      fontWeight:
                          !_is3DMode ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => setState(() => _is3DMode = false),
                  ),
                ],
              ),
            ),
          ),
        ),
        DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: 0.23,
          minChildSize: 0.22,
          maxChildSize: 0.65,
          snap: true,
          snapSizes: const [0.23, 0.65],
          builder: (context, scrollController) => Material(
            color: Colors.white,
            elevation: 5,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 9, bottom: 5),
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                CategoryChips(onCultureDropdownTap: _expandCultureSheet),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 12),
                    children: [
                      for (final d in list)
                        DestinationCard(
                          destination: d,
                          trailing: IconButton(
                            tooltip: 'Buka rute di Google Maps',
                            onPressed: () => _openDirections(d),
                            icon: const Icon(Icons.directions,
                                color: AppColors.green),
                          ),
                          onTap: () {
                            _select(d);
                            openDetail(context, d);
                          },
                        ),
                      const CopyrightFooter(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
