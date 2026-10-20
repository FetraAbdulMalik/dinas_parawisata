import 'dart:typed_data';

class AppUser {
  final int id;
  final String name;
  final String email;
  final String? authUid;
  final String? avatarUrl;
  final Uint8List? avatarBytes;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.authUid,
    this.avatarUrl,
    this.avatarBytes,
  });

  factory AppUser.fromMap(Map<String, Object?> m) => AppUser(
        id: m['id'] as int,
        name: m['name'] as String,
        email: m['email'] as String,
        authUid: m['auth_uid'] as String?,
        avatarUrl: m['avatar_url'] as String?,
        avatarBytes: m['avatar_image'] as Uint8List?,
      );

  AppUser copyWith({
    String? name,
    String? avatarUrl,
    Uint8List? avatarBytes,
    bool clearAvatarUrl = false,
  }) =>
      AppUser(
        id: id,
        name: name ?? this.name,
        email: email,
        authUid: authUid,
        avatarUrl: clearAvatarUrl ? null : avatarUrl ?? this.avatarUrl,
        avatarBytes: avatarBytes ?? this.avatarBytes,
      );
}
