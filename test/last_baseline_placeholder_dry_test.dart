// A paragraph with a box on its lines, asked its LAST baseline before it is
// laid out, answers the baseline of its last line (CSS 2.1 10.8.1: an
// inline-block stands on its parent's line by its last line's baseline).
//
// The shape: a card's text column under an `IntrinsicHeight` row -- which
// measures everything under it dry -- holds a byline `inline-block` of
// 16px on 1.1 lines, stood on the column's 24px strut line by its last
// baseline, and the byline ends in a comments link that is a box of its
// own. Flutter keeps a box's dry and laid-out baselines in one cache, so
// what the dry pass answered is what the row laid out stands on.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:css_box/css_box.dart';
import 'package:css_box/src/dry.dart' show dryBaselineOf, dryLastBaselineOf;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _small = TextStyle(fontFamily: 'Inter', fontSize: 11, height: 1.2);
const _strut = StrutStyle(fontFamily: 'Inter', fontSize: 16, height: 1.1, forceStrutHeight: true);

/// A byline whose words come in several sizes keeps its strut as a floor
/// only: the lines are the painter's either way.
const _floor = StrutStyle(fontFamily: 'Inter', fontSize: 16, height: 1.1);

/// The comments link: a line box of its own, an icon and a count.
Widget _comments() => LineBox(
  keepWords: false,
  lineHeight: 17.59375,
  ascent: 14,
  child: Text.rich(
    const TextSpan(
      children: [
        WidgetSpan(child: SizedBox(width: 16, height: 12), alignment: PlaceholderAlignment.middle),
        TextSpan(text: '1', style: _small),
      ],
    ),
    softWrap: false,
    strutStyle: _strut,
  ),
);

/// The byline: [words], then the link where [link] says.
Widget _byline(String words, {required bool link, StrutStyle strut = _strut}) => Padding(
  padding: const EdgeInsets.only(top: 6),
  child: LastBaseline(
    child: IntrinsicWidth(
      child: LineBox(
        lineHeight: 17.59375,
        ascent: 14,
        child: Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: '⁠'),
              TextSpan(text: words, style: _small),
              if (link) ...[
                edgeSpan(12),
                WidgetSpan(
                  child: _comments(),
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                ),
              ],
              const TextSpan(text: '⁠'),
            ],
          ),
          strutStyle: strut,
        ),
      ),
    ),
  ),
);

/// The byline on the column's 24px line, its strut 18 over 6.
Widget _line(Widget byline) => Row(
  key: const Key('line'),
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.baseline,
  textBaseline: TextBaseline.alphabetic,
  children: [
    const SizedBox(
      width: 0,
      height: 24,
      child: Baseline(baseline: 18, baselineType: TextBaseline.alphabetic, child: Text('')),
    ),
    Flexible(child: byline),
  ],
);

/// The line in a 267px column, under a card's `IntrinsicHeight` row where
/// [card] says, and laid out plainly where it does not.
Widget _page(Widget byline, {required bool card}) {
  final column = Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [const SizedBox(height: 54), _line(byline)],
  );
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: card
          ? SizedBox(
              width: 358,
              child: IntrinsicHeight(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  textDirection: TextDirection.rtl,
                  children: [
                    const SizedBox(width: 91, height: 75),
                    Expanded(child: column),
                  ],
                ),
              ),
            )
          : SizedBox(width: 267, child: column),
    ),
  );
}

Future<double> _lineHeight(WidgetTester t, Widget byline, {required bool card}) async {
  await t.pumpWidget(_page(byline, card: card));
  return t.getSize(find.byKey(const Key('line'))).height;
}

/// Where the byline's lines stand: the number of them.
int _lines(WidgetTester t) {
  final p = t.renderObject<RenderParagraph>(
    find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('\u2060')).first,
  );
  final text = p.text.toPlainText(includeSemanticsLabels: false);
  return p
      .getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: text.length),
        boxHeightStyle: ui.BoxHeightStyle.strut,
      )
      .map((b) => b.top.round())
      .toSet()
      .length;
}

