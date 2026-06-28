import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/services/random_chat_service.dart';

class RandomChatScreen extends StatefulWidget {
  const RandomChatScreen({super.key});

  @override
  State<RandomChatScreen> createState() => _RandomChatScreenState();
}

enum _Phase { searching, chatting, ended }

class _RandomChatScreenState extends State<RandomChatScreen> {
  late final RandomChatService _service = context.read<RandomChatService>();
  late final String _myUid = context.read<AuthProvider>().uid!;

  StreamSubscription<String?>? _roomSub;
  _Phase _phase = _Phase.searching;
  String? _roomId;

  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _startSearch();
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _controller.dispose();
    _scroll.dispose();
    // Best-effort: leave queue if still searching.
    if (_phase == _Phase.searching) _service.leave(_myUid);
    super.dispose();
  }

  Future<void> _startSearch() async {
    setState(() {
      _phase = _Phase.searching;
      _roomId = null;
    });
    _roomSub?.cancel();

    // Listen for a room assigned to us (whether we created it or a partner did).
    _roomSub = _service.myRoomStream(_myUid).listen((roomId) {
      if (roomId != null && _roomId != roomId && mounted) {
        setState(() {
          _roomId = roomId;
          _phase = _Phase.chatting;
        });
      }
    });

    try {
      final result = await _service.findOrQueue(_myUid);
      if (result.roomId != null && mounted) {
        setState(() {
          _roomId = result.roomId;
          _phase = _Phase.chatting;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not find a match. Retry.')));
      }
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _roomId == null) return;
    _controller.clear();
    await _service.sendMessage(_roomId!, _myUid, text);
  }

  Future<void> _endChat() async {
    if (_roomId != null) {
      await _service.endChat(_roomId!, _myUid);
    }
    if (mounted) setState(() => _phase = _Phase.ended);
  }

  Future<void> _newChat() async {
    _roomId = null;
    await _startSearch();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (_phase == _Phase.searching) _service.cancelQueue(_myUid);
        if (_phase == _Phase.chatting && _roomId != null) {
          _service.endChat(_roomId!, _myUid);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Random Chat'),
          actions: [
            if (_phase == _Phase.chatting)
              TextButton(
                onPressed: _endChat,
                child: const Text('End'),
              ),
          ],
        ),
        body: switch (_phase) {
          _Phase.searching => _SearchingView(onCancel: () {
              _service.cancelQueue(_myUid);
              Navigator.of(context).pop();
            }),
          _Phase.chatting => _ChatView(
              roomId: _roomId!,
              myUid: _myUid,
              service: _service,
              controller: _controller,
              scroll: _scroll,
              onSend: _send,
            ),
          _Phase.ended => _EndedView(onNew: _newChat),
        },
      ),
    );
  }
}

class _SearchingView extends StatelessWidget {
  const _SearchingView({required this.onCancel});
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: kBrandGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.violet.withValues(alpha: 0.4),
                  blurRadius: 30,
                ),
              ],
            ),
            child: const Icon(Icons.shuffle_rounded,
                color: Colors.white, size: 48),
          ),
          const SizedBox(height: 28),
          const Text('Finding a stranger…',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 8),
          Text('You\'ll be matched anonymously',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
          const SizedBox(height: 32),
          OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
        ],
      ),
    );
  }
}

class _EndedView extends StatelessWidget {
  const _EndedView({required this.onNew});
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.waving_hand_rounded,
                size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const Text('Chat ended',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 8),
            Text('Start a new chat to meet someone else.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onNew,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('New chat'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to chats'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView({
    required this.roomId,
    required this.myUid,
    required this.service,
    required this.controller,
    required this.scroll,
    required this.onSend,
  });

  final String roomId;
  final String myUid;
  final RandomChatService service;
  final TextEditingController controller;
  final ScrollController scroll;
  final VoidCallback onSend;

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: colors.primaryContainer.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Text(
            'You\'re chatting anonymously with a Stranger',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: StreamBuilder<DatabaseEvent>(
            stream: widget.service.roomStream(widget.roomId),
            builder: (context, snap) {
              final value = snap.data?.snapshot.value;
              if (value is! Map) {
                return const Center(child: CircularProgressIndicator());
              }
              final active = value['active'] != false;
              final messages = _parseMessages(value['messages']);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (widget.scroll.hasClients) {
                  widget.scroll.animateTo(
                    widget.scroll.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                }
              });
              return Column(
                children: [
                  if (!active)
                    Container(
                      width: double.infinity,
                      color: Colors.red.withValues(alpha: 0.1),
                      padding: const EdgeInsets.all(8),
                      child: const Text('The stranger left the chat.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600)),
                    ),
                  Expanded(
                    child: messages.isEmpty
                        ? Center(
                            child: Text('Say hi 👋',
                                style: TextStyle(
                                    color: colors.onSurfaceVariant)),
                          )
                        : ListView.builder(
                            controller: widget.scroll,
                            padding: const EdgeInsets.all(12),
                            itemCount: messages.length,
                            itemBuilder: (context, i) {
                              final m = messages[i];
                              final mine = m.sender == widget.myUid;
                              return Align(
                                alignment: mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context)
                                              .size
                                              .width *
                                          0.72),
                                  decoration: BoxDecoration(
                                    color: mine
                                        ? colors.primary
                                        : colors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(18),
                                      topRight: const Radius.circular(18),
                                      bottomLeft:
                                          Radius.circular(mine ? 18 : 4),
                                      bottomRight:
                                          Radius.circular(mine ? 4 : 18),
                                    ),
                                  ),
                                  child: Text(
                                    m.text,
                                    style: TextStyle(
                                        color: mine
                                            ? Colors.white
                                            : colors.onSurface),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    decoration:
                        const InputDecoration(hintText: 'Message…'),
                    onSubmitted: (_) => widget.onSend(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: widget.onSend,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<_Msg> _parseMessages(Object? value) {
    if (value is! Map) return [];
    final list = <_Msg>[];
    value.forEach((key, v) {
      if (v is Map) {
        list.add(_Msg(
          v['sender']?.toString() ?? '',
          v['text']?.toString() ?? '',
          (v['at'] as num?)?.toInt() ?? 0,
        ));
      }
    });
    list.sort((a, b) => a.at.compareTo(b.at));
    return list;
  }
}

class _Msg {
  final String sender;
  final String text;
  final int at;
  const _Msg(this.sender, this.text, this.at);
}
