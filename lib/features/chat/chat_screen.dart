import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../shared/models/call_model.dart';
import '../../shared/models/chat_model.dart';
import '../../shared/models/message_model.dart';
import '../../shared/models/user_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/utils/media.dart';
import '../../shared/widgets/avatar_widget.dart';
import '../../shared/widgets/error_state_widget.dart';
import '../call/call_screen.dart';
import 'group_info_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chatId});
  final String chatId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  ChatModel? _chat;
  bool _sending = false;

  late final String _myUid = context.read<AuthProvider>().uid!;
  late final FirestoreService _fs = context.read<FirestoreService>();
  bool _startingCall = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  Future<void> _markRead() async {
    await _fs.markChatRead(widget.chatId, _myUid);
    await _fs.markMessagesRead(widget.chatId, _myUid);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _chat == null) return;
    _controller.clear();
    setState(() => _sending = true);
    try {
      await _fs.sendMessage(chat: _chat!, senderUid: _myUid, text: text);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendImage() async {
    if (_chat == null) return;
    final source = await _pickSource();
    if (source == null) return;
    setState(() => _sending = true);
    try {
      final data =
          await Media.pickAsDataUri(source: source, maxWidth: 1000, quality: 55);
      if (data == null) return;
      await _fs.sendMessage(
          chat: _chat!, senderUid: _myUid, text: '', imageUrl: data);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not send photo.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _startCall(CallType type) async {
    final chat = _chat;
    if (chat == null || chat.isGroupChat || _startingCall) return;
    setState(() => _startingCall = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final me = context.read<UserProvider>().user;
      final other = await _fs.getUser(chat.otherMemberId(_myUid));
      if (!mounted) return;
      if (me == null || other == null) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Could not start the call.')));
        return;
      }
      // Open the call screen immediately; it creates the call document itself,
      // so the UI never just "does nothing" if the network is slow.
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CallScreen(
          isCaller: true,
          type: type,
          otherName: other.displayName,
          otherPhoto: other.photoUrl,
          me: me,
          other: other,
        ),
      ));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not start the call.')));
    } finally {
      if (mounted) setState(() => _startingCall = false);
    }
  }

  Future<ImageSource?> _pickSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ChatModel>(
      stream: _fs.chatStream(widget.chatId),
      builder: (context, chatSnap) {
        _chat = chatSnap.data;
        return Scaffold(
          appBar: AppBar(
            title: _chat == null
                ? const Text('Chat')
                : _ChatTitle(chat: _chat!, myUid: _myUid),
            actions: [
              if (_chat != null && !_chat!.isGroupChat) ...[
                IconButton(
                  icon: const Icon(Icons.call_rounded),
                  tooltip: 'Voice call',
                  onPressed:
                      _startingCall ? null : () => _startCall(CallType.audio),
                ),
                IconButton(
                  icon: const Icon(Icons.videocam_rounded),
                  tooltip: 'Video call',
                  onPressed:
                      _startingCall ? null : () => _startCall(CallType.video),
                ),
              ],
              if (_chat?.isGroupChat == true)
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => GroupInfoScreen(chatId: widget.chatId),
                  )),
                ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.04),
                  Theme.of(context).colorScheme.surface,
                ],
              ),
            ),
            child: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: _fs.messages(widget.chatId),
                  builder: (context, snap) {
                    if (snap.hasError) return const ErrorStateWidget();
                    final messages = snap.data ?? [];
                    if (messages.isEmpty) {
                      return const EmptyStateWidget(
                        message: 'Say hi!',
                        icon: Icons.waving_hand_rounded,
                      );
                    }
                    // Mark newly arrived messages as read.
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _markRead());
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, i) {
                        final m = messages[i];
                        return _MessageBubble(
                          message: m,
                          isMine: m.senderUid == _myUid,
                          chat: _chat,
                          myUid: _myUid,
                        );
                      },
                    );
                  },
                ),
              ),
              _Composer(
                controller: _controller,
                sending: _sending,
                onSend: _send,
                onSendImage: _sendImage,
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}

class _ChatTitle extends StatelessWidget {
  const _ChatTitle({required this.chat, required this.myUid});
  final ChatModel chat;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    if (chat.isGroupChat) {
      return Row(
        children: [
          AvatarWidget(
            photoUrl: chat.groupPhotoUrl,
            displayName: chat.groupName ?? 'Group',
            size: 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(chat.groupName ?? 'Group',
                overflow: TextOverflow.ellipsis),
          ),
        ],
      );
    }
    final fs = context.read<FirestoreService>();
    return FutureBuilder<UserModel?>(
      future: fs.getUser(chat.otherMemberId(myUid)),
      builder: (context, snap) {
        final user = snap.data;
        return Row(
          children: [
            AvatarWidget(
              photoUrl: user?.photoUrl,
              displayName: user?.displayName ?? '',
              size: 36,
              isOnline: user?.isPresent ?? false,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(user?.displayName ?? 'Chat',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16)),
                  if (user?.isPresent ?? false)
                    const Text('online',
                        style: TextStyle(fontSize: 11, color: Colors.green)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.chat,
    required this.myUid,
  });

  final MessageModel message;
  final bool isMine;
  final ChatModel? chat;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final others = (chat?.memberIds ?? []).where((id) => id != myUid).toList();
    final readByAll =
        others.isNotEmpty && others.every(message.readBy.contains);

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMine ? 18 : 4),
      bottomRight: Radius.circular(isMine ? 4 : 18),
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.symmetric(
            horizontal: 14, vertical: message.hasImage ? 6 : 10),
        decoration: BoxDecoration(
          color: isMine ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: radius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (message.isStoryReply) ...[
              GestureDetector(
                onTap: () =>
                    _openFullImage(context, message.storyPreviewUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: IntrinsicHeight(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 3,
                          color: isMine ? Colors.white70 : scheme.primary,
                        ),
                        Container(
                          color: (isMine ? Colors.white : scheme.onSurface)
                              .withValues(alpha: 0.12),
                          padding: const EdgeInsets.all(6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SmartImage(
                                  src: message.storyPreviewUrl,
                                  width: 42,
                                  height: 42,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Replied to story',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: (isMine
                                          ? Colors.white
                                          : scheme.onSurface)
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (message.hasImage) ...[
              GestureDetector(
                onTap: () => _openFullImage(context, message.imageUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SmartImage(
                    src: message.imageUrl,
                    fit: BoxFit.cover,
                    width: 220,
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (message.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  message.text,
                  style: TextStyle(
                      color: isMine ? Colors.white : scheme.onSurface),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat.Hm().format(message.sentAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: (isMine ? Colors.white : scheme.onSurface)
                        .withValues(alpha: 0.7),
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    readByAll ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 14,
                    color: readByAll
                        ? Colors.lightBlueAccent
                        : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens a tappable full-screen viewer for a chat photo.
void _openFullImage(BuildContext context, String src) {
  Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 4,
          child: SmartImage(
              src: src, fit: BoxFit.contain, placeholderColor: Colors.black),
        ),
      ),
    ),
  ));
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onSendImage,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onSendImage;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            IconButton(
              onPressed: sending ? null : onSendImage,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              tooltip: 'Send photo',
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Message',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sending ? null : onSend,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
