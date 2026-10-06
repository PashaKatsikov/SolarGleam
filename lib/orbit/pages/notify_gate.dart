import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/gleam_theme.dart';
import '../config/orbit_config.dart';
import '../net/gleam_vault.dart';
import '../net/push_agent.dart';
import 'notice_scaffold.dart';

/// Notification permission prompt shown once before the web module opens.
class NotifyGate extends StatefulWidget {
  const NotifyGate({
    super.key,
    required this.vault,
    required this.push,
    required this.nextBuilder,
    this.onTokenReady,
  });

  final GleamVault vault;
  final PushAgent push;
  final WidgetBuilder nextBuilder;
  final Future<void> Function(String token)? onTokenReady;

  @override
  State<NotifyGate> createState() => _NotifyGateState();
}

class _NotifyGateState extends State<NotifyGate> {
  bool _working = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _accept() async {
    if (_working) return;
    setState(() => _working = true);
    final granted = await widget.push.askPermission();
    final token = widget.push.token;
    if (granted && token != null && token.isNotEmpty) {
      await widget.onTokenReady?.call(token);
    }
    if (!granted) await _snooze();
    _continue();
  }

  Future<void> _skip() async {
    if (_working) return;
    setState(() => _working = true);
    await _snooze();
    _continue();
  }

  Future<void> _snooze() {
    final until = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        OrbitConfig.pushSnoozeSeconds;
    return widget.vault.snoozePushInvite(until);
  }

  void _continue() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: widget.nextBuilder));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GleamColors.night,
      body: NoticePanel(
        icon: Icons.notifications_active_rounded,
        title: OrbitConfig.notifyTitle,
        subtitle: OrbitConfig.notifySubtitle,
        actions: <Widget>[
          NoticeButton(
            label: OrbitConfig.notifyAccept,
            busy: _working,
            onTap: _accept,
          ),
          const SizedBox(height: 14),
          NoticeButton(
            label: OrbitConfig.notifySkip,
            emphasized: false,
            onTap: _skip,
          ),
        ],
      ),
    );
  }
}
