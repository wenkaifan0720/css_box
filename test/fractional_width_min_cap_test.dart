// A FLOOR AT THE SMALLER OF A SHARE AND A LENGTH (`FractionalWidth.minCap`):
// `width: 30%; min-width: min(50%, 300px)` is half the room up to 600 and
// 300 past it, over the width's own 30% (css-values-4 10.9, CSS 2.1 10.4).
// Chrome, `fixtures/abs-share-clamped` n10: the box placed from the right of
// a block 70% of the page wide is 300 wide at 1440 (a 985.6px block) and at
// 1000 (677.6), where the width's 30% is 295.7 and 203.3.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _box = ValueKey('box');

// A window as wide as the page's, where the default 800 would cap the room.
void _wide(WidgetTester t) {
  t.view.physicalSize = const Size(1440, 600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Widget _page(double room, {double? cap = 300}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: room,
      child: FractionalWidth(
        factor: 0.3,
        minFactor: 0.5,
        minCap: cap,
        alignment: Alignment.topRight,
        child: const SizedBox(key: _box, height: 10),
      ),
    ),
  ),
);

void main() {
  for (final (room, want) in [(400.0, 200.0), (600.0, 300.0), (677.6, 300.0), (985.6, 300.0), (1200.0, 360.0)]) {
    testWidgets('30% floored at min(50%, 300px) of $room is $want', (t) async {
      _wide(t);
      await t.pumpWidget(_page(room));
      expect(t.getSize(find.byKey(_box)).width, closeTo(want, 1e-9));
      // Standing on the right, as the inset it has puts it.
      expect(t.getTopLeft(find.byKey(_box)).dx, closeTo(room - want, 1e-9));
    });
  }

  testWidgets('NEGATIVE: with no ceiling the share floor alone binds', (t) async {
    // Half of 985.6, where the ceiling made it 300.
    _wide(t);
    await t.pumpWidget(_page(985.6, cap: null));
    expect(t.getSize(find.byKey(_box)).width, closeTo(492.8, 1e-9));
  });
}
