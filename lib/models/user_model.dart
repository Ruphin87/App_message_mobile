class UserModel {
  const UserModel({
    required this.id,
    required this.nom,
    required this.email,
    this.photo,
    this.bio,
    required this.dateCreation,
  });

  final String id;
  final String nom;
  final String email;
  final String? photo;
  final String? bio;
  final DateTime dateCreation;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      nom: json['nom'] as String,
      email: json['email'] as String,
      photo: json['photo'] as String?,
      bio: json['bio'] as String?,
      dateCreation: DateTime.parse(json['date_creation'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'email': email,
      'photo': photo,
      'bio': bio,
      'date_creation': dateCreation.toIso8601String(),
    };
  }

  /// Lecture depuis une ligne de la base locale SQLite (table `local_users`).
  factory UserModel.fromLocalDb(Map<String, dynamic> row) {
    return UserModel(
      id: row['id'] as String,
      nom: row['nom'] as String,
      email: row['email'] as String,
      photo: row['photo'] as String?,
      bio: row['bio'] as String?,
      dateCreation: DateTime.parse(row['date_creation'] as String),
    );
  }

  /// Conversion vers une ligne insérable dans la base locale SQLite.
  Map<String, dynamic> toLocalDb() {
    return {
      'id': id,
      'nom': nom,
      'email': email,
      'photo': photo,
      'bio': bio,
      'date_creation': dateCreation.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? nom,
    String? email,
    String? photo,
    String? bio,
    DateTime? dateCreation,
  }) {
    return UserModel(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      email: email ?? this.email,
      photo: photo ?? this.photo,
      bio: bio ?? this.bio,
      dateCreation: dateCreation ?? this.dateCreation,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'UserModel(id: $id, nom: $nom, email: $email, bio: $bio)';
  }
}