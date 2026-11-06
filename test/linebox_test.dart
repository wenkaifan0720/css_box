import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';

// The test font draws every glyph 14px wide at 14px: `aaaaaaaa` is 112px,
// wider than the 70px boxes below.
const _style = TextStyle(fontSize: 14, height: 1.0);

Widget _box(Widget child, {TextDirection dir = TextDirection.rtl}) => Directionality(
  textDirection: dir,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 70,
      child: LineBox(key: const Key('l'), child: child),
    ),
  ),
);

void main() {
  double across(WidgetTester t, Type type) => t.getTopLeft(find.byType(type)).dx;

  testWidgets('rtl: a word wider than the box hangs out of its LEFT edge', (tester) async {
    // The paragraph is laid out 112 wide, the word's width, and its right
    // edge put on the box's: `bb` on the next line ends at the box's right
    // edge, and the word hangs 42 out on the left.
    await tester.pumpWidget(_box(const Text('aaaaaaaa bb', style: _style)));
    expect(tester.getSize(find.byKey(const Key('l'))).width, 70);
    expect(tester.getSize(find.byType(RichText)).width, 112);
    expect(across(tester, RichText), -42);
    // `right` and `justify` set their lines against the same edge.
    await tester.pumpWidget(_box(const Text('aaaaaaaa bb', style: _style, textAlign: TextAlign.right)));
    expect(across(tester, RichText), -42);
    await tester.pumpWidget(_box(const Text('aaaaaaaa bb', style: _style, textAlign: TextAlign.justify)));
    expect(across(tester, RichText), -42);
  });

  testWidgets('lines taller than the box overflow it, and are not cut to its height', (tester) async {
    // A 12px box round a 20px line (an inline-block `height: 12px` holding
    // an `x`): the box stays 12, the paragraph is its own 20 and draws
    // them all -- handed 12 it would clip the glyph at the box's bottom.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 30,
            height: 12,
            child: LineBox(
              key: const Key('l'),
              child: const Text('x', style: TextStyle(fontSize: 14, height: 20 / 14)),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('l'))), const Size(30, 12));
    expect(tester.getSize(find.byType(RichText)).height, 20);
    // A box taller than the line stays its own height, the line at its top.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 30,
            height: 40,
            child: LineBox(
              key: const Key('l'),
              child: const Text('x', style: _style),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('l'))), const Size(30, 40));
    expect(tester.getTopLeft(find.byType(RichText)).dy, 0);
  });

  testWidgets('a run of Han breaks between its ideographs, where Skia measures it as one word', (tester) async {
    // Nine ideographs, 126px, in the 70px box: `刊登廣告，` (70) ends the
    // first line -- a comma never starts one -- and `關於我們` is the next.
    await tester.pumpWidget(_box(const Text('刊登廣告，關於我們', style: _style), dir: TextDirection.ltr));
    expect(tester.getSize(find.byType(RichText)), const Size(70, 28));
    // An opening bracket stays with what follows it: `「廣告` is one piece.
    await tester.pumpWidget(_box(const Text('刊登「廣告」', style: _style), dir: TextDirection.ltr));
    expect(tester.getSize(find.byType(RichText)).width, 70);
  });

  testWidgets('what fits, what is set against the other edge, and ltr stay put', (tester) async {
    await tester.pumpWidget(_box(const Text('aaaa bb', style: _style)));
    expect(across(tester, RichText), 0);
    await tester.pumpWidget(_box(const Text('aaaaaaaa bb', style: _style, textAlign: TextAlign.left)));
    expect(across(tester, RichText), 0);
    await tester.pumpWidget(_box(const Text('aaaaaaaa bb', style: _style), dir: TextDirection.ltr));
    expect(across(tester, RichText), 0);
  });

  testWidgets('rtl: a hung first word wider than its room hangs out of the left too', (tester) async {
    // Hung 14 out, the first line's room is the paragraph's width and 14:
    // the least width is 112 - 14 = 98, the paragraph is laid out 98 wide
    // and put 28 out on the left, and its first line ends 14 past the
    // box's right edge.
    await tester.pumpWidget(_box(IndentedText('aaaaaaaa bb', indent: -14, style: _style)));
    expect(tester.getSize(find.byType(IndentedText)).width, 98);
    expect(across(tester, IndentedText), -28);
  });

  testWidgets('a line box stood on its baseline in another line stands on the baseline it draws', (tester) async {
    // A 17.25px box on a 20px line whose strut keeps 13.5 above the
    // baseline: the line is 17.25 over 6.5, 23.75 in CSS, which Skia draws
    // 24 tall on a baseline 17.5 down; the box puts it back at 17.25. Stood
    // in a line of its own by that baseline, the outer line is the same
    // 23.75 and the two baselines are one -- the inner box once answered
    // the baseline its paragraph ASKED for, and was stood a quarter pixel
    // off it.
    const strut = StrutStyle(
      fontSize: 14,
      height: 20 / 14,
      leading: 0,
      leadingDistribution: TextLeadingDistribution.even,
    );
    const run = TextStyle(fontSize: 14, height: 20 / 14, leadingDistribution: TextLeadingDistribution.even);
    Widget mark(String key) => SizedBox(key: Key(key), width: 0, height: 0);
    final inner = LineBox(
      key: const Key('inner'),
      keepWords: false,
      lineHeight: 20,
      ascent: 13.5,
      child: Text.rich(
        TextSpan(
          style: run,
          children: [
            const TextSpan(text: 'ab'),
            WidgetSpan(
              child: mark('in'),
              alignment: PlaceholderAlignment.aboveBaseline,
              baseline: TextBaseline.alphabetic,
            ),
            const WidgetSpan(
              child: SizedBox(width: 4, height: 17.25),
              alignment: PlaceholderAlignment.aboveBaseline,
              baseline: TextBaseline.alphabetic,
            ),
          ],
        ),
        softWrap: false,
        strutStyle: strut,
      ),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            child: LineBox(
              key: const Key('outer'),
              lineHeight: 20,
              ascent: 13.5,
              child: Text.rich(
                TextSpan(
                  style: run,
                  children: [
                    const TextSpan(text: 'x'),
                    WidgetSpan(
                      child: mark('out'),
                      alignment: PlaceholderAlignment.aboveBaseline,
                      baseline: TextBaseline.alphabetic,
                    ),
                    WidgetSpan(
                      child: inner,
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                    ),
                  ],
                ),
                strutStyle: strut,
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('inner'))).height, moreOrLessEquals(23.75, epsilon: 0.01));
    expect(tester.getSize(find.byKey(const Key('outer'))).height, moreOrLessEquals(23.75, epsilon: 0.01));
    expect(
      tester.getBottomLeft(find.byKey(const Key('in'))).dy,
      moreOrLessEquals(tester.getBottomLeft(find.byKey(const Key('out'))).dy, epsilon: 0.01),
    );
  });

  testWidgets('a box on a line under the first stands on that line\'s baseline, as Skia rounded it', (tester) async {
    // A strut of 15 over 5 and, on the SECOND line, a box standing 10.5
    // over its baseline and 8.625 under it: that line is 15 + 8.625 =
    // 23.625, which Skia draws 24 tall with the 0.375 on its ascent, and
    // the box's depth read off the first line's strut came to 9.
    const run = TextStyle(fontSize: 14, height: 1);
    Future<double> high(double width) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: LineBox(
                key: const Key('l'),
                lineHeight: 20,
                ascent: 15,
                child: Text.rich(
                  const TextSpan(
                    style: run,
                    children: [
                      TextSpan(text: 'aaaa '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 5.125),
                          child: Text('b', style: run),
                        ),
                      ),
                    ],
                  ),
                  strutStyle: const StrutStyle(fontSize: 20, height: 1, leading: 0),
                ),
              ),
            ),
          ),
        ),
      );
      return tester.getSize(find.byKey(const Key('l'))).height;
    }

    expect(await high(70), moreOrLessEquals(20 + 23.625, epsilon: 0.01));
    // On the first line it was read right before.
    expect(await high(200), moreOrLessEquals(23.625, epsilon: 0.01));
  });

  testWidgets('a box that raises a line under the first still stands on that line', (tester) async {
    // An empty box 20 tall has its bottom for a baseline: on the second
    // line of a 15-over-5 strut it is that line's ascent, and the line is
    // 20 + 5.
    const run = TextStyle(fontSize: 14, height: 1);
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 70,
            child: LineBox(
              key: Key('l'),
              lineHeight: 20,
              ascent: 15,
              child: Text.rich(
                TextSpan(
                  style: run,
                  children: [
                    TextSpan(text: 'aaaa '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: SizedBox(width: 56, height: 20),
                    ),
                  ],
                ),
                strutStyle: StrutStyle(fontSize: 20, height: 1, leading: 0),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('l'))).height, moreOrLessEquals(20 + 25, epsilon: 0.01));
  });

  testWidgets(
    'asked its height at a width, it counts the lines it lays out there: an inline wider than the line hangs out',
    (tester) async {
      // A bookshop's carousel: a book cover `max-width: 100%` of its
      // 300px picture, its title under it, alone on a line in a 100px card.
      // Its least width, 300, is the box's min-content and no floor for the
      // line (CSS 2.1 9.4.2): laid out at 100, the cover is 100 wide. Asked
      // at 100, the lines were counted at 300 -- 468 for the 164 laid out --
      // and the `IntrinsicHeight` round the row of cards stood 275 deeper.
      final cover = WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: FractionalWidth(
          factor: 1,
          fill: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(aspectRatio: 300 / 455, child: const SizedBox(width: 300, height: 455)),
              const Text('A title', style: _style),
            ],
          ),
        ),
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 100,
              child: LineBox(
                key: const Key('l'),
                lineHeight: 14.9375,
                ascent: 12,
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: '\u200b'),
                      cover,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final line = tester.renderObject<RenderBox>(find.byKey(const Key('l')));
      // To the part of a pixel Skia rounds the line it lays out by, where the
      // question before layout is answered as CSS sizes the line
      // (`_boxesOnly`): 165.67 for 166.
      expect(line.size.height, lessThan(200));
      expect(line.getMaxIntrinsicHeight(100), moreOrLessEquals(line.size.height, epsilon: 0.5));
      expect(line.getMinIntrinsicHeight(100), moreOrLessEquals(line.size.height, epsilon: 0.5));
      // NEGATIVE: its least width is still what it asks of a box round it.
      expect(line.getMinIntrinsicWidth(double.infinity), greaterThanOrEqualTo(300));
    },
  );

  testWidgets("every line is on Blink's 1/64 grid: a line height of 35.2 lays its lines out 35.203125 apart", (
    tester,
  ) async {
    // A banking site's pricing heading: `line-height: 110%` of a size that follows
    // the window, 32px on a phone, so the line height is worked out at
    // layout and comes to 35.2 -- a length, which Blink rounds onto its
    // grid (`LayoutUnit::FromFloatRound`). Two lines are 70.40625 in
    // Chrome; held at 35.2 they were 70.4, and every box under the heading
    // stood 0.00625px high (`fixtures/text-fluid-line-grid`).
    const strut = StrutStyle(
      fontSize: 32,
      height: 1.1,
      leading: 0,
      leadingDistribution: TextLeadingDistribution.even,
      forceStrutHeight: true,
    );
    Widget page(double lineHeight) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 200,
          child: LineBox(
            key: const Key('l'),
            lineHeight: lineHeight,
            ascent: 28,
            child: const Text('aa\nbb', style: TextStyle(fontSize: 32, height: 1.1), strutStyle: strut),
          ),
        ),
      ),
    );
    await tester.pumpWidget(page(32 * 1.1));
    expect(tester.getSize(find.byKey(const Key('l'))).height, 70.40625);
    // NEGATIVE: a line height on the grid already -- every number of pixels
    // the lowering writes -- is the height it says.
    await tester.pumpWidget(page(35.1875));
    expect(tester.getSize(find.byKey(const Key('l'))).height, 70.375);
  });

  testWidgets('a baseline within half a 64th of its ascent is on it: the paragraph is not moved by float noise', (
    tester,
  ) async {
    // A news site's health headline: 24px Post Grotesk on a 27.6px line, its
    // strut written at `fontSize: 22.291` so that Skia's baseline is
    // Blink's 21 -- and Skia answered 21.00012. Put back by the 0.00012,
    // the paragraph at 1440 (its line at y = 1080.5) composed a hair short
    // of the half pixel and was drawn a pixel higher than Chrome draws it
    // and than the same paragraph in a `SizedBox` of the line height.
    // Here the test font's 0.75em ascent makes the strut's baseline
    // 0.25 * size + 13.8: 21.0001 at 28.8004.
    StrutStyle strut(double size) => StrutStyle(
      fontSize: size,
      height: 27.6 / size,
      leading: 0,
      leadingDistribution: TextLeadingDistribution.even,
      forceStrutHeight: true,
    );
    double skia(double size) {
      final p = TextPainter(
        text: const TextSpan(text: 'Hxy', style: TextStyle(fontSize: 24, height: 1.15)),
        strutStyle: strut(size),
        textDirection: TextDirection.ltr,
      )..layout();
      final b = p.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      p.dispose();
      return b;
    }

    Widget page(double size, {required bool held}) {
      final text = Text('Hxy', style: const TextStyle(fontSize: 24, height: 1.15), strutStyle: strut(size));
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 10.5),
            child: SizedBox(
              width: 200,
              child: held
                  ? LineBox(key: const Key('l'), lineHeight: 27.59375, ascent: 21, child: text)
                  : SizedBox(height: 27.59375, child: text),
            ),
          ),
        ),
      );
    }

    final noise = skia(28.8004) - 21;
    expect(noise, inExclusiveRange(0, 1 / 128));
    await tester.pumpWidget(page(28.8004, held: false));
    final unmoved = tester.getTopLeft(find.byType(RichText));
    await tester.pumpWidget(page(28.8004, held: true));
    // Painted where Skia put it; the drop it answers is still the exact one.
    expect(tester.getTopLeft(find.byType(RichText)), unmoved);
    expect(
      tester.renderObject<RenderLineBox>(find.byKey(const Key('l'))).drop,
      moreOrLessEquals(-noise, epsilon: 1e-9),
    );
    // NEGATIVE: a baseline a 64th or more off is put back however little:
    // at 27.6 the strut's baseline is 20.7, and the paragraph goes down 0.3.
    await tester.pumpWidget(page(27.6, held: false));
    final short = tester.getTopLeft(find.byType(RichText));
    await tester.pumpWidget(page(27.6, held: true));
    final drop = tester.renderObject<RenderLineBox>(find.byKey(const Key('l'))).drop;
    expect(drop, moreOrLessEquals(21 - skia(27.6), epsilon: 1e-9));
    expect(drop, moreOrLessEquals(0.3, epsilon: 1e-3));
    expect(tester.getTopLeft(find.byType(RichText)), short + Offset(0, drop));
  });

  testWidgets('a move too small to paint is still answered: a row on its baselines stays its line tall', (
    tester,
  ) async {
    // A SaaS landing page's pricing cards: each feature row stands a strut -- a zero
    // width space in a `SizedBox` of the line, on a `Baseline` at the
    // ascent -- beside the feature's `LastBaseline(LineBox)`, the two on
    // their baselines (`CrossAxisAlignment.baseline`), in a card column an
    // `IntrinsicHeight` holds to the heights it asks of the rows: their
    // lines. A box that ANSWERED Skia's baseline where the move was too
    // small to paint stood the row a hair taller than its line -- the
    // highest ascent over the deepest descent of the two (CSS 2.1 10.8) --
    // and the column overflowed by it: "A RenderFlex overflowed by
    // 0.00000191 pixels on the bottom" at every width from 768 up. The
    // strut here is the news site's above: Skia's 21.0001 for Blink's 21.
    const style = TextStyle(fontSize: 24, height: 1.15);
    const strut = StrutStyle(
      fontSize: 28.8004,
      height: 27.6 / 28.8004,
      leading: 0,
      leadingDistribution: TextLeadingDistribution.even,
      forceStrutHeight: true,
    );
    Widget row(Key key, Widget label) => Row(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        const SizedBox(
          height: 27.59375,
          child: Baseline(
            baseline: 21,
            baselineType: TextBaseline.alphabetic,
            child: Text('\u200B', style: style),
          ),
        ),
        Flexible(child: label),
      ],
    );
    Widget line() => const LineBox(
      lineHeight: 27.59375,
      ascent: 21,
      child: Text('Hxy', style: style, strutStyle: strut),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // As the SaaS landing page writes it, and the box's own first baseline.
                  row(const Key('last'), LastBaseline(child: line())),
                  row(const Key('first'), line()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(const Key('last'))).height, 27.59375);
    expect(tester.getSize(find.byKey(const Key('first'))).height, 27.59375);
    expect(tester.getSize(find.byType(Column)).height, 2 * 27.59375);
  });

  testWidgets('a line of nothing but a box is as tall laid out as it answered before layout, to the last bit', (
    tester,
  ) async {
    // A button's label is an inline-block alone on its line: a zero-width
    // space and one box on its baseline. Asked before layout the line is
    // worked out as CSS sizes it ([RenderLineBox] `_boxesOnly`), in doubles;
    // laid out it is read off the boxes Skia placed, in floats -- the same
    // line a millionth of a pixel apart. A column measures its items before
    // it lays them out, so a stock `Column` of five such buttons was handed
    // 0.0000048 less than it came to, and its debug overflow hatch covered
    // the bottom tenth of the page.
    final drift = <String>[];
    for (final at in const [
      27.00025310546875,
      17.000148749999997,
      19.999997520751954,
      41.00029182434082,
      30.3330078125,
    ]) {
      for (final size in const [20.00006866455078, 22.66713, 17.00029182434082, 31.999]) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                child: LineBox(
                  key: const Key('l'),
                  lineHeight: size,
                  ascent: 0.75 * size,
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: size, height: 1),
                      children: [
                        const TextSpan(text: '​'),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: TopBaseline(at: at, child: const SizedBox(width: 120, height: 44.00035095214844)),
                        ),
                      ],
                    ),
                    strutStyle: StrutStyle(fontSize: size, height: 1, leading: 0),
                  ),
                ),
              ),
            ),
          ),
        );
        final line = tester.renderObject<RenderBox>(find.byKey(const Key('l')));
        final asked = line.getDryLayout(line.constraints).height;
        if (asked != line.size.height) drift.add('at $at, line $size: asked $asked, laid out ${line.size.height}');
      }
    }
    expect(drift, isEmpty);
  });

  testWidgets('NEGATIVE: a line of nothing but a box Skia drew a part of a pixel off keeps the height it drew', (
    tester,
  ) async {
    // Only float noise is taken back. A cover `max-width: 100%` alone on
    // its line in a 100px card: CSS makes the line 165.67 and Skia draws
    // it 166 -- a third of a pixel, the rounding the line is drawn at, not
    // a float's last bits -- and laid out the line keeps Skia's.
    final cover = WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: FractionalWidth(
        factor: 1,
        fill: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(aspectRatio: 300 / 455, child: const SizedBox(width: 300, height: 455)),
            const Text('A title', style: _style),
          ],
        ),
      ),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 100,
            child: LineBox(
              key: const Key('l'),
              lineHeight: 14.9375,
              ascent: 12,
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: '​'),
                    cover,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final line = tester.renderObject<RenderBox>(find.byKey(const Key('l')));
    final asked = line.getDryLayout(line.constraints).height;
    expect((line.size.height - asked).abs(), greaterThan(0.1), reason: 'asked $asked, laid out ${line.size.height}');
    expect(line.size.height, line.size.height.roundToDouble());
  });
}
