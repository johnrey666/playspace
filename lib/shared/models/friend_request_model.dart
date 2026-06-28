import 'package:cloud_firestore/cloud_firestore.dart';

enum FriendRequestStatus { pending, accepted, declined }

FriendRequestStatus _statusFrom(String? value) {
  switch (value) {
    case 'accepted':
      return FriendRequestStatus.accepted;
    case 'declined':
      return FriendRequestStatus.declined;
    default:
      return FriendRequestStatus.pending;
  }
}

class FriendRequestModel {
  final String id;
  final String fromUid;
  final String toUid;
  final FriendRequestStatus status;
  final DateTime createdAt;

  const FriendRequestModel({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.status,
    required this.createdAt,
  });

  factory FriendRequestModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FriendRequestModel(
      id: doc.id,
      fromUid: data['fromUid'] as String? ?? '',
      toUid: data['toUid'] as String? ?? '',
      status: _statusFrom(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'fromUid': fromUid,
        'toUid': toUid,
        'status': status.name,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
