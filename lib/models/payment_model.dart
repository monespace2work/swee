enum PaymentType { adhesion, mensuelle, extraordinaire }

class PaymentModel {
  final String id;
  final String memberId;
  final DateTime date;
  final PaymentType type;
  final double montant;
  final String modeReglement;
  final String? description;

  PaymentModel({
    required this.id,
    required this.memberId,
    required this.date,
    required this.type,
    required this.montant,
    required this.modeReglement,
    this.description,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> data, String documentId) {
    return PaymentModel(
      id: documentId,
      memberId: data['memberId'] ?? '',
      date: (data['date'] as dynamic)?.toDate() ?? DateTime.now(),
      type: PaymentType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type'],
        orElse: () => PaymentType.mensuelle,
      ),
      montant: (data['montant'] as num).toDouble(),
      modeReglement: data['modeReglement'] ?? '',
      description: data['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'memberId': memberId,
      'date': date,
      'type': type.toString().split('.').last,
      'montant': montant,
      'modeReglement': modeReglement,
      'description': description,
    };
  }
}
