import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../models/post_model.dart';
import '../../../services/database_service.dart';
import '../../../services/storage_service.dart';
import 'create_post_screen.dart';

class PostManagementScreen extends StatefulWidget {
  const PostManagementScreen({super.key});

  @override
  State<PostManagementScreen> createState() => _PostManagementScreenState();
}

class _PostManagementScreenState extends State<PostManagementScreen> {
  final DatabaseService _dbService = DatabaseService();
  final StorageService _storageService = StorageService();
  String _searchQuery = '';
  bool _sortAscending = false; // Par défaut décroissant (plus récent en haut)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Publications'),
        actions: [
          IconButton(
            icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () => setState(() => _sortAscending = !_sortAscending),
            tooltip: 'Trier par date',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Rechercher une publication...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<PostModel>>(
              stream: _dbService.getPosts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }
                
                var posts = snapshot.data ?? [];

                // Filtrage
                if (_searchQuery.isNotEmpty) {
                  posts = posts.where((p) => 
                    p.title.toLowerCase().contains(_searchQuery) || 
                    p.content.toLowerCase().contains(_searchQuery)
                  ).toList();
                }

                // Tri (getPosts est déjà trié DESC par Firestore, mais on gère le switch localement)
                posts.sort((a, b) => _sortAscending 
                    ? a.createdAt.compareTo(b.createdAt) 
                    : b.createdAt.compareTo(a.createdAt));

                if (posts.isEmpty) {
                  return const Center(child: Text('Aucune publication trouvée.'));
                }

                return ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      color: post.isActive ? null : Colors.grey[200],
                      child: ListTile(
                        leading: _buildLeading(post),
                        title: Text(
                          post.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: post.isActive ? null : TextDecoration.lineThrough,
                            color: post.isActive ? null : Colors.grey,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.content,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(post.createdAt),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) => _handleAction(value, post),
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                            PopupMenuItem(
                              value: 'toggle_active', 
                              child: Text(post.isActive ? 'Désactiver' : 'Activer'),
                            ),
                            const PopupMenuItem(
                              value: 'delete', 
                              child: Text('Supprimer', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => const CreatePostScreen())
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _handleAction(String action, PostModel post) {
    switch (action) {
      case 'edit':
        _showEditDialog(post);
        break;
      case 'toggle_active':
        _dbService.updatePost(post.id, {'isActive': !post.isActive});
        break;
      case 'delete':
        _confirmDelete(post);
        break;
    }
  }

  void _showEditDialog(PostModel post) {
    final titleController = TextEditingController(text: post.title);
    final contentController = TextEditingController(text: post.content);
    XFile? newImage;
    String? currentImageUrl = post.imageUrl;
    PostType selectedType = post.type;
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifier la publication'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<PostType>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type de publication'),
                  items: PostType.values.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.toString().split('.').last.toUpperCase()),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedType = val);
                  },
                ),
                const SizedBox(height: 16),
                if (currentImageUrl != null && newImage == null)
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Image.network(currentImageUrl!, height: 100, fit: BoxFit.cover),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => setDialogState(() => currentImageUrl = null),
                      ),
                    ],
                  ),
                if (newImage != null)
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      kIsWeb 
                        ? Image.network(newImage!.path, height: 100, fit: BoxFit.cover)
                        : Image.file(File(newImage!.path), height: 100, fit: BoxFit.cover),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => setDialogState(() => newImage = null),
                      ),
                    ],
                  ),
                TextButton.icon(
                  onPressed: () async {
                    try {
                      final picker = ImagePicker();
                      final img = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1920,
                        maxHeight: 1080,
                        imageQuality: 85,
                      );
                      if (img != null) {
                        setDialogState(() => newImage = img);
                      }
                    } catch (e) {
                      debugPrint("Error picking image: $e");
                    }
                  },
                  icon: const Icon(Icons.image),
                  label: Text(post.imageUrl == null ? 'Ajouter une image' : 'Changer l\'image'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Titre', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Contenu', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            isUpdating 
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: () async {
                    setDialogState(() => isUpdating = true);
                    
                    String? finalImageUrl = currentImageUrl;
                    if (newImage != null) {
                      finalImageUrl = await _storageService.uploadPostImage(newImage!);
                      if (finalImageUrl == null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Erreur lors de l\'envoi de l\'image.')),
                        );
                        setDialogState(() => isUpdating = false);
                        return;
                      }
                    }

                    await _dbService.updatePost(post.id, {
                      'title': titleController.text.trim(),
                      'content': contentController.text.trim(),
                      'imageUrl': finalImageUrl,
                      'type': selectedType.toString().split('.').last,
                    });
                    
                    if (context.mounted) Navigator.pop(context);
                  }, 
                  child: const Text('Enregistrer'),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeading(PostModel post) {
    IconData icon;
    Color color;
    switch (post.type) {
      case PostType.officiel:
        icon = Icons.verified;
        color = Colors.blue;
        break;
      case PostType.promotion:
        icon = Icons.star;
        color = Colors.orange;
        break;
      case PostType.ordinaire:
      default:
        icon = Icons.chat;
        color = Colors.grey;
    }

    return Stack(
      children: [
        if (post.imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: post.imageUrl!.startsWith('assets/')
                ? Image.asset(post.imageUrl!, width: 50, height: 50, fit: BoxFit.cover)
                : Image.network(post.imageUrl!, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image)),
          )
        else
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
            child: Icon(icon, color: color),
          ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Icon(icon, size: 14, color: color),
        ),
      ],
    );
  }

  void _confirmDelete(PostModel post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              _dbService.deletePost(post.id);
              Navigator.pop(context);
            }, 
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
