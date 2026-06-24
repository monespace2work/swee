enum PostType { ordinaire, officiel, promotion }

class PostModel {
  final String id;
  final String title;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;
  final String authorId;
  final bool isActive;
  final PostType type;
  final double aspectRatio;
  final Map<String, String> votes; // memberId -> 'like'|'dislike'|'neutral'

  PostModel({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    required this.authorId,
    this.isActive = true,
    this.type = PostType.ordinaire,
    this.aspectRatio = 16 / 9,
    this.votes = const {},
  });

  factory PostModel.fromMap(Map<String, dynamic> data, String documentId) {
    String description = data['content'] ?? '';
    String defaultTitle = description.length > 30 
        ? '${description.substring(0, 30)}...' 
        : description;

    Map<String, String> votesMap = {};
    if (data['votes'] != null) {
      (data['votes'] as Map).forEach((key, value) {
        votesMap[key.toString()] = value.toString();
      });
    }

    return PostModel(
      id: documentId,
      title: data['title'] ?? defaultTitle,
      content: description,
      imageUrl: data['imageUrl'],
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      authorId: data['authorId'] ?? '',
      isActive: data['isActive'] ?? true,
      type: PostType.values.firstWhere(
        (e) => e.toString().split('.').last == (data['type'] ?? 'ordinaire'),
        orElse: () => PostType.ordinaire,
      ),
      aspectRatio: (data['aspectRatio'] ?? 16 / 9).toDouble(),
      votes: votesMap,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'imageUrl': imageUrl,
      'createdAt': createdAt,
      'authorId': authorId,
      'isActive': isActive,
      'type': type.toString().split('.').last,
      'aspectRatio': aspectRatio,
      'votes': votes,
    };
  }
}

class CommentModel {
  final String id;
  final String postId;
  final String memberId;
  final String memberName;
  final String content;
  final DateTime createdAt;

  CommentModel({
    required this.id,
    required this.postId,
    required this.memberId,
    required this.memberName,
    required this.content,
    required this.createdAt,
  });

  factory CommentModel.fromMap(Map<String, dynamic> data, String documentId) {
    return CommentModel(
      id: documentId,
      postId: data['postId'] ?? '',
      memberId: data['memberId'] ?? '',
      memberName: data['memberName'] ?? '',
      content: data['content'] ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'memberId': memberId,
      'memberName': memberName,
      'content': content,
      'createdAt': createdAt,
    };
  }
}
