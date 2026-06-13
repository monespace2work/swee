enum UserRole { secretaire, tresorier, president, membre, conseiller }
enum UserStatus { enAttenteTresorier, enAttentePresident, actif, suspendu, desactive }

class MemberModel {
  final String id;
  final String username;
  final String email;
  final String nom;
  final String prenom;
  final String telephone;
  final String adresse;
  final DateTime dateNaissance;
  final String genre; // 'M' or 'F'
  final DateTime dateInscription;
  final UserRole role;
  final UserStatus status;
  final Map<String, dynamic>? pendingModifications;

  MemberModel({
    required this.id,
    required this.username,
    required this.email,
    required this.nom,
    required this.prenom,
    required this.telephone,
    required this.adresse,
    required this.dateNaissance,
    required this.genre,
    required this.dateInscription,
    required this.role,
    required this.status,
    this.pendingModifications,
  });

  factory MemberModel.fromMap(Map<String, dynamic> data, String documentId) {
    return MemberModel(
      id: documentId,
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      nom: data['nom'] ?? '',
      prenom: data['prenom'] ?? '',
      telephone: data['telephone'] ?? '',
      adresse: data['adresse'] ?? '',
      dateNaissance: (data['dateNaissance'] as dynamic)?.toDate() ?? DateTime.now(),
      genre: data['genre'] ?? 'M',
      dateInscription: (data['dateInscription'] as dynamic)?.toDate() ?? DateTime.now(),
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == data['role'],
        orElse: () => UserRole.membre,
      ),
      status: UserStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => UserStatus.enAttenteTresorier,
      ),
      pendingModifications: data['pendingModifications'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'email': email,
      'nom': nom,
      'prenom': prenom,
      'telephone': telephone,
      'adresse': adresse,
      'dateNaissance': dateNaissance,
      'genre': genre,
      'dateInscription': dateInscription,
      'role': role.toString().split('.').last,
      'status': status.toString().split('.').last,
      'pendingModifications': pendingModifications,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
