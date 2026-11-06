// InlineFlow against a reference inline formatting context: every
// number expected below is what the engine computes for the same content under its Ahem measurer --
// every glyph one em wide, ascent and descent 0.8 and 0.2 em rounded to
// whole pixels, the x-height 0.8 em -- which is the test font's advance and
// the fonts written here. The engine lays these paragraphs out where the
// lowering could not, and it is the oracle while it does.
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

InlineFont font(double size, double lineHeight) => InlineFont(
  size: size,
  ascent: (size * 0.8).roundToDouble(),
  descent: (size * 0.2).roundToDouble(),
  lineHeight: lineHeight,
  xHeight: size * 0.8,
);

TextStyle px(double size) => TextStyle(fontSize: size);

Future<RenderInlineFlow> lay(
  WidgetTester tester,
  double width,
  InlineFlow flow, {
  TextDirection direction = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: direction,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: flow),
      ),
    ),
  );
  return tester.renderObject<RenderInlineFlow>(find.byType(InlineFlow));
}

void rects(List<Rect> got, List<List<double>> want) {
  expect(got.length, want.length, reason: '$got');
  for (var i = 0; i < want.length; i++) {
    final w = want[i];
    expect(
      [got[i].left, got[i].top, got[i].width, got[i].height],
      [for (final v in w) moreOrLessEquals(v, epsilon: 1e-6)],
      reason: 'fragment $i of $got',
    );
  }
}

void pieces(RenderInlineFlow r, List<(String, double, double, double)> want) {
  final got = r.pieces;
  expect([for (final p in got) p.text], [for (final w in want) w.$1]);
  for (var i = 0; i < want.length; i++) {
    expect(
      [got[i].x, got[i].baseline, got[i].width],
      [
        moreOrLessEquals(want[i].$2, epsilon: 1e-6),
        moreOrLessEquals(want[i].$3, epsilon: 1e-6),
        moreOrLessEquals(want[i].$4, epsilon: 1e-6),
      ],
      reason: 'piece ${want[i].$1}',
    );
  }
}

