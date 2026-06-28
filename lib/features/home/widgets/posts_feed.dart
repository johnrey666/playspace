import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/post_model.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import 'post_card.dart';

/// Streams the signed-in user's + their friends' posts for the home feed.
class PostsFeed extends StatelessWidget {
  const PostsFeed({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    final userProvider = context.watch<UserProvider>();
    final myUid = context.watch<AuthProvider>().uid!;
    final ids = {myUid, ...userProvider.friendIds}.toList();

    return StreamBuilder<List<PostModel>>(
      stream: fs.feedPosts(ids),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: ErrorStateWidget(message: 'Could not load posts.'),
          );
        }
        if (!snap.hasData) return const FeedSkeleton();
        final posts = snap.data!;
        if (posts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: EmptyStateWidget(
              message:
                  'No posts yet.\nShare an update or add friends to see theirs!',
              icon: Icons.dynamic_feed_outlined,
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          userProvider.ensureUsers(posts.map((p) => p.uid));
        });

        return Column(
          children: List.generate(posts.length, (i) {
            return PostCard(post: posts[i])
                .animate()
                .fadeIn(duration: 300.ms, delay: (40 * i).ms)
                .slideY(begin: 0.08, end: 0);
          }),
        );
      },
    );
  }
}
