import 'package:flutter/material.dart';

import '../theme.dart';

/// Kerangka layar Masuk/Daftar sesuai desain.
class AuthScaffold extends StatelessWidget {
  final String title;
  final bool showBack;
  final String heading;
  final String description;
  final Widget form;
  final Widget bottom;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.showBack,
    required this.heading,
    required this.description,
    required this.form,
    required this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        automaticallyImplyLeading: false,
        leading: showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        title: Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/images/logo_kabupaten_garut_transparent.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.contain,
                    semanticLabel: 'Lambang Kabupaten Garut',
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 82,
                    height: 38,
                    child: Image.asset(
                      'assets/images/logo_disparbud_garut_transparent.png',
                      fit: BoxFit.contain,
                      semanticLabel: 'Logo Disparbud Garut',
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dinas Pariwisata',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        Text('Layanan pariwisata digital',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(heading,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(description,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: softShadow(),
                ),
                child: form,
              ),
              const SizedBox(height: 20),
              Center(child: bottom),
              const SizedBox(height: 28),
              const Center(
                child: Text(
                  'Butuh bantuan? Hubungi kami\nDinas Pariwisata · Layanan untuk masyarakat',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool password;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final String? helper;

  const AuthField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.password = false,
    this.keyboardType,
    this.validator,
    this.helper,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: widget.controller,
            obscureText: widget.password && _hidden,
            keyboardType: widget.keyboardType,
            validator: widget.validator,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E5EA)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.green),
              ),
              suffixIcon: widget.password
                  ? IconButton(
                      icon: Icon(
                          _hidden ? Icons.visibility_off : Icons.visibility,
                          size: 20),
                      onPressed: () => setState(() => _hidden = !_hidden),
                    )
                  : null,
            ),
          ),
          if (widget.helper != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(widget.helper!,
                  style: const TextStyle(fontSize: 10, color: AppColors.muted)),
            ),
        ],
      ),
    );
  }
}

class GreenButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const GreenButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
