import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/challenge_model.dart';
import '../models/chat_model.dart';
import '../models/friend_request_model.dart';
import '../models/game_result_model.dart';
import '../models/message_model.dart';
import '../models/post_model.dart';
import '../models/story_model.dart';
import '../models/user_model.dart';

/// Central Firestore data access layer for PlaySpace.
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // Collections
  CollectionReference<Map<String, dynamic>> get users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get friendRequests =>
      _db.collection('friendRequests');
  CollectionReference<Map<String, dynamic>> get stories =>
      _db.collection('stories');
  CollectionReference<Map<String, dynamic>> get chats => _db.collection('chats');
  CollectionReference<Map<String, dynamic>> get challenges =>
      _db.collection('challenges');
  CollectionReference<Map<String, dynamic>> get gameResults =>
      _db.collection('gameResults');
  CollectionReference<Map<String, dynamic>> get posts => _db.collection('posts');

  // ---------------------------------------------------------------------------
  // Users
  // ---------------------------------------------------------------------------
  Stream<UserModel?> userStream(String uid) =>
      users.doc(uid).snapshots().map((d) => d.exists ? UserModel.fromDoc(d) : null);

  Future<UserModel?> getUser(String uid) async {
    final doc = await users.doc(uid).get();
    return doc.exists ? UserModel.fromDoc(doc) : null;
  }

  Future<List<UserModel>> getUsers(List<String> uids) async {
    if (uids.isEmpty) return [];
    final List<UserModel> result = [];
    // Firestore whereIn supports up to 30 elements per query.
    for (var i = 0; i < uids.length; i += 30) {
      final chunk = uids.sublist(i, i + 30 > uids.length ? uids.length : i + 30);
      final snap =
          await users.where(FieldPath.documentId, whereIn: chunk).get();
      result.addAll(snap.docs.map(UserModel.fromDoc));
    }
    return result;
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) =>
      users.doc(uid).update(data);

  Future<List<UserModel>> searchByUsername(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final snap = await users
        .where('username', isGreaterThanOrEqualTo: q)
        .where('username', isLessThanOrEqualTo: '$q\uf8ff')
        .limit(25)
        .get();
    return snap.docs.map(UserModel.fromDoc).toList();
  }

  // ---------------------------------------------------------------------------
  // Friend requests
  // ---------------------------------------------------------------------------
  Future<void> sendFriendRequest(String fromUid, String toUid) async {
    // Avoid duplicates.
    final existing = await friendRequests
        .where('fromUid', isEqualTo: fromUid)
        .where('toUid', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;
    await friendRequests.add(FriendRequestModel(
      id: '',
      fromUid: fromUid,
      toUid: toUid,
      status: FriendRequestStatus.pending,
      createdAt: DateTime.now(),
    ).toMap());
  }

  Stream<List<FriendRequestModel>> incomingRequests(String uid) => friendRequests
      .where('toUid', isEqualTo: uid)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((s) => s.docs.map(FriendRequestModel.fromDoc).toList());

  Future<void> acceptFriendRequest(FriendRequestModel request) async {
    final batch = _db.batch();
    batch.update(friendRequests.doc(request.id), {'status': 'accepted'});
    batch.update(users.doc(request.fromUid), {
      'friendIds': FieldValue.arrayUnion([request.toUid]),
    });
    batch.update(users.doc(request.toUid), {
      'friendIds': FieldValue.arrayUnion([request.fromUid]),
    });
    await batch.commit();
  }

  Future<void> declineFriendRequest(String requestId) =>
      friendRequests.doc(requestId).update({'status': 'declined'});

  Future<FriendRequestStatus?> requestStatusBetween(
      String fromUid, String toUid) async {
    final snap = await friendRequests
        .where('fromUid', isEqualTo: fromUid)
        .where('toUid', isEqualTo: toUid)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return FriendRequestModel.fromDoc(snap.docs.first).status;
  }

  // ---------------------------------------------------------------------------
  // Stories
  // ---------------------------------------------------------------------------
  Future<void> addStory(StoryModel story) => stories.add(story.toMap());

  Stream<List<StoryModel>> activeStoriesFor(List<String> uids) {
    if (uids.isEmpty) {
      return const Stream<List<StoryModel>>.empty();
    }
    final now = Timestamp.now();
    // whereIn is limited; for typical friend counts this is fine (<=30).
    final ids = uids.length > 30 ? uids.sublist(0, 30) : uids;
    return stories
        .where('uid', whereIn: ids)
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt')
        .snapshots()
        .map((s) => s.docs.map(StoryModel.fromDoc).toList());
  }

  Future<void> markStoryViewed(String storyId, String uid) => stories
      .doc(storyId)
      .update({'viewedBy': FieldValue.arrayUnion([uid])});

  // ---------------------------------------------------------------------------
  // Chats & messages
  // ---------------------------------------------------------------------------
  Stream<List<ChatModel>> chatsFor(String uid) => chats
      .where('memberIds', arrayContains: uid)
      .orderBy('lastMessageAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(ChatModel.fromDoc).toList());

  Future<ChatModel> getOrCreatePmChat(String myUid, String otherUid) async {
    final snap = await chats
        .where('memberIds', arrayContains: myUid)
        .where('isGroupChat', isEqualTo: false)
        .get();
    for (final doc in snap.docs) {
      final chat = ChatModel.fromDoc(doc);
      if (chat.memberIds.contains(otherUid)) return chat;
    }
    final ref = await chats.add(ChatModel(
      id: '',
      memberIds: [myUid, otherUid],
      isGroupChat: false,
      unreadCounts: {myUid: 0, otherUid: 0},
    ).toMap());
    final created = await ref.get();
    return ChatModel.fromDoc(created);
  }

  Future<String> createGroupChat({
    required String createdBy,
    required List<String> memberIds,
    required String groupName,
    String? groupPhotoUrl,
  }) async {
    final ref = await chats.add(ChatModel(
      id: '',
      memberIds: memberIds,
      isGroupChat: true,
      groupName: groupName,
      groupPhotoUrl: groupPhotoUrl,
      createdBy: createdBy,
      lastMessage: 'Group created',
      lastMessageAt: DateTime.now(),
      unreadCounts: {for (final m in memberIds) m: 0},
    ).toMap());
    return ref.id;
  }

  Future<void> updateGroup(String chatId, Map<String, dynamic> data) =>
      chats.doc(chatId).update(data);

  Stream<ChatModel> chatStream(String chatId) =>
      chats.doc(chatId).snapshots().map(ChatModel.fromDoc);

  Stream<List<MessageModel>> messages(String chatId) => chats
      .doc(chatId)
      .collection('messages')
      .orderBy('sentAt', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map(MessageModel.fromDoc).toList());

  Future<void> sendMessage({
    required ChatModel chat,
    required String senderUid,
    required String text,
    String? imageUrl,
  }) async {
    final batch = _db.batch();
    final msgRef = chats.doc(chat.id).collection('messages').doc();
    batch.set(msgRef, MessageModel(
      id: msgRef.id,
      senderUid: senderUid,
      text: text,
      imageUrl: imageUrl,
      sentAt: DateTime.now(),
      readBy: [senderUid],
    ).toMap());

    final preview = imageUrl != null && imageUrl.isNotEmpty
        ? (text.isNotEmpty ? '📷 $text' : '📷 Photo')
        : text;
    final unread = Map<String, int>.from(chat.unreadCounts);
    for (final m in chat.memberIds) {
      if (m != senderUid) unread[m] = (unread[m] ?? 0) + 1;
    }
    batch.update(chats.doc(chat.id), {
      'lastMessage': preview,
      'lastMessageAt': Timestamp.now(),
      'unreadCounts': unread,
    });
    await batch.commit();
  }

  Future<void> markChatRead(String chatId, String uid) =>
      chats.doc(chatId).update({'unreadCounts.$uid': 0});

  Future<void> markMessagesRead(String chatId, String uid) async {
    final unread = await chats
        .doc(chatId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(50)
        .get();
    final batch = _db.batch();
    for (final doc in unread.docs) {
      final m = MessageModel.fromDoc(doc);
      if (!m.readBy.contains(uid)) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([uid]),
        });
      }
    }
    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // Challenges
  // ---------------------------------------------------------------------------
  Future<String> sendChallenge({
    required String fromUid,
    required String toUid,
    required String gameId,
  }) async {
    final ref = await challenges.add(ChallengeModel(
      id: '',
      fromUid: fromUid,
      toUid: toUid,
      gameId: gameId,
      status: ChallengeStatus.pending,
      createdAt: DateTime.now(),
    ).toMap());
    return ref.id;
  }

  Stream<List<ChallengeModel>> incomingChallenges(String uid) => challenges
      .where('toUid', isEqualTo: uid)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((s) => s.docs.map(ChallengeModel.fromDoc).toList());

  /// Live updates for a single challenge (used by the challenger to detect when
  /// their opponent accepts and jump straight into the game).
  Stream<ChallengeModel?> challengeStream(String id) => challenges
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? ChallengeModel.fromDoc(d) : null);

  Future<void> respondToChallenge(
    String challengeId,
    ChallengeStatus status, {
    String? matchId,
  }) =>
      challenges.doc(challengeId).update({
        'status': status.name,
        'matchId': ?matchId,
      });

  // ---------------------------------------------------------------------------
  // Game results & feed
  // ---------------------------------------------------------------------------
  Future<void> postGameResult(GameResultModel result) async {
    await gameResults.add(result.toMap());
    if (result.isWin) {
      await users.doc(result.uid).update({
        'totalScore': FieldValue.increment(result.score),
      });
    } else {
      await users.doc(result.uid).update({
        'totalScore': FieldValue.increment(result.score),
      });
    }
  }

  Stream<List<GameResultModel>> feedFor(List<String> uids) {
    final ids = uids.isEmpty ? ['__none__'] : uids;
    final limited = ids.length > 30 ? ids.sublist(0, 30) : ids;
    return gameResults
        .where('uid', whereIn: limited)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map(GameResultModel.fromDoc).toList());
  }

  Stream<List<GameResultModel>> resultsForUser(String uid) => gameResults
      .where('uid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(30)
      .snapshots()
      .map((s) => s.docs.map(GameResultModel.fromDoc).toList());

  Future<void> toggleFlame(String resultId, String uid, bool add) =>
      gameResults.doc(resultId).update({
        'flames':
            add ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
      });

  Stream<List<FeedComment>> comments(String resultId) => gameResults
      .doc(resultId)
      .collection('comments')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(FeedComment.fromDoc).toList());

  Future<void> addComment(String resultId, FeedComment comment) async {
    await gameResults.doc(resultId).collection('comments').add(comment.toMap());
    await gameResults
        .doc(resultId)
        .update({'commentCount': FieldValue.increment(1)});
  }

  // ---------------------------------------------------------------------------
  // Posts (social feed: status updates + shared game results)
  // ---------------------------------------------------------------------------
  Future<void> createPost(PostModel post) => posts.add(post.toMap());

  /// Home feed: the signed-in user's + their friends' posts, newest first.
  Stream<List<PostModel>> feedPosts(List<String> uids) {
    final ids = uids.isEmpty ? ['__none__'] : uids;
    final limited = ids.length > 30 ? ids.sublist(0, 30) : ids;
    return posts
        .where('uid', whereIn: limited)
        .orderBy('createdAt', descending: true)
        .limit(60)
        .snapshots()
        .map((s) => s.docs.map(PostModel.fromDoc).toList());
  }

  Stream<List<PostModel>> postsForUser(String uid) => posts
      .where('uid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(40)
      .snapshots()
      .map((s) => s.docs.map(PostModel.fromDoc).toList());

  Future<void> togglePostLike(String postId, String uid, bool add) =>
      posts.doc(postId).update({
        'likes':
            add ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
      });

  Future<void> deletePost(String postId) => posts.doc(postId).delete();

  Stream<List<FeedComment>> postComments(String postId) => posts
      .doc(postId)
      .collection('comments')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(FeedComment.fromDoc).toList());

  Future<void> addPostComment(String postId, FeedComment comment) async {
    await posts.doc(postId).collection('comments').add(comment.toMap());
    await posts.doc(postId).update({'commentCount': FieldValue.increment(1)});
  }

  // ---------------------------------------------------------------------------
  // Leaderboard
  // ---------------------------------------------------------------------------
  Stream<List<UserModel>> globalLeaderboard() => users
      .orderBy('totalScore', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(UserModel.fromDoc).toList());

  Future<List<UserModel>> friendsLeaderboard(List<String> uids) async {
    final list = await getUsers(uids);
    list.sort((a, b) => b.totalScore.compareTo(a.totalScore));
    return list;
  }

  /// Top scores for a single game (used by each game lobby).
  Stream<List<GameResultModel>> gameLeaderboard(String gameId) => gameResults
      .where('gameId', isEqualTo: gameId)
      .orderBy('score', descending: true)
      .limit(20)
      .snapshots()
      .map((s) => s.docs.map(GameResultModel.fromDoc).toList());
}
