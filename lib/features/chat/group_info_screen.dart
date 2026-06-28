import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../shared/models/chat_model.dart';
import '../../shared/models/user_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/utils/media.dart';
import '../../shared/widgets/avatar_widget.dart';
import '../../shared/widgets/error_state_widget.dart';

class GroupInfoScreen extends StatelessWidget {
  const GroupInfoScreen({super.key, required this.chatId});
  final String chatId;

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    final myUid = context.watch<AuthProvider>().uid!;

    return Scaffold(
      appBar: AppBar(title: const Text('Group info')),
      body: StreamBuilder<ChatModel>(
        stream: fs.chatStream(chatId),
        builder: (context, snap) {
          final chat = snap.data;
          if (chat == null) return const ErrorStateWidget();
          final isAdmin = chat.createdBy == myUid;
          return FutureBuilder<List<UserModel>>(
            future: fs.getUsers(chat.memberIds),
            builder: (context, mSnap) {
              final members = mSnap.data ?? [];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: AvatarWidget(
                      photoUrl: chat.groupPhotoUrl,
                      displayName: chat.groupName ?? 'Group',
                      size: 96,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(chat.groupName ?? 'Group',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 8),
                  if (isAdmin)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () => _editName(context, chat),
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: const Text('Rename'),
                        ),
                        TextButton.icon(
                          onPressed: () => _changePhoto(context, chat),
                          icon: const Icon(Icons.image_rounded, size: 18),
                          label: const Text('Photo'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Text('${members.length} members',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...members.map((m) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: AvatarWidget(
                          photoUrl: m.photoUrl,
                          displayName: m.displayName,
                          isOnline: m.isOnline,
                        ),
                        title: Text(m.displayName),
                        subtitle: Text(m.uid == chat.createdBy
                            ? 'Admin'
                            : '@${m.username}'),
                        trailing: (isAdmin && m.uid != myUid)
                            ? IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => fs.updateGroup(chatId, {
                                  'memberIds': chat.memberIds
                                      .where((id) => id != m.uid)
                                      .toList(),
                                }),
                              )
                            : null,
                      )),
                  if (isAdmin) ...[
                    const Divider(),
                    _AddMembers(chat: chat),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _editName(BuildContext context, ChatModel chat) async {
    final controller = TextEditingController(text: chat.groupName);
    final fs = context.read<FirestoreService>();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename group'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await fs.updateGroup(chat.id, {'groupName': result});
    }
  }

  Future<void> _changePhoto(BuildContext context, ChatModel chat) async {
    final data = await Media.pickAsDataUri(
        source: ImageSource.gallery, maxWidth: 400, quality: 60);
    if (data == null || !context.mounted) return;
    final fs = context.read<FirestoreService>();
    await fs.updateGroup(chat.id, {'groupPhotoUrl': data});
  }
}

class _AddMembers extends StatelessWidget {
  const _AddMembers({required this.chat});
  final ChatModel chat;

  @override
  Widget build(BuildContext context) {
    final friendIds = context.watch<UserProvider>().friendIds;
    final fs = context.read<FirestoreService>();
    final candidates =
        friendIds.where((id) => !chat.memberIds.contains(id)).toList();
    if (candidates.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add friends',
            style: Theme.of(context).textTheme.titleMedium),
        FutureBuilder<List<UserModel>>(
          future: fs.getUsers(candidates),
          builder: (context, snap) {
            final users = snap.data ?? [];
            return Column(
              children: users
                  .map((u) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: AvatarWidget(
                          photoUrl: u.photoUrl,
                          displayName: u.displayName,
                        ),
                        title: Text(u.displayName),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => fs.updateGroup(chat.id, {
                            'memberIds': [...chat.memberIds, u.uid],
                          }),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
