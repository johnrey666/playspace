import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper around `flutter_local_notifications` used to surface a real
/// system notification (heads-up "snackbar" outside the app) when a message or
/// challenge arrives while PlaySpace is in the background.
///
/// Note: this fires from in-app Firestore listeners, so it works while the app
/// is alive in the background. Delivering pushes when the app is fully killed
/// requires a server (FCM via Cloud Functions), which needs the Blaze plan.
class LocalNotificationService {
  LocalNotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'playspace_social',
    'Messages & Challenges',
    description: 'Notifications for new messages and game challenges.',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (_ready) return;

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(settings: initSettings);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);
    await android?.requestNotificationsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    _ready = true;
  }

  Future<void> show({
    required String title,
    required String body,
    int? id,
  }) async {
    if (!_ready) {
      // Best-effort late init so a missed init() never silently drops alerts.
      try {
        await init();
      } catch (_) {
        return;
      }
    }
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'playspace_social',
        'Messages & Challenges',
        channelDescription:
            'Notifications for new messages and game challenges.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );
    final notifId =
        id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);
    try {
      await _plugin.show(
        id: notifId,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (_) {/* ignore */}
  }
}
