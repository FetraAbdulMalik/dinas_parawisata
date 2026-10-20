import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../models/destination.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import '../utils/confirmation_dialog.dart';
import '../utils/google_maps_route.dart';
import '../widgets/copyright_footer.dart';
import '../widgets/destination_image.dart';
import '../widgets/destination_rating_section.dart';
import 'login_screen.dart';

/// Layar detail: video (bila ada), pemutar audio dari assets,
/// dan suara otomatis (text-to-speech) sebagai cadangan bila file audio belum ada.
class DetailScreen extends StatefulWidget {
  final int initialIndex;
  const DetailScreen({super.key, required this.initialIndex});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final FlutterTts _tts = FlutterTts();
  late final AudioPlayer _audio;
  final List<StreamSubscription<dynamic>> _subs = [];
  VideoPlayerController? _video;

  Set<String> _available = {};
  late int _index;

  bool _hasAudio = false;
  bool _hasVideo = false;
  bool _playing = false;
  bool _audioStarted = false;
  bool _ttsReady = false;
  String? _ttsIssue;

  // Mode file audio
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Mode suara otomatis (TTS)
  int _offset = 0; // posisi karakter awal segmen yang sedang dibacakan
  int _pos = 0; // posisi karakter absolut saat ini

  @override
  void initState() {
    super.initState();
    _audio = context.read<AudioPlayer>();
    _index = widget.initialIndex;
    _init();
  }

