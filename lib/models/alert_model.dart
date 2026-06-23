enum AlertTarget { all, bureau, ordinary, manual }

class AlertModel {
  final String id;
  final String title;
  final String details;
  final String initiatorId;
  final DateTime createdAt;
  final DateTime startDate;
  final bool isActive;
  final AlertTarget targetType;
  final List<String> targetUserIds;
  final Map<String, DateTime> viewedBy;
  final Map<String, DateTime> remindMeLater;
  final Map<String, DateTime> dismissedBy;
  final String? memberId; // Pour les alertes de validation d'inscription

  AlertModel({
    required this.id,
    required this.title,
    required this.details,
    required this.initiatorId,
    required this.createdAt,
    required this.startDate,
    this.isActive = true,
    required this.targetType,
    this.targetUserIds = const [],
    this.viewedBy = const {},
    this.remindMeLater = const {},
    this.dismissedBy = const {},
    this.memberId,
  });

  factory AlertModel.fromMap(Map<String, dynamic> data, String documentId) {
    return AlertModel(
      id: documentId,
      title: data['title'] ?? '',
      details: data['details'] ?? '',
      initiatorId: data['initiatorId'] ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      startDate: (data['startDate'] as dynamic)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      targetType: AlertTarget.values.firstWhere(
        (e) => e.toString().split('.').last == data['targetType'],
        orElse: () => AlertTarget.all,
      ),
      targetUserIds: List<String>.from(data['targetUserIds'] ?? []),
      viewedBy: (data['viewedBy'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, (value as dynamic).toDate() as DateTime),
      ) ?? {},
      remindMeLater: (data['remindMeLater'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, (value as dynamic).toDate() as DateTime),
      ) ?? {},
      dismissedBy: (data['dismissedBy'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, (value as dynamic).toDate() as DateTime),
      ) ?? {},
      memberId: data['memberId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'details': details,
      'initiatorId': initiatorId,
      'createdAt': createdAt,
      'startDate': startDate,
      'isActive': isActive,
      'targetType': targetType.toString().split('.').last,
      'targetUserIds': targetUserIds,
      'viewedBy': viewedBy,
      'remindMeLater': remindMeLater,
      'dismissedBy': dismissedBy,
      'memberId': memberId,
    };
  }
}
