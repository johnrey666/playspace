import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Wraps any skeleton layout in a shimmering effect that adapts to the theme.
class ShimmerLoader extends StatelessWidget {
  const ShimmerLoader({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHighest,
      highlightColor: scheme.surfaceContainerHigh,
      child: child,
    );
  }
}

class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = 12,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A vertical list of card-shaped skeletons for feed/list loading states.
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoader(
      child: Column(
        children: List.generate(
          count,
          (_) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(
                  children: [
                    ShimmerBox(width: 44, height: 44, radius: 22),
                    SizedBox(width: 12),
                    Expanded(child: ShimmerBox(height: 14)),
                  ],
                ),
                SizedBox(height: 16),
                ShimmerBox(height: 12),
                SizedBox(height: 8),
                ShimmerBox(height: 12, width: 180),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
