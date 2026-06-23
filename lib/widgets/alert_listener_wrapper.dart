import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/member_model.dart';
import '../models/alert_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class AlertListenerWrapper extends StatefulWidget {
  final Widget child;
  const AlertListenerWrapper({super.key, required this.child});

  @override
  State<AlertListenerWrapper> createState() => _AlertListenerWrapperState();
}

class _AlertListenerWrapperState extends State<AlertListenerWrapper> {
  StreamSubscription? _alertSubscription;
  bool _isShowingAlert = false;
  final Set<String> _notifiedAlertIds = {};
  String? _currentUserId;
  UserRole? _currentRole;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkUserAndSetupListener();
  }

  void _checkUserAndSetupListener() {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.userProfile;

    if (user == null) {
      _alertSubscription?.cancel();
      _alertSubscription = null;
      _currentUserId = null;
      _currentRole = null;
      return;
    }

    // Si l'utilisateur ou son rôle a changé, on réinitialise l'écouteur
    if (user.id != _currentUserId || user.role != _currentRole) {
      _alertSubscription?.cancel();
      _currentUserId = user.id;
      _currentRole = user.role;
      _setupAlertListener(user.id, user.role);
    }
  }

  @override
  void dispose() {
    _alertSubscription?.cancel();
    super.dispose();
  }

  void _setupAlertListener(String userId, UserRole role) {
    final userProfile = Provider.of<UserProvider>(context, listen: false).userProfile;
    final dateActivation = userProfile?.dateActivation;

    _alertSubscription = DatabaseService()
        .getPendingAlertsForUser(userId, role)
        .listen((alerts) {
      if (alerts.isNotEmpty) {
        // Notifier pour TOUTES les nouvelles alertes non vues
        for (final alert in alerts) {
          if (!_notifiedAlertIds.contains(alert.id)) {
            NotificationService().showAlertNotification(
              id: alert.id.hashCode,
              title: alert.title,
              body: alert.details,
            );
            _notifiedAlertIds.add(alert.id);
          }
        }

        // On cherche la première alerte éligible pour l'affichage pop-up
        // Elle doit avoir été créée APRÈS l'activation du compte du membre (si la date est connue)
        AlertModel? alertToShow;
        try {
          alertToShow = alerts.firstWhere((a) {
            if (dateActivation == null) return true;
            // On laisse une petite marge de 5 secondes pour les alertes de bienvenue
            return a.createdAt.isAfter(dateActivation.subtract(const Duration(seconds: 5)));
          });
        } catch (_) {
          // Aucune alerte ne remplit les critères de date pour le pop-up
          alertToShow = null;
        }

        // Afficher le dialogue pour la plus ancienne alerte non traitée si pas déjà en cours
        if (!_isShowingAlert && alertToShow != null) {
          _showAlertDialog(alertToShow);
        }
      }
    });
  }

  void _showAlertDialog(AlertModel alert) {
    if (!mounted) return;
    setState(() => _isShowingAlert = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.campaign, color: Colors.orange, size: 30),
            const SizedBox(width: 12),
            Expanded(child: Text(alert.title, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(alert.details, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 32),
            
            // Section Rappels
            const Text(
              'Me rappeler plus tard :', 
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                _buildReminderButton(context, alert.id, '15 min', const Duration(minutes: 15)),
                _buildReminderButton(context, alert.id, '30 min', const Duration(minutes: 30)),
                _buildReminderButton(context, alert.id, '1 h', const Duration(hours: 1)),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Section Actions de Validation (si applicable)
            if (alert.memberId != null) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle),
                label: const Text('VALIDER MAINTENANT', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  final userProvider = Provider.of<UserProvider>(context, listen: false);
                  final role = userProvider.userProfile?.role;
                  final userId = userProvider.userProfile?.id;
                  
                  if (role == null || userId == null) return;

                  final db = DatabaseService();
                  // Déterminer le nouveau statut selon le rôle
                  String? newStatus;
                  Map<String, dynamic> updateData = {};
                  
                  if (role == UserRole.tresorier) {
                    newStatus = 'enAttentePresident';
                    updateData = {'status': newStatus};
                  } else if (role == UserRole.president) {
                    newStatus = 'actif';
                    updateData = {
                      'status': newStatus,
                      'dateActivation': FieldValue.serverTimestamp(),
                    };
                  }

                  if (newStatus != null) {
                    await db.updateMember(alert.memberId!, updateData);
                    
                    // Si c'est le trésorier, on envoie l'alerte au président
                    if (role == UserRole.tresorier) {
                      final presidentIds = await db.getUserIdsByRole(UserRole.president);
                      await db.sendAutomaticAlert(
                        title: 'Validation membre (Niveau 2)',
                        details: 'Le trésorier a validé une inscription. En attente de votre validation finale.',
                        initiatorId: userId,
                        targetType: AlertTarget.manual,
                        targetUserIds: presidentIds,
                        memberId: alert.memberId,
                      );
                    } 
                    // Si c'est le président, on informe le membre
                    else if (role == UserRole.president) {
                      await db.sendAutomaticAlert(
                        title: 'Bienvenue !',
                        details: 'Votre inscription a été validée par le Président. Vous êtes maintenant membre actif.',
                        initiatorId: userId,
                        targetType: AlertTarget.manual,
                        targetUserIds: [alert.memberId!],
                      );
                    }
                  }

                  // Marquer l'alerte comme vue
                  await db.markAlertAsViewed(alert.id, userId);
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    setState(() => _isShowingAlert = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Validation effectuée avec succès !'), backgroundColor: Colors.green),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
            ],

            // Bouton de validation principal
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final userId = Provider.of<UserProvider>(context, listen: false).userProfile?.id;
                if (userId != null) {
                  await DatabaseService().markAlertAsViewed(alert.id, userId);
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  setState(() => _isShowingAlert = false);
                }
              },
              child: const Text(
                'J\'AI VU / COMPRIS',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),
          ],
        ),
        // On laisse actions vide car on a tout mis dans le content pour un meilleur contrôle du layout
        actions: const [],
      ),
    );
  }

  Widget _buildReminderButton(BuildContext context, String alertId, String label, Duration duration) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      onPressed: () async {
        final userId = Provider.of<UserProvider>(context, listen: false).userProfile?.id;
        if (userId != null) {
          await DatabaseService().setAlertReminder(alertId, userId, duration);
        }
        if (context.mounted) {
          Navigator.pop(context);
          setState(() => _isShowingAlert = false);
        }
      },
      child: Text(
        label, 
        style: TextStyle(fontSize: 12, color: Colors.grey.shade700)
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
