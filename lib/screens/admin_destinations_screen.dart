import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/destination.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import '../utils/confirmation_dialog.dart';
import '../widgets/destination_image.dart';

class AdminDestinationsScreen extends StatelessWidget {
  const AdminDestinationsScreen({super.key});

  Future<void> _openEditor(
    BuildContext context, {
    Destination? destination,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DestinationEditorScreen(destination: destination),
      ),
    );
    if (saved != true || !context.mounted) return;
    final message = context.read<AppState>().serviceMessage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? 'Destinasi berhasil disimpan.')),
    );
  }

  Future<void> _deleteDestination(
    BuildContext context,
    Destination destination,
  ) async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Hapus destinasi',
      message: 'Hapus ${destination.name} beserta foto dan videonya?',
      confirmLabel: 'HAPUS',
    );
    if (!confirmed || !context.mounted) return;
    try {
      await context.read<AppState>().deleteDestination(destination.id);
      if (!context.mounted) return;
      final warning = context.read<AppState>().serviceMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(warning ?? 'Destinasi berhasil dihapus.'),
        ),
      );
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus destinasi: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinations = context.watch<AppState>().allDestinations;
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola destinasi')),
      body: destinations.isEmpty
          ? const Center(child: Text('Belum ada destinasi.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: destinations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final destination = destinations[index];
                return Card(
                  color: Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    leading: DestinationImage(
                      url: destination.imageUrl,
                      fallbackAsset: destination.imageAsset,
                      width: 56,
                      height: 56,
                    ),
                    title: Text(
                      destination.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${destination.category} • ${destination.location}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Aksi destinasi',
                      onSelected: (action) {
                        if (action == 'edit') {
                          _openEditor(context, destination: destination);
                        } else if (action == 'delete') {
                          _deleteDestination(context, destination);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Edit'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete_outline),
                            title: Text('Hapus'),
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _openEditor(context, destination: destination),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah destinasi'),
      ),
    );
  }
}

class DestinationEditorScreen extends StatefulWidget {
  const DestinationEditorScreen({super.key, this.destination});

  final Destination? destination;

  @override
  State<DestinationEditorScreen> createState() =>
      _DestinationEditorScreenState();
}

class _DestinationEditorScreenState extends State<DestinationEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  final _history = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _openingHours = TextEditingController();
  final _ticketPrice = TextEditingController();
  final _facilities = TextEditingController();
  final _contact = TextEditingController();
  final _noSkBupati = TextEditingController();

  Uint8List? _imageBytes;
  String? _imageName;
  Uint8List? _videoBytes;
  String? _videoName;
  bool _removeImage = false;
  bool _removeVideo = false;
  bool _saving = false;

  bool get _editing => widget.destination != null;

  @override
  void initState() {
    super.initState();
    final destination = widget.destination;
    if (destination == null) return;
    _name.text = destination.name;
    _category.text = destination.category;
    _location.text = destination.location;
    _description.text = destination.description;
    _history.text = destination.history;
    _latitude.text = destination.latitude.toString();
    _longitude.text = destination.longitude.toString();
    _openingHours.text = destination.openingHours;
    _ticketPrice.text = destination.ticketPrice;
    _facilities.text = destination.facilities;
    _contact.text = destination.contact;
    _noSkBupati.text = destination.noSkBupati;
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _location.dispose();
    _description.dispose();
    _history.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _openingHours.dispose();
    _ticketPrice.dispose();
    _facilities.dispose();
    _contact.dispose();
    _noSkBupati.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Wajib diisi.' : null;

  String? _coordinate(String? value,
      {required double min, required double max}) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || !parsed.isFinite || parsed < min || parsed > max) {
      return 'Masukkan koordinat antara $min dan $max.';
    }
    return null;
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    int minLines = 1,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        validator: validator,
        minLines: minLines,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          alignLabelWithHint: minLines > 1,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (photo == null || !mounted) return;
      final bytes = await photo.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        _showError('Ukuran foto maksimal 10 MB.');
        return;
      }
      final extension = photo.name.split('.').last.toLowerCase();
      if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
        _showError('Format foto harus JPG, PNG, atau WebP.');
        return;
      }
      setState(() {
        _imageBytes = bytes;
        _imageName = photo.name;
        _removeImage = false;
      });
    } on Exception catch (error) {
      if (mounted) _showError('Gagal memilih foto: $error');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (video == null || !mounted) return;
      final extension = video.name.split('.').last.toLowerCase();
      if (extension != 'mp4') {
        _showError('Video harus berformat MP4.');
        return;
      }
      final bytes = await video.readAsBytes();
      if (bytes.length > 50 * 1024 * 1024) {
        _showError('Ukuran video maksimal 50 MB.');
        return;
      }
      setState(() {
        _videoBytes = bytes;
        _videoName = video.name;
        _removeVideo = false;
      });
    } on Exception catch (error) {
      if (mounted) _showError('Gagal memilih video: $error');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final appState = context.read<AppState>();
    final existing = widget.destination;
    final draft = Destination(
      id: existing?.id ?? 0,
      name: _name.text.trim(),
      category: _category.text.trim(),
      location: _location.text.trim(),
      description: _description.text.trim(),
      history: _history.text.trim(),
      latitude: double.parse(_latitude.text.trim()),
      longitude: double.parse(_longitude.text.trim()),
      imageUrl: existing?.imageUrl ?? '',
      imageAsset: existing?.imageAsset ?? '',
      audioAsset: existing?.audioAsset ?? '',
      videoUrl: existing?.videoUrl ?? '',
      videoAsset: existing?.videoAsset ?? '',
      openingHours: _openingHours.text.trim(),
      ticketPrice: _ticketPrice.text.trim(),
      facilities: _facilities.text.trim(),
      contact: _contact.text.trim(),
      noSkBupati: _noSkBupati.text.trim(),
      practicalInfoUpdatedAt: DateTime.now().toUtc(),
    );

    setState(() => _saving = true);
    try {
      if (existing == null) {
        await appState.createDestination(
          draft,
          imageBytes: _imageBytes,
          imageFileName: _imageName,
          videoBytes: _videoBytes,
          videoFileName: _videoName,
        );
      } else {
        await appState.updateDestination(
          draft,
          imageBytes: _imageBytes,
          imageFileName: _imageName,
          videoBytes: _videoBytes,
          videoFileName: _videoName,
          removeImage: _removeImage,
          removeVideo: _removeVideo,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (error) {
      if (mounted) _showError('Gagal menyimpan destinasi: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _mediaCard({
    required String title,
    required String? currentUrl,
    required String? currentAsset,
    required Uint8List? selectedBytes,
    required String? selectedName,
    required bool removed,
    required IconData icon,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    final hasCurrent = (currentUrl?.isNotEmpty ?? false) ||
        (currentAsset?.isNotEmpty ?? false);
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (selectedBytes != null)
              title == 'Foto destinasi'
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        selectedBytes,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  : ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(icon, color: AppColors.green),
                      title: Text(selectedName ?? 'Video terpilih'),
                    )
            else if (hasCurrent && !removed && title == 'Foto destinasi')
              DestinationImage(
                url: currentUrl ?? '',
                fallbackAsset: currentAsset ?? '',
                height: 150,
                width: double.infinity,
                radius: 8,
              )
            else if (hasCurrent && !removed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(icon, color: AppColors.green),
                title: Text(
                  currentUrl?.isNotEmpty == true
                      ? 'Media sudah diunggah'
                      : 'Media lokal aplikasi',
                ),
              )
            else
              const Text('Belum ada media.'),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _saving ? null : onPick,
                  icon: Icon(icon, size: 18),
                  label: Text(selectedBytes == null ? 'Pilih file' : 'Ganti'),
                ),
                if (selectedBytes != null || (hasCurrent && !removed))
                  TextButton(
                    onPressed: _saving ? null : onRemove,
                    child: const Text('Hapus media'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destination = widget.destination;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit destinasi' : 'Tambah destinasi'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _textField(_name, 'Nama destinasi', validator: _required),
            _textField(
              _category,
              'Kategori',
              validator: _required,
              hintText: 'Alam: Gunung, Danau, Kawah, Laut, Air Terjun, Lubuk',
            ),
            _textField(_location, 'Lokasi / kecamatan', validator: _required),
            _textField(
              _description,
              'Deskripsi',
              validator: _required,
              minLines: 3,
              maxLines: 6,
            ),
            _textField(
              _history,
              'Cerita / sejarah',
              minLines: 3,
              maxLines: 8,
            ),
            Row(
              children: [
                Expanded(
                  child: _textField(
                    _latitude,
                    'Latitude',
                    validator: (value) => _coordinate(
                      value,
                      min: -90,
                      max: 90,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _textField(
                    _longitude,
                    'Longitude',
                    validator: (value) => _coordinate(
                      value,
                      min: -180,
                      max: 180,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            _textField(_openingHours, 'Jam operasional'),
            _textField(_ticketPrice, 'Harga tiket'),
            _textField(
              _facilities,
              'Fasilitas',
              minLines: 2,
              maxLines: 4,
            ),
            _textField(
              _contact,
              'Kontak pengelola',
              keyboardType: TextInputType.phone,
            ),
            _textField(_noSkBupati, 'No. SK Bupati'),
            _mediaCard(
              title: 'Foto destinasi',
              currentUrl: destination?.imageUrl,
              currentAsset: destination?.imageAsset,
              selectedBytes: _imageBytes,
              selectedName: _imageName,
              removed: _removeImage,
              icon: Icons.image_outlined,
              onPick: _pickImage,
              onRemove: () => setState(() {
                _imageBytes = null;
                _imageName = null;
                _removeImage = true;
              }),
            ),
            _mediaCard(
              title: 'Video destinasi (MP4)',
              currentUrl: destination?.videoUrl,
              currentAsset: destination?.videoAsset,
              selectedBytes: _videoBytes,
              selectedName: _videoName,
              removed: _removeVideo,
              icon: Icons.video_library_outlined,
              onPick: _pickVideo,
              onRemove: () => setState(() {
                _videoBytes = null;
                _videoName = null;
                _removeVideo = true;
              }),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Menyimpan...' : 'Simpan destinasi'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
