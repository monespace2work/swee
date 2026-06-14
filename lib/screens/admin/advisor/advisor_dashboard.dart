import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swee/providers/user_provider.dart';
import 'package:swee/screens/home/navigation_wrapper.dart';
import 'package:swee/screens/admin/secretary/idea_moderation_screen.dart';
import 'package:swee/screens/admin/secretary/post_management_screen.dart';
import 'package:swee/screens/admin/alerts/manage_alerts_screen.dart';
import 'package:swee/services/database_service.dart';
import 'package:swee/models/post_model.dart';
import 'package:swee/models/idea_model.dart';
import 'package:swee/widgets/app_header_title.dart';
import 'package:swee/widgets/user_menu_button.dart';

class AdvisorDashboard extends StatelessWidget {
  const AdvisorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final dbService = DatabaseService();
    final userProvider = Provider.of<UserProvider>(context);

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
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: MediaQuery.of(context).size.width > 900 ? 4 : 2.5,
        children: [
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
          if (userProvider.hasPermission('can_manage_alerts'))
            _buildMenuCard(context, 'Alertes', Icons.notification_important, const ManageAlertsScreen()),
        ],
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
