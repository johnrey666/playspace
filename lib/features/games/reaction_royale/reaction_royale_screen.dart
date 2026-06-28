import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/game_catalog.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/services/realtime_db_service.dart';
import '../game_common.dart';
import '../lobby_player.dart';

/// Reflex game for 3-8 players. Across several rounds the panel waits a random
/// (seeded, identical for everyone) delay then flashes green — tap as fast as
/// you can. Faster reactions score more; tapping too early scores zero for the
/// round. Scores sync live.
class ReactionRoyaleScreen extends StatefulWidget {
  const ReactionRoyaleScreen({
    super.key,
    required this.matchId,
    required this.players,
    required this.myUid,
  });

  final String matchId;
  final List<LobbyPlayer> players;
  final String myUid;

  @override
  State<ReactionRoyaleScreen> createState() => _ReactionRoyaleScreenState();
}

enum _Phase { intro, waiting, go, tapped, tooSoon }

class _ReactionRoyaleScreenState extends State<ReactionRoyaleScreen> {
  static const _game = GameCatalog.reactionRoyale;
  static const _rounds = 5;

  late final RealtimeDbService _rtdb = context.read<RealtimeDbService>();
  late final FirestoreService _fs = context.read<FirestoreService>();
  late final String _base = 'matches/reaction_royale/${widget.matchId}';
  late final Random _rng =
      Random(widget.matchId.codeUnits.fold<int>(0, (a, b) => a + b));
  late final String _myName = widget.players
      .firstWhere((p) => p.uid == widget.myUid,
          orElse: () => LobbyPlayer(uid: widget.myUid, name: 'You'))
      .name;

  StreamSubscription? _scoreSub;
  Timer? _greenTimer;

  List<ScoreEntry> _board = [];
  int _round = 0;
  int _myScore = 0;
  int _lastReactionMs = 0;
  _Phase _phase = _Phase.intro;
  DateTime? _greenAt;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _rtdb.registerPresence('reaction_royale', widget.matchId, widget.myUid);
    _writeScore();
    _scoreSub = _rtdb.onValue('$_base/scores').listen((event) {
      if (mounted) {
        setState(() => _board = parseScoreboard(event.snapshot.value));
      }
    });
    _beginRound();
  }

  void _writeScore({bool done = false}) {
    _rtdb.set('$_base/scores/${widget.myUid}', {
      'name': _myName,
      'score': _myScore,
      'done': done,
    });
  }

  void _beginRound() {
    _greenTimer?.cancel();
    setState(() => _phase = _Phase.waiting);
    // Identical delay for every player this round (seeded).
    final delayMs = 1500 + _rng.nextInt(3500);
    _greenTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.go;
        _greenAt = DateTime.now();
      });
    });
  }

  void _onTap() {
    switch (_phase) {
      case _Phase.waiting:
        // Jumped the gun.
        _greenTimer?.cancel();
        setState(() => _phase = _Phase.tooSoon);
        _afterRound();
        break;
      case _Phase.go:
        final ms = DateTime.now().difference(_greenAt!).inMilliseconds;
        _lastReactionMs = ms;
        final points = (1000 - ms).clamp(50, 1000);
        setState(() {
          _myScore += points;
          _phase = _Phase.tapped;
        });
        _writeScore();
        _afterRound();
        break;
      default:
        break;
    }
  }

  void _afterRound() {
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      if (_round < _rounds - 1) {
        setState(() => _round++);
        _beginRound();
      } else {
        _finish();
      }
    });
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    _greenTimer?.cancel();
    _writeScore(done: true);

    final board = parseScoreboard((await _rtdb.get('$_base/scores')).value);
    final rank = 1 + board.where((e) => e.score > _myScore).length;

    await postGameResult(
      fs: _fs,
      game: _game,
      uid: widget.myUid,
      score: _myScore,
      rank: rank,
      totalPlayers: widget.players.length,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => WinnerScreen(
        game: _game,
        didWin: rank == 1,
        rank: rank,
        totalPlayers: widget.players.length,
        score: _myScore,
        subtitle: 'You scored $_myScore · #$rank of ${widget.players.length}',
        rankings: board
            .map((e) =>
                ScoreLine(e.uid == widget.myUid ? 'You' : e.name, e.score))
            .toList(),
      ),
    ));
  }

  @override
  void dispose() {
    _greenTimer?.cancel();
    _scoreSub?.cancel();
    _rtdb.leaveMatch('reaction_royale', widget.matchId, widget.myUid);
    super.dispose();
  }

  ({Color color, String title, String subtitle}) get _panel {
    switch (_phase) {
      case _Phase.intro:
        return (
          color: const Color(0xFF334155),
          title: 'Get ready…',
          subtitle: 'Tap the moment it turns green'
        );
      case _Phase.waiting:
        return (
          color: const Color(0xFFDC2626),
          title: 'Wait for it…',
          subtitle: "Don't tap yet!"
        );
      case _Phase.go:
        return (color: const Color(0xFF16A34A), title: 'TAP!', subtitle: '');
      case _Phase.tapped:
        return (
          color: const Color(0xFF2563EB),
          title: '$_lastReactionMs ms',
          subtitle: 'Nice reflexes!'
        );
      case _Phase.tooSoon:
        return (
          color: const Color(0xFF9333EA),
          title: 'Too soon!',
          subtitle: 'No points this round'
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _panel;
    return Scaffold(
      appBar: AppBar(
        title: Text('ReactionRoyale · Round ${_round + 1}/$_rounds'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: LiveScoreboard(entries: _board, myUid: widget.myUid),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: _onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: p.color,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 44,
                            fontWeight: FontWeight.w900),
                      ),
                      if (p.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(p.subtitle,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 16)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
