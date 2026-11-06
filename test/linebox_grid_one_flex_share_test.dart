// A LINE BOX IN THE ONE FLEXIBLE COLUMN OF A GRID HELD TO ITS WIDTH IS ITS
// PARAGRAPH WHERE ITS WIDEST WORD FITS WHAT THE OTHER COLUMNS LEAVE. The
// line box widens its paragraph only to keep a word whole that is wider
// than its room (`linebox.dart`, `_room`; `overflow-wrap: normal`,
// css-text-3 5.5). A flexible column takes its share of what the others
// and the gaps leave, or its base where that is more (css-grid-1 11.7.1,
// "find the size of an fr"; css_box `tracks.dart`, `_expandFlexible`): with
// no other flexible column to share it with, all of it at a factor of 1,
// whatever its content makes its base. The stock pass reads that
// (`tidy.dart`, `_trackRoom`): a product site's app screens, a 232px sidebar beside
// a `1fr` column, a cell `width: 100%; min-width: 2px; overflow: hidden` in
// it. This pins the two spellings to the same boxes -- the paragraph and a
// box after it -- at widths where the word fits what the sidebar leaves
// (fixtures/grid-one-flex-left p1). NEGATIVE: of two `1fr` columns, one
// whose content makes its base past its share leaves the other less than
// half, narrower than the word (n1).
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

/// The grid of [columns] in [width]: [first] in the first column, the
/// paragraph's cell in the second, and a box after the grid.
Widget _page(List<TrackSize> columns, Widget first, double width, {required bool told}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Tracks(
            columns: columns,
            children: [
              TrackCell(child: first),
              TrackCell(widthFraction: 1, minWidth: 2, clips: true, child: _spelled(told: told)),
            ],
          ),
          const SizedBox(key: ValueKey('after'), height: 5),
        ],
      ),
    ),
  ),
);

/// How far apart the two spellings put anything, and what is furthest
/// apart.
Future<(double, String)> _apart(WidgetTester t, List<TrackSize> columns, Widget first, double width) async {
  final got = <bool, Map<String, double>>{};
  for (final told in [true, false]) {
    await t.pumpWidget(_page(columns, first, width, told: told));
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

void main() {
  setUpAll(() async {
    final bytes = Uint8List.fromList(File('test/fonts/Inter.ttf').readAsBytesSync());
    await (FontLoader('Fx')..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  });

  // p1: the product site's screens, a 232px sidebar beside a `1fr` column -- the
  // sidebar holding a box wider than itself too, which a column of a length
  // does not grow for.
  for (final (name, first) in [
    ('an empty sidebar', const SizedBox(height: 10)),
    ('a sidebar holding a wide box', const SizedBox(width: 400, height: 10)),
  ]) {
    testWidgets('where the word fits what the sidebar leaves, the paragraph is the line box ($name)', (t) async {
      for (final width in const [400.0, 500.0, 900.0, 1400.0]) {
        final (d, at) = await _apart(t, const [TrackSize.fixed(232), TrackSize.flex(1)], first, width);
        expect(d, lessThan(1e-3), reason: '$name at $width, $at');
      }
    });
  }

  // ... and a `0.5fr` column, half of what the sidebar leaves.
  testWidgets('where the word fits half of what the sidebar leaves, the paragraph is the line box (a 0.5fr column)', (
    t,
  ) async {
    for (final width in const [600.0, 900.0, 1400.0]) {
      final (d, at) = await _apart(
        t,
        const [TrackSize.fixed(232), TrackSize.flex(0.5)],
        const SizedBox(height: 10),
        width,
      );
      expect(d, lessThan(1e-3), reason: '0.5fr at $width, $at');
    }
  });

  testWidgets(
    'NEGATIVE: beside a 1fr column whose content is past its share, the other is narrower than the word (n1)',
    (t) async {
      var worst = 0.0;
      for (final width in const [400.0, 420.0, 440.0]) {
        worst = math.max(
          worst,
          (await _apart(
            t,
            const [TrackSize.flex(1), TrackSize.flex(1)],
            const SizedBox(width: 300, height: 10),
            width,
          )).$1,
        );
      }
      expect(worst, greaterThan(10));
    },
  );
}
