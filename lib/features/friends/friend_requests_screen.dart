import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/models/friend_request_model.dart';
import '../../shared/models/user_model.dart';
import '../../shared/providers/friends_provider.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/avatar_widget.dart';
import '../../shared/widgets/error_state_widget.dart';

class FriendRequestsScreen extends StatelessWidget {
  const FriendRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final requests = context.watch<FriendsProvider>().requests;
    return Scaffold(
      appBar: AppBar(title: const Text('Friend requests')),
      body: requests.isEmpty
          ? const EmptyStateWidget(
              message: 'No pending requests.',
              icon: Icons.person_add_disabled_rounded)
          : ListView.builder(
              itemCount: requests.length,
              itemBuilder: (context, i) =>
                  _RequestTile(request: requests[i]),
            ),
    );
  }
}

class _RequestTile extends StatefulWidget {
  const _RequestTile({required this.request});
  final FriendRequestModel request;

  @override
  State<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<_RequestTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return FutureBuilder<UserModel?>(
      future: fs.getUser(widget.request.fromUid),
      builder: (context, snap) {
        final user = snap.data;
        return ListTile(
          leading: AvatarWidget(
            photoUrl: user?.photoUrl,
            displayName: user?.displayName ?? '',
          ),
          title: Text(user?.displayName ?? 'Loading…'),
          subtitle: user != null ? Text('@${user.username}') : null,
          trailing: _busy
              ? const SizedBox(
                  width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.check_rounded),
                      onPressed: () async {
                        setState(() => _busy = true);
                        await fs.acceptFriendRequest(widget.request);
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () async {
                        setState(() => _busy = true);
                        await fs.declineFriendRequest(widget.request.id);
                      },
                    ),
                  ],
                ),
        );
      },
    );
  }
}
