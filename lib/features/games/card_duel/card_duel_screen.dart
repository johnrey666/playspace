import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/game_catalog.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/services/realtime_db_service.dart';
import '../game_common.dart';
import '../lobby_player.dart';
import 'card_models.dart';

class CardDuelScreen extends StatefulWidget {
  const CardDuelScreen({
    super.key,
    required this.matchId,
    required this.players,
    required this.myUid,
  });

  final String matchId;
  final List<LobbyPlayer> players;
  final String myUid;

  @override
  State<CardDuelScreen> createState() => _CardDuelScreenState();
}

class _CardDuelScreenState extends State<CardDuelScreen> {
  static const _game = GameCatalog.cardDuel;

  late final RealtimeDbService _rtdb = context.read<RealtimeDbService>();
  late final FirestoreService _fs = context.read<FirestoreService>();
  late final String _base = 'matches/card_duel/${widget.matchId}';

  late final LobbyPlayer _opponent = widget.players.firstWhere(
    (p) => p.uid != widget.myUid,
    orElse: () => const LobbyPlayer(uid: '__none__', name: 'Opponent'),
  );
  late final bool _isHost = widget.players.first.uid == widget.myUid;
  late final List<DuelCard> _myDeck =
      generateDeck(_seedFor(widget.myUid), widget.myUid);

  StreamSubscription? _stateSub;
  StreamSubscription? _presenceSub;

  Map<String, dynamic>? _state;
  int _appliedTurn = -1;
  bool _finished = false;
  bool _opponentLeft = false;

  int _seedFor(String uid) =>
      (widget.matchId + uid).codeUnits.fold<int>(0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    _rtdb.registerPresence('card_duel', widget.matchId, widget.myUid);
    _stateSub = _rtdb.onValue('$_base/state').listen(_onState);
    _presenceSub =
        _rtdb.presenceStream('card_duel', widget.matchId).listen((event) {
      final v = event.snapshot.value;
      if (v is Map) {
        final opp = v[_opponent.uid];
        if (opp is Map && opp['connected'] == false && !_opponentLeft) {
          _opponentLeft = true;
          _awardWinOnOpponentLeft();
        }
      }
    });
  }

  void _onState(DatabaseEvent event) {
    final value = event.snapshot.value;
    if (value == null) {
      if (_isHost) _initGame();
      return;
    }
    if (value is! Map) return;
    setState(() => _state = Map<String, dynamic>.from(value));

    final status = _state!['status']?.toString();
    if (status == 'over') {
      _finish();
      return;
    }
    // Apply start-of-turn once when it becomes my turn.
    final turn = _state!['turn']?.toString();
    final turnCount = (_state!['turnCount'] as num?)?.toInt() ?? 0;
    if (turn == widget.myUid && turnCount != _appliedTurn) {
      _appliedTurn = turnCount;
      _applyStartOfTurn();
    }
  }

  Future<void> _initGame() async {
    final me = _newPlayer(widget.myUid, _myDeck);
    final oppDeck = generateDeck(_seedFor(_opponent.uid), _opponent.uid);
    final opp = _newPlayer(_opponent.uid, oppDeck, name: _opponent.name);
    final state = {
      'status': 'playing',
      'turn': widget.myUid,
      'turnCount': 0,
      'winner': null,
      'players': {
        widget.myUid: me.toMap(),
        _opponent.uid: opp.toMap(),
      },
    };
    await _rtdb.set('$_base/state', state);
  }

  PlayerState _newPlayer(String uid, List<DuelCard> deck, {String? name}) {
    final hand = deck.take(5).toList();
    return PlayerState(
      name: name ??
          widget.players
              .firstWhere((p) => p.uid == uid,
                  orElse: () => LobbyPlayer(uid: uid, name: 'You'))
              .name,
      energy: 0,
      deckCount: 25,
      hand: hand,
      board: [],
    );
  }

  PlayerState _player(String uid) =>
      PlayerState.fromMap(_state!['players'][uid] as Map);

  Future<void> _writeState(Map<String, dynamic> updated) =>
      _rtdb.set('$_base/state', updated);

  void _applyStartOfTurn() {
    final state = Map<String, dynamic>.from(_state!);
    final me = _player(widget.myUid);
    me.energy = (me.energy + 1).clamp(0, 10);
    if (me.deckCount > 0) {
      final index = 30 - me.deckCount;
      if (index < _myDeck.length) me.hand.add(_myDeck[index]);
      me.deckCount -= 1;
    }
    state['players'] = Map<String, dynamic>.from(state['players'])
      ..[widget.myUid] = me.toMap();
    _writeState(state);
  }

  void _playCard(DuelCard card) {
    final me = _player(widget.myUid);
    if (card.cost > me.energy) return;
    me.energy -= card.cost;
    me.hand.removeWhere((c) => c.id == card.id);
    me.board.add(card);
    final state = Map<String, dynamic>.from(_state!);
    state['players'] = Map<String, dynamic>.from(state['players'])
      ..[widget.myUid] = me.toMap();
    _writeState(state);
  }

