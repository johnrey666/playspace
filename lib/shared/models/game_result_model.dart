import 'package:cloud_firestore/cloud_firestore.dart';

class GameResultModel {
  final String id;
  final String uid;
  final String gameId;
  final String gameName;
  final int score;
  final int rank;
  final int totalPlayers;
  final DateTime createdAt;

  // Social engagement (lives on the feed entry)
  final List<String> flames; // uids that reacted
  final int commentCount;

  const GameResultModel({
    required this.id,
    required this.uid,
    required this.gameId,
    required this.gameName,
    required this.score,
    required this.rank,
    required this.totalPlayers,
    required this.createdAt,
    this.flames = const [],
    this.commentCount = 0,
  });

  bool get isWin => rank == 1;

  factory GameResultModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return GameResultModel(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      gameId: data['gameId'] as String? ?? '',
      gameName: data['gameName'] as String? ?? '',
      score: (data['score'] as num?)?.toInt() ?? 0,
      rank: (data['rank'] as num?)?.toInt() ?? 0,
      totalPlayers: (data['totalPlayers'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      flames: (data['flames'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'gameId': gameId,
        'gameName': gameName,
        'score': score,
        'rank': rank,
        'totalPlayers': totalPlayers,
        'createdAt': Timestamp.fromDate(createdAt),
        'flames': flames,
        'commentCount': commentCount,
      };
}

class FeedComment {
  final String id;
  final String uid;
  final String text;
  final DateTime createdAt;

  const FeedComment({
    required this.id,
    required this.uid,
    required this.text,
    required this.createdAt,
  });

  factory FeedComment.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FeedComment(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'text': text,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
