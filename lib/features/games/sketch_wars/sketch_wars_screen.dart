import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/game_catalog.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/services/realtime_db_service.dart';
import '../game_common.dart';
import '../lobby_player.dart';
import 'sketch_words.dart';

class SketchWarsScreen extends StatefulWidget {
  const SketchWarsScreen({
    super.key,
    required this.matchId,
    required this.players,
    required this.myUid,
  });

  final String matchId;
  final List<LobbyPlayer> players;
  final String myUid;

  @override
  State<SketchWarsScreen> createState() => _SketchWarsScreenState();
}

class _SketchWarsScreenState extends State<SketchWarsScreen> {
  static const _game = GameCatalog.sketchWars;
  static const _totalRounds = 8;
  static const _roundSeconds = 70;

  late final RealtimeDbService _rtdb = context.read<RealtimeDbService>();
  late final FirestoreService _fs = context.read<FirestoreService>();
  late final String _base = 'matches/sketch_wars/${widget.matchId}';
  late final bool _isHost = widget.players.first.uid == widget.myUid;

  final _palette = const [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.brown,
  ];

  StreamSubscription? _stateSub;
  StreamSubscription? _strokeSub;
  StreamSubscription? _guessSub;
  Timer? _roundTimer;

  Map<String, dynamic>? _state;
  List<_Stroke> _strokes = [];
  List<_Guess> _guesses = [];
  _Stroke? _current;
  Color _color = Colors.black;
  double _width = 4;
  bool _eraser = false;
  int _listeningRound = -1;
  bool _finished = false;
  final _guessController = TextEditingController();

