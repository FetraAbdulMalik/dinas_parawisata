import '../models/destination.dart';

/// Membuka Google Maps dengan rute menuju koordinat destinasi.
/// Menggunakan path /maps/dir/ dan parameter 'destination' agar Google Maps
/// menampilkan rute perjalanan ke titik yang ditentukan.
Uri googleMapsDirectionsUri(Destination destination) => Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}&travelmode=driving',
    );

/// Menampilkan pin marker merah persis di titik koordinat yang ditentukan.
Uri googleMapsLocationUri(Destination destination) => Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${destination.latitude},${destination.longitude}',
    );
