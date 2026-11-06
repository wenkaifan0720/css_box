// FIT-CONTENT IS THE CONTENT WHERE AN ITEM PAST THE ROOM IS A RUN OF ITS
// OWN (css-sizing-3 5.1; css-flexbox-1 9.2 step 3 E, 4.5, 9.3 step 5, 9.7):
// `width: fit-content; min-width: fit-content` is the item's max-content M
// where it fits the line's room L, and max(m, L) where it does not (m its
// min-content) -- L at least, so in a wrap across a gap it is a run of its
// own, as an item of a content basis is, which the run shrinks to L floored
// at m: the same box. A product site's calls to action are buttons of the two
// keywords, each a flex box centring its label, two to a centred wrap 16
// apart and one alone in a row. The lowerer (`lossy_flex.dart`,
// `_fitAsContentL`) reads the keywords as none there, and the stock pass
// writes the items as it writes any of their content: a label centred by an
// `Align` of no factor across takes all of a width it is handed, so it is
// measured to its content (`_fillsL`: an `IntrinsicWidth` in the `Wrap`, in
// the `Flexible` of a row) (`fixtures/flex-wrap-fit-content-basis`). This
// pins the line with the keywords to the line without them at widths where
// the labels fit (p1), pass the room (L between m and M) and pass it past
// their longest word, in a wrap and alone in a row (p3); and to the stock
// spelling where the room holds every label's longest word.
// NEGATIVE: an item that does not shrink, which the keyword holds to the
// room where its content basis passes it (n1); two side by side in a row
// that does not wrap, which the row shrinks together from bases the
// keyword clamps first (n2); a wrap with no gap, where an item of no length
// joins the run of a button the keyword makes the room exactly (n3); and a
// centred label in a `Wrap` unmeasured, which takes all of its run (n4).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _style = TextStyle(fontSize: 16, height: 1.375);

/// A button: its label in its padding, centred by an `Align` of one line's
/// height where [aligned] (the product site's `display: flex; justify-content:
/// center`), or the bare words.
Widget _button(String key, String label, {required bool aligned}) {
  final Widget text = Text(label, style: _style, textAlign: TextAlign.center);
  return DecoratedBox(
    key: ValueKey(key),
    decoration: const BoxDecoration(color: Color(0xFF181D26)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 17),
      child: aligned ? Align(heightFactor: 1, child: text) : text,
    ),
  );
}

const _labels = ['Get started for free', 'Book demo'];

Widget _frame(Widget line, double width) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: line),
  ),
);

FlexCell _cell(int i, {required bool keywords, required bool aligned, double shrink = 1}) => keywords
    ? FlexCell(
        shrink: shrink,
        basisKeyword: FlexKeyword.fitContent,
        minKeyword: FlexKeyword.fitContent,
        child: _button('b$i', _labels[i], aligned: aligned),
      )
    : FlexCell(
        shrink: shrink,
        child: _button('b$i', _labels[i], aligned: aligned),
      );

Widget _wrap({
  required bool keywords,
  bool aligned = false,
  double spacing = 16,
  double shrink = 1,
  bool mark = false,
}) => FlexLine(
  mainAxisAlignment: MainAxisAlignment.center,
  crossAxisAlignment: CrossAxisAlignment.start,
  spacing: spacing,
  wrap: true,
  runSpacing: 16,
  children: [
    _cell(0, keywords: keywords, aligned: aligned, shrink: shrink),
    if (mark) const SizedBox(key: ValueKey('mark'), width: 0, height: 10),
    _cell(1, keywords: keywords, aligned: aligned, shrink: shrink),
  ],
);

Widget _alone({required bool keywords, bool aligned = false}) => FlexLine(
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [_cell(0, keywords: keywords, aligned: aligned)],
);

/// The wrap as the stock pass writes items of their content: a centred
/// label measured to it.
Widget _stockWrap({required bool aligned, bool measured = true}) => Wrap(
  alignment: WrapAlignment.center,
  spacing: 16,
  runSpacing: 16,
  crossAxisAlignment: WrapCrossAlignment.start,
  children: [
    for (var i = 0; i < 2; i++)
      aligned && measured
          ? IntrinsicWidth(child: _button('b$i', _labels[i], aligned: true))
          : _button('b$i', _labels[i], aligned: aligned),
  ],
);

