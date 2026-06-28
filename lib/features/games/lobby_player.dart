class LobbyPlayer {
  final String uid;
  final String name;
  final String? photoUrl;

  const LobbyPlayer({required this.uid, required this.name, this.photoUrl});

  factory LobbyPlayer.fromMap(String uid, Map value) => LobbyPlayer(
        uid: uid,
        name: value['name']?.toString() ?? 'Player',
        photoUrl: value['photoUrl']?.toString(),
      );
}
