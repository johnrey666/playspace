import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../shared/models/game_catalog.dart';
import '../../../shared/models/game_result_model.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/utils/media.dart';
import '../../../shared/widgets/avatar_widget.dart';

class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post});
  final PostModel post;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final author = context.watch<UserProvider>().cached(post.uid);
    final myUid = context.watch<AuthProvider>().uid!;
    final liked = post.likedBy(myUid);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                AvatarWidget(
                  photoUrl: author?.photoUrl,
                  displayName: author?.displayName ?? '',
                  size: 44,
                  isOnline: author?.isOnline ?? false,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(author?.displayName ?? 'Player',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(timeago.format(post.createdAt),
                          style: TextStyle(
                              fontSize: 12, color: colors.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (post.uid == myUid)
                  IconButton(
                    icon: const Icon(Icons.more_horiz),
                    onPressed: () => _showMenu(context),
                  ),
              ],
            ),
          ),
          if (post.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(post.text,
                  style: const TextStyle(fontSize: 15, height: 1.35)),
            ),
          if (post.type == PostType.game) _GameShareCard(post: post),
          if (post.hasImage)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: SmartImage(src: post.imageUrl, width: double.infinity),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(
              children: [
                _ActionButton(
                  icon: liked ? Icons.favorite : Icons.favorite_border,
                  label: '${post.likes.length}',
                  color: liked ? Colors.redAccent : null,
                  onTap: () => context
                      .read<FirestoreService>()
                      .togglePostLike(post.id, myUid, !liked),
                ),
                _ActionButton(
                  icon: Icons.mode_comment_outlined,
                  label: '${post.commentCount}',
                  onTap: () => _openComments(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
          title: const Text('Delete post'),
          onTap: () {
            context.read<FirestoreService>().deletePost(post.id);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _openComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PostCommentSheet(postId: post.id),
    );
  }
}

class _GameShareCard extends StatelessWidget {
  const _GameShareCard({required this.post});
  final PostModel post;

  @override
  Widget build(BuildContext context) {
    final game = GameCatalog.byId(post.gameId ?? '');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: game.colors.map((c) => c.withValues(alpha: 0.18)).toList(),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            post.isWin ? Icons.emoji_events_rounded : Icons.sports_score_rounded,
            color: post.isWin ? Colors.amber : game.colors.first,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.isWin
                      ? 'Won ${game.name}!'
                      : 'Played ${game.name}',
                  style:
                      const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                Text(
                  'Score ${post.score}'
                  '${post.totalPlayers > 0 ? ' · Rank #${post.rank} of ${post.totalPlayers}' : ''}',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: color),
        label: Text(label,
            style: TextStyle(color: color), overflow: TextOverflow.ellipsis),
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class PostCommentSheet extends StatefulWidget {
  const PostCommentSheet({super.key, required this.postId});
  final String postId;

  @override
  State<PostCommentSheet> createState() => _PostCommentSheetState();
}

class _PostCommentSheetState extends State<PostCommentSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    final fs = context.read<FirestoreService>();
    final myUid = context.read<AuthProvider>().uid!;
    await fs.addPostComment(
      widget.postId,
      FeedComment(id: '', uid: myUid, text: text, createdAt: DateTime.now()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    final userProvider = context.watch<UserProvider>();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            const Text('Comments',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const Divider(),
            Expanded(
              child: StreamBuilder<List<FeedComment>>(
                stream: fs.postComments(widget.postId),
                builder: (context, snap) {
                  final comments = snap.data ?? [];
                  if (comments.isEmpty) {
                    return const Center(child: Text('No comments yet.'));
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    userProvider.ensureUsers(comments.map((c) => c.uid));
                  });
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: comments.length,
                    itemBuilder: (context, i) {
                      final c = comments[i];
                      final author = userProvider.cached(c.uid);
                      return ListTile(
                        leading: AvatarWidget(
                          photoUrl: author?.photoUrl,
                          displayName: author?.displayName ?? '',
                          size: 36,
                        ),
                        title: Text(author?.displayName ?? 'User',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: Text(c.text),
                        trailing: Text(timeago.format(c.createdAt),
                            style: const TextStyle(fontSize: 11)),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration:
                          const InputDecoration(hintText: 'Add a comment…'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                      onPressed: _send, icon: const Icon(Icons.send_rounded)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