/// The row of one as the stock pass writes it: the item `Flexible`, a
/// centred label measured to its content.
Widget _stockAlone({required bool aligned}) => Row(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    Flexible(
      flex: 130,
      child: aligned
          ? IntrinsicWidth(child: _button('b0', _labels[0], aligned: true))
          : _button('b0', _labels[0], aligned: false),
    ),
  ],
);

Future<List<Rect>> _rects(WidgetTester t, Widget w, [List<String> keys = const ['b0', 'b1']]) async {
  await t.pumpWidget(w);
  return [for (final k in keys) t.getRect(find.byKey(ValueKey(k)))];
}

void main() {
  // The FlutterTest face: a glyph is as wide as the font is tall. "Get
  // started for free" is 320 wide in one line, its longest word 112; each
  // button 50 more.
  for (final aligned in const [false, true]) {
    for (final width in const [400.0, 300.0, 250.0, 170.0, 150.0, 100.0]) {
      testWidgets(
        'p1, p2: fit-content in a wrap across a gap is the content, $width wide${aligned ? ', centred' : ''}',
        (t) async {
          final keyed = await _rects(t, _frame(_wrap(keywords: true, aligned: aligned), width));
          final plain = await _rects(t, _frame(_wrap(keywords: false, aligned: aligned), width));
          expect(keyed, plain);
          // The long button is its content clamped into the room, never under
          // its longest word.
          expect(keyed[0].width, (width < 370 ? (width > 162 ? width : 162) : 370).toDouble());
          // Where the room holds every longest word, the stock `Wrap` is it.
          if (width >= 162) expect(await _rects(t, _frame(_stockWrap(aligned: aligned), width)), plain);
        },
      );

      testWidgets('p3: fit-content alone in a row is the content, $width wide${aligned ? ', centred' : ''}', (t) async {
        final keyed = await _rects(t, _frame(_alone(keywords: true, aligned: aligned), width), const ['b0']);
        final plain = await _rects(t, _frame(_alone(keywords: false, aligned: aligned), width), const ['b0']);
        expect(keyed, plain);
        if (width >= 162) expect(await _rects(t, _frame(_stockAlone(aligned: aligned), width), const ['b0']), plain);
      });
    }
  }

  testWidgets('NEGATIVE n1: an item that does not shrink is held to the room by the keyword', (t) async {
    final keyed = await _rects(t, _frame(_wrap(keywords: true, shrink: 0), 250));
    final plain = await _rects(t, _frame(_wrap(keywords: false, shrink: 0), 250));
    expect(keyed[0].width, 250);
    expect(plain[0].width, 370);
  });

  testWidgets('NEGATIVE n2: side by side in a row that does not wrap, the keyword clamps the bases first', (t) async {
    Widget row(bool keywords) => _frame(
      FlexLine(
        children: [
          _cell(0, keywords: keywords, aligned: false),
          _cell(1, keywords: keywords, aligned: false),
        ],
      ),
      200,
    );
    final keyed = await _rects(t, row(true));
    final plain = await _rects(t, row(false));
    expect(keyed[0].width, isNot(plain[0].width));
  });

  testWidgets('NEGATIVE n3: no gap, an item of no length joins the run the keyword fills', (t) async {
    const keys = ['b0', 'mark', 'b1'];
    final keyed = await _rects(t, _frame(_wrap(keywords: true, spacing: 0, mark: true), 250), keys);
    final plain = await _rects(t, _frame(_wrap(keywords: false, spacing: 0, mark: true), 250), keys);
    expect(keyed[0].width, 250);
    expect(keyed[1].top, keyed[0].top);
    expect(plain[1].top, greaterThan(plain[0].top));
  });

  testWidgets('NEGATIVE n4: a centred label unmeasured in a Wrap takes all of its run', (t) async {
    final keyed = await _rects(t, _frame(_wrap(keywords: true, aligned: true), 400));
    final bare = await _rects(t, _frame(_stockWrap(aligned: true, measured: false), 400));
    expect(keyed[1].width, 194);
    expect(bare[1].width, 400);
  });
}
