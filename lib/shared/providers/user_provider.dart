import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/firestore_service.dart';

/// Streams the signed-in user's document and caches friend profiles so the
/// rest of the app can resolve uids -> [UserModel] cheaply.
class UserProvider extends ChangeNotifier {
  UserProvider(this._fs);

  final FirestoreService _fs;

  String? _boundUid;
  StreamSubscription? _sub;
  StreamSubscription? _friendsSub;

  UserModel? _user;
  bool _loading = true;
  final Map<String, UserModel> _cache = {};

  UserModel? get user => _user;
  bool get loading => _loading;
  List<String> get friendIds => _user?.friendIds ?? const [];

  UserModel? cached(String uid) => _cache[uid];
  List<UserModel> get friends =>
      friendIds.map((id) => _cache[id]).whereType<UserModel>().toList();

  void bind(String? uid) {
    if (uid == _boundUid) return;
    _boundUid = uid;
    _sub?.cancel();
    _friendsSub?.cancel();
    _user = null;
    _cache.clear();

    if (uid == null) {
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    _sub = _fs.userStream(uid).listen((u) {
      _user = u;
      _loading = false;
      if (u != null) _cache[u.uid] = u;
      _refreshFriends();
      notifyListeners();
    });
  }

  Future<void> _refreshFriends() async {
    final ids = friendIds;
    if (ids.isEmpty) return;
    final missing = ids.where((id) => !_cache.containsKey(id)).toList();
    if (missing.isEmpty) return;
    final fetched = await _fs.getUsers(missing);
    for (final u in fetched) {
      _cache[u.uid] = u;
    }
    notifyListeners();
  }

  /// Ensures a set of uids are present in the cache (e.g. feed authors).
  Future<void> ensureUsers(Iterable<String> uids) async {
    final missing =
        uids.toSet().where((id) => !_cache.containsKey(id)).toList();
    if (missing.isEmpty) return;
    final fetched = await _fs.getUsers(missing);
    for (final u in fetched) {
      _cache[u.uid] = u;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _friendsSub?.cancel();
    super.dispose();
  }
}
