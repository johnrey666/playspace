import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../shared/models/story_model.dart';
import '../../shared/models/user_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/story_provider.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/utils/media.dart';
import '../../shared/widgets/avatar_widget.dart';

const _reactions = ['❤️', '😂', '😮', '😢', '👏', '🔥'];

/// Full-screen story viewer. Auto-advances every 5 seconds, swipe between
/// friends' story groups, records viewers, and lets you reply or react to a
/// story (delivered as a DM, Instagram-style).
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

  final _replyController = TextEditingController();
  final _replyFocus = FocusNode();

  int _groupIndex = 0;
  int _storyIndex = 0;

  @override
  void initState() {
    super.initState();
    _groupIndex = widget.initialGroup;
    _progress.addStatusListener((status) {
      if (status == AnimationStatus.completed) _next();
    });
    _replyFocus.addListener(() {
      if (_replyFocus.hasFocus) {
        _pause();
      } else {
        _resume();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _startStory());
  }

  @override
  void dispose() {
    _progress.dispose();
    _pageController.dispose();
    _replyController.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  StoryGroup get _group => widget.groups[_groupIndex];
  StoryModel get _story => _group.stories[_storyIndex];
  String get _myUid => context.read<AuthProvider>().uid!;
  bool get _isOwn => _group.uid == _myUid;

  void _pause() {
    _progress.stop();
  }

  void _resume() {
    if (!mounted) return;
    if (!_progress.isAnimating && _progress.value < 1) {
      _progress.forward();
    }
  }

  void _startStory() {
    _progress.forward(from: 0);
    final story = _group.stories[_storyIndex];
    if (!story.seenBy(_myUid)) {
      context.read<FirestoreService>().markStoryViewed(story.id, _myUid);
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

  Future<void> _sendReply([String? quickText]) async {
    final text = (quickText ?? _replyController.text).trim();
    if (text.isEmpty) return;
    _replyController.clear();
    _replyFocus.unfocus();
    final fs = context.read<FirestoreService>();
    final messenger = ScaffoldMessenger.of(context);
    final toUid = _group.uid;
    final story = _story;
    final preview =
        story.mediaType == StoryMediaType.image ? story.mediaUrl : null;
    try {
      await fs.sendStoryReply(
        fromUid: _myUid,
        toUid: toUid,
        text: text,
        storyHint: 'Replied to your story',
        storyPreviewUrl: preview,
      );
      messenger.showSnackBar(SnackBar(
          content: Text('Sent $text'),
          duration: const Duration(seconds: 1)));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not send. Try again.')));
    }
    _resume();
  }

  Future<void> _confirmDelete() async {
    _pause();
    final fs = context.read<FirestoreService>();
    final navigator = Navigator.of(context);
    final storyId = _story.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete story?'),
        content: const Text('This removes it from your Day for everyone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await fs.deleteStory(storyId);
      navigator.maybePop();
    } else {
      _resume();
    }
  }

  void _showViewers() {
    _pause();
    final viewers = _story.viewedBy.where((id) => id != _myUid).toList();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => _ViewersSheet(viewerIds: viewers),
    ).whenComplete(_resume);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                if (_replyFocus.hasFocus) {
                  _replyFocus.unfocus();
                  return;
                }
                final width = MediaQuery.of(context).size.width;
                if (details.globalPosition.dx < width / 3) {
                  _prev();
                } else {
                  _next();
                }
              },
              onLongPressDown: (_) => _pause(),
              onLongPressUp: _resume,
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
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              padding:
                  EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: _isOwn ? _buildOwnerBar() : _buildReplyBar(),
            ),
          ),
        ],
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
        // Top + bottom scrims for legibility.
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 160,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
          ),
        ),
        const Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 180,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 10,
          right: 10,
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
              const SizedBox(height: 12),
              Row(
                children: [
                  AvatarWidget(
                    photoUrl: author?.photoUrl,
                    displayName: author?.displayName ?? '',
                    size: 38,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(author?.displayName ?? '',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                        Text(timeago.format(story.createdAt),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                  if (_isOwn && isCurrent)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.white),
                      onPressed: _confirmDelete,
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
            bottom: 120,
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(story.bgColor),
              Color(story.bgColor).withValues(alpha: 0.75),
            ],
          ),
        ),
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
    return Center(
      child: SmartImage(
        src: story.mediaUrl,
        fit: BoxFit.contain,
        width: double.infinity,
        placeholderColor: Colors.black,
      ),
    );
  }

  Widget _buildReplyBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _reactions
                  .map((e) => GestureDetector(
                        onTap: () => _sendReply(e),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(e,
                              style: const TextStyle(fontSize: 30)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(30),
                      border:
                          Border.all(color: Colors.white.withValues(alpha: 0.5)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: TextField(
                      controller: _replyController,
                      focusNode: _replyFocus,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: Colors.white,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendReply(),
                      decoration: const InputDecoration(
                        hintText: 'Send a reply…',
                        hintStyle: TextStyle(color: Colors.white70),
                        border: InputBorder.none,
                        filled: false,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                  ),
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: () => _sendReply(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerBar() {
    final seen = _story.viewedBy.where((id) => id != _myUid).length;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: GestureDetector(
          onTap: _showViewers,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.visibility_outlined,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                seen == 0 ? 'No views yet' : 'Seen by $seen',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
              if (seen > 0) ...[
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_up_rounded,
                    color: Colors.white70),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewersSheet extends StatelessWidget {
  const _ViewersSheet({required this.viewerIds});
  final List<String> viewerIds;

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('${viewerIds.length} views',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          const Divider(height: 1),
          Expanded(
            child: viewerIds.isEmpty
                ? const Center(child: Text('No one has viewed this yet.'))
                : FutureBuilder<List<UserModel>>(
                    future: fs.getUsers(viewerIds),
                    builder: (context, snap) {
                      final viewers = snap.data ?? [];
                      return ListView.builder(
                        itemCount: viewers.length,
                        itemBuilder: (context, i) {
                          final u = viewers[i];
                          return ListTile(
                            leading: AvatarWidget(
                              photoUrl: u.photoUrl,
                              displayName: u.displayName,
                              size: 42,
                            ),
                            title: Text(u.displayName),
                            subtitle: Text('@${u.username}'),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
