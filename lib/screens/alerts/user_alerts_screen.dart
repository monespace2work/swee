import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/alert_model.dart';
import '../../models/member_model.dart';
import '../../providers/user_provider.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';

class UserAlertsScreen extends StatelessWidget {
  const UserAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.userProfile;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Alertes'),
      ),
      body: StreamBuilder<List<AlertModel>>(
        stream: DatabaseService().getRelevantAlertsForUser(user.id, user.role),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Aucune alerte pour le moment', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final alerts = snapshot.data!;
          // Sort alerts: unread first, then by date
          alerts.sort((a, b) {
            bool aViewed = a.viewedBy.containsKey(user.id);
            bool bViewed = b.viewedBy.containsKey(user.id);
            if (aViewed != bViewed) return aViewed ? 1 : -1;
            return b.createdAt.compareTo(a.createdAt);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              final bool isViewed = alert.viewedBy.containsKey(user.id);

              return Dismissible(
                key: Key(alert.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20.0),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  _hideAlert(context, alert.id, user.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Alerte supprimée de votre vue')),
                  );
                },
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: isViewed ? 0 : 2,
                  color: isViewed 
                      ? (isDark ? Colors.white10 : Colors.grey[100])
                      : (isDark ? AppTheme.darkBlue : Colors.white),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isViewed ? BorderSide.none : BorderSide(color: Colors.orange.withOpacity(0.5)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: isViewed ? Colors.grey : Colors.orange,
                      child: const Icon(Icons.campaign, color: Colors.white),
                    ),
                    title: Text(
                      alert.title,
                      style: TextStyle(
                        fontWeight: isViewed ? FontWeight.normal : FontWeight.bold,
                        color: isViewed ? Colors.grey : (isDark ? Colors.white : AppTheme.darkBlue),
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(alert.details),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(alert.createdAt),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isViewed)
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                            tooltip: 'Marquer comme lu',
                            onPressed: () => DatabaseService().markAlertAsViewed(alert.id, user.id),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Supprimer',
                          onPressed: () => _confirmDismiss(context, alert.id, user.id),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDismiss(BuildContext context, String alertId, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'alerte ?'),
        content: const Text('Cette alerte sera retirée de votre liste.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              _hideAlert(context, alertId, userId);
              Navigator.pop(context);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _hideAlert(BuildContext context, String alertId, String userId) async {
    // We'll update the database to mark it as dismissed/hidden for this user.
    // For now, let's add a 'dismissedBy' field in DatabaseService or use markAlertAsViewed
    // But markAlertAsViewed is already used for "read".
    // Let's add 'dismissedBy' to AlertModel first.
    await DatabaseService().dismissAlertForUser(alertId, userId);
  }
}
