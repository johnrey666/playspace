import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/game_catalog.dart';
import '../../../shared/services/realtime_db_service.dart';
import '../../games/game_lobby_screen.dart';

class GameCardsRow extends StatelessWidget {
  const GameCardsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 188,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: GameCatalog.all.length,
        itemBuilder: (context, i) => GameCard(game: GameCatalog.all[i]),
      ),
    );
  }
}

class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.game});
  final GameInfo game;

  @override
  Widget build(BuildContext context) {
    final rtdb = context.read<RealtimeDbService>();
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => GameLobbyScreen(game: game),
      )),
      child: Container(
        width: 200,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 84,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: game.colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Center(child: Icon(game.icon, color: Colors.white, size: 40)),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: StreamBuilder<DatabaseEvent>(
                      stream: rtdb.onValue('matchmaking/${game.id}'),
                      builder: (context, snap) {
                        final count = _activePlayers(snap.data?.snapshot.value);
                        if (count <= 0) return const SizedBox.shrink();
                        return _LiveBadge(count: count);
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(game.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    game.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _activePlayers(Object? value) {
    if (value is! Map) return 0;
    var total = 0;
    value.forEach((_, match) {
      if (match is Map && match['players'] is Map) {
        total += (match['players'] as Map).length;
      }
    });
    return total;
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, color: Colors.white, size: 8),
          const SizedBox(width: 4),
          Text('LIVE · $count',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
