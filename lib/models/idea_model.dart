enum IdeaStatus { 
  enAttenteTraitement, 
  enAttentePublication, 
  rejetee, 
  publiee 
}

class IdeaModel {
  final String id;
  final String memberId;
  final String memberName;
  final String title;
  final String description;
  final DateTime createdAt;
  final IdeaStatus status;
  final String? response;
  final String? moderatedBy;

  IdeaModel({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.status,
    this.response,
    this.moderatedBy,
  });

  factory IdeaModel.fromMap(Map<String, dynamic> data, String documentId) {
    return IdeaModel(
      id: documentId,
      memberId: data['memberId'] ?? '',
      memberName: data['memberName'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      status: IdeaStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => IdeaStatus.enAttenteTraitement,
      ),
      response: data['response'],
      moderatedBy: data['moderatedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'memberId': memberId,
      'memberName': memberName,
      'title': title,
      'description': description,
      'createdAt': createdAt,
      'status': status.toString().split('.').last,
      'response': response,
      'moderatedBy': moderatedBy,
    };
  }
}
