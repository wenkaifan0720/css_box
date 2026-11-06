// WHAT A GRID ASKS ITS ITEMS, which is what the lowerer reads to decide
// which boxes in them it may write as stock.
//
// A GRID ASKS AN ITEM ITS BASELINE ONLY WHERE ITS OWN IS ASKED, or where an
// item lines its baseline up with its row's (css-grid-1 10.8, css-align-3
// 9): `tracks.dart` works an item's dry baseline out in `_Grid._leaf` only
// under `baselines || aligned`, and `baselines` is set by its own
// `computeDryBaseline` and `computeDistanceToActualBaseline` alone. Laid
// out, measured, asked a dry layout, it reads none. A product site's page columns
// are grids, and every icon tile in them -- a `place-items: center` grid
// round an icon of no baseline, which it makes one up for -- was read as
// asked its baseline, and kept (`fixtures/grid-baseline-unasked`).
//
// A GRID NEVER ASKS AN ITEM ITS LEAST HEIGHT: it asks its least and
// greatest widths, its greatest height at a width and its dry layout
// (`_measure`, `performLayout`), and answers its own least height with a
// dry layout of itself (`computeMinIntrinsicHeight`). A banking site's footer
// columns, grids of one `minmax(0, 1fr)` column in a page grid of sixteen,
// were read as asked their least sizes, and kept.
//
// Each is pinned by a probe that counts the questions that reach it: what
// the lowerer then writes in the item answers every other question as the
// css_box box it was did (the spellings' own tests). NEGATIVE: a grid in a
// row on its baseline, and a grid that lines an item up on its baseline,
// ask it; a `Column` asked its least height asks its children theirs.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

/// Counts the questions asked of what it holds.
class _Probe extends SingleChildRenderObjectWidget {
  const _Probe(this.log, {super.child});
  final List<String> log;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderProbe(log);

  // A probe pumped again in its place keeps its render object: it writes
  // to the log of the widget now there.
  @override
  void updateRenderObject(BuildContext context, _RenderProbe renderObject) => renderObject.log = log;
}

class _RenderProbe extends RenderProxyBox {
  _RenderProbe(this.log);
  List<String> log;

  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
    log.add('dry baseline');
    return super.computeDryBaseline(constraints, baseline);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    log.add('baseline');
    return super.computeDistanceToActualBaseline(baseline);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    log.add('least height');
    return super.computeMinIntrinsicHeight(width);
  }
}

Widget _page(double width, Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: child),
  ),
);

/// A grid of an `auto` column and a share round [a] and [b], its items
/// placed at [align].
Widget _grid(Widget a, Widget b, {CellAlign? align, CellAlign? first}) => Tracks(
  key: const ValueKey('grid'),
  columns: const [TrackSize.auto, TrackSize.flex(1)],
  spacing: 8,
  align: align ?? CellAlign.stretch,
  children: [
    TrackCell(align: first, child: a),
    b,
  ],
);

void main() {
  group('a grid asks an item its baseline only where its own is asked', () {
    // Laid out, measured across and down, asked its dry size: no baseline.
    final quiet = <String, Widget Function(Widget grid)>{
      'laid out': (g) => g,
      'in a column': (g) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [g]),
      'measured across': (g) => IntrinsicWidth(child: g),
      'measured down in a stretched row': (g) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: g),
            const Text('x'),
          ],
        ),
      ),
      'an item of a grid': (g) =>
          Tracks(columns: const [TrackSize.flex(1), TrackSize.fixed(40)], children: [g, const Text('x')]),
      'in a row that centres it': (g) => Row(
        children: [
          Expanded(child: g),
          const Text('x'),
        ],
      ),
    };
    for (final MapEntry(key: name, value: wrap) in quiet.entries) {
      testWidgets(name, (t) async {
        final log = <String>[];
        await t.pumpWidget(
          _page(400, wrap(_grid(_Probe(log, child: const Text('a b c')), const Text('words beside it')))),
        );
        expect(log, isEmpty);
        final box = t.renderObject<RenderBox>(find.byKey(const ValueKey('grid')));
        box.getDryLayout(const BoxConstraints(maxWidth: 300));
        box.getMinIntrinsicWidth(double.infinity);
        box.getMaxIntrinsicWidth(double.infinity);
        box.getMaxIntrinsicHeight(300);
        expect(log, isEmpty);
      });
    }

    testWidgets('NEGATIVE: a grid in a row on its baseline asks its items theirs', (t) async {
      final log = <String>[];
      await t.pumpWidget(
        _page(
          400,
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: _grid(_Probe(log, child: const Text('a b c')), const Text('words'))),
              const Text('x'),
            ],
          ),
        ),
      );
      expect(log, isNotEmpty);
    });

    testWidgets('NEGATIVE: a grid that lines an item up on its baseline asks it', (t) async {
      for (final (align, first) in [(CellAlign.baseline, null), (null, CellAlign.baseline)]) {
        final log = <String>[];
        await t.pumpWidget(
          _page(
            400,
            _grid(
              _Probe(log, child: const Text('a b c')),
              const Text('words'),
              align: align,
              first: first,
            ),
          ),
        );
        expect(log, isNotEmpty, reason: '$align $first');
      }
    });
  });

  group('a grid never asks an item its least height', () {
    testWidgets('laid out, measured, asked its own least height', (t) async {
      final log = <String>[];
      await t.pumpWidget(
        _page(
          400,
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _grid(_Probe(log, child: const Text('a b c')), const Text('words beside it'))),
              ],
            ),
          ),
        ),
      );
      final box = t.renderObject<RenderBox>(find.byKey(const ValueKey('grid')));
      for (final w in const [400.0, 120.0, 30.0, double.infinity]) {
        box.getMinIntrinsicHeight(w);
        box.getMaxIntrinsicHeight(w);
        box.getMinIntrinsicWidth(w);
      }
      expect(log, isNot(contains('least height')));
    });

    testWidgets('NEGATIVE: a column asked its least height asks its children theirs', (t) async {
      final log = <String>[];
      await t.pumpWidget(
        _page(
          400,
          Column(
            key: const ValueKey('grid'),
            children: [_Probe(log, child: const Text('a b c'))],
          ),
        ),
      );
      t.renderObject<RenderBox>(find.byKey(const ValueKey('grid'))).getMinIntrinsicHeight(400);
      expect(log, contains('least height'));
    });
  });
}
