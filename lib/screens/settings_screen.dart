import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../audio/sound.dart';
import '../game/game_settings.dart';
import '../game/progress.dart';
import '../game/world_data.dart';
import '../theme/neon_theme.dart';
import '../widgets/backdrop.dart';
import '../widgets/design_scale.dart';
import '../widgets/neon_ui.dart';
import '../widgets/rule_tutorial.dart';
import '../widgets/story_dialogs.dart';

const _privacyUrl = 'https://solar-gleam.com/privacy-policy';
const _supportUrl = 'https://solar-gleam.com/support';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Opens the page in an in-app Safari sheet, so the app ships no WKWebView.
  Future<void> _openPage(String url) async {
    final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the page. Try again.')),
      );
    }
  }

  Future<void> _confirmReset() async {
    var yes = false;
    await showNeonDialog(
      context,
      builder: (context) => HoloPanel(
        accent: Neon.red,
        accent2: Neon.pink,
        fillAlpha: 0.95,
        strong: true,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Neon.red, size: 36),
            const SizedBox(height: 8),
            Text('RESET PROGRESS?', style: oxa(22, weight: 800, letterSpacing: 2.4, shadows: glowText(Neon.red))),
            const SizedBox(height: 10),
            Text(
              'All restored objects, stars, energy and discovered orbs will be erased. This cannot be undone.',
              textAlign: TextAlign.center,
              style: oxa(14, color: Neon.dim, weight: 500, height: 1.45),
            ),
            const SizedBox(height: 18),
            NeonButton(
              label: 'ERASE EVERYTHING',
              accent: Neon.red,
              accent2: Neon.pink,
              onTap: () {
                yes = true;
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 10),
            NeonButton(
              label: 'KEEP PLAYING',
              filled: false,
              accent: Neon.cyan,
              onTap: () => Navigator.of(context).pop(),
              sound: Sfx.close,
            ),
          ],
        ),
      ),
    );
    if (yes) {
      await Progress.instance.reset();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Progress erased.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      background: const Backdrop(asset: 'assets/art/bg_0.webp', accent: Neon.cyan, dim: 0.55),
      child: SafeArea(
        child: Column(
          children: [
            TopBar(
              title: 'SETTINGS',
              subtitle: 'SOUND · TOUCH · HELP',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: GameSettings.instance,
                builder: (context, _) {
                  final s = GameSettings.instance;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                    children: [
                      _section('SOUND', [
                        _toggle('Music', Icons.music_note_rounded, s.music, s.setMusic),
                        _slider(s.musicVolume, s.music, s.setMusicVolume),
                        const _Divider(),
                        _toggle('Effects', Icons.graphic_eq_rounded, s.sfx, s.setSfx),
                        _slider(s.sfxVolume, s.sfx, (v) {
                          s.setSfxVolume(v);
                        }, onEnd: () => Sound.instance.play(Sfx.select)),
                      ]),
                      const SizedBox(height: 14),
                      _section('FEEL', [
                        _toggle('Vibration', Icons.vibration_rounded, s.vibration, (v) {
                          s.setVibration(v);
                          if (v) s.medium();
                        }),
                        const _Divider(),
                        _quality(s),
                      ]),
                      const SizedBox(height: 14),
                      _section('HOW TO PLAY', [
                        Text(
                          'Tap a rule to see how it works.',
                          style: oxa(12.5, color: Neon.dim, weight: 500),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final r in ruleInfos)
                              GestureDetector(
                                onTap: () => showRuleTutorial(context, r.bit),
                                child: RuleChip(rule: r),
                              ),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 14),
                      _section('ABOUT', [
                        _link('Privacy Policy', Icons.shield_outlined, () => _openPage(_privacyUrl)),
                        const _Divider(),
                        _link('Support', Icons.support_agent_rounded, () => _openPage(_supportUrl)),
                      ]),
                      const SizedBox(height: 14),
                      NeonButton(
                        label: 'RESET PROGRESS',
                        filled: false,
                        accent: Neon.red,
                        height: 48,
                        fontSize: 14,
                        icon: Icons.delete_outline_rounded,
                        onTap: _confirmReset,
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: Text(
                          'SOLAR GLEAM  ·  1.0.0',
                          style: oxa(10.5, color: Neon.faint, weight: 700, letterSpacing: 3),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return HoloPanel(
      accent: Neon.cyan,
      accent2: Neon.violet,
      fillAlpha: 0.72,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: oxa(11.5, color: Neon.cyan, weight: 800, letterSpacing: 3)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _toggle(String label, IconData icon, bool value, void Function(bool) onChanged) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        onChanged(!value);
        Sound.instance.play(Sfx.click);
      },
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Icon(icon, color: value ? Neon.cyan : Neon.faint, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: oxa(16, weight: 700))),
            _NeonSwitch(on: value),
          ],
        ),
      ),
    );
  }

  Widget _slider(double value, bool enabled, void Function(double) onChanged, {VoidCallback? onEnd}) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 5,
        activeTrackColor: Neon.cyan,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
        disabledActiveTrackColor: Neon.faint,
        disabledInactiveTrackColor: Colors.white.withValues(alpha: 0.06),
        thumbColor: Colors.white,
        disabledThumbColor: Neon.faint,
        overlayColor: Neon.cyan.withValues(alpha: 0.15),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
      ),
      child: Slider(
        value: value,
        onChanged: enabled ? onChanged : null,
        onChangeEnd: onEnd == null ? null : (_) => onEnd(),
      ),
    );
  }

  Widget _quality(GameSettings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: Neon.cyan, size: 22),
            const SizedBox(width: 12),
            Text('Effects quality', style: oxa(16, weight: 700)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final q in GraphicsQuality.values) ...[
              if (q != GraphicsQuality.low) const SizedBox(width: 8),
              Expanded(
                child: Pressable(
                  onTap: () => s.setQuality(q),
                  child: SizedBox(
                    height: 40,
                    child: HoloPanel(
                      accent: s.quality == q ? Neon.cyan : Neon.faint,
                      accent2: s.quality == q ? Neon.violet : Neon.edge,
                      cut: 9,
                      padding: EdgeInsets.zero,
                      fillAlpha: s.quality == q ? 0.95 : 0.4,
                      strong: s.quality == q,
                      child: Center(
                        child: Text(
                          q.name.toUpperCase(),
                          style: oxa(12, color: s.quality == q ? Neon.text : Neon.dim, weight: 800, letterSpacing: 1.6),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _link(String label, IconData icon, VoidCallback onTap) {
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Icon(icon, color: Neon.cyan, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: oxa(16, weight: 700))),
            const Icon(Icons.open_in_new_rounded, color: Neon.dim, size: 18),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Container(height: 1, color: Colors.white.withValues(alpha: 0.07)),
  );
}

class _NeonSwitch extends StatelessWidget {
  const _NeonSwitch({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 52,
      height: 28,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: on ? Neon.cyan.withValues(alpha: 0.28) : Colors.white.withValues(alpha: 0.07),
        border: Border.all(color: on ? Neon.cyan : Neon.faint, width: 1.4),
        boxShadow: on ? [BoxShadow(color: Neon.cyan.withValues(alpha: 0.4), blurRadius: 10)] : null,
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? Colors.white : Neon.dim,
          ),
        ),
      ),
    );
  }
}
