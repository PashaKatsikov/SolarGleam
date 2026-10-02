import 'dart:convert';

import '../config/orbit_config.dart';
import '../core/relay_models.dart';
import '../core/veil_pack.dart';
import 'gleam_vault.dart';
import 'solar_agent.dart';
import 'trace.dart';

/// Posts the attribution payload to the edge relay as a sealed envelope and
/// parses the partner's verbatim answer.
class ConfigCall {
  ConfigCall(this._agent, this._vault);

  final SolarAgent _agent;
  final GleamVault _vault;

  Future<ConfigReply> request(Map<String, dynamic> payload) async {
    if (!OrbitConfig.grayCredentialsReady) {
      return ConfigReply.rejected('credentials_unavailable');
    }
    try {
      final envelope = VeilPack.seal(payload, secret: OrbitConfig.relaySecret);
      glmTrace(() => '[GLM.CALL] request ${jsonEncode(payload)}');
      final response = await _agent
          .post(
            Uri.parse(OrbitConfig.endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(envelope),
          )
          // Config POST timeout rotated per project (18 s).
          .timeout(const Duration(seconds: 18));
      glmTrace(
        () => '[GLM.CALL] response ${response.statusCode} ${response.body}',
      );
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
    } catch (error) {
      glmTrace(() => '[GLM.CALL] failed: $error');
      return ConfigReply.rejected('network_failure');
    }
  }
}
