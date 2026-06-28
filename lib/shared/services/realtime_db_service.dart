import 'package:firebase_database/firebase_database.dart';

/// Thin wrapper around Firebase Realtime Database used for live in-game state.
///
/// Game state is stored under `matches/{gameId}/{matchId}`. Each game module
/// defines its own sub-structure but relies on these primitives for syncing.
class RealtimeDbService {
  RealtimeDbService({FirebaseDatabase? database})
      : _db = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  DatabaseReference matchRef(String gameId, String matchId) =>
      _db.ref('matches/$gameId/$matchId');

  DatabaseReference ref(String path) => _db.ref(path);

  Future<void> set(String path, Object? value) => _db.ref(path).set(value);

  Future<void> update(String path, Map<String, Object?> value) =>
      _db.ref(path).update(value);

  Future<void> push(String path, Object? value) => _db.ref(path).push().set(value);

  Future<void> remove(String path) => _db.ref(path).remove();

  Stream<DatabaseEvent> onValue(String path) => _db.ref(path).onValue;

  Stream<DatabaseEvent> onChildAdded(String path) => _db.ref(path).onChildAdded;

  Future<DataSnapshot> get(String path) => _db.ref(path).get();

  /// Registers presence for a player in a match. When the client disconnects
  /// (network drop, app kill), the `connected` flag flips to false so the
  /// remaining players can detect the departure and claim the win.
  Future<void> registerPresence(
    String gameId,
    String matchId,
    String uid,
  ) async {
    final presence =
        _db.ref('matches/$gameId/$matchId/presence/$uid');
    await presence.set({'connected': true, 'at': ServerValue.timestamp});
    await presence.onDisconnect().set({
      'connected': false,
      'at': ServerValue.timestamp,
    });
  }

  Future<void> leaveMatch(String gameId, String matchId, String uid) =>
      _db.ref('matches/$gameId/$matchId/presence/$uid').set({
        'connected': false,
        'at': ServerValue.timestamp,
      });

  Stream<DatabaseEvent> presenceStream(String gameId, String matchId) =>
      _db.ref('matches/$gameId/$matchId/presence').onValue;
}
