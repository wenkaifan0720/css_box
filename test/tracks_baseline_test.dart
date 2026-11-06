// `CellAlign.baseline` in `Tracks` (css-align-3 9, css-grid-1 11.5 step 1):
// a row lines up the first baselines of the items in it that say it, each
// pushed down by as far as the row's lowest baseline is below its own, and
// the push is part of what the item gives the row. Every rect is Chrome's,
// from fixtures/grid-baseline-rows.html and baseline-groups.html (g5). A
// line of text is a box of the height and first baseline Chrome gives it
// (Inter at `line-height: 1.5`: 28px 42/31, 22px 33/24, 20px 30/22, 18px
// 27/20, 16px 24/18, 14px 21/16, 12px 18/13, 10px 15/11), so each row is
// the grid's work alone.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

ValueKey<String> _k(String name) => ValueKey(name);

/// Chrome lays boxes out in 1/64 px.
const _tolerance = 1 / 64;

/// A line of text [height] tall whose baseline is [baseline] down, as wide
/// as the room it is given.
class _Line extends LeafRenderObjectWidget {
  const _Line(this.height, this.baseline, {super.key});
  final double height, baseline;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderLine(height, baseline);
}

class _RenderLine extends RenderBox {
  _RenderLine(this.h, this.b);
  final double h, b;

  @override
  double computeMinIntrinsicWidth(double height) => 40;
  @override
  double computeMaxIntrinsicWidth(double height) => 40;
  @override
  double computeMinIntrinsicHeight(double width) => h;
  @override
  double computeMaxIntrinsicHeight(double width) => h;
  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(Size(constraints.hasBoundedWidth ? constraints.maxWidth : 40, h));
  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) => b;
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => b;
  @override
  void performLayout() => size = computeDryLayout(constraints);
}

/// [grid] laid out [width] wide from the top left, and the rect of each
/// keyed box in it from the grid's own top left, against Chrome's.
Future<void> _expect(WidgetTester tester, double width, Widget grid, Map<String, Rect> chrome) async {
  // A window as wide as Chrome's, so the page's width is not held to the
  // test's 800.
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(key: _k('root'), width: width, child: grid),
      ),
    ),
  );
  final origin = tester.getTopLeft(find.byKey(_k('root')));
  for (final MapEntry(key: name, value: want) in chrome.entries) {
    final got = tester.getRect(find.byKey(_k(name))).shift(-origin);
    final d = [
      got.left - want.left,
      got.top - want.top,
      got.width - want.width,
      got.height - want.height,
    ].map((x) => x.abs()).reduce(math.max);
    expect(d, lessThanOrEqualTo(_tolerance), reason: '$name: tracks $got, Chrome $want');
  }
}

const _columns = [TrackSize.fixed(120), TrackSize.fixed(120), TrackSize.fixed(120)];