void main() {
  final body = font(16, 20);

  testWidgets('opacity: a faded box is one picture at its alpha (css-color-4 2.2), at 0 none', (tester) async {
    // Two glyphs of the faded box overlap by 8px (letter-spacing -8 on
    // 16px glyphs): the group paints each shared pixel once, so it is the
    // gray of a pixel only one glyph covers, not two halves laid over each
    // other; the box at 0 paints nothing.
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: const Color(0xFFFFFFFF),
              child: SizedBox(
                width: 200,
                child: InlineFlow(
                  font: body,
                  style: const TextStyle(fontSize: 16, color: Color(0xFF000000)),
                  children: const [
                    InlineText('a '),
                    InlineBox(opacity: 0.5, style: TextStyle(letterSpacing: -8), children: [InlineText('bb')]),
                    InlineText(' c '),
                    InlineBox(opacity: 0, children: [InlineText('d')]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect([for (final l in tester.layers.whereType<OpacityLayer>()) l.alpha], [128]);
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final data = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData();
      final w = image.width;
      image.dispose();
      return (bytes!, w);
    });
    int red(int x, int y) => data!.$1.getUint8((y * data.$2 + x) * 4);
    expect(red(4, 10), 0, reason: 'a, unfaded');
    // `bb` stands at 32: the first glyph 32..48, the second 40..56.
    final one = red(36, 10), both = red(44, 10);
    expect(one, inInclusiveRange(126, 129), reason: 'one glyph at .5');
    expect(both, one, reason: 'the shared pixels painted once');
    // The box ends at 48: ' c ' is 48..96, `d` 96..112.
    expect(red(70, 10), 0, reason: 'c');
    expect(red(104, 10), 255, reason: 'd at 0 is not painted');
  });

  testWidgets('ellipsis: a line too wide ends on one, as Chrome cuts it (css-overflow-3 3.2)', (tester) async {
    // Oracle: Chrome 151 in Ahem (every glyph, the ellipsis too, one em),
    // each truncated line matched pixel for pixel against lines built by
    // hand, and the boxes' rects read from the page
    // (scratch/inlineflow/probe_ell/ahem.py, rects.py).
    InlineFlow flow(List<InlineNode> kids) =>
        InlineFlow(font: body, style: px(16), whiteSpace: WhiteSpace.nowrap, ellipsis: true, children: kids);

    // The room is 100 less the ellipsis's 16: `ab cd` fits, the space in it
    // counted like any other character.
    var r = await lay(tester, 100, flow(const [InlineText('ab cd ef gh')]));
    final base = r.lineBaselines.single;
    pieces(r, [('ab cd', 0, base, 80), ('\u2026', 80, base, 16)]);

    // A padded box cut short: the ellipsis right after its kept text, not
    // after its end padding; the box keeps its whole fragment (8 + 128 + 8).
    const padded = InlineBox(padding: EdgeInsets.symmetric(horizontal: 8), children: [InlineText('cd ef gh')]);
    r = await lay(tester, 120, flow(const [InlineText('ab '), padded]));
    pieces(r, [('ab ', 0, base, 48), ('cd ', 56, base, 48), ('\u2026', 104, base, 16)]);
    expect(r.fragmentsOf(padded).single.left, 48);
    expect(r.fragmentsOf(padded).single.width, 144);

    // An atomic inline across the room is hidden whole -- still laid out
    // where it stood -- and what comes after it too.
    r = await lay(
      tester,
      90,
      flow(const [InlineText('ab '), InlineAtom(child: SizedBox(width: 40, height: 10)), InlineText(' cd')]),
    );
    pieces(r, [('ab ', 0, base, 48), ('\u2026', 48, base, 16)]);
    final atom = tester.renderObject<RenderBox>(find.byType(SizedBox).last);
    final data = atom.parentData! as InlineFlowParentData;
    expect(data.shown, isFalse);
    expect(data.offset.dx, 48);

    // The first character on the line stays, however narrow the flow.
    r = await lay(tester, 10, flow(const [InlineText('abcdef')]));
    pieces(r, [('a', 0, base, 16), ('\u2026', 16, base, 16)]);

    // A raised box cut short: the ellipsis is the line's, on its baseline.
    r = await lay(
      tester,
      120,
      flow(const [
        InlineText('ab '),
        InlineBox(verticalAlign: VerticalAlign.superscript, children: [InlineText('cd ef gh')]),
      ]),
    );
    final got = r.pieces;
    expect([for (final p in got) p.text], ['ab ', 'cd ', '\u2026']);
    expect(got[1].baseline, lessThan(got[0].baseline));
    expect([got[2].x, got[2].baseline, got[2].width], [96, got[0].baseline, 16]);

    // The flow's own underline is not the ellipsis's (Chrome 151, Inter:
    // `probe_ell/deco.py`).
    r = await lay(
      tester,
      100,
      InlineFlow(
        font: body,
        style: px(16).copyWith(decoration: TextDecoration.underline),
        whiteSpace: WhiteSpace.nowrap,
        ellipsis: true,
        children: const [InlineText('ab cd ef gh')],
      ),
    );
    expect(r.pieces.first.style.decoration, TextDecoration.underline);
    expect(r.pieces.last.text, '\u2026');
    expect(r.pieces.last.style.decoration, TextDecoration.none);

    // A line that fits is left alone.
    r = await lay(tester, 200, flow(const [InlineText('ab cd ef gh')]));
    pieces(r, [('ab cd ef gh', 0, base, 176)]);

    // TRACKED TEXT (probe_ell/tracked.py): the ellipsis asks for its own
    // advance, not the spacing after it, and stands after the spacing of
    // the last letter kept -- `abcde…` in 101px tracked 1px (5 x 17 + 16),
    // `abcd…` in 88px tracked 2px (4 x 18 + 16).
    InlineFlow tracked(double spacing, List<InlineNode> kids) => InlineFlow(
      font: body,
      style: px(16).copyWith(letterSpacing: spacing),
      whiteSpace: WhiteSpace.nowrap,
      ellipsis: true,
      children: kids,
    );
    r = await lay(tester, 101, tracked(1, const [InlineText('abcdefghij')]));
    expect([for (final p in r.pieces) (p.text, p.x)], [('abcde', 0), ('\u2026', 85)]);
    r = await lay(tester, 88, tracked(2, const [InlineText('abcdefghij')]));
    expect([for (final p in r.pieces) (p.text, p.x)], [('abcd', 0), ('\u2026', 72)]);
    // A padded box cut short in tracked text: `cd ` kept, 59 + 51.
    r = await lay(
      tester,
      140,
      tracked(1, const [
        InlineText('ab '),
        InlineBox(padding: EdgeInsets.symmetric(horizontal: 8), children: [InlineText('cd ef gh ij')]),
      ]),
    );
    expect([for (final p in r.pieces) (p.text, p.x)], [('ab ', 0), ('cd ', 59), ('\u2026', 110)]);
    // A box tracked apart from its block: each character kept brings its
    // own box's spacing, the ellipsis its advance alone
    // (probe_ell/tracked_mixed.py: 24 of 24 boundaries).
    r = await lay(
      tester,
      100,
      flow(const [
        InlineText('ab '),
        InlineBox(style: TextStyle(letterSpacing: 2), children: [InlineText('cdefghij')]),
      ]),
    );
    expect([for (final p in r.pieces) (p.text, p.x)], [('ab ', 0), ('cd', 48), ('\u2026', 84)]);
    r = await lay(
      tester,
      131,
      tracked(1, const [
        InlineText('ab '),
        InlineBox(style: TextStyle(letterSpacing: 0), children: [InlineText('cdefghij')]),
      ]),
    );
    expect([for (final p in r.pieces) (p.text, p.x)], [('ab ', 0), ('cdef', 51), ('\u2026', 115)]);

    // The flow's text shadow is the ellipsis's too.
    const shadow = [Shadow(offset: Offset(2, 2), color: Color(0xffff0000))];
    r = await lay(
      tester,
      100,
      InlineFlow(
        font: body,
        style: px(16).copyWith(shadows: shadow),
        whiteSpace: WhiteSpace.nowrap,
        ellipsis: true,
        children: const [InlineText('ab cd ef gh')],
      ),
    );
    expect([for (final p in r.pieces) p.text], ['ab cd', '\u2026']);
    expect(r.pieces.last.style.shadows, shadow);
  });

  testWidgets('textWrap: balanced and pretty lines as Chrome breaks them (css-text-4 6.2)', (tester) async {
    // Oracle: Chrome 151 in Ahem at 16px/20px, each line's text read off
    // the glyphs' rects (scratch/inlineflow/probe_bal/bal.py): greedy,
    // balance and pretty for each paragraph. The last two come out of 600
    // random paragraphs (probe_bal/sweep.py, in Ahem and in Inter) all of
    // which the flow breaks as Chrome does: 'edges', where a line does
    // not count the box edges after its last word, and 'bisect', where
    // balance falls back to the narrowest width that keeps three lines --
    // the score's best, `g da cff` / `ffc dc`, is two.
    InlineBox pad(double h, String t) => InlineBox(
      padding: EdgeInsets.symmetric(horizontal: h),
      children: [InlineText(t)],
    );
    InlineBox ruled(String t) => InlineBox(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(border: Border.all(width: 3)),
      children: [InlineText(t)],
    );
    final atom = GlobalKey();
    final cases = <String, (double, double, List<InlineNode>, List<List<String>>)>{
      'plain': (
        200,
        0,
        [const InlineText('aaa bb cc dd e ff')],
        [
          ['aaa bb cc dd', 'e ff'],
          ['aaa bb cc', 'dd e ff'],
          ['aaa bb cc dd', 'e ff'],
        ],
      ),
      'three': (
        150,
        0,
        [const InlineText('aa bbb cc dd eee ff gg hh ii')],
        [
          ['aa bbb cc', 'dd eee ff', 'gg hh ii'],
          ['aa bbb cc', 'dd eee ff', 'gg hh ii'],
          ['aa bbb cc', 'dd eee ff', 'gg hh ii'],
        ],
      ),
      'padded': (
        150,
        0,
        [const InlineText('ab '), pad(8, 'cd ef gh ij'), const InlineText(' kl')],
        [
          ['ab cd ef', 'gh ij kl'],
          ['ab cd ef', 'gh ij kl'],
          ['ab cd ef', 'gh ij kl'],
        ],
      ),
      'border': (
        170,
        0,
        [
          const InlineText('Balance '),
          InlineBox(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(border: Border.all(width: 3)),
            children: const [InlineText('heading wrap choices')],
          ),
          const InlineText(' evenly.'),
        ],
        [
          for (var i = 0; i < 3; i++) ['Balance', 'heading', 'wrap', 'choices', 'evenly.'],
        ],
      ),
      'margin': (
        180,
        0,
        [
          const InlineText('aa '),
          const InlineBox(margin: EdgeInsets.symmetric(horizontal: 12), children: [InlineText('bb cc dd')]),
          const InlineText(' ee ff gg'),
        ],
        [
          ['aa bb cc', 'dd ee ff', 'gg'],
          ['aa bb cc', 'dd ee', 'ff gg'],
          ['aa bb cc', 'dd ee', 'ff gg'],
        ],
      ),
      'indent': (
        180,
        32,
        [const InlineText('aa bb cc dd ee ff gg')],
        [
          for (var i = 0; i < 3; i++) ['aa bb cc', 'dd ee ff gg'],
        ],
      ),
      'atomic': (
        180,
        0,
        [
          const InlineText('aa bb '),
          InlineAtom(child: SizedBox(key: atom, width: 40, height: 10)),
          const InlineText(' cc dd ee'),
        ],
        [
          for (var i = 0; i < 3; i++) ['aa bb', 'cc dd ee'],
        ],
      ),
      'hyphen': (
        180,
        0,
        [const InlineText('aa bb-cc dd ee ff')],
        [
          ['aa bb-cc dd', 'ee ff'],
          ['aa bb-cc', 'dd ee ff'],
          ['aa bb-cc dd', 'ee ff'],
        ],
      ),
      'lastword': (
        200,
        0,
        [const InlineText('aaa bb cc dd eee ff gg h')],
        [
          for (var i = 0; i < 3; i++) ['aaa bb cc dd', 'eee ff gg h'],
        ],
      ),
      'pad4': (
        170,
        0,
        [
          const InlineText('aa '),
          pad(4, 'bb cc'),
          const InlineText(' dd '),
          pad(4, 'ee'),
          const InlineText(' ff gg hh'),
        ],
        [
          ['aa bb cc', 'dd ee ff', 'gg hh'],
          ['aa bb', 'cc dd ee', 'ff gg hh'],
          ['aa bb cc', 'dd ee ff', 'gg hh'],
        ],
      ),
      'pretty1': (
        200,
        0,
        [const InlineText('aa bb cc dd ee ff gg hh ii')],
        [
          ['aa bb cc dd', 'ee ff gg hh', 'ii'],
          ['aa bb cc', 'dd ee ff', 'gg hh ii'],
          ['aa bb cc dd', 'ee ff gg', 'hh ii'],
        ],
      ),
      'prettypad': (
        200,
        0,
        [const InlineText('aa bb '), pad(6, 'cc dd ee'), const InlineText(' ff gg hh ii')],
        [
          ['aa bb cc dd', 'ee ff gg hh', 'ii'],
          ['aa bb cc', 'dd ee ff', 'gg hh ii'],
          ['aa bb cc dd', 'ee ff gg', 'hh ii'],
        ],
      ),
      'prettyind': (
        200,
        24,
        [const InlineText('aa bb cc dd ee ff gg hh ii jj kk')],
        [
          ['aa bb cc dd', 'ee ff gg hh', 'ii jj kk'],
          ['aa bb cc', 'dd ee ff gg', 'hh ii jj kk'],
          ['aa bb cc dd', 'ee ff gg hh', 'ii jj kk'],
        ],
      ),
      'balind': (
        200,
        48,
        [const InlineText('aaa bb cc dd e ff')],
        [
          ['aaa bb cc', 'dd e ff'],
          ['aaa bb', 'cc dd e ff'],
          ['aaa bb cc', 'dd e ff'],
        ],
      ),
      'edges': (
        198,
        16,
        [ruled('gb ccfe cb'), const InlineText(' eca fagbcd hcd '), ruled('gf cd aaf'), const InlineText(' ged')],
        [
          ['gb ccfe', 'cb eca', 'fagbcd hcd', 'gf cd aaf', 'ged'],
          ['gb ccfe', 'cb eca', 'fagbcd', 'hcd gf cd', 'aaf ged'],
          ['gb ccfe', 'cb eca', 'fagbcd', 'hcd gf cd', 'aaf ged'],
        ],
      ),
      'bisect': (
        163,
        16,
        [const InlineText('g da '), pad(10, 'cff'), const InlineText(' ffc dc')],
        [
          ['g da', 'cff ffc', 'dc'],
          ['g da', 'cff', 'ffc dc'],
          ['g da', 'cff ffc', 'dc'],
        ],
      ),
      // A forced break ends a paragraph: balance the first alone, pretty
      // each on its own (bal.py 'brbal', 'brpretty', 'brind').
      'brbal': (
        200,
        0,
        [const InlineText('aaa bb cc dd e ff'), const InlineBreak(), const InlineText('aaa bb cc dd e ff')],
        [
          ['aaa bb cc dd', 'e ff', 'aaa bb cc dd', 'e ff'],
          ['aaa bb cc', 'dd e ff', 'aaa bb cc dd', 'e ff'],
          ['aaa bb cc dd', 'e ff', 'aaa bb cc dd', 'e ff'],
        ],
      ),
      'brpretty': (
        200,
        0,
        [
          const InlineText('aa bb cc dd ee ff gg hh ii'),
          const InlineBreak(),
          const InlineText('aa bb cc dd ee ff gg hh ii'),
        ],
        [
          ['aa bb cc dd', 'ee ff gg hh', 'ii', 'aa bb cc dd', 'ee ff gg hh', 'ii'],
          ['aa bb cc', 'dd ee ff', 'gg hh ii', 'aa bb cc dd', 'ee ff gg hh', 'ii'],
          ['aa bb cc dd', 'ee ff gg', 'hh ii', 'aa bb cc dd', 'ee ff gg', 'hh ii'],
        ],
      ),
      'brind': (
        200,
        32,
        [const InlineText('aa bb cc dd ee ff gg'), const InlineBreak(), const InlineText('aa bb cc dd ee ff gg hh ii')],
        [
          ['aa bb cc', 'dd ee ff gg', 'aa bb cc dd', 'ee ff gg hh', 'ii'],
          ['aa bb cc', 'dd ee ff gg', 'aa bb cc dd', 'ee ff gg hh', 'ii'],
          ['aa bb cc', 'dd ee ff gg', 'aa bb cc dd', 'ee ff gg', 'hh ii'],
        ],
      ),
    };
    for (final MapEntry(key: name, value: (width, indent, children, want)) in cases.entries) {
      for (final (i, wrap) in TextWrapStyle.values.indexed) {
        final r = await lay(
          tester,
          width,
          InlineFlow(font: body, style: px(16), textIndent: indent, textWrap: wrap, children: children),
        );
        final byLine = <double, String>{};
        for (final p in r.pieces) {
          byLine[p.baseline] = (byLine[p.baseline] ?? '') + p.text;
        }
        final keys = byLine.keys.toList()..sort();
        final got = [for (final k in keys) byLine[k]!.trim().replaceAll(RegExp(r' +'), ' ')];
        expect(got, want[i], reason: '$name, $wrap');
        if (name == 'atomic') expect(tester.getTopLeft(find.byKey(atom)).dy, lessThan(20), reason: '$wrap');
        // Only the breaks move: never the line count, nor the widths.
        expect(r.size.height, 20.0 * want[0].length, reason: '$name, $wrap');
        expect(
          r.getMaxIntrinsicWidth(double.infinity),
          (await lay(
            tester,
            width,
            InlineFlow(font: body, style: px(16), textIndent: indent, children: children),
          )).getMaxIntrinsicWidth(double.infinity),
          reason: '$name, $wrap',
        );
      }
    }

    // AN ATOMIC INLINE LAST BEFORE A FORCED BREAK leaves pretty lines
    // greedy (Blink's `CanBreakInside` sees the break after it): a last
    // line of the atom alone stays, where at the flow's end it is pulled
    // up to `hhh` (Chrome 151, probe_bal/bal.py 'bratom', 'atomend').
    final last = GlobalKey();
    for (final (br, lines, text) in [
      (true, 4, ['aa bb cc dd', 'ee ff gg hhh', 'aa']),
      (false, 3, ['aa bb cc dd', 'ee ff gg', 'hhh']),
    ]) {
      final r = await lay(
        tester,
        200,
        InlineFlow(
          font: body,
          style: px(16),
          textWrap: TextWrapStyle.pretty,
          children: [
            const InlineText('aa bb cc dd ee ff gg hhh '),
            InlineAtom(child: SizedBox(key: last, width: 16, height: 10)),
            if (br) ...const [InlineBreak(), InlineText('aa')],
          ],
        ),
      );
      final byLine = <double, String>{};
      for (final p in r.pieces) {
        byLine[p.baseline] = (byLine[p.baseline] ?? '') + p.text;
      }
      final keys = byLine.keys.toList()..sort();
      expect([for (final k in keys) byLine[k]!.trim()], text, reason: 'br: $br');
      expect(r.size.height, 20.0 * lines, reason: 'br: $br');
      final y = tester.getTopLeft(find.byKey(last)).dy;
      expect(y >= 40 && y < 60, isTrue, reason: 'br: $br, the atom on the third line, at $y');
    }

    // KEPT SPACES (`white-space: pre-wrap`): a run of them is one break,
    // after its last space (UAX #14 LB7), hanging where the line ends --
    // no candidate between two of its spaces (Chrome 151,
    // probe_bal/sweep6.py: 600 paragraphs of words with runs of one to
    // three spaces, every greedy, balanced and pretty line as Chrome's).
    for (final (wrap, text) in [
      (TextWrapStyle.auto, ['dbbdhd haahh', 'db fdd ehefg', 'cf df aab', 'ga']),
      (TextWrapStyle.balance, ['dbbdhd', 'haahh db', 'fdd ehefg cf', 'df aab ga']),
      (TextWrapStyle.pretty, ['dbbdhd haahh', 'db fdd', 'ehefg cf df', 'aab ga']),
    ]) {
      final r = await lay(
        tester,
        202,
        InlineFlow(
          font: body,
          style: px(16),
          whiteSpace: WhiteSpace.preWrap,
          textWrap: wrap,
          children: const [InlineText('dbbdhd haahh  db fdd ehefg cf df   aab  ga')],
        ),
      );
      final byLine = <double, String>{};
      for (final p in r.pieces) {
        byLine[p.baseline] = (byLine[p.baseline] ?? '') + p.text;
      }
      final keys = byLine.keys.toList()..sort();
      expect([for (final k in keys) byLine[k]!.trim().replaceAll(RegExp(r' +'), ' ')], text, reason: '$wrap');
    }
  });

  testWidgets('a line fits as Blink counts it: each text at its width rounded up to 1/64 px, and 1/64 px to spare', (
    tester,
  ) async {
    // Oracle: Chrome 151 in Ahem at 16px/20px, a hair of letter-spacing
    // for the fractions (scratch/inlineflow/probe_pw/lu.py). Blink's
    // `LineBreaker` fits a line to its room `AddEpsilon()`-ed, one
    // LayoutUnit more, summing each text item it has closed at its
    // `SnappedWidth()`, its float width rounded up: `aaaaa b` tracked
    // 0.001px, 112.007 wide, is one line in 112px; with `aaaaa` a span of
    // its own (80.005 -> 80.015625) it is two, and one again in 113px.
    for (final (width, ls, spans, lines) in [
      (112.0, 0.001, 0, 1),
      (111.0, 0.001, 0, 2),
      (112.0, 0.002, 0, 1),
      (112.0, 0.003, 0, 2),
      (112.0, 0.001, 1, 2),
      (113.0, 0.001, 1, 1),
      (112.0, 0.0, 1, 1),
      (112.0, 0.001, 2, 2),
    ]) {
      final r = await lay(
        tester,
        width,
        InlineFlow(
          font: body,
          style: TextStyle(fontSize: 16, letterSpacing: ls),
          children: [
            if (spans == 0) const InlineText('aaaaa b'),
            if (spans == 1) InlineBox(children: const [InlineText('aaaaa')]),
            if (spans == 2) ...[
              InlineBox(children: const [InlineText('aa')]),
              InlineBox(children: const [InlineText('aaa')]),
            ],
            if (spans > 0) const InlineText(' b'),
          ],
        ),
      );
      expect(r.size.height, 20.0 * lines, reason: 'width $width, letter-spacing $ls, spans $spans');
    }

    // PRETTY'S "LAST LINE UNDER A THIRD OF THE ROOM" in LayoutUnits: the
    // third cut down to 1/64 px (probe_pw/third.py). In 96.03125px a
    // third is 32.0104, 32 in LayoutUnits, so `gg` (32) stays last.
    for (final (width, text) in [
      (96.0, ['aa bb', 'cc dd', 'ee ff', 'gg']),
      (96.03125, ['aa bb', 'cc dd', 'ee ff', 'gg']),
      (96.0625, ['aa bb', 'cc dd', 'ee', 'ff gg']),
    ]) {
      final r = await lay(
        tester,
        width,
        InlineFlow(
          font: body,
          style: px(16),
          textWrap: TextWrapStyle.pretty,
          children: const [InlineText('aa bb cc dd ee ff gg')],
        ),
      );
      final byLine = <double, String>{};
      for (final p in r.pieces) {
        byLine[p.baseline] = (byLine[p.baseline] ?? '') + p.text;
      }
      final keys = byLine.keys.toList()..sort();
      expect([for (final k in keys) byLine[k]!.trim()], text, reason: 'width $width');
    }
  });

  testWidgets('pre-wrap: balanced and pretty lines score kept spaces as Blink does', (tester) async {
    // Oracle: Chrome 151 in Ahem at 16px/20px, `white-space: pre-wrap`,
    // paragraphs of scratch/inlineflow/probe_bal/sweep5.py and sweep7.py
    // (framed, sized and nowrap spans, inline-blocks `#`, forced breaks),
    // each line's text off the glyphs' rects. Of 3300 such paragraphs, in
    // Ahem and in Inter, the flow breaks every one greedy, balanced and
    // pretty as Chrome does but one balanced one, Inter tracked 1px.
    // - c195: the greedy break after a nowrap span stands where the kept
    //   space after the span ends the greedy line;
    // - c8: a kept space before a forced break, in the last word's text, is
    //   the paragraph's last line's -- the lines stay greedy; without it
    //   (c8-) they balance;
    // - c154: those spaces count only as far as the greedy last line's
    //   room (`ebhgd   ` is 128px in 127);
    // - c45: kept spaces that lead a run after nowrap text are one break
    //   with the first, which the score does not take;
    // - c214: the kept space after `<br>` breaks, whatever is before it.
    final atoms = <GlobalKey>[];
    List<InlineNode> build(List<(String, Object)> segs, List<String> gaps) {
      final kids = <InlineNode>[];
      var text = '';
      void cut() {
        if (text.isNotEmpty) kids.add(InlineText(text));
        text = '';
      }

      for (final (i, (k, v)) in segs.indexed) {
        if (i > 0) text += gaps[i - 1];
        final parts = k.split(' ');
        switch (parts[0]) {
          case 'w':
            text += v as String;
          case 'nowrap':
            cut();
            kids.add(InlineBox(whiteSpace: WhiteSpace.nowrap, children: [InlineText(v as String)]));
          case 'size12' || 'size20':
            cut();
            final size = parts[0] == 'size12' ? 12.0 : 20.0;
            kids.add(
              InlineBox(
                style: TextStyle(fontSize: size),
                font: font(size, 20),
                children: [InlineText(v as String)],
              ),
            );
          case 'frame':
            cut();
            final [pad, mar, bor] = [for (final n in parts.skip(1)) double.parse(n)];
            kids.add(
              InlineBox(
                padding: EdgeInsets.symmetric(horizontal: pad),
                margin: EdgeInsets.symmetric(horizontal: mar),
                decoration: bor == 0 ? null : BoxDecoration(border: Border.all(width: bor)),
                children: [InlineText(v as String)],
              ),
            );
          case 'br':
            cut();
            kids.add(const InlineBreak());
          case 'atom':
            cut();
            final key = GlobalKey();
            atoms.add(key);
            kids.add(
              InlineAtom(
                child: SizedBox(key: key, width: (v as int).toDouble(), height: 10),
              ),
            );
        }
      }
      cut();
      return kids;
    }

    for (final (name, width, indent, align, ls, breakWord, wrap, segs, gaps, want) in [
      (
        'c195',
        209.0,
        0.0,
        TextAlign.left,
        0.0,
        false,
        TextWrapStyle.balance,
        [('w', 'h'), ('nowrap', 'abe e gebeg'), ('w', 'haf'), ('w', 'hb'), ('w', 'ca'), ('frame 6 4 1', 'afgdfc')],
        [' ', ' ', '   ', '  ', '   '],
        ['h abe e gebeg', 'haf hb', 'ca afgdfc'],
      ),
      (
        'c8',
        157.0,
        40.0,
        TextAlign.left,
        0.0,
        true,
        TextWrapStyle.balance,
        [
          ('w', 'hecgb'),
          ('w', 'ee'),
          ('w', 'ebgdbb'),
          ('w', 'd'),
          ('w', 'egdg'),
          ('w', 'eaa'),
          ('size12', 'faffc hfa bb'),
          ('w', 'dbhfahe'),
          ('br', ''),
          ('size20', 'cchbf'),
          ('w', 'f'),
          ('w', 'gg'),
        ],
        ['   ', ' ', ' ', ' ', ' ', '  ', ' ', ' ', ' ', ' ', ' '],
        ['hecgb', 'ee ebgdbb', 'd egdg', 'eaa faffc', 'hfa bb', 'dbhfahe', 'cchbf f', 'gg'],
      ),
      (
        'c8-',
        157.0,
        40.0,
        TextAlign.left,
        0.0,
        true,
        TextWrapStyle.balance,
        [
          ('w', 'hecgb'),
          ('w', 'ee'),
          ('w', 'ebgdbb'),
          ('w', 'd'),
          ('w', 'egdg'),
          ('w', 'eaa'),
          ('size12', 'faffc hfa bb'),
          ('w', 'dbhfahe'),
          ('br', ''),
          ('size20', 'cchbf'),
          ('w', 'f'),
          ('w', 'gg'),
        ],
        ['   ', ' ', ' ', ' ', ' ', '  ', ' ', '', ' ', ' ', ' '],
        ['hecgb', 'ee ebgdbb', 'd egdg', 'eaa', 'faffc hfa', 'bb dbhfahe', 'cchbf f', 'gg'],
      ),
      (
        'c154',
        127.0,
        16.0,
        TextAlign.left,
        0.0,
        true,
        TextWrapStyle.balance,
        [('w', 'dch'), ('size12', 'fbaddg'), ('atom', 24), ('w', 'ebhgd'), ('br', ''), ('w', 'fhd'), ('w', 'dg')],
        [' ', ' ', '  ', '   ', ' ', ' '],
        ['dch', 'fbaddg #', 'ebhgd', 'fhd dg'],
      ),
      (
        'c45',
        302.0,
        0.0,
        TextAlign.left,
        0.0,
        false,
        TextWrapStyle.pretty,
        [
          ('size20', 'dbbe ahgffhe'),
          ('br', ''),
          ('size20', 'e'),
          ('w', 'ga'),
          ('size12', 'c'),
          ('w', 'h'),
          ('nowrap', 'e eef'),
          ('nowrap', 'ghfdc ceech'),
          ('w', 'cbeha'),
          ('atom', 64),
        ],
        ['   ', ' ', '  ', ' ', '  ', ' ', ' ', '  ', ' '],
        ['dbbe ahgffhe', 'e ga c h e eef', 'ghfdc ceech cbeha', '#'],
      ),
      (
        'c214',
        166.0,
        0.0,
        TextAlign.center,
        1.0,
        false,
        TextWrapStyle.pretty,
        [
          ('w', 'bc'),
          ('w', 'abdccb'),
          ('size12', 'bagah agb haef'),
          ('w', 'e'),
          ('frame 0 4 0', 'cfgh fedcgff fdf'),
          ('w', 'gb'),
          ('frame 10 0 1', 'bhhb cgbeh'),
          ('br', ''),
          ('w', 'ge'),
          ('nowrap', 'fefgb behfgh ae'),
          ('br', ''),
          ('w', 'ba'),
          ('w', 'e'),
          ('w', 'hg'),
        ],
        [' ', ' ', '   ', ' ', '  ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', '   '],
        [
          'bc abdccb',
          'bagah agb',
          'haef e',
          'cfgh',
          'fedcgff',
          'fdf gb',
          'bhhb',
          'cgbeh',
          'ge',
          'fefgb behfgh ae',
          'ba',
          'e hg',
        ],
      ),
    ]) {
      atoms.clear();
      final r = await lay(
        tester,
        width,
        InlineFlow(
          font: body,
          style: TextStyle(fontSize: 16, letterSpacing: ls),
          textIndent: indent,
          textAlign: align,
          overflowWrap: breakWord ? OverflowWrap.breakWord : OverflowWrap.normal,
          whiteSpace: WhiteSpace.preWrap,
          textWrap: wrap,
          children: build(segs, gaps),
        ),
      );
      final origin = tester.getTopLeft(find.byType(InlineFlow));
      final rows = <(double, double, String)>[
        for (final p in r.pieces) (p.baseline, p.x, p.text),
        for (final k in atoms)
          (tester.getTopLeft(find.byKey(k)).dy - origin.dy + 10, tester.getTopLeft(find.byKey(k)).dx - origin.dx, '#'),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
      final lines = <List<(double, double, String)>>[];
      for (final row in rows) {
        if (lines.isEmpty || (row.$1 - lines.last.first.$1).abs() > 10) {
          lines.add([row]);
        } else {
          lines.last.add(row);
        }
      }
      final got = [
        for (final l in lines)
          ((List.of(
            l,
          )..sort((a, b) => a.$2.compareTo(b.$2))).map((e) => e.$3).join(' ')).replaceAll(RegExp(r'\s+'), ' ').trim(),
      ];
      expect(got, want, reason: name);
    }
  });

  testWidgets('break-word breaks a word the line cannot hold, never in text that does not wrap', (tester) async {
    // Oracle: Chrome 151 in Ahem at 16px/20px (scratch/inlineflow/
    // probe_bal/bw.py), `overflow-wrap: break-word` on the paragraph.
    InlineBox framed(double pad, double margin, double border, String t) => InlineBox(
      padding: EdgeInsets.symmetric(horizontal: pad),
      margin: EdgeInsets.symmetric(horizontal: margin),
      decoration: BoxDecoration(border: Border.all(width: border)),
      children: [InlineText(t)],
    );
    final cases = <String, (double, List<InlineNode>, List<String>)>{
      // A nowrap run too wide for the line stays whole, overflowing.
      'nowrap': (
        96,
        [
          const InlineText('ab '),
          const InlineBox(whiteSpace: WhiteSpace.nowrap, children: [InlineText('cdef ghij')]),
          const InlineText(' kl'),
        ],
        ['ab', 'cdef ghij', 'kl'],
      ),
      // A word too wide for the line it STARTS is broken too.
      'start': (104, [const InlineText('abcdefghijklmnopqr st')], ['abcdef', 'ghijkl', 'mnopqr', 'st']),
      // A box's start edge takes room from its word.
      'edge': (
        90,
        [const InlineText('ab '), framed(6, 4, 1, 'acace'), const InlineText(' de')],
        ['ab', 'acac', 'e de'],
      ),
      // A box's last word that fits but for its end edge loses its last
      // letter, whatever the edge (probe_bal/endedge.py).
      'end edge': (
        119,
        [const InlineText('f '), framed(3, 4, 3, 'agbbebc fgcbfea'), const InlineText(' gabg')],
        ['f', 'agbbeb', 'c', 'fgcbfe', 'a gabg'],
      ),
      'wide end edge': (117, [framed(10, 12, 3, 'ac ddfcdah'), const InlineText(' cd')], ['ac', 'ddfcda', 'h cd']),
      'wider end edge': (130, [framed(20, 17, 3, 'ac abcdefg'), const InlineText(' cd')], ['ac', 'abcdef', 'g cd']),
    };
    for (final MapEntry(key: name, value: (width, children, want)) in cases.entries) {
      final r = await lay(
        tester,
        width,
        InlineFlow(font: body, style: px(16), overflowWrap: OverflowWrap.breakWord, children: children),
      );
      final byLine = <double, String>{};
      for (final p in r.pieces) {
        byLine[p.baseline] = (byLine[p.baseline] ?? '') + p.text;
      }
      final keys = byLine.keys.toList()..sort();
      expect([for (final k in keys) byLine[k]!.trim().replaceAll(RegExp(r' +'), ' ')], want, reason: name);
    }
    // The min-content width is still the longest word's: break-word's
    // breaks are not soft wrap opportunities for it (css-text-3 5.5).
    final r = await lay(
      tester,
      104,
      InlineFlow(
        font: body,
        style: px(16),
        overflowWrap: OverflowWrap.breakWord,
        children: const [InlineText('abcdefghijklmnopqr st')],
      ),
    );
    expect(r.getMinIntrinsicWidth(double.infinity), 18 * 16);
  });

  testWidgets('the test font is one em a glyph, spaces too', (tester) async {
    final tp = TextPainter(
      text: const TextSpan(text: 'a b', style: TextStyle(fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(tp.width, 30);
    tp.dispose();
  });

  testWidgets('middle: a box a line breaks inside stands each piece by its own line (CSS 2.1 10.8.1)', (tester) async {
    const span = InlineBox(
      style: TextStyle(fontSize: 24),
      font: InlineFont(size: 24, ascent: 19, descent: 5, lineHeight: 30, xHeight: 19.2),
      verticalAlign: VerticalAlign.middle,
      children: [InlineText('cc dddd eee')],
    );
    final r = await lay(
      tester,
      200,
      InlineFlow(font: body, style: px(16), children: const [InlineText('aaa bbb '), span, InlineText(' ff')]),
    );
    expect(r.size, const Size(200, 80));
    rects(r.fragmentsOf(span), [
      [128, 3, 48, 24],
      [0, 33, 192, 24],
    ]);
    pieces(r, [('aaa bbb ', 0, 21.40625, 128), ('cc', 128, 22, 48), ('dddd eee', 0, 52, 192), ('ff', 0, 75, 32)]);
  });

  // Blink, not the engine: a fifth and a third of the PARENT's size, each
  // cut to 1/64 px, and one pixel more (`fixtures/vertical-align-shift`).
  testWidgets('sub and super: a fifth of the parent down, a third up, a pixel more each', (tester) async {
    final sub = InlineBox(
      style: px(12),
      font: font(12, 20),
      verticalAlign: VerticalAlign.sub,
      children: const [InlineText('12')],
    );
    final sup = InlineBox(
      style: px(10),
      font: font(10, 20),
      verticalAlign: VerticalAlign.superscript,
      children: const [InlineText('3')],
    );
    final r = await lay(
      tester,
      300,
      InlineFlow(
        font: body,
        style: px(16),
        children: [const InlineText('x'), sub, const InlineText(' y'), sup, const InlineText(' z')],
      ),
    );
    expect(r.size.height, moreOrLessEquals(29.515625, epsilon: 1e-6));
    rects(r.fragmentsOf(sub), [
      [16, 13.515625, 24, 12],
    ]);
    rects(r.fragmentsOf(sup), [
      [72, 5, 10, 10],
    ]);
  });

  testWidgets('a frame broken over two lines: its start on the first, its end on the last', (tester) async {
    final chip = InlineBox(
      padding: const EdgeInsets.fromLTRB(4, 1, 4, 3),
      decoration: BoxDecoration(border: Border.all(width: 2)),
      children: const [InlineText('cd efgh ij')],
    );
    final r = await lay(
      tester,
      150,
      InlineFlow(font: body, style: px(16), children: [const InlineText('ab '), chip, const InlineText(' kl')]),
    );
    expect(r.size, const Size(150, 60));
    rects(r.fragmentsOf(chip), [
      [48, -1, 38, 24],
      [0, 19, 118, 24],
    ]);
    pieces(r, [('ab ', 0, 15, 48), ('cd', 54, 15, 32), ('efgh ij', 0, 35, 112), ('kl', 0, 55, 32)]);
  });

  testWidgets('atomic inlines at bottom, middle and top', (tester) async {
    final r = await lay(
      tester,
      300,
      InlineFlow(
        font: body,
        style: px(16),
        children: const [
          InlineText('ab '),
          InlineAtom(
            child: SizedBox(key: ValueKey('a'), width: 30, height: 40),
            verticalAlign: VerticalAlign.bottom,
          ),
          InlineText(' cd '),
          InlineAtom(
            child: SizedBox(key: ValueKey('b'), width: 20, height: 10),
            verticalAlign: VerticalAlign.middle,
          ),
          InlineText(' ef '),
          InlineAtom(
            child: SizedBox(key: ValueKey('c'), width: 10, height: 50),
            verticalAlign: VerticalAlign.top,
          ),
        ],
      ),
    );
    expect(r.size, const Size(300, 50));
    expect(tester.getRect(find.byKey(const ValueKey('a'))), const Rect.fromLTWH(48, 10, 30, 40));
    expect(tester.getRect(find.byKey(const ValueKey('b'))), const Rect.fromLTWH(142, 23.59375, 20, 10));
    expect(tester.getRect(find.byKey(const ValueKey('c'))), const Rect.fromLTWH(226, 0, 10, 50));
  });

  testWidgets('text-top, text-bottom and a length', (tester) async {
    final top = InlineBox(
      style: px(10),
      font: font(10, 20),
      verticalAlign: VerticalAlign.textTop,
      children: const [InlineText('cd')],
    );
    final bottom = InlineBox(
      style: px(30),
      font: font(30, 30),
      verticalAlign: VerticalAlign.textBottom,
      children: const [InlineText('gh')],
    );
    final raised = InlineBox(verticalAlign: const VerticalAlign.length(5), children: const [InlineText('kl')]);
    final r = await lay(
      tester,
      400,
      InlineFlow(
        font: body,
        style: px(16),
        children: [const InlineText('ab '), top, const InlineText(' ef '), bottom, const InlineText(' ij '), raised],
      ),
    );
    expect(r.size, const Size(400, 34));
    rects(r.fragmentsOf(top), [
      [48, 19, 20, 10],
    ]);
    rects(r.fragmentsOf(bottom), [
      [132, 0, 60, 30],
    ]);
    rects(r.fragmentsOf(raised), [
      [256, 9, 32, 16],
    ]);
  });

  testWidgets('a forced break, each line centred', (tester) async {
    final r = await lay(
      tester,
      200,
      InlineFlow(
        font: body,
        style: px(16),
        textAlign: TextAlign.center,
        children: const [InlineText('abc'), InlineBreak(), InlineText('de f')],
      ),
    );
    expect(r.size, const Size(200, 40));
    pieces(r, [('abc', 76, 15, 48), ('de f', 68, 35, 64)]);
  });

  testWidgets('a nowrap run in a wrapping line comes down whole, and hangs out', (tester) async {
    const run = InlineBox(whiteSpace: WhiteSpace.nowrap, children: [InlineText('cd ef gh')]);
    final r = await lay(
      tester,
      100,
      InlineFlow(font: body, style: px(16), children: const [InlineText('ab '), run, InlineText(' ij')]),
    );
    expect(r.size, const Size(100, 60));
    rects(r.fragmentsOf(run), [
      [0, 22, 128, 16],
    ]);
    pieces(r, [('ab', 0, 15, 32), ('cd ef gh', 0, 35, 128), ('ij', 0, 55, 32)]);
  });

  // From here on the numbers are CHROME's (151, Ahem at 16px/20px, which
  // is this font's advance), where the engine sets these otherwise.
  testWidgets('pre-wrap spaces are kept, and hang past the edge where a soft wrap ends the line', (tester) async {
    const run = InlineBox(whiteSpace: WhiteSpace.preWrap, children: [InlineText('c  d  e')]);
    final r = await lay(
      tester,
      120,
      InlineFlow(font: body, style: px(16), children: const [InlineText('ab '), run, InlineText(' f')]),
    );
    expect(r.size, const Size(120, 40));
    rects(r.fragmentsOf(run), [
      [48, 2, 96, 16],
      [0, 22, 16, 16],
    ]);
    pieces(r, [('ab ', 0, 15, 48), ('c  d  ', 48, 15, 96), ('e', 0, 35, 16), (' f', 16, 35, 32)]);
  });

  testWidgets('hanging spaces take no room under text-align: at a soft wrap none, at the end what fits', (
    tester,
  ) async {
    var r = await lay(
      tester,
      120,
      InlineFlow(
        font: body,
        style: px(16),
        whiteSpace: WhiteSpace.preWrap,
        textAlign: TextAlign.right,
        children: const [InlineText('abc  defgh')],
      ),
    );
    pieces(r, [('abc  ', 72, 15, 80), ('defgh', 40, 35, 80)]);
    r = await lay(
      tester,
      200,
      InlineFlow(
        font: body,
        style: px(16),
        whiteSpace: WhiteSpace.preWrap,
        textAlign: TextAlign.right,
        children: const [InlineText('abc   ')],
      ),
    );
    pieces(r, [('abc   ', 104, 15, 96)]);
    r = await lay(
      tester,
      80,
      InlineFlow(
        font: body,
        style: px(16),
        whiteSpace: WhiteSpace.preWrap,
        textAlign: TextAlign.right,
        children: const [InlineText('abc      ')],
      ),
    );
    pieces(r, [('abc      ', 0, 15, 144)]);
    // Max-content keeps the paragraph's last spaces; min-content none.
    final flow = InlineFlow(
      font: body,
      style: px(16),
      whiteSpace: WhiteSpace.preWrap,
      children: const [InlineText('ab   cd   ')],
    );
    r = await lay(tester, 300, flow);
    expect(r.getMinIntrinsicWidth(double.infinity), 32);
    expect(r.getMaxIntrinsicWidth(double.infinity), 160);
  });

  testWidgets('a tab stops at the next multiple of tab-size spaces from the line start', (tester) async {
    Future<List<double>> xs(InlineFlow f) async {
      final r = await lay(tester, 600, f);
      return [for (final p in r.pieces) p.x];
    }

    InlineFlow pre(String t, {double indent = 0, double tabSize = 8}) => InlineFlow(
      font: body,
      style: px(16),
      whiteSpace: WhiteSpace.pre,
      textIndent: indent,
      tabSize: tabSize,
      children: [InlineText(t)],
    );
    expect(await xs(pre('abc\tde')), [0, 128]);
    expect(await xs(pre('abcdefg\th')), [0, 128]);
    // On a stop, a whole tab more.
    expect(await xs(pre('abcdefgh\ti')), [0, 256]);
    // The indent is inside the line; the stops are not moved by it.
    expect(await xs(pre('abc\tde', indent: 40)), [40, 128]);
    expect(await xs(pre('abc\tde', tabSize: 4)), [0, 64]);
  });

  testWidgets("top and bottom: a box a line breaks inside stands on each line's edge, its words with it", (
    tester,
  ) async {
    final small = font(10, 14);
    for (final (align, first, second) in [
      (VerticalAlign.top, [42.0, 2.0, 80.0, 10.0], [0.0, 22.0, 110.0, 10.0]),
      (VerticalAlign.bottom, [42.0, 8.0, 80.0, 10.0], [0.0, 28.0, 110.0, 10.0]),
    ]) {
      final box = InlineBox(
        font: small,
        verticalAlign: align,
        children: [InlineText('hi no ac ev st we ru', style: px(10))],
      );
      final r = await lay(
        tester,
        140,
        InlineFlow(
          font: font(14, 20),
          style: px(14),
          children: [const InlineText('Ca '), box, const InlineText(' wo')],
        ),
      );
      expect(r.size, const Size(140, 60));
      rects(r.fragmentsOf(box), [first, second]);
      pieces(r, [
        ('Ca ', 0, 14, 42),
        ('hi no ac', 42, first[1] + 8, 80),
        ('ev st we ru', 0, second[1] + 8, 110),
        ('wo', 0, 54, 28),
      ]);
    }
  });

  testWidgets('break-all breaks between any two letters, the first word on a line too', (tester) async {
    var r = await lay(
      tester,
      50,
      InlineFlow(font: body, style: px(16), wordBreak: WordBreak.breakAll, children: const [InlineText('abcdefg hi')]),
    );
    expect(r.size, const Size(50, 80));
    pieces(r, [('abc', 0, 15, 48), ('def', 0, 35, 48), ('g h', 0, 55, 48), ('i', 0, 75, 16)]);
    r = await lay(
      tester,
      100,
      InlineFlow(font: body, style: px(16), wordBreak: WordBreak.breakAll, children: const [InlineText('abc defghij')]),
    );
    pieces(r, [('abc de', 0, 15, 96), ('fghij', 0, 35, 80)]);
  });

  testWidgets('right to left: a line of left-to-right words set against the right edge', (tester) async {
    const span = InlineBox(padding: EdgeInsets.only(left: 4, right: 6), children: [InlineText('cd ef')]);
    final r = await lay(
      tester,
      200,
      direction: TextDirection.rtl,
      InlineFlow(font: body, style: px(16), children: const [InlineText('ab '), span, InlineText(' gh')]),
    );
    expect(r.size, const Size(200, 20));
    rects(r.fragmentsOf(span), [
      [62, 2, 90, 16],
    ]);
    pieces(r, [('ab ', 14, 15, 48), ('cd ef', 66, 15, 80), (' gh', 152, 15, 48)]);
  });

  testWidgets('min- and max-content widths', (tester) async {
    final r = await lay(
      tester,
      200,
      InlineFlow(
        font: body,
        style: px(16),
        children: const [
          InlineText('ab cdef '),
          InlineAtom(child: SizedBox(width: 70, height: 10)),
        ],
      ),
    );
    expect(r.getMinIntrinsicWidth(double.infinity), 70);
    expect(r.getMaxIntrinsicWidth(double.infinity), 16 * 8 + 70);
  });
}
