import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/destination.dart';
import '../models/destination_review.dart';
import '../providers/app_state.dart';
import '../screens/login_screen.dart';
import '../theme.dart';
import '../utils/confirmation_dialog.dart';

class DestinationRatingSection extends StatefulWidget {
  final Destination destination;

  const DestinationRatingSection({
    super.key,
    required this.destination,
  });

  @override
  State<DestinationRatingSection> createState() =>
      _DestinationRatingSectionState();
}

class _DestinationRatingSectionState extends State<DestinationRatingSection> {
  final _reviewController = TextEditingController();
  int _selectedRating = 0;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    unawaited(_loadReviews());
  }

  @override
  void didUpdateWidget(covariant DestinationRatingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destination.id != widget.destination.id) {
      _reviewController.clear();
      _selectedRating = 0;
      unawaited(_loadReviews());
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final state = context.read<AppState>();
    try {
      await state.loadDestinationReviews(widget.destination.id);
      if (!mounted) return;
      final myReview = state.myReviewFor(widget.destination.id);
      setState(() {
        _selectedRating = myReview?.rating ?? 0;
        _reviewController.text = myReview?.review ?? '';
        _loading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _submit() async {
    final state = context.read<AppState>();
    if (!state.canSubmitCloudReview) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Masuk dengan akun online untuk memberi rating.'),
          action: SnackBarAction(
            label: 'Masuk',
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const LoginScreen())),
          ),
        ),
      );
      return;
    }
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih rating dari 1 sampai 5 bintang.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await state.submitDestinationReview(
        destinationId: widget.destination.id,
        rating: _selectedRating,
        review: _reviewController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rating dan ulasan berhasil disimpan.')),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan ulasan: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteReview() async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Hapus rating dan ulasan?',
      message: 'Rating dan ulasan Anda untuk destinasi ini akan dihapus.',
      confirmLabel: 'HAPUS',
    );
    if (!confirmed || !mounted) return;

    setState(() => _saving = true);
    try {
      await context
          .read<AppState>()
          .deleteDestinationReview(widget.destination.id);
      if (!mounted) return;
      setState(() {
        _selectedRating = 0;
        _reviewController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rating dan ulasan berhasil dihapus.')),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus ulasan: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final rating = state.ratingFor(widget.destination.id);
    final myReview = state.myReviewFor(widget.destination.id);
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
          const Text(
            'Rating dan Ulasan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFF4B400)),
              const SizedBox(width: 4),
              Text(
                rating.$2 == 0
                    ? 'Belum ada rating'
                    : '${rating.$1.toStringAsFixed(1)} dari 5 · ${rating.$2} ulasan',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const LinearProgressIndicator()
          else if (_loadError != null)
            Text(
              'Ulasan belum dapat dimuat: $_loadError',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            )
          else ...[
            for (final review in state.reviewsFor(widget.destination.id))
              _ReviewTile(
                review: review,
                isOwnReview: review.userId == state.currentAuthUserId,
              ),
            if (state.reviewsFor(widget.destination.id).isEmpty)
              const Text(
                'Jadilah yang pertama memberikan ulasan.',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
          ],
          const SizedBox(height: 12),
          Text(
            myReview == null ? 'Beri penilaian' : 'Perbarui penilaian Anda',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Row(
            children: [
              for (var star = 1; star <= 5; star++)
                IconButton(
                  tooltip: '$star bintang',
                  visualDensity: VisualDensity.compact,
                  onPressed: _saving
                      ? null
                      : () => setState(() => _selectedRating = star),
                  icon: Icon(
                    star <= _selectedRating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFF4B400),
                    size: 30,
                  ),
                ),
            ],
          ),
          TextField(
            controller: _reviewController,
            enabled: !_saving,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
              hintText: 'Tulis ulasan (opsional)',
              border: OutlineInputBorder(),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (myReview != null)
                  TextButton.icon(
                    onPressed: _saving ? null : _deleteReview,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Hapus ulasan'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                    ),
                  ),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_outlined, size: 17),
                  label: Text(myReview == null ? 'Kirim ulasan' : 'Perbarui'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final DestinationReview review;
  final bool isOwnReview;

  const _ReviewTile({
    required this.review,
    required this.isOwnReview,
  });

  @override
  Widget build(BuildContext context) {
    final date = review.createdAt.toLocal();
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var star = 0; star < 5; star++)
                Icon(
                  star < review.rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: const Color(0xFFF4B400),
                  size: 16,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOwnReview ? 'Ulasan Anda' : 'Pengunjung',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(dateLabel,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ),
          if (review.review.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(review.review),
          ],
        ],
      ),
    );
  }
}
