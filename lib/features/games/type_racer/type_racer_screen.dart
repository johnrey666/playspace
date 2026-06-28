import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/game_catalog.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/services/realtime_db_service.dart';
import '../game_common.dart';
import '../lobby_player.dart';

const List<String> _paragraphs = [
  'The quick brown fox jumps over the lazy dog while the sun sets behind the distant hills.',
  'Coding is like solving a puzzle where every piece must fit perfectly to reveal the bigger picture.',
  'A journey of a thousand miles begins with a single step taken with courage and determination.',
  'Bright ideas often arrive when we least expect them, sparking creativity in unexpected moments.',
];

class TypeRacerScreen extends StatefulWidget {
  const TypeRacerScreen({
    super.key,
    required this.matchId,
    required this.players,
    required this.myUid,
  });

  final String matchId;
  final List<LobbyPlayer> players;
  final String myUid;

  @override
  State<TypeRacerScreen> createState() => _TypeRacerScreenState();
}

class _TypeRacerScreenState extends State<TypeRacerScreen> {
  static const _game = GameCatalog.typeRacer;

  late final RealtimeDbService _rtdb = context.read<RealtimeDbService>();
  late final FirestoreService _fs = context.read<FirestoreService>();
  late final String _base = 'matches/type_racer/${widget.matchId}';
  late final String _target = _paragraphs[
      widget.matchId.codeUnits.fold<int>(0, (a, b) => a + b) %
          _paragraphs.length];

  final _controller = TextEditingController();
  final _focus = FocusNode();
  StreamSubscription? _progressSub;
  StreamSubscription? _presenceSub;
  DateTime? _startTime;

  Map<String, _PlayerProgress> _progress = {};
  int _wpm = 0;
  double _accuracy = 1;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _rtdb.registerPresence('type_racer', widget.matchId, widget.myUid);
    final me = widget.players.firstWhere((p) => p.uid == widget.myUid,
        orElse: () => LobbyPlayer(uid: widget.myUid, name: 'You'));
    _rtdb.set('$_base/progress/${widget.myUid}', {
      'name': me.name,
      'progress': 0,
      'wpm': 0,
      'finished': false,
    });
    _progressSub = _rtdb.onValue('$_base/progress').listen((event) {
      final value = event.snapshot.value;
      if (value is Map && mounted) {
        setState(() {
          _progress = value.map((k, v) =>
              MapEntry(k.toString(), _PlayerProgress.fromMap(v as Map)));
        });
      }
    });
    _presenceSub =
        _rtdb.presenceStream('type_racer', widget.matchId).listen((_) {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _onChanged(String typed) {
    if (_finished) return;
    var correct = 0;
    for (var i = 0; i < typed.length && i < _target.length; i++) {
      if (typed[i] == _target[i]) {
        correct++;
      } else {
        break; // progress only counts the correct leading run
      }
    }
    final progress = correct / _target.length;
    final elapsedMin =
        DateTime.now().difference(_startTime!).inMilliseconds / 60000.0;
    final words = correct / 5.0;
    final wpm = elapsedMin > 0 ? (words / elapsedMin).round() : 0;
    final accuracy =
        typed.isEmpty ? 1.0 : (correct / typed.length).clamp(0.0, 1.0);

    setState(() {
      _wpm = wpm;
      _accuracy = accuracy;
    });
    _rtdb.update('$_base/progress/${widget.myUid}', {
      'progress': progress,
      'wpm': wpm,
    });

    if (correct >= _target.length) _finish();
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    await _rtdb.update('$_base/progress/${widget.myUid}', {
      'progress': 1,
      'wpm': _wpm,
      'finished': true,
    });
    // Atomic finish-order counter determines rank.
    final result = await _rtdb
        .ref('$_base/finishCount')
        .runTransaction((current) {
      final n = ((current as num?)?.toInt() ?? 0) + 1;
      return Transaction.success(n);
    });
    final rank = (result.snapshot.value as num?)?.toInt() ?? 1;

    await postGameResult(
      fs: _fs,
      game: _game,
      uid: widget.myUid,
      score: _wpm,
      rank: rank,
      totalPlayers: widget.players.length,
    );
    if (!mounted) return;
    final rankings = _progress.values.toList()
      ..sort((a, b) => b.wpm.compareTo(a.wpm));
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => WinnerScreen(
        game: _game,
        didWin: rank == 1,
        rank: rank,
        totalPlayers: widget.players.length,
        score: _wpm,
        subtitle: 'You finished #$rank · $_wpm WPM',
        rankings:
            rankings.map((p) => ScoreLine(p.name, p.wpm)).toList(),
      ),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _progressSub?.cancel();
    _presenceSub?.cancel();
    _rtdb.leaveMatch('type_racer', widget.matchId, widget.myUid);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typed = _controller.text;
    return Scaffold(
      appBar: AppBar(
        title: const Text('TypeRacer'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._progress.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            e.key == widget.myUid
                                ? 'You'
                                : e.value.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${e.value.wpm} WPM'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: e.value.progress,
                        minHeight: 10,
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: RichText(
              text: TextSpan(
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(height: 1.5),
                children: List.generate(_target.length, (i) {
                  Color color = Theme.of(context).colorScheme.onSurfaceVariant;
                  if (i < typed.length) {
                    color = (i < _target.length && typed[i] == _target[i])
                        ? Colors.green
                        : Colors.red;
                  }
                  return TextSpan(text: _target[i], style: TextStyle(color: color));
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            focusNode: _focus,
            maxLines: 3,
            enabled: !_finished,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: 'Start typing here…',
              helperText: 'WPM $_wpm · Accuracy ${(_accuracy * 100).round()}%',
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerProgress {
  final String name;
  final double progress;
  final int wpm;
  final bool finished;

  const _PlayerProgress(this.name, this.progress, this.wpm, this.finished);

  factory _PlayerProgress.fromMap(Map m) => _PlayerProgress(
        m['name']?.toString() ?? 'Player',
        ((m['progress'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
        (m['wpm'] as num?)?.toInt() ?? 0,
        m['finished'] == true,
      );
}