  int get _round => (_state?['round'] as num?)?.toInt() ?? 0;
  int get _drawerIndex => (_state?['drawerIndex'] as num?)?.toInt() ?? 0;
  String get _drawerUid => widget.players[_drawerIndex % widget.players.length].uid;
  bool get _isDrawer => _drawerUid == widget.myUid;
  String get _word => _state?['word']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _rtdb.registerPresence('sketch_wars', widget.matchId, widget.myUid);
    _stateSub = _rtdb.onValue('$_base/state').listen(_onState);
  }

  void _onState(DatabaseEvent event) {
    final value = event.snapshot.value;
    if (value == null) {
      if (_isHost) _initGame();
      return;
    }
    if (value is! Map) return;
    setState(() => _state = Map<String, dynamic>.from(value));

    if (_state!['status'] == 'over') {
      _finish();
      return;
    }
    if (_round != _listeningRound) {
      _listeningRound = _round;
      _subscribeRound(_round);
      if (_isHost) _startRoundTimer();
    }
  }

  Future<void> _initGame() async {
    await _rtdb.set('$_base/state', {
      'status': 'playing',
      'round': 0,
      'drawerIndex': 0,
      'word': pickSketchWord(widget.matchId.hashCode),
      'scores': {for (final p in widget.players) p.uid: 0},
      'guessedCount': 0,
    });
  }

  void _subscribeRound(int round) {
    _strokeSub?.cancel();
    _guessSub?.cancel();
    setState(() {
      _strokes = [];
      _guesses = [];
      _current = null;
    });
    _strokeSub =
        _rtdb.onValue('$_base/rounds/$round/strokes').listen((event) {
      final value = event.snapshot.value;
      final list = <_Stroke>[];
      if (value is Map) {
        final entries = value.entries.toList()
          ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
        for (final e in entries) {
          list.add(_Stroke.fromMap(e.value as Map));
        }
      }
      if (mounted) setState(() => _strokes = list);
    });
    _guessSub = _rtdb.onValue('$_base/rounds/$round/guesses').listen((event) {
      final value = event.snapshot.value;
      final list = <_Guess>[];
      if (value is Map) {
        final entries = value.entries.toList()
          ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
        for (final e in entries) {
          list.add(_Guess.fromMap(e.value as Map));
        }
      }
      if (mounted) setState(() => _guesses = list);
    });
  }

  void _startRoundTimer() {
    _roundTimer?.cancel();
    _roundTimer = Timer(const Duration(seconds: _roundSeconds), _nextRound);
  }

  Future<void> _nextRound() async {
    if (!_isHost || _state == null) return;
    final next = _round + 1;
    final state = Map<String, dynamic>.from(_state!);
    if (next >= _totalRounds) {
      state['status'] = 'over';
      await _rtdb.set('$_base/state', state);
      return;
    }
    state['round'] = next;
    state['drawerIndex'] = next % widget.players.length;
    state['word'] = pickSketchWord(widget.matchId.hashCode + next * 31);
    state['guessedCount'] = 0;
    await _rtdb.set('$_base/state', state);
  }

  // ---- Drawing ----
  void _onPanStart(Offset p, Size size) {
    if (!_isDrawer) return;
    _current = _Stroke(
      color: _eraser ? 0xFFFFFFFF : _color.toARGB32(),
      width: _eraser ? 18 : _width,
      points: [p.dx / size.width, p.dy / size.height],
    );
    setState(() {});
  }

  void _onPanUpdate(Offset p, Size size) {
    if (!_isDrawer || _current == null) return;
    setState(() {
      _current!.points.add(p.dx / size.width);
      _current!.points.add(p.dy / size.height);
    });
  }

  void _onPanEnd() {
    if (!_isDrawer || _current == null) return;
    _rtdb.push('$_base/rounds/$_round/strokes', _current!.toMap());
    _current = null;
  }

  Future<void> _clearCanvas() async {
    if (!_isDrawer) return;
    await _rtdb.remove('$_base/rounds/$_round/strokes');
  }

  // ---- Guessing ----
  Future<void> _submitGuess() async {
    final text = _guessController.text.trim();
    if (text.isEmpty || _isDrawer) return;
    _guessController.clear();
    final me = widget.players.firstWhere((p) => p.uid == widget.myUid,
        orElse: () => LobbyPlayer(uid: widget.myUid, name: 'You'));
    final alreadyGuessed = _guesses
        .any((g) => g.uid == widget.myUid && g.correct);
    final correct =
        !alreadyGuessed && text.toLowerCase() == _word.toLowerCase();

    await _rtdb.push('$_base/rounds/$_round/guesses', {
      'uid': widget.myUid,
      'name': me.name,
      'text': correct ? '' : text,
      'correct': correct,
    });

    if (correct) {
      final scores = Map<String, dynamic>.from(
          (_state!['scores'] as Map?) ?? {});
      final guesserPts = 100 - (_guesses.length * 5);
      scores[widget.myUid] =
          ((scores[widget.myUid] as num?)?.toInt() ?? 0) +
              guesserPts.clamp(20, 100);
      scores[_drawerUid] =
          ((scores[_drawerUid] as num?)?.toInt() ?? 0) + 30;
      await _rtdb.update('$_base/state', {'scores': scores});

      // If everyone guessed, host moves on.
      final guessers = widget.players.length - 1;
      final correctCount = _guesses.where((g) => g.correct).length + 1;
      if (_isHost && correctCount >= guessers) _nextRound();
    }
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    _roundTimer?.cancel();
    final scores = Map<String, dynamic>.from((_state!['scores'] as Map?) ?? {});
    final myScore = (scores[widget.myUid] as num?)?.toInt() ?? 0;
    final sorted = scores.entries.toList()
      ..sort((a, b) =>
          ((b.value as num).toInt()).compareTo((a.value as num).toInt()));
    final rank = sorted.indexWhere((e) => e.key == widget.myUid) + 1;

    await postGameResult(
      fs: _fs,
      game: _game,
      uid: widget.myUid,
      score: myScore,
      rank: rank < 1 ? widget.players.length : rank,
      totalPlayers: widget.players.length,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => WinnerScreen(
        game: _game,
        didWin: rank == 1,
        rank: rank < 1 ? widget.players.length : rank,
        totalPlayers: widget.players.length,
        score: myScore,
        rankings: sorted.map((e) {
          final p = widget.players.firstWhere((pl) => pl.uid == e.key,
              orElse: () => LobbyPlayer(uid: e.key, name: 'Player'));
          return ScoreLine(p.uid == widget.myUid ? 'You' : p.name,
              (e.value as num).toInt());
        }).toList(),
      ),
    ));
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _strokeSub?.cancel();
    _guessSub?.cancel();
    _roundTimer?.cancel();
    _guessController.dispose();
    _rtdb.leaveMatch('sketch_wars', widget.matchId, widget.myUid);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final drawer = widget.players[_drawerIndex % widget.players.length];
    return Scaffold(
      appBar: AppBar(
        title: Text('SketchWars · Round ${_round + 1}/$_totalRounds'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(_isDrawer ? 'You are drawing:' : '${drawer.name} is drawing'),
                const Spacer(),
                Text(
                  _isDrawer
                      ? _word.toUpperCase()
                      : List.filled(_word.length, '_').join(' '),
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  onPanStart: (d) => _onPanStart(d.localPosition, size),
                  onPanUpdate: (d) => _onPanUpdate(d.localPosition, size),
                  onPanEnd: (_) => _onPanEnd(),
                  child: Container(
                    color: Colors.white,
                    child: CustomPaint(
                      painter: _SketchPainter(
                        strokes: [..._strokes, ?_current],
                        size: size,
                      ),
                      size: size,
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isDrawer) _buildTools(),
          Expanded(child: _buildChat()),
          if (!_isDrawer) _buildGuessBar(),
          if (_isHost && _isDrawer)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextButton(
                  onPressed: _nextRound, child: const Text('Skip round')),
            ),
        ],
      ),
    );
  }

  Widget _buildTools() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          ..._palette.map((c) => GestureDetector(
                onTap: () => setState(() {
                  _color = c;
                  _eraser = false;
                }),
                child: Container(
                  width: 30,
                  height: 30,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (!_eraser && _color == c)
                          ? Colors.blue
                          : Colors.grey.shade300,
                      width: 3,
                    ),
                  ),
                ),
              )),
          IconButton(
            icon: Icon(Icons.auto_fix_high,
                color: _eraser ? Colors.blue : null),
            onPressed: () => setState(() => _eraser = true),
          ),
          // Brush size
          ...[2.0, 4.0, 8.0, 14.0].map((w) => GestureDetector(
                onTap: () => setState(() => _width = w),
                child: Container(
                  width: 34,
                  alignment: Alignment.center,
                  child: CircleAvatar(
                    radius: w / 2 + 4,
                    backgroundColor:
                        _width == w ? Colors.blue : Colors.grey.shade400,
                  ),
                ),
              )),
          IconButton(
              icon: const Icon(Icons.delete_outline), onPressed: _clearCanvas),
        ],
      ),
    );
  }

  Widget _buildChat() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _guesses.length,
      itemBuilder: (context, i) {
        final g = _guesses[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: g.correct
              ? Text('${g.name} guessed the word! ✅',
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.w700))
              : RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      TextSpan(
                          text: '${g.name}: ',
                          style:
                              const TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: g.text),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildGuessBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _guessController,
                decoration: const InputDecoration(hintText: 'Type your guess…'),
                onSubmitted: (_) => _submitGuess(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
                onPressed: _submitGuess, icon: const Icon(Icons.send_rounded)),
          ],
        ),
      ),
    );
  }
}

