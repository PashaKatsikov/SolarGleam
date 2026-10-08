import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../game/game_settings.dart';
import '../game/progress.dart';
import '../game/world_data.dart';
import '../theme/neon_theme.dart';
import '../widgets/backdrop.dart';
import '../widgets/design_scale.dart';
import '../widgets/diorama.dart';
import '../widgets/neon_ui.dart';
import '../widgets/routes.dart';
import '../widgets/story_dialogs.dart';
import 'puzzle_screen.dart';

/// The eight restorations of one region.
class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key, required this.region});

  final int region;

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  RegionDef get region => regionDefs[widget.region];
  String? _note;

  void _open(int level) {
    final progress = Progress.instance;
    if (!progress.levelOpen(widget.region, level)) {
      Sound.instance.play(Sfx.error, volume: 0.6);
      GameSettings.instance.medium();
      setState(() => _note = 'Restore ${region.slots[level - 1].name} first');
      Future<void>.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _note = null);
      });
      return;
    }
    Sound.instance.play(Sfx.teleport, volume: 0.5);
    Navigator.of(context).push(softRoute(PuzzleScreen(region: widget.region, level: level)));
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      background: Backdrop(asset: region.background, accent: region.accent, dim: 0.3),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: Progress.instance,
          builder: (context, _) {
            final progress = Progress.instance;
            final r = widget.region;
            final next = [
              for (var l = 0; l < Progress.levels; l++)
                if (progress.stars[r][l] == 0) l,
            ];
            final nextLevel = next.isEmpty ? 0 : next.first;
            return Column(
              children: [
                TopBar(
                  title: region.name,
                  subtitle: region.line.toUpperCase(),
                  accent: region.accent,
                  onBack: () => Navigator.of(context).pop(),
                  trailing: null,
                ),
                Expanded(
                  flex: 11,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Center(
                      child: RegionDiorama(
                        region: region,
                        restoredMask: progress.restoredMask(r),
                        decorMask: progress.decorMask(r),
                        focus: next.isEmpty ? null : nextLevel,
                        aspect: 1.12,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _progressStrip(progress),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _grid(progress),
                ),
                SizedBox(
                  height: 28,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _note == null
                          ? const SizedBox.shrink()
                          : Text(
                              _note!,
                              key: ValueKey(_note),
                              style: oxa(12.5, color: Neon.red, weight: 700, letterSpacing: 1),
                            ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: NeonButton(
                    label: next.isEmpty ? 'REPLAY FINALE' : 'PLAY LEVEL ${nextLevel + 1}',
                    accent: region.accent,
                    accent2: region.accent2,
                    icon: Icons.play_arrow_rounded,
                    onTap: () => _open(next.isEmpty ? Progress.levels - 1 : nextLevel),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _progressStrip(Progress progress) {
    final r = widget.region;
    final done = progress.cleared(r);
    final memory = progress.memoryUnlocked(r);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'RESTORED $done / ${Progress.levels}',
                    style: oxa(12, weight: 800, letterSpacing: 2),
                  ),
                  const Spacer(),
                  StarRow(count: progress.starsIn(r), total: 1, size: 15),
                  const SizedBox(width: 3),
                  Text('${progress.starsIn(r)} / ${Progress.levels * 3}', style: oxa(12, color: Neon.gold, weight: 800)),
                ],
              ),
              const SizedBox(height: 7),
              RailBar(value: done / Progress.levels, color: region.accent),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconPad(
          icon: memory ? Icons.auto_awesome_rounded : Icons.lock_rounded,
          accent: memory ? region.accent : Neon.faint,
          size: 42,
          onTap: memory
              ? () => showMemoryDialog(context, region)
              : () {
                  setState(() => _note = 'Restore all 8 objects to read the memory');
                  Future<void>.delayed(const Duration(milliseconds: 2000), () {
                    if (mounted) setState(() => _note = null);
                  });
                },
        ),
      ],
    );
  }

  Widget _grid(Progress progress) {
    return Column(
      children: [
        for (var row = 0; row < 2; row++)
          Padding(
            padding: EdgeInsets.only(bottom: row == 0 ? 8 : 0),
            child: Row(
              children: [
                for (var col = 0; col < 4; col++) ...[
                  if (col > 0) const SizedBox(width: 8),
                  Expanded(child: _tile(progress, row * 4 + col)),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _tile(Progress progress, int level) {
    final r = widget.region;
    final stars = progress.stars[r][level];
    final open = progress.levelOpen(r, level);
    final current = open && stars == 0;
    final slot = region.slots[level];
    final accent = current ? Neon.gold : (stars > 0 ? region.accent : Neon.faint);
    return Pressable(
      onTap: () => _open(level),
      sound: null,
      child: SizedBox(
        height: 88,
        child: HoloPanel(
          accent: accent,
          accent2: stars > 0 ? region.accent2 : Neon.edge,
          cut: 10,
          fillAlpha: open ? 0.8 : 0.6,
          padding: const EdgeInsets.fromLTRB(4, 5, 4, 5),
          glow: current ? 2 : 1,
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: open ? 1 : 0.4,
                      child: ColorFiltered(
                        colorFilter: stars > 0
                            ? tintMatrix(saturation: 1, brightness: 1)
                            : tintMatrix(saturation: open ? 0.25 : 0, brightness: open ? 0.6 : 0.35),
                        child: Image.asset(
                          (stars > 0 ? slot.restored : (slot.ruined ?? slot.restored)).path,
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                    if (!open) const Icon(Icons.lock_rounded, color: Neon.dim, size: 22),
                    Positioned(
                      left: 2,
                      top: 0,
                      child: Text(
                        '${level + 1}',
                        style: oxa(
                          15,
                          color: current ? Neon.gold : (open ? Neon.text : Neon.faint),
                          weight: 800,
                          shadows: current
                              ? glowText(Neon.gold, blur: 8)
                              : const [Shadow(color: Colors.black, blurRadius: 5), Shadow(color: Colors.black, blurRadius: 2)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              StarRow(count: stars, size: 14, spacing: 0),
            ],
          ),
        ),
      ),
    );
  }
}
