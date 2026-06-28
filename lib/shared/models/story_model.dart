import 'package:cloud_firestore/cloud_firestore.dart';

enum StoryMediaType { image, text }

class StoryModel {
  final String id;
  final String uid;
  final String? mediaUrl;
  final StoryMediaType mediaType;
  final String caption;
  final int bgColor; // for text stories
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> viewedBy;

  const StoryModel({
    required this.id,
    required this.uid,
    this.mediaUrl,
    required this.mediaType,
    this.caption = '',
    this.bgColor = 0xFF2563EB,
    required this.createdAt,
    required this.expiresAt,
    this.viewedBy = const [],
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool seenBy(String uid) => viewedBy.contains(uid);

  factory StoryModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return StoryModel(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      mediaUrl: data['mediaUrl'] as String?,
      mediaType: (data['mediaType'] as String?) == 'text'
          ? StoryMediaType.text
          : StoryMediaType.image,
      caption: data['caption'] as String? ?? '',
      bgColor: (data['bgColor'] as num?)?.toInt() ?? 0xFF2563EB,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(hours: 24)),
      viewedBy: (data['viewedBy'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType.name,
        'caption': caption,
        'bgColor': bgColor,
        'createdAt': Timestamp.fromDate(createdAt),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'viewedBy': viewedBy,
      };
}
