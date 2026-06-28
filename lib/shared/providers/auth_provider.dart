import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import '../services/presence_service.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authService, this._fcm, this._presence) {
    _sub = _authService.authStateChanges().listen(_onAuthChanged);
  }

  final AuthService _authService;
  final FcmService _fcm;
  final PresenceService _presence;
  StreamSubscription<User?>? _sub;

  AuthStatus _status = AuthStatus.unknown;
  String? _uid;

  AuthStatus get status => _status;
  String? get uid => _uid;
  bool get isSignedIn => _status == AuthStatus.signedIn;

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      _uid = null;
      _status = AuthStatus.signedOut;
    } else {
      _uid = user.uid;
      _status = AuthStatus.signedIn;
      // Best-effort side effects; never let them break the auth flow.
      unawaited(_fcm.init(user.uid).catchError((_) {}));
      _presence.start(user.uid);
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    final uid = _uid;
    // Best-effort cleanup. These touch Firestore / Realtime DB and must never
    // prevent the user from actually signing out (e.g. on permission errors).
    if (uid != null) {
      try {
        await _presence.goOffline(uid);
      } catch (_) {/* ignore */}
      try {
        await _fcm.clearToken(uid);
      } catch (_) {/* ignore */}
    }
    _presence.dispose();
    await _authService.signOut();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
