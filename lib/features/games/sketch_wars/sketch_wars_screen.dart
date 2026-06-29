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
  static const _roundSeconds = 60;
  // A fresh letter of the word is revealed to guessers every this many seconds.
  static const _hintEverySeconds = 20;

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
  StreamSubscription? _presenceSub;
  Timer? _roundTimer;
  // Drives the on-screen countdown + progressive letter hints (1s tick).
  Timer? _uiTimer;

  Map<String, dynamic>? _state;
  List<_Stroke> _strokes = [];
  List<_Guess> _guesses = [];
  _Stroke? _current;
  Color _color = Colors.black;
  double _width = 4;
  bool _eraser = false;
  _PenType _penType = _PenType.pen;
  int _listeningRound = -1;
  bool _finished = false;
  bool _opponentLeft = false;
  // Guards against advancing the same round twice when the guess stream
  // re-emits.
  int _advancedFromRound = -1;
  final _guessController = TextEditingController();

  /// Everyone who isn't me — used to detect when the opponent(s) bail out.
  late final List<String> _otherUids =
      widget.players.map((p) => p.uid).where((u) => u != widget.myUid).toList();

  int get _round => (_state?['round'] as num?)?.toInt() ?? 0;
  int get _drawerIndex => (_state?['drawerIndex'] as num?)?.toInt() ?? 0;
  String get _drawerUid => widget.players[_drawerIndex % widget.players.length].uid;
  bool get _isDrawer => _drawerUid == widget.myUid;
  String get _word => _state?['word']?.toString() ?? '';
  int? get _roundStartMs => (_state?['roundStartAt'] as num?)?.toInt();

  /// Whole seconds elapsed in the current round (0.._roundSeconds), derived from
  /// the server-stamped round start so both clients stay in sync.
  int get _elapsedSeconds {
    final start = _roundStartMs;
    if (start == null) return 0;
    final secs =
        ((DateTime.now().millisecondsSinceEpoch - start) / 1000).floor();
    return secs.clamp(0, _roundSeconds);
  }

  int get _remainingSeconds => (_roundSeconds - _elapsedSeconds).clamp(0, _roundSeconds);

  @override
  void initState() {
    super.initState();
    _rtdb.registerPresence('sketch_wars', widget.matchId, widget.myUid);
    _stateSub = _rtdb.onValue('$_base/state').listen(_onState);
    _presenceSub =
        _rtdb.presenceStream('sketch_wars', widget.matchId).listen(_onPresence);
    // Repaint once a second so the countdown ticks and new hint letters appear.
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  /// If the only other player drops their connection, end the match and award
  /// the remaining player the win.
  void _onPresence(DatabaseEvent event) {
    if (_opponentLeft || _finished || _otherUids.isEmpty) return;
    final value = event.snapshot.value;
    if (value is! Map) return;
    final allGone = _otherUids.every((uid) {
      final p = value[uid];
      return p is Map && p['connected'] == false;
    });
    if (allGone) {
      setState(() => _opponentLeft = true);
      _finish();
    }
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
      'roundStartAt': ServerValue.timestamp,
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
      _maybeAdvanceAfterGuesses();
    });
  }

  /// Host-driven: as soon as every guesser has the word, jump to the next round.
  /// Runs off the synced guess stream so it works no matter who is the host.
  void _maybeAdvanceAfterGuesses() {
    if (!_isHost || _advancedFromRound == _round) return;
    final guessers = widget.players.length - 1;
    if (guessers <= 0) return;
    final correctGuessers =
        _guesses.where((g) => g.correct).map((g) => g.uid).toSet().length;
    if (correctGuessers >= guessers) {
      _advancedFromRound = _round;
      final r = _round;
      // Small beat so everyone sees the "guessed it!" confirmation first.
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted && _round == r) _nextRound();
      });
    }
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
    state['roundStartAt'] = ServerValue.timestamp;
    await _rtdb.set('$_base/state', state);
  }

  // ---- Drawing ----
  /// Effective ARGB colour for the current tool (highlighter is translucent).
  int _strokeColorValue() {
    if (_eraser) return 0xFFFFFFFF;
    if (_penType == _PenType.highlighter) {
      return _color.withValues(alpha: 0.32).toARGB32();
    }
    return _color.toARGB32();
  }

  /// Effective stroke width for the current tool and chosen thickness.
  double _strokeWidthValue() {
    if (_eraser) return 22;
    switch (_penType) {
      case _PenType.pen:
        return _width;
      case _PenType.marker:
        return (_width * 2).clamp(8, 44);
      case _PenType.highlighter:
        return (_width * 3).clamp(16, 60);
    }
  }

  void _onPanStart(Offset p, Size size) {
    if (!_isDrawer) return;
    _current = _Stroke(
      color: _strokeColorValue(),
      width: _strokeWidthValue(),
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
      // Time-based payout: the longer the round drags on, the fewer points the
      // guesser earns and the more the drawer earns (they kept the word hidden).
      final frac = (_elapsedSeconds / _roundSeconds).clamp(0.0, 1.0);
      final guesserPts = ((1 - frac) * 100).round().clamp(10, 100);
      final drawerPts = (frac * 100).round().clamp(10, 100);
      scores[widget.myUid] =
          ((scores[widget.myUid] as num?)?.toInt() ?? 0) + guesserPts;
      scores[_drawerUid] =
          ((scores[_drawerUid] as num?)?.toInt() ?? 0) + drawerPts;
      await _rtdb.update('$_base/state', {'scores': scores});
      // Advancing to the next round is handled by the host in
      // [_maybeAdvanceAfterGuesses], driven off the synced guess stream.
    }
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    _roundTimer?.cancel();
    final scores = Map<String, dynamic>.from((_state?['scores'] as Map?) ?? {});
    final myScore = (scores[widget.myUid] as num?)?.toInt() ?? 0;
    final sorted = scores.entries.toList()
      ..sort((a, b) =>
          ((b.value as num).toInt()).compareTo((a.value as num).toInt()));
    var rank = sorted.indexWhere((e) => e.key == widget.myUid) + 1;
    // Opponent bailed → the remaining player takes the win outright.
    if (_opponentLeft) rank = 1;
    final didWin = rank == 1;

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
        didWin: didWin,
        rank: rank < 1 ? widget.players.length : rank,
        totalPlayers: widget.players.length,
        score: myScore,
        subtitle: _opponentLeft ? 'Opponent left — you win!' : null,
        rankings: sorted.map((e) {
          final p = widget.players.firstWhere((pl) => pl.uid == e.key,
              orElse: () => LobbyPlayer(uid: e.key, name: 'Player'));
          return ScoreLine(p.uid == widget.myUid ? 'You' : p.name,
              (e.value as num).toInt());
        }).toList(),
      ),
    ));
  }

  // ---- Hints ----
  /// How many letters of the word have been revealed so far (one more every
  /// [_hintEverySeconds]). Never reveals the entire word.
  int get _revealCount {
    final w = _word;
    if (w.isEmpty) return 0;
    final letters = w.replaceAll(' ', '').length;
    final maxReveal = (letters - 1).clamp(0, letters);
    return (_elapsedSeconds ~/ _hintEverySeconds).clamp(0, maxReveal);
  }

  /// Deterministic per-round order in which letters get revealed, so the
  /// drawer and guesser always see the same hints.
  List<int> _hintOrder() {
    final w = _word;
    final indices = [for (var i = 0; i < w.length; i++) if (w[i] != ' ') i];
    var seed = (w.hashCode ^ (_round * 0x9E3779B1)) & 0x7fffffff;
    for (var i = indices.length - 1; i > 0; i--) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      final j = seed % (i + 1);
      final t = indices[i];
      indices[i] = indices[j];
      indices[j] = t;
    }
    return indices;
  }

  /// The word as the guesser sees it: blanks with any revealed hint letters.
  String _maskedWord() {
    final w = _word;
    if (w.isEmpty) return '';
    final revealed = _hintOrder().take(_revealCount).toSet();
    final out = <String>[];
    for (var i = 0; i < w.length; i++) {
      final ch = w[i];
      if (ch == ' ') {
        out.add(' ');
      } else if (revealed.contains(i)) {
        out.add(ch.toUpperCase());
      } else {
        out.add('_');
      }
    }
    return out.join(' ');
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _strokeSub?.cancel();
    _guessSub?.cancel();
    _presenceSub?.cancel();
    _roundTimer?.cancel();
    _uiTimer?.cancel();
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
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_opponentLeft) const OpponentLeftBanner(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isDrawer
                              ? 'You are drawing:'
                              : '${drawer.name} is drawing',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _RoundTimerChip(seconds: _remainingSeconds),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      _isDrawer ? _word.toUpperCase() : _maskedWord(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          fontSize: 18),
                    ),
                  ),
                  if (!_isDrawer && _revealCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Center(
                        child: Text(
                          '$_revealCount hint${_revealCount == 1 ? '' : 's'} revealed',
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Flexible square canvas: shrinks with the keyboard so the guess
            // field never overflows the bottom.
            Expanded(
              flex: 5,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size =
                          Size(constraints.maxWidth, constraints.maxHeight);
                      return GestureDetector(
                        onPanStart: (d) => _onPanStart(d.localPosition, size),
                        onPanUpdate: (d) =>
                            _onPanUpdate(d.localPosition, size),
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
              ),
            ),
            if (_isDrawer) _buildTools(),
            Expanded(flex: 3, child: _buildChat()),
            if (!_isDrawer) _buildGuessBar(),
            if (_isHost && _isDrawer)
              TextButton(
                  onPressed: _nextRound, child: const Text('Skip round')),
          ],
        ),
      ),
    );
  }

  Widget _buildTools() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Colours, eraser and clear.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
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
                  tooltip: 'Eraser',
                  icon: Icon(Icons.auto_fix_high,
                      color: _eraser ? Colors.blue : null),
                  onPressed: () => setState(() => _eraser = true),
                ),
                IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _clearCanvas,
                ),
              ],
            ),
          ),
          // Pen type.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _penTypeChip(_PenType.pen, Icons.edit_rounded, 'Pen'),
                _penTypeChip(_PenType.marker, Icons.brush_rounded, 'Marker'),
                _penTypeChip(
                    _PenType.highlighter, Icons.highlight_rounded, 'Highlight'),
              ],
            ),
          ),
          // Thickness + live preview of the current nib.
          Row(
            children: [
              const Icon(Icons.line_weight_rounded, size: 18),
              Expanded(
                child: Slider(
                  min: 1,
                  max: 20,
                  value: _width,
                  label: _width.round().toString(),
                  divisions: 19,
                  onChanged: (v) => setState(() {
                    _width = v;
                    _eraser = false;
                  }),
                ),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Container(
                    width: (_strokeWidthValue()).clamp(4, 40).toDouble(),
                    height: (_strokeWidthValue()).clamp(4, 40).toDouble(),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _eraser
                          ? scheme.surfaceContainerHighest
                          : Color(_strokeColorValue()),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _penTypeChip(_PenType type, IconData icon, String label) {
    final selected = !_eraser && _penType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        avatar: Icon(icon,
            size: 16, color: selected ? Colors.white : null),
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() {
          _penType = type;
          _eraser = false;
        }),
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

enum _PenType { pen, marker, highlighter }

class _RoundTimerChip extends StatelessWidget {
  const _RoundTimerChip({required this.seconds});
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final low = seconds <= 10;
    final color = low ? Colors.red : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 16, color: color),
          const SizedBox(width: 4),
          Text('${seconds}s',
              style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ],
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
