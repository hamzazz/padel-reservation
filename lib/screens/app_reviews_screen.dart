import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/player_review.dart';
import '../services/review_service.dart';
import '../state/auth_provider.dart';
import '../state/locale_provider.dart';
import '../theme/app_theme.dart';

const _kClubTarget = 'club';

class AppReviewsScreen extends StatefulWidget {
  const AppReviewsScreen({super.key});

  @override
  State<AppReviewsScreen> createState() => _AppReviewsScreenState();
}

class _AppReviewsScreenState extends State<AppReviewsScreen> {
  final _svc = ReviewService();
  List<PlayerReview> _reviews = [];
  bool _loading = true;
  PlayerReview? _myReview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final all = await _svc.getForPlayer(_kClubTarget);
    final mine = auth.currentUser == null
        ? null
        : all.where((r) => r.reviewerId == auth.currentUser!.id).firstOrNull;
    setState(() {
      _reviews = all;
      _myReview = mine;
      _loading = false;
    });
  }

  double get _average {
    if (_reviews.isEmpty) return 0;
    return _reviews.map((r) => r.rating).reduce((a, b) => a + b) /
        _reviews.length;
  }

  Map<int, int> get _breakdown {
    final map = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in _reviews) {
      final star = r.rating.round().clamp(1, 5);
      map[star] = (map[star] ?? 0) + 1;
    }
    return map;
  }

  Future<void> _deleteMyReview() async {
    if (_myReview == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer mon avis'),
        content: const Text('Voulez-vous supprimer votre avis ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _svc.deleteReview(_myReview!.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.read<LocaleProvider>().tr('reviewDeleted')),
        backgroundColor: AppTheme.primary,
      ));
      _load();
    }
  }

  void _openForm() {
    final locale = context.read<LocaleProvider>();
    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null) return;

    double rating = _myReview?.rating ?? 0;
    final commentCtrl =
        TextEditingController(text: _myReview?.comment ?? '');
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _myReview != null
                    ? locale.tr('editMyReview')
                    : locale.tr('writeReview'),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              // Star selector
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    return GestureDetector(
                      onTap: () => setS(() => rating = star.toDouble()),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          star <= rating ? Icons.star : Icons.star_border,
                          color: const Color(0xFFFFC107),
                          size: 40,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              if (rating == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Center(
                    child: Text(locale.tr('selectRating'),
                        style: TextStyle(
                            color: Colors.orange.shade700, fontSize: 12)),
                  ),
                ),
              const SizedBox(height: 20),
              TextField(
                controller: commentCtrl,
                maxLines: 4,
                maxLength: 300,
                decoration: InputDecoration(
                  hintText: locale.tr('writeYourReview'),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: submitting || rating == 0
                      ? null
                      : () async {
                          setS(() => submitting = true);
                          final user = auth.currentUser!;
                          await _svc.submitReview(
                            reviewerId: user.id,
                            reviewerName: user.fullName,
                            reviewerEmoji: user.avatarEmoji,
                            targetId: _kClubTarget,
                            rating: rating,
                            comment: commentCtrl.text.trim(),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(
                              content:
                                  Text(locale.tr('reviewSent')),
                              backgroundColor: AppTheme.primary,
                            ));
                            _load();
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(locale.tr('submitReview')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    final locale = context.read<LocaleProvider>();
    final auth = context.read<AuthProvider>();
    final me = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            const Text('⭐', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(locale.tr('clubReviews'),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      floatingActionButton: me != null
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.primary,
              icon: Icon(
                _myReview != null ? Icons.edit : Icons.rate_review,
                color: Colors.white,
              ),
              label: Text(
                _myReview != null
                    ? locale.tr('editMyReview')
                    : locale.tr('writeReview'),
                style: const TextStyle(color: Colors.white),
              ),
              onPressed: _openForm,
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.primary,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // ── Summary card ──────────────────────────────────
                  _SummaryCard(
                    average: _average,
                    total: _reviews.length,
                    breakdown: _breakdown,
                    locale: locale,
                  ),
                  const SizedBox(height: 20),

                  // ── My review (pinned) ────────────────────────────
                  if (_myReview != null) ...[
                    _SectionHeader(
                        icon: Icons.person,
                        label: locale.tr('yourReview'),
                        color: AppTheme.primary),
                    const SizedBox(height: 8),
                    _ReviewCard(
                      review: _myReview!,
                      isMine: true,
                      onDelete: _deleteMyReview,
                      onEdit: _openForm,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── All reviews ───────────────────────────────────
                  if (_reviews.isEmpty)
                    _EmptyState(locale: locale)
                  else ...[
                    _SectionHeader(
                        icon: Icons.rate_review_outlined,
                        label: '${_reviews.length} ${locale.tr('ratingsCount')}',
                        color: Colors.grey.shade700),
                    const SizedBox(height: 8),
                    ..._reviews
                        .where((r) => r.id != _myReview?.id)
                        .map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ReviewCard(review: r),
                            )),
                  ],
                ],
              ),
            ),
    );
  }
}

// ── Summary ────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double average;
  final int total;
  final Map<int, int> breakdown;
  final LocaleProvider locale;

  const _SummaryCard({
    required this.average,
    required this.total,
    required this.breakdown,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          // Big average number
          Column(
            children: [
              Text(
                total == 0 ? '—' : average.toStringAsFixed(1),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    height: 1),
              ),
              const SizedBox(height: 4),
              _Stars(rating: average, size: 18, color: Colors.white),
              const SizedBox(height: 4),
              Text('$total ${locale.tr('ratingsCount')}',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(width: 24),
          // Star breakdown bars
          Expanded(
            child: Column(
              children: [5, 4, 3, 2, 1].map((star) {
                final count = breakdown[star] ?? 0;
                final frac = total == 0 ? 0.0 : count / total;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text('$star',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11)),
                      const SizedBox(width: 2),
                      const Icon(Icons.star,
                          color: Colors.white54, size: 11),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: frac,
                            backgroundColor: Colors.white24,
                            color: Colors.white,
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 16,
                        child: Text('$count',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11),
                            textAlign: TextAlign.right),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Review card ────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final PlayerReview review;
  final bool isMine;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const _ReviewCard({
    required this.review,
    this.isMine = false,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMine
            ? AppTheme.primary.withOpacity(0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isMine
                ? AppTheme.primary.withOpacity(0.25)
                : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isMine
                      ? AppTheme.primary.withOpacity(0.1)
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(review.reviewerEmoji,
                      style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.reviewerName,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isMine ? AppTheme.primary : null)),
                    Text(
                      DateFormat('d MMM yyyy', 'fr')
                          .format(review.createdAt),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              if (isMine)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 18, color: AppTheme.primary),
                      onPressed: onEdit,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.red),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                )
              else
                _Stars(rating: review.rating, size: 16),
            ],
          ),
          if (isMine) ...[
            const SizedBox(height: 6),
            _Stars(rating: review.rating, size: 18),
          ],
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment,
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Stars ──────────────────────────────────────────────────────────────────

class _Stars extends StatelessWidget {
  final double rating;
  final double size;
  final Color color;

  const _Stars({
    required this.rating,
    this.size = 16,
    this.color = const Color(0xFFFFC107),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final star = i + 1;
        IconData icon;
        if (star <= rating) {
          icon = Icons.star;
        } else if (star - 0.5 <= rating) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(icon, color: color, size: size);
      }),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionHeader(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color)),
      ],
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final LocaleProvider locale;
  const _EmptyState({required this.locale});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(locale.tr('noReviewsYet'),
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500)),
        const SizedBox(height: 8),
        Text(locale.tr('beFirstReview'),
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 13, color: Colors.grey.shade400)),
      ],
    );
  }
}
