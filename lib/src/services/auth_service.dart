import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  final _db = FirebaseFirestore.instance;

  AuthService() {
    _auth.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  User? get user => _user ?? _auth.currentUser;
  bool get isAuthenticated => user != null;
  String? get displayName => user?.displayName ?? user?.email?.split('@').first;

  Future<UserCredential> registerWithEmail(String email, String password, {String? displayName}) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    if (displayName != null && displayName.isNotEmpty) {
      await cred.user?.updateDisplayName(displayName);
    }
    await _ensureLandlordDoc(cred.user, displayNameHint: displayName);
    await cred.user?.reload();
    _user = _auth.currentUser;
    notifyListeners();
    return cred;
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      _user = cred.user;
      await _ensureLandlordDoc(_user);
      notifyListeners();
      return cred;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e));
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        googleProvider
          ..addScope('email')
          ..setCustomParameters({'prompt': 'select_account'});
        final cred = await _auth.signInWithPopup(googleProvider);
        _user = cred.user;
        await _ensureLandlordDoc(_user);
        notifyListeners();
        return cred;
      } else {
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          throw Exception('Sign in aborted');
        }
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final cred = await _auth.signInWithCredential(credential);
        _user = cred.user;
        await _ensureLandlordDoc(_user);
        notifyListeners();
        return cred;
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential' && e.email != null) {
        final methods = await _auth.fetchSignInMethodsForEmail(e.email!);
        final hint = methods.contains('password')
            ? 'Use email and password login for ${e.email}'
            : methods.isNotEmpty
                ? 'Use ${methods.first} to sign in for ${e.email}'
                : 'Try signing in with a different method for ${e.email}';
        throw Exception('This email is already registered with a different sign-in method. $hint');
      }
      throw Exception(_mapAuthError(e));
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await GoogleSignIn().signOut().catchError((_) {});
    }
    await _auth.signOut();
    _user = null;
    notifyListeners();
  }

  Future<void> _ensureLandlordDoc(User? user, {String? displayNameHint}) async {
    if (user == null) return;
    final ref = _db.collection('landlords').doc(user.uid);
    final snap = await ref.get();
    final now = FieldValue.serverTimestamp();
    final name = user.displayName ?? displayNameHint ?? user.email?.split('@').first;
    if (!snap.exists) {
      await ref.set({
        'name': name,
        'email': user.email,
        'active': true,
        'createdAt': now,
        'lastLoginAt': now,
      }, SetOptions(merge: true));
    } else {
      await ref.set({
        'name': name,
        'email': user.email,
        'lastLoginAt': now,
      }, SetOptions(merge: true));
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
        return 'Invalid email or password';
      case 'user-not-found':
        return 'No account found for that email';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      case 'invalid-email':
        return 'The email address is not valid';
      default:
        return 'Authentication failed: ${e.code}';
    }
  }
}
