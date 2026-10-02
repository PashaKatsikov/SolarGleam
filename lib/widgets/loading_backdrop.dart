import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../assets.dart';
import '../theme/gleam_theme.dart';

const gameOrientations = <DeviceOrientation>[
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
];

class LoadingBackdrop extends StatelessWidget {
  const LoadingBackdrop({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    final asset = landscape
        ? GleamAssets.horizontalLoading
        : GleamAssets.verticalLoading;
    final image = Image.asset(
      asset,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
    );
    // Phone art matches the loading image. iPad is wider, so cover-crop
    // cuts the logo off and blows a small image up. Fit the whole picture.
    if (size.shortestSide < 600) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: GleamColors.night),
          image,
          ?child,
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final aspect = landscape ? 844 / 390 : 390 / 844;
        var width = maxW;
        var height = width / aspect;
        if (height > maxH) {
          height = maxH;
          width = height * aspect;
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: GleamColors.night),
            Positioned.fill(
              child: ClipRect(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  child: Transform.scale(scale: 1.12, child: image),
                ),
              ),
            ),
            const ColoredBox(color: Color(0x6606040E)),
            Center(
              child: SizedBox(
                width: width,
                height: height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      asset,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                      gaplessPlayback: true,
                    ),
                    ?child,
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
