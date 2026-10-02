import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../assets.dart';
import '../game/gleam_settings.dart';
import '../game/slot_controller.dart';
import '../theme/gleam_theme.dart';
import '../widgets/image_slice.dart';
import '../widgets/loading_backdrop.dart';
import '../widgets/overlays.dart';
import 'browser_screen.dart';
import 'game_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  static const _privacyUrl = 'https://solar-gleam.com/privacy-policy';
  static const _supportUrl = 'https://solar-gleam.com/support';
  static const _logoSource = Size(512, 512);
  static const _logoRect = Rect.fromLTWH(9, 159, 494, 199);

  var _settings = false;
  var _playable = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    GleamSettings.instance.load();
  }

  Future<void> _openBrowser(String title, String url) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BrowserScreen(title: title, url: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.orientationOf(context) == Orientation.landscape) {
      return const Scaffold(
        backgroundColor: GleamColors.night,
        body: LoadingBackdrop(),
      );
    }

    return Scaffold(
      backgroundColor: GleamColors.night,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _MenuBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final buttonWidth = width >= 700 ? 420.0 : width * 0.72;
                final logoWidth = width >= 700 ? 460.0 : width * 0.78;
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          width: logoWidth,
                          height: logoWidth * (199 / 494),
                          child: const ImageSlice(
                            asset: GleamAssets.gameName,
                            source: _logoSource,
                            rect: _logoRect,
                          ),
                        ),
                        const SizedBox(height: 36),
                        _MenuButton(
                          label: 'PLAY',
                          width: buttonWidth,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const GameScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _MenuButton(
                          label: 'PLAYABLE',
                          width: buttonWidth,
                          onPressed: () => setState(() => _playable = true),
                        ),
                        const SizedBox(height: 16),
                        _MenuButton(
                          label: 'SETTINGS',
                          width: buttonWidth,
                          onPressed: () => setState(() => _settings = true),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_playable)
            PaytableSheet(
              bet: SlotController.bets[1],
              onClose: () => setState(() => _playable = false),
            ),
          if (_settings)
            _SettingsSheet(
              onClose: () => setState(() => _settings = false),
              onPrivacy: () => _openBrowser('Privacy Policy', _privacyUrl),
              onSupport: () => _openBrowser('Support', _supportUrl),
            ),
        ],
      ),
    );
  }
}

class _MenuBackground extends StatelessWidget {
  const _MenuBackground();

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
              colors: [Color(0x99000000), Color(0x33000000), Color(0xCC000000)],
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.width,
    required this.onPressed,
  });

  final String label;
  final double width;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF8A5A12), Color(0xFFF8D78A), Color(0xFFC8882B)],
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x88F0A020), blurRadius: 16),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: cinzel(18, GleamColors.ink, letterSpacing: 1.6),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({
    required this.onClose,
    required this.onPrivacy,
    required this.onSupport,
  });

  final VoidCallback onClose;
  final VoidCallback onPrivacy;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GleamSettings.instance,
      builder: (context, _) {
        final settings = GleamSettings.instance;
        return _SettingsPanel(
          vibration: settings.vibration,
          onVibration: settings.setVibration,
          onClose: onClose,
          onPrivacy: onPrivacy,
          onSupport: onSupport,
        );
      },
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.vibration,
    required this.onVibration,
    required this.onClose,
    required this.onPrivacy,
    required this.onSupport,
  });

  final bool vibration;
  final ValueChanged<bool> onVibration;
  final VoidCallback onClose;
  final VoidCallback onPrivacy;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xC006040E),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xF20C1022),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: GleamColors.gold, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66F0A020), blurRadius: 28),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 8, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Settings',
                              style: cinzel(22, GleamColors.goldLight),
                            ),
                          ),
                          IconButton(
                            onPressed: onClose,
                            icon: const Icon(
                              Icons.close,
                              color: GleamColors.gold,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: GleamColors.plaque,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: GleamColors.gold),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Vibration',
                                    style: cinzel(
                                      16,
                                      GleamColors.ivory,
                                      weight: 600,
                                    ),
                                  ),
                                ),
                                Switch.adaptive(
                                  value: vibration,
                                  activeTrackColor: GleamColors.goldDeep,
                                  activeThumbColor: GleamColors.goldLight,
                                  onChanged: onVibration,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      GoldTextButton(label: 'PRIVACY', onPressed: onPrivacy),
                      const SizedBox(height: 12),
                      GoldTextButton(label: 'SUPPORT', onPressed: onSupport),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
