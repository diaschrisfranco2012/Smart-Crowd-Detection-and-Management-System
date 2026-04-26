import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin
  _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings
    initializationSettingsAndroid =
        AndroidInitializationSettings(
          '@mipmap/ic_launcher',
        );

    const InitializationSettings
    initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
        );

    // Renamed callback from onSelectNotification to onDidReceiveNotificationResponse
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse details) {
            debugPrint(
              "Notification Tapped: ${details.payload}",
            );
          },
    );
  }

  Future<void> showEmergencyAlert() async {
    // ONLY the first two are positional. Everything else is NAMED.
    const AndroidNotificationDetails
    androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'emergency_channel_id', // 1st Positional: channelId
          'Emergency Alerts', // 2nd Positional: channelName
          channelDescription:
              'High priority notifications for verified falls', // Named
          importance: Importance.max,
          priority: Priority.high,
          color: Color(0xFFD32F2F),
          enableVibration: true,
          playSound: true,
        );

    const NotificationDetails
    platformChannelSpecifics =
        NotificationDetails(
          android:
              androidPlatformChannelSpecifics,
        );

    await _notificationsPlugin.show(
      0,
      '🚨 EMERGENCY: FALL VERIFIED',
      'AI has confirmed a person has fallen in Zone A. Immediate assistance required.',
      platformChannelSpecifics, // This argument is now called notificationDetails in some versions
      payload: 'fall_alert',
    );
  }
}
