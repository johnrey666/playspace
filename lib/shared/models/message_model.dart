import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderUid;
  final String text;
  final String? imageUrl; // base64 data URI for photo messages
  final DateTime sentAt;
  final List<String> readBy;

  const MessageModel({
    required this.id,
    required this.senderUid,
    required this.text,
    this.imageUrl,
    required this.sentAt,
    this.readBy = const [],
  });

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  factory MessageModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MessageModel(
      id: doc.id,
      senderUid: data['senderUid'] as String? ?? '',
      text: data['text'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readBy: (data['readBy'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'senderUid': senderUid,
        'text': text,
        'imageUrl': imageUrl,
        'sentAt': Timestamp.fromDate(sentAt),
        'readBy': readBy,
      };
}
