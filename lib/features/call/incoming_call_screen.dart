import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/models/call_model.dart';
import '../../shared/services/call_service.dart';
import '../../shared/widgets/avatar_widget.dart';
import 'call_screen.dart';

/// Full-screen ringing UI shown to the person being called. Accepting drops
/// straight into the live [CallScreen] as the callee; declining ends the call.
class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key, required this.call});

  final CallModel call;

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  late final CallService _calls = context.read<CallService>();
  StreamSubscription? _sub;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    // Auto-dismiss if the caller cancels before we answer.
    _sub = _calls.callStream(widget.call.id).listen((call) {
      if (_handled) return;
      if (call == null ||
          call.status == CallStatus.ended ||
          call.status == CallStatus.declined) {
        _handled = true;
        if (mounted) Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_handled) return;
    _handled = true;
    final navigator = Navigator.of(context);
    navigator.pushReplacement(MaterialPageRoute(
      builder: (_) => CallScreen(
        callId: widget.call.id,
        isCaller: false,
        type: widget.call.type,
        otherName: widget.call.callerName,
        otherPhoto: widget.call.callerPhoto,
      ),
    ));
  }

  Future<void> _decline() async {
    if (_handled) return;
    _handled = true;
    await _calls.setStatus(widget.call.id, CallStatus.declined);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2B2D5B), Color(0xFF0E0F1A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              AvatarWidget(
                photoUrl: call.callerPhoto,
                displayName: call.callerName,
                size: 130,
              ),
              const SizedBox(height: 24),
              Text(call.callerName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                call.isVideo ? 'Incoming video call…' : 'Incoming voice call…',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _AnswerButton(
                      icon: Icons.call_end_rounded,
                      color: Colors.red,
                      label: 'Decline',
                      onTap: _decline,
                    ),
                    _AnswerButton(
                      icon: call.isVideo
                          ? Icons.videocam_rounded
                          : Icons.call_rounded,
                      color: Colors.green,
                      label: 'Accept',
                      onTap: _accept,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}
