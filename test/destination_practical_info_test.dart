import 'package:flutter_test/flutter_test.dart';
import 'package:guriang_garut/models/destination.dart';

void main() {
  test('round-trips practical destination information', () {
    final updatedAt = DateTime.utc(2026, 10, 17, 10);
    final destination = Destination(
      id: 1,
      name: 'Candi Cangkuang',
      category: 'Cagar Budaya',
      location: 'Leles, Garut',
      description: '',
      history: '',
      latitude: -7.1033,
      longitude: 107.9172,
      openingHours: 'Setiap hari, 08.00–16.00',
      ticketPrice: 'Rp10.000',
      facilities: 'Parkir\nToilet',
      contact: '08123456789',
      noSkBupati: '188.45/123/Disparbud/2026',
      practicalInfoUpdatedAt: updatedAt,
    );

    final restored = Destination.fromMap(destination.toMap());

    expect(restored.openingHours, destination.openingHours);
    expect(restored.ticketPrice, destination.ticketPrice);
    expect(restored.facilities, destination.facilities);
    expect(restored.contact, destination.contact);
    expect(restored.noSkBupati, destination.noSkBupati);
    expect(restored.practicalInfoUpdatedAt, updatedAt);
  });
}
