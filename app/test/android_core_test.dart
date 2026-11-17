import 'package:flutter_test/flutter_test.dart';
import 'package:vista_vpn/core/android_core.dart';

void main() {
  group('AppRouting', () {
    test('All apps mode ignores selections without deleting saved lists', () {
      final routing = AppRouting(
        allApps: true,
        bypass: {'com.example.bypass'},
        only: {'com.example.legacy'},
      );
      expect(routing.checked('com.example.bypass'), isFalse);
      expect(routing.checked('com.example.legacy'), isFalse);
      expect(routing.bypass, contains('com.example.bypass'));
      expect(routing.only, contains('com.example.legacy'));
    });

    test('switching between all and bypass preserves saved lists', () {
      final routing = AppRouting(
        allApps: true,
        bypass: {'com.example.bypass'},
        only: {'com.example.legacy'},
      );
      routing.allApps = false;
      expect(routing.checked('com.example.bypass'), isTrue);
      expect(routing.checked('com.example.legacy'), isFalse);
    });

    test('All apps mode is represented in the routing key', () {
      final routing = AppRouting(
        bypass: {'com.example.bypass'},
        only: {'com.example.legacy'},
      );
      final bypassKey = routing.key;
      routing.allApps = true;
      expect(routing.key, isNot(bypassKey));
    });

    test('toggling an app in bypass mode changes only the bypass list', () {
      final routing = AppRouting(
        bypass: {'com.example.bypass'},
        only: {'com.example.legacy'},
      );
      routing.toggle('com.example.new', true);
      expect(routing.bypass, {'com.example.bypass', 'com.example.new'});
      expect(routing.only, {'com.example.legacy'});
    });

    test('toggling an app while in All apps mode does not change lists', () {
      final routing = AppRouting(
        allApps: true,
        bypass: {'com.example.bypass'},
        only: {'com.example.legacy'},
      );
      routing.toggle('com.example.new', true);
      expect(routing.bypass, {'com.example.bypass'});
      expect(routing.only, {'com.example.legacy'});
    });
  });
}
