import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/alert_model.dart';
import '../../../services/database_service.dart';
import '../../../providers/user_provider.dart';
import 'edit_alert_screen.dart';
import 'alert_stats_screen.dart';
import 'package:intl/intl.dart';

class ManageAlertsScreen extends StatefulWidget {
  const ManageAlertsScreen({super.key});

  @override
  State<ManageAlertsScreen> createState() => _ManageAlertsScreenState();
}

class _ManageAlertsScreenState extends State<ManageAlertsScreen> {
  final DatabaseService _dbService = DatabaseService();

  @override
  Widget build(BuildContext context) {
    final userProfile = Provider.of<UserProvider>(context).userProfile;
    if (userProfile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gérer les Alertes'),
      ),
      body: StreamBuilder<List<AlertModel>>(
        stream: _dbService.getAllAlerts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text('Erreur lors du chargement des alertes : ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucune alerte trouvée.'));
          }

          final alerts = snapshot.data!;
          // Sort by createdAt descending (already done by service, but safety first)
          // alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return ListView.builder(
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(alert.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert.details, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                        'Cible: ${_getTargetText(alert.targetType)} • Début: ${DateFormat('dd/MM/yy').format(alert.startDate)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Vues: ${alert.viewedBy.length}',
                        style: const TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.bar_chart, color: Colors.blue, size: 22),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Statistiques',
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => AlertStatsScreen(alert: alert)),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              alert.isActive ? Icons.visibility : Icons.visibility_off, 
                              color: alert.isActive ? Colors.green : Colors.grey,
                              size: 22,
                            ),
                            visualDensity: VisualDensity.compact,
                            tooltip: alert.isActive ? 'Désactiver' : 'Activer',
                            onPressed: () => _toggleActive(alert),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.orange, size: 22),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Modifier',
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => EditAlertScreen(alert: alert)),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 22),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Supprimer',
                            onPressed: () => _confirmDelete(alert),
                          ),
                        ],
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EditAlertScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _getTargetText(AlertTarget target) {
    switch (target) {
      case AlertTarget.all: return 'Tous';
      case AlertTarget.bureau: return 'Bureau';
      case AlertTarget.ordinary: return 'Membres ordinaires';
      case AlertTarget.manual: return 'Sélection manuelle';
    }
  }

  void _toggleActive(AlertModel alert) async {
    await _dbService.updateAlert(alert.id, {'isActive': !alert.isActive});
  }

  void _confirmDelete(AlertModel alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'alerte ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              try {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                Navigator.pop(context); // Ferme le dialogue
                
                await _dbService.deleteAlert(alert.id);
                
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Alerte supprimée avec succès'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur lors de la suppression : $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }, 
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
