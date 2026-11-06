// A FLOOR OF THE CONTENT'S MOST PAST A TIGHT WIDTH, ASKED. `KeywordClamp`
// (floor: max) handed a tight width lays its content out at the larger of
// the width and the content's most (`clamp.dart`, `_bounded`), and the
// lossy pass writes an `IntrinsicWidth` let past the width by an
// `OverflowBox` of no ceiling for it (`lossy.dart`, `KeywordClamp ->
// OverflowBox(IntrinsicWidth)`). Laid out, the two are one page; asked:
// - a dry layout, the clamp answers at that larger width and the
//   `OverflowBox` at the width it is handed (`computeDryLayout`, fit
//   `deferToChild`: `child.getDryLayout(constraints)`);
// - its least width, the clamp answers its content's (a proxy) and the
//   `IntrinsicWidth` its content's most (`RenderIntrinsicWidth.
//   computeMinIntrinsicWidth`).
// A product site's `min-width: max-content` timeline header in a stretched column
// (`fixtures/keyword-floor-asked`). Each test lays both out side by side
// and compares the keyed rects; NEGATIVE cases are the questions asked
// under the words' width, where the two differ.
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

// The test font draws every glyph 14px wide at 14px: the words are 224px
// on one line, `aaaaaaaa` 112.
const _style = TextStyle(fontSize: 14, height: 1.0);
const _words = 'aaaaaaaa bb cccc';
const _para = ValueKey('para');
const _after = ValueKey('after');
const _other = ValueKey('other');

Widget _clamp(Widget c) => KeywordClamp(floor: ContentWidth.max, child: c);
Widget _stock(Widget c) => OverflowBox(
  maxWidth: double.infinity,
  fit: OverflowBoxFit.deferToChild,
  alignment: AlignmentDirectional.topStart,
  child: IntrinsicWidth(child: c),
);

Widget _page(Widget Function(Widget Function(Widget)) box, Widget Function(Widget) spelling, double width) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              box(spelling),
              const SizedBox(key: _after, height: 10),
            ],
          ),
        ),
      ),
    );

Future<Map<Key, Rect>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  return {
    for (final k in [_para, _after, if (find.byKey(_other).evaluate().isNotEmpty) _other]) k: t.getRect(find.byKey(k)),
  };
}

Future<bool> _same(WidgetTester t, Widget Function(Widget Function(Widget)) box, double width) async {
  final css = await _rects(t, _page(box, _clamp, width));
  final stock = await _rects(t, _page(box, _stock, width));
  return css.keys.every((k) => css[k] == stock[k]);
}

Widget _text() => const Text(_words, key: _para, style: _style);

void main() {
  testWidgets('laid out past a tight width, the two are one page', (t) async {
    Widget tight(Widget Function(Widget) s) => SizedBox(width: 50, child: s(_text()));
    Widget wide(Widget Function(Widget) s) => SizedBox(width: 300, child: s(_text()));
    // Asked its height, each answers its content's at the width it is asked at.
    Widget asked(Widget Function(Widget) s) => IntrinsicHeight(child: SizedBox(width: 50, child: s(_text())));
    for (final box in [tight, wide, asked]) {
      for (final w in const [60.0, 400.0]) {
        expect(await _same(t, box, w), isTrue, reason: '$w');
      }
    }
  });

  testWidgets('NEGATIVE: asked a dry layout, the OverflowBox answers at the width it is handed', (t) async {
    // A wrap answers its intrinsic height with a dry layout of its
    // children (`RenderWrap.computeMaxIntrinsicHeight`).
    Widget dry(Widget Function(Widget) s) => IntrinsicHeight(
      child: Wrap(children: [SizedBox(width: 50, child: s(_text()))]),
    );
    expect(await _same(t, dry, 400), isFalse);
    // Handed a width the words fit, there is nothing to let past.
    Widget fits(Widget Function(Widget) s) => IntrinsicHeight(
      child: Wrap(children: [SizedBox(width: 300, child: s(_text()))]),
    );
    expect(await _same(t, fits, 400), isTrue);
  });

  testWidgets('NEGATIVE: asked its least width, the IntrinsicWidth answers its most', (t) async {
    // An item a row floors at its min-content (css-flexbox-1 4.5).
    Widget row(Widget Function(Widget) s) => FlexLine(
      children: [
        FlexCell(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [s(_text())]),
        ),
        const FlexCell(shrink: 0, child: SizedBox(key: _other, width: 60, height: 10)),
      ],
    );
    expect(await _same(t, row, 200), isFalse);
    // Room for both, the floor binds nowhere.
    expect(await _same(t, row, 400), isTrue);
  });
}
