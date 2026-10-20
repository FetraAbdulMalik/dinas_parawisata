import 'package:flutter/material.dart';

import '../theme.dart';

class CopyrightFooter extends StatelessWidget {
  const CopyrightFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final logoHeight = constraints.maxWidth < 220 ? 30.0 : 42.0;
          final authorityWidth = logoHeight * 1.45;
          final departmentWidth = logoHeight * 3.7;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 10,
                children: [
                  Image.asset(
                    'assets/images/logo_kabupaten_garut_transparent.png',
                    width: authorityWidth,
                    height: logoHeight,
                    fit: BoxFit.contain,
                    semanticLabel: 'Logo Pemerintah Kabupaten Garut',
                  ),
                  Image.asset(
                    'assets/images/logo_disparbud_garut_transparent.png',
                    width: departmentWidth,
                    height: logoHeight,
                    fit: BoxFit.contain,
                    semanticLabel: 'Logo Dinas Pariwisata dan Kebudayaan Garut',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                '© 2026 Fetra Abdul Malik & dinas parawisata kabupaten garut',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 8, color: AppColors.muted),
              ),
            ],
          );
        },
      ),
    );
  }
}
