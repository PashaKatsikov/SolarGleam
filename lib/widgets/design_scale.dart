import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/neon_theme.dart';

/// Lays a screen out in a fixed "design space" about 400 points wide and
/// scales it up on iPad, so one layout serves every portrait device.
///
/// The background is painted by the caller across the whole screen; only the
/// content lives in the scaled box.
class DesignScale extends StatelessWidget {
  const DesignScale({super.key, required this.child, this.maxWidth = 440});

  final Widget child;
  final double maxWidth;

  static double factor(Size size) =>
      (math.min(size.width, size.height) / 400).clamp(1.0, 1.55);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final u = factor(Size(w, h));
        final designW = math.min(w / u, maxWidth);
        final designH = h / u;
        return Center(
          child: SizedBox(
            width: designW * u,
            height: h,
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: designW,
                height: designH,
                child: MediaQuery(
                  data: media.copyWith(
                    size: Size(designW, designH),
                    padding: media.padding / u,
                    viewPadding: media.viewPadding / u,
                    viewInsets: media.viewInsets / u,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Screen shell: full-bleed background plus scaled content.
class NeonScaffold extends StatelessWidget {
  const NeonScaffold({super.key, required this.background, required this.child});

  final Widget background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Neon.void0,
      body: Stack(
        fit: StackFit.expand,
        children: [
          background,
          DesignScale(child: child),
        ],
      ),
    );
  }
}
