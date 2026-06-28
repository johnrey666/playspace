import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  User? get currentUser => _auth.currentUser;
  String? get currentUid => _auth.currentUser?.uid;
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  Future<bool> isUsernameAvailable(String username) async {
    final query = await _users
        .where('username', isEqualTo: username.toLowerCase())
        .limit(1)
        .get();
    return query.docs.isEmpty;
  }

  Future<UserModel> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    DateTime? birthday,
    String? photoUrl,
  }) async {
    final first = firstName.trim();
    final last = lastName.trim();
    final displayName = [first, last].where((e) => e.isNotEmpty).join(' ');

    // Create the auth account FIRST. The username uniqueness check reads
    // Firestore, which (under normal security rules) requires the caller to be
    // authenticated. Doing the read before sign-up would fail with
    // permission-denied and surface as a generic "could not create account".
    final UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e));
    }

    final user = cred.user!;
    final uid = user.uid;
    try {
      final username = await _generateUsername(first, last, email);

      final model = UserModel(
        uid: uid,
        displayName: displayName.isEmpty ? username : displayName,
        username: username,
        email: email.trim(),
        photoUrl: photoUrl,
        bio: '',
        firstName: first,
        lastName: last,
        birthday: birthday,
        friendIds: const [],
        createdAt: DateTime.now(),
      );
      await _users.doc(uid).set(model.toMap());
      await user.updateDisplayName(model.displayName);
      return model;
    } on AuthException {
      rethrow;
    } catch (_) {
      // Profile write failed (e.g. Firestore rules / connectivity). Clean up the
      // orphaned auth account so the email is free to use again.
      await _safeDelete(user);
      throw AuthException(
          'Could not finish setting up your account. Please try again.');
    }
  }

  /// Builds a unique @handle from the user's name (or email), appending a
  /// numeric suffix until it's free.
  Future<String> _generateUsername(
      String first, String last, String email) async {
    var base = (first + last)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (base.isEmpty) {
      base = email.split('@').first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    }
    if (base.isEmpty) base = 'player';
    if (base.length > 16) base = base.substring(0, 16);

    var candidate = base;
    var attempt = 0;
    while (!await isUsernameAvailable(candidate)) {
      attempt++;
      candidate = '$base${1000 + (attempt * 137) % 9000}';
      if (attempt > 12) {
        candidate = '$base${DateTime.now().millisecondsSinceEpoch % 100000}';
        break;
      }
    }
    return candidate;
  }

  /// Re-authenticates with the current password then updates to a new one.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw AuthException('You need to be signed in to change your password.');
    }
    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  Future<void> _safeDelete(User user) async {
    try {
      await user.delete();
    } catch (_) {
      // If deletion fails (e.g. requires recent login) just sign out so we
      // don't leave the app in a half-authenticated state.
      await _auth.signOut();
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  Future<void> signOut() => _auth.signOut();

  String _mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}
