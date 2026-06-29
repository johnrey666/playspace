import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../app/theme.dart';
import '../../shared/models/chat_model.dart';
import '../../shared/models/user_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/chat_provider.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/avatar_widget.dart';
import '../../shared/widgets/error_state_widget.dart';
import '../friends/friends_screen.dart';
import 'chat_screen.dart';
import 'create_gc_screen.dart';
import 'random_chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chats = context.watch<ChatProvider>().chats;
    final myUid = context.watch<AuthProvider>().uid!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'New message',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const FriendsScreen(),
            )),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _GradientFab(
            icon: Icons.shuffle_rounded,
            label: 'Random Chat',
            gradient: const LinearGradient(
              colors: [Color(0xFFEC4899), Color(0xFFF97316)],
            ),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const RandomChatScreen(),
            )),
          ),
          const SizedBox(height: 12),
          _GradientFab(
            icon: Icons.group_add_rounded,
            label: 'Create GC',
            gradient: kBrandGradient,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const CreateGcScreen(),
            )),
          ),
        ],
      ),
      body: chats.isEmpty
          ? const EmptyStateWidget(
              message: 'No conversations yet.\nStart a chat with a friend!',
              icon: Icons.forum_outlined,
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              itemCount: chats.length,
              itemBuilder: (context, i) =>
                  _ChatTile(chat: chats[i], myUid: myUid),
            ),
    );
  }
}

class _GradientFab extends StatelessWidget {
  const _GradientFab({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.last.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.myUid});
  final ChatModel chat;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    final unread = chat.unreadFor(myUid);
    final subtitle = chat.lastMessage.isEmpty ? 'No messages yet' : chat.lastMessage;
    final time = chat.lastMessageAt != null
        ? timeago.format(chat.lastMessageAt!, locale: 'en_short')
        : '';

    Widget tile({String? title, String? photoUrl, bool online = false}) {
      final scheme = Theme.of(context).colorScheme;
      final hasUnread = unread > 0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: hasUnread
              ? scheme.primary.withValues(alpha: 0.08)
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChatScreen(chatId: chat.id),
            )),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  AvatarWidget(
                    photoUrl: photoUrl,
                    displayName: title ?? '',
                    size: 52,
                    isOnline: online,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title ?? 'Chat',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 3),
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: hasUnread
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(time,
                          style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      if (hasUnread)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('$unread',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        )
                      else
                        const SizedBox(height: 18),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (chat.isGroupChat) {
      return tile(title: chat.groupName, photoUrl: chat.groupPhotoUrl);
    }
    final fs = context.read<FirestoreService>();
    return FutureBuilder<UserModel?>(
      future: fs.getUser(chat.otherMemberId(myUid)),
      builder: (context, snap) {
        final user = snap.data;
        return tile(
          title: user?.displayName,
          photoUrl: user?.photoUrl,
          online: user?.isPresent ?? false,
        );
      },
    );
  }
}
