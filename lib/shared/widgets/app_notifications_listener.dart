import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/challenge_model.dart';
import '../models/chat_model.dart';
import '../models/game_catalog.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/local_notification_service.dart';

/// Listens to incoming challenges and chat messages and raises a system
/// notification when the app is in the background. Wraps the signed-in app
/// shell so it lives for the whole authenticated session.
class AppNotificationsListener extends StatefulWidget {
  const AppNotificationsListener({
    super.key,
    required this.uid,
    required this.child,
  });

  final String uid;
  final Widget child;

  @override
  State<AppNotificationsListener> createState() =>
      _AppNotificationsListenerState();
}

class _AppNotificationsListenerState extends State<AppNotificationsListener>
    with WidgetsBindingObserver {
  late final FirestoreService _fs = context.read<FirestoreService>();
  late final LocalNotificationService _notifier =
      context.read<LocalNotificationService>();

  StreamSubscription? _challengeSub;
  StreamSubscription? _chatSub;

  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  // Baselines so we only notify for activity that arrives *after* startup.
  final Set<String> _seenChallengeIds = {};
  bool _challengesPrimed = false;
  final Map<String, DateTime> _lastMessageAt = {};
  bool _chatsPrimed = false;

  // Cache to label PM notifications with the sender's name.
  final Map<String, UserModel> _userCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notifier.init();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant AppNotificationsListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _resetAndResubscribe();
    }
  }

  void _resetAndResubscribe() {
    _challengeSub?.cancel();
    _chatSub?.cancel();
    _seenChallengeIds.clear();
    _challengesPrimed = false;
    _lastMessageAt.clear();
    _chatsPrimed = false;
    _subscribe();
  }

  void _subscribe() {
    _challengeSub =
        _fs.incomingChallenges(widget.uid).listen(_onChallenges, onError: (_) {});
    _chatSub = _fs.chatsFor(widget.uid).listen(_onChats, onError: (_) {});
  }

  bool get _inBackground => _lifecycle != AppLifecycleState.resumed;

  void _onChallenges(List<ChallengeModel> challenges) {
    if (!_challengesPrimed) {
      _challengesPrimed = true;
      for (final c in challenges) {
        _seenChallengeIds.add(c.id);
      }
      return;
    }
    for (final c in challenges) {
      if (_seenChallengeIds.contains(c.id)) continue;
      _seenChallengeIds.add(c.id);
      // Only fresh challenges, and only when the user is away.
      if (DateTime.now().difference(c.createdAt) >
          const Duration(seconds: 30)) {
        continue;
      }
      if (!_inBackground) continue;
      _notifyChallenge(c);
    }
  }

  Future<void> _notifyChallenge(ChallengeModel c) async {
    final from = await _resolveUser(c.fromUid);
    final game = GameCatalog.byId(c.gameId);
    await _notifier.show(
      title: '${from?.displayName ?? 'A friend'} challenged you!',
      body: 'Tap to play ${game.name} now.',
    );
  }

  void _onChats(List<ChatModel> chats) {
    if (!_chatsPrimed) {
      _chatsPrimed = true;
      for (final chat in chats) {
        if (chat.lastMessageAt != null) {
          _lastMessageAt[chat.id] = chat.lastMessageAt!;
        }
      }
      return;
    }
    for (final chat in chats) {
      final at = chat.lastMessageAt;
      if (at == null) continue;
      final prev = _lastMessageAt[chat.id];
      _lastMessageAt[chat.id] = at;
      if (prev == null || !at.isAfter(prev)) continue;
      // A newer message exists. Only alert if it isn't mine (unread for me)
      // and the app is in the background.
      if (chat.unreadFor(widget.uid) <= 0) continue;
      if (!_inBackground) continue;
      _notifyMessage(chat);
    }
  }

  Future<void> _notifyMessage(ChatModel chat) async {
    String title;
    if (chat.isGroupChat) {
      title = chat.groupName ?? 'New message';
    } else {
      final other = await _resolveUser(chat.otherMemberId(widget.uid));
      title = other?.displayName ?? 'New message';
    }
    final body =
        chat.lastMessage.isEmpty ? 'Sent you a message' : chat.lastMessage;
    await _notifier.show(title: title, body: body);
  }

  Future<UserModel?> _resolveUser(String uid) async {
    if (_userCache.containsKey(uid)) return _userCache[uid];
    try {
      final user = await _fs.getUser(uid);
      if (user != null) _userCache[uid] = user;
      return user;
    } catch (_) {
      return null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _challengeSub?.cancel();
    _chatSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
