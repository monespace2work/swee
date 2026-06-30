import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../../models/member_model.dart';
import 'login_screen.dart';
import '../home/navigation_wrapper.dart';
import '../admin/admin_dashboard_screen.dart';
import '../../widgets/alert_listener_wrapper.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    // 1. État de chargement (Auth + Firestore)
    if (userProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text(
                "Initialisation sécurisée...",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // 2. Si aucun profil n'est chargé
    if (userProvider.userProfile == null) {
      return const LoginScreen();
    }

    // On prépare l'écran de destination selon le statut et le rôle
    Widget screen;

    // 3. Gestion des comptes en attente de validation
    if (userProvider.userProfile!.status == UserStatus.enAttenteTresorier ||
        userProvider.userProfile!.status == UserStatus.enAttentePresident) {
      screen = const PendingValidationScreen();
    }
    // 4. Gestion des comptes bloqués
    else if (userProvider.userProfile!.status == UserStatus.suspendu ||
        userProvider.userProfile!.status == UserStatus.desactive) {
      screen = const AccountBlockedScreen();
    }
    // 5. Redirection finale selon le rôle
    else if (userProvider.userProfile!.role == UserRole.membre) {
      screen = const NavigationWrapper();
    } else {
      // Pour tous les autres rôles (secretaire, tresorier, president)
      screen = const AdminDashboardScreen();
    }

    // On enveloppe l'écran choisi avec le listener d'alertes global
    return AlertListenerWrapper(child: screen);
  }
}

class PendingValidationScreen extends StatelessWidget {
  const PendingValidationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Validation en cours')),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_empty, size: 64, color: Colors.orange),
              ),
              const SizedBox(height: 32),
              const Text(
                'Compte en attente',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Votre compte est en cours de validation par les membres du bureau. Vous recevrez un accès complet dès approbation.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Provider.of<UserProvider>(context, listen: false).refreshProfile(),
                  child: const Text('Actualiser le statut'),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await AuthService().signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const AuthWrapper()),
                      (route) => false,
                    );
                  }
                },
                child: Text('Se déconnecter', style: TextStyle(color: colorScheme.primary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AccountBlockedScreen extends StatelessWidget {
  const AccountBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accès restreint')),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.block, size: 64, color: Colors.red),
              ),
              const SizedBox(height: 32),
              const Text(
                'Compte Bloqué',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Votre compte a été suspendu ou désactivé par l\'administration. Veuillez contacter le support pour plus d\'informations.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 48),
              TextButton(
                onPressed: () async {
                  await AuthService().signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const AuthWrapper()),
                      (route) => false,
                    );
                  }
                },
                child: const Text('Retour à la page de connexion'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
