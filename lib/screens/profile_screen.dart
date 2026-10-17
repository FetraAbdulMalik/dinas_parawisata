import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme.dart';
import '../widgets/copyright_footer.dart';
import 'faq_screen.dart';
import 'privacy_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editName(BuildContext context) async {
    final state = context.read<AppState>();
    final ctl = TextEditingController(text: state.user?.name ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: TextField(
          controller: ctl,
          decoration: const InputDecoration(labelText: 'Nama lengkap'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctl.text),
              child: const Text('Simpan')),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await state.updateName(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;

    Widget item(String label, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.white,
            elevation: 2,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(label,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600))),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Center(
          child: CircleAvatar(
            radius: 65,
            backgroundColor: AppColors.green,
            child: Text(
              (user?.name.isNotEmpty ?? false)
                  ? user!.name[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  fontSize: 56,
                  color: Colors.white,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(user?.name ?? '',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _editName(context),
              child: const Icon(Icons.edit, size: 18),
            ),
          ],
        ),
        Center(
          child: Text(user?.email ?? '',
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ),
        if (state.serviceMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            state.serviceMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.deepOrange),
          ),
        ],
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              item('Edit Profile', () => _editName(context)),
              item(
                  'pengaturan privasi',
                  () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const PrivacyScreen()))),
              item(
                  'FAQ',
                  () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FaqScreen()))),
              if (state.isContentAdmin)
                item('Kirim foto, video, dan daftar ke Supabase', () async {
                  try {
                    await context.read<AppState>().publishLocalDestinations();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Foto, video, dan daftar destinasi berhasil dikirim.',
                          ),
                        ),
                      );
                    }
                  } on Exception catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Gagal mengirim destinasi: $error'),
                        ),
                      );
                    }
                  }
                }),
              item('keluar', () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Keluar'),
                    content: const Text('Anda yakin ingin keluar dari akun?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Batal')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Keluar')),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  await context.read<AppState>().logout();
                }
              }),
            ],
          ),
        ),
        const CopyrightFooter(),
      ],
    );
  }
}
