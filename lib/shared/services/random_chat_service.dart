import 'package:firebase_database/firebase_database.dart';

/// Result of attempting to enter the random-chat pool.
class RandomMatchResult {
  /// Non-null when paired immediately; null means we're now waiting in queue.
  final String? roomId;
  const RandomMatchResult(this.roomId);
}

/// Anonymous random ("stranger") chat backed by Realtime Database.
///
/// Structure under `randomChat`:
///   - `queue/{uid}`  = { exclude, since }     waiting users
///   - `rooms/{roomId}` = { users:{a,b}, active, createdAt, messages:{...} }
///   - `users/{uid}`  = { roomId, lastPartner, lastEndedAt }
///
/// Matching is done with a transaction on the shared `queue` node so two
/// clients can never grab the same partner. A 5-minute cooldown prevents
/// instantly re-matching the person you just left.
class RandomChatService {
  RandomChatService({FirebaseDatabase? database})
      : _db = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  static const Duration rematchCooldown = Duration(minutes: 5);

  DatabaseReference get _root => _db.ref('randomChat');
  DatabaseReference get _queue => _root.child('queue');
  DatabaseReference _userMeta(String uid) => _root.child('users/$uid');
  DatabaseReference _room(String roomId) => _root.child('rooms/$roomId');

  /// Reads the partner we should avoid right now (the last person we left,
  /// if that happened within the cooldown window).
  Future<String?> _currentExclude(String uid) async {
    final snap = await _userMeta(uid).get();
    final data = snap.value;
    if (data is! Map) return null;
    final lastPartner = data['lastPartner']?.toString();
    final lastEndedAt = (data['lastEndedAt'] as num?)?.toInt();
    if (lastPartner == null || lastEndedAt == null) return null;
    final elapsed =
        DateTime.now().millisecondsSinceEpoch - lastEndedAt;
    if (elapsed < rematchCooldown.inMilliseconds) return lastPartner;
    return null;
  }

  /// Tries to pair with a waiting stranger; otherwise joins the queue.
  Future<RandomMatchResult> findOrQueue(String uid) async {
    // Clear any stale room pointer up-front so a freshly-assigned one (set by a
    // partner who matches us while we wait) is never accidentally wiped.
    await _userMeta(uid).child('roomId').remove();

    final myExclude = await _currentExclude(uid);
    String? matchedUid;

    final result = await _queue.runTransaction((current) {
      final data = Map<String, dynamic>.from(
          (current as Map?)?.cast<String, dynamic>() ?? {});

      matchedUid = null;
      for (final entry in data.entries) {
        final otherUid = entry.key;
        if (otherUid == uid) continue;
        final value = entry.value;
        final theirExclude =
            value is Map ? value['exclude']?.toString() : null;
        if (myExclude == otherUid) continue;
        if (theirExclude == uid) continue;
        matchedUid = otherUid;
        break;
      }

      if (matchedUid != null) {
        // Claim the partner by removing both from the queue.
        data.remove(matchedUid);
        data.remove(uid);
      } else {
        data[uid] = {
          'exclude': myExclude ?? '',
          'since': ServerValue.timestamp,
        };
      }
      return Transaction.success(data);
    });

    if (!result.committed) {
      throw Exception('Could not join random chat. Try again.');
    }

    final partner = matchedUid;
    if (partner == null) {
      // Now waiting in the queue; the myRoomStream listener will fire once a
      // partner pairs with us.
      return const RandomMatchResult(null);
    }

    // Paired: create the room and point both users at it.
    final roomId = _root.child('rooms').push().key!;
    await _room(roomId).set({
      'users': {uid: true, partner: true},
      'active': true,
      'createdAt': ServerValue.timestamp,
    });
    await _userMeta(uid).child('roomId').set(roomId);
    await _userMeta(partner).child('roomId').set(roomId);
    return RandomMatchResult(roomId);
  }

  /// Fires with the room id once we've been matched (or null while waiting).
  Stream<String?> myRoomStream(String uid) =>
      _userMeta(uid).child('roomId').onValue.map((e) {
        final v = e.snapshot.value;
        return (v is String && v.isNotEmpty) ? v : null;
      });

  Stream<DatabaseEvent> roomStream(String roomId) => _room(roomId).onValue;

  Future<void> sendMessage(String roomId, String sender, String text) =>
      _room(roomId).child('messages').push().set({
        'sender': sender,
        'text': text,
        'at': ServerValue.timestamp,
      });

  Future<void> cancelQueue(String uid) => _queue.child(uid).remove();

  /// Ends the chat for both parties and records the cooldown partner so they
  /// won't be matched again for [rematchCooldown].
  Future<void> endChat(String roomId, String uid) async {
    final snap = await _room(roomId).get();
    final data = snap.value;
    final users = <String>[];
    if (data is Map && data['users'] is Map) {
      (data['users'] as Map).forEach((k, _) => users.add(k.toString()));
    }
    await _room(roomId).update({'active': false, 'endedBy': uid});
    final now = ServerValue.timestamp;
    for (final u in users) {
      final partner = users.firstWhere((x) => x != u, orElse: () => '');
      await _userMeta(u).update({
        'roomId': null,
        'lastPartner': partner,
        'lastEndedAt': now,
      });
    }
  }

  /// Best-effort cleanup when leaving the feature entirely.
  Future<void> leave(String uid) async {
    await cancelQueue(uid);
    await _userMeta(uid).child('roomId').remove();
  }
}
