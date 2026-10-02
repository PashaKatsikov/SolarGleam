/// Routing decision persisted per install.
enum GleamRoute {
  native,
  portal,
  undecided;

  String get storageValue => switch (this) {
    GleamRoute.native => 'native',
    GleamRoute.portal => 'portal',
    GleamRoute.undecided => 'undecided',
  };

  static GleamRoute parse(String? value) => switch (value) {
    'portal' || 'web' => GleamRoute.portal,
    'native' || 'game' => GleamRoute.native,
    _ => GleamRoute.undecided,
  };
}

/// Parsed answer from the config relay.
class ConfigReply {
  const ConfigReply({
    required this.accepted,
    this.url,
    this.expiresAt,
    this.reason,
  });

  factory ConfigReply.fromJson(Map<String, dynamic> json) {
    final rawExpiry = json['expires'];
    return ConfigReply(
      accepted: json['ok'] == true,
      url: json['url'] is String ? json['url'] as String : null,
      expiresAt: rawExpiry is num
          ? rawExpiry.toInt()
          : int.tryParse(rawExpiry?.toString() ?? ''),
      reason: json['message']?.toString(),
    );
  }

  factory ConfigReply.rejected(String reason) =>
      ConfigReply(accepted: false, reason: reason);

  final bool accepted;
  final String? url;
  final int? expiresAt;
  final String? reason;

  bool get hasDestination => accepted && (url?.isNotEmpty ?? false);
}

/// Where the boot flow should land.
sealed class GleamStop {
  const GleamStop();
}

final class NativeStop extends GleamStop {
  const NativeStop();
}

final class PortalStop extends GleamStop {
  const PortalStop(this.url, {this.coldLaunch = false});

  final String url;
  final bool coldLaunch;
}

final class OfflineStop extends GleamStop {
  const OfflineStop({required this.returnToNative});

  final bool returnToNative;
}
