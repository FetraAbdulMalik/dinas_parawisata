import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/destination.dart';
import '../theme.dart';

class GarutWeatherCard extends StatefulWidget {
  const GarutWeatherCard({super.key});

  @override
  State<GarutWeatherCard> createState() => _GarutWeatherCardState();
}

class _GarutWeatherCardState extends State<GarutWeatherCard> {
  late final Future<_Weather> _weather = _loadWeather();

  Future<_Weather> _loadWeather() async {
    final uri = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      {
        'latitude': '-7.216',
        'longitude': '107.902',
        'current': 'temperature_2m,relative_humidity_2m,weather_code',
        'timezone': 'Asia/Jakarta',
      },
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('Layanan cuaca membalas ${response.statusCode}.');
    }
    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic> || json['current'] is! Map) {
      throw const FormatException('Data cuaca tidak sesuai format.');
    }
    final current = Map<String, dynamic>.from(json['current'] as Map);
    return _Weather(
      temperature: (current['temperature_2m'] as num).toDouble(),
      humidity: (current['relative_humidity_2m'] as num).toInt(),
      conditionCode: (current['weather_code'] as num).toInt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _InsightCard(
      title: 'Cuaca Garut',
      child: FutureBuilder<_Weather>(
        future: _weather,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text(
              'Cuaca belum dapat dimuat. Periksa koneksi internet.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            );
          }
          if (!snapshot.hasData) {
            return const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('Memuat cuaca Garut...'),
              ],
            );
          }
          final weather = snapshot.data!;
          return Row(
            children: [
              Icon(_weatherIcon(weather.conditionCode),
                  size: 38, color: AppColors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${weather.temperature.round()}°C · ${_weatherDescription(weather.conditionCode)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Kelembapan ${weather.humidity}% · Open-Meteo',
                      style:
                          const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Weather {
  final double temperature;
  final int humidity;
  final int conditionCode;

  const _Weather({
    required this.temperature,
    required this.humidity,
    required this.conditionCode,
  });
}

IconData _weatherIcon(int code) {
  if (code == 0) return Icons.wb_sunny_outlined;
  if (code <= 3) return Icons.cloud_outlined;
  if (code <= 48) return Icons.foggy;
  if (code <= 67 || (code >= 80 && code <= 82)) {
    return Icons.water_drop_outlined;
  }
  if (code >= 95) return Icons.thunderstorm_outlined;
  return Icons.cloud_outlined;
}

String _weatherDescription(int code) {
  if (code == 0) return 'Cerah';
  if (code <= 3) return 'Berawan';
  if (code <= 48) return 'Berkabut';
  if (code <= 57) return 'Gerimis';
  if (code <= 67) return 'Hujan';
  if (code <= 77) return 'Salju';
  if (code <= 82) return 'Hujan lokal';
  if (code <= 86) return 'Hujan salju';
  if (code <= 99) return 'Hujan petir';
  return 'Kondisi tidak diketahui';
}

class DestinationMiniMap extends StatelessWidget {
  final List<Destination> destinations;
  final ValueChanged<Destination> onTap;

  const DestinationMiniMap({
    super.key,
    required this.destinations,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _InsightCard(
      title: 'Peta Destinasi Garut',
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FlutterMap(
                options: const MapOptions(
                  initialCenter: LatLng(-7.216, 107.902),
                  initialZoom: 8.2,
                  interactionOptions: InteractionOptions(
                    flags: InteractiveFlag.drag |
                        InteractiveFlag.pinchZoom |
                        InteractiveFlag.doubleTapZoom |
                        InteractiveFlag.scrollWheelZoom,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'id.go.garut.guriang_garut',
                  ),
                  MarkerLayer(
                    markers: [
                      for (final destination in destinations)
                        Marker(
                          point: LatLng(
                            destination.latitude,
                            destination.longitude,
                          ),
                          width: 30,
                          height: 36,
                          child: Tooltip(
                            message: destination.name,
                            child: GestureDetector(
                              onTap: () => onTap(destination),
                              child: const Icon(
                                Icons.location_on,
                                color: AppColors.green,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              '© OpenStreetMap contributors',
              style: TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _InsightCard({required this.title, required this.child});

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
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
