import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Image handling that works entirely on Firebase's free (Spark) plan.
///
/// Firebase Storage now requires the Blaze plan, so instead of uploading files
/// we compress images on-device and store them directly in Firestore as a
/// base64 `data:` URI string. The same string is rendered by [SmartImage] and
/// [AvatarWidget], whether it's a data URI or a regular network URL.
class Media {
  Media._();

  static final _picker = ImagePicker();

  /// True when [src] is an embedded base64 data URI (stored in Firestore).
  static bool isDataUri(String? src) =>
      src != null && src.startsWith('data:image');

  static bool _isNetwork(String? src) =>
      src != null && (src.startsWith('http://') || src.startsWith('https://'));

  /// Picks an image and returns it as a compressed base64 data URI, or null if
  /// the user cancelled. [maxWidth]/[quality] keep the encoded size well under
  /// Firestore's 1 MB document limit.
  static Future<String?> pickAsDataUri({
    required ImageSource source,
    int maxWidth = 900,
    int quality = 55,
  }) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: maxWidth.toDouble(),
      imageQuality: quality,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  /// Decodes the base64 payload of a data URI to raw bytes.
  static Uint8List? bytesFromDataUri(String src) {
    final comma = src.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(src.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  /// Builds an [ImageProvider] for either a data URI or a network URL.
  static ImageProvider? providerFor(String? src) {
    if (src == null || src.isEmpty) return null;
    if (isDataUri(src)) {
      final bytes = bytesFromDataUri(src);
      return bytes == null ? null : MemoryImage(bytes);
    }
    if (_isNetwork(src)) return CachedNetworkImageProvider(src);
    return null;
  }
}

/// Renders an image from a base64 data URI or a network URL with graceful
/// placeholder / error states.
class SmartImage extends StatelessWidget {
  const SmartImage({
    super.key,
    required this.src,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholderColor,
  });

  final String? src;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Color? placeholderColor;

  @override
  Widget build(BuildContext context) {
    final provider = Media.providerFor(src);
    if (provider == null) {
      return Container(
        width: width,
        height: height,
        color: placeholderColor ?? Colors.black12,
        child: const Icon(Icons.image_not_supported_outlined,
            color: Colors.white54),
      );
    }
    return Image(
      image: provider,
      fit: fit,
      width: width,
      height: height,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => Container(
        width: width,
        height: height,
        color: placeholderColor ?? Colors.black12,
        child: const Icon(Icons.broken_image_outlined, color: Colors.white54),
      ),
    );
  }
}
