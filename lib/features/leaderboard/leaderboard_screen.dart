import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../shared/models/user_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/avatar_widget.dart';
import '../../shared/widgets/error_state_widget.dart';
import '../../shared/widgets/shimmer_loader.dart';
import '../profile/profile_screen.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ranks',
              style: TextStyle(fontWeight: FontWeight.w800)),
          bottom: const TabBar(
            tabs: [Tab(text: 'Global'), Tab(text: 'Friends')],
          ),
        ),
        body: const TabBarView(
          children: [
            _GlobalBoard(),
            _FriendsBoard(),
          ],
        ),
      ),
    );
  }
}

class _GlobalBoard extends StatelessWidget {
  const _GlobalBoard();

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    final myUid = context.watch<AuthProvider>().uid;
    return StreamBuilder<List<UserModel>>(
      stream: fs.globalLeaderboard(),
      builder: (context, snap) {
        if (snap.hasError) return const ErrorStateWidget();
        if (!snap.hasData) return const FeedSkeleton();
        return _RankList(users: snap.data!, myUid: myUid);
      },
    );
  }
}

class _FriendsBoard extends StatelessWidget {
  const _FriendsBoard();

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    final myUid = context.watch<AuthProvider>().uid;
    final friendIds = context.watch<UserProvider>().friendIds;
    final ids = {...friendIds, ?myUid}.toList();
    return FutureBuilder<List<UserModel>>(
      future: fs.friendsLeaderboard(ids),
      builder: (context, snap) {
        if (snap.hasError) return const ErrorStateWidget();
        if (!snap.hasData) return const FeedSkeleton();
        if (snap.data!.isEmpty) {
          return const EmptyStateWidget(
              message: 'Add friends to compete!', icon: Icons.group_outlined);
        }
        return _RankList(users: snap.data!, myUid: myUid);
      },
    );
  }
}

class _RankList extends StatelessWidget {
  const _RankList({required this.users, required this.myUid});
  final List<UserModel> users;
  final String? myUid;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const EmptyStateWidget(
          message: 'No rankings yet.\nPlay a game to get on the board!',
          icon: Icons.leaderboard_outlined);
    }

    final podium = users.take(3).toList();
    final rest = users.length > 3 ? users.sublist(3) : <UserModel>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _Podium(top: podium, myUid: myUid),
        if (rest.isNotEmpty) const SizedBox(height: 20),
        ...List.generate(rest.length, (i) {
          final u = rest[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RankRow(user: u, rank: i + 4, isMe: u.uid == myUid),
          );
        }),
      ],
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.top, required this.myUid});
  final List<UserModel> top;
  final String? myUid;

  @override
  Widget build(BuildContext context) {
    // Order columns as 2 - 1 - 3 for a classic podium silhouette.
    final order = <int>[if (top.length > 1) 1, 0, if (top.length > 2) 2];
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 24, 8, 20),
      decoration: BoxDecoration(
        gradient: kBrandGradientSoft,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.violet.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final idx in order)
            _PodiumColumn(
              user: top[idx],
              rank: idx + 1,
              isMe: top[idx].uid == myUid,
            ),
        ],
      ),
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  const _PodiumColumn(
      {required this.user, required this.rank, required this.isMe});
  final UserModel user;
  final int rank;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final isFirst = rank == 1;
    final size = isFirst ? 78.0 : 60.0;
    final medal = switch (rank) {
      1 => Colors.amber,
      2 => const Color(0xFFD7DEE6),
      _ => const Color(0xFFE6A86B),
    };

    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProfileScreen(uid: user.uid),
        )),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isFirst)
              const Icon(Icons.workspace_premium_rounded,
                  color: Colors.amber, size: 28),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: medal, width: 3),
              ),
              child: AvatarWidget(
                photoUrl: user.photoUrl,
                displayName: user.displayName,
                size: size,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${user.totalScore} pts',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow(
      {required this.user, required this.rank, required this.isMe});
  final UserModel user;
  final int rank;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: isMe ? scheme.primaryContainer : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProfileScreen(uid: user.uid),
        )),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: isMe
                    ? scheme.primary.withValues(alpha: 0.4)
                    : scheme.outlineVariant.withValues(alpha: 0.6)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text('$rank',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurfaceVariant)),
              ),
              const SizedBox(width: 8),
              AvatarWidget(
                photoUrl: user.photoUrl,
                displayName: user.displayName,
                size: 40,
                isOnline: user.isPresent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(user.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: isMe ? FontWeight.w800 : FontWeight.w600)),
              ),
              Text('${user.totalScore}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(width: 2),
              Text(' pts',
                  style: TextStyle(
                      fontSize: 11, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
