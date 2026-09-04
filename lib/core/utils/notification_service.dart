import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Request FCM permission
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('FCM Notification permission granted');
      }

      // 2. Initialize Local Notifications Plugin
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
          
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: DarwinInitializationSettings(),
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint("Notification tapped: ${response.payload}");
        },
      );

      // 3. Create High Importance Android Notification Channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'arena_high_importance_channel',
        'Arena TV High Priority Notifications',
        description: 'This channel is used for important match, deposit, withdrawal and announcement alerts.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(channel);
        await androidPlugin.requestNotificationsPermission();
      }

      // 4. Get FCM Device Token
      String? token = await _fcm.getToken();
      debugPrint("FCM Device Token: $token");

      // 5. Handle background handler setup
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 6. Handle foreground FCM messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Received FCM foreground message: ${message.notification?.title}');
        RemoteNotification? notification = message.notification;
        if (notification != null) {
          showNotification(
            title: notification.title ?? 'ArenaTV Alert 🔔',
            body: notification.body ?? '',
          );
        }
      });

      // 7. Handle background FCM message tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('App opened from FCM notification: ${message.data}');
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint("Error initializing NotificationService: $e");
    }
  }

  /// Displays a real status-bar / heads-up notification on Android/iOS device
  Future<void> showNotification({
    required String title,
    required String body,
    int? id,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'arena_high_importance_channel',
        'Arena TV High Priority Notifications',
        channelDescription: 'Important match, deposit, withdrawal and announcement alerts.',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      final notificationId = id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await _localNotifications.show(
        notificationId,
        title,
        body,
        platformDetails,
      );
    } catch (e) {
      debugPrint("Error showing local notification: $e");
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
    } catch (e) {
      debugPrint("Error subscribing to FCM topic $topic: $e");
    }
  }
}

// Global background handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling background FCM message: ${message.messageId}");
}
