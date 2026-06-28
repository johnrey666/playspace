import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  // No heavy work; system tray displays the notification automatically.
  debugPrint('BG message: ${message.messageId}');
}

/// Handles FCM token registration and surfaces foreground pushes as in-app
/// banners. Notification *sending* is performed by Cloud Functions / server
/// triggers reacting to Firestore writes (friend requests, challenges, etc.).
class FcmService {
  FcmService({FirebaseMessaging? messaging, FirebaseFirestore? firestore})
      : _messaging = messaging ?? FirebaseMessaging.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;

  final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  Future<void> init(String uid) async {
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await _messaging.getToken();
    if (token != null) await _saveToken(uid, token);
    _messaging.onTokenRefresh.listen((t) => _saveToken(uid, t));

    FirebaseMessaging.onMessage.listen(_showBanner);
  }

  Future<void> _saveToken(String uid, String token) async {
    // Best-effort: never let a token write crash the app (e.g. on permission
    // errors before rules are deployed).
    try {
      await _db.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
    } catch (_) {/* ignore */}
  }

  void _showBanner(RemoteMessage message) {
    final notif = message.notification;
    if (notif == null) return;
    final state = messengerKey.currentState;
    if (state == null) return;
    state.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notif.title != null)
              Text(notif.title!,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            if (notif.body != null) Text(notif.body!),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> clearToken(String uid) async {
    final token = await _messaging.getToken();
    if (token == null) return;
    await _db.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayRemove([token]),
    }, SetOptions(merge: true));
  }
}
