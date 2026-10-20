import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/app_state.dart';
import '../theme.dart';
import '../utils/confirmation_dialog.dart';
import '../widgets/copyright_footer.dart';
import 'admin_destinations_screen.dart';
import 'faq_screen.dart';
import 'privacy_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _updatingPhoto = false;

  Future<void> _editName(BuildContext context) async {
    final state = context.read<AppState>();
    final ctl = TextEditingController(text: state.user?.name ?? '');
    final result = await showDialog<String>(
      context: context,
      animationStyle: appDialogAnimationStyle,
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

  Future<void> _changePhoto() async {
    final appState = context.read<AppState>();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kIsWeb ||
                defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Ambil foto'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final photo = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (photo == null) return;

      final bytes = await photo.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        throw StateError('Ukuran foto maksimal 5 MB.');
      }
      final contentType = _photoContentType(photo);

      setState(() => _updatingPhoto = true);
      await appState.updateProfilePhoto(
        bytes: bytes,
        contentType: contentType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto profil berhasil diperbarui.')),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memperbarui foto profil: $error')),
      );
    } finally {
      if (mounted) setState(() => _updatingPhoto = false);
    }
  }

  String _photoContentType(XFile photo) {
    final mimeType = photo.mimeType?.toLowerCase();
    if (mimeType == 'image/jpeg' ||
        mimeType == 'image/png' ||
        mimeType == 'image/webp') {
      return mimeType!;
    }
    final name = photo.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    throw StateError('Format foto harus JPG, PNG, atau WebP.');
  }

  Widget _avatarFallback(String name) {
    return CircleAvatar(
      radius: 65,
      backgroundColor: AppColors.green,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 56,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _avatarPhoto(String name, String? avatarUrl, Uint8List? avatarBytes) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          avatarUrl,
          width: 130,
          height: 130,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => avatarBytes == null
              ? _avatarFallback(name)
              : _localAvatarPhoto(name, avatarBytes),
        ),
      );
    }
    if (avatarBytes != null) return _localAvatarPhoto(name, avatarBytes);
    return _avatarFallback(name);
  }

  Widget _localAvatarPhoto(String name, Uint8List bytes) {
    return ClipOval(
      child: Image.memory(
        bytes,
        width: 130,
        height: 130,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _avatarFallback(name),
      ),
    );
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
          child: Stack(
            children: [
              _avatarPhoto(
                user?.name ?? '',
                user?.avatarUrl,
                user?.avatarBytes,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: IconButton.filled(
                  tooltip: 'Ubah foto profil',
                  onPressed:
                      _updatingPhoto || user == null ? null : _changePhoto,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                  ),
                  icon: _updatingPhoto
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.camera_alt_outlined),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton.icon(
            onPressed: _updatingPhoto || user == null ? null : _changePhoto,
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: Text(_updatingPhoto ? 'Menyimpan foto...' : 'Ubah foto'),
          ),
        ),
        const SizedBox(height: 8),
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
                item(
                    'Kelola destinasi (tambah, edit, hapus)',
                    () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const AdminDestinationsScreen()))),
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
                final ok = await showConfirmationDialog(
                  context: context,
                  title: 'Keluar',
                  message: 'Anda yakin ingin keluar dari akun?',
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
