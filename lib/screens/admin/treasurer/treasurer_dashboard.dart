import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swee/providers/user_provider.dart';
import '../../home/navigation_wrapper.dart';
import '../../../services/database_service.dart';
import '../../../models/member_model.dart';
import '../../../models/alert_model.dart';
import 'record_payment_screen.dart';
import 'payment_management_screen.dart';
import '../alerts/manage_alerts_screen.dart';
import '../../../widgets/app_header_title.dart';
import '../../../widgets/user_menu_button.dart';
import '../../../theme/app_theme.dart';

class TreasurerDashboard extends StatefulWidget {
  const TreasurerDashboard({super.key});

  @override
  State<TreasurerDashboard> createState() => _TreasurerDashboardState();
}

class _TreasurerDashboardState extends State<TreasurerDashboard> {
  late Stream<List<MemberModel>> _membersStream;
  final DatabaseService _dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _membersStream = _dbService.getMembers();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isWeb = MediaQuery.of(context).size.width > 900;

    final List<Widget> actionButtons = [
      if (userProvider.hasPermission('can_manage_payments'))
        _build3DButton(
          context,
          title: 'Enregistrer un paiement',
          subtitle: 'Cotisations et dons',
          icon: Icons.add_card,
          color: AppTheme.darkBlue,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RecordPaymentScreen())),
        ),
      if (userProvider.hasPermission('can_manage_payments'))
        _build3DButton(
          context,
          title: 'Situation des paiements',
          subtitle: 'Historique et rapports',
          icon: Icons.history,
          color: AppTheme.darkBlue,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentManagementScreen())),
        ),
      if (userProvider.hasPermission('can_manage_alerts'))
        _build3DButton(
          context,
          title: 'Gérer les Alertes',
          subtitle: 'Rappels de paiement',
          icon: Icons.notification_important,
          color: AppTheme.darkBlue,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageAlertsScreen())),
        ),
    ];

    final bool showValidations = userProvider.hasPermission('can_manage_members');

    if (actionButtons.isEmpty && !showValidations) {
      return Scaffold(
        appBar: AppBar(title: const AppHeaderTitle(showRole: true)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Accès restreint', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('Le Président doit vous accorder des permissions pour accéder aux outils du Trésorier.', textAlign: TextAlign.center),
              ),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NavigationWrapper())),
                child: const Text('Aller au Mode Membre'),
              ),
            ],
          ),
        ),
      );
    }

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            // Menu Principal
            if (actionButtons.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: isWeb ? 3 : 1,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: isWeb ? 3.5 : 4.5,
                  children: actionButtons,
                ),
              ),

            if (showValidations) ...[
              const SizedBox(height: 40),
              const Divider(),
              
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.pending_actions, color: AppTheme.gold),
                    SizedBox(width: 8),
                    Text('Validations en attente (Niveau 2)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              
              StreamBuilder<List<MemberModel>>(
                stream: _membersStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  final pending = (snapshot.data ?? []).where((m) => m.status == UserStatus.enAttenteTresorier).toList();
                  
                  if (pending.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline, size: 48, color: Colors.green.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          const Text('Tout est à jour ! Aucune validation requise.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: pending.length,
                    itemBuilder: (context, index) {
                      final member = pending[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.gold.withValues(alpha: 0.1),
                            child: Text(member.nom[0], style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold)),
                          ),
                          title: Text('${member.prenom} ${member.nom}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(member.email, style: const TextStyle(fontSize: 12)),
                              Text('Statut: ${member.status.name}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: _build3DValidationButton(
                            onPressed: () => _validateMember(member.id),
                            label: 'Valider',
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _build3DButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDark ? AppTheme.deepNavy : Colors.white,
          boxShadow: [
            // Ombre portée pour l'effet 3D
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.3),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
            // Ombre douce
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              offset: const Offset(0, 10),
              blurRadius: 10,
            ),
          ],
          border: Border.all(
            color: isDark ? AppTheme.gold.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Petit accent de couleur sur le côté
              Positioned(
                left: 0, top: 0, bottom: 0,
                width: 6,
                child: Container(color: AppTheme.gold),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: AppTheme.gold, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppTheme.gold, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _build3DValidationButton({required VoidCallback onPressed, required String label}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.gold,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFA68928), // Version plus sombre du gold
              offset: Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppTheme.darkBlue,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _validateMember(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la validation'),
        content: const Text('Voulez-vous valider cette inscription (Niveau 2) et transmettre le dossier au Président ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULER'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold, foregroundColor: AppTheme.darkBlue),
            child: const Text('CONFIRMER'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _dbService.updateMember(id, {'status': 'enAttentePresident'});
    
    // AA to President
    final presidentIds = await _dbService.getUserIdsByRole(UserRole.president);
    await _dbService.sendAutomaticAlert(
      title: 'Validation membre (Niveau 2)',
      details: 'Le trésorier a validé une inscription. En attente de votre validation finale.',
      initiatorId: _dbService.currentUser?.uid ?? 'system',
      targetType: AlertTarget.manual,
      targetUserIds: presidentIds,
      memberId: id,
    );
  }
}
