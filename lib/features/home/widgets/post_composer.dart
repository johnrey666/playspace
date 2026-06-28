import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/post_model.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/utils/media.dart';
import '../../../shared/widgets/avatar_widget.dart';

/// The "What's on your mind?" entry card shown at the top of the home feed.
class PostComposer extends StatelessWidget {
  const PostComposer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final me = context.watch<UserProvider>().user;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AvatarWidget(
                photoUrl: me?.photoUrl,
                displayName: me?.displayName ?? '',
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _openComposer(context),
                  child: Container(
                    height: 46,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text("What's on your mind?",
                        style: TextStyle(color: colors.onSurfaceVariant)),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(
                child: _ComposerAction(
                  icon: Icons.photo_library_rounded,
                  label: 'Photo',
                  color: Colors.green,
                  onTap: () => _openComposer(context, withPhoto: true),
                ),
              ),
              Expanded(
                child: _ComposerAction(
                  icon: Icons.edit_note_rounded,
                  label: 'Write',
                  color: colors.primary,
                  onTap: () => _openComposer(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openComposer(BuildContext context, {bool withPhoto = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ComposeSheet(pickOnOpen: withPhoto),
    );
  }
}

class _ComposerAction extends StatelessWidget {
  const _ComposerAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: color),
      label: Text(label,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet({this.pickOnOpen = false});
  final bool pickOnOpen;

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final _controller = TextEditingController();
  String? _imageData;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    if (widget.pickOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickImage());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final data = await Media.pickAsDataUri(source: ImageSource.gallery);
    if (data != null && mounted) setState(() => _imageData = data);
  }

  Future<void> _post() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _imageData == null) return;
    setState(() => _posting = true);
    final fs = context.read<FirestoreService>();
    final myUid = context.read<AuthProvider>().uid!;
    try {
      await fs.createPost(PostModel(
        id: '',
        uid: myUid,
        type: PostType.text,
        text: text,
        imageUrl: _imageData,
        createdAt: DateTime.now(),
      ));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _posting = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not post. Try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final me = context.watch<UserProvider>().user;
    final provider = Media.providerFor(_imageData);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarWidget(
                photoUrl: me?.photoUrl,
                displayName: me?.displayName ?? '',
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(me?.displayName ?? 'You',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: !widget.pickOnOpen,
            maxLines: 5,
            minLines: 3,
            decoration: const InputDecoration(
              hintText: "Share what's on your mind…",
              border: InputBorder.none,
            ),
          ),
          if (provider != null) ...[
            const SizedBox(height: 8),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image(
                    image: provider,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _imageData = null),
                    child: const CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.close, size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library_rounded,
                    color: Colors.green),
                tooltip: 'Add photo',
              ),
              const Spacer(),
              FilledButton(
                onPressed: _posting ? null : _post,
                style: FilledButton.styleFrom(backgroundColor: colors.primary),
                child: _posting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Post'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
