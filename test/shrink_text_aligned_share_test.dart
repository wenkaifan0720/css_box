// A SHRINK-TO-FIT BOX ROUND TEXT THAT FITS ITS CONTENT IS THE TEXT ONLY
// WHERE THE TEXT IS SET FROM ITS START. The box lays its child out tight at
// the child's greatest width where the room is wider (`shrink.dart`,
// `_fit`); the child alone is laid out in the room. A paragraph set from
// its start puts its lines at 0 either way. A line centred or set at its
// end is placed by Skia within the width it is laid out at and moved by
// `TextPainter`'s paint offset (`_computePaintOffsetFraction`), and in a
// line box a tracked line lands up to half its spacing apart from where
// the box would put it: `Treasury` at `letter-spacing: 0.8px`, centred,
// 0.4px (`fixtures/shrink-line-text` n1; a product site's and a Japanese news site's tracked
// centred labels). The lowering frees such a box only round text set from
// its start (`lossy.dart`, `_fitsL`, `_startSetL`).
//
// p1: set from its start -- left, start, justify, left to right -- the box
// and its child alone are one, glyph for glyph and size for size, plain,
// tracked and spaced, bare and in a line box, in a room a hair wider than
// the text and in one far wider.
// NEGATIVE (n1): tracked, centred or set at its end, bare and in a line box;
// and right to left, set from its start, which is its right edge.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:css_box/css_box.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

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
  'spaced': TextStyle(
    fontFamily: 'Fx',
    fontSize: 16,
    wordSpacing: 3,
    leadingDistribution: TextLeadingDistribution.even,
  ),
};
const _key = ValueKey('box');

/// The child the lowerer writes: a paragraph, bare or in a line box.
final Map<String, Widget Function(Text)> _children = {'text': (t) => t, 'line box': (t) => LineBox(child: t)};

double _most(String text, TextStyle style) {
  final p = TextPainter(
    text: TextSpan(text: text, style: style),
    strutStyle: _strut,
    textDirection: TextDirection.ltr,
  )..layout();
  final w = p.maxIntrinsicWidth;
  p.dispose();
  return w;
}

/// The box [w] in [room], at the top left of the screen: its size, and
/// every glyph where the screen has it.
Future<(Size, List<Rect>)> _read(WidgetTester t, Widget w, double room, TextDirection dir) async {
  await t.pumpWidget(
    Directionality(
      textDirection: dir,
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: room),
          child: KeyedSubtree(key: _key, child: w),
        ),
      ),
    ),
  );
  final box = t.renderObject<RenderBox>(find.byKey(_key));
  final p = t.renderObject<RenderParagraph>(find.descendant(of: find.byKey(_key), matching: find.byType(RichText)));
  final n = p.text.toPlainText(includeSemanticsLabels: false).length;
  final at = p.localToGlobal(Offset.zero);
  return (
    box.size,
    [
      for (var i = 0; i < n; i++)
        for (final b in p.getBoxesForSelection(TextSelection(baseOffset: i, extentOffset: i + 1))) b.toRect().shift(at),
    ],
  );
}

/// How far the box round [child] and [child] alone stand apart: the
/// largest distance between two of their glyphs' edges, or their sizes.
Future<double> _apart(WidgetTester t, Widget child, double room, TextDirection dir) async {
  final (boxSize, boxGlyphs) = await _read(t, ShrinkWidth(child: child), room, dir);
  final (size, glyphs) = await _read(t, child, room, dir);
  var worst = math.max((boxSize.width - size.width).abs(), (boxSize.height - size.height).abs());
  for (var i = 0; i < glyphs.length; i++) {
    worst = math.max(worst, (boxGlyphs[i].left - glyphs[i].left).abs());
    worst = math.max(worst, (boxGlyphs[i].right - glyphs[i].right).abs());
    worst = math.max(worst, (boxGlyphs[i].top - glyphs[i].top).abs());
  }
  return worst;
}

void main() {
  setUpAll(() async {
    final bytes = Uint8List.fromList(File('test/fonts/Inter.ttf').readAsBytesSync());
    await (FontLoader('Fx')..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  });

  const texts = ['Treasury', 'Cookie Preferences', 'AI App Building'];
  testWidgets('a shrink-to-fit box round text set from its start is the text (p1)', (t) async {
    var worst = (0.0, '');
    for (final text in texts) {
      for (final MapEntry(key: sn, value: style) in _styles.entries) {
        final most = _most(text, style);
        for (final MapEntry(key: cn, value: child) in _children.entries) {
          for (final align in [null, TextAlign.left, TextAlign.start, TextAlign.justify]) {
            for (final room in [most + 0.5, most + 30]) {
              final d = await _apart(
                t,
                child(Text(text, textAlign: align, style: style, strutStyle: _strut)),
                room,
                TextDirection.ltr,
              );
              if (d > worst.$1) worst = (d, '$text $sn $cn $align in $room');
            }
          }
        }
      }
    }
    expect(worst.$1, lessThan(1e-3), reason: worst.$2);
  });

  testWidgets('NEGATIVE: tracked, centred or set at its end, the box is half the spacing apart (n1)', (t) async {
    // Each spacing, its paragraph laid out tight and in the room: half the
    // spacing apart wherever the line is placed from the room's middle or
    // its end -- right to left, its start is its right edge. Untracked and
    // word-spaced lines land as one, but the lowering does not read the
    // spacing, so it frees the box round neither.
    for (final (sn, half) in [('tracked', 0.4), ('tight', 0.225)]) {
      for (final MapEntry(key: cn, value: child) in _children.entries) {
        for (final (dir, align) in [
          (TextDirection.ltr, TextAlign.center),
          (TextDirection.ltr, TextAlign.right),
          (TextDirection.ltr, TextAlign.end),
          (TextDirection.rtl, null),
          (TextDirection.rtl, TextAlign.start),
          (TextDirection.rtl, TextAlign.center),
        ]) {
          final style = _styles[sn]!;
          final d = await _apart(
            t,
            child(Text('Treasury', textAlign: align, style: style, strutStyle: _strut)),
            _most('Treasury', style) + 30,
            dir,
          );
          expect(d, closeTo(half, 1e-3), reason: 'Treasury $sn $cn ${dir.name} $align');
        }
      }
    }
  });
}
