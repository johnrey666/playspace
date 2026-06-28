import 'package:firebase_database/firebase_database.dart';

class MatchHandle {
  final String matchId;
  final bool isHost;
  const MatchHandle(this.matchId, this.isHost);
}

/// Lobby-based matchmaking on Realtime Database. Works for 1v1 (auto-start at
/// capacity) and multiplayer games (host starts once min players present).
///
/// Structure: `matchmaking/{gameId}/{matchId}`
///   - status: 'waiting' | 'started' | 'closed'
///   - host: uid
///   - min / max
///   - players/{uid}: { name, photoUrl, joinedAt }
class MatchmakingService {
  MatchmakingService({FirebaseDatabase? database})
      : _db = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  DatabaseReference _gameRef(String gameId) => _db.ref('matchmaking/$gameId');

  /// Joins an open lobby or creates a new one. Returns the match handle.
  Future<MatchHandle> joinRandom({
    required String gameId,
    required String uid,
    required String name,
    String? photoUrl,
    required int minPlayers,
    required int maxPlayers,
  }) async {
    final gameRef = _gameRef(gameId);
    String? joinedMatchId;
    bool isHost = false;

    final result = await gameRef.runTransaction((current) {
      final data = Map<String, dynamic>.from(
          (current as Map?)?.cast<String, dynamic>() ?? {});

      // Find an open waiting match with room.
      String? target;
      data.forEach((matchId, value) {
        if (target != null) return;
        final m = Map<String, dynamic>.from(value as Map);
        final players =
            Map<String, dynamic>.from((m['players'] as Map?) ?? {});
        if (m['status'] == 'waiting' &&
            players.length < (m['max'] as num).toInt() &&
            !players.containsKey(uid)) {
          target = matchId;
        }
      });

      final playerData = {
        'name': name,
        'photoUrl': photoUrl,
        'joinedAt': ServerValue.timestamp,
      };

      if (target != null) {
        final m = Map<String, dynamic>.from(data[target] as Map);
        final players =
            Map<String, dynamic>.from((m['players'] as Map?) ?? {});
        players[uid] = playerData;
        m['players'] = players;
        // Auto-start 1v1 lobbies the moment they fill.
        if (players.length >= (m['max'] as num).toInt()) {
          m['status'] = 'started';
        }
        data[target!] = m;
        joinedMatchId = target;
        isHost = false;
      } else {
        final newId = gameRef.push().key!;
        data[newId] = {
          'status': 'waiting',
          'host': uid,
          'min': minPlayers,
          'max': maxPlayers,
          'createdAt': ServerValue.timestamp,
          'players': {uid: playerData},
        };
        joinedMatchId = newId;
        isHost = true;
      }

      return Transaction.success(data);
    });

    if (!result.committed || joinedMatchId == null) {
      throw Exception('Matchmaking failed, please retry.');
    }
    return MatchHandle(joinedMatchId!, isHost);
  }

  /// Creates a private lobby for a direct challenge. Both players use the same
  /// matchId so the challenge can deep-link straight into the game.
  Future<MatchHandle> createPrivateMatch({
    required String gameId,
    required String matchId,
    required String hostUid,
    required String name,
    String? photoUrl,
    required int minPlayers,
    required int maxPlayers,
  }) async {
    await _gameRef(gameId).child(matchId).set({
      'status': 'waiting',
      'host': hostUid,
      'min': minPlayers,
      'max': maxPlayers,
      'private': true,
      'createdAt': ServerValue.timestamp,
      'players': {
        hostUid: {
          'name': name,
          'photoUrl': photoUrl,
          'joinedAt': ServerValue.timestamp,
        },
      },
    });
    return MatchHandle(matchId, true);
  }

  Future<void> joinMatch({
    required String gameId,
    required String matchId,
    required String uid,
    required String name,
    String? photoUrl,
  }) async {
    await _gameRef(gameId).child('$matchId/players/$uid').set({
      'name': name,
      'photoUrl': photoUrl,
      'joinedAt': ServerValue.timestamp,
    });
  }

  Stream<DatabaseEvent> lobbyStream(String gameId, String matchId) =>
      _gameRef(gameId).child(matchId).onValue;

  Future<void> startMatch(String gameId, String matchId) =>
      _gameRef(gameId).child('$matchId/status').set('started');

  Future<void> leaveLobby(String gameId, String matchId, String uid) =>
      _gameRef(gameId).child('$matchId/players/$uid').remove();
}
