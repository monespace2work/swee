import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swee/theme/app_theme.dart';
import 'package:swee/providers/user_provider.dart';
import 'package:swee/models/member_model.dart';
import 'package:swee/services/auth_service.dart';
import 'package:swee/screens/admin/secretary/secretary_dashboard.dart';
import 'package:swee/screens/admin/treasurer/treasurer_dashboard.dart';
import 'package:swee/screens/admin/president/president_dashboard.dart';
import 'package:swee/screens/admin/advisor/advisor_dashboard.dart';
import 'package:swee/screens/auth/auth_wrapper.dart';
import 'package:swee/widgets/app_tutorial.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _tutorialChecked = false;

  void _checkTutorial(MemberModel? user) {
    if (_tutorialChecked) return;
    if (user != null && !user.hasSeenTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppTutorial.show(context, user.id);
      });
      _tutorialChecked = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.userProfile;

    // État de chargement élégant et léger
    if (userProvider.isLoading) {
      return _buildLoadingScreen(context);
    }

    _checkTutorial(user);

    // Gestion du cas où le profil est introuvable
    if (user == null) {
      return _buildStatusScreen(
        context,
        icon: Icons.error_outline,
        title: 'Accès Impossible',
        message: 'Impossible de charger votre profil administrateur.',
        buttonText: 'Se déconnecter',
        onPressed: () async {
          await AuthService().signOut();
          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const AuthWrapper()),
              (route) => false,
            );
          }
        },
        iconColor: Colors.redAccent,
      );
    }

    // Direction vers le tableau de bord approprié selon le rôle
    Widget dashboard;
    switch (user.role) {
      case UserRole.secretaire:
        dashboard = const SecretaryDashboard();
        break;
      case UserRole.tresorier:
        dashboard = const TreasurerDashboard();
        break;
      case UserRole.president:
        dashboard = const PresidentDashboard();
        break;
      case UserRole.conseiller:
        dashboard = const AdvisorDashboard();
        break;
      default:
        return _buildStatusScreen(
          context,
          icon: Icons.lock_outline,
          title: 'Accès Restreint',
          message: 'Vous ne disposez pas des droits d\'administration requis.',
          buttonText: 'Retour au Login',
          onPressed: () async {
            await AuthService().signOut();
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const AuthWrapper()),
                (route) => false,
              );
            }
          },
          iconColor: AppTheme.gold,
        );
    }

    return dashboard;
  }

  Widget _buildLoadingScreen(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.deepNavy : AppTheme.darkBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 100,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.shield, size: 80, color: AppTheme.gold),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.gold),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'SÉCURISATION DE L\'ACCÈS',
              style: TextStyle(
                color: AppTheme.gold.withOpacity(0.8),
                letterSpacing: 3,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusScreen(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onPressed,
    required Color iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 60, color: iconColor),
              ),
              const SizedBox(height: 32),
              Text(
                title,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16, 
                  color: isDark ? Colors.grey[400] : Colors.grey[600]
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onPressed,
                  child: Text(buttonText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
