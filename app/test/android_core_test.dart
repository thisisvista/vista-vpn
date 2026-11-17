import 'package:flutter_test/flutter_test.dart';
import 'package:vista_vpn/core/android_core.dart';

void main() {
  group('AppRouting', () {
    test('All apps mode ignores selections without deleting them', () {
      final routing = AppRouting(
        onlyChosen: false,
        allApps: true,
        bypass: {'com.example.bypass'},
        only: {'com.example.only'},
        suggested: {'com.example.bypass'},
      );

      expect(routing.checked('com.example.bypass'), isFalse);
      expect(routing.checked('com.example.only'), isFalse);
      expect(routing.bypass, contains('com.example.bypass'));
      expect(routing.only, contains('com.example.only'));
    });

    test('switching modes preserves both saved app lists', () {
      final routing = AppRouting(
        onlyChosen: false,
        allApps: true,
        bypass: {'com.example.bypass'},
        only: {'com.example.only'},
        suggested: const {},
      );

      routing.allApps = false;
      routing.onlyChosen = true;
      expect(routing.checked('com.example.only'), isTrue);
      expect(routing.checked('com.example.bypass'), isFalse);

      routing.onlyChosen = false;
      expect(routing.checked('com.example.bypass'), isTrue);
      expect(routing.checked('com.example.only'), isFalse);
    });

    test('All apps mode is represented in the routing key', () {
      final routing = AppRouting(
        onlyChosen: false,
        allApps: false,
        bypass: {'com.example.bypass'},
        only: {'com.example.only'},
        suggested: const {},
      );
      final excludeKey = routing.key;

      routing.allApps = true;
      expect(routing.key, isNot(excludeKey));
    });

    test('toggling an app while in All apps mode does not change lists', () {
      final routing = AppRouting(
        onlyChosen: false,
        allApps: true,
        bypass: {'com.example.bypass'},
        only: {'com.example.only'},
        suggested: const {},
      );

      routing.toggle('com.example.new', true);

      expect(routing.bypass, {'com.example.bypass'});
      expect(routing.only, {'com.example.only'});
    });
  });
}
