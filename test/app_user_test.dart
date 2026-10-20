import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:guriang_garut/models/app_user.dart';

void main() {
  test('reads a cached profile photo and preserves it when the name changes',
      () {
    final photo = Uint8List.fromList([1, 2, 3]);
    final user = AppUser.fromMap({
      'id': 4,
      'name': 'Garut',
      'email': 'garut@example.com',
      'auth_uid': 'user-uid',
      'avatar_url': 'https://example.com/avatar',
      'avatar_image': photo,
    });

    final renamedUser = user.copyWith(name: 'Guriang');

    expect(renamedUser.name, 'Guriang');
    expect(renamedUser.avatarUrl, user.avatarUrl);
    expect(renamedUser.avatarBytes, photo);
  });
}
