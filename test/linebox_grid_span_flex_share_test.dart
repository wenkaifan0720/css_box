// A LINE BOX IN A CELL ACROSS EVERY COLUMN OF A GRID HELD TO ITS WIDTH,
// ONE OF THEM FLEXIBLE, IS ITS PARAGRAPH. The line box widens its
// paragraph only to keep a word whole that is wider than its room
// (`linebox.dart`, `_room`; `overflow-wrap: normal`, css-text-3 5.5), and
// such a cell is never narrower than the grid: the flexible columns share
// out all the room the others and the gaps leave, a column whose base is
// more than its share keeping its base (css-grid-1 11.7, 11.7.1; css_box
// `tracks.dart`, `_expandFlexible`, `_frSize`), so where every factor is 1
// or more the columns and the gaps come to the grid's width -- or more,
// where their bases and the gaps already pass it. The stock pass writes the
// paragraph there where its widest word fits the grid (`tidy.dart`,
// `_trackRoom`): a product site's sections, twelve `1fr` columns 32px apart with a
// cell from the first line to the last. This pins the two spellings to the
// same boxes -- the paragraph and a cell under it -- at widths from under
// the gaps (where the columns sit at their bases) to wide
// (fixtures/grid-span-all-flex p1-p3). UNDER A BOX THAT SHRINKS TO ITS
// CONTENT the grid held to the width it is handed is no narrower than the
// least of its room and its own content, which is at least the cell's: the
// cell's max-content contribution fills the columns and gaps it spans when
// the grid is sized to its max-content (11.7.1, "find the size of an fr";
// `_expandFlexible`), and its min-content contribution their bases (11.5
// step 1, `_intrinsicSizes`). So the cell is at least the least of the room
// and its own content, and the word fits wherever it fits the room: a grid
// `width: fit-content`, and the product site's sections in items of a flex line
// that floor them at their min-content (p4, p5). NEGATIVE: a `0.5fr`
// column of a cell that states no floor, which takes half of what is left
// and is narrower than the word: the line box keeps it whole, the
// paragraph breaks it (n1); in a grid that shrinks to its content, a cell
// that states no floor across one of two columns, which takes half of what
// is left (n3).
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

const _words = 'Explore incomprehensible AI Plays for every team';

/// The paragraph as css_box lays it out ([told]), in a line box that keeps
/// its words whole, or as the stock pass writes it.
Widget _spelled({required bool told}) {
  final text = Text(_words, key: const ValueKey('a'), style: _fx(16, 24));
  return told ? LineBox(child: text) : text;
}

typedef _Grid = ({String name, List<TrackSize> columns, Widget Function(Widget) cell});

/// The grid in [width] -- held to it, or in a box [shrink] wraps round it
/// -- its first row the paragraph's cell and its second a box after it
/// across the same columns.
Widget _page(_Grid g, double width, {required bool told, Widget Function(Widget)? shrink}) {
  final grid = Tracks(
    columns: g.columns,
    spacing: 32,
    children: [
      g.cell(_spelled(told: told)),
      g.cell(const SizedBox(key: ValueKey('after'), height: 5)),
    ],
  );
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: shrink == null ? grid : Align(alignment: Alignment.topLeft, child: shrink(grid)),
      ),
    ),
  );
}

