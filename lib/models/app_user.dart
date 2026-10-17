class AppUser {
  final int id;
  final String name;
  final String email;
  final String? authUid;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.authUid,
  });

  factory AppUser.fromMap(Map<String, Object?> m) => AppUser(
        id: m['id'] as int,
        name: m['name'] as String,
        email: m['email'] as String,
        authUid: m['auth_uid'] as String?,
      );
}
