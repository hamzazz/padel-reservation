import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import 'whatsapp_service.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  // Google Sign-In requires a clientId on web — disabled on web for now
  final GoogleSignIn? _googleSignIn = kIsWeb ? null : GoogleSignIn();

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  // ── Register ──────────────────────────────────────────────────────────
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
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final uid = cred.user!.uid;
      final isAdmin = email.trim().toLowerCase() == 'admin@padel.com';
      final user = AppUser(
        id: uid,
        email: email.trim().toLowerCase(),
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        phone: phone.trim(),
        level: level,
        walletBalance: isAdmin ? 500.0 : 0.0,
        avatarEmoji: avatarEmoji,
        isAdmin: isAdmin,
        friendIds: [],
        blockedIds: [],
        createdAt: DateTime.now(),
      );
      try {
        await _users.doc(uid).set(user.toMap()).timeout(
          const Duration(seconds: 15),
        );
      } catch (firestoreErr) {
        return 'Compte créé mais profil non sauvegardé. Vérifiez les règles Firestore. Erreur: $firestoreErr';
      }
      // Déconnexion immédiate — l'utilisateur doit se connecter manuellement
      await _auth.signOut();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') return 'Cet email est déjà utilisé';
      if (e.code == 'weak-password') return 'Mot de passe trop faible (min. 6 caractères)';
      if (e.code == 'invalid-email') return 'Email invalide';
      if (e.code == 'configuration-not-found' || e.code == 'internal-error') {
        return 'Firebase Auth non activé — allez dans Firebase Console > Authentication > Méthode de connexion > Email/Mot de passe > Activer';
      }
      return '[Auth: ${e.code}] ${e.message ?? 'Erreur inscription'}';
    } catch (e) {
      return 'Erreur inattendue: $e';
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────
  Future<({AppUser? user, String? error})> login(
      String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      AppUser? user;
      try {
        user = await _getUserDoc(cred.user!.uid);
      } catch (firestoreErr) {
        return (user: null, error: 'Connecté mais profil inaccessible. Vérifiez les règles Firestore. Erreur: $firestoreErr');
      }
      if (user == null) return (user: null, error: 'Profil introuvable dans Firestore');
      if (user.isBlockedByAdmin) {
        await _auth.signOut();
        return (user: null, error: 'Votre compte a été suspendu par un administrateur');
      }
      return (user: user, error: null);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        return (user: null, error: 'Email ou mot de passe incorrect');
      }
      if (e.code == 'wrong-password') {
        return (user: null, error: 'Mot de passe incorrect');
      }
      if (e.code == 'configuration-not-found' || e.code == 'internal-error') {
        return (user: null, error: 'Firebase Auth non activé — Firebase Console > Authentication > Email/Mot de passe > Activer');
      }
      return (user: null, error: '[Auth: ${e.code}] ${e.message ?? 'Erreur connexion'}');
    } catch (e) {
      return (user: null, error: 'Erreur inattendue: $e');
    }
  }

  // ── Google Sign-In ────────────────────────────────────────────────────
  Future<({AppUser? user, String? error})> loginWithGoogle() async {
    if (_googleSignIn == null) {
      return (user: null, error: 'Google Sign-In non disponible sur web');
    }
    try {
      final googleUser = await _googleSignIn!.signIn();
      if (googleUser == null) return (user: null, error: 'Annulé');
      final googleAuth = await googleUser!.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      final uid = cred.user!.uid;
      AppUser? user = await _getUserDoc(uid);
      if (user == null) {
        final names = (googleUser.displayName ?? 'Joueur Padel').split(' ');
        user = AppUser(
          id: uid,
          email: googleUser.email,
          firstName: names.first,
          lastName: names.length > 1 ? names.sublist(1).join(' ') : '',
          phone: '',
          level: 1,
          walletBalance: 0,
          avatarEmoji: '🎾',
          isAdmin: false,
          friendIds: [],
          blockedIds: [],
          createdAt: DateTime.now(),
        );
        await _users.doc(uid).set(user.toMap());
      }
      if (user.isBlockedByAdmin) {
        await _auth.signOut();
        return (user: null, error: 'Votre compte a été suspendu par un administrateur');
      }
      return (user: user, error: null);
    } catch (e) {
      return (user: null, error: 'Erreur Google Sign-In: $e');
    }
  }

  // ── Facebook Sign-In ──────────────────────────────────────────────────
  Future<({AppUser? user, String? error})> loginWithFacebook() async {
    try {
      final result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.cancelled) {
        return (user: null, error: 'Annulé');
      }
      if (result.status != LoginStatus.success) {
        return (user: null, error: 'Erreur Facebook: ${result.message}');
      }
      final credential = FacebookAuthProvider.credential(result.accessToken!.tokenString);
      final cred = await _auth.signInWithCredential(credential);
      final uid = cred.user!.uid;
      AppUser? user = await _getUserDoc(uid);
      if (user == null) {
        final data = await FacebookAuth.instance.getUserData();
        final name = (data['name'] as String?) ?? 'Joueur Padel';
        final names = name.split(' ');
        user = AppUser(
          id: uid,
          email: cred.user!.email ?? '',
          firstName: names.first,
          lastName: names.length > 1 ? names.sublist(1).join(' ') : '',
          phone: '',
          level: 1,
          walletBalance: 0,
          avatarEmoji: '🎾',
          isAdmin: false,
          friendIds: [],
          blockedIds: [],
          createdAt: DateTime.now(),
        );
        await _users.doc(uid).set(user.toMap());
      }
      if (user.isBlockedByAdmin) {
        await _auth.signOut();
        return (user: null, error: 'Votre compte a été suspendu par un administrateur');
      }
      return (user: user, error: null);
    } catch (e) {
      return (user: null, error: 'Erreur Facebook Sign-In: $e');
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _clearUserCache();
    await _googleSignIn?.signOut();
    await FacebookAuth.instance.logOut();
    await _auth.signOut();
  }

  // ── Get current user ──────────────────────────────────────────────────
  Future<AppUser?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    return await _getUserDoc(firebaseUser.uid);
  }

  // ── Update user profile ───────────────────────────────────────────────
  Future<void> updateUser(AppUser updated) async {
    await _users.doc(updated.id).set(updated.toMap());
    unawaited(_cacheUserLocally(updated));
  }

  // ── Get all users ────────────────────────────────────────────────────
  Future<List<AppUser>> getAllUsers() async {
    try {
      final snap = await _users.get();
      return snap.docs.map((d) => AppUser.fromMap(_toMap(d))).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Admin block / unblock ─────────────────────────────────────────────
  Future<void> adminBlockUser(String userId) async {
    await _users.doc(userId).update({'isBlockedByAdmin': true});
  }

  Future<void> adminUnblockUser(String userId) async {
    await _users.doc(userId).update({'isBlockedByAdmin': false});
  }

  // ── WhatsApp OTP via Meta Cloud API ──────────────────────────────────

  static String _phoneKey(String phone) =>
      phone.replaceAll(RegExp(r'[^\d]'), '');

  Future<String?> sendWhatsAppOtp(String phoneNumber) async {
    try {
      final key = _phoneKey(phoneNumber);
      if (key.length < 8) return 'Numéro invalide';

      final code = (100000 + Random().nextInt(900000)).toString();
      final expiresAt = DateTime.now().add(const Duration(minutes: 15));

      await _db.collection('otp_requests').doc(key).set({
        'code': code,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'attempts': 0,
      });

      await WhatsAppService.send(
        phoneNumber,
        '🎾 *Padel Club*\n\nCode de vérification : *$code*\n\n⏱️ Valable 15 minutes. Ne partagez pas ce code.',
      );
      return null;
    } catch (e) {
      return 'Erreur envoi OTP : $e';
    }
  }

  Future<({AppUser? user, String? error, bool isNew})> verifyWhatsAppOtp({
    required String phoneNumber,
    required String code,
  }) async {
    try {
      final key = _phoneKey(phoneNumber);
      final docRef = _db.collection('otp_requests').doc(key);
      final doc = await docRef.get();

      if (!doc.exists) {
        return (user: null, error: 'Code expiré. Demandez un nouveau code.', isNew: false);
      }

      final data = doc.data()!;
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      final attempts = (data['attempts'] as int?) ?? 0;

      if (DateTime.now().isAfter(expiresAt)) {
        await docRef.delete();
        return (user: null, error: 'Code expiré. Demandez un nouveau code.', isNew: false);
      }

      if (attempts >= 3) {
        await docRef.delete();
        return (user: null, error: 'Trop de tentatives. Demandez un nouveau code.', isNew: false);
      }

      if (data['code'] != code) {
        await docRef.update({'attempts': attempts + 1});
        final remaining = 2 - attempts;
        return (user: null, error: 'Code incorrect. $remaining essai(s) restant(s).', isNew: false);
      }

      await docRef.delete();

      // Sign in with Firebase using deterministic credentials from phone
      final email = '$key@padel.club';
      final password = 'Pdl_${key}_2024!';

      UserCredential cred;
      try {
        cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' ||
            e.code == 'invalid-credential' ||
            e.code == 'INVALID_LOGIN_CREDENTIALS') {
          cred = await _auth.createUserWithEmailAndPassword(
              email: email, password: password);
        } else {
          rethrow;
        }
      }

      final uid = cred.user!.uid;
      final existing = await _getUserDoc(uid);

      if (existing != null) {
        if (existing.isBlockedByAdmin) {
          await _auth.signOut();
          return (user: null, error: 'Compte suspendu par un administrateur.', isNew: false);
        }
        return (user: existing, error: null, isNew: false);
      }

      // New user — create a minimal doc now so authStateChanges finds it
      // ProfileSetupScreen will complete the profile (name, level, avatar)
      final newUser = AppUser(
        id: uid,
        email: email,
        firstName: '',
        lastName: '',
        phone: phoneNumber,
        level: 1,
        walletBalance: 0,
        avatarEmoji: '🎾',
        isAdmin: false,
        friendIds: [],
        blockedIds: [],
        createdAt: DateTime.now(),
      );
      await _users.doc(uid).set(newUser.toMap());
      return (user: newUser, error: null, isNew: true);
    } on FirebaseAuthException catch (e) {
      return (user: null, error: '[${e.code}] ${e.message ?? 'Erreur auth'}', isNew: false);
    } catch (e) {
      return (user: null, error: 'Erreur : $e', isNew: false);
    }
  }

  // ── Firebase Auth state stream ────────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Helpers ───────────────────────────────────────────────────────────

  static const _kUserCacheKey = 'padel_user_cache';

  Future<void> _cacheUserLocally(AppUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUserCacheKey, jsonEncode(user.toMap()));
    } catch (_) {}
  }

  Future<AppUser?> _loadUserLocally(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kUserCacheKey);
      if (raw == null) return null;
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final user = AppUser.fromMap(map);
      return user.id == uid ? user : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearUserCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kUserCacheKey);
    } catch (_) {}
  }

  Future<AppUser?> _getUserDoc(String uid) async {
    // 1. Try Firestore server
    try {
      final doc = await _users.doc(uid).get();
      if (!doc.exists) return null;
      final user = AppUser.fromMap(_toMap(doc));
      unawaited(_cacheUserLocally(user)); // Keep local cache fresh
      return user;
    } catch (_) {}
    // 2. Try Firestore local cache (works offline if previously loaded)
    try {
      final doc = await _users.doc(uid).get(const GetOptions(source: Source.cache));
      if (!doc.exists) return null;
      return AppUser.fromMap(_toMap(doc));
    } catch (_) {}
    // 3. Last resort: SharedPreferences — user stays logged in
    return _loadUserLocally(uid);
  }

  Map<String, dynamic> _toMap(DocumentSnapshot<Map<String, dynamic>> doc) {
    return _convertTimestamps(doc.data()!);
  }

  static Map<String, dynamic> _convertTimestamps(Map<String, dynamic> map) {
    return map.map((key, value) {
      if (value is Timestamp) {
        return MapEntry(key, value.toDate().toIso8601String());
      }
      if (value is Map<String, dynamic>) {
        return MapEntry(key, _convertTimestamps(value));
      }
      return MapEntry(key, value);
    });
  }
}
