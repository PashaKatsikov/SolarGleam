import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../game/world_data.dart';
import '../theme/neon_theme.dart';
import 'design_scale.dart';
import 'neon_ui.dart';
import 'orb_view.dart';

/// Opens a centred glass card above the current screen.
Future<void> showNeonDialog(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  Sound.instance.play(Sfx.open);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.7),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, a, b) => DesignScale(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Material(color: Colors.transparent, child: Builder(builder: builder)),
        ),
      ),
    ),
    transitionBuilder: (context, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween<double>(begin: 0.9, end: 1).animate(curved), child: child),
      );
    },
  );
}

/// The story fragment a finished region hands out.
Future<void> showMemoryDialog(BuildContext context, RegionDef region) {
  return showNeonDialog(
    context,
    builder: (context) => HoloPanel(
      accent: region.accent,
      accent2: region.accent2,
      fillAlpha: 0.95,
      strong: true,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('MEMORY FRAGMENT', style: oxa(11.5, color: Neon.dim, weight: 700, letterSpacing: 3)),
          const SizedBox(height: 12),
          Icon(Icons.auto_awesome_rounded, color: region.accent, size: 34),
          const SizedBox(height: 10),
          Text(
            region.memoryTitle.toUpperCase(),
            textAlign: TextAlign.center,
            style: oxa(21, weight: 800, letterSpacing: 2, shadows: glowText(region.accent)),
          ),
          const SizedBox(height: 4),
          Text(region.name, style: oxa(11.5, color: region.accent, weight: 700, letterSpacing: 2.4)),
          const SizedBox(height: 16),
          Text(
            region.memory,
            textAlign: TextAlign.center,
            style: oxa(15, color: Neon.text.withValues(alpha: 0.92), weight: 500, height: 1.5),
          ),
          const SizedBox(height: 20),
          NeonButton(
            label: 'CLOSE',
            accent: region.accent,
            accent2: region.accent2,
            onTap: () => Navigator.of(context).pop(),
            sound: Sfx.close,
          ),
        ],
      ),
    ),
  );
}

/// Detail card of one orb, shown from the collection and the reward list.
Future<void> showOrbDialog(BuildContext context, OrbDef orb, {required bool found}) {
  return showNeonDialog(
    context,
    builder: (context) => HoloPanel(
      accent: found ? orb.glow : Neon.faint,
      accent2: Neon.violet,
      fillAlpha: 0.95,
      strong: true,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 130,
            child: Center(
              child: OrbView(
                def: orb,
                size: 96,
                lit: found ? 0.12 : 0,
                dim: found ? 0 : 1,
                halo: found ? 0.3 : 0,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            found ? orb.name.toUpperCase() : 'UNDISCOVERED ORB',
            textAlign: TextAlign.center,
            style: oxa(21, weight: 800, letterSpacing: 2.4, shadows: found ? glowText(orb.glow) : null),
          ),
          const SizedBox(height: 6),
          if (found)
            Text(orb.role, style: oxa(12, color: orb.glow, weight: 800, letterSpacing: 3))
          else
            Text('KEEP RESTORING', style: oxa(12, color: Neon.dim, weight: 800, letterSpacing: 3)),
          const SizedBox(height: 14),
          Text(
            found ? orb.story : 'This orb is still asleep somewhere in the mirage. Restore more memories to wake it.',
            textAlign: TextAlign.center,
            style: oxa(14.5, color: Neon.text.withValues(alpha: 0.92), weight: 500, height: 1.5),
          ),
          const SizedBox(height: 20),
          NeonButton(
            label: 'CLOSE',
            accent: found ? orb.glow : Neon.edge,
            onTap: () => Navigator.of(context).pop(),
            sound: Sfx.close,
          ),
        ],
      ),
    ),
  );
}
