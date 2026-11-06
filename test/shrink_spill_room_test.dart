// A FIT-CONTENT BOX OF CONTENT OF ONE WIDTH, NEVER ASKED UNDER THAT WIDTH,
// IS ITS STOCK SPELLING. `ShrinkWidth` (spill) round content whose
// min-content is its max-content (css-sizing-3 5.1) lays it out at that
// width w and answers an intrinsic height and a dry layout there too
// (`shrink.dart`, `_fit`: min(max(w, room), w) is w); the lossy pass writes
// an `IntrinsicWidth` let past the room by an `OverflowBox` of no ceiling
// for it, which answers both at the width it is asked at
// (`RenderShiftedBox`; `RenderIntrinsicWidth.computeMaxIntrinsicHeight` at
// a finite width; `RenderConstrainedOverflowBox.computeDryLayout`, fit
// `deferToChild`, hands its child the outer constraints, which
// `RenderIntrinsicWidth` tightens to w where they reach that far). Under w
// the two differ -- Skia breaks the word between letters
// (`shrink_spill_asked_test.dart`) -- and at w or wider they are one page:
// a dry layout is the content laid out tight at w, or at a floor past it,
// either way, and an intrinsic height is the content's at w and at the
// width asked, one height where the content's lines at its max-content
// are its lines at any width past it: a word, a padded word, two words
// held at their max-content. The lossy pass reads the least width any
// question reaches the box at (`tidy.dart`, `_roomFloor`) and frees it
// where the content's max-content fits there (`lossy.dart`, `_askedPastL`,
// `fixtures/shrink-spill-room`).
// And CONTENT OF ONE HEIGHT AT ANY WIDTH is the stock spelling asked at
// any width (`_heightAtAnyWidthL`): a word in its line box, which lays the
// word out whole however narrow the width it is asked at (`linebox.dart`,
// `_width`, `_room`), and a row of pixels let out of a padded border by an
// `OverflowBox` (`RenderFlex` lays a child that does not flex out with no
// bound along the row); that word set pretty (`RenderBalance` is a proxy)
// or aligned (`AlignBox`); and a line that never wraps with a widget hung
// above its baseline (`RenderParagraph` lays its widgets out dry under the
// width it is asked at, its text at no bound: `_adjustMaxWidth`); and a
// row that flexes a box of a stated height (`RenderFlex` asks and lays a
// flexible child out at its share).
// NEGATIVE: a width under the word; a box of a stated width round words
// that wrap in it, whose height a `SizedBox` answers at the width it is
// asked at, not its own (`RenderConstrainedBox` hands the question on):
// laid out, and asked a dry layout, the two are one; asked a height past the
// stated width, they are not; a widget on the line's baseline whose
// first line moves with the width it is asked at; and a row flexing words
// that wrap in their share.
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

// The test font draws every glyph 14px wide at 14px: `aaaaaaaa` is 112px.
const _style = TextStyle(fontSize: 14, height: 1.0);
const _para = ValueKey('para');
const _box = ValueKey('box');
const _after = ValueKey('after');

Widget _css(Widget c) => ShrinkWidth(key: _box, spill: true, child: c);
Widget _stock(Widget c) => OverflowBox(
  key: _box,
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

// Where the content stands and how big it is, and where the box after it is.
Future<List<Rect>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  return [t.getRect(find.byKey(_para)), t.getRect(find.byKey(_after))];
}

Future<bool> _same(WidgetTester t, Widget Function(Widget) around, Widget content, double width) async {
  final css = await _rects(t, _page(around(_css(content)), width));
  final stock = await _rects(t, _page(around(_stock(content)), width));
  return css[0] == stock[0] && css[1] == stock[1];
}

// What each box answers asked directly at [at]: its least and greatest
// height, and its dry layout under a ceiling and under a tight width.
Future<List<Object>> _answers(WidgetTester t, Widget box, double at) async {
  await t.pumpWidget(_page(box, 400));
  final r = t.renderObject<RenderBox>(find.byKey(_box));
  return [
    r.getMinIntrinsicHeight(at),
    r.getMaxIntrinsicHeight(at),
    r.getDryLayout(BoxConstraints(maxWidth: at)),
    if (at.isFinite) r.getDryLayout(BoxConstraints.tightFor(width: at)),
  ];
}

Future<bool> _answersSame(WidgetTester t, Widget content, double at) async {
  final css = await _answers(t, _css(content), at);
  final stock = await _answers(t, _stock(content), at);
  return [for (var i = 0; i < css.length; i++) css[i] == stock[i]].every((v) => v);
}

