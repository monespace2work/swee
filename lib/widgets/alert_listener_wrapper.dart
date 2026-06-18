import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupAlertListener();
    });
  }

  @override
  void dispose() {
    _alertSubscription?.cancel();
    super.dispose();
  }

  void _setupAlertListener() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.userProfile;
    if (user == null) return;

    _alertSubscription = DatabaseService()
        .getPendingAlertsForUser(user.id, user.role)
        .listen((alerts) {
      if (alerts.isNotEmpty) {
        final alert = alerts.first;
        
        // Afficher la notification si pas encore fait pour cette alerte
        if (!_notifiedAlertIds.contains(alert.id)) {
          NotificationService().showAlertNotification(
            id: alert.id.hashCode,
            title: alert.title,
            body: alert.details,
          );
          _notifiedAlertIds.add(alert.id);
        }

        // Afficher le dialogue si pas déjà en cours
        if (!_isShowingAlert) {
          _showAlertDialog(alert);
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
