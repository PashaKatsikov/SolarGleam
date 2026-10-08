import 'package:flutter/material.dart';

import '../game/progress.dart';
import '../game/world_data.dart';
import '../theme/neon_theme.dart';
import '../widgets/backdrop.dart';
import '../widgets/design_scale.dart';
import '../widgets/diorama.dart';
import '../widgets/neon_ui.dart';
import '../widgets/orb_view.dart';
import '../widgets/story_dialogs.dart';

/// Everything found so far: orbs, memory fragments and decor relics.
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  var _tab = 0;

  static const _tabs = ['ORBS', 'MEMORIES', 'RELICS'];

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      background: const Backdrop(asset: 'assets/art/bg_1.webp', accent: Neon.mint, dim: 0.5),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: Progress.instance,
          builder: (context, _) {
            final progress = Progress.instance;
            final orbCount = progress.orbs.length;
            final memories = progress.regionsComplete;
            final relics = progress.decor.length;
            final counts = ['$orbCount/${orbDefs.length}', '$memories/${Progress.regions}', '$relics/${Progress.regions * 4}'];
            return Column(
              children: [
                TopBar(
                  title: 'COLLECTION',
                  subtitle: 'ORBS · MEMORIES · RELICS',
                  accent: Neon.mint,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                  child: Row(
                    children: [
                      for (var i = 0; i < _tabs.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(child: _tabButton(i, counts[i])),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: KeyedSubtree(
                      key: ValueKey(_tab),
                      child: switch (_tab) {
                        0 => _orbs(progress),
                        1 => _memories(progress),
                        _ => _relics(progress),
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tabButton(int i, String count) {
    final selected = _tab == i;
    return Pressable(
      onTap: () => setState(() => _tab = i),
      child: SizedBox(
        height: 48,
        child: HoloPanel(
          accent: selected ? Neon.mint : Neon.faint,
          accent2: selected ? Neon.cyan : Neon.edge,
          cut: 10,
          fillAlpha: selected ? 0.92 : 0.55,
          strong: selected,
          padding: EdgeInsets.zero,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _tabs[i],
                  style: oxa(12.5, color: selected ? Neon.text : Neon.dim, weight: 800, letterSpacing: 1.6),
                ),
                Text(count, style: oxa(11, color: selected ? Neon.mint : Neon.faint, weight: 700)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _orbs(Progress progress) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.86,
      ),
      itemCount: orbDefs.length,
      itemBuilder: (context, i) {
        final orb = orbDefs[i];
        final found = progress.orbs.contains(orb.id);
        return Pressable(
          onTap: () => showOrbDialog(context, orb, found: found),
          child: HoloPanel(
            accent: found ? orb.glow : Neon.faint,
            accent2: Neon.violet,
            cut: 12,
            fillAlpha: found ? 0.8 : 0.55,
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, c) => OrbView(
                        def: orb,
                        size: (c.maxHeight * 0.92).clamp(30.0, 74.0),
                        dim: found ? 0 : 1,
                        halo: found ? 0.22 : 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  found ? orb.name.split(' ').first.toUpperCase() : '???',
                  style: oxa(12, color: found ? Neon.text : Neon.faint, weight: 800, letterSpacing: 1.6),
                ),
                Text(
                  found ? orb.role : 'UNKNOWN',
                  style: oxa(9.5, color: found ? orb.glow : Neon.faint, weight: 800, letterSpacing: 2),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _memories(Progress progress) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
      itemCount: Progress.regions,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final region = regionDefs[i];
        final open = progress.memoryUnlocked(i);
        return Pressable(
          onTap: open ? () => showMemoryDialog(context, region) : null,
          child: HoloPanel(
            accent: open ? region.accent : Neon.faint,
            accent2: open ? region.accent2 : Neon.edge,
            fillAlpha: open ? 0.8 : 0.55,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: open ? region.accent : Neon.faint, width: 1.4),
                    color: (open ? region.accent : Neon.faint).withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    open ? Icons.auto_awesome_rounded : Icons.lock_rounded,
                    color: open ? region.accent : Neon.faint,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        open ? region.memoryTitle : 'Sealed memory',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: oxa(15.5, weight: 800, color: open ? Neon.text : Neon.dim),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        open
                            ? region.name
                            : 'Restore all of ${region.name.split(' ').map((w) => w[0] + w.substring(1).toLowerCase()).join(' ')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: oxa(11.5, color: open ? region.accent : Neon.faint, weight: 700, letterSpacing: open ? 1.6 : 0.2),
                      ),
                    ],
                  ),
                ),
                if (open) Icon(Icons.chevron_right_rounded, color: region.accent),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _relics(Progress progress) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
      itemCount: Progress.regions,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, r) {
        final region = regionDefs[r];
        final have = [for (var i = 0; i < 4; i++) progress.decor.contains(r * 4 + i)];
        final count = have.where((e) => e).length;
        return HoloPanel(
          accent: count > 0 ? region.accent : Neon.faint,
          accent2: Neon.edge,
          fillAlpha: 0.7,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      region.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: oxa(12, color: region.accent, weight: 800, letterSpacing: 2),
                    ),
                  ),
                  Text('$count/4', style: oxa(12, color: Neon.dim, weight: 800)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < 4; i++)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 52,
                            child: Opacity(
                              opacity: have[i] ? 1 : 0.9,
                              child: ColorFiltered(
                                colorFilter: have[i]
                                    ? tintMatrix(saturation: 1, brightness: 1)
                                    : tintMatrix(saturation: 0, brightness: 0.18),
                                child: Image.asset(
                                  region.decor[i].sprite.path,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            have[i] ? region.decor[i].name : '???',
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: oxa(9.5, color: have[i] ? Neon.dim : Neon.faint, weight: 600, height: 1.15),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
