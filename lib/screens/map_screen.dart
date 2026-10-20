import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/destination.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import '../utils/confirmation_dialog.dart';
import '../utils/google_maps_route.dart';
import '../widgets/category_chips.dart';
import '../widgets/copyright_footer.dart';
import '../widgets/destination_card.dart';
import '../widgets/maplibre_3d_web_stub.dart'
    if (dart.library.html) '../widgets/maplibre_3d_web.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'home_screen.dart';

class MapScreen extends StatefulWidget {
  final bool isActive;

  const MapScreen({super.key, this.isActive = true});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  WebViewController? _webViewController;
  AppState? _observedAppState;
  int? _selectedId;
  int? _lastFocusedCreatedDestinationId;
  int? _lastObservedCreatedDestinationId;
  String? _lastSearchFocusKey;
  String? _lastObservedQuery;
  Timer? _syncDebounce;
  bool _isMapStyleReady = false;
  bool _isConfirmationOpen = false;
  final String _webMapChannel =
      'guriang-map-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _initWebController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<AppState>();
    if (identical(state, _observedAppState)) return;
    _observedAppState?.removeListener(_handleAppStateChanged);
    _observedAppState = state;
    _lastObservedQuery = state.query.trim();
    _lastObservedCreatedDestinationId = state.lastCreatedDestinationId;
    _lastFocusedCreatedDestinationId = state.lastCreatedDestinationId;
    state.addListener(_handleAppStateChanged);
  }

  @override
  void dispose() {
    _observedAppState?.removeListener(_handleAppStateChanged);
    _syncDebounce?.cancel();
    _sheetController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      if (kIsWeb) {
        setState(() {});
      } else {
        unawaited(_sync3DMap(forceFocus: true));
      }
    }
  }

  void _handleAppStateChanged() {
    final state = _observedAppState;
    if (state == null || !mounted) return;

    final query = state.query.trim();
    if (query != _lastObservedQuery) {
      _lastObservedQuery = query;
      _selectedId = null;
      _lastSearchFocusKey = null;
    }

    final createdId = state.lastCreatedDestinationId;
    final isNewlyCreated =
        createdId != null && createdId != _lastObservedCreatedDestinationId;
    _lastObservedCreatedDestinationId = createdId;
    if (isNewlyCreated &&
        state.allDestinations
            .any((destination) => destination.id == createdId)) {
      setState(() => _selectedId = createdId);
      if (kIsWeb) {
        _lastFocusedCreatedDestinationId = createdId;
      } else if (_isMapStyleReady && _webViewController != null) {
        unawaited(_sync3DMap());
      }
      return;
    }

    if (_isMapStyleReady && _webViewController != null) {
      _syncDebounce?.cancel();
      _syncDebounce = Timer(const Duration(milliseconds: 600), () {
        if (mounted) unawaited(_sync3DMap());
      });
    }
  }

  Future<void> _expandCategorySheet() async {
    if (!_sheetController.isAttached) return;
    await _sheetController.animateTo(
      0.65,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _toggleSheet() async {
    if (!_sheetController.isAttached) return;
    final isExpanded = _sheetController.size > 0.35;
    await _sheetController.animateTo(
      isExpanded ? (kIsWeb ? 0.30 : 0.23) : 0.65,
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
      ..addJavaScriptChannel(
        'MapReady',
        onMessageReceived: (message) {
          if (message.message != 'ready' || _isMapStyleReady) return;
          setState(() => _isMapStyleReady = true);
          unawaited(_sync3DMap());
        },
      )
      ..loadHtmlString(_buildCesium3DHtml());
  }

  Future<void> _sync3DMap({bool forceFocus = false}) async {
    if (!_isMapStyleReady || _webViewController == null) return;
    final state = context.read<AppState>();
    final query = state.query.trim();
    final target = _mapFocusTarget(state, state.destinations);
    final dests = _mapDestinations(
      _destinationsForMap(state.destinations, target),
      selectedId: target?.id,
    );

    final jsonStr = jsonEncode(dests);
    await _webViewController!.runJavaScript('updateDestinations($jsonStr);');

    if (query.isNotEmpty) {
      if (target == null) return;
      final focusKey = '$query:${target.id}';
      if (!forceFocus && focusKey == _lastSearchFocusKey) return;
      await _webViewController!.runJavaScript(
        'focusDestination(${target.latitude}, ${target.longitude});',
      );
      _lastSearchFocusKey = focusKey;
      return;
    }

    _lastSearchFocusKey = null;
    final createdId = state.lastCreatedDestinationId;
    if (createdId != null && createdId != _lastFocusedCreatedDestinationId) {
      Destination? created;
      for (final destination in state.allDestinations) {
        if (destination.id == createdId) {
          created = destination;
          break;
        }
      }
      if (created != null) {
        await _webViewController!.runJavaScript(
          'focusDestination(${created.latitude}, ${created.longitude});',
        );
        _lastFocusedCreatedDestinationId = createdId;
        return;
      }
    }
  }

  void _select(Destination d) {
    setState(() => _selectedId = d.id);
    if (context.read<AppState>().query.trim().isNotEmpty) {
      _lastSearchFocusKey = '${context.read<AppState>().query.trim()}:${d.id}';
    }
    _webViewController?.runJavaScript(
      'focusDestination(${d.latitude}, ${d.longitude});',
    );
  }

  Destination? _mapFocusTarget(AppState state, List<Destination> destinations) {
    final query = state.query.trim().toLowerCase();
    if (query.isNotEmpty) {
      final all = state.allDestinations;
      for (final destination in all) {
        if (destination.name.trim().toLowerCase() == query) return destination;
      }
      for (final destination in all) {
        final name = destination.name.trim().toLowerCase();
        if (name.startsWith(query)) {
          return destination;
        }
      }
      for (final destination in all) {
        if (destination.name.trim().toLowerCase().contains(query)) {
          return destination;
        }
      }
      for (final destination in all) {
        if (destination.location.trim().toLowerCase().contains(query)) {
          return destination;
        }
      }
      return destinations.isEmpty ? null : destinations.first;
    }
    for (final destination in destinations) {
      if (destination.id == _selectedId) return destination;
    }
    return null;
  }

  List<Destination> _destinationsForMap(
    List<Destination> destinations,
    Destination? target,
  ) {
    if (target == null ||
        destinations.any((destination) => destination.id == target.id)) {
      return destinations;
    }
    return [...destinations, target];
  }

  Future<void> _openDirections(Destination destination) async {
    setState(() => _isConfirmationOpen = true);
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Buka Google Maps?',
      message: 'Buka rute ke ${destination.name} di Google Maps?',
    );
    if (mounted) {
      setState(() => _isConfirmationOpen = false);
    }
    if (!confirmed || !mounted) return;

    final uri = googleMapsDirectionsUri(destination);
    final opened = await launchUrl(
      uri,
      mode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Maps tidak dapat dibuka.')),
      );
    }
  }

  void _onWebMapMessage(int id) {
    final destinations = context.read<AppState>().allDestinations;
    for (final destination in destinations) {
      if (destination.id == id) {
        _openDirections(destination);
        return;
      }
    }
  }

  bool _isCultureCategory(String category) =>
      category == 'Budaya' ||
      category == 'Cagar Budaya' ||
      category == 'Warisan Budaya Tak Benda';

  List<Map<String, Object>> _mapDestinations(
    List<Destination> destinations, {
    int? selectedId,
  }) =>
      destinations
          .map((d) => {
                'id': d.id,
                'name': d.name,
                'category': d.category,
                'lat': d.latitude,
                'lng': d.longitude,
                'isCulture': _isCultureCategory(d.category),
                'isSelected': d.id == selectedId,
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
    .destination-marker.is-selected .custom-marker {
      width: 42px;
      height: 42px;
      border: 3px solid #ffca28;
      background: #e53935;
      box-shadow: 0 0 0 8px rgba(255, 202, 40, 0.35), 0 4px 14px rgba(0,0,0,0.55);
      font-size: 20px;
    }
    .destination-marker.is-selected .destination-label {
      background: #e53935;
      font-size: 13px;
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
    .guriang-popup {
      color: #0f172a;
      padding: 4px;
      font-family: inherit;
      min-width: 170px;
    }
    .popup-title {
      font-size: 13px;
      font-weight: bold;
      margin-bottom: 4px;
      color: #1b5e20;
    }
    .popup-desc {
      font-size: 11px;
      color: #475569;
      margin-bottom: 8px;
      line-height: 1.3;
    }
    .popup-actions {
      display: flex;
      gap: 6px;
      justify-content: flex-end;
    }
    .popup-actions button {
      border: none;
      padding: 5px 9px;
      border-radius: 5px;
      font-size: 11px;
      cursor: pointer;
      font-weight: 600;
    }
    .popup-btn-cancel {
      background: #f1f5f9;
      color: #475569;
    }
    .popup-btn-confirm {
      background: #2e7d32;
      color: white;
    }
    .maplibregl-popup-content {
      border-radius: 10px;
      box-shadow: 0 4px 14px rgba(0,0,0,0.25);
      padding: 10px 12px;
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
            tileSize: 256,
            maxzoom: 15
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
    let pendingFocus = null;
    let mapLoaded = false;
    const natureEmojis = {
      'Gunung': '🏔️',
      'Danau': '🏞️',
      'Kawah': '🌋',
      'Laut': '🌊',
      'Air Terjun': '💦',
      'Lubuk': '💧'
    };

    function updateDestinations(dests) {
      currentMarkers.forEach(m => m.remove());
      currentMarkers = [];

      dests.forEach(d => {
        const el = document.createElement('div');
        el.className = 'destination-marker' + (d.isSelected ? ' is-selected' : '');

        const label = document.createElement('div');
        label.className = 'destination-label';
        label.textContent = d.name;
        el.appendChild(label);

        const pin = document.createElement('div');
        pin.className = 'custom-marker ' +
          (d.isCulture ? 'culture-marker' : 'nature-marker');
        pin.textContent = d.isCulture
          ? '🏛️'
          : (natureEmojis[d.category] || '🌿');
        pin.title = d.category || (d.isCulture ? 'Budaya' : 'Alam');
        el.appendChild(pin);

        function triggerOpenDirections(id) {
          if (window.MapBridge) {
            MapBridge.postMessage(String(id));
          }
          const msg = JSON.stringify({channel: '$channel', kind: 'destination', id: id});
          try { window.parent.postMessage(msg, '*'); } catch(_) {}
          try { window.top.postMessage(msg, '*'); } catch(_) {}
        }

        const popupContent = document.createElement('div');
        popupContent.className = 'guriang-popup';
        popupContent.innerHTML = `
          <div class="popup-title">\${d.name}</div>
          <div class="popup-desc">Buka rute destinasi ini di Google Maps?</div>
          <div class="popup-actions">
            <button class="popup-btn-cancel" id="btn-cancel-\${d.id}">Batal</button>
            <button class="popup-btn-confirm" id="btn-confirm-\${d.id}">Ya, Buka</button>
          </div>
        `;

        const popup = new maplibregl.Popup({ offset: 25, closeButton: false })
          .setDOMContent(popupContent);

        popup.on('open', () => {
          const btnConfirm = document.getElementById('btn-confirm-' + d.id);
          const btnCancel = document.getElementById('btn-cancel-' + d.id);
          if (btnConfirm) {
            btnConfirm.onclick = () => {
              triggerOpenDirections(d.id);
              popup.remove();
            };
          }
          if (btnCancel) {
            btnCancel.onclick = () => {
              popup.remove();
            };
          }
        });

        el.onclick = (e) => {
          e.stopPropagation();
          triggerOpenDirections(d.id);
        };

        const marker = new maplibregl.Marker({ element: el, anchor: 'bottom' })
          .setLngLat([d.lng, d.lat])
          .setPopup(popup)
          .addTo(map);

        currentMarkers.push(marker);
      });
    }

    function focusDestination(lat, lng, focusKey) {
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) return;
      if (!mapLoaded) {
        pendingFocus = { latitude: lat, longitude: lng, focusKey };
        return false;
      }
      pendingFocus = null;
      map.stop();
      map.resize();
      map.flyTo({
        center: [lng, lat],
        zoom: 16.5,
        pitch: 0,
        bearing: 0,
        curve: 1.9,
        offset: [0, -map.getContainer().clientHeight * 0.12],
        duration: 3200,
        easing: t => t * (2 - t),
        essential: true
      });
      window.lastFocusKey = focusKey;
      window.parent.postMessage(
        JSON.stringify({
          channel: webChannel,
          kind: 'stateApplied',
          focusKey
        }),
        '*'
      );
      return true;
    }

    map.on('load', () => {
      mapLoaded = true;
      if (pendingFocus) {
        const focus = pendingFocus;
        focusDestination(focus.latitude, focus.longitude, focus.focusKey);
      }
      if (window.MapReady) MapReady.postMessage('ready');
    });

    const webChannel = '$channel';
    const initialDestinations = $initialDestinationsJson;
    new ResizeObserver(() => map.resize()).observe(document.getElementById('map'));
    if (webChannel) {
      map.on('load', () => {
        updateDestinations(initialDestinations);
        window.parent.postMessage(
          JSON.stringify({channel: webChannel, kind: 'ready'}),
          '*'
        );
      });
      window.addEventListener('message', event => {
        if (event.source !== window.parent ||
            typeof event.data !== 'string') return;
        let message;
        try {
          message = JSON.parse(event.data);
        } catch (_) {
          return;
        }
        if (message.channel !== webChannel) return;
        if (message.kind === 'state') {
          const stateKey = JSON.stringify(message);
          if (stateKey !== window.lastAppliedState) {
            window.lastAppliedState = stateKey;
            updateDestinations(message.destinations);
          }
          if (message.latitude != null && message.longitude != null &&
              message.focusKey !== window.lastFocusKey) {
            map.stop();
            map.resize();
            if (!focusDestination(
                message.latitude, message.longitude, message.focusKey)) {
              return;
            }
          }
          window.parent.postMessage(
            JSON.stringify({
              channel: webChannel,
              kind: 'stateApplied',
              focusKey: message.focusKey
            }),
            '*'
          );
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
    final focusTarget = _mapFocusTarget(state, list);
    final mapDestinations = _destinationsForMap(list, focusTarget);

    return Stack(
      children: [
        Positioned.fill(
          child: kIsWeb
              ? IgnorePointer(
                  ignoring: _isConfirmationOpen,
                  child: MapLibre3DWebView(
                    key: ValueKey(_webMapChannel),
                    channel: _webMapChannel,
                    destinations: _mapDestinations(
                      mapDestinations,
                      selectedId: focusTarget?.id,
                    ),
                    html: _buildCesium3DHtml(
                      webChannel: _webMapChannel,
                      initialDestinations: _mapDestinations(
                        mapDestinations,
                        selectedId: focusTarget?.id,
                      ),
                    ),
                    selectedLatitude: focusTarget?.latitude,
                    selectedLongitude: focusTarget?.longitude,
                    focusKey:
                        '${state.query.trim()}:${focusTarget?.id}:${widget.isActive}',
                    onDestinationTap: _onWebMapMessage,
                    isInteractive: !_isConfirmationOpen,
                  ),
                )
              : _webViewController != null
                  ? WebViewWidget(controller: _webViewController!)
                  : const Center(child: CircularProgressIndicator()),
        ),
        Positioned(
          top: 8,
          right: 12,
          child: Material(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            elevation: 4,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.public, size: 16, color: AppColors.green),
                  SizedBox(width: 5),
                  Text(
                    'PETA 3D',
                    style: TextStyle(
                      color: AppColors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: 0.28,
          minChildSize: 0.18,
          maxChildSize: 0.75,
          snap: true,
          snapSizes: const [0.28, 0.75],
          builder: (context, scrollController) => PointerInterceptor(
            child: Material(
              color: Colors.white,
              elevation: 5,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  InkWell(
                    onTap: _toggleSheet,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _sheetController.isAttached &&
                                    _sheetController.size > 0.35
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_up,
                            size: 20,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ),
                  ),
                  CategoryChips(onSubtypeDropdownTap: _expandCategorySheet),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
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
                              openDetail(context, d);
                              _select(d);
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
        ),
      ],
    );
  }
}
