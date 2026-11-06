// A FIT-CONTENT BOX OF ONE WORD PAST ITS ROOM, ASKED. `ShrinkWidth`
// (spill) round content of one width lays it out at that width, past a
// narrower room, and answers an intrinsic height and a dry layout there too
// (`shrink.dart`, `_fit`, `computeMaxIntrinsicHeight`, `computeDryLayout`);
// the lossy pass writes an `IntrinsicWidth` let past the room by an
// `OverflowBox` of no ceiling for it (`lossy.dart`, `ShrinkWidth ->
// OverflowBox (content of one width, past the room)`), which answers both
// at the room (`RenderShiftedBox`, `RenderIntrinsicWidth` at a finite
// width; `computeDryLayout`, fit `deferToChild`). A word Skia breaks where
// it is wider than the width is then taller: a music store's store badges, a
// padded `iOS` in a line of text (`fixtures/shrink-spill-asked`). NEGATIVE:
// a line that never wraps and a box of pixels are one height at any width,
// and at the word or wider the two are one page.
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

// The test font draws every glyph 14px wide at 14px: `aaaaaaaa` is 112px.
const _style = TextStyle(fontSize: 14, height: 1.0);
const _para = ValueKey('para');
const _after = ValueKey('after');

Widget _css(Widget c) => ShrinkWidth(spill: true, child: c);
Widget _stock(Widget c) => OverflowBox(
  maxWidth: double.infinity,
  fit: OverflowBoxFit.deferToChild,
  alignment: AlignmentDirectional.topStart,
  child: IntrinsicWidth(child: c),
);

Widget _page(Widget box, double width) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          box,
          const SizedBox(key: _after, height: 10),
        ],
      ),
    ),
  ),
);

// Where the content starts, how tall it is, and where the box after it
// is. (A line that never wraps draws the same whatever width its
// paragraph is handed, which `constrain` sets.)
Future<List<Object>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  final para = t.getRect(find.byKey(_para));
  return [para.topLeft, para.height, t.getRect(find.byKey(_after))];
}

Future<bool> _same(WidgetTester t, Widget Function(Widget) around, Widget content, double width) async {
  final css = await _rects(t, _page(around(_css(content)), width));
  final stock = await _rects(t, _page(around(_stock(content)), width));
  return [for (var i = 0; i < css.length; i++) css[i] == stock[i]].every((v) => v);
}

void main() {
  const word = Text('aaaaaaaa', key: _para, style: _style);
  const nowrap = Text('aaaa bbbb', key: _para, style: _style, softWrap: false);
  const pixels = SizedBox(key: _para, width: 112, height: 20);

  testWidgets('laid out, the two are one page', (t) async {
    Widget plain(Widget box) => box;
    for (final w in const [50.0, 200.0]) {
      for (final c in const [word, nowrap, pixels]) {
        expect(await _same(t, plain, c, w), isTrue, reason: '$w $c');
      }
    }
  });

  testWidgets('NEGATIVE: asked its height under the word, the OverflowBox answers at the room', (t) async {
    Widget asked(Widget box) => IntrinsicHeight(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [box]),
    );
    expect(await _same(t, asked, word, 50), isFalse);
    // At the word or wider, and round content of one height.
    expect(await _same(t, asked, word, 200), isTrue);
    expect(await _same(t, asked, nowrap, 50), isTrue);
    expect(await _same(t, asked, pixels, 50), isTrue);
  });

  testWidgets('NEGATIVE: asked a dry layout under the word, the OverflowBox answers at the room', (t) async {
    // A wrap answers its intrinsic height with a dry layout of its
    // children (`RenderWrap.computeMaxIntrinsicHeight`).
    Widget dry(Widget box) => IntrinsicHeight(
      child: Wrap(
        children: [
          SizedBox(
            width: 50,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [box]),
          ),
        ],
      ),
    );
    expect(await _same(t, dry, word, 300), isFalse);
    expect(await _same(t, dry, nowrap, 300), isTrue);
    expect(await _same(t, dry, pixels, 300), isTrue);
  });
}
