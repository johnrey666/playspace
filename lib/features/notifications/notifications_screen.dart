import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../app/theme.dart';
import '../../shared/models/friend_request_model.dart';
import '../../shared/models/user_model.dart';
import '../../shared/providers/friends_provider.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/avatar_widget.dart';
import '../../shared/widgets/error_state_widget.dart';
import '../friends/friend_requests_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final friends = context.watch<FriendsProvider>();
    final requests = friends.requests;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: requests.isEmpty
          ? const EmptyStateWidget(
              message: 'You\'re all caught up!',
              icon: Icons.notifications_none_rounded,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                ...requests.map((r) => _RequestNotif(request: r)),
              ],
            ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: context.colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: child,
    );
  }
}

class _RequestNotif extends StatelessWidget {
  const _RequestNotif({required this.request});
  final FriendRequestModel request;

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return _Tile(
      child: FutureBuilder<UserModel?>(
        future: fs.getUser(request.fromUid),
        builder: (context, snap) {
          final user = snap.data;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const FriendRequestsScreen(),
            )),
            child: Row(
              children: [
                AvatarWidget(
                  photoUrl: user?.photoUrl,
                  displayName: user?.displayName ?? '',
                  size: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${user?.displayName ?? 'Someone'} sent a request',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(timeago.format(request.createdAt),
                          style: TextStyle(
                              fontSize: 12,
                              color: context.colors.onSurfaceVariant)),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.check_rounded),
                  onPressed: () => fs.acceptFriendRequest(request),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => fs.declineFriendRequest(request.id),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
