import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../models/member_model.dart';
import '../../models/alert_model.dart';
import '../../services/database_service.dart';
import '../feed/feed_screen.dart';
import '../ideas/idea_box_screen.dart';
import '../finance/my_account_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../alerts/user_alerts_screen.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_header_title.dart';
import '../../widgets/user_menu_button.dart';
import '../auth/auth_wrapper.dart';
import '../../widgets/app_tutorial.dart';
import '../../theme/app_theme.dart';

class NavigationWrapper extends StatefulWidget {
  const NavigationWrapper({super.key});

  @override
  State<NavigationWrapper> createState() => _NavigationWrapperState();
}

class _NavigationWrapperState extends State<NavigationWrapper> {
  int _selectedIndex = 0;
  bool _tutorialChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkTutorial();
  }

  void _checkTutorial() {
    if (_tutorialChecked) return;
    
    final userProfile = Provider.of<UserProvider>(context, listen: false).userProfile;
    if (userProfile != null && !userProfile.hasSeenTutorial && userProfile.status == UserStatus.actif) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppTutorial.show(context, userProfile.id);
      });
      _tutorialChecked = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = Provider.of<UserProvider>(context).userProfile;
    if (userProfile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    final bool isAdmin = userProfile.role != UserRole.membre;

    final List<Widget> screens = [
      const FeedScreen(),
      const IdeaBoxScreen(),
      const MyAccountScreen(),
    ];

    final List<BottomNavigationBarItem> items = [
      const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
      const BottomNavigationBarItem(icon: Icon(Icons.lightbulb), label: 'Idées'),
      const BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Mon Compte'),
    ];

    if (_selectedIndex >= screens.length) {
      _selectedIndex = screens.length - 1;
    }

    return Scaffold(
      appBar: AppBar(
        title: const AppHeaderTitle(),
        actions: [
          StreamBuilder<List<AlertModel>>(
            stream: DatabaseService().getPendingAlertsForUser(userProfile.id, userProfile.role),
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
          const UserMenuButton(),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      floatingActionButton: (userProfile.role == UserRole.tresorier || userProfile.role == UserRole.president)
          ? StreamBuilder<List<MemberModel>>(
              stream: DatabaseService().getMembersByStatus(
                userProfile.role == UserRole.tresorier 
                    ? UserStatus.enAttenteTresorier 
                    : UserStatus.enAttentePresident
              ),
              builder: (context, snapshot) {
                final pending = snapshot.data ?? [];
                if (pending.isEmpty) return const SizedBox.shrink();

                return FloatingActionButton.extended(
                  heroTag: 'validation_quick_action',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
                    );
                  },
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.darkBlue,
                  icon: const Icon(Icons.how_to_reg),
                  label: Text(
                    pending.length == 1 
                        ? 'ACTIVER ${pending.first.prenom.toUpperCase()}' 
                        : 'VALIDATIONS (${pending.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: items,
      ),
    );
  }
}
