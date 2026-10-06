import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../assets.dart';
import '../game/slot_controller.dart';
import '../theme/gleam_theme.dart';
import '../widgets/image_slice.dart';
import '../widgets/loading_backdrop.dart';
import '../widgets/overlays.dart';
import '../widgets/reel_board.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  static const _buttonSheet = Size(816, 447);
  static const _playRect = Rect.fromLTWH(56, 36, 393, 383);
  static const _autoRect = Rect.fromLTWH(471, 43, 287, 374);
  static const _logoSource = Size(512, 512);
  static const _logoRect = Rect.fromLTWH(9, 159, 494, 199);

  final _controller = SlotController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_lockPortrait());
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _controller.load();
  }

  Future<void> _lockPortrait() async {
    try {
      await SystemChrome.setPreferredOrientations(gameOrientations);
    } catch (_) {
      // Orientation locks are unavailable outside a device shell.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.save());
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _controller.save();
    }
  }

  void _leave() {
    _controller.setPaused(true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.orientationOf(context) == Orientation.landscape) {
      return const Scaffold(
        backgroundColor: GleamColors.night,
        body: LoadingBackdrop(),
      );
    }

    final media = MediaQuery.of(context);
    final scaler = media.textScaler.scale(1).clamp(0.9, 1.12);
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(scaler)),
      child: Scaffold(
        backgroundColor: GleamColors.night,
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                const _Background(),
                SafeArea(
                  child: _Playfield(controller: _controller, onBack: _leave),
                ),
                if (_controller.needsRefill)
                  RefillSheet(
                    onRestore: _controller.refill,
                    onClose: _controller.dismissRefill,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Background extends StatelessWidget {
  const _Background();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          GleamAssets.background,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x88000000),
                Color(0x00000000),
                Color(0x00000000),
                Color(0x99000000),
              ],
              stops: [0, 0.16, 0.68, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _Playfield extends StatelessWidget {
  const _Playfield({required this.controller, required this.onBack});

  final SlotController controller;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final tablet = width >= 700;
        final contentW = tablet
            ? math.min(width - 28, 940.0)
            : math.max(280.0, width - 4);
        final scale = tablet
            ? 1.28
            : (contentW / 390).clamp(0.86, 1.05).toDouble();
        final hudH = 76.0 * scale;
        final betH = 60.0 * scale;
        final playH = 84.0 * scale;
        final chipH = controller.freeSpins > 0 ? 26.0 : 0.0;
        final betW = math.min(contentW, betH * (584 / 203));
        final fittedBetH = betW / (584 / 203);
        var playW = playH * (393 / 383);
        var autoH = playH * 0.92;
        var autoW = autoH * (287 / 374);
        final buttonGap = 14.0 * scale;
        final buttonRow = playW + autoW + buttonGap;
        if (buttonRow > contentW) {
          final fit = contentW / buttonRow;
          playW *= fit;
          autoW *= fit;
          autoH *= fit;
        }

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: contentW,
            child: Column(
              children: [
                SizedBox(
                  height: hudH,
                  child: _Hud(controller: controller, onBack: onBack),
                ),
                if (controller.freeSpins > 0)
                  SizedBox(
                    height: chipH,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _FreeSpinChip(count: controller.freeSpins),
                    ),
                  ),
                if (tablet)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
                    child: SizedBox(
                      height: 138,
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: 494,
                          height: 199,
                          child: ImageSlice(
                            asset: GleamAssets.gameName,
                            source: _GameScreenState._logoSource,
                            rect: _GameScreenState._logoRect,
                          ),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, frameConstraints) {
                      const aspect = 1547 / 1513;
                      const gridTop = 0.312;
                      const gridBottom = 0.788;
                      const gridSpan = gridBottom - gridTop;
                      final availableH = frameConstraints.maxHeight;
                      final double frameW;
                      final double frameH;
                      if (tablet) {
                        frameH = math.min(availableH, contentW / aspect);
                        frameW = frameH * aspect;
                      } else {
                        final wide = contentW * 0.92 / (0.752 - 0.248);
                        var nextH = wide / aspect;
                        var nextW = wide;
                        if (nextH * gridSpan > availableH) {
                          nextH = availableH / gridSpan;
                          nextW = nextH * aspect;
                        }
                        frameW = nextW;
                        frameH = nextH;
                      }
                      final gridCenter = (gridTop + gridBottom) / 2;
                      final topClip = frameH <= availableH
                          ? 0.0
                          : (gridCenter * frameH - availableH / 2)
                                .clamp(0.0, frameH - availableH)
                                .toDouble();
                      final alignY = frameH <= availableH
                          ? 0.0
                          : (2 * topClip / (frameH - availableH) - 1)
                                .clamp(-1.0, 1.0)
                                .toDouble();
                      final crest = frameH * 0.30 - topClip;
                      final logoH = crest
                          .clamp(0.0, tablet ? 92.0 : 68.0)
                          .toDouble();
                      final logoW = math.min(
                        contentW * 0.72,
                        logoH / (199 / 494),
                      );
                      return ClipRect(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            OverflowBox(
                              alignment: tablet && frameH <= availableH
                                  ? Alignment.topCenter
                                  : Alignment(0, alignY),
                              minWidth: frameW,
                              maxWidth: frameW,
                              minHeight: frameH,
                              maxHeight: frameH,
                              child: SizedBox(
                                width: frameW,
                                height: frameH,
                                child: ReelBoard(
                                  grid: controller.grid,
                                  spinId: controller.spinId,
                                  spinning: controller.spinning,
                                  rush: controller.rush,
                                  winningCells: controller.winningCells,
                                  showWins:
                                      !controller.spinning &&
                                      controller.winningCells.isNotEmpty,
                                  onSettled: controller.onReelsSettled,
                                  onTap: controller.onSpinPressed,
                                ),
                              ),
                            ),
                            if (!tablet && logoH >= 36)
                              Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: SizedBox(
                                    width: logoW,
                                    height: logoW * (199 / 494),
                                    child: const ImageSlice(
                                      asset: GleamAssets.gameName,
                                      source: _GameScreenState._logoSource,
                                      rect: _GameScreenState._logoRect,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: betW,
                  height: fittedBetH,
                  child: _BetControl(
                    amount: controller.bet,
                    enabled: !controller.spinning && controller.freeSpins == 0,
                    onMinus: () => controller.changeBet(-1),
                    onPlus: () => controller.changeBet(1),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: playH,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _Pressable(
                        semanticLabel: controller.autoplay
                            ? 'Stop auto spin'
                            : 'Auto spin',
                        onTap: controller.toggleAuto,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: controller.autoplay
                                ? const [
                                    BoxShadow(
                                      color: Color(0xCCF0C14B),
                                      blurRadius: 18,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: SizedBox(
                            width: autoW,
                            height: autoH,
                            child: const ImageSlice(
                              asset: GleamAssets.spinButtons,
                              source: _GameScreenState._buttonSheet,
                              rect: _GameScreenState._autoRect,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 18 * scale.clamp(1, 1.3)),
                      _Pressable(
                        semanticLabel: 'Spin',
                        onTap: controller.onSpinPressed,
                        child: SizedBox(
                          width: playW,
                          height: playH,
                          child: const ImageSlice(
                            asset: GleamAssets.spinButtons,
                            source: _GameScreenState._buttonSheet,
                            rect: _GameScreenState._playRect,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.controller, required this.onBack});

  final SlotController controller;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: 'Menu',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: const Icon(Icons.arrow_back, color: GleamColors.goldLight),
        ),
        Expanded(
          child: _Plaque(
            label: 'BALANCE',
            value: formatGleam(controller.balance),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Plaque(label: 'WIN', value: formatGleam(controller.shownWin)),
        ),
      ],
    );
  }
}

class _Plaque extends StatelessWidget {
  const _Plaque({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: GleamColors.plaque,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GleamColors.gold, width: 1.6),
        boxShadow: const [BoxShadow(color: Color(0x55F0A020), blurRadius: 12)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: cinzel(
                  18,
                  GleamColors.gold,
                  weight: 700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(value, style: rajdhani(28, GleamColors.ivory)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreeSpinChip extends StatelessWidget {
  const _FreeSpinChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: GleamColors.plaque,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GleamColors.gold),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Text(
          'FREE SPINS  $count',
          style: cinzel(12, GleamColors.goldLight, letterSpacing: 1.1),
        ),
      ),
    );
  }
}

class _BetControl extends StatelessWidget {
  const _BetControl({
    required this.amount,
    required this.enabled,
    required this.onMinus,
    required this.onPlus,
  });

  final int amount;
  final bool enabled;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            GleamAssets.betAmount,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
          Row(
            children: [
              Expanded(
                flex: 24,
                child: _Zone(
                  label: 'Decrease bet',
                  onTap: enabled ? onMinus : null,
                ),
              ),
              Expanded(
                flex: 52,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatGleam(amount),
                      style: rajdhani(32, GleamColors.goldLight),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 24,
                child: _Zone(
                  label: 'Increase bet',
                  onTap: enabled ? onPlus : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Zone extends StatelessWidget {
  const _Zone({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.onTap,
    required this.child,
    required this.semanticLabel,
  });

  final VoidCallback onTap;
  final Widget child;
  final String semanticLabel;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  var _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.94 : 1,
          duration: const Duration(milliseconds: 90),
          child: widget.child,
        ),
      ),
    );
  }
}
