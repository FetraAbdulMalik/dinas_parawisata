import 'package:flutter_test/flutter_test.dart';
import 'package:guriang_garut/utils/password_policy.dart';

void main() {
  test('requires at least eight characters', () {
    expect(validatePassword('abc!123'), isNotNull);
  });

  test('requires a special character', () {
    expect(validatePassword('abcdefgh'), isNotNull);
  });

  test('accepts a long password with a special character', () {
    expect(validatePassword('garut!123'), isNull);
  });
}