const _two = 'ANTONIO G. DI BENEDETTO, SEAN HOLLISTER and 1 MORE';
const _one = 'TOM WARREN';
const _three = 'ANTONIO G. DI BENEDETTO, SEAN HOLLISTER, TOM WARREN, EMMA ROTH, CAMERON FAULKNER and 1 MORE';

void main() {
  setUpAll(() async {
    final bytes = File('test/fonts/Inter.ttf').readAsBytesSync();
    await (FontLoader('Inter')..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)))).load();
  });

  group('a paragraph with a box on its lines answers its last line dry', () {
    // p1: two lines ending in the link. Before: the card's line stood on
    // the first line, 41.19 tall where the line laid out plainly is 43.59.
    testWidgets('p1: two lines and a link -- the card measures the line it lays out', (t) async {
      final plain = await _lineHeight(t, _byline(_two, link: true), card: false);
      expect(_lines(t), 2);
      final carded = await _lineHeight(t, _byline(_two, link: true), card: true);
      expect(_lines(t), 2);
      // 6 + the last line's baseline over the strut's 6 of descent: two
      // 17.59375px lines, the last 14 over its baseline, as CSS stacks
      // them -- not as Skia does, 18 apart.
      expect(plain, closeTo(6 + 17.59375 + 14 + 6, 0.01));
      expect(carded, closeTo(plain, 0.01));
    });

    // NEGATIVE n1: one line with the link -- its last baseline is its
    // first, and the line is what it was.
    testWidgets('n1: one line and a link stands on its one line', (t) async {
      final plain = await _lineHeight(t, _byline(_one, link: true), card: false);
      expect(_lines(t), 1);
      final carded = await _lineHeight(t, _byline(_one, link: true), card: true);
      expect(carded, closeTo(plain, 0.01));
      // 6 + 14 + 6. Before: 25.6, the line stood on the paragraph's own
      // baseline put back by the drop, where Skia draws the line 18 tall
      // a fraction under the one it answers.
      expect(plain, closeTo(26, 0.01));
    });

    // p2: the same with a strut that does not force the lines. Before: the
    // dry pass answered the first line whenever the strut did not force.
    testWidgets('p2: two lines and a link under a strut that does not force', (t) async {
      final plain = await _lineHeight(t, _byline(_two, link: true, strut: _floor), card: false);
      expect(_lines(t), 2);
      final carded = await _lineHeight(t, _byline(_two, link: true, strut: _floor), card: true);
      expect(_lines(t), 2);
      expect(plain, greaterThan(40));
      expect(carded, closeTo(plain, 0.01));
    });

    // p3: three lines and a link. Before: 0.4 low, the lines read at
    // Skia's pitch, 18 apart.
    testWidgets('p3: three lines and a link stand on the third at the pitch CSS gives them', (t) async {
      final plain = await _lineHeight(t, _byline(_three, link: true), card: false);
      expect(_lines(t), 3);
      final carded = await _lineHeight(t, _byline(_three, link: true), card: true);
      expect(carded, closeTo(plain, 0.01));
      expect(plain, closeTo(6 + 2 * 17.59375 + 14 + 6, 0.01));
    });

    // NEGATIVE n3: one line and a link under that strut -- its last
    // baseline, asked dry, is its first, as before.
    testWidgets('n3: one line and a link under a strut that does not force answers its first', (t) async {
      await _lineHeight(t, _byline(_one, link: true, strut: _floor), card: false);
      expect(_lines(t), 1);
      final p = t.renderObject<RenderParagraph>(
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('\u2060')).first,
      );
      const room = BoxConstraints(maxWidth: 267);
      final first = dryBaselineOf(p, room, TextBaseline.alphabetic);
      expect(first, isNotNull);
      expect(dryLastBaselineOf(p, room, TextBaseline.alphabetic), first);
    });

    // NEGATIVE n2: two lines with no box -- counted off the strut, as before.
    testWidgets('n2: two lines with no box are counted as before', (t) async {
      final plain = await _lineHeight(t, _byline(_two, link: false), card: false);
      final carded = await _lineHeight(t, _byline(_two, link: false), card: true);
      expect(carded, closeTo(plain, 0.01));
    });
  });
}
