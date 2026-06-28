import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/story_model.dart';
import '../services/firestore_service.dart';

class StoryGroup {
  final String uid;
  final List<StoryModel> stories;
  const StoryGroup(this.uid, this.stories);

  bool hasUnseenFor(String viewerUid) =>
      stories.any((s) => !s.seenBy(viewerUid));
}

/// Streams active (non-expired) stories for the user + their friends, grouped
/// per author for the home story row and the full-screen viewer.
class StoryProvider extends ChangeNotifier {
  StoryProvider(this._fs);

  final FirestoreService _fs;

  String? _boundUid;
  List<String> _boundIds = const [];
  StreamSubscription? _sub;

  List<StoryGroup> _groups = [];
  List<StoryGroup> get groups => _groups;

  StoryGroup? groupFor(String uid) {
    for (final g in _groups) {
      if (g.uid == uid) return g;
    }
    return null;
  }

  void bind(String? uid, List<String> friendIds) {
    if (uid == null) {
      _sub?.cancel();
      _groups = [];
      _boundUid = null;
      _boundIds = const [];
      notifyListeners();
      return;
    }
    final ids = {uid, ...friendIds}.toList();
    if (uid == _boundUid && _sameIds(ids, _boundIds)) return;
    _boundUid = uid;
    _boundIds = ids;

    _sub?.cancel();
    _sub = _fs.activeStoriesFor(ids).listen((stories) {
      final map = <String, List<StoryModel>>{};
      for (final s in stories) {
        if (s.isExpired) continue;
        map.putIfAbsent(s.uid, () => []).add(s);
      }
      for (final list in map.values) {
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
      _groups = map.entries.map((e) => StoryGroup(e.key, e.value)).toList();
      notifyListeners();
    });
  }

  bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sa = a.toSet();
    return b.every(sa.contains);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
