import 'package:flutter_test/flutter_test.dart';
import 'package:vista_vpn/core/android_core.dart';

AppRouting routing() => AppRouting(
  onlyChosen: false,
  bypass: {'my.bank'},
  only: {},
);

void main() {
  test('only manually selected apps are checked', () {
    final r = routing();
    expect(r.checked('ir.bale'), isFalse);
    expect(r.checked('my.bank'), isTrue);
    r.toggle('ir.bale', true);
    expect(r.checked('ir.bale'), isTrue);
    r.toggle('ir.bale', false);
    expect(r.checked('ir.bale'), isFalse);
  });

  test('proxy selected apps keeps its own choice', () {
    final r = routing()..onlyChosen = true;
    expect(r.checked('my.bank'), isFalse);
    r.toggle('org.telegram', true);
    expect(r.only, {'org.telegram'});
    expect(r.bypass, {'my.bank'});
  });

  test('the key changes with the choice', () {
    final r = routing();
    final before = r.key;
    r.toggle('org.telegram', true);
    expect(r.key, isNot(before));
  });
}