/// How far apart the two spellings put anything, and what is furthest
/// apart.
Future<(double, String)> _apart(WidgetTester t, _Grid g, double width, {Widget Function(Widget)? shrink}) async {
  final got = <bool, Map<String, double>>{};
  for (final told in [true, false]) {
    await t.pumpWidget(_page(g, width, told: told, shrink: shrink));
    expect(t.takeException(), isNull, reason: '${g.name} at $width');
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

/// Widths the widest word fits, from under the twelve columns' gaps to wide.
const _widths = [160.0, 240.0, 320.0, 400.0, 500.0, 900.0];

void main() {
  setUpAll(() async {
    final bytes = Uint8List.fromList(File('test/fonts/Inter.ttf').readAsBytesSync());
    await (FontLoader('Fx')..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  });

  final twelve = [for (var i = 0; i < 12; i++) const TrackSize.flex(1)];
  final exact = <_Grid>[
    // p1: the product site's sections, twelve `1fr` columns and a cell from the
    // first line to the last.
    (
      name: 'twelve 1fr columns, first line to last',
      columns: twelve,
      cell: (w) => TrackCell(column: 0, columnEnd: 12, child: w),
    ),
    // p2: a column of a length beside a `2fr` one, the cell across both.
    (
      name: 'a length beside a flexible column, across both',
      columns: const [TrackSize.fixed(100), TrackSize.flex(2)],
      cell: (w) => TrackCell(column: 0, columnEnd: 2, child: w),
    ),
    // p3: one `1fr` column of a cell that states no floor of its own.
    (
      name: 'one 1fr column, no floor',
      columns: const [TrackSize.flex(1)],
      cell: (w) => TrackCell(minWidth: 0, child: w),
    ),
  ];

  for (final g in exact) {
    testWidgets('across every column of a grid held to its width, the paragraph is the line box (${g.name})', (
      t,
    ) async {
      for (final width in _widths) {
        final (d, at) = await _apart(t, g, width);
        expect(d, lessThan(1e-3), reason: '${g.name} at $width, $at');
      }
    });
  }

  testWidgets('NEGATIVE: a 0.5fr column of a cell that states no floor is narrower than a word (n1)', (t) async {
    final g = (
      name: 'one 0.5fr column, no floor',
      columns: const [TrackSize.flex(0.5)],
      cell: (Widget w) => TrackCell(minWidth: 0, child: w),
    );
    var worst = 0.0;
    for (final width in _widths) {
      worst = math.max(worst, (await _apart(t, g, width)).$1);
    }
    expect(worst, greaterThan(10));
  });

  // p4: a grid `width: fit-content` -- as wide as its max-content, or the
  // room -- two `1fr` columns 32px apart and the cell across both.
  final two = <TrackSize>[const TrackSize.flex(1), const TrackSize.flex(1)];
  final _Grid both = (
    name: 'two 1fr columns, across both',
    columns: two,
    cell: (w) => TrackCell(column: 0, columnEnd: 2, child: w),
  );
  testWidgets('in a grid as wide as its content, across every column, the paragraph is the line box (p4)', (t) async {
    for (final width in _widths) {
      final (d, at) = await _apart(t, both, width, shrink: (g) => IntrinsicWidth(child: g));
      expect(d, lessThan(1e-3), reason: 'fit-content at $width, $at');
    }
  });
  // p5: the product site's sections floored at their min-content, as a flex line's
  // item is -- shrink-to-fit, never under it -- at every width, the twelve
  // columns' gaps and a phone's width included.
  testWidgets('in a grid shrunk to fit, across every column, the paragraph is the line box (p5)', (t) async {
    for (final width in const [60.0, 100.0, 160.0, 320.0, 500.0, 900.0]) {
      final (d, at) = await _apart(t, exact.first, width, shrink: (g) => ShrinkWidth(spill: true, child: g));
      expect(d, lessThan(1e-3), reason: 'shrink-to-fit at $width, $at');
    }
  });

  testWidgets(
    'NEGATIVE: in a grid as wide as its content, a cell across one of two columns is narrower than a word (n3)',
    (t) async {
      final _Grid one = (
        name: 'two 1fr columns, across one',
        columns: two,
        cell: (w) => TrackCell(column: 0, minWidth: 0, child: w),
      );
      var worst = 0.0;
      for (final width in const [160.0, 200.0, 240.0]) {
        worst = math.max(worst, (await _apart(t, one, width, shrink: (g) => IntrinsicWidth(child: g))).$1);
      }
      expect(worst, greaterThan(10));
    },
  );
}
