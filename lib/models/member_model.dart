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
  final String photoUrl;
  final DateTime dateInscription;
  final UserRole role;
  final UserStatus status;
  final Map<String, dynamic>? pendingModifications;
  final bool hasSeenTutorial;
  final DateTime? dateActivation;

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
    this.photoUrl = '',
    required this.dateInscription,
    required this.role,
    required this.status,
    this.pendingModifications,
    this.hasSeenTutorial = false,
    this.dateActivation,
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
      photoUrl: data['photoUrl'] ?? '',
      dateInscription: (data['dateInscription'] as dynamic)?.toDate() ?? DateTime.now(),
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == data['role'],
        orElse: () => UserRole.membre,
      ),
      status: UserStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => UserStatus.enAttenteTresorier,
      ),
      pendingModifications: data['pendingModifications'] != null 
          ? Map<String, dynamic>.from(data['pendingModifications']) 
          : null,
      hasSeenTutorial: data['hasSeenTutorial'] ?? false,
      dateActivation: data['dateActivation'] != null ? (data['dateActivation'] as dynamic).toDate() : null,
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
      'photoUrl': photoUrl,
      'dateInscription': dateInscription,
      'role': role.toString().split('.').last,
      'status': status.toString().split('.').last,
      'pendingModifications': pendingModifications,
      'hasSeenTutorial': hasSeenTutorial,
      'dateActivation': dateActivation,
    };
  }

  MemberModel copyWith({
    String? id,
    String? username,
    String? email,
    String? nom,
    String? prenom,
    String? telephone,
    String? adresse,
    DateTime? dateNaissance,
    String? genre,
    String? photoUrl,
    DateTime? dateInscription,
    UserRole? role,
    UserStatus? status,
    Map<String, dynamic>? pendingModifications,
    bool? hasSeenTutorial,
    DateTime? dateActivation,
  }) {
    return MemberModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      telephone: telephone ?? this.telephone,
      adresse: adresse ?? this.adresse,
      dateNaissance: dateNaissance ?? this.dateNaissance,
      genre: genre ?? this.genre,
      photoUrl: photoUrl ?? this.photoUrl,
      dateInscription: dateInscription ?? this.dateInscription,
      role: role ?? this.role,
      status: status ?? this.status,
      pendingModifications: pendingModifications ?? this.pendingModifications,
      hasSeenTutorial: hasSeenTutorial ?? this.hasSeenTutorial,
      dateActivation: dateActivation ?? this.dateActivation,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
