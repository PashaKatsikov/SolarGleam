import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../game/game_settings.dart';
import '../game/native_math.dart';
import '../game/progress.dart';
import '../game/world_data.dart';
import '../theme/neon_theme.dart';
import '../widgets/backdrop.dart';
import '../widgets/design_scale.dart';
import '../widgets/neon_ui.dart';
import '../widgets/routes.dart';
import '../widgets/story_dialogs.dart';
import 'level_select_screen.dart';

/// Six regions to restore, opened one after another with energy.
class WorldMapScreen extends StatefulWidget {
  const WorldMapScreen({super.key});

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends State<WorldMapScreen> {
  String? _note;

  void _flash(String text) {
    setState(() => _note = text);
    Future<void>.delayed(const Duration(milliseconds: 2200), () {
      if (mounted && _note == text) setState(() => _note = null);
    });
  }

  Future<void> _tap(int r) async {
    final progress = Progress.instance;
    final region = regionDefs[r];
    if (progress.regionOpen(r)) {
      _enter(r);
      return;
    }
    final quote = progress.quote(r);
    switch (quote.status) {
      case UnlockStatus.locked:
        Sound.instance.play(Sfx.error, volume: 0.6);
        GameSettings.instance.medium();
        _flash('Restore every object in ${regionDefs[r - 1].name} first');
      case UnlockStatus.short:
        Sound.instance.play(Sfx.error, volume: 0.6);
        GameSettings.instance.medium();
        _flash('You need ${formatCount(quote.cost - progress.energy)} more energy');
      case UnlockStatus.free || UnlockStatus.payable:
        var confirmed = false;
        await showNeonDialog(
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
                Text('OPEN REGION', style: oxa(11.5, color: Neon.dim, weight: 700, letterSpacing: 3)),
                const SizedBox(height: 10),
                Text(
                  region.name,
                  textAlign: TextAlign.center,
                  style: oxa(23, weight: 800, letterSpacing: 2.4, shadows: glowText(region.accent)),
                ),
                const SizedBox(height: 10),
                Text(
                  region.blurb,
                  textAlign: TextAlign.center,
                  style: oxa(14, color: Neon.text.withValues(alpha: 0.9), weight: 500, height: 1.45),
                ),
                const SizedBox(height: 14),
                Text('TEACHES', style: oxa(10.5, color: Neon.dim, weight: 700, letterSpacing: 2.4)),
                Text(region.teaches.toUpperCase(), style: oxa(13, color: region.accent, weight: 800, letterSpacing: 1.6)),
                const SizedBox(height: 18),
                NeonButton(
                  label: quote.cost == 0 ? 'OPEN' : 'SPEND ${formatCount(quote.cost)}',
                  icon: quote.cost == 0 ? Icons.lock_open_rounded : Icons.bolt_rounded,
                  accent: region.accent,
                  accent2: region.accent2,
                  onTap: () {
                    confirmed = true;
                    Navigator.of(context).pop();
                  },
                  sound: Sfx.areaUnlock,
                ),
                const SizedBox(height: 10),
                NeonButton(
                  label: 'NOT NOW',
                  filled: false,
                  accent: Neon.dim,
                  onTap: () => Navigator.of(context).pop(),
                  sound: Sfx.close,
                ),
              ],
            ),
          ),
        );
        if (!confirmed || !mounted) return;
        if (await progress.openRegion(r)) {
          GameSettings.instance.heavy();
          if (mounted) _enter(r);
        }
    }
  }

  void _enter(int r) {
    Sound.instance.play(Sfx.teleport, volume: 0.6);
    Navigator.of(context).push(softRoute(LevelSelectScreen(region: r)));
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      background: const Backdrop(asset: 'assets/art/bg_5.webp', accent: Neon.violet, dim: 0.5),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: Progress.instance,
          builder: (context, _) {
            final progress = Progress.instance;
            return Column(
              children: [
                TopBar(
                  title: 'WORLDS',
                  subtitle: 'SIX FORGOTTEN REGIONS',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RESTORED ${progress.totalCleared} / ${Progress.regions * Progress.levels}',
                              style: oxa(12, weight: 800, letterSpacing: 2),
                            ),
                            const SizedBox(height: 6),
                            RailBar(value: progress.worldPercent, color: Neon.cyan),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      EnergyChip(value: progress.energy),
                    ],
                  ),
                ),
                SizedBox(
                  height: 22,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _note == null
                          ? const SizedBox.shrink()
                          : Text(
                              _note!,
                              key: ValueKey(_note),
                              style: oxa(12.5, color: Neon.red, weight: 700, letterSpacing: 0.8),
                            ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
                    itemCount: Progress.regions,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _RegionCard(index: i, onTap: () => _tap(i)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RegionCard extends StatelessWidget {
  const _RegionCard({required this.index, required this.onTap});

  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = Progress.instance;
    final region = regionDefs[index];
    final open = progress.regionOpen(index);
    final done = progress.regionComplete(index);
    final cleared = progress.cleared(index);
    final quote = open ? null : progress.quote(index);
    final affordable = quote?.status == UnlockStatus.payable || quote?.status == UnlockStatus.free;

    final String tag;
    final Color tagColor;
    if (done) {
      tag = 'RESTORED';
      tagColor = Neon.mint;
    } else if (open) {
      tag = cleared == 0 ? 'NEW' : 'IN PROGRESS';
      tagColor = region.accent;
    } else if (affordable) {
      tag = quote!.cost == 0 ? 'OPEN NOW' : 'READY TO OPEN';
      tagColor = Neon.gold;
    } else {
      tag = 'SEALED';
      tagColor = Neon.faint;
    }

    return Pressable(
      onTap: onTap,
      sound: null,
      child: SizedBox(
        height: 122,
        child: HoloPanel(
          accent: open ? region.accent : (affordable ? Neon.gold : Neon.faint),
          accent2: open ? region.accent2 : Neon.edge,
          glow: affordable ? 2 : 1,
          fillAlpha: 0.7,
          padding: const EdgeInsets.all(7),
          child: Row(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipPath(
                  clipper: _CardClip(),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColorFiltered(
                        colorFilter: open
                            ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                            : const ColorFilter.matrix(<double>[
                                0.2, 0.3, 0.1, 0, 0,
                                0.2, 0.3, 0.1, 0, 0,
                                0.2, 0.3, 0.1, 0, 10,
                                0, 0, 0, 1, 0,
                              ]),
                        child: Image.asset(
                          region.background,
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, 0.3),
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
                        child: Opacity(
                          opacity: open ? 1 : 0.4,
                          child: Image.asset(
                            region.centrepiece.restored.path,
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ),
                      if (!open)
                        const Center(child: Icon(Icons.lock_rounded, color: Neon.text, size: 30)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text('${index + 1}', style: oxa(12, color: Neon.dim, weight: 800, letterSpacing: 1)),
                        const SizedBox(width: 8),
                        Text(tag, style: oxa(10.5, color: tagColor, weight: 800, letterSpacing: 2)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      region.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: oxa(16.5, weight: 800, letterSpacing: 1, color: open ? Neon.text : Neon.dim),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      region.teaches,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: oxa(11.5, color: Neon.dim, weight: 500),
                    ),
                    const SizedBox(height: 8),
                    if (open) ...[
                      RailBar(value: cleared / Progress.levels, color: region.accent, height: 6),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Text('$cleared/${Progress.levels}', style: oxa(11.5, weight: 800)),
                          const Spacer(),
                          const Icon(Icons.star_rounded, color: Neon.gold, size: 14),
                          const SizedBox(width: 2),
                          Text('${progress.starsIn(index)}', style: oxa(11.5, color: Neon.gold, weight: 800)),
                        ],
                      ),
                    ] else
                      Row(
                        children: [
                          if (quote!.cost > 0) ...[
                            Icon(Icons.bolt_rounded, color: affordable ? Neon.gold : Neon.faint, size: 18),
                            Text(
                              formatCount(quote.cost),
                              style: oxa(15, color: affordable ? Neon.gold : Neon.faint, weight: 800),
                            ),
                          ] else
                            Text('FREE', style: oxa(14, color: Neon.gold, weight: 800, letterSpacing: 2)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              quote.status == UnlockStatus.locked ? 'Finish the previous region' : '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: oxa(11, color: Neon.faint, weight: 500),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Icon(
                open ? Icons.chevron_right_rounded : Icons.lock_outline_rounded,
                color: open ? region.accent : Neon.faint,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardClip extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => chamferPath(size, 12, round: 4);

  @override
  bool shouldReclip(_CardClip old) => false;
}
