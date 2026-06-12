import 'package:flutter/material.dart';
import '../../../models/alert_model.dart';
import '../../../models/member_model.dart';
import '../../../services/database_service.dart';
import 'package:intl/intl.dart';

class AlertStatsScreen extends StatelessWidget {
  final AlertModel alert;
  const AlertStatsScreen({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final dbService = DatabaseService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques de l\'alerte'),
      ),
      body: StreamBuilder<List<MemberModel>>(
        stream: dbService.getMembers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final allMembers = snapshot.data!;
          final viewedIds = alert.viewedBy.keys.toList();
          final reminderIds = alert.remindMeLater.keys.toList();

          final viewedMembers = allMembers.where((m) => viewedIds.contains(m.id)).toList();
          final reminderMembers = allMembers.where((m) => reminderIds.contains(m.id)).toList();

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(text: 'Vues (${viewedMembers.length})'),
                    Tab(text: 'En attente (${reminderMembers.length})'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildMemberList(viewedMembers, alert.viewedBy, 'Vu le'),
                      _buildMemberList(reminderMembers, alert.remindMeLater, 'Rappel prévu'),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMemberList(List<MemberModel> members, Map<String, DateTime> dates, String label) {
    if (members.isEmpty) {
      return const Center(child: Text('Aucun membre dans cette catégorie.'));
    }

    return ListView.builder(
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        final date = dates[member.id];
        return ListTile(
          leading: CircleAvatar(
            child: Text(member.prenom[0] + member.nom[0]),
          ),
          title: Text('${member.prenom} ${member.nom}'),
          subtitle: date != null 
            ? Text('$label : ${DateFormat('dd/MM/yy HH:mm').format(date)}')
            : null,
        );
      },
    );
  }
}
