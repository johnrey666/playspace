import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../shared/providers/friends_provider.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/widgets/avatar_widget.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import 'widgets/challenge_banner.dart';
import 'widgets/game_cards_row.dart';
import 'widgets/post_composer.dart';
import 'widgets/posts_feed.dart';
import 'widgets/story_row.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static String _greeting(String? name) {
    final hour = DateTime.now().hour;
    final part = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final first = (name ?? '').trim().split(' ').first;
    return first.isEmpty ? part : '$part, $first';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final hasNotifications = context.watch<FriendsProvider>().hasNotifications;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async =>
              await Future<void>.delayed(const Duration(milliseconds: 600)),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  kBrandGradient.createShader(bounds),
                              child: const Text(
                                'playspace',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            Text(
                              _greeting(user?.displayName),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.notifications_outlined),
                            if (hasNotifications)
                              Positioned(
                                right: -1,
                                top: -1,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surface,
                                        width: 1.5),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const NotificationsScreen()),
                        ),
                      ),
                      const SizedBox(width: 4),
                      AvatarWidget(
                        photoUrl: user?.photoUrl,
                        displayName: user?.displayName ?? '',
                        size: 38,
                        isOnline: true,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ProfileScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: StoryRow()),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              const SliverToBoxAdapter(child: _SectionTitle('Games')),
              const SliverToBoxAdapter(child: GameCardsRow()),
              const SliverToBoxAdapter(child: ChallengeBanner()),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              const SliverToBoxAdapter(child: PostComposer()),
              const SliverToBoxAdapter(child: _SectionTitle('Feed')),
              const SliverToBoxAdapter(child: PostsFeed()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800)),
    );
  }
}
