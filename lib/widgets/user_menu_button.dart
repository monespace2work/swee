import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';
import '../services/auth_service.dart';
import '../screens/profile/my_profile_screen.dart';
import '../screens/association/members_list_screen.dart';
import '../screens/auth/auth_wrapper.dart';
import 'app_tutorial.dart';
import '../theme/app_theme.dart';

class UserMenuButton extends StatelessWidget {
  const UserMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final user = Provider.of<UserProvider>(context).userProfile;

    Widget icon;
    if (user != null) {
      final initials = ((user.prenom.isNotEmpty ? user.prenom[0] : '') +
                        (user.nom.isNotEmpty ? user.nom[0] : '')).toUpperCase();
      icon = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? AppTheme.gold : Colors.white,
            width: 2,
          ),
        ),
        child: CircleAvatar(
          radius: 14,
          backgroundColor: isDark ? AppTheme.gold : AppTheme.darkBlue,
          backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
          child: user.photoUrl.isEmpty
              ? Text(
                  initials,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.deepNavy : Colors.white,
                  ),
                )
              : null,
        ),
      );
    } else {
      icon = const Icon(Icons.account_circle_outlined);
    }

    return PopupMenuButton<String>(
      icon: icon,
      tooltip: 'Menu utilisateur',
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) async {
        if (value == 'profile') {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Scaffold(
                  resizeToAvoidBottomInset: true,
                  appBar: AppBar(
                    title: const Text('Mon Profil'),
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  body: const MyProfileScreen(),
                ),
              ),
            ),
          );
        } else if (value == 'members') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MembersListScreen()),
          );
        } else if (value == 'tutorial') {
          if (user != null) {
            AppTutorial.show(context, user.id, isManualLaunch: true);
          }
        } else if (value == 'theme_light') {
          themeProvider.setThemeMode(ThemeMode.light);
        } else if (value == 'theme_dark') {
          themeProvider.setThemeMode(ThemeMode.dark);
        } else if (value == 'theme_system') {
          themeProvider.setThemeMode(ThemeMode.system);
        } else if (value == 'logout') {
          await AuthService().signOut();
          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const AuthWrapper()),
              (route) => false,
            );
          }
        }
      },
      itemBuilder: (context) {
        final initials = user != null 
            ? ((user.prenom.isNotEmpty ? user.prenom[0] : '') + (user.nom.isNotEmpty ? user.nom[0] : '')).toUpperCase()
            : '';
        
        return [
          // Header avec grande photo
          PopupMenuItem(
            enabled: false,
            height: 120,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppTheme.gold : AppTheme.darkBlue,
                        width: 3,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: isDark ? AppTheme.gold : AppTheme.darkBlue,
                      backgroundImage: (user != null && user.photoUrl.isNotEmpty) ? NetworkImage(user.photoUrl) : null,
                      child: (user != null && user.photoUrl.isEmpty)
                          ? Text(
                              initials,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.deepNavy : Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user != null ? '${user.prenom} ${user.nom}' : 'Utilisateur',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'profile',
            child: ListTile(
              leading: Icon(Icons.person_outline),
              title: Text('Profil'),
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const PopupMenuItem(
            value: 'members',
            child: ListTile(
              leading: Icon(Icons.people_outline),
              title: Text('Annuaire des Membres'),
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const PopupMenuItem(
            value: 'tutorial',
            child: ListTile(
              leading: Icon(Icons.help_outline),
              title: Text('Tutoriel'),
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const PopupMenuItem(
            value: 'theme_system',
            child: ListTile(
              leading: Icon(Icons.brightness_auto),
              title: Text('Thème Système'),
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
          PopupMenuItem(
            value: isDark ? 'theme_light' : 'theme_dark',
            child: ListTile(
              leading: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
              title: Text(isDark ? 'Passer au Clair' : 'Passer au Sombre'),
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            enabled: false,
            child: Center(
              child: Text(
                'Version 1.0.7',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const PopupMenuItem(
            value: 'logout',
            child: ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text('Déconnexion', style: TextStyle(color: Colors.red)),
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ];
      },
    );
  }
}
