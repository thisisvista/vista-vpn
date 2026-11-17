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