  void _attackAndEndTurn() {
    final me = _player(widget.myUid);
    final opp = _player(_opponent.uid);

    for (final attacker in List<DuelCard>.from(me.board)) {
      if (!me.board.any((c) => c.id == attacker.id)) continue; // destroyed
      if (opp.board.isNotEmpty) {
        opp.board.sort((a, b) => a.defense.compareTo(b.defense));
        final target = opp.board.first;
        if (attacker.attack >= target.defense) {
          opp.board.removeWhere((c) => c.id == target.id);
        }
        if (target.attack >= attacker.defense) {
          me.board.removeWhere((c) => c.id == attacker.id);
        }
      } else {
        // Direct hit: destroy one of opponent's remaining cards.
        if (opp.deckCount > 0) {
          opp.deckCount -= 1;
        } else if (opp.hand.isNotEmpty) {
          opp.hand.removeLast();
        }
      }
    }

    final state = Map<String, dynamic>.from(_state!);
    String? winner;
    if (opp.totalCards <= 0) winner = widget.myUid;

    state['players'] = {
      widget.myUid: me.toMap(),
      _opponent.uid: opp.toMap(),
    };
    if (winner != null) {
      state['status'] = 'over';
      state['winner'] = winner;
    } else {
      state['turn'] = _opponent.uid;
      state['turnCount'] = ((state['turnCount'] as num?)?.toInt() ?? 0) + 1;
    }
    _writeState(state);
  }

  Future<void> _awardWinOnOpponentLeft() async {
    if (_finished || _state == null) return;
    final state = Map<String, dynamic>.from(_state!);
    state['status'] = 'over';
    state['winner'] = widget.myUid;
    await _writeState(state);
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    final winner = _state?['winner']?.toString();
    final iWin = winner == widget.myUid || _opponentLeft;
    final me = _state != null ? _player(widget.myUid) : null;
    final score = (me?.totalCards ?? 0) * 10 + (iWin ? 100 : 0);
    await postGameResult(
      fs: _fs,
      game: _game,
      uid: widget.myUid,
      score: score,
      rank: iWin ? 1 : 2,
      totalPlayers: 2,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => WinnerScreen(
        game: _game,
        didWin: iWin,
        rank: iWin ? 1 : 2,
        totalPlayers: 2,
        score: score,
        subtitle: _opponentLeft ? 'Opponent left — you win!' : null,
      ),
    ));
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _presenceSub?.cancel();
    _rtdb.leaveMatch('card_duel', widget.matchId, widget.myUid);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final me = _player(widget.myUid);
    final opp = _player(_opponent.uid);
    final myTurn = _state!['turn']?.toString() == widget.myUid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CardDuel'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          if (_opponentLeft) const OpponentLeftBanner(),
          _PlayerBanner(
            name: _opponent.name,
            energy: opp.energy,
            cards: opp.totalCards,
            isTurn: !myTurn,
          ),
          _BoardRow(cards: opp.board, faceUp: true),
          const Divider(),
          Expanded(child: Container()),
          _BoardRow(cards: me.board, faceUp: true),
          const Divider(),
          _PlayerBanner(
            name: 'You',
            energy: me.energy,
            cards: me.totalCards,
            isTurn: myTurn,
          ),
          SizedBox(
            height: 130,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              children: me.hand
                  .map((c) => _HandCard(
                        card: c,
                        playable: myTurn && c.cost <= me.energy,
                        onTap: myTurn && c.cost <= me.energy
                            ? () => _playCard(c)
                            : null,
                      ))
                  .toList(),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: myTurn ? _attackAndEndTurn : null,
                icon: const Icon(Icons.sports_kabaddi_rounded),
                label: Text(myTurn ? 'Attack & End Turn' : 'Opponent\'s turn…'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerBanner extends StatelessWidget {
  const _PlayerBanner({
    required this.name,
    required this.energy,
    required this.cards,
    required this.isTurn,
  });
  final String name;
  final int energy;
  final int cards;
  final bool isTurn;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isTurn
          ? Theme.of(context).colorScheme.primaryContainer
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          Icon(Icons.bolt_rounded, size: 18, color: Colors.amber.shade700),
          Text(' $energy   '),
          const Icon(Icons.style_rounded, size: 18),
          Text(' $cards'),
        ],
      ),
    );
  }
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({required this.cards, required this.faceUp});
  final List<DuelCard> cards;
  final bool faceUp;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: cards.isEmpty
          ? const Center(child: Text('No cards in play'))
          : ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: cards.map((c) => _MiniCard(card: c)).toList(),
            ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.card});
  final DuelCard card;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFEF4444)]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text('${card.cost}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${card.attack}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
                Text('${card.defense}',
                    style: const TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HandCard extends StatelessWidget {
  const _HandCard({required this.card, required this.playable, this.onTap});
  final DuelCard card;
  final bool playable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: playable ? 1 : 0.5,
        child: Container(
          width: 84,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: playable ? Colors.white : Colors.transparent, width: 2),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
                  Text('${card.cost}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w900)),
                ],
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.gps_fixed,
                          color: Colors.white, size: 14),
                      Text('${card.attack}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Icon(Icons.shield_outlined,
                          color: Colors.white70, size: 14),
                      Text('${card.defense}',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w900,
                              fontSize: 18)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
