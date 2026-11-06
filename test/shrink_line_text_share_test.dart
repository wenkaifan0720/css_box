// A SHRINK-TO-FIT BOX ROUND A LINE BOX OF TEXT IS THE LINE BOX. A box that
// was not handed a width -- an inline-block, a float, a flex item a column
// does not stretch -- is as wide as min(max(min-content, room),
// max-content) (css-sizing-3 5.1), and css_box's `ShrinkWidth` lays its
// child out tight at that width (`shrink.dart`, `_fit`, `_inner`). A line
// box round a paragraph of text comes to the same width by itself: in a
// room wider than its words it is the paragraph, `clamp(greatest, minWidth,
// maxWidth)` wide (`TextPainter._contentWidthFor`), and in a room under its
// longest word it widens the room to that word and hangs out of it whole
// (`linebox.dart`, `_room`, `_lineFloor`; `overflow-wrap: normal`,
// css-text-3 5.5) -- as the box does where it spills (`spill: true`), laid
// out at its child's least width, which a line box answers with the same
// floor (`computeMinIntrinsicWidth`). The lowerer writes the pair as the
// line box: a news site's footer links, a sports shop's caption settings,
// a product site's footer links and its chips in a `Wrap` in an inline-block on
// the line of a heading (`fixtures/shrink-line-text` p1, p2).
//
// This pins the two side by side, keyed: the box's size and place, every
// glyph, the baseline laid out and css_box's walk to the last one, the
// least and greatest widths at no height and at one, the heights asked at
// widths from nothing past the text, the dry layout, the dry baseline and
// the dry walk to the last one -- tight, loose, floored, held to a height
// and unbounded, in rooms from nothing past the text, for a word, words and
// a word broken at a zero width space, plain and tracked, set from the
// start. And the chips: a heading's line laid out round them at every
// width, and asked its widths, the same with the boxes as without.
//
// NEGATIVE: a line box that keeps no word whole (`keepWords: false`) lays
// its paragraph out in the room and breaks the word; a paragraph holding
// an inline widget, which the line box floors at its text alone
// (`_textFloor`) and the box at its least with the widget; a tracked line
// centred or set at its end in a room wider than it, which Skia places
// within the room the line box is laid out in and within the text's width
// where the box lays it out tight (n1); right to left, a word set at its
// left in a room under it, which the box hangs from its right edge.
import 'dart:io';
import 'dart:typed_data';

import 'package:css_box/css_box.dart';
import 'package:css_box/src/dry.dart' show dryLastBaselineOf;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The news site's footer link as the lowerer writes it: 16px Inter on a
/// 24px line, and the same tracked out and in.
const _strut = StrutStyle(
  fontFamily: 'Fx',
  fontSize: 14.0234,
  height: 24 / 14.0234,
  leading: 0,
  leadingDistribution: TextLeadingDistribution.even,
  forceStrutHeight: true,
);
const _styles = {
  'plain': TextStyle(fontFamily: 'Fx', fontSize: 16, leadingDistribution: TextLeadingDistribution.even),
  'tracked': TextStyle(
    fontFamily: 'Fx',
    fontSize: 16,
    letterSpacing: 0.8,
    leadingDistribution: TextLeadingDistribution.even,
  ),
  'tight': TextStyle(
    fontFamily: 'Fx',
    fontSize: 16,
    letterSpacing: -0.45,
    leadingDistribution: TextLeadingDistribution.even,
  ),
};

const _key = ValueKey('box');

/// css_box's walk to the last line's baseline, laid out, starts here
/// (`baseline.dart`, `RenderLastBaseline.lastBaselineOf`).
const _walk = ValueKey('walk');

Text _text(String text, TextStyle style, TextAlign? align) =>
    Text(text, textAlign: align, style: style, strutStyle: _strut);

/// The two line boxes the lowerer writes round a label: bare, and told
/// the line's height and ascent.
final Map<String, Widget Function(Text, Key?)> _lines = {
  'bare': (t, key) => LineBox(key: key, child: t),
  'set': (t, key) => LineBox(key: key, lineHeight: 24, ascent: 18, child: t),
};