Widget _asked(Widget box) => IntrinsicHeight(
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [box]),
);

// A wrap answers its intrinsic height with a dry layout of its children
// under the width it is asked at (`RenderWrap.computeMaxIntrinsicHeight`).
Widget Function(Widget) _dry(double room) =>
    (Widget box) => IntrinsicHeight(
      child: Wrap(
        children: [
          SizedBox(
            width: room,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [box]),
          ),
        ],
      ),
    );

// A paragraph measures its widgets dry at the width it is asked at
// (`RenderParagraph._computeIntrinsicHeight`, `layoutInlineChildren`), and
// lays them out loose in its own.
Widget _inline(Widget box) => IntrinsicHeight(
  child: Text.rich(
    TextSpan(
      style: _style,
      children: [
        const TextSpan(text: 'x'),
        WidgetSpan(child: box),
      ],
    ),
  ),
);

void main() {
  // Each of one width, and that width.
  const word = Text('aaaaaaaa', key: _para, style: _style); // 112
  const padded = Padding(
    padding: EdgeInsets.all(10.5),
    child: Text('aaaaaaaa', key: _para, style: _style),
  ); // 133
  const held = IntrinsicWidth(
    child: Text('aaaa bbbb', key: _para, style: _style),
  ); // 126
  const contents = <(Widget, double)>[(word, 112), (padded, 133), (held, 126)];

  testWidgets('asked at its width or wider, the two answer alike', (t) async {
    for (final (c, w) in contents) {
      for (final at in [w, w + 0.5, 200.0, 1000.0, double.infinity]) {
        expect(await _answersSame(t, c, at), isTrue, reason: '$c at $at');
      }
      // NEGATIVE: under it.
      expect(await _answersSame(t, c, w - 14), isFalse, reason: '$c at ${w - 14}');
    }
  });

  testWidgets('measured from above at its width or wider, the two are one page', (t) async {
    for (final (c, w) in contents) {
      for (final width in [w, w + 0.5, 200.0, 1000.0]) {
        expect(await _same(t, _asked, c, width), isTrue, reason: 'asked: $c at $width');
        expect(await _same(t, _inline, c, width), isTrue, reason: 'inline: $c at $width');
        expect(await _same(t, _dry(width), c, 1000), isTrue, reason: 'dry: $c in $width');
      }
      // NEGATIVE: in a room under it.
      expect(await _same(t, _asked, c, w - 14), isFalse, reason: 'asked: $c at ${w - 14}');
      expect(await _same(t, _inline, c, w - 14), isFalse, reason: 'inline: $c at ${w - 14}');
      expect(await _same(t, _dry(w - 14), c, 1000), isFalse, reason: 'dry: $c in ${w - 14}');
    }
  });

  testWidgets('NEGATIVE: a stated width round words that wrap answers its height at the width it is asked', (t) async {
    // 60 wide, the words take two lines; asked at 200 the `SizedBox` asks
    // its paragraph at 200, one line.
    const stated = SizedBox(
      width: 60,
      child: Text('aaaa bbbb', key: _para, style: _style),
    );
    expect(await _same(t, (b) => b, stated, 200), isTrue);
    // A dry layout lays it out tight at 60 either way: a wrap above, which
    // asks no height of its items, is one page.
    expect(await _same(t, _dry(200), stated, 1000), isTrue);
    final css = await _answers(t, _css(stated), 200);
    final stock = await _answers(t, _stock(stated), 200);
    expect([css[2], css[3]], [stock[2], stock[3]]);
    // Asked its height at 200, the `OverflowBox` answers one line (14), the
    // `ShrinkWidth` the two it lays out at 60 (28): an `IntrinsicHeight`
    // above would cut the second line off.
    expect([css[0], css[1]], [28.0, 28.0]);
    expect([stock[0], stock[1]], [14.0, 14.0]);
  });

  testWidgets('content of one height at any width: the two answer alike under it too', (t) async {
    // A word in its line box: laid out, and asked, at no less than the word.
    const lined = LineBox(
      child: Text('aaaaaaaa', key: _para, style: _style),
    );
    // A row of pixels let out of a padded border: 20 + 40 + 10.
    const pill = DecoratedBox(
      decoration: BoxDecoration(border: Border.fromBorderSide(BorderSide(width: 1))),
      child: Padding(
        padding: EdgeInsets.all(5),
        child: OverflowBox(
          maxWidth: double.infinity,
          fit: OverflowBoxFit.deferToChild,
          alignment: Alignment.topLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 20, height: 20),
              SizedBox(key: _para, width: 40, height: 14),
            ],
          ),
        ),
      ),
    );
    // The word set pretty, and aligned in a box it may be taller than
    // (`RenderBalance` is a proxy; `AlignBox` asks its child at the width
    // it is asked at).
    const pretty = Pretty(child: lined);
    const aligned = AlignBox(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      heightFactor: 1,
      overflowHeight: true,
      child: lined,
    );
    // A line that never wraps, with a dot hung above its baseline: the
    // paragraph lays the dot out dry under the width it is asked at, and
    // its text at no bound.
    const dotted = IntrinsicWidth(
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'aaaaaaaa'),
            WidgetSpan(
              alignment: PlaceholderAlignment.aboveBaseline,
              baseline: TextBaseline.alphabetic,
              child: OverflowBox(
                minWidth: 0,
                maxWidth: double.infinity,
                fit: OverflowBoxFit.deferToChild,
                alignment: Alignment.topLeft,
                child: Padding(padding: EdgeInsets.only(left: 4), child: SizedBox(width: 6, height: 6)),
              ),
            ),
          ],
        ),
        key: _para,
        softWrap: false,
        style: _style,
      ),
    );
    // A row that flexes a box of a stated height beside a box that does
    // not flex: the one at its share, the other at its own width.
    const slot = IntrinsicWidth(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: SizedBox(width: 12, height: 24)),
          SizedBox(key: _para, width: 40, height: 14),
        ],
      ),
    );
    for (final c in const [lined, pill, pretty, aligned, dotted, slot]) {
      for (final at in const [30.0, 60.0, 112.0, 400.0, double.infinity]) {
        expect(await _answersSame(t, c, at), isTrue, reason: '$c at $at');
      }
      for (final width in const [30.0, 60.0, 200.0]) {
        expect(await _same(t, _asked, c, width), isTrue, reason: 'asked: $c at $width');
        expect(await _same(t, _inline, c, width), isTrue, reason: 'inline: $c at $width');
        expect(await _same(t, _dry(width), c, 1000), isTrue, reason: 'dry: $c in $width');
      }
    }
    // NEGATIVE: the bare word, and a word let out by the `OverflowBox`.
    const out = Padding(
      padding: EdgeInsets.all(5),
      child: OverflowBox(
        maxWidth: double.infinity,
        fit: OverflowBoxFit.deferToChild,
        alignment: Alignment.topLeft,
        child: Text('aaaaaaaa', key: _para, style: _style),
      ),
    );
    for (final c in const [word, out]) {
      expect(await _answersSame(t, c, 60), isFalse, reason: '$c');
      expect(await _same(t, _asked, c, 60), isFalse, reason: '$c');
    }
    // NEGATIVE: a widget on the line's BASELINE, a stated height round
    // words that wrap -- one height at any width, but its first line, and
    // so its baseline, is not: `aa ` of 10px and `bb` of 30px on one line
    // in 90 or more, `aa ` alone on the first under it.
    const onBaseline = IntrinsicWidth(
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'aa'),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: SizedBox(
                height: 40,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'aa ', style: TextStyle(fontSize: 10)),
                      TextSpan(text: 'bb', style: TextStyle(fontSize: 30)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        key: _para,
        softWrap: false,
        style: _style,
      ),
    );
    expect(await _answersSame(t, onBaseline, 400), isTrue);
    expect(await _answersSame(t, onBaseline, 60), isFalse);
    // At the bottom of the line the same widget is as tall at any width,
    // and the two answer alike under the content too.
    const atBottom = IntrinsicWidth(
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'aa'),
            WidgetSpan(
              child: SizedBox(
                height: 40,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'aa ', style: TextStyle(fontSize: 10)),
                      TextSpan(text: 'bb', style: TextStyle(fontSize: 30)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        key: _para,
        softWrap: false,
        style: _style,
      ),
    );
    for (final at in const [30.0, 60.0, 118.0, 400.0]) {
      expect(await _answersSame(t, atBottom, at), isTrue, reason: 'at $at');
    }
    // NEGATIVE: the row flexing words that wrap in their share.
    const flexed = IntrinsicWidth(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text('aaaa bbbb', key: _para, style: _style),
          ),
        ],
      ),
    );
    expect(await _answersSame(t, flexed, 400), isTrue);
    expect(await _answersSame(t, flexed, 60), isFalse);
  });
}
