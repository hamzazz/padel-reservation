import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/court.dart';
import '../models/match.dart';
import '../models/reservation.dart';
import '../services/match_service.dart';
import '../services/notification_service.dart';
import '../services/reservation_service.dart';
import '../state/auth_provider.dart';
import '../state/court_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/court_image_widget.dart';
import 'match_detail_screen.dart';

enum _Input {
  none,
  action,
  // booking flow
  courtType,
  date,
  slot,
  courtSelect,
  playerCount,
  confirmBooking,
  // match flow
  matchAction,
  // rejoindre
  matchJoinLevel,
  matchCards,
  // créer
  reservationSelect,
  matchPlayerCount,
  matchLevel,
  confirmMatch,
}

class _Msg {
  final bool isBot;
  final String text;
  _Msg({required this.isBot, required this.text});
}

class ChatHomeScreen extends StatefulWidget {
  const ChatHomeScreen({super.key});

  @override
  State<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen> {
  final _scroll = ScrollController();
  final _resSvc = ReservationService();
  final _matchSvc = MatchService();
  final _notifSvc = NotificationService();

  final List<_Msg> _msgs = [];
  bool _isTyping = false;
  bool _saving = false;
  _Input _input = _Input.none;

  // Booking state
  String _filter = 'all';
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  String _selectedSlot = '';
  List<Court> _availableCourts = [];
  List<String> _availableSlots = [];
  Court? _selectedCourt;
  int _players = 2;

  // Match — rejoindre
  List<Match> _availableMatches = [];
  // Match — créer
  List<Reservation> _userReservations = [];
  Reservation? _selectedReservation;
  int _maxMatchPlayers = 4;
  int _matchLevel = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addUserMsg(String text) {
    setState(() {
      _msgs.add(_Msg(isBot: false, text: text));
      _input = _Input.none;
    });
    _scrollToBottom();
  }

  Future<void> _botSay(String text, _Input nextInput) async {
    setState(() => _isTyping = true);
    _scrollToBottom();
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      _isTyping = false;
      _msgs.add(_Msg(isBot: true, text: text));
      _input = nextInput;
    });
    _scrollToBottom();
  }

  // ── Reset ────────────────────────────────────────────────────────────────────

  void _reset() {
    setState(() {
      _msgs.clear();
      _isTyping = false;
      _saving = false;
      _input = _Input.none;
      _filter = 'all';
      _date = DateTime.now().add(const Duration(days: 1));
      _selectedSlot = '';
      _availableCourts = [];
      _availableSlots = [];
      _selectedCourt = null;
      _players = 2;
      _availableMatches = [];
      _userReservations = [];
      _selectedReservation = null;
      _maxMatchPlayers = 4;
      _matchLevel = 0;
    });
    _start();
  }

  // ── Entry point ─────────────────────────────────────────────────────────────

  Future<void> _start() async {
    final user = context.read<AuthProvider>().currentUser;
    final name = user?.firstName ?? 'joueur';
    await _botSay(
      'Bonjour $name ! 👋\nJe suis votre assistant padel. Que souhaitez-vous faire ?',
      _Input.action,
    );
  }

  // ── Action choice ────────────────────────────────────────────────────────────

  Future<void> _onAction(String label) async {
    _addUserMsg(label);
    if (label.contains('Réserver')) {
      await _botSay('Quel type de terrain préférez-vous ?', _Input.courtType);
    } else {
      await _botSay(
        'Souhaitez-vous rejoindre un match existant ou en créer un ?',
        _Input.matchAction,
      );
    }
  }

  // ── Booking flow ─────────────────────────────────────────────────────────────

  Future<void> _onCourtType(String filter, String label) async {
    _filter = filter;
    _addUserMsg(label);

    final allCourts = context.read<CourtProvider>().courts;
    final filtered = allCourts.where((c) {
      if (filter == 'indoor') return c.isIndoor;
      if (filter == 'outdoor') return !c.isIndoor;
      return true;
    }).toList();

    if (filtered.isEmpty) {
      final typeName = filter == 'indoor'
          ? 'couvert'
          : filter == 'outdoor'
              ? 'extérieur'
              : '';
      await _botSay(
        'Désolé, il n\'y a aucun terrain $typeName disponible dans notre club 😕\nVoulez-vous choisir un autre type ?',
        _Input.courtType,
      );
      return;
    }

    await _botSay('Quelle date souhaitez-vous réserver ?', _Input.date);
  }

  Future<void> _onDatePicked(DateTime date) async {
    _date = date;
    _addUserMsg(DateFormat('EEEE dd MMMM', 'fr').format(date));
    setState(() => _isTyping = true);
    _scrollToBottom();

    final allCourts = context.read<CourtProvider>().courts;
    final filtered = allCourts.where((c) {
      if (_filter == 'indoor') return c.isIndoor;
      if (_filter == 'outdoor') return !c.isIndoor;
      return true;
    }).toList();

    // Check all slots in parallel
    final slotResults = await Future.wait(timeSlots.map((slot) async {
      final counts = await Future.wait(
        filtered.map((c) => _resSvc.countSlotReservations(c.id, date, slot)),
      );
      final hasAvail = filtered
          .asMap()
          .entries
          .any((e) => (counts[e.key]) < e.value.maxReservationsPerSlot);
      return (slot: slot, available: hasAvail);
    }));

    if (!mounted) return;
    final available =
        slotResults.where((r) => r.available).map((r) => r.slot).toList();
    setState(() {
      _isTyping = false;
      _availableSlots = available;
    });

    if (available.isEmpty) {
      await _botSay(
        'Aucun créneau disponible pour le ${DateFormat('dd/MM/yyyy').format(date)} 😕\nEssayez une autre date :',
        _Input.date,
      );
    } else {
      await _botSay(
        '${available.length} créneau${available.length > 1 ? 'x' : ''} disponible${available.length > 1 ? 's' : ''} — choisissez :',
        _Input.slot,
      );
    }
  }

  Future<void> _onSlotPicked(String slot) async {
    _selectedSlot = slot;
    _addUserMsg(slot);
    setState(() => _isTyping = true);
    _scrollToBottom();

    final allCourts = context.read<CourtProvider>().courts;
    final filtered = allCourts.where((c) {
      if (_filter == 'indoor') return c.isIndoor;
      if (_filter == 'outdoor') return !c.isIndoor;
      return true;
    }).toList();

    final counts = <String, int>{};
    await Future.wait(filtered.map((c) async {
      counts[c.id] = await _resSvc.countSlotReservations(c.id, _date, slot);
    }));

    final available = filtered
        .where((c) => (counts[c.id] ?? 0) < c.maxReservationsPerSlot)
        .toList();

    if (!mounted) return;
    setState(() {
      _isTyping = false;
      _availableCourts = available;
    });

    if (available.isEmpty) {
      await _botSay(
        'Aucun terrain disponible pour ce créneau 😕\nEssayez un autre horaire :',
        _Input.slot,
      );
    } else {
      final n = available.length;
      await _botSay(
        '$n terrain${n > 1 ? 's' : ''} disponible${n > 1 ? 's' : ''} pour le ${DateFormat('dd/MM').format(_date)} à $slot 🎾\nTapez sur un terrain pour le sélectionner :',
        _Input.courtSelect,
      );
    }
  }

  Future<void> _onCourtSelected(Court court) async {
    _selectedCourt = court;
    _addUserMsg(court.name);
    await _botSay(
      'Combien de joueurs serez-vous ?',
      _Input.playerCount,
    );
  }

  Future<void> _onPlayerCount(int count) async {
    _players = count;
    _addUserMsg('$count joueurs');
    await _botSay(
      'Récapitulatif de votre réservation :',
      _Input.confirmBooking,
    );
  }

  Future<void> _confirmBooking() async {
    _addUserMsg('Confirmer la réservation');
    setState(() => _saving = true);

    final auth = context.read<AuthProvider>();
    final reservation = Reservation(
      id: const Uuid().v4(),
      userId: auth.currentUser?.id ?? '',
      courtId: _selectedCourt!.id,
      courtName: _selectedCourt!.name,
      date: _date,
      timeSlot: _selectedSlot,
      playerName: auth.currentUser?.fullName ?? '',
      numberOfPlayers: _players,
      totalPrice: _selectedCourt!.pricePerHour,
      createdAt: DateTime.now(),
    );

    await _resSvc.save(reservation);
    if (!mounted) return;
    setState(() => _saving = false);

    final user = auth.currentUser;
    _notifSvc.push(
      userId: user?.id ?? '',
      title: 'Réservation confirmée ✅',
      body: '🏟️ ${reservation.courtName}\n'
          '📅 ${DateFormat('dd/MM/yyyy').format(reservation.date)} · ${reservation.timeSlot}\n'
          '👥 ${reservation.numberOfPlayers} joueurs · '
          '💰 ${reservation.totalPrice.toStringAsFixed(0)} DH',
      type: 'reservation',
      phone: user?.phone,
    );

    await _botSay(
      '🎉 Réservation confirmée !\n\n'
      '🏟️ ${reservation.courtName}\n'
      '📅 ${DateFormat('dd/MM/yyyy').format(reservation.date)} · ${reservation.timeSlot}\n'
      '👥 ${reservation.numberOfPlayers} joueurs\n'
      '💰 ${reservation.totalPrice.toStringAsFixed(0)} DH',
      _Input.action,
    );
  }

  // ── Match flow ───────────────────────────────────────────────────────────────

  Future<void> _onMatchAction(String label) async {
    _addUserMsg(label);
    if (label.contains('Rejoindre')) {
      await _botSay('Quel niveau recherchez-vous ?', _Input.matchJoinLevel);
    } else {
      setState(() => _isTyping = true);
      _scrollToBottom();
      final auth = context.read<AuthProvider>();
      final userId = auth.currentUser?.id ?? '';
      final all = await _resSvc.getForUser(userId);
      final now = DateTime.now();
      final future = all
          .where((r) =>
              r.date.isAfter(now.subtract(const Duration(hours: 2))))
          .toList();
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _userReservations = future;
      });

      if (future.isEmpty) {
        await _botSay(
          'Vous n\'avez pas de réservation à venir 😕\nRéservez d\'abord un terrain pour créer un match.',
          _Input.action,
        );
      } else {
        await _botSay(
          'Sur quelle réservation souhaitez-vous créer un match ?',
          _Input.reservationSelect,
        );
      }
    }
  }

  Future<void> _onJoinLevel(int level, String label) async {
    _addUserMsg(label);
    setState(() => _isTyping = true);
    _scrollToBottom();

    final userId = context.read<AuthProvider>().currentUser?.id ?? '';
    final all = await _matchSvc.getAll();
    final now = DateTime.now();
    var upcoming = all
        .where((m) => m.date.isAfter(now.subtract(const Duration(hours: 2))))
        .toList();

    if (level > 0) {
      upcoming = upcoming.where((m) => m.level == level).toList();
    }

    // Exclude full matches and matches the user created or already joined
    final available = upcoming
        .where((m) =>
            !m.isFull &&
            m.organizerId != userId &&
            !m.players.any((p) => p.id == userId))
        .toList();

    if (!mounted) return;
    setState(() {
      _isTyping = false;
      _availableMatches = available;
    });

    if (available.isEmpty) {
      await _botSay(
        'Aucun match disponible${level > 0 ? ' pour ce niveau' : ''} 😕\nEssayez un autre niveau :',
        _Input.matchJoinLevel,
      );
    } else {
      final n = available.length;
      await _botSay(
        '$n match${n > 1 ? 's' : ''} disponible${n > 1 ? 's' : ''} 🎾\nAppuyez sur un match pour le rejoindre :',
        _Input.matchCards,
      );
    }
  }

  Future<void> _onJoinMatch(Match match) async {
    _addUserMsg('Rejoindre — ${match.courtName}');
    setState(() => _saving = true);

    final auth = context.read<AuthProvider>();
    final player = MatchPlayer(
      id: auth.currentUser?.id ?? const Uuid().v4(),
      name: auth.currentUser?.fullName ?? '',
      hasPaid: false,
      joinedAt: DateTime.now(),
    );

    final success = await _matchSvc.joinMatch(match.id, player);
    if (!mounted) return;
    setState(() => _saving = false);

    if (success) {
      final user = auth.currentUser;
      // Notify the joiner
      _notifSvc.push(
        userId: user?.id ?? '',
        title: 'Match rejoint ✅',
        body: '🏟️ ${match.courtName}\n'
            '📅 ${DateFormat('dd/MM/yyyy').format(match.date)} · ${match.timeSlot}\n'
            '👥 ${match.players.length + 1}/${match.maxPlayers} joueurs',
        type: 'match',
        phone: user?.phone,
      );
      // Notify the organizer if different
      if (match.organizerId.isNotEmpty && match.organizerId != (user?.id ?? '')) {
        final orgDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(match.organizerId)
            .get();
        final orgPhone = orgDoc.data()?['phone'] as String? ?? '';
        _notifSvc.push(
          userId: match.organizerId,
          title: 'Nouveau joueur dans votre match 🎾',
          body: '${user?.fullName ?? 'Un joueur'} a rejoint votre match\n'
              '🏟️ ${match.courtName} · ${match.timeSlot}',
          type: 'match',
          phone: orgPhone,
        );
      }
      await _botSay(
        '🎉 Vous avez rejoint le match !\nVoici les détails :',
        _Input.none,
      );
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => MatchDetailScreen(matchId: match.id)),
        ).then((_) => _botSay('Autre chose ? 😊', _Input.action));
      }
    } else {
      await _botSay(
        'Désolé, ce match est complet ou vous êtes déjà inscrit 😕\nChoisissez un autre match :',
        _Input.matchCards,
      );
    }
  }

  Future<void> _onReservationSelected(Reservation r) async {
    _selectedReservation = r;
    _addUserMsg('${r.courtName} · ${DateFormat('dd/MM').format(r.date)} ${r.timeSlot}');
    await _botSay('Combien de joueurs maximum pour ce match ?', _Input.matchPlayerCount);
  }

  Future<void> _onMatchPlayerCount(int count) async {
    _maxMatchPlayers = count;
    _addUserMsg('$count joueurs');
    await _botSay('Quel niveau pour ce match ?', _Input.matchLevel);
  }

  Future<void> _onMatchLevel(int level, String label) async {
    _matchLevel = level;
    _addUserMsg(label);
    await _botSay('Récapitulatif du match :', _Input.confirmMatch);
  }

  Future<void> _confirmMatch() async {
    _addUserMsg('Créer le match');
    setState(() => _saving = true);

    final auth = context.read<AuthProvider>();
    final res = _selectedReservation!;
    final court = context.read<CourtProvider>().findById(res.courtId);
    final pricePerPlayer =
        (court?.pricePerHour ?? 0) / _maxMatchPlayers;

    final userId = auth.currentUser?.id ?? '';
    final match = Match(
      id: const Uuid().v4(),
      organizerId: userId,
      courtId: res.courtId,
      courtName: res.courtName,
      date: res.date,
      timeSlot: res.timeSlot,
      organizerName: auth.currentUser?.fullName ?? '',
      maxPlayers: _maxMatchPlayers,
      players: [
        MatchPlayer(
          id: userId, // use auth ID so MatchDetailScreen recognizes the organizer
          name: auth.currentUser?.fullName ?? '',
          hasPaid: false,
          joinedAt: DateTime.now(),
        ),
      ],
      pricePerPlayer: pricePerPlayer,
      status: 'open',
      createdAt: DateTime.now(),
      level: _matchLevel,
    );

    await _matchSvc.save(match);
    if (!mounted) return;
    setState(() => _saving = false);

    // Notify the organizer
    final user = auth.currentUser;
    _notifSvc.push(
      userId: userId,
      title: 'Match créé ✅',
      body: '🏟️ ${match.courtName}\n'
          '📅 ${DateFormat('dd/MM/yyyy').format(match.date)} · ${match.timeSlot}\n'
          '👥 Max ${match.maxPlayers} joueurs · ${match.pricePerPlayer.toStringAsFixed(0)} DH/joueur',
      type: 'match',
      phone: user?.phone,
    );

    final levelLabel = _matchLevel > 0 ? levelLabels[_matchLevel] : 'Tous niveaux';
    await _botSay(
      '🎉 Match créé avec succès !\n\n'
      '🏟️ ${match.courtName}\n'
      '📅 ${DateFormat('dd/MM/yyyy').format(match.date)} · ${match.timeSlot}\n'
      '👥 Max ${match.maxPlayers} joueurs\n'
      '🎯 Niveau : $levelLabel\n'
      '💰 ${match.pricePerPlayer.toStringAsFixed(0)} DH/joueur',
      _Input.action,
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              itemCount: _msgs.length + (_isTyping ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (_isTyping && i == _msgs.length) {
                  return _buildTypingIndicator();
                }
                final msg = _msgs[i];
                final isLast = i == _msgs.length - 1;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBubble(msg),
                    if (isLast && !_isTyping && !_saving)
                      _buildInteraction(),
                  ],
                );
              },
            ),
          ),
          if (_saving)
            const LinearProgressIndicator(
                color: AppTheme.accent, minHeight: 3),
          _buildHint(),
        ],
      ),
    );
  }

  // ── Bubbles ──────────────────────────────────────────────────────────────────

  Widget _buildBubble(_Msg msg) {
    if (msg.isBot) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, top: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child:
                  const Center(child: Text('🎾', style: TextStyle(fontSize: 14))),
            ),
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Text(msg.text,
                    style: const TextStyle(fontSize: 14, height: 1.5)),
              ),
            ),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Text(msg.text,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, height: 1.45)),
          ),
        ),
      );
    }
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8, top: 2),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child:
                const Center(child: Text('🎾', style: TextStyle(fontSize: 14))),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  // ── Interaction widgets ──────────────────────────────────────────────────────

  Widget _buildInteraction() {
    switch (_input) {
      case _Input.action:
        return _quickReplies([
          ('🎾 Réserver un terrain', () => _onAction('Réserver un terrain')),
          ('⚡ Rejoindre / créer un match',
              () => _onAction('Rejoindre / créer un match')),
        ]);
      case _Input.courtType:
        return _quickReplies([
          ('🏠 Couvert', () => _onCourtType('indoor', '🏠 Couvert')),
          ('☀️ Extérieur', () => _onCourtType('outdoor', '☀️ Extérieur')),
          ('🎯 Peu importe', () => _onCourtType('all', '🎯 Peu importe')),
        ]);
      case _Input.date:
        return _dateButton();
      case _Input.slot:
        return _slotChips();
      case _Input.courtSelect:
        return _courtCards();
      case _Input.playerCount:
        return _playerCountButtons();
      case _Input.confirmBooking:
        return _bookingConfirmCard();
      case _Input.matchAction:
        return _quickReplies([
          ('👥 Rejoindre un match', () => _onMatchAction('Rejoindre un match')),
          ('✏️ Créer un match', () => _onMatchAction('Créer un match')),
        ]);
      case _Input.matchJoinLevel:
        return _joinLevelChips();
      case _Input.matchCards:
        return _matchJoinCards();
      case _Input.reservationSelect:
        return _reservationCards();
      case _Input.matchPlayerCount:
        return _matchPlayerCountButtons();
      case _Input.matchLevel:
        return _levelChips();
      case _Input.confirmMatch:
        return _matchConfirmCard();
      case _Input.none:
        return const SizedBox.shrink();
    }
  }

  // ── Quick replies ────────────────────────────────────────────────────────────

  Widget _quickReplies(List<(String, VoidCallback)> options) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 6, 0, 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((opt) => GestureDetector(
          onTap: opt.$2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.primary.withOpacity(0.45)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1)),
              ],
            ),
            child: Text(opt.$1,
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        )).toList(),
      ),
    );
  }

  // ── Date button ──────────────────────────────────────────────────────────────

  Widget _dateButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 6, 0, 14),
      child: GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _date,
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 60)),
            builder: (ctx, child) => Theme(
              data: Theme.of(ctx).copyWith(
                colorScheme:
                    const ColorScheme.light(primary: AppTheme.primary),
              ),
              child: child!,
            ),
          );
          if (picked != null) _onDatePicked(picked);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today, color: Colors.white, size: 15),
              const SizedBox(width: 8),
              Text(
                '📅  ${DateFormat('dd/MM/yyyy').format(_date)}  →  Changer',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Slot chips ───────────────────────────────────────────────────────────────

  Widget _slotChips() {
    final slots = _availableSlots.isNotEmpty ? _availableSlots : timeSlots;
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 6, 4, 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: slots
            .map((slot) => GestureDetector(
                  onTap: () => _onSlotPicked(slot),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.primary.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 3,
                            offset: const Offset(0, 1)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time,
                            size: 13, color: AppTheme.primary),
                        const SizedBox(width: 5),
                        Text(slot,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary)),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ── Court cards ──────────────────────────────────────────────────────────────

  Widget _courtCards() {
    if (_availableCourts.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(40, 6, 12, 14),
        itemCount: _availableCourts.length,
        itemBuilder: (ctx, i) {
          final court = _availableCourts[i];
          return GestureDetector(
            onTap: () => _onCourtSelected(court),
            child: Container(
              width: 190,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: CourtImageWidget(court: court, height: 88),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(court.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(court.address,
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade600),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${court.pricePerHour.toStringAsFixed(0)}DH',
                              style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: court.isIndoor
                                    ? Colors.blue.shade50
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                court.isIndoor ? 'Couvert' : 'Extérieur',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: court.isIndoor
                                        ? Colors.blue.shade700
                                        : Colors.orange.shade700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text('Sélectionner →',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Player count (booking) ───────────────────────────────────────────────────

  Widget _playerCountButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 6, 0, 14),
      child: Row(
        children: [2, 3, 4].map((n) => GestureDetector(
          onTap: () => _onPlayerCount(n),
          child: Container(
            margin: const EdgeInsets.only(right: 10),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$n',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                Text('joueur${n > 1 ? 's' : ''}',
                    style: TextStyle(
                        fontSize: 9, color: Colors.grey.shade600)),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }

  // ── Booking confirm card ─────────────────────────────────────────────────────

  Widget _bookingConfirmCard() {
    if (_selectedCourt == null) return const SizedBox.shrink();
    final court = _selectedCourt!;
    final total = court.pricePerHour;

    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 6, 8, 14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.06),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long,
                      color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  const Text('Récapitulatif',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _summaryRow('🏟️', 'Terrain', court.name),
                  _summaryRow('📅', 'Date',
                      DateFormat('dd/MM/yyyy').format(_date)),
                  if (_selectedSlot.isNotEmpty)
                    _summaryRow('🕐', 'Créneau', _selectedSlot),
                  _summaryRow('👥', 'Joueurs', '$_players joueurs'),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${total.toStringAsFixed(0)} DH',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                              fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        _addUserMsg('Annuler');
                        _botSay(
                            'D\'accord, pas de problème 😊\nQue souhaitez-vous faire ?',
                            _Input.action);
                      },
                      child: const Text('Annuler',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _confirmBooking,
                      child: const Text('Confirmer',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Reservation cards (for match creation) ───────────────────────────────────

  Widget _reservationCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 6, 8, 14),
      child: Column(
        children: _userReservations.map((r) {
          return GestureDetector(
            onTap: () => _onReservationSelected(r),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.sports_tennis,
                        color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.courtName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 3),
                        Text(
                          '${DateFormat('dd/MM/yyyy').format(r.date)} · ${r.timeSlot}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 13, color: AppTheme.primary),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Match player count ───────────────────────────────────────────────────────

  Widget _matchPlayerCountButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 6, 0, 14),
      child: Row(
        children: [2, 4].map((n) => GestureDetector(
          onTap: () => _onMatchPlayerCount(n),
          child: Container(
            margin: const EdgeInsets.only(right: 10),
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$n',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                Text('joueurs',
                    style: TextStyle(
                        fontSize: 9, color: Colors.grey.shade600)),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }

  // ── Level chips (match) ──────────────────────────────────────────────────────

  Widget _levelChips() {
    final options = <(int, String)>[
      (0, 'Tous niveaux'),
      ...List.generate(8, (i) => (i + 1, 'Niv.${i + 1} ${levelLabels[i + 1]}')),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 6, 4, 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((opt) => GestureDetector(
          onTap: () => _onMatchLevel(opt.$1, opt.$2),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1)),
              ],
            ),
            child: Text(opt.$2,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary)),
          ),
        )).toList(),
      ),
    );
  }

  // ── Match confirm card ───────────────────────────────────────────────────────

  Widget _matchConfirmCard() {
    if (_selectedReservation == null) return const SizedBox.shrink();
    final res = _selectedReservation!;
    final court = context.read<CourtProvider>().findById(res.courtId);
    final pricePerPlayer =
        (court?.pricePerHour ?? 0) / _maxMatchPlayers;
    final levelLabel =
        _matchLevel > 0 ? levelLabels[_matchLevel] : 'Tous niveaux';

    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 6, 8, 14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.06),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sports_tennis,
                      color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  const Text('Récapitulatif du match',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _summaryRow('🏟️', 'Terrain', res.courtName),
                  _summaryRow('📅', 'Date',
                      DateFormat('dd/MM/yyyy').format(res.date)),
                  _summaryRow('🕐', 'Créneau', res.timeSlot),
                  _summaryRow(
                      '👥', 'Joueurs max', '$_maxMatchPlayers joueurs'),
                  _summaryRow('🎯', 'Niveau', levelLabel),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Prix / joueur',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${pricePerPlayer.toStringAsFixed(0)} DH',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                              fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        _addUserMsg('Annuler');
                        _botSay(
                            'D\'accord 😊 Que souhaitez-vous faire ?',
                            _Input.action);
                      },
                      child: const Text('Annuler',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _confirmMatch,
                      child: const Text('Créer le match',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Join level chips ─────────────────────────────────────────────────────────

  Widget _joinLevelChips() {
    final options = <(int, String)>[
      (0, 'Tous niveaux'),
      ...List.generate(8, (i) => (i + 1, 'Niv.${i + 1} ${levelLabels[i + 1]}')),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 6, 4, 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((opt) => GestureDetector(
          onTap: () => _onJoinLevel(opt.$1, opt.$2),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1)),
              ],
            ),
            child: Text(opt.$2,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary)),
          ),
        )).toList(),
      ),
    );
  }

  // ── Match join cards ─────────────────────────────────────────────────────────

  Widget _matchJoinCards() {
    if (_availableMatches.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 6, 8, 14),
      child: Column(
        children: _availableMatches.map((match) {
          final spotsLeft = match.availableSpots;
          final levelLabel =
              match.level > 0 ? levelLabels[match.level] : 'Tous niveaux';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withOpacity(0.18)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.05),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sports_tennis,
                          color: AppTheme.primary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(match.courtName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.primary)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: spotsLeft > 0
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$spotsLeft place${spotsLeft > 1 ? 's' : ''} libre${spotsLeft > 1 ? 's' : ''}',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: spotsLeft > 0
                                  ? Colors.green.shade700
                                  : Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _matchInfoChip(
                              Icons.calendar_today,
                              DateFormat('dd/MM').format(match.date)),
                          const SizedBox(width: 8),
                          _matchInfoChip(
                              Icons.access_time, match.timeSlot),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _matchInfoChip(
                              Icons.person_outline,
                              'Par ${match.organizerName}'),
                          const SizedBox(width: 8),
                          if (match.level > 0)
                            _matchInfoChip(Icons.bar_chart, levelLabel),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${match.players.length}/${match.maxPlayers} joueurs  ·  ${match.pricePerPlayer.toStringAsFixed(0)} DH/joueur',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _onJoinMatch(match),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('Rejoindre',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _matchInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _summaryRow(String emoji, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_outlined,
              size: 16, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Appuyez sur une option pour continuer',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
          GestureDetector(
            onTap: _reset,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded,
                      size: 13, color: Colors.red.shade400),
                  const SizedBox(width: 4),
                  Text('Réinitialiser',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Typing dots animation ────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = (_ctrl.value + i * 0.3) % 1.0;
          final opacity = (0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2))
              .clamp(0.3, 1.0);
          return Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(opacity),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}
