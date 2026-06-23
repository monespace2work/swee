import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/member_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/member_avatar.dart';

class MembersListScreen extends StatefulWidget {
  const MembersListScreen({super.key});

  @override
  State<MembersListScreen> createState() => _MembersListScreenState();
}

class _MembersListScreenState extends State<MembersListScreen> {
  final DatabaseService _dbService = DatabaseService();
  String _searchQuery = '';

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber.replaceAll(' ', ''),
    );
    try {
      await launchUrl(launchUri);
    } catch (e) {
      debugPrint('Error making phone call: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Annuaire des Membres'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un membre...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<MemberModel>>(
              stream: _dbService.getMembers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }

                var members = snapshot.data ?? [];
                
                // On ne montre que les membres actifs
                members = members.where((m) => m.status == UserStatus.actif).toList();

                // Filtrage par recherche
                if (_searchQuery.isNotEmpty) {
                  members = members.where((m) {
                    final fullName = '${m.prenom} ${m.nom}'.toLowerCase();
                    return fullName.contains(_searchQuery);
                  }).toList();
                }

                // Tri par nom
                members.sort((a, b) => a.nom.compareTo(b.nom));

                if (members.isEmpty) {
                  return const Center(
                    child: Text('Aucun membre trouvé'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: members.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      leading: MemberAvatar(member: member, radius: 25),
                      title: Text(
                        '${member.prenom} ${member.nom}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getRoleColor(member.role).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _getRoleColor(member.role).withOpacity(0.5)),
                            ),
                            child: Text(
                              _getRoleLabel(member.role),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _getRoleColor(member.role),
                              ),
                            ),
                          ),
                          if (member.telephone.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.phone, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  member.telephone,
                                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      trailing: member.telephone.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.phone_enabled, color: Colors.green),
                              onPressed: () => _makePhoneCall(member.telephone),
                            )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleLabel(UserRole role) {
    switch (role) {
      case UserRole.president: return 'PRÉSIDENT';
      case UserRole.secretaire: return 'SECRÉTAIRE';
      case UserRole.tresorier: return 'TRÉSORIER';
      case UserRole.conseiller: return 'CONSEILLER';
      case UserRole.membre: return 'MEMBRE';
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.president: return Colors.red;
      case UserRole.secretaire: return Colors.blue;
      case UserRole.tresorier: return Colors.amber;
      case UserRole.conseiller: return Colors.purple;
      case UserRole.membre: return Colors.green;
    }
  }
}
