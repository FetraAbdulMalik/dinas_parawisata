import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme.dart';
import '../widgets/auth_widgets.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final error =
        await context.read<AppState>().login(_email.text, _password.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Masuk',
      showBack: false,
      heading: 'Selamat datang kembali',
      description:
          'Masuk untuk membuka peta dan menyimpan destinasi favorit.',
      form: Form(
        key: _formKey,
        child: Column(
          children: [
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
              hint: 'Masukkan kata sandi',
              controller: _password,
              password: true,
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Kata sandi wajib diisi' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Hubungi Dinas Pariwisata untuk mengatur ulang kata sandi.')),
                ),
                child: const Text('Lupa kata sandi?',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.green,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 18),
            GreenButton(
                label: _loading ? 'Memproses...' : 'Masuk',
                onPressed: _loading ? null : _submit),
          ],
        ),
      ),
      bottom: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Belum punya akun? ',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
              GestureDetector(
                onTap: () async {
                  final navigator = Navigator.of(context);
                  final appState = context.read<AppState>();
                  await navigator.push(MaterialPageRoute(
                      builder: (_) => const RegisterScreen()));
                  if (!mounted) return;
                  if (appState.user != null && navigator.canPop()) {
                    navigator.pop();
                  }
                },
                child: const Text('Daftar',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.green,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Data akun Anda digunakan untuk layanan aplikasi dan dijaga kerahasiaannya.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
