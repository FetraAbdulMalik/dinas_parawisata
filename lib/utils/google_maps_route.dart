import '../models/destination.dart';

Uri googleMapsDirectionsUri(Destination destination) => Uri.https(
      'www.google.com',
      '/maps/dir/',
      {
        'api': '1',
        'destination': '${destination.latitude},${destination.longitude}',
        'travelmode': 'driving',
      },
    );

Uri googleMapsLocationUri(Destination destination) => Uri.https(
      'www.google.com',
      '/maps/search/',
      {
        'api': '1',
        'query': '${destination.latitude},${destination.longitude}',
      },
    );
