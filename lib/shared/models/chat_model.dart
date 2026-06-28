import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final List<String> memberIds;
  final bool isGroupChat;
  final String? groupName;
  final String? groupPhotoUrl;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final String? createdBy;
  final Map<String, int> unreadCounts;

  const ChatModel({
    required this.id,
    required this.memberIds,
    required this.isGroupChat,
    this.groupName,
    this.groupPhotoUrl,
    this.lastMessage = '',
    this.lastMessageAt,
    this.createdBy,
    this.unreadCounts = const {},
  });

  factory ChatModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChatModel(
      id: doc.id,
      memberIds: (data['memberIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      isGroupChat: data['isGroupChat'] as bool? ?? false,
      groupName: data['groupName'] as String?,
      groupPhotoUrl: data['groupPhotoUrl'] as String?,
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String?,
      unreadCounts: (data['unreadCounts'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }

  Map<String, dynamic> toMap() => {
        'memberIds': memberIds,
        'isGroupChat': isGroupChat,
        'groupName': groupName,
        'groupPhotoUrl': groupPhotoUrl,
        'lastMessage': lastMessage,
        'lastMessageAt':
            lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
        'createdBy': createdBy,
        'unreadCounts': unreadCounts,
      };

  String otherMemberId(String myUid) =>
      memberIds.firstWhere((id) => id != myUid, orElse: () => myUid);

  int unreadFor(String uid) => unreadCounts[uid] ?? 0;
}
