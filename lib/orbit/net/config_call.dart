import 'dart:convert';

import '../config/orbit_config.dart';
import '../core/flow_models.dart';
import '../core/body_signer.dart';
import 'gleam_vault.dart';
import 'solar_agent.dart';

/// Sends the composed payload to the endpoint as a sealed envelope and parses
/// the response.
class ConfigCall {
  ConfigCall(this._agent, this._vault);

  final SolarAgent _agent;
  final GleamVault _vault;

  Future<ConfigReply> request(Map<String, dynamic> payload) async {
    if (!OrbitConfig.credentialsReady) {
      return ConfigReply.rejected('credentials_unavailable');
    }
    try {
      final envelope = BodySigner.seal(payload, secret: OrbitConfig.signingSecret);
      final response = await _agent
          .post(
            Uri.parse(OrbitConfig.endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(envelope),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return ConfigReply.rejected('http_${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return ConfigReply.rejected('invalid_response');
      final reply = ConfigReply.fromJson(Map<String, dynamic>.from(decoded));
      if (reply.hasDestination) {
        await _vault.cacheUrl(reply.url!, reply.expiresAt);
      }
      return reply;
    } catch (_) {
      return ConfigReply.rejected('network_failure');
    }
  }
}
