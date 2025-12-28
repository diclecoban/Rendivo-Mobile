import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  final AndroidNotificationChannel _channel = const AndroidNotificationChannel(
    'rendivo_notifications',
    'Rendivo Notifications',
    description: 'General notifications',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    await _messaging.requestPermission();

    if (Platform.isIOS || Platform.isMacOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _local.initialize(initSettings);

    final androidPlugin = _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ;
    await androidPlugin?.createNotificationChannel(_channel);

    if (Platform.isAndroid) {
      await androidPlugin?.requestNotificationsPermission();
    }

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  Future<String?> getToken() async {
    return _messaging.getToken();
  }

  void listenForTokenRefresh(ValueChanged<String> onRefresh) {
    _messaging.onTokenRefresh.listen(onRefresh);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
