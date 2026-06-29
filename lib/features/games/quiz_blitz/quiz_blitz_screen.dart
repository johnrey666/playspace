import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/game_catalog.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/services/realtime_db_service.dart';
import '../game_common.dart';
import '../lobby_player.dart';
import 'quiz_questions.dart';

class QuizBlitzScreen extends StatefulWidget {
  const QuizBlitzScreen({
    super.key,
    required this.matchId,
    required this.players,
    required this.myUid,
  });

  final String matchId;
  final List<LobbyPlayer> players;
  final String myUid;

  @override
  State<QuizBlitzScreen> createState() => _QuizBlitzScreenState();
}

class _QuizBlitzScreenState extends State<QuizBlitzScreen> {
  static const _rounds = 5;
  static const _roundMs = 15000;
  static const _game = GameCatalog.quizBlitz;

  late final RealtimeDbService _rtdb = context.read<RealtimeDbService>();
  late final FirestoreService _fs = context.read<FirestoreService>();
  late final String _base = 'matches/quiz_blitz/${widget.matchId}';
  late final LobbyPlayer _opponent = widget.players.firstWhere(
    (p) => p.uid != widget.myUid,
    orElse: () => const LobbyPlayer(uid: '__none__', name: 'Opponent'),
  );
  late final List<QuizQuestion> _questions = _pickQuestions();

  StreamSubscription? _scoreSub;
  StreamSubscription? _presenceSub;
  StreamSubscription? _answeredSub;
  Timer? _ticker;

  int _round = 0;
  int _myScore = 0;
  int _oppScore = 0;
  int _timeLeftMs = _roundMs;
  int? _selected;
  bool _revealed = false;
  bool _finished = false;
  bool _opponentLeft = false;
  bool _opponentAnswered = false;
  // Guards so a given round is only advanced once even though both the local
  // lock and the realtime listener can trigger it.
  int _advancedForRound = -1;

  bool get _isSolo => _opponent.uid == '__none__';

  @override
  void initState() {
    super.initState();
    _rtdb.registerPresence('quiz_blitz', widget.matchId, widget.myUid);
    _rtdb.set('$_base/scores/${widget.myUid}', 0);
    _scoreSub = _rtdb.onValue('$_base/scores').listen((event) {
      final value = event.snapshot.value;
      if (value is Map) {
        final opp = value[_opponent.uid];
        if (opp is num && mounted) setState(() => _oppScore = opp.toInt());
      }
    });
    // Round progression is gated on *both* players answering. Each player marks
    // `answered/r{round}/{uid}` and we only move on once every player is in.
    _answeredSub = _rtdb.onValue('$_base/answered').listen(_onAnswered);
    _presenceSub =
        _rtdb.presenceStream('quiz_blitz', widget.matchId).listen((event) {
      final value = event.snapshot.value;
      if (value is Map) {
        final opp = value[_opponent.uid];
        if (opp is Map &&
            opp['connected'] == false &&
            mounted &&
            !_opponentLeft &&
            _opponent.uid != '__none__') {
          setState(() => _opponentLeft = true);
          // End the match right away and award the win.
          _finish();
        }
      }
    });
    _startRound();
  }

  List<QuizQuestion> _pickQuestions() {
    final seed = widget.matchId.codeUnits.fold<int>(0, (a, b) => a + b);
    final indices = List<int>.generate(kQuizBank.length, (i) => i);
    // Deterministic shuffle so both players get the same questions/order.
    for (var i = indices.length - 1; i > 0; i--) {
      final j = (seed * (i + 7)) % (i + 1);
      final tmp = indices[i];
      indices[i] = indices[j];
      indices[j] = tmp;
    }
    return indices.take(_rounds).map((i) => kQuizBank[i]).toList();
  }

