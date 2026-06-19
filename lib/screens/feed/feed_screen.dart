import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_service.dart';
import '../../models/post_model.dart';
import '../../providers/user_provider.dart';
import 'package:intl/intl.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dbService = DatabaseService();

    return StreamBuilder<List<PostModel>>(
      stream: dbService.getPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Aucune publication pour le moment.'));
        }

        final posts = snapshot.data!.where((p) => p.isActive).toList();
        
        if (posts.isEmpty) {
          return const Center(child: Text('Aucune publication active pour le moment.'));
        }

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            return PostCard(post: posts[index]);
          },
        );
      },
    );
  }
}

class PostCard extends StatelessWidget {
  final PostModel post;
  const PostCard({super.key, required this.post});

  void _showZoomedImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Hero(
                tag: imageUrl,
                child: imageUrl.startsWith('assets/')
                    ? Image.asset(imageUrl, fit: BoxFit.contain)
                    : Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Design parameters based on type
    BoxDecoration decoration;
    Widget? headerBadge;
    
    switch (post.type) {
      case PostType.officiel:
        decoration = BoxDecoration(
          color: isDark ? const Color(0xFF002B5B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(isDark ? 0.4 : 0.2),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: Colors.blue.withAlpha(200),
            width: 2.5,
          ),
        );
        headerBadge = _buildBadge(Icons.verified, 'OFFICIEL', Colors.blue);
        break;
        
      case PostType.promotion:
        decoration = BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
              ? [const Color(0xFF1A1A00), const Color(0xFF332200)] 
              : [const Color(0xFFFFF9E6), Colors.white],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(isDark ? 0.5 : 0.3),
              blurRadius: 25,
              spreadRadius: 1,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: Colors.orange.withAlpha(220),
            width: 3,
          ),
        );
        headerBadge = _buildBadge(Icons.star, 'PROMOTION', Colors.orange);
        break;
        
