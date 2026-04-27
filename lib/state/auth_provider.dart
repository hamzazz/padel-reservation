import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/wallet_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final _auth = AuthService();
  final _wallet = WalletService();
  final _notif = NotificationService();

  AppUser? _user;
  int _unreadNotifs = 0;
  bool _loading = true;

  AppUser? get currentUser => _user;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isClubAdmin => _user?.isClubAdmin ?? false;
  String get clubId => _user?.clubId ?? '';
  int get unreadNotifs => _unreadNotifs;
  bool get loading => _loading;

  Future<void> init() async {
    _auth.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser == null) {
        _user = null;
        _unreadNotifs = 0;
        _loading = false;
        notifyListeners();
      } else {
        _user = await _auth.getCurrentUser();
        if (_user != null) await _refreshNotifCount();
        _loading = false;
        notifyListeners();
      }
    });
  }

  Future<String?> login(String email, String password) async {
    try {
      final result = await _auth.login(email, password);
      if (result.error != null) return result.error;
      _user = result.user;
      await _refreshNotifCount();
      notifyListeners();
      return null;
    } catch (e) {
      return 'Erreur connexion: $e';
    }
  }

  Future<String?> loginWithGoogle() async {
    try {
      final result = await _auth.loginWithGoogle();
      if (result.error != null && result.error != 'Annulé') return result.error;
      if (result.user != null) {
        _user = result.user;
        await _refreshNotifCount();
        notifyListeners();
      }
      return null;
    } catch (e) {
      return 'Erreur Google: $e';
    }
  }

  // ── Phone Auth ────────────────────────────────────────────────────────
  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String error) onError,
  }) async {
    await _auth.sendPhoneOtp(
      phoneNumber: phoneNumber,
      onAutoVerified: (credential) async {
        // Android auto-verification — sign in immediately
        final result = await _auth.signInWithPhone(
          verificationId: credential.verificationId ?? '',
          smsCode: credential.smsCode ?? '',
        );
        if (result.user != null) {
          _user = result.user;
          await _refreshNotifCount();
          notifyListeners();
        }
      },
      onCodeSent: onCodeSent,
      onError: onError,
    );
  }

  Future<({String? error, bool isNew})> verifyPhoneOtp({
    required String verificationId,
    required String smsCode,
    String? firstName,
    String? lastName,
    String? avatarEmoji,
    int level = 1,
  }) async {
    try {
      final result = await _auth.signInWithPhone(
        verificationId: verificationId,
        smsCode: smsCode,
        firstName: firstName,
        lastName: lastName,
        avatarEmoji: avatarEmoji,
        level: level,
      );
      if (result.error != null) return (error: result.error, isNew: false);
      _user = result.user;
      await _refreshNotifCount();
      notifyListeners();
      return (error: null, isNew: result.isNew);
    } catch (e) {
      return (error: 'Erreur: $e', isNew: false);
    }
  }

  Future<String?> loginWithFacebook() async {
    try {
      final result = await _auth.loginWithFacebook();
      if (result.error != null && result.error != 'Annulé') return result.error;
      if (result.user != null) {
        _user = result.user;
        await _refreshNotifCount();
        notifyListeners();
      }
      return null;
    } catch (e) {
      return 'Erreur Facebook: $e';
    }
  }

  Future<void> adminBlockUser(AppUser target) async {
    await _auth.adminBlockUser(target.id);
  }

  Future<void> adminUnblockUser(AppUser target) async {
    await _auth.adminUnblockUser(target.id);
  }

  Future<String?> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required int level,
    required String avatarEmoji,
  }) async {
    try {
      final err = await _auth.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        level: level,
        avatarEmoji: avatarEmoji,
      );
      if (err != null) return err;
      // authStateChanges listener in init() will set _user automatically
      return null;
    } catch (e) {
      return 'Erreur inscription: $e';
    }
  }

  Future<void> logout() async {
    await _auth.logout();
    _user = null;
    _unreadNotifs = 0;
    notifyListeners();
  }

  Future<void> updateProfile(AppUser updated) async {
    await _auth.updateUser(updated);
    _user = updated;
    notifyListeners();
  }

  // ── Wallet ────────────────────────────────────────────────────────────
  Future<bool> rechargeWallet(double amount) async {
    if (_user == null) return false;
    final updated = _user!.copyWith(walletBalance: _user!.walletBalance + amount);
    await _auth.updateUser(updated);
    await _wallet.addTransaction(
      userId: _user!.id,
      amount: amount,
      type: 'recharge',
      description: 'Recharge carte bancaire',
    );
    _user = updated;
    notifyListeners();
    return true;
  }

  Future<bool> debitWallet(double amount, String description) async {
    if (_user == null) return false;
    if (_user!.walletBalance < amount) return false;
    final updated = _user!.copyWith(walletBalance: _user!.walletBalance - amount);
    await _auth.updateUser(updated);
    await _wallet.addTransaction(
      userId: _user!.id,
      amount: amount,
      type: 'payment',
      description: description,
    );
    _user = updated;
    notifyListeners();
    return true;
  }

  Future<void> refundWallet(double amount, String description) async {
    if (_user == null) return;
    final updated = _user!.copyWith(walletBalance: _user!.walletBalance + amount);
    await _auth.updateUser(updated);
    await _wallet.addTransaction(
      userId: _user!.id,
      amount: amount,
      type: 'refund',
      description: description,
    );
    _user = updated;
    notifyListeners();
  }

  // ── Friends ───────────────────────────────────────────────────────────
  Future<void> addFriend(String friendId) async {
    if (_user == null) return;
    final ids = List<String>.from(_user!.friendIds);
    if (!ids.contains(friendId)) ids.add(friendId);
    await updateProfile(_user!.copyWith(friendIds: ids));
  }

  Future<void> removeFriend(String friendId) async {
    if (_user == null) return;
    final ids = List<String>.from(_user!.friendIds)..remove(friendId);
    await updateProfile(_user!.copyWith(friendIds: ids));
  }

  Future<void> blockUser(String userId) async {
    if (_user == null) return;
    final blocked = List<String>.from(_user!.blockedIds);
    if (!blocked.contains(userId)) blocked.add(userId);
    await updateProfile(_user!.copyWith(blockedIds: blocked));
  }

  Future<void> unblockUser(String userId) async {
    if (_user == null) return;
    final blocked = List<String>.from(_user!.blockedIds)..remove(userId);
    await updateProfile(_user!.copyWith(blockedIds: blocked));
  }

  // ── Notifications ─────────────────────────────────────────────────────
  Future<void> _refreshNotifCount() async {
    if (_user == null) return;
    _unreadNotifs = await _notif.unreadCount(_user!.id);
  }

  Future<void> refreshNotifs() async {
    await _refreshNotifCount();
    notifyListeners();
  }
}
