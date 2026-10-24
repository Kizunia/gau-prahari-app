import 'dart:convert';
import '../../domain/entities/user.dart';

/// Data model representing a user with JSON serialization.
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.name,
    required super.identifier,
    required super.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      identifier: json['identifier'] as String? ?? '',
      role: json['role'] as String? ?? 'Dairy Farmer',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'identifier': identifier, 'role': role};
  }

  String toJsonString() => jsonEncode(toJson());

  factory UserModel.fromJsonString(String source) =>
      UserModel.fromJson(jsonDecode(source) as Map<String, dynamic>);

  factory UserModel.fromEntity(User user) {
    return UserModel(
      id: user.id,
      name: user.name,
      identifier: user.identifier,
      role: user.role,
    );
  }
}
