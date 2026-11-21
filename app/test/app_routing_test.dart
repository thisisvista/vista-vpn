import 'package:flutter_test/flutter_test.dart';
import 'package:vista_vpn/core/android_core.dart';

AppRouting routing() => AppRouting(
  allApps: false,
  bypass: {'my.bank'},
  only: {},
);

void main() {
  test('only manually selected apps are bypassed', () {
    final r = routing();
    expect(r.checked('ir.bale'), isFalse);
    expect(r.checked('my.bank'), isTrue);
    r.toggle('ir.bale', true);
    expect(r.checked('ir.bale'), isTrue);
    r.toggle('ir.bale', false);
    expect(r.checked('ir.bale'), isFalse);
  });

  test('toggling bypass selections never changes the legacy only-list', () {
    final r = routing();
    r.toggle('org.telegram', true);
    expect(r.bypass, {'my.bank', 'org.telegram'});
    expect(r.only, isEmpty);
  });

  test('the key changes with bypass selections and all-app mode', () {
    final r = routing();
    final before = r.key;
    r.toggle('org.telegram', true);
    expect(r.key, isNot(before));
    final selectedKey = r.key;
    r.allApps = true;
    expect(r.key, isNot(selectedKey));
  });

  test('Tunnel Selected Apps edits only the VPN allow-list', () {
    final r = AppRouting(
      tunnelSelectedApps: true,
      bypass: {'com.example.direct'},
      only: {'com.example.vpn'},
    );
    expect(r.mode, 'include');
    expect(r.checked('com.example.vpn'), isTrue);
    expect(r.checked('com.example.direct'), isFalse);
    r.toggle('com.example.new-vpn', true);
    expect(r.only, {'com.example.vpn', 'com.example.new-vpn'});
    expect(r.bypass, {'com.example.direct'});
    r.toggle('com.example.vpn', false);
    expect(r.only, {'com.example.new-vpn'});
  });

  test('All apps mode ignores selections without deleting saved bypass list', () {
    final r = AppRouting(
      allApps: true,
      bypass: {'com.example.bypass'},
      only: {'com.example.legacy'},
    );
    expect(r.checked('com.example.bypass'), isFalse);
    r.toggle('com.example.new', true);
    expect(r.bypass, {'com.example.bypass'});
    expect(r.only, {'com.example.legacy'});
  });
}
