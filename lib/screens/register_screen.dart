import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme.dart';
import '../utils/password_policy.dart';
import '../widgets/auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final error = await context
        .read<AppState>()
        .register(_name.text, _email.text, _password.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Daftar',
      showBack: true,
      heading: 'Buat akun Anda',
      description:
          'Daftar untuk mengelola profil dan menyimpan destinasi wisata pilihan Anda.',
      form: Form(
        key: _formKey,
        child: Column(
          children: [
            AuthField(
              label: 'Nama lengkap',
              hint: 'Masukkan nama lengkap',
              controller: _name,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Nama wajib diisi'
                  : null,
            ),
            AuthField(
              label: 'Email',
              hint: 'Masukkan email Anda',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Email tidak valid' : null,
            ),
            AuthField(
              label: 'Kata sandi',
              hint: 'Buat kata sandi',
              controller: _password,
              password: true,
              helper: 'Minimal 8 karakter dan sertakan karakter khusus (!@#).',
              validator: validatePassword,
            ),
            AuthField(
              label: 'Konfirmasi kata sandi',
              hint: 'Ulangi kata sandi',
              controller: _confirm,
              password: true,
              validator: (v) =>
                  v != _password.text ? 'Kata sandi tidak sama' : null,
            ),
            const SizedBox(height: 6),
            GreenButton(
                label: _loading ? 'Memproses...' : 'Daftar',
                onPressed: _loading ? null : _submit),
          ],
        ),
      ),
      bottom: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Sudah punya akun? ',
              style: TextStyle(fontSize: 12, color: AppColors.muted)),
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Text('Masuk',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.green,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
