import 'package:cloud_firestore/cloud_firestore.dart';

enum PostType { text, game }

PostType _typeFrom(String? v) =>
    v == 'game' ? PostType.game : PostType.text;

/// A social post on the home feed / profile. Either a free-text status (with an
/// optional base64 image) or a shared game result card.
class PostModel {
  final String id;
  final String uid;
  final PostType type;
  final String text;
  final String? imageUrl; // base64 data URI for photo posts
  final DateTime createdAt;
  final List<String> likes;
  final int commentCount;

  // Game-share fields (type == game)
  final String? gameId;
  final String? gameName;
  final int score;
  final int rank;
  final int totalPlayers;
  final bool isWin;

  const PostModel({
    required this.id,
    required this.uid,
    required this.type,
    this.text = '',
    this.imageUrl,
    required this.createdAt,
    this.likes = const [],
    this.commentCount = 0,
    this.gameId,
    this.gameName,
    this.score = 0,
    this.rank = 0,
    this.totalPlayers = 0,
    this.isWin = false,
  });

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool likedBy(String uid) => likes.contains(uid);

  factory PostModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PostModel(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      type: _typeFrom(data['type'] as String?),
      text: data['text'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: (data['likes'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      gameId: data['gameId'] as String?,
      gameName: data['gameName'] as String?,
      score: (data['score'] as num?)?.toInt() ?? 0,
      rank: (data['rank'] as num?)?.toInt() ?? 0,
      totalPlayers: (data['totalPlayers'] as num?)?.toInt() ?? 0,
      isWin: data['isWin'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'type': type.name,
        'text': text,
        'imageUrl': imageUrl,
        'createdAt': Timestamp.fromDate(createdAt),
        'likes': likes,
        'commentCount': commentCount,
        'gameId': gameId,
        'gameName': gameName,
        'score': score,
        'rank': rank,
        'totalPlayers': totalPlayers,
        'isWin': isWin,
      };
}