  Future<void> _init() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _available = manifest.listAssets().toSet();
    } catch (_) {
      _available = {};
    }

    _tts.setProgressHandler((text, start, end, word) {
      if (!mounted) return;
      setState(() => _pos = _offset + end);
    });
    _tts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _pos = 0;
        _offset = 0;
      });
    });
    _tts.setErrorHandler((error) {
      _setTtsIssue('Suara otomatis gagal: $error');
    });

    try {
      final languageAvailable = await _tts.isLanguageAvailable('id-ID');
      if (languageAvailable != true) {
        _setTtsIssue(
          'Bahasa Indonesia belum tersedia di Text-to-speech perangkat. '
          'Pasang data suara Bahasa Indonesia di Pengaturan Android.',
        );
      } else {
        final languageSet = await _tts.setLanguage('id-ID');
        if (languageSet == 1) {
          await _tts.setSpeechRate(0.45);
          await _tts.setVolume(1.0);
          _ttsReady = true;
        } else {
          _setTtsIssue(
            'Text-to-speech perangkat tidak dapat memilih suara Bahasa Indonesia.',
          );
        }
      }
    } catch (error) {
      _setTtsIssue(
        'Text-to-speech perangkat tidak dapat dijalankan. '
        'Periksa mesin Text-to-speech di Pengaturan Android. ($error)',
      );
    }

    _subs.add(_audio.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    }));
    _subs.add(_audio.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _duration = d);
    }));
    _subs.add(_audio.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _playing = state.playing;
        if (state.processingState == ProcessingState.completed) {
          _audioStarted = false;
          _position = Duration.zero;
        }
      });
    }));
    _subs.add(_audio.errorStream.listen((error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audio gagal diputar: $error')),
      );
    }));

    if (mounted) await _prepare();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _video?.dispose();
    super.dispose();
  }

  List<Destination> get _all => context.read<AppState>().allDestinations;
  Destination get _dest => _all[_index];
  String get _text => [
        _dest.description.trim(),
        _dest.history.trim(),
      ].where((text) => text.isNotEmpty).join('\n\n');

  void _setTtsIssue(String issue) {
    _ttsReady = false;
    _ttsIssue = issue;
    if (mounted) setState(() {});
  }

  void _showTtsIssue() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          _ttsIssue ??
              'Suara otomatis tidak dapat diputar. '
                  'Periksa pengaturan Text-to-speech Android.',
        ),
        duration: const Duration(seconds: 6),
      ));
  }

  Future<void> _editPracticalInfo(Destination destination) async {
    final openingHoursController =
        TextEditingController(text: destination.openingHours);
    final ticketPriceController =
        TextEditingController(text: destination.ticketPrice);
    final facilitiesController =
        TextEditingController(text: destination.facilities);
    final contactController = TextEditingController(text: destination.contact);
    final noSkBupatiController =
        TextEditingController(text: destination.noSkBupati);

    try {
      final result = await showDialog<
          ({
            String openingHours,
            String ticketPrice,
            String facilities,
            String contact,
            String noSkBupati
          })>(
        context: context,
        animationStyle: appDialogAnimationStyle,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Edit informasi praktis'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: openingHoursController,
                  decoration: const InputDecoration(
                    labelText: 'Jam operasional',
                    hintText: 'Contoh: Setiap hari, 08.00–16.00',
                  ),
                ),
                TextField(
                  controller: ticketPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Harga tiket',
                    hintText: 'Contoh: Gratis atau Rp10.000',
                  ),
                ),
                TextField(
                  controller: facilitiesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Fasilitas',
                    hintText: 'Pisahkan setiap fasilitas dengan baris baru',
                  ),
                ),
                TextField(
                  controller: contactController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Kontak pengelola',
                    hintText: 'Nomor telepon atau informasi kontak',
                  ),
                ),
                TextField(
                  controller: noSkBupatiController,
                  decoration: const InputDecoration(
                    labelText: 'No. SK Bupati',
                    hintText: 'Nomor surat keputusan Bupati',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Kosongkan informasi yang belum terverifikasi. '
                  'Tanggal pembaruan akan diisi otomatis.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                (
                  openingHours: openingHoursController.text,
                  ticketPrice: ticketPriceController.text,
                  facilities: facilitiesController.text,
                  contact: contactController.text,
                  noSkBupati: noSkBupatiController.text,
                ),
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      );
      if (result == null || !mounted) return;

      try {
        await context.read<AppState>().updateDestinationPracticalInfo(
              destinationId: destination.id,
              openingHours: result.openingHours,
              ticketPrice: result.ticketPrice,
              facilities: result.facilities,
              contact: result.contact,
              noSkBupati: result.noSkBupati,
            );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informasi praktis berhasil disimpan.')),
        );
      } on Exception catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan informasi: $error')),
        );
      }
    } finally {
      openingHoursController.dispose();
      ticketPriceController.dispose();
      facilitiesController.dispose();
      contactController.dispose();
      noSkBupatiController.dispose();
    }
  }

  Widget _practicalInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 2),
                Text(
                  value.trim().isEmpty ? 'Belum tersedia' : value.trim(),
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPracticalInfoDate(DateTime? date) {
    if (date == null) return 'Belum diperbarui';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final local = date.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  Widget _practicalInfoSection(Destination destination, bool isAdmin) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Informasi Praktis',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              if (isAdmin)
                TextButton.icon(
                  onPressed: () => _editPracticalInfo(destination),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
            ],
          ),
          _practicalInfoItem(
            Icons.schedule,
            'Jam operasional',
            destination.openingHours,
          ),
          _practicalInfoItem(
            Icons.confirmation_num_outlined,
            'Harga tiket',
            destination.ticketPrice,
          ),
          _practicalInfoItem(
            Icons.miscellaneous_services_outlined,
            'Fasilitas',
            destination.facilities,
          ),
          _practicalInfoItem(
            Icons.phone_outlined,
            'Kontak pengelola',
            destination.contact,
          ),
          _practicalInfoItem(
            Icons.description_outlined,
            'No. SK Bupati',
            destination.noSkBupati,
          ),
          const SizedBox(height: 12),
          Text(
            'Terakhir diperbarui: '
            '${_formatPracticalInfoDate(destination.practicalInfoUpdatedAt)}',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  /// Siapkan audio/video untuk destinasi yang sedang tampil.
  Future<void> _prepare() async {
    final d = _dest;
    final sequence = _audio.sequence;
    final currentTag = sequence.isEmpty ? null : sequence.first.tag;
    final keepAudio = _available.contains(d.audioAsset) &&
        currentTag is MediaItem &&
        currentTag.id == d.id.toString() &&
        _audio.processingState != ProcessingState.completed;
    await _tts.stop();
    if (!keepAudio) await _audio.stop();
    _video?.dispose();
    _video = null;
    setState(() {
      _hasAudio = _available.contains(d.audioAsset);
      _hasVideo = d.videoUrl.isNotEmpty || _available.contains(d.videoAsset);
      _playing = keepAudio && _audio.playing;
      _audioStarted = keepAudio;
      _position = keepAudio ? _audio.position : Duration.zero;
      _duration = keepAudio ? _audio.duration ?? Duration.zero : Duration.zero;
      _pos = 0;
      _offset = 0;
    });

    if (_hasVideo) {
      final c = d.videoUrl.isNotEmpty
          ? VideoPlayerController.networkUrl(Uri.parse(d.videoUrl))
          : VideoPlayerController.asset(d.videoAsset);
      _video = c;
      try {
        await c.initialize();
      } catch (_) {
        if (d.videoUrl.isNotEmpty &&
            _available.contains(d.videoAsset) &&
            mounted) {
          await c.dispose();
          final fallback = VideoPlayerController.asset(d.videoAsset);
          _video = fallback;
          try {
            await fallback.initialize();
          } catch (_) {
            if (_video == fallback) {
              _video = null;
              if (mounted) setState(() => _hasVideo = false);
            }
            await fallback.dispose();
            return;
          }
          if (!mounted || _video != fallback) {
            fallback.dispose();
            return;
          }
          fallback.addListener(() {
            if (mounted) setState(() {});
          });
          setState(() {});
          return;
        }
        if (_video == c) {
          _video = null;
          if (mounted) setState(() => _hasVideo = false);
        }
        await c.dispose();
        return;
      }
      if (!mounted || _video != c) {
        c.dispose();
        return;
      }
      c.addListener(() {
        if (mounted) setState(() {});
      });
      setState(() {});
    }
  }

  // ---------- Kontrol audio ----------
  Future<void> _speakFrom(int start) async {
    final text = _text;
    final s = start.clamp(0, text.length);
    if (s >= text.length) return;
    _offset = s;
    final result = await _tts.speak(text.substring(s), focus: true);
    if (result != true && result != 1) {
      throw StateError('Mesin Text-to-speech menolak permintaan bicara.');
    }
  }

  Future<void> _togglePlay() async {
    if (_hasAudio) {
      if (_playing) {
        await _audio.pause();
      } else if (!_audioStarted) {
        await _video?.pause();
        await _audio.setAudioSource(
          AudioSource.asset(
            _dest.audioAsset,
            tag: MediaItem(
              id: _dest.id.toString(),
              album: 'Guriang Garut',
              title: _dest.name,
            ),
          ),
        );
        _audioStarted = true;
        unawaited(_audio.play());
      } else {
        await _video?.pause();
        unawaited(_audio.play());
      }
      return;
    }
    // Cadangan: suara otomatis
    if (!_ttsReady) {
      _showTtsIssue();
      return;
    }
    if (_playing) {
      await _tts.stop();
      setState(() {
        _offset = _pos;
        _playing = false;
      });
    } else {
      await _video?.pause();
      setState(() => _playing = true);
      try {
        await _speakFrom(_pos);
      } catch (error) {
        if (!mounted) return;
        setState(() => _playing = false);
        _setTtsIssue('Suara otomatis gagal diputar. ($error)');
        _showTtsIssue();
      }
    }
  }

  Future<void> _pauseNarration() async {
    if (_hasAudio) {
      await _audio.pause();
    } else if (_playing) {
      await _tts.stop();
      setState(() {
        _offset = _pos;
        _playing = false;
      });
    }
  }

  Future<void> _seek(double value) async {
    final target = value.toInt();
    if (_hasAudio) {
      if (_audioStarted) await _audio.seek(Duration(milliseconds: target));
      return;
    }
    if (_playing) {
      await _tts.stop();
      setState(() => _pos = target);
      await _speakFrom(target);
    } else {
      setState(() {
        _pos = target;
        _offset = target;
      });
    }
  }

  Future<void> _toggleVideo() async {
    final c = _video;
    if (c == null) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await _pauseNarration();
      await c.play();
    }
  }

  Future<void> _move(int delta) async {
    final n = _all.length;
    _index = (_index + delta) % n;
    if (_index < 0) _index += n;
    await _prepare();
  }

  // ---------- Tampilan ----------
  String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _fmtChars(int chars) {
    final seconds = (chars / 14).round(); // perkiraan kecepatan baca
    return _fmtDuration(Duration(seconds: seconds));
  }

  Widget _textSection(String title, String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            text.trim(),
            textAlign: TextAlign.left,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );
  }

  bool _requireLogin() {
    final appState = context.read<AppState>();
    if (appState.user != null) return true;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text(
              'Silakan masuk atau daftar untuk menggunakan fitur ini.'),
          action: SnackBarAction(
            label: 'Masuk',
            onPressed: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          ),
        ),
      );
    return false;
  }

  Future<void> _showLocation() async {
    if (!_requireLogin()) return;
    if (!mounted) return;
    final d = _dest;
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Buka Google Maps?',
      message: 'Lihat lokasi ${d.name} di Google Maps?',
    );
    if (!confirmed || !mounted) return;

    final opened = await launchUrl(
      googleMapsLocationUri(d),
      mode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Maps tidak dapat dibuka.')),
      );
    }
  }

  Future<void> _toggleFavorite() async {
    if (!_requireLogin()) return;
    if (!mounted) return;
    final destination = _dest;
    final isFavorite =
        context.read<AppState>().favoriteIds.contains(destination.id);
    final confirmed = await showConfirmationDialog(
      context: context,
      title: isFavorite ? 'Hapus dari favorit?' : 'Tambah ke favorit?',
      message: isFavorite
          ? 'Hapus ${destination.name} dari daftar favorit?'
          : 'Tambahkan ${destination.name} ke daftar favorit?',
    );
    if (!confirmed || !mounted) return;
    await context.read<AppState>().toggleFavorite(destination.id);
  }

  Widget _media(Destination d) {
    final c = _video;
    if (_hasVideo && c != null && c.value.isInitialized) {
      return Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: AspectRatio(
                  aspectRatio: c.value.aspectRatio,
                  child: VideoPlayer(c),
                ),
              ),
              GestureDetector(
                onTap: _toggleVideo,
                child: AnimatedOpacity(
                  opacity: c.value.isPlaying ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow,
                        color: Colors.white, size: 36),
                  ),
                ),
              ),
            ],
          ),
          VideoProgressIndicator(
            c,
            allowScrubbing: true,
            colors: const VideoProgressColors(playedColor: AppColors.green),
          ),
        ],
      );
    }
    return Hero(
      tag: 'destination-image-${d.id}',
      child: DestinationImage(
        url: d.imageUrl,
        fallbackAsset: d.imageAsset,
        height: 201,
        width: double.infinity,
        radius: 4,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final d = _dest;
    final fav = state.favoriteIds.contains(d.id);

    final double max = _hasAudio
        ? math.max(_duration.inMilliseconds, 1).toDouble()
        : math.max(_text.length, 1).toDouble();
    final double value =
        (_hasAudio ? _position.inMilliseconds.toDouble() : _pos.toDouble())
            .clamp(0.0, max)
            .toDouble();
    final String leftLabel =
        _hasAudio ? _fmtDuration(_position) : _fmtChars(_pos);
    final String rightLabel = _hasAudio
        ? '-${_fmtDuration(_duration - _position)}'
        : '-${_fmtChars(_text.length - _pos)}';

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Text(d.name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(21, 20, 21, 24),
        children: [
          _media(d),
          const SizedBox(height: 4),
          Row(
            children: [
              GestureDetector(
                onTap: _showLocation,
                child: const Row(
                  children: [
                    Icon(Icons.location_on, size: 22),
                    SizedBox(width: 2),
                    Text('lihat lokasi',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                    size: 32, color: fav ? AppColors.green : Colors.black),
                onPressed: _toggleFavorite,
              ),
            ],
          ),
          Slider(
            value: value,
            min: 0,
            max: max,
            activeColor: Colors.black,
            inactiveColor: Colors.black26,
            onChanged: (v) => setState(() {
              if (_hasAudio) {
                if (_audioStarted) {
                  _position = Duration(milliseconds: v.toInt());
                }
              } else {
                _pos = v.toInt();
              }
            }),
            onChangeEnd: _seek,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(leftLabel, style: const TextStyle(fontSize: 11)),
                Text(rightLabel, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 36,
                icon: const Icon(Icons.skip_previous),
                onPressed: () => _move(-1),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 67,
                  height: 67,
                  decoration: const BoxDecoration(
                      color: Colors.black, shape: BoxShape.circle),
                  child: Icon(_playing ? Icons.pause : Icons.play_arrow,
                      color: Colors.white, size: 36),
                ),
              ),
              const SizedBox(width: 24),
              IconButton(
                iconSize: 36,
                icon: const Icon(Icons.skip_next),
                onPressed: () => _move(1),
              ),
            ],
          ),
          if (!_hasAudio)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Center(
                child: Text(
                  'Suara otomatis (file audio belum ditambahkan)',
                  style: TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ),
            ),
          if (!_hasAudio && _ttsIssue != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _ttsIssue!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
          const SizedBox(height: 20),
          if (d.description.trim().isNotEmpty)
            _textSection('Deskripsi', d.description),
          if (d.history.trim().isNotEmpty)
            _textSection('Cerita / Sejarah', d.history),
          _practicalInfoSection(d, state.isContentAdmin),
          DestinationRatingSection(destination: d),
          const CopyrightFooter(),
        ],
      ),
    );
  }
}
