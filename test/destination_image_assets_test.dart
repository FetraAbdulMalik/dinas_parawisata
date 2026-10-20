import 'package:flutter_test/flutter_test.dart';
import 'package:guriang_garut/utils/destination_image_assets.dart';

void main() {
  const assets = {
    'assets/images/gunung_papandayan.jpg',
    'assets/images/talaga_bodas.jpg',
    'assets/images/situ_bangendit.jpg',
    'assets/images/logo_guriang_garut.png',
  };

  test('matches image filenames to destination names', () {
    expect(
      findDestinationImageAsset('Gunung Papandayan', assets),
      'assets/images/gunung_papandayan.jpg',
    );
  });

  test('uses explicit aliases when asset and destination names differ', () {
    expect(
      findDestinationImageAsset('Kawah Talaga Bodas', assets),
      'assets/images/talaga_bodas.jpg',
    );
    expect(
      findDestinationImageAsset('Situ Bagendit', assets),
      'assets/images/situ_bangendit.jpg',
    );
  });

  test('maps each image asset to its matching destination', () {
    const destinations = {
      'Candi Cangkuang': 'assets/images/candi_cangkuang.jpg',
      'Situ Cangkuang': 'assets/images/situ_cangkuang.jpg',
      'Kawah Talaga Bodas': 'assets/images/talaga_bodas.jpg',
      'Gunung Papandayan': 'assets/images/gunung_papandayan.jpg',
      'Situ Bagendit': 'assets/images/situ_bangendit.jpg',
      'Kampung Pulo': 'assets/images/kampung_pulo.jpg',
      'Pantai Santolo': 'assets/images/pantai_santolo.jpeg',
      'Lais': 'assets/images/lais.jpg',
      'Surak Ibra': 'assets/images/surak_ibra.jpg',
      'Badeng': 'assets/images/badeng.jpg',
    };

    for (final entry in destinations.entries) {
      final availableAssets = {...assets, entry.value};
      expect(
        findDestinationImageAsset(entry.key, availableAssets),
        entry.value,
        reason: 'Expected image asset for ${entry.key}',
      );
    }
  });

  test('does not assign an unrelated logo to a destination', () {
    expect(findDestinationImageAsset('Pantai Santolo', assets), isNull);
  });
}