      case PostType.ordinaire:
      default:
        decoration = BoxDecoration(
          color: isDark ? const Color(0xFF001F3F) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        );
        headerBadge = null;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (headerBadge != null) headerBadge,
          
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
            GestureDetector(
              onTap: () => _showZoomedImage(context, post.imageUrl!),
              child: Hero(
                tag: post.imageUrl!,
                child: Builder(builder: (context) {
                  final isAsset = post.imageUrl!.startsWith('assets/');
                  if (isAsset) {
                    return Image.asset(
                      post.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                    );
                  }
                  return Image.network(
                    post.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: double.infinity,
                        height: 200,
                        color: isDark ? Colors.white10 : Colors.grey[100],
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                  );
                }),
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  style: TextStyle(
                    fontSize: 22, 
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd MMMM yyyy à HH:mm').format(post.createdAt),
                      style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final lines = post.content.split('\n');
                    // Détecter si c'est une publication issue d'une suggestion
                    if (lines.isNotEmpty && lines[0].startsWith('Suggestion de :')) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lines[0],
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.blueGrey[200] : Colors.blueGrey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            lines.skip(1).join('\n').trim(),
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              color: isDark ? Colors.grey[200] : Colors.black87,
                            ),
                          ),
                        ],
                      );
                    }
                    return Text(
                      post.content,
                      style: TextStyle(
                        fontSize: 16, 
                        height: 1.5,
                        color: isDark ? Colors.grey[200] : Colors.black87,
                      ),
                    );
                  },
                ),
                
                if (post.type != PostType.promotion) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(
                        post.type == PostType.officiel ? 'VOTES' : 'RÉACTIONS',
                        style: TextStyle(
                          fontSize: 12, 
                          fontWeight: FontWeight.w900, 
                          letterSpacing: 1.2,
                          color: post.type == PostType.officiel ? Colors.blue : Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Divider(color: Colors.blue.withOpacity(0.3))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  if (post.type == PostType.officiel)
                    VoteSection(post: post)
                  else
                    CommentListSection(postId: post.id),
                    
                  if (post.type == PostType.ordinaire) ...[
                    const SizedBox(height: 20),
                    CommentInputField(postId: post.id),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      width: double.infinity,
      color: color,
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class VoteSection extends StatelessWidget {
  final PostModel post;
  const VoteSection({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final userProfile = Provider.of<UserProvider>(context).userProfile;
    if (userProfile == null) return const SizedBox.shrink();

    final myVote = post.votes[userProfile.id];
    final dbService = DatabaseService();

    // Stats
    int likes = post.votes.values.where((v) => v == 'like').length;
    int dislikes = post.votes.values.where((v) => v == 'dislike').length;
    int neutrals = post.votes.values.where((v) => v == 'neutral').length;
    int total = post.votes.length;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _voteButton(
              context, 
              'J\'aime', 
              Icons.thumb_up_alt_rounded, 
              Colors.green, 
              myVote == 'like',
              () => dbService.votePost(post.id, userProfile.id, 'like')
            ),
            _voteButton(
              context, 
              'Neutre', 
              Icons.remove_circle_outline_rounded, 
              Colors.grey, 
              myVote == 'neutral',
              () => dbService.votePost(post.id, userProfile.id, 'neutral')
            ),
            _voteButton(
              context, 
              'Je n\'aime pas', 
              Icons.thumb_down_alt_rounded, 
              Colors.red, 
              myVote == 'dislike',
              () => dbService.votePost(post.id, userProfile.id, 'dislike')
            ),
          ],
        ),
        if (total > 0) ...[
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (likes > 0) Expanded(flex: likes, child: Container(color: Colors.green)),
                  if (neutrals > 0) Expanded(flex: neutrals, child: Container(color: Colors.grey)),
                  if (dislikes > 0) Expanded(flex: dislikes, child: Container(color: Colors.red)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$likes J\'aime', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
              Text('$neutrals Neutre', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              Text('$dislikes Je n\'aime pas', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _voteButton(BuildContext context, String label, IconData icon, Color color, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        width: 100,
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : (isDark ? Colors.white24 : Colors.black12)),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : (isDark ? Colors.white70 : Colors.black54), size: 28),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: TextStyle(
              fontSize: 10, 
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? color : (isDark ? Colors.white70 : Colors.black54),
            )),
          ],
        ),
      ),
    );
  }
}

class CommentListSection extends StatelessWidget {
  final String postId;
  const CommentListSection({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    final dbService = DatabaseService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return StreamBuilder<List<CommentModel>>(
      stream: dbService.getComments(postId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text("Erreur de chargement", style: TextStyle(color: Colors.red, fontSize: 12));
        if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 20);

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Aucun commentaire.', 
              style: TextStyle(fontStyle: FontStyle.italic, color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 13)),
          );
        }

        final comments = snapshot.data!;

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: comments.length > 3 ? 3 : comments.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final comment = comments[index];
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(comment.memberName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(comment.content, style: const TextStyle(fontSize: 13)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class CommentInputField extends StatefulWidget {
  final String postId;
  const CommentInputField({super.key, required this.postId});

  @override
  State<CommentInputField> createState() => _CommentInputFieldState();
}

class _CommentInputFieldState extends State<CommentInputField> {
  final _controller = TextEditingController();
  bool _isSending = false;

  void _sendComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    final profile = Provider.of<UserProvider>(context, listen: false).userProfile;

    if (profile != null) {
      await DatabaseService().addComment(CommentModel(
        id: '',
        postId: widget.postId,
        memberId: profile.id,
        memberName: '${profile.prenom} ${profile.nom}',
        content: text,
        createdAt: DateTime.now(),
      ));
      _controller.clear();
    }
    if (mounted) setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Écrire un commentaire...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
              fillColor: Colors.grey.withOpacity(0.1),
              filled: true,
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
          onPressed: _isSending ? null : _sendComment,
        ),
      ],
    );
  }
}
