import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/call/incoming_call_screen.dart';
import '../models/call_model.dart';
import '../services/call_service.dart';

/// Watches for incoming calls addressed to the signed-in user and presents the
/// full-screen ringing UI. Lives for the whole authenticated session.
class CallListener extends StatefulWidget {
  const CallListener({super.key, required this.uid, required this.child});

  final String uid;
  final Widget child;

  @override
  State<CallListener> createState() => _CallListenerState();
}

class _CallListenerState extends State<CallListener> {
  late final CallService _calls = context.read<CallService>();
  StreamSubscription? _sub;
  final Set<String> _shownIds = {};
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant CallListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _sub?.cancel();
      _shownIds.clear();
      _subscribe();
    }
  }

  void _subscribe() {
    _sub = _calls.incomingCalls(widget.uid).listen(_onCalls, onError: (_) {});
  }

  void _onCalls(List<CallModel> calls) {
    if (_active) return;
    for (final call in calls) {
      if (_shownIds.contains(call.id)) continue;
      // Ignore stale ringing docs left over from a previous session.
      if (DateTime.now().difference(call.createdAt) >
          const Duration(seconds: 60)) {
        _shownIds.add(call.id);
        continue;
      }
      _shownIds.add(call.id);
      _present(call);
      break;
    }
  }

  Future<void> _present(CallModel call) async {
    _active = true;
    await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => IncomingCallScreen(call: call),
    ));
    _active = false;
    // Re-check in case another call queued up while this one was on screen.
    if (mounted) {
      final fresh = await _calls.incomingCalls(widget.uid).first;
      _onCalls(fresh);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
