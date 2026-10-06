import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/gleam_theme.dart';

/// Circular profile avatar: shows the chosen photo (cover-fit, EXIF-normalised
/// by the picker) or a placeholder. When [onTap] is set it behaves as a button
/// (tap to change); [showBadge] draws the small camera badge used on the
/// editable avatar. In display-only spots (e.g. the in-game HUD) both are
/// left off.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.photoPath,
    this.onTap,
    this.size = 96,
    this.showBadge = true,
    this.borderWidth = 2.4,
  });

  final String? photoPath;
  final VoidCallback? onTap;
  final double size;
  final bool showBadge;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    final circle = SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: <Color>[Color(0xFF241A3C), Color(0xFF130C24)],
              ),
              border: Border.all(color: GleamColors.gold, width: borderWidth),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x66F0A020), blurRadius: 18),
              ],
            ),
            child: ClipOval(
              child: path == null
                  ? Icon(
                      Icons.person_rounded,
                      size: size * 0.56,
                      color: GleamColors.gold.withValues(alpha: 0.85),
                    )
                  : Image.file(
                      File(path),
                      key: ValueKey<String>(path),
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.person_rounded,
                        size: size * 0.56,
                        color: GleamColors.gold.withValues(alpha: 0.85),
                      ),
                    ),
            ),
          ),
          if (showBadge)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: size * 0.34,
                height: size * 0.34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: GleamColors.goldDeep,
                  border: Border.all(color: GleamColors.night, width: 2),
                ),
                child: Icon(
                  Icons.photo_camera_rounded,
                  size: size * 0.18,
                  color: GleamColors.ink,
                ),
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return circle;

    return Semantics(
      button: true,
      label: 'Profile photo',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: circle,
      ),
    );
  }
}
