import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

/// Tracks the signed-in user's online/offline status using Realtime Database's
/// `.info/connected` channel + `onDisconnect`, mirroring the result into the
/// Firestore user doc so avatars across the app can show a green dot.
class PresenceService {
  PresenceService({FirebaseDatabase? database, FirebaseFirestore? firestore})
      : _db = database ?? FirebaseDatabase.instance,
        _fs = firestore ?? FirebaseFirestore.instance;

  final FirebaseDatabase _db;
  final FirebaseFirestore _fs;
  StreamSubscription<DatabaseEvent>? _sub;

  void start(String uid) {
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

        // Mirror to Firestore for cross-app querying.
        await _fs.collection('users').doc(uid).set({
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {/* ignore */}
    }, onError: (_) {/* ignore */});
  }

  Future<void> goOffline(String uid) async {
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
  }
}
