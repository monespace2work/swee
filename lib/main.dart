import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:swee/providers/user_provider.dart';
import 'package:swee/firebase_options.dart';
import 'package:swee/screens/auth/auth_wrapper.dart';
import 'package:swee/theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:swee/services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

// Gestionnaire de messages en arrière-plan (doit être une fonction de haut niveau)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialisation minimale pour le background
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
    
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
  } catch (e) {
    debugPrint("Background Handler Error: $e");
  }
}

void main() async {
  final WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  
  // Préserver le splash screen jusqu'à ce que l'app soit prête
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  // Handler arrière-plan (à enregistrer le plus tôt possible)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    // Initialisation séquentielle pour éviter les conflits
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
    
    // Configuration Firestore
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    await initializeDateFormatting('fr_FR', null);
    
    // Initialisation des notifications
    await NotificationService().init();
  } catch (e) {
    debugPrint("Initialization error: $e");
  }
  
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Retirer le splash screen dès que le premier frame est prêt
    FlutterNativeSplash.remove();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Si l'application revient de l'arrière-plan, on force une petite reconstruction
    // pour éviter les écrans noirs sur certains appareils Android
    if (state == AppLifecycleState.resumed) {
      debugPrint("App resumed - checking state...");
      setState(() {});
    }
  }

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
