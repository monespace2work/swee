import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'database_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // Utiliser un getter pour s'assurer que Firebase est initialisé avant l'accès
  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Gérer le clic sur la notification ici si nécessaire
      },
    );

    // Demander les permissions pour Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Configuration FCM
    await _setupFcm();
  }

  Future<void> _setupFcm() async {
    // Demander les permissions iOS/Android
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    }

    // Gestion du clic sur la notification quand l'app est fermée
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    // Gestion du clic quand l'app est en arrière-plan
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // Écouter les messages en premier plan
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("Message reçu en premier plan: ${message.notification?.title}");
      if (message.notification != null) {
        showAlertNotification(
          id: message.hashCode,
          title: message.notification!.title ?? "Alerte",
          body: message.notification!.body ?? "",
        );
      }
    });
  }

  void _handleMessage(RemoteMessage message) {
    debugPrint("App lancée via notification: ${message.data}");
    // Ici on peut naviguer vers un écran spécifique si besoin
  }

  /// Enregistre le token FCM de l'utilisateur en base de données pour permettre l'envoi de notifications push
  Future<void> syncToken(String userId) async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        await DatabaseService().updateFcmToken(userId, token);
        debugPrint("FCM Token synchronisé pour l'utilisateur $userId");
      }
      
      // S'abonner aux changements de token
      _fcm.onTokenRefresh.listen((newToken) {
        DatabaseService().updateFcmToken(userId, newToken);
      });
    } catch (e) {
      debugPrint("Erreur lors de la synchronisation du token FCM: $e");
    }
  }

  /// Affiche une notification même si l'app est en arrière-plan (utilisé par le background handler)
  Future<void> showNotificationDirectly({
    required int id,
    required String title,
    required String body,
  }) async {
    // Initialisation rapide pour le processus d'arrière-plan
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: DarwinInitializationSettings(),
    );
    await _notificationsPlugin.initialize(settings: initializationSettings);

    await showAlertNotification(id: id, title: title, body: body);
  }

  Future<void> showAlertNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'alerts_channel',
      'Alertes Importantes',
      channelDescription: 'Canal pour les alertes de l\'application',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }
}
