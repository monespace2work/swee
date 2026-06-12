import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/database_service.dart';
import '../../models/idea_model.dart';
import '../../models/member_model.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';

enum IdeaSortOption { chronological, status, alphabetical }

class IdeaBoxScreen extends StatefulWidget {
  const IdeaBoxScreen({super.key});

  @override
  State<IdeaBoxScreen> createState() => _IdeaBoxScreenState();
}

class _IdeaBoxScreenState extends State<IdeaBoxScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  
  IdeaSortOption _sortOption = IdeaSortOption.chronological;
  bool _isAscending = false; // Par défaut, plus récent en premier

  void _submitIdea() async {
    final user = Provider.of<UserProvider>(context, listen: false).userProfile;
    if (user == null) return;

    if (_titleController.text.isNotEmpty && _descriptionController.text.isNotEmpty) {
      final newIdea = IdeaModel(
        id: '',
        memberId: user.id,
        memberName: '${user.prenom} ${user.nom}',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        createdAt: DateTime.now(),
        status: IdeaStatus.enAttenteTraitement,
      );

      await _dbService.addIdea(newIdea);
      _titleController.clear();
      _descriptionController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Votre suggestion a été envoyée au Secrétaire.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.userProfile;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (userProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isSecretary = user?.role == UserRole.secretaire;

    return RefreshIndicator(
      onRefresh: () => userProvider.refreshProfile(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isSecretary) ...[
              Text(
                'Soumettre une idée', 
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.gold : AppTheme.darkBlue,
                )
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titre de la suggestion',
                  hintText: 'Ex: Amélioration du local...',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description détaillée',
                  hintText: 'Expliquez votre idée en quelques mots...',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _submitIdea, 
                icon: const Icon(Icons.send),
                label: const Text('Envoyer la suggestion'),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
            ],
            
            Row(
              children: [
                Icon(
                  isSecretary ? Icons.analytics : Icons.history,
                  color: isDark ? AppTheme.gold : AppTheme.darkBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isSecretary ? 'Point des suggestions (Tous)' : 'Mes suggestions', 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                ),
                PopupMenuButton<IdeaSortOption>(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Trier par',
                  onSelected: (option) => setState(() => _sortOption = option),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: IdeaSortOption.chronological, child: Text('Date')),
                    const PopupMenuItem(value: IdeaSortOption.status, child: Text('État')),
                    const PopupMenuItem(value: IdeaSortOption.alphabetical, child: Text('Titre')),
                  ],
                ),
                IconButton(
                  icon: Icon(_isAscending ? Icons.arrow_upward : Icons.arrow_downward),
                  onPressed: () => setState(() => _isAscending = !_isAscending),
                  tooltip: _isAscending ? 'Croissant' : 'Décroissant',
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            StreamBuilder<List<IdeaModel>>(
              stream: isSecretary 
                  ? _dbService.getAllIdeas() 
                  : _dbService.getMemberIdeas(user?.id ?? ''),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                  );
                }
                
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                
                List<IdeaModel> ideas = snapshot.data ?? [];
                
                // Application du tri personnalisé
                ideas.sort((a, b) {
                  int cmp;
                  switch (_sortOption) {
                    case IdeaSortOption.chronological:
                      cmp = a.createdAt.compareTo(b.createdAt);
                      break;
                    case IdeaSortOption.status:
                      cmp = a.status.index.compareTo(b.status.index);
                      break;
                    case IdeaSortOption.alphabetical:
                      cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
                      break;
                  }
                  return _isAscending ? cmp : -cmp;
                });
                
                if (ideas.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.lightbulb_outline, size: 48, color: Colors.grey.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          isSecretary 
                              ? 'Aucune suggestion à traiter.' 
                              : 'Vous n\'avez pas encore soumis de suggestions.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: ideas.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final idea = ideas[index];
                    return _buildIdeaCard(context, idea, isSecretary, isDark);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdeaCard(BuildContext context, IdeaModel idea, bool isSecretary, bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        idea.title, 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd/MM/yyyy à HH:mm').format(idea.createdAt),
                        style: TextStyle(
                          fontSize: 11, 
                          color: isDark ? Colors.grey[400] : Colors.grey[600]
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(idea.status),
              ],
            ),
            if (isSecretary)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Par: ${idea.memberName}', 
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isDark ? Colors.grey[400] : Colors.grey[600])
                ),
              ),
            const SizedBox(height: 12),
            Text(
              idea.description,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
            ),
            if (idea.response != null && idea.response!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.blueGrey.withOpacity(0.2) : Colors.blueGrey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueGrey.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.reply, size: 14, color: Colors.blueGrey),
                        const SizedBox(width: 4),
                        Text(
                          'Réponse du secrétariat :', 
                          style: TextStyle(
                            fontSize: 11, 
                            fontWeight: FontWeight.bold, 
                            color: isDark ? Colors.blueGrey[200] : Colors.blueGrey[700]
                          )
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      idea.response!, 
                      style: TextStyle(
                        fontSize: 13, 
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white : Colors.black87,
                      )
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(IdeaStatus status) {
    String label;
    Color color;
    IconData icon;

    switch (status) {
      case IdeaStatus.enAttenteTraitement:
        label = 'En attente';
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        break;
      case IdeaStatus.enAttentePublication:
        label = 'Validé';
        color = Colors.blue;
        icon = Icons.rule;
        break;
      case IdeaStatus.rejetee:
        label = 'Rejeté';
        color = Colors.red;
        icon = Icons.cancel_outlined;
        break;
      case IdeaStatus.publiee:
        label = 'Publié';
        color = Colors.green;
        icon = Icons.check_circle_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
