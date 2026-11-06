import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';

// The test font draws every glyph 14px wide at 14px: a 140px box holds ten
// characters a line, and the breaks below can be counted.
const _words = 'aaaa bbbb cccc dddd eeee ffff';
const _style = TextStyle(fontSize: 14, height: 1.0);

Widget _page(double indent, {double width = 140, TextAlign align = TextAlign.start, bool wrap = true}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: IndentedText(
            _words,
            key: const Key('p'),
            indent: indent,
            style: _style,
            textAlign: align,
            softWrap: wrap,
          ),
        ),
      ),
    );

void main() {
  RenderIndentedText ro(WidgetTester t) => t.renderObject<RenderIndentedText>(find.byKey(const Key('p')));

  testWidgets('a hanging indent widens the first line and breaks the rest in the box', (tester) async {
    // First line room 210 = 15 characters: `aaaa bbbb cccc` (14) fits;
    // the rest, in 10, is `dddd eeee` / `ffff`.
    await tester.pumpWidget(_page(-70));
    expect(ro(tester).restText, 'dddd eeee ffff');
    expect(tester.getSize(find.byKey(const Key('p'))), const Size(140, 42));
  });

  testWidgets('balanced, each line is scored against its own room, the first against the wider one', (tester) async {
    // A first line of 14 characters (196 = 140 + 56), the rest of 10.
    // Greedy: `a bbb c ddd` / `eeee fffff` / `gggg hhhh` / `aaaa`. Every
    // line against 10 would pull `ddd` down: `a bbb c` / `ddd eeee` / ...
    // Against its own room the first keeps it, and the rest even out
    // (fixtures/indent-hanging-balance, where Chrome sets a product site's quote
    // so).
    const words = 'a bbb c ddd eeee fffff gggg hhhh aaaa';
    Widget page({required bool balance}) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 140,
          child: IndentedText(words, key: const Key('p'), indent: -56, style: _style, balance: balance),
        ),
      ),
    );
    await tester.pumpWidget(page(balance: false));
    expect(ro(tester).restText, 'eeee fffff gggg hhhh aaaa');
    expect(tester.getSize(find.byKey(const Key('p'))).height, 56);
    await tester.pumpWidget(page(balance: true));
    expect(ro(tester).restText, 'eeee\nfffff gggg\nhhhh aaaa');
    // The same four lines: balancing never changes the count.
    expect(tester.getSize(find.byKey(const Key('p'))).height, 56);
    // Nor the intrinsic widths, which are the greedy text's.
    expect(ro(tester).getMaxIntrinsicWidth(double.infinity), 37 * 14 - 56);
  });

  testWidgets('pretty, the last lines re-broken reach the first, scored against its own room', (tester) async {
    // A first line of 13 characters (182 = 140 + 42), the rest of 10.
    // Greedy: `aaaaaa bbb` / `cccc ddddd` / `e ffffff` / `ggg`, one word
    // under a third of the room on the last line. The four lines are
    // re-broken with two words at least on the last, the first scored
    // against 13, where it keeps `bbb`; against 10 it would give it up
    // (fixtures/indent-hanging-pretty, 61 of 61 Chrome paragraphs).
    const words = 'aaaaaa bbb cccc ddddd e ffffff ggg';
    Widget page({required bool pretty}) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 140,
          child: IndentedText(words, key: const Key('p'), indent: -42, style: _style, pretty: pretty),
        ),
      ),
    );
    await tester.pumpWidget(page(pretty: false));
    expect(ro(tester).restText, 'cccc ddddd e ffffff ggg');
    await tester.pumpWidget(page(pretty: true));
    expect(ro(tester).restText, 'cccc\nddddd e\nffffff ggg');
    expect(tester.getSize(find.byKey(const Key('p'))).height, 56);
  });

  testWidgets('a narrower hanging indent breaks the first line sooner', (tester) async {
    // Room 168 = 12: `aaaa bbbb` (9); the rest is `cccc dddd` / `eeee ffff`.
    await tester.pumpWidget(_page(-28));
    expect(ro(tester).restText, 'cccc dddd eeee ffff');
    expect(tester.getSize(find.byKey(const Key('p'))).height, 42);
  });

  testWidgets('a positive indent narrows the first line', (tester) async {
    // Room 112 = 8: `aaaa`; the rest in 10 is three lines.
    await tester.pumpWidget(_page(28));
    expect(ro(tester).restText, 'bbbb cccc dddd eeee ffff');
    expect(tester.getSize(find.byKey(const Key('p'))).height, 56);
  });

  testWidgets('one line that fits has no rest, and no wrapping means one line', (tester) async {
    await tester.pumpWidget(_page(-70, width: 420));
    expect(ro(tester).restText, '');
    expect(tester.getSize(find.byKey(const Key('p'))).height, 14);
    await tester.pumpWidget(_page(-70, wrap: false));
    expect(ro(tester).restText, '');
    expect(tester.getSize(find.byKey(const Key('p'))).height, 14);
  });

  testWidgets('the intrinsic widths are the text\'s, moved by the indent', (tester) async {
    await tester.pumpWidget(_page(-70));
    final r = ro(tester);
    // The whole text on one line is 29 characters, 406px, and starts 70
    // out: the box needs 336. The widest word is 4 characters, 56px.
    expect(r.getMaxIntrinsicWidth(double.infinity), 336);
    expect(r.getMinIntrinsicWidth(double.infinity), 56);
    expect(r.getDryLayout(const BoxConstraints(maxWidth: 140)).height, 42);
    expect(r.getDryBaseline(const BoxConstraints(maxWidth: 140), TextBaseline.alphabetic), isNotNull);
  });

  testWidgets('a span tree is cut at the first line with its styles kept', (tester) async {
    // The same words as spans -- `cccc dddd` styled, as a han-trimmed run
    // styles the glyph that gives up its blank -- break where the plain
    // string does, and the styled part reaches the rest whole.
    const styled = TextStyle(fontFeatures: [FontFeature('halt')]);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 140,
            child: IndentedText.rich(
              const TextSpan(
                children: [
                  TextSpan(text: 'aaaa bb'),
                  TextSpan(text: 'bb cccc dddd', style: styled),
                  TextSpan(text: ' eeee ffff'),
                ],
              ),
              key: const Key('p'),
              indent: -28,
              style: _style,
            ),
          ),
        ),
      ),
    );
    final r = ro(tester);
    expect(r.restText, 'cccc dddd eeee ffff');
    expect(r.restSpan!.toPlainText(), 'cccc dddd eeee ffff');
    final parts = <String>[];
    r.restSpan!.visitChildren((span) {
      if (span is TextSpan && span.text != null) {
        parts.add('${span.text}${span.style?.fontFeatures != null ? '*' : ''}');
      }
      return true;
    });
    // The styled span is cut to its tail and stays styled; the plain
    // one after it is whole.
    expect(parts, ['cccc dddd*', ' eeee ffff']);
    expect(tester.getSize(find.byKey(const Key('p'))).height, 42);
  });

  testWidgets('a loose box is as wide as the shifted whole text, as a Text is', (tester) async {
    await tester.pumpWidget(_page(-70, width: 1000));
    // Not 1000: the box is the text's own width, 406 - 70.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: IndentedText(_words, key: const Key('p'), indent: -70, style: _style),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('p'))).width, 336);
  });

  Widget box(Widget child, {double width = 140, TextDirection dir = TextDirection.ltr}) => Directionality(
    textDirection: dir,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: width, child: child),
    ),
  );

  testWidgets('a share of the width is resolved against the box, and taken as nothing unsized', (tester) async {
    // 0.2 of 140 is 28: the same breaks as `indent: 28`.
    await tester.pumpWidget(box(IndentedText(_words, key: const Key('p'), share: 0.2, style: _style)));
    final r = ro(tester);
    expect(r.restText, 'bbbb cccc dddd eeee ffff');
    expect(tester.getSize(find.byKey(const Key('p'))).height, 56);
    // The widths asked before there is a box take the share as nothing.
    expect(r.getMaxIntrinsicWidth(double.infinity), 406);
    expect(r.getMinIntrinsicWidth(double.infinity), 56);
    // Painted 28 along.
    expect(
      r,
      paints
        ..paragraph(offset: const Offset(28, 0))
        ..paragraph(offset: const Offset(0, 14)),
    );
  });

  testWidgets('at no width the text is one line deep, as a Text is: no NaN from the share', (tester) async {
    // A `Column` measuring its width asks each child's height at infinity.
    // `0 * infinity` (no share) and `infinity - infinity` (a share) were
    // NaN, and the painter threw.
    await tester.pumpWidget(box(IndentedText(_words, key: const Key('p'), indent: -70, style: _style)));
    expect(ro(tester).getMaxIntrinsicHeight(double.infinity), 14);
    expect(ro(tester).getMinIntrinsicHeight(double.infinity), 14);
    // A share: the box laid out loose -- its own width 406, the share
    // taken as nothing, then 0.2 of it hung in -- which wraps one line.
    await tester.pumpWidget(box(IndentedText(_words, key: const Key('p'), share: 0.2, style: _style)));
    expect(ro(tester).getMaxIntrinsicHeight(double.infinity), 28);
    expect(ro(tester).getDryLayout(const BoxConstraints()).height, 28);
    // NEGATIVE: at a width, the height is the one laid out there.
    expect(ro(tester).getMaxIntrinsicHeight(140), 56);
  });

  testWidgets('rtl: the first line hangs out past the RIGHT edge', (tester) async {
    await tester.pumpWidget(
      box(
        IndentedText(_words, key: const Key('p'), indent: -70, style: _style),
        dir: TextDirection.rtl,
      ),
    );
    final r = ro(tester);
    expect(r.restText, 'dddd eeee ffff');
    // The first line's room is 210 from the LEFT edge, so its right end is
    // 70 past the box's; the rest is in the box.
    expect(
      r,
      paints
        ..paragraph(offset: Offset.zero)
        ..paragraph(offset: const Offset(0, 14)),
    );
    expect(r.firstLineWidth, 196);
  });

  testWidgets('a justified first line is spread to its room, and a last one is not', (tester) async {
    // Room 168 = 12: `aaaa bbbb` (126) spread to 168; the rest is justified
    // but for its last line, as a Text is.
    await tester.pumpWidget(
      box(IndentedText(_words, key: const Key('p'), indent: -28, style: _style, textAlign: TextAlign.justify)),
    );
    final r = ro(tester);
    expect(r.restText, 'cccc dddd eeee ffff');
    expect(r.firstLineWidth, 168);
    expect(
      r,
      paints
        ..save()
        ..clipRect(rect: const Rect.fromLTRB(-1e9, -1e9, 1e9, 14))
        ..paragraph(offset: const Offset(-28, 0))
        ..restore()
        ..paragraph(offset: const Offset(0, 14)),
    );
    // All of it on one line: a last line, not spread.
    await tester.pumpWidget(
      box(IndentedText('aaaa bbbb', key: const Key('p'), indent: -28, style: _style, textAlign: TextAlign.justify)),
    );
    expect(ro(tester).firstLineWidth, 126);
  });

  testWidgets('a forced break ends the first line, and the rest keeps its spaces', (tester) async {
    await tester.pumpWidget(
      box(
        IndentedText('gone\n  shown x', key: const Key('p'), indent: -1000, style: _style, softWrap: false),
        width: 80,
      ),
    );
    final r = ro(tester);
    expect(r.restText, '  shown x');
    expect(tester.getSize(find.byKey(const Key('p'))).height, 28);
    expect(
      r,
      paints
        ..paragraph(offset: const Offset(-1000, 0))
        ..paragraph(offset: const Offset(0, 14)),
    );
  });

  testWidgets('with no wrapping the least width is the longest line, the first moved by the indent', (tester) async {
    await tester.pumpWidget(
      box(IndentedText(_words, key: const Key('p'), indent: -70, style: _style, softWrap: false)),
    );
    var r = ro(tester);
    expect(r.getMinIntrinsicWidth(double.infinity), 336);
    expect(r.getMaxIntrinsicWidth(double.infinity), 336);
    await tester.pumpWidget(
      box(IndentedText('aaaa\nbbbbbbbb', key: const Key('p'), indent: -14, style: _style, softWrap: false)),
    );
    r = ro(tester);
    expect(r.getMaxIntrinsicWidth(double.infinity), 112);
  });

  testWidgets('a short rest set to the right is placed in the box, not in its own width', (tester) async {
    // Room 168: `aaaa bbbb`; the rest `cccc dd` is 98 of 140, at the right.
    await tester.pumpWidget(
      box(
        IndentedText('aaaa bbbb cccc dd', key: const Key('p'), indent: -28, style: _style, textAlign: TextAlign.right),
      ),
    );
    final r = ro(tester);
    expect(r.restText, 'cccc dd');
    expect(
      r,
      paints
        ..paragraph(offset: const Offset(-28, 0))
        ..paragraph(offset: const Offset(0, 14)),
    );
  });

  testWidgets('the rest starting on a neutral keeps the direction the letter before it gave it', (tester) async {
    // Under rtl, `(cccc` after Latin words is left to right in the whole
    // paragraph; set alone it would be right to left. A left-to-right
    // mark in front of it keeps it so. Under ltr nothing is needed.
    Widget page(TextDirection dir) => box(
      IndentedText('aaaa bbbb (ccc dddd', key: const Key('p'), indent: -28, style: _style),
      dir: dir,
    );
    await tester.pumpWidget(page(TextDirection.rtl));
    expect(ro(tester).restText, '(ccc dddd');
    expect(ro(tester).restSpan!.toPlainText(), '\u200E(ccc dddd');
    await tester.pumpWidget(page(TextDirection.ltr));
    expect(ro(tester).restSpan!.toPlainText(), '(ccc dddd');
  });

  testWidgets('the min-content width puts the indent on the first piece alone', (tester) async {
    Future<double> least(String words, double indent) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: IndentedText(words, key: const Key('p'), indent: indent, style: _style),
          ),
        ),
      );
      return ro(tester).getMinIntrinsicWidth(double.infinity);
    }

    // Hung 70 out, the 112px first word needs 42; the widest after it, 28.
    expect(await least('wwwwwwww bb cc', -70), 42);
    // 28 in, the 28px first word needs 56; the widest after it, 84.
    expect(await least('aa bbbbbb cc', 28), 84);
    // 28 in, the 84px first word needs 112.
    expect(await least('aaaaaa bb', 28), 112);
    // The first piece is found by breaking: `a`, 70 in, needs 84.
    expect(await least('a b cc', 70), 84);
    // One piece: its width, moved by the indent.
    expect(await least('aaaa', -14), 42);
  });

  testWidgets('a first word wider than the box but not than its hung room keeps a LineBox the box wide', (
    tester,
  ) async {
    // 12 characters, 168px, in a 140px box hung 42 out: the room is 182,
    // the word fits it, and the least width is 126 -- no word overflows,
    // so the line box does not widen the paragraph, and under rtl the
    // rest stays at the box's right edge.
    await tester.pumpWidget(
      box(
        LineBox(
          child: IndentedText('wwwwwwwwwwww bb', key: const Key('p'), indent: -42, style: _style),
        ),
        dir: TextDirection.rtl,
      ),
    );
    final r = ro(tester);
    expect(tester.getSize(find.byKey(const Key('p'))).width, 140);
    expect(r.restText, 'bb');
    expect(r.firstLineWidth, 168);
  });
}
