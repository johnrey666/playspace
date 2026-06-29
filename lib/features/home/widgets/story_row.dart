import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/story_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../stories/add_story_screen.dart';
import '../../stories/story_viewer_screen.dart';

class StoryRow extends StatelessWidget {
  const StoryRow({super.key});

  @override
  Widget build(BuildContext context) {
    final storyProvider = context.watch<StoryProvider>();
    final userProvider = context.watch<UserProvider>();
    final myUid = context.watch<AuthProvider>().uid!;
    final me = userProvider.user;

    // Ensure author profiles are cached for the row + viewer.
    final groups = storyProvider.groups;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      userProvider.ensureUsers(groups.map((g) => g.uid));
    });

    final selfGroup = storyProvider.groupFor(myUid);
    final otherGroups = groups.where((g) => g.uid != myUid).toList();

    return SizedBox(
      height: 104,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          // Current user "My Day" tile with a + to add a story.
          _StoryTile(
            label: 'My Day',
            child: Stack(
              children: [
                AvatarWidget(
                  photoUrl: me?.photoUrl,
                  displayName: me?.displayName ?? '',
                  size: 64,
                  ring: selfGroup == null
                      ? StoryRing.none
                      : (selfGroup.hasUnseenFor(myUid)
                          ? StoryRing.unseen
                          : StoryRing.seen),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: kBrandGradient,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 2),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
            onTap: () {
              if (selfGroup != null) {
                _openViewer(context, groups, myUid);
              } else {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const AddStoryScreen(),
                ));
              }
            },
            onLongPress: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const AddStoryScreen(),
            )),
          ),
          ...otherGroups.map((g) {
            final author = userProvider.cached(g.uid);
            return _StoryTile(
              label: author?.displayName ?? '',
              child: AvatarWidget(
                photoUrl: author?.photoUrl,
                displayName: author?.displayName ?? '',
                size: 64,
                ring: g.hasUnseenFor(myUid)
                    ? StoryRing.unseen
                    : StoryRing.seen,
              ),
              onTap: () => _openViewer(context, groups, g.uid),
            );
          }),
        ],
      ),
    );
  }

  void _openViewer(BuildContext context, List<StoryGroup> groups, String uid) {
    final index = groups.indexWhere((g) => g.uid == uid);
    if (index < 0) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StoryViewerScreen(groups: groups, initialGroup: index),
    ));
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({
    required this.label,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 76,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            child,
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
