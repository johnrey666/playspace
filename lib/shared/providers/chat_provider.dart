import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_model.dart';
import '../services/firestore_service.dart';

/// Streams the user's conversations and computes the total unread badge shown
/// on the Chat tab of the bottom navigation.
class ChatProvider extends ChangeNotifier {
  ChatProvider(this._fs);

  final FirestoreService _fs;

  String? _boundUid;
  StreamSubscription? _sub;
  List<ChatModel> _chats = [];

  List<ChatModel> get chats => _chats;

  int get totalUnread {
    if (_boundUid == null) return 0;
    return _chats.fold(0, (sum, c) => sum + c.unreadFor(_boundUid!));
  }

  void bind(String? uid) {
    if (uid == _boundUid) return;
    _boundUid = uid;
    _sub?.cancel();
    _chats = [];

    if (uid == null) {
      notifyListeners();
      return;
    }
    _sub = _fs.chatsFor(uid).listen((c) {
      _chats = c;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
