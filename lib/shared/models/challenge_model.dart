import 'package:cloud_firestore/cloud_firestore.dart';

enum ChallengeStatus { pending, accepted, declined }

ChallengeStatus _statusFrom(String? value) {
  switch (value) {
    case 'accepted':
      return ChallengeStatus.accepted;
    case 'declined':
      return ChallengeStatus.declined;
    default:
      return ChallengeStatus.pending;
  }
}

class ChallengeModel {
  final String id;
  final String fromUid;
  final String toUid;
  final String gameId;
  final ChallengeStatus status;
  final DateTime createdAt;
  final String? matchId;

  const ChallengeModel({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.gameId,
    required this.status,
    required this.createdAt,
    this.matchId,
  });

  factory ChallengeModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChallengeModel(
      id: doc.id,
      fromUid: data['fromUid'] as String? ?? '',
      toUid: data['toUid'] as String? ?? '',
      gameId: data['gameId'] as String? ?? '',
      status: _statusFrom(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      matchId: data['matchId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'fromUid': fromUid,
        'toUid': toUid,
        'gameId': gameId,
        'status': status.name,
        'createdAt': Timestamp.fromDate(createdAt),
        'matchId': matchId,
      };
}