/// The shrink-to-fit boxes the lowerer writes round one.
final Map<String, Widget Function(Widget)> _shrinks = {
  'fit': (c) => ShrinkWidth(key: _key, child: c),
  'spill': (c) => ShrinkWidth(key: _key, spill: true, child: c),
  'spill from the start': (c) => ShrinkWidth(key: _key, spill: true, spillAlign: -1, child: c),
  'spill at its height': (c) => ShrinkWidth(key: _key, spill: true, atHeight: true, child: c),
  'at its height': (c) => ShrinkWidth(key: _key, atHeight: true, child: c),
};

/// The paragraph's least and greatest widths.
(double, double) _widths(String text, TextStyle style) {
  final p = TextPainter(
    text: TextSpan(text: text, style: style),
    strutStyle: _strut,
    textDirection: TextDirection.ltr,
  )..layout();
  final out = (p.minIntrinsicWidth, p.maxIntrinsicWidth);
  p.dispose();
  return out;
}

/// [child] handed [c] at the top left of the screen; with no bound across
/// where [c] has none.
Widget _host(BoxConstraints c, Widget child, {TextDirection direction = TextDirection.ltr}) => Directionality(
  textDirection: direction,
  child: Align(
    alignment: Alignment.topLeft,
    child: c.hasBoundedWidth
        ? ConstrainedBox(constraints: c, child: child)
        : OverflowBox(minWidth: 0, maxWidth: double.infinity, alignment: Alignment.topLeft, child: child),
  ),
);

/// Every glyph of [p], where the screen has it.
List<Rect> _glyphs(RenderParagraph p) {
  final n = p.text.toPlainText(includeSemanticsLabels: false).length;
  final at = p.localToGlobal(Offset.zero);
  return [
    for (var i = 0; i < n; i++)
      for (final b in p.getBoxesForSelection(TextSelection(baseOffset: i, extentOffset: i + 1))) b.toRect().shift(at),
  ];
}

/// Everything a parent or the page reads of the keyed box handed [c], by
/// name.
Future<Map<String, Object?>> _read(
  WidgetTester t,
  Widget box,
  BoxConstraints c,
  double least,
  double most, {
  TextDirection direction = TextDirection.ltr,
}) async {
  await t.pumpWidget(
    _host(
      c,
      LastBaseline(key: _walk, child: box),
      direction: direction,
    ),
  );
  final r = t.renderObject<RenderBox>(find.byKey(_key));
  final p = t.renderObject<RenderParagraph>(find.descendant(of: find.byKey(_key), matching: find.byType(RichText)));
  final dry = c.hasBoundedWidth ? c : BoxConstraints(minHeight: c.minHeight, maxHeight: c.maxHeight);
  return {
    'size': r.size,
    'at': r.localToGlobal(Offset.zero),
    'glyphs': _glyphs(p),
    'baseline': _asked(() => r.getDistanceToBaseline(TextBaseline.alphabetic)),
    'last baseline': _asked(
      () => t.renderObject<RenderBox>(find.byKey(_walk)).getDistanceToBaseline(TextBaseline.alphabetic),
    ),
    for (final h in [double.infinity, 40.0]) ...{
      'least at height $h': r.getMinIntrinsicWidth(h),
      'most at height $h': r.getMaxIntrinsicWidth(h),
    },
    for (final w in [0.0, least / 2, least, (least + most) / 2, most, most + 10, double.infinity]) ...{
      'least height at $w': r.getMinIntrinsicHeight(w),
      'most height at $w': r.getMaxIntrinsicHeight(w),
    },
    'dry': r.getDryLayout(dry),
    'dry baseline': _asked(() => r.getDryBaseline(dry, TextBaseline.alphabetic)),
    'dry last baseline': _asked(() => dryLastBaselineOf(r, dry, TextBaseline.alphabetic)),
  };
}

/// [ask] of a box laid out, as a box above it would ask it: the framework
/// asserts a box is not asked its baseline outside a layout.
T _asked<T>(T Function() ask) {
  final was = RenderObject.debugCheckingIntrinsics;
  RenderObject.debugCheckingIntrinsics = true;
  try {
    return ask();
  } finally {
    RenderObject.debugCheckingIntrinsics = was;
  }
}

/// The first reading the two answer differently, or null.
String? _apart(Map<String, Object?> a, Map<String, Object?> b) {
  for (final k in a.keys) {
    final x = a[k], y = b[k];
    if (x is List && y is List ? !listEquals(x, y) : x != y) return '$k: $x (box) vs $y (line box)';
  }
  return null;
}