void main() {
  testWidgets('three sizes of text in one row come down to the largest one\'s baseline', (tester) async {
    await _expect(
      tester,
      1408,
      Tracks(
        key: _k('grid'),
        columns: _columns,
        align: CellAlign.baseline,
        children: [
          _Line(42, 31, key: _k('big')),
          _Line(18, 13, key: _k('small')),
          _Line(27, 20, key: _k('middle')),
        ],
      ),
      {
        'grid': const Rect.fromLTWH(0, 0, 1408, 42),
        'big': const Rect.fromLTWH(0, 0, 120, 42),
        'small': const Rect.fromLTWH(120, 18, 120, 18),
        'middle': const Rect.fromLTWH(240, 11, 120, 27),
      },
    );
  });

  testWidgets('a baseline under a padding and one under a margin both count', (tester) async {
    await _expect(
      tester,
      1408,
      Tracks(
        key: _k('grid'),
        columns: _columns,
        align: CellAlign.baseline,
        children: [
          // `padding-top: 20px` is the item's content's: its baseline is 36.
          _Line(41, 36, key: _k('padded')),
          TrackCell(
            margin: const EdgeInsets.only(top: 12),
            child: _Line(21, 16, key: _k('margined')),
          ),
          _Line(21, 16, key: _k('plain')),
        ],
      ),
      {
        'grid': const Rect.fromLTWH(0, 0, 1408, 41),
        'padded': const Rect.fromLTWH(0, 0, 120, 41),
        'margined': const Rect.fromLTWH(120, 20, 120, 21),
        'plain': const Rect.fromLTWH(240, 20, 120, 21),
      },
    );
  });

  testWidgets('two items of a row say it beside one at the end; a group of one starts', (tester) async {
    await _expect(
      tester,
      1408,
      Tracks(
        key: _k('grid'),
        columns: _columns,
        rows: const [TrackSize.fixed(60), TrackSize.fixed(50)],
        children: [
          TrackCell(
            align: CellAlign.baseline,
            child: _Line(33, 24, key: _k('walnut')),
          ),
          TrackCell(
            align: CellAlign.baseline,
            child: _Line(18, 13, key: _k('xylem')),
          ),
          TrackCell(
            align: CellAlign.end,
            height: 20,
            child: SizedBox(key: _k('end'), height: 20),
          ),
          TrackCell(
            align: CellAlign.baseline,
            child: _Line(30, 22, key: _k('alone')),
          ),
          _Line(18, 13, key: _k('stretched')),
        ],
      ),
      {
        'grid': const Rect.fromLTWH(0, 0, 1408, 110),
        'walnut': const Rect.fromLTWH(0, 0, 120, 33),
        'xylem': const Rect.fromLTWH(120, 11, 120, 18),
        'end': const Rect.fromLTWH(240, 40, 120, 20),
        'alone': const Rect.fromLTWH(0, 60, 120, 30),
        'stretched': const Rect.fromLTWH(120, 60, 120, 50),
      },
    );
  });

  testWidgets('the grid\'s own baseline is the first item that lines up, where its row put it', (tester) async {
    await _expect(
      tester,
      1408,
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(width: 95.75, child: _Line(42, 31, key: _k('anchor'))),
          Tracks(
            key: _k('grid'),
            columns: const [TrackSize.fixed(90), TrackSize.fixed(90)],
            align: CellAlign.baseline,
            children: [
              _Line(18, 13, key: _k('bramble')),
              _Line(33, 24, key: _k('cobalt')),
            ],
          ),
        ],
      ),
      {
        'anchor': const Rect.fromLTWH(0, 0, 95.75, 42),
        'grid': const Rect.fromLTWH(95.75, 7, 180, 33),
        'bramble': const Rect.fromLTWH(95.75, 18, 90, 18),
        'cobalt': const Rect.fromLTWH(185.75, 7, 90, 33),
      },
    );
  });

  testWidgets('NEGATIVE: an item with an auto top margin is not in the group', (tester) async {
    // grid-baseline-rows n1: the margin takes the row's free space, and the
    // text deep under its padding drags no one down.
    await _expect(
      tester,
      1408,
      Tracks(
        key: _k('grid'),
        columns: _columns,
        align: CellAlign.baseline,
        children: [
          TrackCell(
            autoMargin: const AutoEdges(top: true),
            child: _Line(45, 41, key: _k('deep')),
          ),
          _Line(42, 31, key: _k('ember')),
          _Line(18, 13, key: _k('fennel')),
        ],
      ),
      {
        'grid': const Rect.fromLTWH(0, 0, 1408, 45),
        'deep': const Rect.fromLTWH(0, 0, 120, 45),
        'ember': const Rect.fromLTWH(120, 0, 120, 42),
        'fennel': const Rect.fromLTWH(240, 18, 120, 18),
      },
    );
    // baseline-groups g5: the auto-margin item sets the row, 40 tall, and
    // the two 16px lines beside it share one baseline at the top.
    await _expect(
      tester,
      1408,
      Tracks(
        key: _k('grid'),
        columns: const [TrackSize.fixed(70), TrackSize.fixed(70), TrackSize.fixed(70)],
        align: CellAlign.baseline,
        children: [
          TrackCell(
            autoMargin: const AutoEdges(top: true),
            height: 40,
            child: _Line(40, 30, key: _k('b23')),
          ),
          _Line(24, 18, key: _k('b24')),
          _Line(24, 18, key: _k('b25')),
        ],
      ),
      {
        'grid': const Rect.fromLTWH(0, 0, 1408, 40),
        'b23': const Rect.fromLTWH(0, 0, 70, 40),
        'b24': const Rect.fromLTWH(70, 0, 70, 24),
        'b25': const Rect.fromLTWH(140, 0, 70, 24),
      },
    );
  });
}
