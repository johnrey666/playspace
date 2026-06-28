import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/challenge_model.dart';
import '../../../shared/models/game_catalog.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/providers/friends_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/services/firestore_service.dart';
import '../../games/challenge_flow.dart';

class ChallengeBanner extends StatefulWidget {
  const ChallengeBanner({super.key});

  @override
  State<ChallengeBanner> createState() => _ChallengeBannerState();
}

class _ChallengeBannerState extends State<ChallengeBanner> {
  Timer? _ticker;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    // Drive the live countdown.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int _secondsLeft(ChallengeModel c) {
    final elapsed = DateTime.now().difference(c.createdAt).inSeconds;
    return (FriendsProvider.challengeTtl.inSeconds - elapsed).clamp(0, 999);
  }

  @override
  Widget build(BuildContext context) {
    final challenge = context.watch<FriendsProvider>().topChallenge;
    if (challenge == null) return const SizedBox.shrink();
    final game = GameCatalog.byId(challenge.gameId);
    final fs = context.read<FirestoreService>();
    final secondsLeft = _secondsLeft(challenge);

    return FutureBuilder<UserModel?>(
      future: fs.getUser(challenge.fromUid),
      builder: (context, snap) {
        final name = snap.data?.displayName ?? 'A friend';
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: game.colors),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: game.colors.last.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              _Countdown(secondsLeft: secondsLeft, icon: game.icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$name challenged you!',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                    Text('${game.name} · expires in ${secondsLeft}s',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(0, 40),
                ),
                onPressed: _accepting
                    ? null
                    : () => _accept(context, challenge, game),
                child: _accepting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Accept'),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 350.ms)
            .slideY(begin: -0.2, end: 0, curve: Curves.easeOut);
      },
    );
  }

  Future<void> _accept(
      BuildContext context, ChallengeModel challenge, GameInfo game) async {
    setState(() => _accepting = true);
    final fs = context.read<FirestoreService>();
    final me = context.read<UserProvider>().user;
    final challenger = await fs.getUser(challenge.fromUid);
    if (me == null || challenger == null || !context.mounted) {
      if (mounted) setState(() => _accepting = false);
      return;
    }
    await fs.respondToChallenge(challenge.id, ChallengeStatus.accepted,
        matchId: challenge.id);
    if (!context.mounted) return;
    enterChallengeGame(
      context,
      game: game,
      matchId: challenge.id,
      players: challengePlayers(me, challenger),
      myUid: me.uid,
      replace: false,
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.secondsLeft, required this.icon});
  final int secondsLeft;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final progress =
        (secondsLeft / FriendsProvider.challengeTtl.inSeconds).clamp(0.0, 1.0);
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 3,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
          Icon(icon, color: Colors.white, size: 20),
        ],
      ),
    );
  }
}
