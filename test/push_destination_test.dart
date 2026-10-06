import 'package:flutter_test/flutter_test.dart';
import 'package:solar_gleam/orbit/net/push_agent.dart';

void main() {
  group('push destination extraction', () {
    test('http links are preserved as http', () {
      expect(
        PushAgent.destinationFrom(<String, dynamic>{
          'url': 'http://promo.example.com/offer?id=7',
        }),
        'http://promo.example.com/offer?id=7',
      );
    });

    test('https links are preserved', () {
      expect(
        PushAgent.destinationFrom(<String, dynamic>{
          'link': 'https://play.example.com/bonus',
        }),
        'https://play.example.com/bonus',
      );
    });

    test('scheme-less links default to https', () {
      expect(
        PushAgent.destinationFrom(<String, dynamic>{
          'deep_link': 'promo.example.com/x',
        }),
        'https://promo.example.com/x',
      );
    });

    test('whitespace is trimmed', () {
      expect(
        PushAgent.normalizeUrl('  http://a.example.com/  '),
        'http://a.example.com/',
      );
    });

    test('nested data payloads resolve', () {
      expect(
        PushAgent.destinationFrom(<String, dynamic>{
          'data': <String, dynamic>{'target': 'http://nested.example.com'},
        }),
        'http://nested.example.com',
      );
    });

    test('missing / empty links yield null', () {
      expect(PushAgent.destinationFrom(<String, dynamic>{}), isNull);
      expect(PushAgent.destinationFrom(<String, dynamic>{'url': '   '}), isNull);
    });
  });
}
