import 'package:flutter/material.dart';
import '../../../models/idea_model.dart';
import '../../../services/database_service.dart';
import 'create_post_screen.dart';

class IdeaModerationScreen extends StatelessWidget {
  const IdeaModerationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dbService = DatabaseService();

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
          
          final ideas = snapshot.data!;

          return ListView.builder(
            itemCount: ideas.length,
            itemBuilder: (context, index) {
              final idea = ideas[index];
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
                    ],
                  ),
                  trailing: _buildActions(context, idea, dbService),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget? _buildActions(BuildContext context, IdeaModel idea, DatabaseService dbService) {
    switch (idea.status) {
      case IdeaStatus.enAttenteTraitement:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              tooltip: 'Valider pour publication',
              onPressed: () => _updateIdeaStatus(context, idea.id, IdeaStatus.enAttentePublication, dbService),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              tooltip: 'Rejeter (non conforme)',
              onPressed: () => _updateIdeaStatus(context, idea.id, IdeaStatus.rejetee, dbService),
            ),
          ],
        );
      case IdeaStatus.enAttentePublication:
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

  void _updateIdeaStatus(BuildContext context, String id, IdeaStatus status, DatabaseService dbService) {
    if (status == IdeaStatus.rejetee || status == IdeaStatus.enAttentePublication) {
      _showResponseDialog(context, id, status, dbService);
    } else {
      dbService.updateIdea(id, {'status': status.name});
    }
  }

  void _showResponseDialog(BuildContext context, String id, IdeaStatus status, DatabaseService dbService) {
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
