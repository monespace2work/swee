import 'package:flutter/material.dart';
import '../../home/navigation_wrapper.dart';
import '../../../services/database_service.dart';
import '../../../models/member_model.dart';
import '../../../models/alert_model.dart';
import '../../../services/auth_service.dart';
import '../../auth/auth_wrapper.dart';
import '../../../widgets/app_header_title.dart';
import '../../../widgets/user_menu_button.dart';
import '../secretary/association_settings_screen.dart';
import '../secretary/member_management_screen.dart';
import '../secretary/idea_moderation_screen.dart';
import '../secretary/post_management_screen.dart';
import '../alerts/manage_alerts_screen.dart';
import 'role_management_screen.dart';
import '../../../theme/app_theme.dart';
import '../../../models/post_model.dart';
import '../../../models/idea_model.dart';

class PresidentDashboard extends StatelessWidget {
  const PresidentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final dbService = DatabaseService();

    return Scaffold(
      appBar: AppBar(
        title: const AppHeaderTitle(showRole: true),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Mode Membre',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NavigationWrapper()),
            ),
          ),
          const UserMenuButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuickActions(context),
        label: const Text('Actions'),
        icon: const Icon(Icons.bolt),
        backgroundColor: AppTheme.gold,
        foregroundColor: AppTheme.darkBlue,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Tableau de Bord Président', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: MediaQuery.of(context).size.width > 900 ? 4 : 2.5,
              children: [
                StreamBuilder<List<MemberModel>>(
                  stream: dbService.getMembers(),
                  builder: (context, snapshot) {
                    final members = snapshot.data ?? [];
                    final active = members.where((m) => m.status == UserStatus.actif).length;
                    return _buildMenuCard(
                      context, 
                      'Membres', 
                      Icons.people, 
                      const MemberManagementScreen(),
                      stats: snapshot.hasData ? '$active Actifs' : '...',
                    );
                  }
                ),
                StreamBuilder<List<IdeaModel>>(
                  stream: dbService.getAllIdeas(),
                  builder: (context, snapshot) {
                    final ideas = snapshot.data ?? [];
                    final pending = ideas.where((i) => i.status == IdeaStatus.enAttenteTraitement).length;
                    return _buildMenuCard(
                      context, 
                      'Suggestions', 
                      Icons.lightbulb, 
                      const IdeaModerationScreen(),
                      stats: snapshot.hasData ? '$pending en attente' : '...',
                    );
                  }
                ),
                StreamBuilder<List<PostModel>>(
                  stream: dbService.getPosts(),
                  builder: (context, snapshot) {
                    final posts = snapshot.data ?? [];
                    final active = posts.where((p) => p.isActive).length;
                    return _buildMenuCard(
                      context, 
                      'Publications', 
                      Icons.post_add, 
                      const PostManagementScreen(),
                      stats: snapshot.hasData ? '$active Actives' : '...',
                    );
                  }
                ),
                _buildMenuCard(
                  context, 
                  'Identité Club', 
                  Icons.settings_suggest, 
                  const AssociationSettingsScreen()
                ),
                _buildMenuCard(
                  context, 
                  'Alertes', 
                  Icons.notification_important, 
                  const ManageAlertsScreen()
                ),
                _buildMenuCard(
                  context, 
                  'Rôles & Accès', 
                  Icons.admin_panel_settings, 
                  null, // Custom onTap handle
                  onTap: () => _verifyPresidentPassword(context, const RoleManagementScreen()),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 32, 16, 8),
              child: Text('Validations de Compte (Niveau 3)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            StreamBuilder<List<MemberModel>>(
              stream: dbService.getMembers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(child: CircularProgressIndicator()),
                );
                final pending = snapshot.data!.where((m) => m.status == UserStatus.enAttentePresident).toList();
                
                if (pending.isEmpty) return const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(child: Text('Aucune validation en attente.')),
                );

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pending.length,
                  itemBuilder: (context, index) {
                    final member = pending[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        title: Text('${member.prenom} ${member.nom}'),
                        subtitle: Text(member.email),
                        trailing: ElevatedButton(
                          onPressed: () => _validateMember(member.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.gold,
                            foregroundColor: AppTheme.darkBlue,
                          ),
                          child: const Text('Activer'),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, Widget? screen, {String? stats, VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 80),
        child: InkWell(
          onTap: onTap ?? () {
            if (screen != null) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 28, color: primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title, 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (stats != null)
                        Text(
                          stats,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _validateMember(String id) async {
    final dbService = DatabaseService();
    await dbService.updateMember(id, {'status': 'actif'});

    // AA to Member
    await dbService.sendAutomaticAlert(
      title: 'Bienvenue !',
      details: 'Votre inscription a été validée par le Président. Vous êtes maintenant membre actif.',
      initiatorId: dbService.currentUser?.uid ?? 'system',
      targetType: AlertTarget.manual,
      targetUserIds: [id],
    );
  }

  void _verifyPresidentPassword(BuildContext context, Widget screen) {
    final passwordController = TextEditingController();
    final authService = AuthService();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zone Sécurisée'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Veuillez confirmer votre mot de passe pour accéder à la gestion des rôles.'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await authService.reauthenticate(passwordController.text);
              if (success) {
                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mot de passe incorrect'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showQuickActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actions Rapides',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkBlue),
            ),
            const SizedBox(height: 20),
            _buildActionTile(
              context,
              icon: Icons.settings_suggest,
              title: 'Modifier l\'Identité du Club',
              subtitle: 'Nom, slogan, logo de l\'association',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AssociationSettingsScreen()));
              },
            ),
            _buildActionTile(
              context,
              icon: Icons.person_add,
              title: 'Gérer les Membres',
              subtitle: 'Valider, suspendre ou modifier un profil',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const MemberManagementScreen()));
              },
            ),
            _buildActionTile(
              context,
              icon: Icons.campaign,
              title: 'Nouvelle Publication',
              subtitle: 'Créer une annonce pour les membres',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PostManagementScreen()));
              },
            ),
            _buildActionTile(
              context,
              icon: Icons.security,
              title: 'Gérer les Rôles',
              subtitle: 'Modifier les droits et accès des membres',
              onTap: () {
                Navigator.pop(context);
                _verifyPresidentPassword(context, const RoleManagementScreen());
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.gold.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppTheme.darkBlue),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
    );
  }
}
