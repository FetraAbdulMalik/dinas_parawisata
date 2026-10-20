class Destination {
  final int id;
  final String name;
  final String category;
  final String location;
  final String description;
  final String history;
  final double latitude;
  final double longitude;
  final String imageUrl;
  final String imageAsset;
  final String videoUrl;
  final String openingHours;
  final String ticketPrice;
  final String facilities;
  final String contact;
  final String noSkBupati;
  final DateTime? practicalInfoUpdatedAt;

  /// Path file di folder assets, mis. `assets/audio/candi_cangkuang.mp3`.
  final String audioAsset;
  final String videoAsset;

  const Destination({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.description,
    required this.history,
    required this.latitude,
    required this.longitude,
    this.imageUrl = '',
    this.imageAsset = '',
    this.audioAsset = '',
    this.videoAsset = '',
    this.videoUrl = '',
    this.openingHours = '',
    this.ticketPrice = '',
    this.facilities = '',
    this.contact = '',
    this.noSkBupati = '',
    this.practicalInfoUpdatedAt,
  });

  factory Destination.fromMap(Map<String, Object?> m) => Destination(
        id: m['id'] as int,
        name: m['name'] as String,
        category: m['category'] as String,
        location: m['location'] as String,
        description: m['description'] as String,
        history: (m['history'] as String?) ?? '',
        latitude: (m['latitude'] as num).toDouble(),
        longitude: (m['longitude'] as num).toDouble(),
        imageUrl: (m['image_url'] as String?) ?? '',
        imageAsset: (m['image_asset'] as String?) ?? '',
        audioAsset: (m['audio_asset'] as String?) ?? '',
        videoAsset: (m['video_asset'] as String?) ?? '',
        videoUrl: (m['video_url'] as String?) ?? '',
        openingHours: (m['opening_hours'] as String?) ?? '',
        ticketPrice: (m['ticket_price'] as String?) ?? '',
        facilities: (m['facilities'] as String?) ?? '',
        contact: (m['contact'] as String?) ?? '',
        noSkBupati: (m['no_sk_bupati'] as String?) ?? '',
        practicalInfoUpdatedAt: _dateTime(m['practical_info_updated_at']),
      );

  static DateTime? _dateTime(Object? value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'location': location,
        'description': description,
        'history': history,
        'latitude': latitude,
        'longitude': longitude,
        'image_url': imageUrl,
        'image_asset': imageAsset,
        'audio_asset': audioAsset,
        'video_asset': videoAsset,
        'video_url': videoUrl,
        'opening_hours': openingHours,
        'ticket_price': ticketPrice,
        'facilities': facilities,
        'contact': contact,
        'no_sk_bupati': noSkBupati,
        'practical_info_updated_at':
            practicalInfoUpdatedAt?.toUtc().toIso8601String(),
      };

  Destination copyWith({
    int? id,
    String? name,
    String? category,
    String? location,
    String? description,
    String? history,
    double? latitude,
    double? longitude,
    String? imageUrl,
    String? imageAsset,
    String? audioAsset,
    String? videoAsset,
    String? videoUrl,
    String? openingHours,
    String? ticketPrice,
    String? facilities,
    String? contact,
    String? noSkBupati,
    DateTime? practicalInfoUpdatedAt,
  }) =>
      Destination(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        location: location ?? this.location,
        description: description ?? this.description,
        history: history ?? this.history,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        imageUrl: imageUrl ?? this.imageUrl,
        imageAsset: imageAsset ?? this.imageAsset,
        audioAsset: audioAsset ?? this.audioAsset,
        videoAsset: videoAsset ?? this.videoAsset,
        videoUrl: videoUrl ?? this.videoUrl,
        openingHours: openingHours ?? this.openingHours,
        ticketPrice: ticketPrice ?? this.ticketPrice,
        facilities: facilities ?? this.facilities,
        contact: contact ?? this.contact,
        noSkBupati: noSkBupati ?? this.noSkBupati,
        practicalInfoUpdatedAt:
            practicalInfoUpdatedAt ?? this.practicalInfoUpdatedAt,
      );

  /// Teks yang dibacakan (suara otomatis) bila file audio belum tersedia.
  String get narration =>
      history.isEmpty ? description : '$description $history';
}
