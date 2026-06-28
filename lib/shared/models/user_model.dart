import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String displayName;
  final String username;
  final String email;
  final String? photoUrl;
  final String bio;
  final String firstName;
  final String lastName;
  final DateTime? birthday;
  final List<String> friendIds;
  final DateTime createdAt;
  final bool isOnline;
  final DateTime? lastSeen;
  final int totalScore;

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.username,
    required this.email,
    this.photoUrl,
    this.bio = '',
    this.firstName = '',
    this.lastName = '',
    this.birthday,
    this.friendIds = const [],
    required this.createdAt,
    this.isOnline = false,
    this.lastSeen,
    this.totalScore = 0,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      username: map['username'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      bio: map['bio'] as String? ?? '',
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      birthday: (map['birthday'] as Timestamp?)?.toDate(),
      friendIds: (map['friendIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isOnline: map['isOnline'] as bool? ?? false,
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate(),
      totalScore: (map['totalScore'] as num?)?.toInt() ?? 0,
    );
  }

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel.fromMap({...data, 'uid': doc.id});
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'username': username,
      'email': email,
      'photoUrl': photoUrl,
      'bio': bio,
      'firstName': firstName,
      'lastName': lastName,
      'birthday': birthday != null ? Timestamp.fromDate(birthday!) : null,
      'friendIds': friendIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'totalScore': totalScore,
    };
  }

  UserModel copyWith({
    String? displayName,
    String? username,
    String? photoUrl,
    String? bio,
    String? firstName,
    String? lastName,
    DateTime? birthday,
    List<String>? friendIds,
    bool? isOnline,
    DateTime? lastSeen,
    int? totalScore,
  }) {
    return UserModel(
      uid: uid,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      email: email,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      birthday: birthday ?? this.birthday,
      friendIds: friendIds ?? this.friendIds,
      createdAt: createdAt,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      totalScore: totalScore ?? this.totalScore,
    );
  }
}
