String? validatePassword(String? password) {
  if (password == null || password.length < 8) {
    return 'Kata sandi minimal 8 karakter.';
  }
  if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
    return 'Sertakan minimal satu karakter khusus, misalnya !, @, atau #.';
  }
  return null;
}
