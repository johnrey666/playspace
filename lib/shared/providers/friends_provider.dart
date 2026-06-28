import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/challenge_model.dart';
import '../models/friend_request_model.dart';
import '../services/firestore_service.dart';

/// Exposes incoming friend requests and challenges for the signed-in user,
/// powering the notification bell badge and the home-screen challenge banner.
class FriendsProvider extends ChangeNotifier {
  FriendsProvider(this._fs);

  final FirestoreService _fs;

  /// Challenges expire (and stop showing) this long after they're created.
  static const Duration challengeTtl = Duration(seconds: 20);

  String? _boundUid;
  StreamSubscription? _reqSub;
  StreamSubscription? _challengeSub;
  Timer? _expiryTimer;

  List<FriendRequestModel> _requests = [];
  List<ChallengeModel> _allChallenges = [];
  List<ChallengeModel> _challenges = [];

  List<FriendRequestModel> get requests => _requests;

  /// Only non-expired challenges are surfaced to the UI.
  List<ChallengeModel> get challenges => _challenges;
  ChallengeModel? get topChallenge =>
      _challenges.isNotEmpty ? _challenges.first : null;

  // Challenges are intentionally excluded from the bell count: they only live
  // on the home banner now.
  int get notificationCount => _requests.length;
  bool get hasNotifications => notificationCount > 0;

  void bind(String? uid) {
    if (uid == _boundUid) return;
    _boundUid = uid;
    _reqSub?.cancel();
    _challengeSub?.cancel();
    _expiryTimer?.cancel();
    _requests = [];
    _allChallenges = [];
    _challenges = [];

    if (uid == null) {
      notifyListeners();
      return;
    }

    _reqSub = _fs.incomingRequests(uid).listen((r) {
      _requests = r;
      notifyListeners();
    });
    _challengeSub = _fs.incomingChallenges(uid).listen((c) {
      _allChallenges = c;
      _recomputeChallenges();
    });
  }

  void _recomputeChallenges() {
    final now = DateTime.now();
    _challenges = _allChallenges
        .where((c) => now.difference(c.createdAt) < challengeTtl)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _expiryTimer?.cancel();
    if (_challenges.isNotEmpty) {
      // Re-evaluate when the soonest-to-expire challenge lapses.
      var soonest = challengeTtl;
      for (final c in _challenges) {
        final remaining = challengeTtl - now.difference(c.createdAt);
        if (remaining < soonest) soonest = remaining;
      }
      _expiryTimer = Timer(
        soonest + const Duration(milliseconds: 250),
        _recomputeChallenges,
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _reqSub?.cancel();
    _challengeSub?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }
}
