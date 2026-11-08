import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _pic = ValueKey('pic'), _measured = ValueKey('measured');

Widget _page(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(alignment: Alignment.topLeft, child: child),
);

// A picture at `max-width: 100%`: the cap of the whole room, squeezable to
// nothing (css-sizing-3 5.2.2).
Widget _capped(Widget child) => FractionalConstraints(maxFactor: 1, compressible: true, child: child);

// `width: 127px` beside the picture's ratio, 127x52.
Widget _logo() => SizedBox(
  key: _pic,
  width: 127,
  child: AspectRatio(aspectRatio: 127 / 52, child: Container()),
);

// The room [room] wide, asked how tall the picture is by an `IntrinsicHeight`
// round a column that centres its items.
Widget _asked(double room, Widget picture) => _page(
  SizedBox(
    width: room,
    child: IntrinsicHeight(
      key: _measured,
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [_capped(picture)]),
    ),
  ),
);

RenderBox _box(WidgetTester t) => t.renderObject<RenderBox>(find.byType(FractionalConstraints));

void main() {
  // A picture of a stated width stays that width in a wider room (CSS 2.1
  // 10.4), and is as tall as its ratio makes that width: asked at the
  // room, the `SizedBox` handed the room on to the ratio.
  testWidgets('a picture narrower than its room answers its own height, not the room\'s', (t) async {
    await t.pumpWidget(_asked(192, _logo()));
    expect(t.getSize(find.byKey(_pic)).width, 127);
    expect(t.getSize(find.byKey(_pic)).height, closeTo(52, 1e-9));
    expect(_box(t).getMinIntrinsicHeight(192), closeTo(52, 1e-9));
    expect(_box(t).getMaxIntrinsicHeight(192), closeTo(52, 1e-9));
    expect(t.getSize(find.byKey(_measured)).height, closeTo(52, 1e-9));
  });

  testWidgets('a picture wider than its room is capped to it and answers the room\'s height', (t) async {
    await t.pumpWidget(_asked(100, _logo()));
    expect(t.getSize(find.byKey(_pic)).width, 100);
    expect(_box(t).getMaxIntrinsicHeight(100), closeTo(100 * 52 / 127, 1e-9));
    expect(t.getSize(find.byKey(_measured)).height, closeTo(100 * 52 / 127, 1e-9));
  });

  // NEGATIVE: a ratio of no width fills the room it is handed, so the room
  // is the width it is asked at, as before -- even where what it holds is
  // narrower, which its max-content width would say instead.
  testWidgets('NEGATIVE: a ratio child of no width keeps the room\'s answer', (t) async {
    await t.pumpWidget(_asked(192, AspectRatio(key: _pic, aspectRatio: 2, child: Container())));
    expect(t.getSize(find.byKey(_pic)), const Size(192, 96));
    expect(_box(t).getMaxIntrinsicHeight(192), 96);
    expect(t.getSize(find.byKey(_measured)).height, 96);
  });

  testWidgets('NEGATIVE: a ratio round a narrower box is the room wide, and answers there', (t) async {
    await t.pumpWidget(
      _asked(
        192,
        const AspectRatio(
          key: _pic,
          aspectRatio: 2,
          child: Center(child: SizedBox(width: 50, height: 25)),
        ),
      ),
    );
    expect(_box(t).getMaxIntrinsicWidth(double.infinity), 50);
    expect(t.getSize(find.byKey(_pic)), const Size(192, 96));
    expect(_box(t).getMinIntrinsicHeight(192), 96);
    expect(_box(t).getMaxIntrinsicHeight(192), 96);
    expect(t.getSize(find.byKey(_measured)).height, 96);
  });

  // NEGATIVE: a child that is no width in the room it is handed says
  // nothing about where it would stand: it is asked at the room, as before.
  testWidgets('NEGATIVE: a child of no width is asked at the room', (t) async {
    await t.pumpWidget(_asked(192, const SizedBox(key: _pic, width: 0, height: 30)));
    expect(_box(t).getMaxIntrinsicHeight(192), 30);
    expect(t.getSize(find.byKey(_measured)).height, 30);
  });

  // A box of text keeps its line breaks at the width it is laid out at:
  // one line asked at its own width is one line.
  testWidgets('words narrower than the room answer one line, as at the room', (t) async {
    const words = Text('Trusted by', key: _pic, style: TextStyle(fontSize: 16, height: 1.25));
    await t.pumpWidget(_asked(400, words));
    final one = t.getSize(find.byKey(_pic)).height;
    expect(_box(t).getMaxIntrinsicHeight(400), one);
    expect(t.getSize(find.byKey(_measured)).height, one);
  });
}
