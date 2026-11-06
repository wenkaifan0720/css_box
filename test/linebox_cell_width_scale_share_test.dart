// A LINE BOX IN A GRID CELL OF A LENGTH, OR UNDER A SCALE, IS ITS PARAGRAPH
// WHERE ITS WIDEST WORD FITS THE ROOM. The line box widens its paragraph
// only to keep a word whole that is wider than its room (`linebox.dart`,
// `_room`; `overflow-wrap: normal`, css-text-3 5.5). A grid item of a
// stated width is laid out at that width, clamped, wherever the grid puts
// it -- only an `auto` width is stretched over its area (css-grid-1 6.2,
// css-align-3 6.1; css_box `tracks.dart`, `_position`) -- and a
// `Transform.scale` lays its child out under the constraints it is handed
// and only paints it scaled (`RenderTransform` is a `RenderProxyBox`;
// css-transforms-1 3). The stock pass reads both (`tidy.dart`,
// `_trackRoom`, `_roomTo`): a product site's phone carousel, cards of `width:
// 328px` down a grid's columns, and its product previews, a 1200px screen
// at half size, and a sports shop's button scaled to half in a box as wide as its
// content (a scale answers its child's intrinsics). This pins the two
// spellings to the same boxes -- the paragraph and a box after it -- at
// widths where the word fits the room (fixtures/grid-cell-own-width p1, p2;
// fixtures/scaled-preview-room p1, p2).
// NEGATIVE: a cell half its area wide, and a scaled box narrower than the
// word, where the line box keeps it whole and the paragraph breaks it
// (grid-cell-own-width n1, scaled-preview-room n1).
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:css_box/css_box.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

TextStyle _fx(double size, [double? lh]) => TextStyle(
  fontFamily: 'Fx',
  fontSize: size,
  height: lh == null ? null : lh / size,
  leadingDistribution: TextLeadingDistribution.even,
);

const _words = 'Purpose-built for incomprehensible planning';

/// The paragraph as css_box lays it out ([told]), in a line box that keeps
/// its words whole, or as the stock pass writes it.
Widget _spelled({required bool told}) {
  final text = Text(_words, key: const ValueKey('a'), style: _fx(16, 24));
  return told ? LineBox(child: text) : text;
}

const _after = SizedBox(key: ValueKey('after'), height: 5);

/// A shape round the paragraph, and the least page width it is laid out
/// at: where the room it gives comes down with the page, the word fits it
/// only above that.
typedef _Shape = ({String name, double least, Widget Function(Widget) hold});

/// [s] round the paragraph in [width], a box after it.
Widget _page(_Shape s, double width, {required bool told}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          s.hold(_spelled(told: told)),
          _after,
        ],
      ),
    ),
  ),
);

/// How far apart the two spellings put anything, and what is furthest
/// apart.
Future<(double, String)> _apart(WidgetTester t, _Shape s, double width) async {
  final got = <bool, Map<String, double>>{};
  for (final told in [true, false]) {
    await t.pumpWidget(_page(s, width, told: told));
    t.takeException();
    got[told] = {
      for (final k in ['a', 'after']) ...{
        '$k.left': t.getRect(find.byKey(ValueKey(k))).left,
        '$k.top': t.getRect(find.byKey(ValueKey(k))).top,
        '$k.right': t.getRect(find.byKey(ValueKey(k))).right,
        '$k.bottom': t.getRect(find.byKey(ValueKey(k))).bottom,
      },
    };
  }
  var worst = (0.0, '');
  for (final k in got[true]!.keys) {
    final d = (got[true]![k]! - got[false]![k]!).abs();
    if (d > worst.$1) worst = (d, '$k: ${got[true]![k]} told, ${got[false]![k]} stock');
  }
  return worst;
}

const _widths = [100.0, 200.0, 320.0, 500.0, 900.0];

void main() {
  setUpAll(() async {
    final bytes = Uint8List.fromList(File('test/fonts/Inter.ttf').readAsBytesSync());
    await (FontLoader('Fx')..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  });

  final exact = <_Shape>[
    // grid-cell-own-width p1: the product site's cards, 328px, down the columns, the
    // heading at the top of a column of the card's content.
    (
      name: 'a cell of a length down the columns',
      least: 0,
      hold: (w) => Tracks(
        flow: TrackFlow.column,
        spacing: 8,
        children: [
          TrackCell(
            width: 328,
            height: 120,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [w],
            ),
          ),
          const TrackCell(width: 328, height: 120, child: SizedBox.shrink()),
        ],
      ),
    ),
    // grid-cell-own-width p2: a cell of 200px in the first of two `1fr`
    // columns.
    (
      name: 'a cell of a length in a flexible column',
      least: 0,
      hold: (w) => Tracks(
        columns: const [TrackSize.flex(1), TrackSize.flex(1)],
        children: [TrackCell(width: 200, child: w)],
      ),
    ),
    // scaled-preview-room p2: a 240px button at half size, in a box as wide
    // as its content.
    (
      name: 'a box of a length at half size, in a box as wide as its content',
      // As wide as the page under 240: the word fits from 200 up.
      least: 200,
      hold: (w) => Align(
        alignment: Alignment.topLeft,
        child: IntrinsicWidth(
          child: Transform.scale(
            scale: 0.5,
            alignment: Alignment.topLeft,
            child: SizedBox(width: 240, child: w),
          ),
        ),
      ),
    ),
    // scaled-preview-room p1: a 1200px screen at half size.
    (
      name: 'a screen of a length at half size',
      least: 0,
      hold: (w) => Transform.scale(
        scale: 0.5,
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1200, maxWidth: 1200),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 240, child: w),
              const Expanded(child: SizedBox(height: 10)),
            ],
          ),
        ),
      ),
    ),
  ];

  for (final s in exact) {
    testWidgets('where the word fits the room, the paragraph is the line box (${s.name})', (t) async {
      for (final width in _widths.where((w) => w >= s.least)) {
        final (d, at) = await _apart(t, s, width);
        expect(d, lessThan(1e-3), reason: '${s.name} at $width, $at');
      }
    });
  }

  for (final s in <_Shape>[
    // grid-cell-own-width n1: a cell half its area wide.
    (
      name: 'a cell half its area wide',
      least: 0,
      hold: (w) => Tracks(
        columns: const [TrackSize.flex(1)],
        children: [TrackCell(widthFraction: 0.5, child: w)],
      ),
    ),
    // scaled-preview-room n1: a scaled box narrower than the word.
    (
      name: 'a scaled box narrower than the word',
      least: 0,
      hold: (w) => Transform.scale(
        scale: 0.5,
        alignment: Alignment.topLeft,
        child: SizedBox(width: 60, child: w),
      ),
    ),
  ]) {
    testWidgets('NEGATIVE: a room under the word (${s.name})', (t) async {
      var worst = 0.0;
      for (final width in _widths) {
        worst = math.max(worst, (await _apart(t, s, width)).$1);
      }
      expect(worst, greaterThan(10));
    });
  }
}
