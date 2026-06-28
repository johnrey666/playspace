import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/game_catalog.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/services/realtime_db_service.dart';
import '../game_common.dart';
import '../lobby_player.dart';
import 'math_questions.dart';

/// Rapid mental-math race for 3-8 players. Everyone answers the same seeded
/// set of questions; faster correct answers score more. Scores sync live and a
/// player finishes independently, mirroring the TypeRacer flow.
class MathMastersScreen extends StatefulWidget {
  const MathMastersScreen({
    super.key,
    required this.matchId,
    required this.players,
    required this.myUid,
  });

  final String matchId;
  final List<LobbyPlayer> players;
  final String myUid;

  @override
  State<MathMastersScreen> createState() => _MathMastersScreenState();
}

class _MathMastersScreenState extends State<MathMastersScreen> {
  static const _game = GameCatalog.mathMasters;
  static const _questionCount = 10;
  static const _roundMs = 8000;

  late final RealtimeDbService _rtdb = context.read<RealtimeDbService>();
  late final FirestoreService _fs = context.read<FirestoreService>();
  late final String _base = 'matches/math_masters/${widget.matchId}';
  late final List<MathQuestion> _questions = buildMathQuestions(
    widget.matchId.codeUnits.fold<int>(0, (a, b) => a + b),
    _questionCount,
  );
  late final String _myName = widget.players
      .firstWhere((p) => p.uid == widget.myUid,
          orElse: () => LobbyPlayer(uid: widget.myUid, name: 'You'))
      .name;

  StreamSubscription? _scoreSub;
  Timer? _ticker;

  List<ScoreEntry> _board = [];
  int _index = 0;
  int _myScore = 0;
  int _timeLeftMs = _roundMs;
  int? _selected;
  bool _revealed = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _rtdb.registerPresence('math_masters', widget.matchId, widget.myUid);
    _writeScore();
    _scoreSub = _rtdb.onValue('$_base/scores').listen((event) {
      if (mounted) {
        setState(() => _board = parseScoreboard(event.snapshot.value));
      }
    });
    _startRound();
  }

  void _writeScore({bool done = false}) {
    _rtdb.set('$_base/scores/${widget.myUid}', {
      'name': _myName,
      'score': _myScore,
      'done': done,
    });
  }

  void _startRound() {
    _selected = null;
    _revealed = false;
    _timeLeftMs = _roundMs;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => _timeLeftMs -= 100);
      if (_timeLeftMs <= 0) _lock(null);
    });
    setState(() {});
  }

  void _answer(int i) {
    if (_revealed) return;
    setState(() => _selected = i);
    _lock(i);
  }

  void _lock(int? choice) {
    if (_revealed) return;
    _ticker?.cancel();
    final correct = choice == _questions[_index].correctIndex;
    final speedBonus = (_timeLeftMs / _roundMs * 100).clamp(0, 100).round();
    setState(() {
      _revealed = true;
      if (correct) _myScore += 100 + speedBonus;
    });
    _writeScore();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (_index < _questionCount - 1) {
        setState(() => _index++);
        _startRound();
      } else {
        _finish();
      }
    });
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    _ticker?.cancel();
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
    _ticker?.cancel();
    _scoreSub?.cancel();
    _rtdb.leaveMatch('math_masters', widget.matchId, widget.myUid);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_index];
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('MathMasters · ${_index + 1}/$_questionCount'),
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
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CountdownRing(
                    value: _timeLeftMs / _roundMs,
                    seconds: (_timeLeftMs / 1000).ceil().clamp(0, 8),
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    q.prompt,
                    style: const TextStyle(
                        fontSize: 44, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 28),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.2,
                    children: List.generate(q.options.length, (i) {
                      Color? bg;
                      if (_revealed) {
                        if (i == q.correctIndex) {
                          bg = Colors.green;
                        } else if (i == _selected) {
                          bg = Colors.red;
                        }
                      }
                      return FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          backgroundColor: bg,
                          foregroundColor: bg != null ? Colors.white : null,
                        ),
                        onPressed: _revealed ? null : () => _answer(i),
                        child: Text('${q.options[i]}',
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w800)),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
