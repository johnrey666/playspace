import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Shared visual shell for the auth screens: a vibrant gradient hero with
/// floating accent blobs, the brand mark, and a rounded "sheet" that holds the
/// form. Keeps sign-in and sign-up perfectly consistent.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final media = MediaQuery.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: showBack
          ? AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
            )
          : null,
      body: Stack(
        children: [
          // Gradient hero header.
          Container(
            height: media.size.height * 0.42,
            width: double.infinity,
            decoration: const BoxDecoration(gradient: kBrandGradient),
          ),
          // Decorative blobs.
          Positioned(
            top: -40,
            right: -30,
            child: _blob(150, Colors.white.withValues(alpha: 0.14)),
          ),
          Positioned(
            top: media.size.height * 0.18,
            left: -50,
            child: _blob(120, Colors.white.withValues(alpha: 0.10)),
          ),
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: showBack ? 8 : 36),
                _BrandMark(title: title, subtitle: subtitle),
                const SizedBox(height: 24),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32)),
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                          24, 32, 24, media.viewInsets.bottom + 28),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ShaderMask(
            shaderCallback: (b) => kBrandGradient.createShader(b),
            child: const Icon(Icons.sports_esports_rounded,
                color: Colors.white, size: 42),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
