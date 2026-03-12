import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String? id;
  final String email;
  final String? telephone;
  final String? imageProfile;
  final String? token;
  final GeoPoint? location;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    this.id,
    required this.email,
    this.telephone,
    this.imageProfile,
    this.token,
    this.location,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      telephone: data['telephone'],
      imageProfile: data['image_profile'],
      token: data['token'],
      location: data['location'] as GeoPoint?,
      createdAt: (data['created_At'] as Timestamp?)?.toDate(),
      updatedAt: (data['updated_At'] as Timestamp?)?.toDate(),
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> data, {String? id}) {
    return UserModel(
      id: id,
      email: data['email'] ?? '',
      telephone: data['telephone'],
      imageProfile: data['image_profile'],
      token: data['token'],
      location: data['location'] as GeoPoint?,
      createdAt: (data['created_At'] as Timestamp?)?.toDate(),
      updatedAt: (data['updated_At'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'telephone': telephone,
      'image_profile': imageProfile,
      'token': token,
      'location': location,
      'created_At': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updated_At': FieldValue.serverTimestamp(),
    };
  }
}
