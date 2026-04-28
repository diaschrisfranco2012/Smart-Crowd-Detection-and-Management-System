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

  // 1. FOR FALLS & STAMPEDES (Loud, Red, Max Priority)
  Future<void> showEmergencyAlert(
    String title,
    String body,
  ) async {
    const AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      'emergency_channel',
      'Emergency Alerts',
      channelDescription:
          'Life-threatening emergencies',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFFD32F2F), // RED
      enableVibration: true,
      playSound: true,
    );
    await _notificationsPlugin.show(
      0,
      title,
      body,
      const NotificationDetails(
        android: androidDetails,
      ),
      payload: 'emergency',
    );
  }

  // 2. FOR PI OFFLINE / HARDWARE FAILURES (High Priority, Orange)
  Future<void> showSystemAlert(
    String title,
    String body,
  ) async {
    const AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      'system_channel',
      'System Alerts',
      channelDescription:
          'Hardware and network failures',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFFFF9800), // ORANGE
      enableVibration: true,
      playSound: true,
    );
    await _notificationsPlugin.show(
      1,
      title,
      body,
      const NotificationDetails(
        android: androidDetails,
      ),
      payload: 'system',
    );
  }

  // 3. FOR CROWD WARNINGS (Medium Priority, Blue)
  Future<void> showWarningAlert(
    String title,
    String body,
  ) async {
    const AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      'warning_channel',
      'Warning Alerts',
      channelDescription:
          'Crowd density warnings',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      color: Color(0xFF2196F3), // BLUE
      enableVibration:
          false, // Don't buzz their pocket for just a warning
    );
    await _notificationsPlugin.show(
      2,
      title,
      body,
      const NotificationDetails(
        android: androidDetails,
      ),
      payload: 'warning',
    );
  }
}
