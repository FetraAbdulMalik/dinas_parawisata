import 'package:flutter/material.dart';

import '../theme.dart';

class CopyrightFooter extends StatelessWidget {
  const CopyrightFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(12, 20, 12, 12),
      child: Center(
        child: Text(
          '© 2026 Fetra Abdul Malik & dinas parawisata kabupaten garut',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 8, color: AppColors.muted),
        ),
      ),
    );
  }
}
