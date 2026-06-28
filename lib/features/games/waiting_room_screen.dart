import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/models/game_catalog.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/services/matchmaking_service.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/avatar_widget.dart';
import 'game_routes.dart';
import 'lobby_player.dart';

class WaitingRoomScreen extends StatefulWidget {
  const WaitingRoomScreen({
    super.key,
    required this.game,
    required this.matchId,
    required this.isHost,
  });

  final GameInfo game;
  final String matchId;
  final bool isHost;

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  bool _navigated = false;

  late final MatchmakingService _mm = context.read<MatchmakingService>();
  late final String _myUid = context.read<AuthProvider>().uid!;

  // Grace countdown before auto-starting once minimum players are present, so
  // additional players can still join but the match never gets stuck waiting.
  static const int _autoStartSeconds = 6;
  Timer? _autoStartTimer;
  int _countdown = 0;

  @override
  void dispose() {
    _autoStartTimer?.cancel();
    super.dispose();
  }

  void _scheduleAutoStart(int playerCount, String status) {
    final eligible = widget.isHost &&
        status == 'waiting' &&
        playerCount >= widget.game.minPlayers &&
        playerCount < widget.game.maxPlayers;

    if (!eligible) {
      if (_autoStartTimer != null) {
        _autoStartTimer?.cancel();
        _autoStartTimer = null;
        if (mounted && _countdown != 0) setState(() => _countdown = 0);
      }
      return;
    }

    if (_autoStartTimer != null) return; // already counting down
    _countdown = _autoStartSeconds;
    _autoStartTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        _autoStartTimer = null;
        _mm.startMatch(widget.game.id, widget.matchId);
      }
    });
    setState(() {});
  }

  List<LobbyPlayer> _parsePlayers(Object? value) {
    if (value is! Map) return [];
    final players = <LobbyPlayer>[];
    value.forEach((uid, data) {
      if (data is Map) players.add(LobbyPlayer.fromMap(uid.toString(), data));
    });
    players.sort((a, b) {
      final aj = (value[a.uid]?['joinedAt'] ?? 0) as num;
      final bj = (value[b.uid]?['joinedAt'] ?? 0) as num;
      return aj.compareTo(bj);
    });
    return players;
  }

  void _goToGame(List<LobbyPlayer> players) {
    if (_navigated) return;
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => buildGameScreen(
          game: widget.game,
          matchId: widget.matchId,
          players: players,
          myUid: _myUid,
        ),
      ));
    });
  }

  Future<void> _leave() async {
    await _mm.leaveLobby(widget.game.id, widget.matchId, _myUid);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_navigated) {
          _mm.leaveLobby(widget.game.id, widget.matchId, _myUid);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text('${widget.game.name} lobby')),
        body: StreamBuilder<DatabaseEvent>(
          stream: _mm.lobbyStream(widget.game.id, widget.matchId),
          builder: (context, snap) {
            final data = snap.data?.snapshot.value;
            if (data is! Map) {
              return const Center(child: CircularProgressIndicator());
            }
            final status = data['status']?.toString() ?? 'waiting';
            final players = _parsePlayers(data['players']);

            // Auto-start once the lobby is full (covers 1v1 + private matches).
            if (status == 'waiting' &&
                widget.isHost &&
                players.length >= widget.game.maxPlayers) {
              _mm.startMatch(widget.game.id, widget.matchId);
            }

            // Otherwise auto-start after a short grace once min players join.
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => _scheduleAutoStart(players.length, status));

            if (status == 'started' && players.length >= widget.game.minPlayers) {
              _goToGame(players);
            }

            final canStart = widget.isHost &&
                players.length >= widget.game.minPlayers &&
                status == 'waiting';

            return Column(
              children: [
                const SizedBox(height: 16),
                Text(
                  'Waiting for players… (${players.length}/${widget.game.maxPlayers})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text('Need at least ${widget.game.minPlayers} to start',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 3,
                    padding: const EdgeInsets.all(16),
                    children: players
                        .map((p) => Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AvatarWidget(
                                    photoUrl: p.photoUrl,
                                    displayName: p.name,
                                    size: 56),
                                const SizedBox(height: 6),
                                Text(p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ))
                        .toList(),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (widget.isHost)
                          AppButton(
                            label: canStart
                                ? (_countdown > 0
                                    ? 'Start now (auto in $_countdown s)'
                                    : 'Start game')
                                : 'Waiting for players…',
                            icon: Icons.play_arrow_rounded,
                            onPressed: canStart
                                ? () {
                                    _autoStartTimer?.cancel();
                                    _autoStartTimer = null;
                                    _mm.startMatch(
                                        widget.game.id, widget.matchId);
                                  }
                                : null,
                          )
                        else
                          Text(_countdown > 0
                              ? 'Starting in $_countdown s…'
                              : 'Waiting for host to start…'),
                        TextButton(
                          onPressed: _leave,
                          child: const Text('Leave lobby'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
