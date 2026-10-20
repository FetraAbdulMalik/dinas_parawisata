import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class MapLibre3DWebView extends StatefulWidget {
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
  State<MapLibre3DWebView> createState() => _MapLibre3DWebViewState();
}

class _MapLibre3DWebViewState extends State<MapLibre3DWebView> {
  static int _nextViewId = 0;

  late final String _viewType;
  late final web.EventListener _messageListener;
  web.HTMLIFrameElement? _frame;
  bool _ready = false;
  String? _lastState;
  Timer? _stateRetryTimer;
  Timer? _focusDebounceTimer;

  @override
  void initState() {
    super.initState();
    _viewType = 'guriang-maplibre-3d-${_nextViewId++}';
    _messageListener = ((web.Event event) {
      if (event is web.MessageEvent) _handleMessage(event);
    }).toJS;
    web.window.addEventListener('message', _messageListener);
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (viewId) {
      final frame = web.HTMLIFrameElement()
        ..style.cssText =
            'border: 0; width: 100%; height: 100%; pointer-events: ${widget.isInteractive ? 'auto' : 'none'};'
        ..setAttribute('title', 'Peta 3D Guriang Garut')
        ..srcdoc = widget.html.toJS;
      _frame = frame;
      return frame;
    });
  }

  @override
  void didUpdateWidget(covariant MapLibre3DWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isInteractive != widget.isInteractive) {
      _frame?.style.pointerEvents = widget.isInteractive ? 'auto' : 'none';
    }
    if (oldWidget.focusKey != widget.focusKey ||
        oldWidget.selectedLatitude != widget.selectedLatitude ||
        oldWidget.selectedLongitude != widget.selectedLongitude) {
      _stateRetryTimer?.cancel();
      _stateRetryTimer = null;
      _focusDebounceTimer?.cancel();
      _focusDebounceTimer = Timer(
        const Duration(milliseconds: 600),
        _sendState,
      );
    } else {
      _sendState();
    }
  }

  void _handleMessage(web.MessageEvent event) {
    final payload = event.data?.dartify();
    if (payload is! String) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['channel'] != widget.channel) {
      return;
    }

    if (decoded['kind'] == 'ready') {
      _ready = true;
      _sendState();
    } else if (decoded['kind'] == 'stateApplied' &&
        decoded['focusKey'] == widget.focusKey) {
      _stateRetryTimer?.cancel();
      _stateRetryTimer = null;
    } else if (decoded['kind'] == 'destination' && decoded['id'] is num) {
      widget.onDestinationTap((decoded['id'] as num).toInt());
    }
  }

  void _sendState() {
    if (!_ready) return;
    final state = jsonEncode({
      'channel': widget.channel,
      'kind': 'state',
      'destinations': widget.destinations,
      'latitude': widget.selectedLatitude,
      'longitude': widget.selectedLongitude,
      'focusKey': widget.focusKey,
    });
    if (state == _lastState) return;
    _lastState = state;
    _stateRetryTimer?.cancel();
    var attempts = 0;
    void sendState() {
      _frame?.contentWindow?.postMessage(state.toJS, '*'.toJS);
      attempts++;
      if (attempts >= 20) {
        _stateRetryTimer?.cancel();
        _stateRetryTimer = null;
      }
    }

    sendState();
    _stateRetryTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => sendState(),
    );
  }

  @override
  void dispose() {
    _stateRetryTimer?.cancel();
    _focusDebounceTimer?.cancel();
    web.window.removeEventListener('message', _messageListener);
    _frame?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
