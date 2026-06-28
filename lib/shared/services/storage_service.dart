import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;
  final _uuid = const Uuid();

  Future<String> _upload(String path, File file) async {
    final ref = _storage.ref().child(path);
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }

  Future<String> uploadProfilePhoto(String uid, File file) =>
      _upload('profile_photos/$uid.jpg', file);

  Future<String> uploadStoryMedia(String uid, File file) =>
      _upload('stories/$uid/${_uuid.v4()}.jpg', file);

  Future<String> uploadGroupPhoto(File file) =>
      _upload('group_photos/${_uuid.v4()}.jpg', file);
}
