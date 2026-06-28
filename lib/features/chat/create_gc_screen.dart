import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../shared/models/user_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/utils/media.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/avatar_widget.dart';
import '../../shared/widgets/error_state_widget.dart';
import 'chat_screen.dart';

class CreateGcScreen extends StatefulWidget {
  const CreateGcScreen({super.key});

  @override
  State<CreateGcScreen> createState() => _CreateGcScreenState();
}

class _CreateGcScreenState extends State<CreateGcScreen> {
  final _nameController = TextEditingController();
  final Set<String> _selected = {};
  String? _photoData; // base64 data URI
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final data = await Media.pickAsDataUri(
        source: ImageSource.gallery, maxWidth: 400, quality: 60);
    if (data != null) setState(() => _photoData = data);
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selected.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pick a name and at least 2 friends.'),
      ));
      return;
    }
    setState(() => _creating = true);
    try {
      final fs = context.read<FirestoreService>();
      final myUid = context.read<AuthProvider>().uid!;
      final String? photoUrl = _photoData;
      final chatId = await fs.createGroupChat(
        createdBy: myUid,
        memberIds: [myUid, ..._selected],
        groupName: name,
        groupPhotoUrl: photoUrl,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ChatScreen(chatId: chatId),
      ));
    } catch (_) {
      if (mounted) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create group.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendIds = context.watch<UserProvider>().friendIds;
    final fs = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Create group chat')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickPhoto,
                  child: _photoData != null
                      ? CircleAvatar(
                          radius: 28,
                          backgroundImage: Media.providerFor(_photoData))
                      : const CircleAvatar(
                          radius: 28,
                          child: Icon(Icons.add_a_photo_outlined)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Group name'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: friendIds.isEmpty
                ? const EmptyStateWidget(
                    message: 'Add friends first to create a group.',
                    icon: Icons.group_outlined,
                  )
                : FutureBuilder<List<UserModel>>(
                    future: fs.getUsers(friendIds),
                    builder: (context, snap) {
                      final friends = snap.data ?? [];
                      return ListView.builder(
                        itemCount: friends.length,
                        itemBuilder: (context, i) {
                          final f = friends[i];
                          final selected = _selected.contains(f.uid);
                          return CheckboxListTile(
                            value: selected,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selected.add(f.uid);
                              } else {
                                _selected.remove(f.uid);
                              }
                            }),
                            secondary: AvatarWidget(
                              photoUrl: f.photoUrl,
                              displayName: f.displayName,
                            ),
                            title: Text(f.displayName),
                            subtitle: Text('@${f.username}'),
                          );
                        },
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AppButton(
                label: 'Create group (${_selected.length} selected)',
                loading: _creating,
                onPressed: _create,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