class _Stroke {
  final int color;
  final double width;
  final List<double> points; // normalized x,y pairs

  _Stroke({required this.color, required this.width, required this.points});

  factory _Stroke.fromMap(Map m) => _Stroke(
        color: (m['color'] as num?)?.toInt() ?? 0xFF000000,
        width: (m['width'] as num?)?.toDouble() ?? 4,
        points: ((m['points'] as List?) ?? [])
            .map((e) => (e as num).toDouble())
            .toList(),
      );

  Map<String, dynamic> toMap() =>
      {'color': color, 'width': width, 'points': points};
}

class _Guess {
  final String uid;
  final String name;
  final String text;
  final bool correct;
  const _Guess(this.uid, this.name, this.text, this.correct);

  factory _Guess.fromMap(Map m) => _Guess(
        m['uid']?.toString() ?? '',
        m['name']?.toString() ?? 'Player',
        m['text']?.toString() ?? '',
        m['correct'] == true,
      );
}

class _SketchPainter extends CustomPainter {
  _SketchPainter({required this.strokes, required this.size});
  final List<_Stroke> strokes;
  final Size size;

  @override
  void paint(Canvas canvas, Size s) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = Color(stroke.color)
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final path = Path();
      final pts = stroke.points;
      for (var i = 0; i + 1 < pts.length; i += 2) {
        final x = pts[i] * s.width;
        final y = pts[i + 1] * s.height;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SketchPainter oldDelegate) => true;
}
