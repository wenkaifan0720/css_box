// A WORD NO LINE BREAKS INSIDE IS ONE LINE IN ANY ROOM. Letters and digits
// side by side give a line no place to break (UAX #14 LB28, LB23, LB25),
// nor does a full stop or a question mark after them (LB13), and CSS hangs
// such a word out of a line narrower than it, whole and at its start
// (`overflow-wrap: normal`, css-text-3 5.5, 7.1). css_box's `LineBox` keeps
// it whole by laying its paragraph out at the word's width; the lowerer
// writes the paragraph as a `Text` that never wraps, painted past its box
// (`lossy.dart`, `_unbrokenWordL`): a banking site's footer links, a product site's customer
// names, a price-table site's `U` badge (fixtures/linebox-one-word p1, p2).
//
// This pins the two side by side, keyed: the box's size and place, the
// word's glyphs, the baseline, the least and greatest widths, the heights
// asked at every width, the dry layout and dry baseline, and that nothing
// is clipped -- tight, loose, floored and unbounded, in rooms from nothing
// to past the word, set from the start, tracked and not. NEGATIVE: two
// words, which the line box breaks in a room under them (n1); a tracked
// word centred or set at its end in a room wider than it, which Skia
// places within the room the line box lays the paragraph out in and
// `TextPainter` shifts from the word's own width, up to half the spacing
// apart (n1's `Q4`); a right-to-left line, which the line box sets against
// its right edge.
import 'dart:io';
import 'dart:typed_data';

import 'package:css_box/css_box.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The banking site's footer link as the lowerer writes it: 16px Inter on a 24px
/// line, and the same tracked out and in.
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

/// The paragraph as the line box holds it.
Widget _lineBox(String word, TextStyle style, TextAlign? align) => LineBox(
  key: _key,
  child: Text(word, textAlign: align, style: style, strutStyle: _strut),
);

/// The paragraph as the lowerer writes it.
Widget _stock(String word, TextStyle style, TextAlign? align) => Text(
  word,
  key: _key,
  softWrap: false,
  overflow: TextOverflow.visible,
  textAlign: align,
  style: style,
  strutStyle: _strut,
);

