import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swee/widgets/alert_listener_wrapper.dart';
import '../../providers/user_provider.dart';
import '../../models/member_model.dart';
import '../../models/alert_model.dart';
import '../../services/database_service.dart';
import '../feed/feed_screen.dart';
import '../ideas/idea_box_screen.dart';
import '../finance/my_account_screen.dart';
import '../profile/my_profile_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../alerts/user_alerts_screen.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_header_title.dart';
import '../auth/auth_wrapper.dart';

class NavigationWrapper extends StatefulWidget {
  const NavigationWrapper({super.key});

  @override
  State<NavigationWrapper> createState() => _NavigationWrapperState();
}

class _NavigationWrapperState extends State<NavigationWrapper> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final userProfile = Provider.of<UserProvider>(context).userProfile;
    if (userProfile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    final bool isAdmin = userProfile.role != UserRole.membre;

    final List<Widget> screens = [
      const FeedScreen(),
      const IdeaBoxScreen(),
      const MyAccountScreen(),
      const MyProfileScreen(),
    ];

    final List<BottomNavigationBarItem> items = [
      const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
      const BottomNavigationBarItem(icon: Icon(Icons.lightbulb), label: 'Idées'),
      const BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Mon Compte'),
      const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
    ];

    // Ajustement de l'index si nécessaire (ex: si on était sur Idées et qu'on change de rôle)
    if (_selectedIndex >= screens.length) {
      _selectedIndex = screens.length - 1;
    }

    return AlertListenerWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: const AppHeaderTitle(),
          actions: [
            StreamBuilder<List<AlertModel>>(
              stream: DatabaseService().getPendingAlertsForUser(userProfile!.id, userProfile.role),
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications),
                      tooltip: 'Mes Alertes',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const UserAlertsScreen()),
                      ),
                    ),
                    if (count > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '$count',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            if (isAdmin)
              IconButton(
                icon: const Icon(Icons.admin_panel_settings),
                tooltip: 'Dashboard Admin',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Déconnexion',
              onPressed: () => _showLogoutDialog(context),
            ),
          ],
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: items,
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Fermer le dialog
              await AuthService().signOut();
              if (context.mounted) {
                // On s'assure de vider toute la pile de navigation pour revenir à l'AuthWrapper (Login)
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthWrapper()),
                  (route) => false,
                );
              }
            },
            child: const Text('Se déconnecter', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
