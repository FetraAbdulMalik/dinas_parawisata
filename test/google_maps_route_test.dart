import 'package:flutter_test/flutter_test.dart';
import 'package:guriang_garut/models/destination.dart';
import 'package:guriang_garut/utils/google_maps_route.dart';

void main() {
  test('builds Google Maps directions URL for a destination', () {
    const destination = Destination(
      id: 1,
      name: 'Gunung Papandayan',
      category: 'Alam',
      location: 'Garut',
      description: '',
      history: '',
      latitude: -7.32,
      longitude: 107.73,
    );

    final uri = googleMapsDirectionsUri(destination);

    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters, {
      'api': '1',
      'destination': '-7.32,107.73',
      'travelmode': 'driving',
    });
  });

  test('builds Google Maps location URL for a destination', () {
    const destination = Destination(
      id: 1,
      name: 'Gunung Papandayan',
      category: 'Alam',
      location: 'Garut',
      description: '',
      history: '',
      latitude: -7.32,
      longitude: 107.73,
    );

    final uri = googleMapsLocationUri(destination);

    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/search/');
    expect(uri.queryParameters, {
      'api': '1',
      'query': '-7.32,107.73',
    });
  });
}
