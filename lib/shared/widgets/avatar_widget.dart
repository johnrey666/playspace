import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../utils/media.dart';

enum StoryRing { none, unseen, seen }

class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    this.photoUrl,
    this.displayName = '',
    this.size = 44,
    this.isOnline = false,
    this.ring = StoryRing.none,
    this.onTap,
  });

  final String? photoUrl;
  final String displayName;
  final double size;
  final bool isOnline;
  final StoryRing ring;
  final VoidCallback? onTap;

  String get _initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasPhoto ? null : kBrandGradient,
        color: hasPhoto ? scheme.surfaceContainerHighest : null,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: hasPhoto
          ? SmartImage(
              src: photoUrl,
              fit: BoxFit.cover,
              width: size,
              height: size,
            )
          : _initialsText(),
    );

    if (ring != StoryRing.none) {
      final unseen = ring == StoryRing.unseen;
      avatar = Container(
        padding: const EdgeInsets.all(2.6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: unseen ? kBrandGradient : null,
          color: unseen ? null : scheme.outlineVariant,
        ),
        child: Container(
          padding: const EdgeInsets.all(2.4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.surface,
          ),
          child: avatar,
        ),
      );
    }

    Widget result = avatar;
    if (isOnline) {
      result = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: AppTheme.online,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 2),
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: result);
    }
    return result;
  }

  Widget _initialsText() => Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
        ),
      );
}
