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
      );

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
      };

  Destination copyWith({
    String? imageUrl,
    String? videoUrl,
  }) =>
      Destination(
        id: id,
        name: name,
        category: category,
        location: location,
        description: description,
        history: history,
        latitude: latitude,
        longitude: longitude,
        imageUrl: imageUrl ?? this.imageUrl,
        imageAsset: imageAsset,
        audioAsset: audioAsset,
        videoAsset: videoAsset,
        videoUrl: videoUrl ?? this.videoUrl,
      );

  /// Teks yang dibacakan (suara otomatis) bila file audio belum tersedia.
  String get narration =>
      history.isEmpty ? description : '$description $history';
}
