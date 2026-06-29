import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../create_post_screen.dart';

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
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CreatePostScreen(pickOnOpen: withPhoto),
    ));
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
