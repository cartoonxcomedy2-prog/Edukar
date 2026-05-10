import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static const String _channelId = 'sindh_updates_v2';
  static const String _channelName = 'Admission Updates';
  static const String _channelDescription =
      'Application status and deadline reminders';
  static const AndroidNotificationChannel _defaultChannel =
      AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
      );

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final Map<String, DateTime> _recentHashes = <String, DateTime>{};
  static const Duration _dedupeWindow = Duration(seconds: 30);
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(settings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_defaultChannel);
    await androidPlugin?.requestNotificationsPermission();

    _isInitialized = true;
    debugPrint('NotificationService initialized');
  }

  static Future<void> showNotification(String title, String body) async {
    await init();

    final hash = '$title::$body';
    final now = DateTime.now();
    _recentHashes.removeWhere(
      (_, timestamp) => now.difference(timestamp) > _dedupeWindow,
    );
    final previousAt = _recentHashes[hash];
    if (previousAt != null && now.difference(previousAt) <= _dedupeWindow) {
      return;
    }
    _recentHashes[hash] = now;

    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      channelShowBadge: true,
      ticker: 'Admission update',
      visibility: NotificationVisibility.public,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );

    debugPrint('NOTIFICATION SENT SUCCESS => $title | $body');
  }
}
