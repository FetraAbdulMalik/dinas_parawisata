import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../theme.dart';

Future<bool?> showPopupKonfirmasi(
  BuildContext context, {
  String? pesan,
  String? judul,
  Widget? konten,
  bool barrierDismissible = false,
  String cancelLabel = 'TIDAK',
  String confirmLabel = 'IYA',
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    animationStyle: appDialogAnimationStyle,
    builder: (_) => PopupKonfirmasi(
      judul: judul,
      pesan: pesan,
      konten: konten,
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
    ),
  );
}

Future<bool> showConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String cancelLabel = 'TIDAK',
  String confirmLabel = 'IYA',
}) async {
  return await showPopupKonfirmasi(
        context,
        judul: title,
        pesan: message,
        cancelLabel: cancelLabel,
        confirmLabel: confirmLabel,
      ) ??
      false;
}

class PopupKonfirmasi extends StatelessWidget {
  const PopupKonfirmasi({
    super.key,
    this.judul,
    this.pesan,
    this.konten,
    this.cancelLabel = 'TIDAK',
    this.confirmLabel = 'IYA',
  });

  final String? judul;
  final String? pesan;
  final Widget? konten;
  final String cancelLabel;
  final String confirmLabel;

  static const Color _hijau = Color(0xFF59A845);

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 48,
          vertical: 24,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  children: [
                    _logo(
                      'assets/images/logo_kabupaten_garut_transparent.png',
                      height: 28,
                    ),
                    const SizedBox(width: 12),
                    _logo(
                      'assets/images/logo_disparbud_garut_transparent.png',
                      height: 22,
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 80),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    child: konten ??
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (judul != null) ...[
                              Text(
                                judul!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              if (pesan != null && pesan!.isNotEmpty)
                                const SizedBox(height: 8),
                            ],
                            if (pesan != null && pesan!.isNotEmpty)
                              Text(
                                pesan!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: judul == null
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: Colors.black87,
                                ),
                              ),
                          ],
                        ),
                  ),
                ),
              ),
              _tombol(context, confirmLabel, true),
              const SizedBox(height: 8),
              _tombol(context, cancelLabel, false),
              const SizedBox(height: 8),
              const Text(
                '© fetra abdul malik & dinas parawisata\nkab garut',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logo(String path, {required double height}) {
    return Image.asset(
      path,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => SizedBox(
        height: height,
        width: height * 1.5,
        child: const Icon(
          Icons.image_not_supported_outlined,
          size: 18,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _tombol(BuildContext context, String label, bool value) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).pop(value),
        style: ElevatedButton.styleFrom(
          backgroundColor: _hijau,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
