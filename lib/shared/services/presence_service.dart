import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

/// Tracks the signed-in user's online/offline status.
///
/// Online state is mirrored into the Firestore user doc (`isOnline` +
/// `lastSeen`) so avatars across the app can show a green dot. Because
/// Realtime Database's `onDisconnect` can only write to RTDB (not Firestore),
/// a Firestore `isOnline: true` could otherwise get stuck forever when the app
/// is killed. To prevent "ghost online" friends, we write a `lastSeen`
/// heartbeat every [_heartbeat] while connected; the UI treats a user as
/// online only when that timestamp is fresh (see [UserModel.isPresent]).
class PresenceService {
  PresenceService({FirebaseDatabase? database, FirebaseFirestore? firestore})
      : _db = database ?? FirebaseDatabase.instance,
        _fs = firestore ?? FirebaseFirestore.instance;

  final FirebaseDatabase _db;
  final FirebaseFirestore _fs;
  StreamSubscription<DatabaseEvent>? _sub;
  Timer? _heartbeatTimer;
  String? _uid;

  static const Duration _heartbeat = Duration(seconds: 60);

  void start(String uid) {
    _uid = uid;
    final statusRef = _db.ref('status/$uid');
    final connectedRef = _db.ref('.info/connected');

    _sub?.cancel();
    _sub = connectedRef.onValue.listen((event) async {
      final connected = event.snapshot.value == true;
      if (!connected) return;

      // Presence is best-effort: swallow permission / network errors so a
      // misconfigured backend can never crash the app on launch.
      try {
        await statusRef.onDisconnect().set({
          'online': false,
          'lastSeen': ServerValue.timestamp,
        });
        await statusRef
            .set({'online': true, 'lastSeen': ServerValue.timestamp});

        await _writeOnline(uid);
      } catch (_) {/* ignore */}
    }, onError: (_) {/* ignore */});

    // Keep the Firestore heartbeat fresh so the user keeps reading as online
    // while the app is alive, and naturally goes "offline" shortly after the
    // app is closed/killed.
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeat, (_) => _writeOnline(uid));
  }

  Future<void> _writeOnline(String uid) async {
    try {
      await _fs.collection('users').doc(uid).set({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {/* ignore */}
  }

  Future<void> goOffline(String uid) async {
    _heartbeatTimer?.cancel();
    try {
      await _db.ref('status/$uid').set({
        'online': false,
        'lastSeen': ServerValue.timestamp,
      });
      await _fs.collection('users').doc(uid).set({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {/* ignore */}
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _uid = null;
  }

  String? get uid => _uid;
}
