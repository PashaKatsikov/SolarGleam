import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/gleam_theme.dart';
import '../config/orbit_config.dart';
import '../net/reach_sensor.dart';
import 'notice_scaffold.dart';

/// No-internet screen. Retry rebuilds from [retryBuilder] using this page's own
/// mounted context.
class NoSignalPage extends StatefulWidget {
  const NoSignalPage({
    super.key,
    required this.sensor,
    required this.retryBuilder,
  });

  final ReachSensor sensor;
  final WidgetBuilder retryBuilder;

  @override
  State<NoSignalPage> createState() => _NoSignalPageState();
}

class _NoSignalPageState extends State<NoSignalPage> {
  bool _checking = false;
  bool _stillOffline = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _retry() async {
    if (_checking) return;
    HapticFeedback.lightImpact();
    setState(() {
      _checking = true;
      _stillOffline = false;
    });
    bool online = false;
    try {
      online = await widget.sensor.canReachNetwork();
    } catch (_) {
      online = false;
    }
    if (!mounted) return;
    if (online) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: widget.retryBuilder),
      );
      return;
    }
    setState(() {
      _checking = false;
      _stillOffline = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GleamColors.night,
      body: NoticePanel(
        icon: Icons.wifi_off_rounded,
        title: OrbitConfig.nowifiTitle,
        subtitle: OrbitConfig.nowifiSubtitle,
        actions: <Widget>[
          NoticeButton(
            label: OrbitConfig.retryLabel,
            icon: Icons.refresh_rounded,
            busy: _checking,
            onTap: _retry,
          ),
        ],
        footer: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: _stillOffline
              ? Text(
                  OrbitConfig.noConnectionYet,
                  textAlign: TextAlign.center,
                  style: rajdhani(
                    15,
                    Colors.white.withValues(alpha: 0.75),
                    weight: FontWeight.w700,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