/// Each room a label is laid out in: tight, loose, floored at half of it
/// and held to a height, and no bound at all past the text.
List<BoxConstraints> _rooms(double least, double most) => [
  for (final room in [0.0, least / 2, least - 0.5, least, (least + most) / 2, most, most + 0.5, 400.0]) ...[
    BoxConstraints.tightFor(width: room),
    BoxConstraints(maxWidth: room),
    BoxConstraints(minWidth: room / 2, maxWidth: room),
    BoxConstraints(maxWidth: room, minHeight: 40, maxHeight: 40),
  ],
  const BoxConstraints(),
  const BoxConstraints(minHeight: 40, maxHeight: 40),
];

/// The product site's heading: a line of 24px text on a 30px line, an inline-block
/// on it of chips in a `Wrap`, each chip's label a line box in a
/// shrink-to-fit box where [shrink], or the line box alone.
Widget _heading(bool shrink) {
  const chip = TextStyle(fontFamily: 'Fx', fontSize: 16, leadingDistribution: TextLeadingDistribution.even);
  const strut = StrutStyle(fontFamily: 'Fx', fontSize: 16, height: 21.59375 / 16, leading: 0, forceStrutHeight: true);
  Widget label(String text) {
    final line = LineBox(
      key: ValueKey(text),
      lineHeight: 21.59375,
      ascent: 17,
      child: Text(text, style: chip, strutStyle: strut),
    );
    return shrink ? ShrinkWidth(child: line) : line;
  }

  return LineBox(
    key: _key,
    lineHeight: 30,
    ascent: 22,
    child: Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Build with '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [for (final c in _chips) label(c)]),
            ),
          ),
          const TextSpan(text: ' today'),
        ],
      ),
      style: const TextStyle(fontFamily: 'Fx', fontSize: 24, leadingDistribution: TextLeadingDistribution.even),
      strutStyle: const StrutStyle(fontFamily: 'Fx', fontSize: 24, height: 30 / 24, leading: 0, forceStrutHeight: true),
    ),
  );
}

const _chips = ['AI App Building', 'AI Agents', 'Product Ops'];

