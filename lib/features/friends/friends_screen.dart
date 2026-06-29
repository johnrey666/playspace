import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/models/user_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/friends_provider.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/avatar_widget.dart';
import '../../shared/widgets/error_state_widget.dart';
import '../../shared/widgets/shimmer_loader.dart';
import '../chat/chat_screen.dart';
import '../profile/profile_screen.dart';
import 'friend_requests_screen.dart';
import 'user_search_screen.dart';

class FriendsScreen extends StatelessWidget {
  /// Shows the friends of [uid]; defaults to the signed-in user.
  const FriendsScreen({super.key, this.uid});
  final String? uid;

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    final myUid = context.watch<AuthProvider>().uid;
    final targetUid = uid ?? myUid;
    final isSelf = targetUid == myUid;
    final pending =
        isSelf ? context.watch<FriendsProvider>().requests.length : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          if (isSelf)
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const UserSearchScreen(),
              )),
            ),
          if (isSelf)
            IconButton(
              icon: Badge(
                isLabelVisible: pending > 0,
                label: Text('$pending'),
                child: const Icon(Icons.person_add_alt_1_outlined),
              ),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const FriendRequestsScreen(),
              )),
            ),
        ],
      ),
      body: StreamBuilder<UserModel?>(
        stream: fs.userStream(targetUid!),
        builder: (context, snap) {
          if (snap.hasError) return const ErrorStateWidget();
          if (!snap.hasData) return const FeedSkeleton();
          final friendIds = snap.data?.friendIds ?? [];
          if (friendIds.isEmpty) {
            return EmptyStateWidget(
              message:
                  isSelf ? 'No friends yet. Search to add some!' : 'No friends yet.',
              icon: Icons.group_outlined,
            );
          }
          return FutureBuilder<List<UserModel>>(
            future: fs.getUsers(friendIds),
            builder: (context, fSnap) {
              if (!fSnap.hasData) return const FeedSkeleton();
              final friends = fSnap.data!;
              return ListView.builder(
                itemCount: friends.length,
                itemBuilder: (context, i) {
                  final f = friends[i];
                  return ListTile(
                    leading: AvatarWidget(
                      photoUrl: f.photoUrl,
                      displayName: f.displayName,
                      isOnline: f.isPresent,
                    ),
                    title: Text(f.displayName),
                    subtitle: Text('@${f.username}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      onPressed: () async {
                        final chat =
                            await fs.getOrCreatePmChat(myUid!, f.uid);
                        if (!context.mounted) return;
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ChatScreen(chatId: chat.id),
                        ));
                      },
                    ),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ProfileScreen(uid: f.uid),
                    )),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
