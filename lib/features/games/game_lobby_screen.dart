import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/models/game_catalog.dart';
import '../../shared/models/game_result_model.dart';
import '../../shared/models/user_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/matchmaking_service.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/avatar_widget.dart';
import '../../shared/widgets/shimmer_loader.dart';
import 'challenge_flow.dart';
import 'waiting_room_screen.dart';

class GameLobbyScreen extends StatefulWidget {
  const GameLobbyScreen({super.key, required this.game, this.directMatchId});

  final GameInfo game;
  final String? directMatchId;

  @override
  State<GameLobbyScreen> createState() => _GameLobbyScreenState();
}

class _GameLobbyScreenState extends State<GameLobbyScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.directMatchId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _joinDirect());
    }
  }

  UserModel get _me => context.read<UserProvider>().user!;

  Future<void> _joinDirect() async {
    final mm = context.read<MatchmakingService>();
    await mm.joinMatch(
      gameId: widget.game.id,
      matchId: widget.directMatchId!,
      uid: _me.uid,
      name: _me.displayName,
      photoUrl: _me.photoUrl,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => WaitingRoomScreen(
        game: widget.game,
        matchId: widget.directMatchId!,
        isHost: false,
      ),
    ));
  }

  Future<void> _quickMatch() async {
    setState(() => _busy = true);
    try {
      final mm = context.read<MatchmakingService>();
      final handle = await mm.joinRandom(
        gameId: widget.game.id,
        uid: _me.uid,
        name: _me.displayName,
        photoUrl: _me.photoUrl,
        minPlayers: widget.game.minPlayers,
        maxPlayers: widget.game.maxPlayers,
      );
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => WaitingRoomScreen(
          game: widget.game,
          matchId: handle.matchId,
          isHost: handle.isHost,
        ),
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Matchmaking failed. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _challengeFriend() async {
    final friendIds = context.read<UserProvider>().friendIds;
    final fs = context.read<FirestoreService>();
    if (friendIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add friends to challenge them!')),
      );
      return;
    }
    final friends = await fs.getUsers(friendIds);
    if (!mounted) return;
    final friend = await showModalBottomSheet<UserModel>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: friends
            .map((f) => ListTile(
                  leading: AvatarWidget(
                      photoUrl: f.photoUrl,
                      displayName: f.displayName,
                      isOnline: f.isPresent),
                  title: Text(f.displayName),
                  subtitle: Text('@${f.username}'),
                  onTap: () => Navigator.pop(context, f),
                ))
            .toList(),
      ),
    );
    if (friend == null || !mounted) return;

    // The challenge doc id is reused as the match id, so when the friend
    // accepts, both clients drop straight into the same live game.
    final challengeId = await fs.sendChallenge(
      fromUid: _me.uid,
      toUid: friend.uid,
      gameId: widget.game.id,
    );
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChallengeWaitScreen(
        game: widget.game,
        challengeId: challengeId,
        me: _me,
        opponent: friend,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    if (widget.directMatchId != null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(game.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(game.icon, color: Colors.white, size: 40),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(game.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(game.description,
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.group_rounded,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              game.isOneVsOne
                                  ? '1v1'
                                  : '${game.minPlayers}-${game.maxPlayers} players',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Quick Match',
            icon: Icons.flash_on_rounded,
            loading: _busy,
            onPressed: _quickMatch,
          ),
          const SizedBox(height: 12),
          AppOutlinedButton(
            label: 'Challenge a Friend',
            icon: Icons.person_add_alt_1_rounded,
            onPressed: _challengeFriend,
          ),
          const SizedBox(height: 24),
          Text('Leaderboard',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _GameLeaderboard(gameId: game.id),
        ],
      ),
    );
  }
}

class _GameLeaderboard extends StatelessWidget {
  const _GameLeaderboard({required this.gameId});
  final String gameId;

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    final myUid = context.watch<AuthProvider>().uid;
    final userProvider = context.watch<UserProvider>();
    return StreamBuilder<List<GameResultModel>>(
      stream: fs.gameLeaderboard(gameId),
      builder: (context, snap) {
        if (!snap.hasData) return const FeedSkeleton(count: 3);
        final results = snap.data!;
        if (results.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No scores yet. Be the first!')),
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          userProvider.ensureUsers(results.map((r) => r.uid));
        });
        return Column(
          children: List.generate(results.length, (i) {
            final r = results[i];
            final author = userProvider.cached(r.uid);
            return ListTile(
              dense: true,
              leading: Text('#${i + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              title: Row(
                children: [
                  AvatarWidget(
                      photoUrl: author?.photoUrl,
                      displayName: author?.displayName ?? '',
                      size: 30),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(author?.displayName ?? 'Player',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: r.uid == myUid
                                  ? FontWeight.w800
                                  : FontWeight.normal))),
                ],
              ),
              trailing: Text('${r.score}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            );
          }),
        );
      },
    );
  }
}
