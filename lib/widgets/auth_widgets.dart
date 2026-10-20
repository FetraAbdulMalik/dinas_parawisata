import 'dart:ui' show ImageFilter;

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
      body: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Image.asset(
                'assets/images/gunung_papandayan.jpg',
                fit: BoxFit.cover,
                semanticLabel: 'Pemandangan Gunung Papandayan',
              ),
          ),
          const ColoredBox(color: Color(0x33000000)),
          SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Image.asset(
                                'assets/images/logo_kabupaten_garut_transparent.png',
                                width: 48,
                                height: 48,
                                fit: BoxFit.contain,
                                semanticLabel: 'Lambang Kabupaten Garut',
                              ),
                              const SizedBox(width: 10),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dinas Pariwisata',
                                    style: TextStyle(
                                      color: AppColors.text,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Layanan pariwisata digital',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            heading,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            description,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                              boxShadow: softShadow(),
                            ),
                            child: form,
                          ),
                          const SizedBox(height: 14),
                          Center(child: bottom),
                          const SizedBox(height: 28),
                          const Center(
                            child: Text(
                              'Butuh bantuan? Hubungi kami\nDinas Pariwisata · Layanan untuk masyarakat',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ),
        ],
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
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.48),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.9)),
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