void main() {
  setUpAll(() async {
    final bytes = Uint8List.fromList(File('test/fonts/Inter.ttf').readAsBytesSync());
    await (FontLoader('Fx')..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  });

  const texts = ['Treasury', 'Cookie Preferences', 'E-​paper'];
  const aligns = [null, TextAlign.left, TextAlign.start, TextAlign.justify];
  for (final MapEntry(key: name, value: style) in _styles.entries) {
    testWidgets('a shrink-to-fit box round a line box of text, set from its start, is the line box ($name)', (t) async {
      var cases = 0;
      for (final text in texts) {
        final (least, most) = _widths(text, style);
        for (final MapEntry(key: lineName, value: line) in _lines.entries) {
          for (final MapEntry(key: shrinkName, value: shrink) in _shrinks.entries) {
            for (final c in _rooms(least, most)) {
              for (final align in aligns) {
                final box = await _read(t, shrink(line(_text(text, style, align), null)), c, least, most);
                final alone = await _read(t, line(_text(text, style, align), _key), c, least, most);
                expect(_apart(box, alone), isNull, reason: '$text, $lineName, $shrinkName, in $c, $align');
                cases++;
              }
            }
          }
        }
      }
      expect(cases, 3 * 2 * 5 * (8 * 4 + 2) * 4);
    });
  }

  testWidgets("the product site's chips: a heading's line round them is the same with the boxes as without (p1)", (
    t,
  ) async {
    for (final w in [0.0, 60.0, 120.0, 200.0, 320.0, 480.0, 800.0]) {
      for (final c in [BoxConstraints.tightFor(width: w), BoxConstraints(maxWidth: w)]) {
        final seen = <Map<String, Object?>>[];
        for (final shrink in [true, false]) {
          await t.pumpWidget(_host(c, _heading(shrink)));
          final r = t.renderObject<RenderBox>(find.byKey(_key));
          final p = t.renderObject<RenderParagraph>(
            find.descendant(of: find.byKey(_key), matching: find.byType(RichText)).first,
          );
          seen.add({
            'size': r.size,
            'line': _glyphs(p),
            for (final chip in _chips) ...{
              '$chip box': t.getRect(find.byKey(ValueKey(chip))),
              '$chip glyphs': _glyphs(
                t.renderObject<RenderParagraph>(
                  find.descendant(of: find.byKey(ValueKey(chip)), matching: find.byType(RichText)),
                ),
              ),
            },
            'baseline': _asked(() => r.getDistanceToBaseline(TextBaseline.alphabetic)),
            'least': r.getMinIntrinsicWidth(double.infinity),
            'most': r.getMaxIntrinsicWidth(double.infinity),
            'least height': r.getMinIntrinsicHeight(w),
            'most height': r.getMaxIntrinsicHeight(w),
            'dry': r.getDryLayout(c),
            'dry baseline': _asked(() => r.getDryBaseline(c, TextBaseline.alphabetic)),
          });
        }
        expect(_apart(seen[0], seen[1]), isNull, reason: '$c');
      }
    }
  });

  testWidgets(
    'NEGATIVE: words not kept whole, an inline widget, a tracked line centred or at its end, right to left (n1, n2)',
    (t) async {
      final style = _styles['plain']!;
      // A line box that keeps no word whole lays `Treasury` out in a room
      // under it, and Skia breaks the word into three lines; the spilling
      // box lays it out at its least, whole, on one.
      const word = 'Treasury';
      final (least, most) = _widths(word, style);
      final c = BoxConstraints(maxWidth: least / 2);
      final kept = await _read(
        t,
        ShrinkWidth(
          key: _key,
          spill: true,
          child: LineBox(keepWords: false, child: _text(word, style, null)),
        ),
        c,
        least,
        most,
      );
      final broken = await _read(
        t,
        LineBox(key: _key, keepWords: false, child: _text(word, style, null)),
        c,
        least,
        most,
      );
      expect((kept['size']! as Size).height, 24);
      expect((broken['size']! as Size).height, 72);
      // A paragraph holding a 100px inline widget after `ab cd`: in a room
      // of 30 the line box, floored at its words alone, breaks them onto two
      // lines over the widget's; the spilling box lays it out at its least
      // with the widget, 100, where the words share a line.
      Widget atom(Key? key) => LineBox(
        key: key,
        child: Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'ab cd '),
              const WidgetSpan(child: SizedBox(width: 100, height: 10)),
            ],
          ),
          style: style,
          strutStyle: _strut,
        ),
      );
      const room = BoxConstraints(maxWidth: 30);
      final shrunk = await _read(t, ShrinkWidth(key: _key, spill: true, child: atom(null)), room, 20, 150);
      final alone = await _read(t, atom(_key), room, 20, 150);
      expect((shrunk['size']! as Size).height, 48);
      expect((alone['size']! as Size).height, 72);
      // A tracked word centred, or set at its end, in a room wider than it,
      // held to the room or not: the box lays the line box out tight at the
      // word's width, where Skia sets the line within that width; alone, the
      // line box is laid out in the room and the line set within it, then
      // moved back by `TextPainter`'s paint offset -- up to half the spacing
      // apart, in boxes of one size.
      final tracked = _styles['tracked']!;
      final (tLeast, tMost) = _widths(word, tracked);
      for (final align in [TextAlign.center, TextAlign.right, TextAlign.end]) {
        for (final c in [BoxConstraints(maxWidth: tMost + 0.5), BoxConstraints(minWidth: 0, maxWidth: tMost + 30)]) {
          final box = await _read(
            t,
            ShrinkWidth(
              key: _key,
              child: LineBox(child: _text(word, tracked, align)),
            ),
            c,
            tLeast,
            tMost,
          );
          final line = await _read(t, LineBox(key: _key, child: _text(word, tracked, align)), c, tLeast, tMost);
          expect(box['size'], line['size'], reason: '$align in $c');
          expect(box['glyphs'], isNot(line['glyphs']), reason: '$align in $c');
        }
      }
      // Right to left, a word set at its left in a room under it: the box
      // hangs the line box, at the word's width, from its right edge -- its
      // start -- where the line box alone sets the word from its left.
      final rtl = BoxConstraints(maxWidth: least / 2);
      final hung = await _read(
        t,
        ShrinkWidth(
          key: _key,
          spill: true,
          child: LineBox(child: _text(word, style, TextAlign.left)),
        ),
        rtl,
        least,
        most,
        direction: TextDirection.rtl,
      );
      final set = await _read(
        t,
        LineBox(key: _key, child: _text(word, style, TextAlign.left)),
        rtl,
        least,
        most,
        direction: TextDirection.rtl,
      );
      expect(hung['size'], set['size']);
      expect(hung['glyphs'], isNot(set['glyphs']));
    },
  );
}
