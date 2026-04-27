import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/app_user.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();

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
        user = await _getUserDoc(cred.user!.uid).timeout(
          const Duration(seconds: 15),
        );
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
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return (user: null, error: 'Annulé');
      final googleAuth = await googleUser.authentication;
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
    await _googleSignIn.signOut();
    await FacebookAuth.instance.logOut();
    await _auth.signOut();
  }

  // ── Get current user ──────────────────────────────────────────────────
  Future<AppUser?> getCurrentUser() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) return null;
      return await _getUserDoc(firebaseUser.uid).timeout(
        const Duration(seconds: 15),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Update user profile ───────────────────────────────────────────────
  Future<void> updateUser(AppUser updated) async {
    await _users.doc(updated.id).set(updated.toMap());
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

  // ── Phone Auth — send OTP ─────────────────────────────────────────────
  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required void Function(PhoneAuthCredential) onAutoVerified,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String error) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: onAutoVerified,
      verificationFailed: (e) {
        if (e.code == 'invalid-phone-number') {
          onError('Numéro de téléphone invalide');
        } else if (e.code == 'too-many-requests') {
          onError('Trop de tentatives. Réessayez plus tard.');
        } else {
          onError('Erreur [${e.code}]: ${e.message}');
        }
      },
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  // ── Phone Auth — verify OTP ───────────────────────────────────────────
  Future<({AppUser? user, String? error, bool isNew})> signInWithPhone({
    required String verificationId,
    required String smsCode,
    String? firstName,
    String? lastName,
    String? avatarEmoji,
    int level = 1,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final cred = await _auth.signInWithCredential(credential);
      final uid = cred.user!.uid;

      AppUser? existing = await _getUserDoc(uid);
      if (existing != null) {
        if (existing.isBlockedByAdmin) {
          await _auth.signOut();
          return (user: null, error: 'Compte suspendu par un administrateur', isNew: false);
        }
        return (user: existing, error: null, isNew: false);
      }

      // New user — create profile
      final phone = cred.user!.phoneNumber ?? '';
      final user = AppUser(
        id: uid,
        email: '',
        firstName: firstName ?? 'Joueur',
        lastName: lastName ?? '',
        phone: phone,
        level: level,
        walletBalance: 0,
        avatarEmoji: avatarEmoji ?? '🎾',
        isAdmin: false,
        friendIds: [],
        blockedIds: [],
        createdAt: DateTime.now(),
      );
      await _users.doc(uid).set(user.toMap());
      return (user: user, error: null, isNew: true);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') {
        return (user: null, error: 'Code incorrect. Vérifiez et réessayez.', isNew: false);
      }
      if (e.code == 'session-expired') {
        return (user: null, error: 'Code expiré. Demandez un nouveau code.', isNew: false);
      }
      return (user: null, error: 'Erreur [${e.code}]: ${e.message}', isNew: false);
    } catch (e) {
      return (user: null, error: 'Erreur: $e', isNew: false);
    }
  }

  // ── Firebase Auth state stream ────────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Helpers ───────────────────────────────────────────────────────────
  Future<AppUser?> _getUserDoc(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(_toMap(doc));
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
