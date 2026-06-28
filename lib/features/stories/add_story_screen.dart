import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../shared/models/story_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/utils/media.dart';
import '../../shared/widgets/app_button.dart';

const _textBgColors = [
  0xFF2563EB,
  0xFF7C3AED,
  0xFFEC4899,
  0xFFEF4444,
  0xFFF59E0B,
  0xFF10B981,
  0xFF111827,
];

class AddStoryScreen extends StatefulWidget {
  const AddStoryScreen({super.key});

  @override
  State<AddStoryScreen> createState() => _AddStoryScreenState();
}

class _AddStoryScreenState extends State<AddStoryScreen> {
  final _caption = TextEditingController();
  final _textStory = TextEditingController();
  String? _imageData; // base64 data URI
  int _bgColor = _textBgColors.first;
  bool _textMode = false;
  bool _posting = false;

  @override
  void dispose() {
    _caption.dispose();
    _textStory.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final data = await Media.pickAsDataUri(
        source: source, maxWidth: 1000, quality: 60);
    if (data != null) {
      setState(() {
        _imageData = data;
        _textMode = false;
      });
    }
  }

  Future<void> _post() async {
    final myUid = context.read<AuthProvider>().uid!;
    final fs = context.read<FirestoreService>();

    if (!_textMode && _imageData == null) return;
    if (_textMode && _textStory.text.trim().isEmpty) return;

    setState(() => _posting = true);
    try {
      final now = DateTime.now();
      // Stored straight into Firestore as a base64 data URI (free-tier; no
      // Firebase Storage needed).
      final String? mediaUrl = _textMode ? null : _imageData;
      await fs.addStory(StoryModel(
        id: '',
        uid: myUid,
        mediaUrl: mediaUrl,
        mediaType: _textMode ? StoryMediaType.text : StoryMediaType.image,
        caption: _textMode ? _textStory.text.trim() : _caption.text.trim(),
        bgColor: _bgColor,
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
        viewedBy: const [],
      ));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _posting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not post story.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add to My Day'),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _textMode = !_textMode;
              _imageData = null;
            }),
            child: Text(_textMode ? 'Photo' : 'Text'),
          ),
        ],
      ),
      body: _textMode ? _buildTextStory() : _buildMediaStory(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AppButton(
            label: 'Share to My Day',
            loading: _posting,
            onPressed: _post,
          ),
        ),
      ),
    );
  }

  Widget _buildTextStory() {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(_bgColor),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24),
            child: TextField(
              controller: _textStory,
              maxLines: null,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
              cursorColor: Colors.white,
              decoration: const InputDecoration(
                border: InputBorder.none,
                filled: false,
                hintText: 'Type something…',
                hintStyle: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _textBgColors
                .map((c) => GestureDetector(
                      onTap: () => setState(() => _bgColor = c),
                      child: Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _bgColor == c
                                ? Colors.white
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildMediaStory() {
    return Column(
      children: [
        Expanded(
          child: _imageData == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_library_outlined, size: 64),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _pick(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_rounded),
                            label: const Text('Camera'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => _pick(ImageSource.gallery),
                            icon: const Icon(Icons.image_rounded),
                            label: const Text('Gallery'),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SmartImage(
                        src: _imageData,
                        fit: BoxFit.cover,
                        width: double.infinity),
                  ),
                ),
        ),
        if (_imageData != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _caption,
              decoration: const InputDecoration(labelText: 'Caption (optional)'),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}
