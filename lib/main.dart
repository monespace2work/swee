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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialisation en parallèle pour gagner du temps au lancement
  await Future.wait([
    initializeDateFormatting('fr_FR', null),
    Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).then((_) {
      // Activer la persistance pour permettre un accès hors-ligne et un chargement instantané
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }).catchError((e) {
      debugPrint("Firebase initialization error: $e");
    }),
  ]);

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
