import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../game/progress.dart';
import '../game/puzzle_controller.dart';
import '../game/world_data.dart';
import '../theme/neon_theme.dart';
import '../widgets/backdrop.dart';
import '../widgets/design_scale.dart';
import '../widgets/neon_ui.dart';
import '../widgets/puzzle_board.dart';
import '../widgets/routes.dart';
import '../widgets/rule_tutorial.dart';
import 'restore_screen.dart';
import 'settings_screen.dart';

class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key, required this.region, required this.level});

  final int region;
  final int level;

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> with WidgetsBindingObserver {
  late final PuzzleController _ctrl = PuzzleController(widget.region, widget.level);
  late final RegionDef _region = regionDefs[widget.region];
  var _pauseOpen = false;
  var _leaving = false;
  var _ready = false;
  var _introRun = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!_ctrl.begin()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }
    _ready = true;
    _ctrl.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _intro());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.removeListener(_onChange);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _ready) _setPause(true);
  }

  /// Rule cards for anything new on this level, then the preview.
  Future<void> _intro() async {
    final run = ++_introRun;
    final progress = Progress.instance;
    final first = progress.tutorialBits == 0;
    for (final rule in rulesOf(_ctrl.spec.modes)) {
      if (progress.tutorialSeen(rule.bit)) continue;
      if (!mounted || run != _introRun) return;
      await showRuleTutorial(context, rule.bit, first: first && rule.bit == Rule.echo);
      await progress.markTutorial(rule.bit);
    }
    if (!mounted || run != _introRun) return;
    _ctrl.startPreview();
  }

  void _onChange() {
    if (_ctrl.phase == PuzzlePhase.solved && !_leaving) {
      _leaving = true;
      Timer(const Duration(milliseconds: 1900), () {
        final applied = _ctrl.applied;
        if (!mounted || applied == null) return;
        Navigator.of(context).pushReplacement(softRoute(RestoreScreen(applied: applied), milliseconds: 600));
      });
    }
  }

  void _setPause(bool open) {
    if (_ctrl.phase == PuzzlePhase.solved || _leaving) return;
    if (_pauseOpen == open) return;
    setState(() => _pauseOpen = open);
    if (open) {
      _ctrl.pause();
      Sound.instance.play(Sfx.open);
    } else {
      _ctrl.resume();
    }
  }

  Future<void> _retry() async {
    Sound.instance.play(Sfx.teleport, volume: 0.6);
    setState(() => _pauseOpen = false);
    _ctrl.restart();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(backgroundColor: Neon.void0);
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setPause(!_pauseOpen);
      },
      child: NeonScaffold(
        background: Backdrop(
          asset: _region.background,
          accent: _region.accent,
          dim: 0.34,
          alignment: const Alignment(0, -0.2),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: _ctrl,
            builder: (context, _) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  _body(),
                  if (_ctrl.phase == PuzzlePhase.failed) _failOverlay(),
                  if (_pauseOpen) _pauseOverlay(),
                  if (_ctrl.phase == PuzzlePhase.solved) _solvedFlash(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // Layout -----------------------------------------------------------------------

  Widget _body() {
    final slot = _region.slots[widget.level];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Row(
            children: [
              IconPad(
                icon: Icons.pause_rounded,
                accent: _region.accent,
                onTap: () => _setPause(true),
                sound: null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _region.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: oxa(11.5, color: _region.accent, weight: 800, letterSpacing: 2.6),
                    ),
                    Text(
                      'LEVEL ${widget.level + 1}  /  ${Progress.levels}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: oxa(17, weight: 800, letterSpacing: 1.6),
                    ),
                  ],
                ),
              ),
              ListenableBuilder(
                listenable: Progress.instance,
                builder: (context, _) => EnergyChip(value: Progress.instance.energy, compact: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _ruleStrip(),
        const SizedBox(height: 10),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: _objective(slot)),
        Expanded(child: PuzzleBoard(controller: _ctrl, region: _region)),
        _status(),
        const SizedBox(height: 8),
        _sequenceDots(),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: _AidButton(
                  icon: Icons.replay_rounded,
                  label: 'REPLAY',
                  count: _ctrl.replaysLeft,
                  accent: Neon.violet,
                  enabled: _ctrl.canAct && _ctrl.replaysLeft > 0,
                  onTap: _ctrl.useReplay,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AidButton(
                  icon: Icons.lightbulb_rounded,
                  label: 'HINT',
                  count: _ctrl.hintsLeft,
                  accent: Neon.gold,
                  enabled: _ctrl.canAct && _ctrl.hintsLeft > 0,
                  glow: _ctrl.mistakes >= 2 && _ctrl.hintsLeft > 0 && _ctrl.canAct,
                  onTap: _ctrl.useHint,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ruleStrip() {
    final rules = rulesOf(_ctrl.spec.modes);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        for (final r in rules)
          GestureDetector(
            onTap: () => showRuleTutorial(context, r.bit),
            child: RuleChip(rule: r),
          ),
      ],
    );
  }

  Widget _objective(SlotDef slot) {
    final dormant = slot.ruined ?? slot.restored;
    final attempts = _ctrl.spec.attempts;
    return HoloPanel(
      accent: _region.accent,
      accent2: _region.accent2,
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
      cut: 12,
      child: Row(
        children: [
          SizedBox(
            width: 62,
            height: 58,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [_region.accent.withValues(alpha: 0.25), Colors.transparent],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: ColorFiltered(
                  colorFilter: slot.ruined != null
                      ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                      : const ColorFilter.matrix(<double>[
                          0.3, 0.45, 0.2, 0, 0,
                          0.3, 0.45, 0.2, 0, 0,
                          0.3, 0.45, 0.2, 0, 0,
                          0, 0, 0, 0.7, 0,
                        ]),
                  child: Image.asset(
                    dormant.path,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'RESTORING',
                  style: oxa(10.5, color: Neon.dim, weight: 700, letterSpacing: 2.4),
                ),
                const SizedBox(height: 2),
                Text(
                  slot.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: oxa(17, weight: 800, letterSpacing: 0.4),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ATTEMPTS', style: oxa(10, color: Neon.dim, weight: 700, letterSpacing: 2)),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < attempts; i++)
                    Padding(
                      padding: const EdgeInsets.only(left: 5),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _ctrl.attemptsLeft ? _region.accent : Colors.transparent,
                          border: Border.all(
                            color: i < _ctrl.attemptsLeft ? Colors.white : Neon.faint,
                            width: 1.4,
                          ),
                          boxShadow: i < _ctrl.attemptsLeft
                              ? [BoxShadow(color: _region.accent.withValues(alpha: 0.8), blurRadius: 8)]
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _status() {
    final glyph = _ctrl.spec.modes & Rule.glyph != 0;
    final mirror = _ctrl.spec.modes & Rule.mirror != 0;
    final (text, color) = switch (_ctrl.phase) {
      PuzzlePhase.briefing => ('GET READY', Neon.dim),
      PuzzlePhase.watching => (glyph ? 'READ THE CORE' : 'WATCH THE ORBS', Neon.cyan),
      PuzzlePhase.shifting => ('FOLLOW THE ORBS', Neon.gold),
      PuzzlePhase.input => _ctrl.lastTapWrong
          ? ('NOT QUITE - START AGAIN', Neon.red)
          : (mirror ? 'TAP IN REVERSE ORDER' : (glyph ? 'TAP THE MATCHING ORBS' : 'YOUR TURN'), Neon.mint),
      PuzzlePhase.solved => ('MEMORY RESTORED', Neon.mint),
      PuzzlePhase.failed => ('SIGNAL LOST', Neon.red),
    };
    return SizedBox(
      height: 30,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: Text(
          text,
          key: ValueKey(text),
          style: oxa(17, color: color, weight: 800, letterSpacing: 3.4, shadows: glowText(color, blur: 10)),
        ),
      ),
    );
  }

  Widget _sequenceDots() {
    final total = _ctrl.spec.sequenceLength;
    final live = _ctrl.phase == PuzzlePhase.input || _ctrl.phase == PuzzlePhase.solved;
    return SizedBox(
      height: 18,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i < _ctrl.entered ? 14 : 10,
              height: i < _ctrl.entered ? 14 : 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _ctrl.entered ? _region.accent : Colors.transparent,
                border: Border.all(
                  color: !live
                      ? Neon.faint.withValues(alpha: 0.6)
                      : (i < _ctrl.entered ? Colors.white : Neon.dim),
                  width: 1.4,
                ),
                boxShadow: i < _ctrl.entered
                    ? [BoxShadow(color: _region.accent.withValues(alpha: 0.9), blurRadius: 9)]
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  // Overlays ---------------------------------------------------------------------

  Widget _veil({required Widget child}) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.66),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _pauseOverlay() {
    return _veil(
      child: HoloPanel(
        accent: _region.accent,
        accent2: _region.accent2,
        fillAlpha: 0.94,
        strong: true,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('PAUSED', style: oxa(26, weight: 800, letterSpacing: 6, shadows: glowText(_region.accent))),
            const SizedBox(height: 4),
            Text(
              '${_region.name} · LEVEL ${widget.level + 1}',
              style: oxa(12, color: Neon.dim, weight: 700, letterSpacing: 2),
            ),
            const SizedBox(height: 20),
            NeonButton(
              label: 'RESUME',
              accent: _region.accent,
              accent2: _region.accent2,
              icon: Icons.play_arrow_rounded,
              onTap: () => _setPause(false),
              sound: Sfx.close,
            ),
            const SizedBox(height: 11),
            NeonButton(
              label: 'NEW PUZZLE',
              filled: false,
              accent: Neon.violet,
              icon: Icons.refresh_rounded,
              onTap: _retry,
            ),
            const SizedBox(height: 11),
            NeonButton(
              label: 'SETTINGS',
              filled: false,
              accent: Neon.cyan,
              icon: Icons.tune_rounded,
              onTap: () => Navigator.of(context).push(softRoute(const SettingsScreen())),
            ),
            const SizedBox(height: 11),
            NeonButton(
              label: 'LEAVE LEVEL',
              filled: false,
              accent: Neon.red,
              icon: Icons.logout_rounded,
              onTap: () => Navigator.of(context).pop(),
              sound: Sfx.close,
            ),
          ],
        ),
      ),
    );
  }

  Widget _failOverlay() {
    return _veil(
      child: HoloPanel(
        accent: Neon.red,
        accent2: Neon.pink,
        fillAlpha: 0.95,
        strong: true,
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.heart_broken_rounded, color: Neon.red, size: 38),
            const SizedBox(height: 8),
            Text('SIGNAL LOST', style: oxa(25, weight: 800, letterSpacing: 4, shadows: glowText(Neon.red))),
            const SizedBox(height: 8),
            Text(
              'The memory slipped away. Every try builds a new pattern, so take a breath and watch again.',
              textAlign: TextAlign.center,
              style: oxa(14, color: Neon.dim, weight: 500, height: 1.4),
            ),
            const SizedBox(height: 20),
            NeonButton(
              label: 'TRY AGAIN',
              accent: Neon.pink,
              accent2: Neon.red,
              icon: Icons.refresh_rounded,
              onTap: _retry,
              sound: Sfx.teleport,
            ),
            const SizedBox(height: 11),
            NeonButton(
              label: 'LEAVE LEVEL',
              filled: false,
              accent: Neon.dim,
              onTap: () => Navigator.of(context).pop(),
              sound: Sfx.close,
            ),
          ],
        ),
      ),
    );
  }

  Widget _solvedFlash() {
    return Positioned.fill(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1700),
          builder: (context, t, _) {
            final a = t < 0.35 ? t / 0.35 : (1 - t) / 0.65;
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, 0.05),
                  radius: 1.1,
                  colors: [
                    _region.accent.withValues(alpha: 0.55 * a.clamp(0.0, 1.0)),
                    Colors.transparent,
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AidButton extends StatelessWidget {
  const _AidButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.accent,
    required this.enabled,
    required this.onTap,
    this.glow = false,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color accent;
  final bool enabled;
  final bool glow;
  final bool Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: enabled ? () => onTap() : null,
      sound: null,
      child: SizedBox(
        height: 52,
        child: HoloPanel(
          accent: accent,
          accent2: accent,
          glow: glow ? 2.2 : 1,
          fillAlpha: 0.72,
          cut: 12,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: 8),
              Text(label, style: oxa(14, weight: 800, letterSpacing: 2)),
              const SizedBox(width: 10),
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.2),
                  border: Border.all(color: accent, width: 1.2),
                ),
                child: Text('$count', style: oxa(13, weight: 800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
