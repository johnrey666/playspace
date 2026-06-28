import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../shared/models/game_catalog.dart';
import '../../shared/models/game_result_model.dart';
import '../../shared/models/post_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/services/firestore_service.dart';

/// Posts the local player's result to Firestore. This auto-appends to the
/// activity feed (see [FirestoreService.postGameResult]).
Future<void> postGameResult({
  required FirestoreService fs,
  required GameInfo game,
  required String uid,
  required int score,
  required int rank,
  required int totalPlayers,
}) {
  return fs.postGameResult(GameResultModel(
    id: '',
    uid: uid,
    gameId: game.id,
    gameName: game.name,
    score: score,
    rank: rank,
    totalPlayers: totalPlayers,
    createdAt: DateTime.now(),
  ));
}

class WinnerScreen extends StatefulWidget {
  const WinnerScreen({
    super.key,
    required this.game,
    required this.didWin,
    required this.rank,
    required this.totalPlayers,
    required this.score,
    this.rankings = const [],
    this.subtitle,
  });

  final GameInfo game;
  final bool didWin;
  final int rank;
  final int totalPlayers;
  final int score;
  final List<ScoreLine> rankings;
  final String? subtitle;

  @override
  State<WinnerScreen> createState() => _WinnerScreenState();
}

class _WinnerScreenState extends State<WinnerScreen> {
  bool _shared = false;
  bool _sharing = false;

  GameInfo get game => widget.game;
  bool get didWin => widget.didWin;
  int get rank => widget.rank;
  int get totalPlayers => widget.totalPlayers;
  int get score => widget.score;
  List<ScoreLine> get rankings => widget.rankings;
  String? get subtitle => widget.subtitle;

  Future<void> _shareToProfile() async {
    setState(() => _sharing = true);
    final fs = context.read<FirestoreService>();
    final myUid = context.read<AuthProvider>().uid;
    if (myUid == null) {
      setState(() => _sharing = false);
      return;
    }
    try {
      await fs.createPost(PostModel(
        id: '',
        uid: myUid,
        type: PostType.game,
        createdAt: DateTime.now(),
        gameId: game.id,
        gameName: game.name,
        score: score,
        rank: rank,
        totalPlayers: totalPlayers,
        isWin: didWin,
      ));
      if (mounted) setState(() => _shared = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not share. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Icon(
                didWin ? Icons.emoji_events_rounded : Icons.flag_rounded,
                size: 96,
                color: didWin ? Colors.amber : Theme.of(context).colorScheme.outline,
              )
                  .animate()
                  .scale(duration: 500.ms, curve: Curves.elasticOut)
                  .then()
                  .shake(hz: 2, duration: 400.ms),
              const SizedBox(height: 16),
              Text(
                didWin ? 'Victory!' : 'Good game!',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 4),
              Text(
                subtitle ?? 'You finished #$rank of $totalPlayers · $score pts',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              if (rankings.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: rankings.length,
                    itemBuilder: (context, i) {
                      final line = rankings[i];
                      return Card(
                        child: ListTile(
                          leading: Text('#${i + 1}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16)),
                          title: Text(line.name),
                          trailing: Text('${line.score}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: (100 * i).ms)
                          .slideX(begin: 0.2, end: 0);
                    },
                  ),
                )
              else
                const Spacer(),
              OutlinedButton.icon(
                onPressed: _shared || _sharing ? null : _shareToProfile,
                icon: _sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_shared
                        ? Icons.check_circle_rounded
                        : Icons.ios_share_rounded),
                label: Text(_shared ? 'Shared to profile' : 'Share to profile'),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => Navigator.of(context)
                    .popUntil((route) => route.isFirst),
                child: const Text('Back to Home'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class ScoreLine {
  final String name;
  final int score;
  const ScoreLine(this.name, this.score);
}

/// A single player's live entry in a score-based multiplayer match.
class ScoreEntry {
  final String uid;
  final String name;
  final int score;
  final bool done;
  const ScoreEntry(this.uid, this.name, this.score, this.done);

  factory ScoreEntry.fromMap(String uid, Map value) => ScoreEntry(
        uid,
        value['name']?.toString() ?? 'Player',
        (value['score'] as num?)?.toInt() ?? 0,
        value['done'] == true,
      );
}

/// Parses the `$base/scores` node (uid -> {name, score, done}) into a sorted
/// (highest first) list of entries.
List<ScoreEntry> parseScoreboard(Object? value) {
  if (value is! Map) return [];
  final list = <ScoreEntry>[];
  value.forEach((uid, data) {
    if (data is Map) list.add(ScoreEntry.fromMap(uid.toString(), data));
  });
  list.sort((a, b) => b.score.compareTo(a.score));
  return list;
}

/// Live scoreboard panel shown during score-based multiplayer games.
class LiveScoreboard extends StatelessWidget {
  const LiveScoreboard({super.key, required this.entries, required this.myUid});

  final List<ScoreEntry> entries;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: List.generate(entries.length, (i) {
        final e = entries[i];
        final isMe = e.uid == myUid;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isMe
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text('${i + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              Expanded(
                child: Text(isMe ? 'You' : e.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight:
                            isMe ? FontWeight.w800 : FontWeight.w600)),
              ),
              if (e.done)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.check_circle_rounded,
                      size: 16, color: Colors.green),
                ),
              Text('${e.score}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
        );
      }),
    );
  }
}

/// Animated circular countdown used at the start of rounds.
class CountdownRing extends StatelessWidget {
  const CountdownRing({
    super.key,
    required this.value,
    required this.seconds,
    this.color,
  });

  final double value; // 0..1 remaining
  final int seconds;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: 5,
            backgroundColor: c.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(c),
          ),
          Text('$seconds',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ],
      ),
    );
  }
}

/// Shows a banner + awards the win when an opponent leaves mid-game.
class OpponentLeftBanner extends StatelessWidget {
  const OpponentLeftBanner({super.key, this.message = 'Opponent left'});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.red.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(message,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.red, fontWeight: FontWeight.w700)),
    );
  }
}
