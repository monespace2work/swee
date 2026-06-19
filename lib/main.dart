import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:swee/providers/user_provider.dart';
import 'package:swee/screens/auth/login_screen.dart';
import 'package:swee/screens/home/navigation_wrapper.dart';
import 'package:swee/models/member_model.dart';
import 'package:swee/firebase_options.dart';
import 'package:swee/screens/auth/auth_wrapper.dart';
import 'package:swee/theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:swee/services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Gestionnaire de messages en arrière-plan (doit être une fonction de haut niveau)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Si le message contient des données mais pas de notification automatique
  if (message.data.isNotEmpty || message.notification != null) {
    final title = message.notification?.title ?? message.data['title'] ?? "Nouvelle alerte";
    final body = message.notification?.body ?? message.data['body'] ?? "Vous avez reçu un nouveau message";
    
    // On affiche une notification locale depuis l'arrière-plan
    await NotificationService().showNotificationDirectly(
      id: message.hashCode,
      title: title,
      body: body,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialisation sécurisée de Firebase
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    
    // Configuration Firestore
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint("Firestore settings already initialized or error: $e");
    }

    // Handler arrière-plan
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  await initializeDateFormatting('fr_FR', null);
  
  // Initialisation des notifications
  NotificationService().init().catchError((e) => debugPrint("Notification init error: $e"));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      title: 'Swee',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const AuthWrapper(),
    );
  }
}
