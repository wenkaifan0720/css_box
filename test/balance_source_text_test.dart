// A BALANCED PARAGRAPH IS ASKED ABOUT ITS SOURCE TEXT, NOT ABOUT THE BREAKS
// ITS LAST LAYOUT PUT ON IT. `Balance` states the lines it settles on as
// hard breaks in the paragraph's own span; asked a dry layout, a dry
// baseline or an intrinsic height at another width, or laid out again under
// another text scaler or at no width at all, it answered off those breaks:
// three lines of 180 at 700, where the words are one line. The test font's
// glyphs are 10 square at 10px.
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const words = 'one two three four five six seven eight nine ten';
const style = TextStyle(fontSize: 10);

Widget host(Widget child, {double scale = 1}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Align(alignment: Alignment.topLeft, child: child),
  ),
);

/// The plain text the paragraph under the box holds now.
String shown(WidgetTester t) => t.renderObject<RenderParagraph>(find.byType(RichText)).text.toPlainText();

/// The height [text] comes to, greedy, at [width].
double greedy(String text, double width, {TextStyle s = style}) {
  final p = TextPainter(
    text: TextSpan(text: text, style: s),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width);
  final h = p.height;
  p.dispose();
  return h;
}

void main() {
  group('asked at another width than the one laid out', () {
    Future<RenderBox> laidAt180(WidgetTester t, Widget box) async {
      await t.pumpWidget(host(SizedBox(width: 180, child: box)));
      expect(shown(t), contains('\n'), reason: 'the paragraph is broken at 180');
      return t.renderObject<RenderBox>(find.byWidget(box));
    }

    testWidgets('a dry layout is the source text there', (t) async {
      final r = await laidAt180(t, const Balance(child: Text(words, style: style)));
      expect(greedy(words, 700), 10);
      expect(r.getDryLayout(const BoxConstraints(maxWidth: 700)).height, 10);
    });

    testWidgets('NEGATIVE: asked where it was laid out, it answers what it holds', (t) async {
      // The breaks on the paragraph are the ones a layout at 180 puts there,
      // so the paragraph itself is asked; and no question puts a break on
      // it: the span it holds is its layout's.
      final r = await laidAt180(t, const Balance(child: Text(words, style: style)));
      final held = shown(t);
      expect(r.size.height, 30);
      expect(r.getDryLayout(const BoxConstraints(maxWidth: 180)), r.size);
      expect(r.getMaxIntrinsicHeight(180), 30);
      r.getDryLayout(const BoxConstraints(maxWidth: 700));
      expect(shown(t), held);
    });

    testWidgets('an intrinsic height is the source text there', (t) async {
      final r = await laidAt180(t, const Balance(child: Text(words, style: style)));
      expect(r.getMinIntrinsicHeight(700), 10);
      expect(r.getMaxIntrinsicHeight(700), 10);
      expect(r.getMaxIntrinsicHeight(180), 30);
    });

    testWidgets('a dry last baseline is the source text\'s last line there', (t) async {
      // A paragraph's last line is read dry under a forced strut, as the
      // lowering sets one: every line 12.
      const strut = StrutStyle(fontSize: 10, height: 1.2, forceStrutHeight: true);
      final r = await laidAt180(
        t,
        const Balance(
          child: Text(words, style: style, strutStyle: strut),
        ),
      );
      expect(r.size.height, 36);
      final first = r.getDryBaseline(const BoxConstraints(maxWidth: 700), TextBaseline.alphabetic)!;
      expect(dryLastBaselineOf(r, const BoxConstraints(maxWidth: 700), TextBaseline.alphabetic), first);
      expect(dryLastBaselineOf(r, const BoxConstraints(maxWidth: 180), TextBaseline.alphabetic), first + 24);
    });

    testWidgets('through a line box', (t) async {
      // Every line the strut's 12, as the lowering sets a line.
      const strut = StrutStyle(fontSize: 10, height: 1.2, forceStrutHeight: true);
      final r = await laidAt180(
        t,
        const Balance(
          child: LineBox(
            lineHeight: 12,
            child: Text(words, style: style, strutStyle: strut),
          ),
        ),
      );
      expect(r.size.height, 36);
      expect(r.getDryLayout(const BoxConstraints(maxWidth: 700)).height, 12);
      expect(r.getDryLayout(const BoxConstraints(maxWidth: 180)).height, 36);
    });

    testWidgets('a pretty paragraph too', (t) async {
      // `aaaa bbbb cccc` fills 140 and leaves `dd` alone under a third of
      // it, which `Pretty` pulls a word down to.
      const text = 'aaaa bbbb cccc dd';
      const box = Pretty(child: Text(text, style: style));
      await t.pumpWidget(host(const SizedBox(width: 140, child: box)));
      expect(shown(t), 'aaaa bbbb\ncccc dd');
      final r = t.renderObject<RenderBox>(find.byWidget(box));
      expect(r.getDryLayout(const BoxConstraints(maxWidth: 700)).height, 10);
      expect(r.getMaxIntrinsicHeight(700), 10);
    });

    testWidgets('then laid out there, it lays out what it answered', (t) async {
      const box = Balance(child: Text(words, style: style));
      await t.pumpWidget(host(const SizedBox(width: 180, child: box)));
      final dry = t.renderObject<RenderBox>(find.byWidget(box)).getDryLayout(const BoxConstraints.tightFor(width: 260));
      await t.pumpWidget(host(const SizedBox(width: 260, child: box)));
      expect(t.getSize(find.byWidget(box)), dry);
    });
  });

  group('a width with no bound takes the breaks back off', () {
    testWidgets('a row', (t) async {
      final key = GlobalKey();
      await t.pumpWidget(
        host(
          SizedBox(
            width: 180,
            child: Balance(
              key: key,
              child: const Text(words, style: style),
            ),
          ),
        ),
      );
      expect(shown(t), contains('\n'));
      await t.pumpWidget(
        host(
          Row(
            children: [
              Balance(
                key: key,
                child: const Text(words, style: style),
              ),
            ],
          ),
        ),
      );
      expect(shown(t), words);
      expect(t.getSize(find.byKey(key)), const Size(480, 10));
    });

    testWidgets('the same paragraph, kept', (t) async {
      Widget page(double width) => host(
        SizedBox(
          width: 700,
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: 0,
            maxWidth: width,
            child: const Balance(child: Text(words, style: style)),
          ),
        ),
      );
      await t.pumpWidget(page(180));
      expect(shown(t), contains('\n'));
      await t.pumpWidget(page(double.infinity));
      expect(shown(t), words);
    });
  });

  testWidgets('a text scaler changed under it re-breaks it', (t) async {
    Widget page(double scale, Key key) => host(
      SizedBox(
        width: 180,
        child: Balance(
          key: key,
          child: const Text(words, style: style),
        ),
      ),
      scale: scale,
    );
    await t.pumpWidget(page(1, const ValueKey('kept')));
    await t.pumpWidget(page(2, const ValueKey('kept')));
    final keptText = shown(t);
    final keptSize = t.getSize(find.byType(Balance));
    await t.pumpWidget(page(2, const ValueKey('fresh')));
    expect(keptSize, t.getSize(find.byType(Balance)));
    expect(keptText, shown(t));
    expect(keptSize.height, greedy(words, 180, s: const TextStyle(fontSize: 20)));
  });

  testWidgets('a box between that may answer otherwise leaves the paragraph greedy', (t) async {
    // A `ConstrainedBox` answers for itself, so no copy of it can be asked
    // about other breaks: the paragraph is left as Skia breaks it, and
    // asked dry it answers what it lays out.
    final box = Balance(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 1),
        child: const Text(words, style: style),
      ),
    );
    await t.pumpWidget(host(SizedBox(width: 180, child: box)));
    expect(shown(t), words);
    final r = t.renderObject<RenderBox>(find.byWidget(box));
    expect(r.getDryLayout(const BoxConstraints(maxWidth: 180)), r.size);
    expect(r.getDryLayout(const BoxConstraints(maxWidth: 700)).height, 10);
  });

  testWidgets('a semantics label between is passed through', (t) async {
    // `Text` puts its own `Semantics` over the paragraph where it is given
    // a label; that box answers as the paragraph does, and the paragraph is
    // balanced through it.
    const box = Balance(
      child: Text(words, style: style, semanticsLabel: 'ten words'),
    );
    await t.pumpWidget(host(const SizedBox(width: 180, child: box)));
    expect(shown(t), contains('\n'));
    final r = t.renderObject<RenderBox>(find.byWidget(box));
    expect(r.getDryLayout(const BoxConstraints(maxWidth: 700)).height, 10);
  });
}
