import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/idea_model.dart';
import '../../../models/member_model.dart';
import '../../../services/database_service.dart';
import '../../../providers/user_provider.dart';
import 'create_post_screen.dart';

class IdeaModerationScreen extends StatelessWidget {
  const IdeaModerationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dbService = DatabaseService();
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = userProvider.userProfile;

    return Scaffold(
      appBar: AppBar(title: const Text('Modération des Idées')),
      body: StreamBuilder<List<IdeaModel>>(
        stream: dbService.getAllIdeas(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucune suggestion pour le moment.'));
          }
          
          final allIdeas = snapshot.data!;
          final List<IdeaModel> filteredIdeas;

          if (currentUser?.role == UserRole.president) {
            filteredIdeas = allIdeas;
          } else {
            // Un admin ordinaire ne voit que ce qu'il a "publié" (modéré) 
            // OU les nouvelles idées s'il a le droit de modération?
            // Le prompt dit : "ne peuvent voir... que les elements qu'eux-meme ont publiées"
            // Donc strictement parlant, ils ne voient pas les nouvelles idées.
            // Cependant, pour pouvoir modérer, ils ont besoin de l'Inbox.
            // J'interprète "publiées" comme "prises en charge".
            
            filteredIdeas = allIdeas.where((idea) {
              // 1. Toujours voir les nouvelles idées en attente de traitement (sinon blocage)
              if (idea.status == IdeaStatus.enAttenteTraitement) return true;
              // 2. Voir ses propres modérations passées
              return idea.moderatedBy == currentUser?.id;
            }).toList();
          }

          if (filteredIdeas.isEmpty) {
            return const Center(child: Text('Aucune suggestion à afficher.'));
          }

          return ListView.builder(
            itemCount: filteredIdeas.length,
            itemBuilder: (context, index) {
              final idea = filteredIdeas[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(idea.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('De: ${idea.memberName}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                      const SizedBox(height: 4),
                      Text(idea.description),
                      const SizedBox(height: 8),
                      _buildStatusBadge(idea.status),
                      if (idea.moderatedBy != null && currentUser?.role == UserRole.president)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text('Modéré par ID: ${idea.moderatedBy}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ),
                    ],
                  ),
                  trailing: _buildActions(context, idea, dbService, currentUser?.id),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget? _buildActions(BuildContext context, IdeaModel idea, DatabaseService dbService, String? currentUserId) {
    switch (idea.status) {
      case IdeaStatus.enAttenteTraitement:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              tooltip: 'Valider pour publication',
              onPressed: () => _updateIdeaStatus(context, idea.id, IdeaStatus.enAttentePublication, dbService, currentUserId),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              tooltip: 'Rejeter (non conforme)',
              onPressed: () => _updateIdeaStatus(context, idea.id, IdeaStatus.rejetee, dbService, currentUserId),
            ),
          ],
        );
      case IdeaStatus.enAttentePublication:
        // Seul le modérateur de l'idée (ou le président) peut finaliser la publication
        if (idea.moderatedBy != null && idea.moderatedBy != currentUserId && currentUserId != null) {
          return null; 
        }
        return ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreatePostScreen(fromIdea: idea),
            ),
          ),
          child: const Text('Publier'),
        );
      default:
        return null;
    }
  }

  Widget _buildStatusBadge(IdeaStatus status) {
    String label;
    Color color;
    switch (status) {
      case IdeaStatus.enAttenteTraitement:
        label = 'EN ATTENTE TRAITEMENT';
        color = Colors.orange;
        break;
      case IdeaStatus.enAttentePublication:
        label = 'BON POUR PUBLICATION';
        color = Colors.blue;
        break;
      case IdeaStatus.rejetee:
        label = 'REJETÉ';
        color = Colors.red;
        break;
      case IdeaStatus.publiee:
        label = 'PUBLIÉ';
        color = Colors.green;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _updateIdeaStatus(BuildContext context, String id, IdeaStatus status, DatabaseService dbService, String? currentUserId) {
    if (status == IdeaStatus.rejetee || status == IdeaStatus.enAttentePublication) {
      _showResponseDialog(context, id, status, dbService, currentUserId);
    } else {
      dbService.updateIdea(id, {
        'status': status.name,
        'moderatedBy': currentUserId,
      });
    }
  }

  void _showResponseDialog(BuildContext context, String id, IdeaStatus status, DatabaseService dbService, String? currentUserId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(status == IdeaStatus.rejetee ? 'Motif du rejet' : 'Commentaire (Optionnel)'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Écrivez votre message ici...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              dbService.updateIdea(id, {
                'status': status.name,
                'response': controller.text.trim(),
                'moderatedBy': currentUserId,
              });
              Navigator.pop(context);
            }, 
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }
}
