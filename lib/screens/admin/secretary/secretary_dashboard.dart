import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swee/providers/user_provider.dart';
import 'package:swee/screens/home/navigation_wrapper.dart';
import 'package:swee/screens/admin/secretary/member_management_screen.dart';
import 'package:swee/screens/admin/secretary/idea_moderation_screen.dart';
import 'package:swee/screens/admin/secretary/post_management_screen.dart';
import 'package:swee/screens/admin/secretary/association_settings_screen.dart';
import 'package:swee/screens/admin/alerts/manage_alerts_screen.dart';
import 'package:swee/services/database_service.dart';
import 'package:swee/models/member_model.dart';
import 'package:swee/models/post_model.dart';
import 'package:swee/models/idea_model.dart';
import 'package:swee/widgets/app_header_title.dart';
import 'package:swee/widgets/user_menu_button.dart';

class SecretaryDashboard extends StatelessWidget {
  const SecretaryDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final dbService = DatabaseService();
    final userProvider = Provider.of<UserProvider>(context);

    final List<Widget> menuCards = [
      if (userProvider.hasPermission('can_manage_members'))
        StreamBuilder<List<MemberModel>>(
          stream: dbService.getMembers(),
          builder: (context, snapshot) {
            final members = snapshot.data ?? [];
            final active = members.where((m) => m.status == UserStatus.actif).length;
            final pending = members.where((m) => m.status == UserStatus.enAttenteTresorier || m.status == UserStatus.enAttentePresident).length;
            return _buildMenuCard(
              context, 
              'Membres', 
              Icons.people, 
              const MemberManagementScreen(),
              stats: snapshot.hasData ? '$active Actifs • $pending Attente' : '...',
            );
          }
        ),
      if (userProvider.hasPermission('can_moderate_ideas'))
        StreamBuilder<List<IdeaModel>>(
          stream: dbService.getAllIdeas(),
          builder: (context, snapshot) {
            final ideas = snapshot.data ?? [];
            final pending = ideas.where((i) => i.status == IdeaStatus.enAttenteTraitement).length;
            final processed = ideas.where((i) => i.status != IdeaStatus.enAttenteTraitement).length;
            return _buildMenuCard(
              context, 
              'Suggestions', 
              Icons.lightbulb, 
              const IdeaModerationScreen(),
              stats: snapshot.hasData ? '$pending Nouvelles • $processed Traitées' : '...',
            );
          }
        ),
      if (userProvider.hasPermission('can_manage_posts'))
        StreamBuilder<List<PostModel>>(
          stream: dbService.getPosts(),
          builder: (context, snapshot) {
            final posts = snapshot.data ?? [];
            final active = posts.where((p) => p.isActive).length;
            final inactive = posts.where((p) => !p.isActive).length;
            return _buildMenuCard(
              context, 
              'Publications', 
              Icons.post_add, 
              const PostManagementScreen(),
              stats: snapshot.hasData ? '$active Actives • $inactive Désact.' : '...',
            );
          }
        ),
      if (userProvider.hasPermission('can_edit_settings'))
        _buildMenuCard(context, 'Identité Club', Icons.settings_suggest, const AssociationSettingsScreen()),
      if (userProvider.hasPermission('can_manage_alerts'))
        _buildMenuCard(context, 'Alertes', Icons.notification_important, const ManageAlertsScreen()),
    ];

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
      body: menuCards.isEmpty 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_person, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Aucune permission accordée',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                  child: Text(
                    'Le Président doit vous accorder des droits d\'accès spécifiques pour voir les outils d\'administration.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NavigationWrapper())),
                  child: const Text('Aller au Mode Membre'),
                ),
              ],
            ),
          )
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Tableau de Bord Secrétaire', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: MediaQuery.of(context).size.width > 900 ? 4 : 2.5,
                  children: menuCards,
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 32, 16, 8),
                  child: Text('Validations de Profil en Attente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                StreamBuilder<List<MemberModel>>(
                  stream: dbService.getMembers(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                    
                    final pending = snapshot.data!.where((m) => m.pendingModifications != null).toList();
                    
                    if (pending.isEmpty) return const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: Text('Aucune modification à valider.')),
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
                            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                            title: Text('${member.prenom} ${member.nom}'),
                            subtitle: const Text('Demande de modification de profil'),
                            trailing: const Icon(Icons.chevron_right, color: Colors.orange),
                            onTap: () => Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (context) => const MemberManagementScreen())
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

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, Widget screen, {String? stats}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 80),
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => screen)),
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
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text(title)), body: const Center(child: Text('En cours de développement')));
  }
}
