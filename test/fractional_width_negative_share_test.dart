// A WIDTH IS NEVER LESS THAN NOTHING (`FractionalWidth._share`):
// `calc(50% - 20.5px)` of a room narrower than 41px resolves below zero, and
// CSS clamps it to zero before `min-width` and `max-width` apply
// (css-values-4 10.12). Asked its depth at such a room, the box asked its
// child at a negative width and Flutter asserted (`getMaxIntrinsicHeight`).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _box = ValueKey('box');
const _share = ValueKey('share');

Widget _page(double room, {double? min}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: room,
      child: FractionalWidth(
        key: _share,
        factor: 0.5,
        offset: -20.5,
        min: min,
        child: const SizedBox(key: _box, height: 10),
      ),
    ),
  ),
);

void main() {
  for (final room in [0.0, 30.0, 40.0]) {
    testWidgets('calc(50% - 20.5px) of $room is nothing, laid out and asked', (t) async {
      await t.pumpWidget(_page(room));
      expect(t.takeException(), isNull);
      expect(t.getSize(find.byKey(_box)).width, 0);
      final share = t.renderObject<RenderBox>(find.byKey(_share));
      expect(share.getMaxIntrinsicHeight(room), 10);
      expect(share.getMinIntrinsicHeight(room), 10);
    });
  }

  testWidgets('the floor applies after the clamp: min-width 12px of a share under nothing is 12', (t) async {
    await t.pumpWidget(_page(30, min: 12));
    expect(t.getSize(find.byKey(_box)).width, 12);
  });

  testWidgets('NEGATIVE: a room past 41px keeps the share as it was', (t) async {
    // 50 - 20.5 and 150 - 20.5.
    for (final (room, want) in [(100.0, 29.5), (300.0, 129.5)]) {
      await t.pumpWidget(_page(room));
      expect(t.getSize(find.byKey(_box)).width, want);
    }
  });
}
