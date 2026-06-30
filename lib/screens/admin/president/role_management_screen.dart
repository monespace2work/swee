import 'package:flutter/material.dart';
import '../../../models/member_model.dart';
import '../../../services/database_service.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/user_menu_button.dart';

class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  final DatabaseService _dbService = DatabaseService();
  String _searchQuery = '';
  
  // State for local permission modifications before saving
  final Map<String, Map<String, bool>> _localPermissions = {};
  bool _hasChanges = false;
  bool _isSaving = false;

  final List<Map<String, String>> _availablePermissions = [
    {'id': 'can_manage_members', 'label': 'Gérer les membres'},
    {'id': 'can_manage_posts', 'label': 'Gérer les publications'},
    {'id': 'can_moderate_ideas', 'label': 'Modérer les suggestions'},
    {'id': 'can_manage_payments', 'label': 'Gérer les paiements'},
    {'id': 'can_manage_alerts', 'label': 'Gérer les alertes'},
    {'id': 'can_edit_settings', 'label': 'Modifier l\'identité du club'},
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestion des Rôles'),
          actions: const [UserMenuButton()],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'Membres'),
              Tab(icon: Icon(Icons.security), text: 'Permissions'),
            ],
            labelColor: AppTheme.gold,
            unselectedLabelColor: Colors.white70,
            indicatorColor: AppTheme.gold,
          ),
        ),
        body: TabBarView(
          children: [
            _buildRoleAssignmentTab(),
            _buildPermissionsTab(),
          ],
        ),
        floatingActionButton: _hasChanges ? FloatingActionButton.extended(
          onPressed: _isSaving ? null : _saveAllPermissions,
          label: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Confirmer les modifications'),
          icon: const Icon(Icons.save),
          backgroundColor: Colors.green,
        ) : null,
      ),
    );
  }

  Widget _buildRoleAssignmentTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher un membre...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<MemberModel>>(
            stream: _dbService.getMembers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Aucun membre trouvé'));
              }

              final members = snapshot.data!.where((m) {
                final fullName = '${m.prenom} ${m.nom}'.toLowerCase();
                return fullName.contains(_searchQuery.toLowerCase()) || 
                       m.email.toLowerCase().contains(_searchQuery.toLowerCase());
              }).toList();

              return ListView.builder(
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.darkBlue,
                        child: Text(
                          member.prenom[0].toUpperCase(),
                          style: const TextStyle(color: AppTheme.gold),
                        ),
                      ),
                      title: Text('${member.prenom} ${member.nom}'),
                      subtitle: Text('Rôle actuel: ${member.role.name}'),
                      trailing: member.role == UserRole.president 
                        ? const Icon(Icons.shield, color: AppTheme.gold)
                        : _buildRoleSelector(member),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelector(MemberModel member) {
    return DropdownButton<UserRole>(
      value: member.role,
      onChanged: (UserRole? newRole) {
        if (newRole != null && newRole != member.role) {
          _confirmRoleChange(member, newRole);
        }
      },
      items: UserRole.values.map((UserRole role) {
        return DropdownMenuItem<UserRole>(
          value: role,
          child: Text(role.name),
        );
      }).toList(),
    );
  }

  void _confirmRoleChange(MemberModel member, UserRole newRole) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer le changement'),
        content: Text('Voulez-vous vraiment accorder le rôle de "${newRole.name}" à ${member.prenom} ${member.nom} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              await _dbService.updateMember(member.id, {'role': newRole.name});
              navigator.pop();
              scaffoldMessenger.showSnackBar(
                SnackBar(content: Text('Rôle mis à jour pour ${member.prenom}')),
              );
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsTab() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _dbService.getAllRolePermissions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _localPermissions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasData && !_hasChanges) {
          // Initialize local state from DB if no changes are pending
          snapshot.data!.forEach((role, perms) {
            _localPermissions[role] = Map<String, bool>.from(perms as Map);
          });
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: Text(
                'Définition des droits d\'accès par rôle',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...UserRole.values.where((r) => r != UserRole.president).map((role) {
              final roleKey = role.name;
              final roleData = _localPermissions[roleKey] ?? {};
              
              return _buildRolePermissionCard(role, roleData);
            }),
            const Card(
              color: AppTheme.darkBlue,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.gold),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Note: Le Président possède tous les droits d\'administration par défaut et ne peut être restreint.',
                        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 80), // Space for FAB
          ],
        );
      },
    );
  }

  Widget _buildRolePermissionCard(UserRole role, Map<String, bool> currentPermissions) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(role.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkBlue)),
        subtitle: Text('${currentPermissions.values.where((v) => v == true).length} permissions accordées'),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: _availablePermissions.map((permission) {
                final bool isEnabled = currentPermissions[permission['id']] == true;
                return CheckboxListTile(
                  title: Text(permission['label']!),
                  value: isEnabled,
                  activeColor: AppTheme.gold,
                  onChanged: (bool? value) {
                    setState(() {
                      _localPermissions[role.name] ??= {};
                      _localPermissions[role.name]![permission['id']!] = value ?? false;
                      _hasChanges = true;
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAllPermissions() async {
    final passwordController = TextEditingController();
    final authService = AuthService();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer l\'enregistrement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Veuillez confirmer votre mot de passe pour appliquer ces modifications de permissions.'),
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              final success = await authService.reauthenticate(passwordController.text);
              
              if (success) {
                navigator.pop(true);
              } else {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Mot de passe incorrect'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      for (var entry in _localPermissions.entries) {
        await _dbService.updateRolePermissions(entry.key, entry.value);
      }
      setState(() {
        _hasChanges = false;
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Toutes les permissions ont été enregistrées avec succès !'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'enregistrement : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
