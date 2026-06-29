import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../shared/models/post_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/utils/media.dart';
import '../../shared/widgets/avatar_widget.dart';

/// Full-screen "What's on your mind?" composer.
///
/// This is a real page (not a bottom sheet) so the keyboard, focus and the
/// post button always behave reliably across devices.
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key, this.pickOnOpen = false});

  /// When true, immediately opens the gallery picker after the page loads.
  final bool pickOnOpen;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _imageData;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    if (widget.pickOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickImage());
    } else {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _focus.requestFocus());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _canPost =>
      !_posting && (_controller.text.trim().isNotEmpty || _imageData != null);

  Future<void> _pickImage([ImageSource source = ImageSource.gallery]) async {
    try {
      final data = await Media.pickAsDataUri(source: source);
      if (data != null && mounted) setState(() => _imageData = data);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open photos.')));
      }
    }
  }

  Future<void> _chooseSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickImage(source);
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
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Posted to your feed.')));
      }
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create post'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: FilledButton(
              onPressed: _canPost ? _post : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(72, 40),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              child: _posting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Post'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              AvatarWidget(
                photoUrl: me?.photoUrl,
                displayName: me?.displayName ?? '',
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(me?.displayName ?? 'You',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest
                            .withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.public_rounded,
                              size: 13, color: colors.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text('Public',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            focusNode: _focus,
            autofocus: !widget.pickOnOpen,
            maxLines: null,
            minLines: 5,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 18, height: 1.4),
            decoration: const InputDecoration(
              hintText: "Share what's on your mind…",
              border: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          if (provider != null) ...[
            const SizedBox(height: 12),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image(
                    image: provider,
                    width: double.infinity,
                    height: 280,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
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
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            border: Border(
                top: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.5))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              const SizedBox(width: 8),
              const Text('Add to your post',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                onPressed: _chooseSource,
                icon: const Icon(Icons.photo_library_rounded,
                    color: Colors.green),
                tooltip: 'Add photo',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
