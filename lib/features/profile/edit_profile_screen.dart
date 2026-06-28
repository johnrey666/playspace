import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../shared/models/user_model.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/utils/media.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/avatar_widget.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user});
  final UserModel user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _displayName =
      TextEditingController(text: widget.user.displayName);
  late final TextEditingController _bio =
      TextEditingController(text: widget.user.bio);
  String? _pickedData; // base64 data URI
  bool _saving = false;

  @override
  void dispose() {
    _displayName.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // Profile photos are kept small (square-ish) so they're cheap to store as
    // base64 in the user document and fast to load everywhere.
    final data = await Media.pickAsDataUri(
        source: ImageSource.gallery, maxWidth: 400, quality: 60);
    if (data != null) setState(() => _pickedData = data);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final fs = context.read<FirestoreService>();
      final String? photoUrl = _pickedData ?? widget.user.photoUrl;
      await fs.updateUser(widget.user.uid, {
        'displayName': _displayName.text.trim(),
        'bio': _bio.text.trim(),
        'photoUrl': photoUrl,
      });
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save changes.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Stack(
              children: [
                _pickedData != null
                    ? CircleAvatar(
                        radius: 52,
                        backgroundImage: Media.providerFor(_pickedData))
                    : AvatarWidget(
                        photoUrl: widget.user.photoUrl,
                        displayName: widget.user.displayName,
                        size: 104,
                      ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _displayName,
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bio,
            maxLines: 3,
            maxLength: 160,
            decoration: const InputDecoration(labelText: 'Bio'),
          ),
          const SizedBox(height: 16),
          TextField(
            enabled: false,
            decoration: InputDecoration(
              labelText: 'Username',
              hintText: '@${widget.user.username}',
            ),
          ),
          const SizedBox(height: 24),
          AppButton(label: 'Save', loading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