  void _startRound() {
    _selected = null;
    _revealed = false;
    _opponentAnswered = false;
    _timeLeftMs = _roundMs;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) return;
      setState(() => _timeLeftMs -= 100);
      if (_timeLeftMs <= 0) _lockAnswer(null);
    });
    setState(() {});
  }

  void _answer(int index) {
    if (_revealed) return;
    setState(() => _selected = index);
    _lockAnswer(index);
  }

  void _lockAnswer(int? choice) {
    if (_revealed) return;
    _ticker?.cancel();
    final correct = choice == _questions[_round].correctIndex;
    final speedBonus = (_timeLeftMs / _roundMs * 100).clamp(0, 100).round();
    final points = correct ? 100 + speedBonus : 0;
    setState(() {
      _revealed = true;
      _myScore += points;
    });
    _rtdb.set('$_base/scores/${widget.myUid}', _myScore);
    // Announce that I've answered this round (non-numeric key so RTDB keeps it
    // as a map rather than collapsing it into an array).
    _rtdb.set('$_base/answered/r$_round/${widget.myUid}', true);
    _maybeAdvance();
  }

  /// Reacts to either player marking themselves answered for the active round.
  void _onAnswered(DatabaseEvent event) {
    final value = event.snapshot.value;
    if (value is! Map) return;
    final roundData = value['r$_round'];
    final answered = <String>{};
    if (roundData is Map) {
      roundData.forEach((k, v) {
        if (v == true) answered.add(k.toString());
      });
    }
    final oppAnswered = answered.contains(_opponent.uid);
    if (mounted && oppAnswered != _opponentAnswered) {
      setState(() => _opponentAnswered = oppAnswered);
    } else {
      _opponentAnswered = oppAnswered;
    }
    _maybeAdvance();
  }

  /// Advances to the next round (or finishes) only once *both* players have
  /// locked their answer for the current round. Keeps the two clients on the
  /// exact same question the whole game.
  void _maybeAdvance() {
    if (_advancedForRound == _round || !_revealed) return;
    final bothAnswered = _isSolo || _opponentAnswered;
    if (!bothAnswered) return;
    _advancedForRound = _round;
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_round < _rounds - 1) {
        setState(() => _round++);
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

    final iWin = _opponentLeft || _myScore >= _oppScore;
    final rank = iWin ? 1 : 2;
    await postGameResult(
      fs: _fs,
      game: _game,
      uid: widget.myUid,
      score: _myScore,
      rank: rank,
      totalPlayers: 2,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => WinnerScreen(
        game: _game,
        didWin: iWin,
        rank: rank,
        totalPlayers: 2,
        score: _myScore,
        subtitle: _opponentLeft
            ? 'Opponent left — you win!'
            : 'You $_myScore · ${_opponent.name} $_oppScore',
        rankings: [
          ScoreLine('You', _myScore),
          ScoreLine(_opponent.name, _oppScore),
        ]..sort((a, b) => b.score.compareTo(a.score)),
      ),
    ));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _scoreSub?.cancel();
    _presenceSub?.cancel();
    _answeredSub?.cancel();
    _rtdb.leaveMatch('quiz_blitz', widget.matchId, widget.myUid);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_round];
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Round ${_round + 1}/$_rounds'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          if (_opponentLeft) const OpponentLeftBanner(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _ScorePill(label: 'You', score: _myScore, highlight: true),
                const SizedBox(width: 12),
                CountdownRing(
                  value: _timeLeftMs / _roundMs,
                  seconds: (_timeLeftMs / 1000).ceil().clamp(0, 15),
                ),
                const SizedBox(width: 12),
                _ScorePill(label: _opponent.name, score: _oppScore),
              ],
            ),
          ),
          if (_revealed && !_isSolo && !_opponentAnswered)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text('Waiting for ${_opponent.name} to answer…',
                      style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    q.question,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 32),
                  ...List.generate(q.options.length, (i) {
                    Color? bg;
                    if (_revealed) {
                      if (i == q.correctIndex) {
                        bg = Colors.green;
                      } else if (i == _selected) {
                        bg = Colors.red;
                      }
                    } else if (i == _selected) {
                      bg = scheme.primaryContainer;
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            backgroundColor: bg,
                            foregroundColor:
                                bg != null && bg != scheme.primaryContainer
                                    ? Colors.white
                                    : null,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                          ),
                          onPressed: _revealed ? null : () => _answer(i),
                          child: Text(q.options[i],
                              style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill(
      {required this.label, required this.score, this.highlight = false});
  final String label;
  final int score;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: highlight
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
            Text('$score',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
