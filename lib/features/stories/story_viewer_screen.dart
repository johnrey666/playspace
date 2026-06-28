import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/models/story_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/story_provider.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/utils/media.dart';
import '../../shared/widgets/avatar_widget.dart';

/// Full-screen story viewer. Auto-advances every 5 seconds, swipe between
/// friends' story groups, and records the viewer in `viewedBy`.
class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.groups,
    required this.initialGroup,
  });

  final List<StoryGroup> groups;
  final int initialGroup;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController =
      PageController(initialPage: widget.initialGroup);
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  int _groupIndex = 0;
  int _storyIndex = 0;

  @override
  void initState() {
    super.initState();
    _groupIndex = widget.initialGroup;
    _progress.addStatusListener((status) {
      if (status == AnimationStatus.completed) _next();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _startStory());
  }

  @override
  void dispose() {
    _progress.dispose();
    _pageController.dispose();
    super.dispose();
  }

  StoryGroup get _group => widget.groups[_groupIndex];

  void _startStory() {
    _progress.forward(from: 0);
    final story = _group.stories[_storyIndex];
    final myUid = context.read<AuthProvider>().uid!;
    if (!story.seenBy(myUid)) {
      context.read<FirestoreService>().markStoryViewed(story.id, myUid);
    }
  }

  void _next() {
    if (_storyIndex < _group.stories.length - 1) {
      setState(() => _storyIndex++);
      _startStory();
    } else if (_groupIndex < widget.groups.length - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _prev() {
    if (_storyIndex > 0) {
      setState(() => _storyIndex--);
      _startStory();
    } else if (_groupIndex > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3) {
            _prev();
          } else {
            _next();
          }
        },
        onLongPressDown: (_) => _progress.stop(),
        onLongPressUp: () => _progress.forward(),
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.groups.length,
          onPageChanged: (i) {
            setState(() {
              _groupIndex = i;
              _storyIndex = 0;
            });
            _startStory();
          },
          itemBuilder: (context, i) => _buildGroup(widget.groups[i]),
        ),
      ),
    );
  }

  Widget _buildGroup(StoryGroup group) {
    final isCurrent = group.uid == _group.uid;
    final idx = isCurrent ? _storyIndex : 0;
    final story = group.stories[idx];
    final author = context.watch<UserProvider>().cached(group.uid);

    return Stack(
      children: [
        Positioned.fill(child: _buildStoryContent(story)),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          right: 8,
          child: Column(
            children: [
              Row(
                children: List.generate(group.stories.length, (s) {
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      child: AnimatedBuilder(
                        animation: _progress,
                        builder: (context, _) {
                          double value;
                          if (s < idx) {
                            value = 1;
                          } else if (s == idx && isCurrent) {
                            value = _progress.value;
                          } else {
                            value = 0;
                          }
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: value,
                              backgroundColor: Colors.white24,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  AvatarWidget(
                    photoUrl: author?.photoUrl,
                    displayName: author?.displayName ?? '',
                    size: 36,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(author?.displayName ?? '',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (story.caption.isNotEmpty && story.mediaType == StoryMediaType.image)
          Positioned(
            bottom: 48,
            left: 24,
            right: 24,
            child: Text(
              story.caption,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 8, color: Colors.black)],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStoryContent(StoryModel story) {
    if (story.mediaType == StoryMediaType.text) {
      return Container(
        color: Color(story.bgColor),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(32),
        child: Text(
          story.caption,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }
    return SmartImage(
      src: story.mediaUrl,
      fit: BoxFit.contain,
      width: double.infinity,
      placeholderColor: Colors.black,
    );
  }
}
