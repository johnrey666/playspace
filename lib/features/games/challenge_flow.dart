import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../shared/models/challenge_model.dart';
import '../../shared/models/game_catalog.dart';
import '../../shared/models/user_model.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/avatar_widget.dart';
import 'game_routes.dart';
import 'lobby_player.dart';

/// Builds a deterministic, identically-ordered player list for a 1v1 challenge
/// so both clients agree on who the "host" is (players.first).
List<LobbyPlayer> challengePlayers(UserModel a, UserModel b) {
  final players = [
    LobbyPlayer(uid: a.uid, name: a.displayName, photoUrl: a.photoUrl),
    LobbyPlayer(uid: b.uid, name: b.displayName, photoUrl: b.photoUrl),
  ];
  players.sort((x, y) => x.uid.compareTo(y.uid));
  return players;
}

/// Drops both players straight into the live game screen for [matchId].
void enterChallengeGame(
  BuildContext context, {
  required GameInfo game,
  required String matchId,
  required List<LobbyPlayer> players,
  required String myUid,
  bool replace = true,
}) {
  final route = MaterialPageRoute(
    builder: (_) => buildGameScreen(
      game: game,
      matchId: matchId,
      players: players,
      myUid: myUid,
    ),
  );
  if (replace) {
    Navigator.of(context).pushReplacement(route);
  } else {
    Navigator.of(context).push(route);
  }
}

/// Shown to the challenger after they send a challenge. Waits for the opponent
/// to accept (listening to the challenge doc) and then both players jump into
/// the game at the same time.
class ChallengeWaitScreen extends StatefulWidget {
  const ChallengeWaitScreen({
    super.key,
    required this.game,
    required this.challengeId,
    required this.me,
    required this.opponent,
  });

  final GameInfo game;
  final String challengeId;
  final UserModel me;
  final UserModel opponent;

  @override
  State<ChallengeWaitScreen> createState() => _ChallengeWaitScreenState();
}

class _ChallengeWaitScreenState extends State<ChallengeWaitScreen> {
  late final FirestoreService _fs = context.read<FirestoreService>();
  StreamSubscription? _sub;
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    _sub = _fs.challengeStream(widget.challengeId).listen((challenge) {
      if (challenge == null || _entered || !mounted) return;
      if (challenge.status == ChallengeStatus.accepted) {
        _entered = true;
        enterChallengeGame(
          context,
          game: widget.game,
          matchId: widget.challengeId,
          players: challengePlayers(widget.me, widget.opponent),
          myUid: widget.me.uid,
        );
      } else if (challenge.status == ChallengeStatus.declined) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '${widget.opponent.displayName} declined the challenge.')));
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: game.colors),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: game.colors.last.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Icon(game.icon, color: Colors.white, size: 56),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AvatarWidget(
                      photoUrl: widget.me.photoUrl,
                      displayName: widget.me.displayName,
                      size: 64),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('VS',
                        style: context.texts.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900)),
                  ),
                  AvatarWidget(
                      photoUrl: widget.opponent.photoUrl,
                      displayName: widget.opponent.displayName,
                      size: 64),
                ],
              ),
              const SizedBox(height: 28),
              Text('Waiting for ${widget.opponent.displayName} to accept…',
                  textAlign: TextAlign.center,
                  style: context.texts.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('${game.name} · the match starts the moment they join',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: context.colors.onSurfaceVariant)),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel challenge'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