double _width(String word, TextStyle style) {
  final p = TextPainter(
    text: TextSpan(text: word, style: style),
    strutStyle: _strut,
    textDirection: TextDirection.ltr,
  )..layout();
  final w = p.maxIntrinsicWidth;
  p.dispose();
  return w;
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

/// Everything a parent or the page reads of the keyed box handed [c], by
/// name.
Future<Map<String, Object>> _read(
  WidgetTester t,
  Widget box,
  BoxConstraints c,
  String word,
  double w, {
  TextDirection direction = TextDirection.ltr,
}) async {
  await t.pumpWidget(_host(c, box, direction: direction));
  final r = t.renderObject<RenderBox>(find.byKey(_key));
  final p = t.renderObject<RenderParagraph>(find.descendant(of: find.byKey(_key), matching: find.byType(RichText)));
  final glyphs = p.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: word.length));
  var ink = glyphs.first.toRect();
  for (final g in glyphs.skip(1)) {
    ink = ink.expandToInclude(g.toRect());
  }
  final dry = c.hasBoundedWidth ? c : const BoxConstraints();
  return {
    'size': r.size,
    'at': r.localToGlobal(Offset.zero),
    'glyphs': ink.shift(p.localToGlobal(Offset.zero)),
    'lines': (p.size.height / 24).round(),
    'baseline': _asked(() => r.getDistanceToBaseline(TextBaseline.alphabetic)!),
    'least': r.getMinIntrinsicWidth(double.infinity),
    'most': r.getMaxIntrinsicWidth(double.infinity),
    for (final at in [0.0, w / 2, w - 1, w, w + 10, double.infinity]) ...{
      'least height at $at': r.getMinIntrinsicHeight(at),
      'most height at $at': r.getMaxIntrinsicHeight(at),
    },
    'dry': r.getDryLayout(dry),
    'dry baseline': _asked(() => r.getDryBaseline(dry, TextBaseline.alphabetic) ?? -1),
    'clips': !paintsExactlyCountTimes(#clipRect, 0).matches(p, <dynamic, dynamic>{}),
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
String? _apart(Map<String, Object> a, Map<String, Object> b) {
  for (final k in a.keys) {
    if (a[k] != b[k]) return '$k: ${a[k]} (line box) vs ${b[k]} (stock)';
  }
  return null;
}

void main() {
  setUpAll(() async {
    final bytes = Uint8List.fromList(File('test/fonts/Inter.ttf').readAsBytesSync());
    await (FontLoader('Fx')..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  });

  const words = ['Treasury', 'Nimbus', 'U', 'Thinking.', 'uwu?', '2026', 'Q4'];
  const aligns = [null, TextAlign.left, TextAlign.start, TextAlign.justify];
  for (final MapEntry(key: name, value: style) in _styles.entries) {
    testWidgets('a line box round one word no line breaks inside is a Text that never wraps ($name)', (t) async {
      var cases = 0;
      for (final word in words) {
        final w = _width(word, style);
        for (final room in [0.0, w / 3, w - 1, w - 0.01, w, w + 0.01, w + 0.5, w + 30, 400.0]) {
          final constraints = [
            BoxConstraints.tightFor(width: room),
            BoxConstraints(maxWidth: room),
            BoxConstraints(minWidth: room / 2, maxWidth: room),
            if (room == 400) const BoxConstraints(),
          ];
          for (final c in constraints) {
            for (final align in aligns) {
              final box = await _read(t, _lineBox(word, style, align), c, word, w);
              final text = await _read(t, _stock(word, style, align), c, word, w);
              expect(_apart(box, text), isNull, reason: '$word in $c, $align');
              expect(text['lines'], 1);
              expect(text['clips'], false);
              cases++;
            }
          }
        }
      }
      expect(cases, 7 * (8 * 3 + 4) * 4);
    });
  }

  testWidgets('NEGATIVE: two words, a word centred or set at its end, a right-to-left line (n1)', (t) async {
    final style = _styles['plain']!;
    // The line box breaks `Open Account` at its space in a room under the
    // whole line and over its longest word: two lines where the `Text`
    // keeps one.
    const words = 'Open Account';
    final under = _width(words, style) - 1;
    final two = await _read(t, _lineBox(words, style, null), BoxConstraints(maxWidth: under), words, under);
    final one = await _read(t, _stock(words, style, null), BoxConstraints(maxWidth: under), words, under);
    expect(two['lines'], 2);
    expect(one['lines'], 1);
    // A tracked word centred, or set at the end, in a room wider than it,
    // held to the room or not: Skia places the line within the room the line
    // box lays its paragraph out in, `TextPainter` shifts the line that
    // never wraps from the word's own width, and the two land up to half
    // the spacing apart -- in a box of the same size.
    final tracked = _styles['tracked']!;
    const word = 'Treasury';
    final w = _width(word, tracked);
    for (final align in [TextAlign.center, TextAlign.right, TextAlign.end]) {
      for (final c in [BoxConstraints.tightFor(width: w + 0.5), BoxConstraints(maxWidth: w + 0.5)]) {
        final box = await _read(t, _lineBox(word, tracked, align), c, word, w);
        final text = await _read(t, _stock(word, tracked, align), c, word, w);
        expect(box['size'], text['size'], reason: '$align in $c');
        expect(box['glyphs'], isNot(text['glyphs']), reason: '$align in $c');
      }
    }
    // Right to left, the line box sets the word it widened past the box
    // against the box's right edge; the `Text` hangs it out of the end.
    final room = _width(word, style) - 20;
    final c = BoxConstraints.tightFor(width: room);
    final box = await _read(t, _lineBox(word, style, null), c, word, room, direction: TextDirection.rtl);
    final text = await _read(t, _stock(word, style, null), c, word, room, direction: TextDirection.rtl);
    expect(box['size'], text['size']);
    expect(box['glyphs'], isNot(text['glyphs']));
  });
}
