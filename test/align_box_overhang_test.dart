// A BOX ALIGNED IN ITS CONTAINER'S CONTENT BOX is aligned by what it LAYS
// OUT where that is past what it reports (`Overhangs`), as `SpotShift`
// aligns one: a `FractionalHeight` at `calc(50% + 60px)` of a 90px room is
// 105 tall however much of the room it reports. Chrome,
// `fixtures/positioned-share-calc` n13: an absolute box at `height: calc(50%
// + 20px)` centred by `align-items` in a 90px row is 65 tall and 12.5 down.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _box = ValueKey('box');

Widget _row(Widget aligned) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 240,
      height: 90,
      child: Stack(
        clipBehavior: Clip.none,
        children: [Positioned(left: 20, top: 0, bottom: 0, child: aligned)],
      ),
    ),
  ),
);

void main() {
  testWidgets('a share and a length that fit are centred in the room', (t) async {
    await t.pumpWidget(
      _row(
        const AlignBox(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: FractionalHeight(factor: 0.5, offset: 20, child: SizedBox(key: _box, width: 60)),
        ),
      ),
    );
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(20, 12.5, 60, 65));
  });

  testWidgets('a share and a length past the room are centred by what they lay out', (t) async {
    await t.pumpWidget(
      _row(
        const AlignBox(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: FractionalHeight(factor: 0.5, offset: 60, child: SizedBox(key: _box, width: 60)),
        ),
      ),
    );
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(20, -7.5, 60, 105));
  });

  testWidgets('and at the end, hung out past the start by what is past the room', (t) async {
    await t.pumpWidget(
      _row(
        const AlignBox(
          alignment: Alignment.bottomLeft,
          widthFactor: 1,
          child: FractionalHeight(factor: 0.5, offset: 60, child: SizedBox(key: _box, width: 60)),
        ),
      ),
    );
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(20, -15, 60, 105));
  });

  testWidgets('NEGATIVE: a stock Align centres the room the widget reports', (t) async {
    await t.pumpWidget(
      _row(
        const Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: FractionalHeight(factor: 0.5, offset: 60, child: SizedBox(key: _box, width: 60)),
        ),
      ),
    );
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(20, 0, 60, 105));
  });
}
