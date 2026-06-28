import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../shared/models/friend_request_model.dart';
import '../../shared/models/game_result_model.dart';
import '../../shared/models/post_model.dart';
import '../../shared/models/user_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/avatar_widget.dart';
import '../../shared/widgets/error_state_widget.dart';
import '../../shared/widgets/shimmer_loader.dart';
import '../chat/chat_screen.dart';
import '../friends/friends_screen.dart';
import '../home/widgets/post_card.dart';
import 'settings_sheet.dart';

class ProfileScreen extends StatelessWidget {
  /// When [uid] is null the screen shows the currently signed-in user.
  const ProfileScreen({super.key, this.uid});

  final String? uid;

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    final myUid = context.watch<AuthProvider>().uid;
    final targetUid = uid ?? myUid;
    final isSelf = targetUid == myUid;

    if (targetUid == null) {
      return const Scaffold(body: ErrorStateWidget(message: 'Not signed in.'));
    }

    return StreamBuilder<UserModel?>(
      stream: fs.userStream(targetUid),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Scaffold(body: ErrorStateWidget());
        }
        final user = snap.data;
        return Scaffold(
          body: user == null
              ? const FeedSkeleton()
              : _ProfileBody(user: user, isSelf: isSelf),
        );
      },
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.user, required this.isSelf});
  final UserModel user;
  final bool isSelf;

  void _openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SettingsSheet(user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    final colors = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 260,
          backgroundColor: colors.surface,
          actions: [
            if (isSelf)
              IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                onPressed: () => _openSettings(context),
              )
            else
              const SizedBox.shrink(),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _Header(user: user),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (!isSelf) ...[
                  _OtherUserActions(user: user),
                  const SizedBox(height: 16),
                ],
                _InfoChips(user: user),
                const SizedBox(height: 16),
                StreamBuilder<List<GameResultModel>>(
                  stream: fs.resultsForUser(user.uid),
                  builder: (context, snap) {
                    final results = snap.data ?? [];
                    return Column(
                      children: [
                        _StatsRow(results: results, user: user),
                        const SizedBox(height: 16),
                        _BestScores(results: results),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Activity',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ),
        _PostsSliver(uid: user.uid, isSelf: isSelf),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary.withValues(alpha: 0.85),
            AppTheme.violet.withValues(alpha: 0.85),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: AvatarWidget(
                photoUrl: user.photoUrl,
                displayName: user.displayName,
                size: 96,
                isOnline: user.isOnline,
              ),
            ),
            const SizedBox(height: 12),
            Text(user.displayName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            Text('@${user.username}',
                style: const TextStyle(color: Colors.white70)),
            if (user.bio.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
                child: Text(user.bio,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoChips extends StatelessWidget {
  const _InfoChips({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _chip(context, Icons.calendar_today_rounded,
          'Joined ${DateFormat.yMMM().format(user.createdAt)}'),
      if (user.birthday != null)
        _chip(context, Icons.cake_outlined,
            DateFormat.yMMMd().format(user.birthday!)),
      _chip(
        context,
        user.isOnline ? Icons.circle : Icons.circle_outlined,
        user.isOnline ? 'Online' : 'Offline',
        color: user.isOnline ? Colors.green : null,
      ),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: chips,
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label,
      {Color? color}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? colors.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface)),
        ],
      ),
    );
  }
}

class _PostsSliver extends StatelessWidget {
  const _PostsSliver({required this.uid, required this.isSelf});
  final String uid;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    final userProvider = context.watch<UserProvider>();
    return StreamBuilder<List<PostModel>>(
      stream: fs.postsForUser(uid),
      builder: (context, snap) {
        final posts = snap.data ?? [];
        if (posts.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  isSelf
                      ? 'Nothing shared yet.\nShare a game result or post an update!'
                      : 'No activity yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          userProvider.ensureUsers(posts.map((p) => p.uid));
        });
        return SliverList.builder(
          itemCount: posts.length,
          itemBuilder: (context, i) => PostCard(post: posts[i]),
        );
      },
    );
  }
}

class _OtherUserActions extends StatefulWidget {
  const _OtherUserActions({required this.user});
  final UserModel user;

  @override
  State<_OtherUserActions> createState() => _OtherUserActionsState();
}

class _OtherUserActionsState extends State<_OtherUserActions> {
  FriendRequestStatus? _status;
  bool _loadingStatus = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final fs = context.read<FirestoreService>();
    final myUid = context.read<AuthProvider>().uid!;
    final status = await fs.requestStatusBetween(myUid, widget.user.uid);
    if (mounted) {
      setState(() {
        _status = status;
        _loadingStatus = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = context.read<AuthProvider>().uid!;
    final isFriend = widget.user.friendIds.contains(myUid);
    final fs = context.read<FirestoreService>();

    return Row(
      children: [
        if (isFriend)
          Expanded(
            child: FilledButton.icon(
              onPressed: () async {
                final chat =
                    await fs.getOrCreatePmChat(myUid, widget.user.uid);
                if (!context.mounted) return;
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChatScreen(chatId: chat.id),
                ));
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('Message'),
            ),
          )
        else if (_loadingStatus)
          const Expanded(child: Center(child: LinearProgressIndicator()))
        else if (_status == FriendRequestStatus.pending)
          const Expanded(
            child: OutlinedButton(
              onPressed: null,
              child: Text('Request sent'),
            ),
          )
        else
          Expanded(
            child: FilledButton.icon(
              onPressed: _sending
                  ? null
                  : () async {
                      setState(() => _sending = true);
                      await fs.sendFriendRequest(myUid, widget.user.uid);
                      if (mounted) {
                        setState(() {
                          _sending = false;
                          _status = FriendRequestStatus.pending;
                        });
                      }
                    },
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add friend'),
            ),
          ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.results, required this.user});
  final List<GameResultModel> results;
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final played = results.length;
    final wins = results.where((r) => r.isWin).length;
    final winRate = played == 0 ? 0 : ((wins / played) * 100).round();
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _stat(context, '$played', 'Played'),
          _stat(context, '$wins', 'Wins'),
          _stat(context, '$winRate%', 'Win rate'),
          _stat(context, '${user.totalScore}', 'Score'),
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => FriendsScreen(uid: user.uid),
            )),
            child: _stat(context, '${user.friendIds.length}', 'Friends'),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _BestScores extends StatelessWidget {
  const _BestScores({required this.results});
  final List<GameResultModel> results;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();
    final best = <String, GameResultModel>{};
    for (final r in results) {
      final current = best[r.gameId];
      if (current == null || r.score > current.score) best[r.gameId] = r;
    }
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Best scores',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...best.values.map((r) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(r.gameName),
                trailing: Text('${r.score} pts',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              )),
        ],
      ),
    );
  }
}
