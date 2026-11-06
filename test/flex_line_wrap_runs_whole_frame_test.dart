// A WRAP OF RUNS: A WHOLE LINE IS NOT SHRUNK INSIDE ITS FRAME, AND A FLOOR
// OF THE RUN ON A GROWER ALONE IN IT IS MOOT (css-flexbox-1 9.3 step 5,
// 9.7 steps 1-4). An item of `width: 100%` is a run of its own; with no
// margin along, its outer base is all of the run, the run is short by
// nothing, and it stays its base whatever its frame. A grower of `flex: 1
// 1 0%` between two such items is alone in its run and grows into all of
// it: a floor of no more than the run holds it at no less than it is.
// A docs site's sandboxes are an editor and a preview that grow from nothing
// either side of a tab bar of `width: 100%; padding: 4px`, `min-width:
// 100%` on a phone (`fixtures/flex-wrap-runs-whole-frame` p1, p2). The
// lowerer (`lossy_flex.dart`: the whole line skipped where a line its bases
// fill keeps one shrunk inside its frame, `_loneFloorL`) writes the line as
// the `Column` of its runs (`_runsL`), each grower a `Row` of its
// `Expanded`. This pins the line with the frame and the floors to the
// line without them, and to that spelling, at several widths.
// NEGATIVE: a margin along the tab bar, round content wider than the run
// less the margin -- the automatic minimum holds the item past what the
// `Column` gives it (n1); a floor past the run (n3); two growers side by
// side, which their floors break into two runs where the `Row` shares one
// out between them (n4).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

Widget _box(String key, {double? width, double? height}) => SizedBox(
  key: ValueKey(key),
  width: width,
  height: height,
  child: const ColoredBox(color: Color(0xFF336699)),
);

Widget _frame(Widget line, double width) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: line),
  ),
);

FlexCell _grower(String key, {double? floor}) => FlexCell(
  grow: 1,
  basisFraction: 0,
  mainSizeFraction: 1,
  crossSize: 100,
  minFraction: floor,
  child: _box(key, height: 100),
);

/// The tab bar: all of the line, in a padding of 4 its frame states.
FlexCell _tab({bool framed = true, double margin = 0, double? content}) => FlexCell(
  mainSizeFraction: 1,
  frame: framed ? const EdgeInsets.all(4) : EdgeInsets.zero,
  margin: EdgeInsets.only(left: margin),
  child: Padding(
    key: const ValueKey('t'),
    padding: const EdgeInsets.all(4),
    child: SizedBox(width: content, height: 20),
  ),
);

Widget _line(List<FlexCell> items) => FlexLine(wrap: true, spacing: 1, runSpacing: 1, children: items);

/// The line as the lowerer writes it: the `Column` of its runs.
Widget _runs({double margin = 0, double? content}) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  spacing: 1,
  children: [
    Row(
      spacing: 1,
      children: [Expanded(child: SizedBox(height: 100, child: _box('a', height: 100)))],
    ),
    Padding(
      padding: EdgeInsets.only(left: margin),
      child: Padding(
        key: const ValueKey('t'),
        padding: const EdgeInsets.all(4),
        child: SizedBox(width: content, height: 20),
      ),
    ),
    Row(
      spacing: 1,
      children: [Expanded(child: SizedBox(height: 100, child: _box('b', height: 100)))],
    ),
  ],
);

Future<List<Rect>> _rects(WidgetTester t, Widget w, [List<String> keys = const ['a', 't', 'b']]) async {
  await t.pumpWidget(w);
  return [for (final k in keys) t.getRect(find.byKey(ValueKey(k)))];
}

void main() {
  for (final width in const [390.0, 300.0, 120.0]) {
    testWidgets('p1: a whole line of a wrap of runs is not shrunk inside its frame, $width wide', (t) async {
      final framed = await _rects(t, _frame(_line([_grower('a'), _tab(), _grower('b')]), width));
      final bare = await _rects(t, _frame(_line([_grower('a'), _tab(framed: false), _grower('b')]), width));
      expect(framed, bare);
      expect(framed[1].width, width);
      expect(await _rects(t, _frame(_runs(), width)), framed);
    });

    testWidgets('p2: a floor of the run on a grower alone in it is moot, $width wide', (t) async {
      final floored = await _rects(t, _frame(_line([_grower('a', floor: 1), _tab(), _grower('b', floor: 1)]), width));
      final free = await _rects(t, _frame(_line([_grower('a'), _tab(), _grower('b')]), width));
      expect(floored, free);
      expect(floored[0].width, width);
      expect(await _rects(t, _frame(_runs(), width)), floored);
      // A floor short of the run, likewise.
      expect(await _rects(t, _frame(_line([_grower('a', floor: 0.5), _tab(), _grower('b', floor: 0.5)]), width)), free);
    });
  }

  testWidgets('NEGATIVE n1: a margin along the tab bar, round content past the run less it, holds it past the Column', (
    t,
  ) async {
    final line = await _rects(t, _frame(_line([_grower('a'), _tab(margin: 20, content: 300), _grower('b')]), 300));
    final runs = await _rects(t, _frame(_runs(margin: 20, content: 300), 300));
    // Its automatic minimum, all of the run (the smaller of its width and
    // its content), past the 280 the margin leaves.
    expect(line[1].width, 300);
    expect(runs[1].width, 280);
  });

  testWidgets('NEGATIVE n3: a floor past the run holds the grower past it', (t) async {
    final line = await _rects(t, _frame(_line([_grower('a', floor: 1.5), _tab(), _grower('b')]), 300));
    expect(line[0].width, 450);
    expect((await _rects(t, _frame(_runs(), 300)))[0].width, 300);
  });

  testWidgets('NEGATIVE n4: two growers side by side are broken apart by their floors', (t) async {
    final line = await _rects(t, _frame(_line([_grower('a', floor: 1), _grower('b', floor: 1), _tab()]), 300));
    expect(line[0].width, 300);
    expect(line[2].width, 300);
    expect(line[2].top, greaterThan(line[0].bottom));
    final free = await _rects(t, _frame(_line([_grower('a'), _grower('b'), _tab()]), 300));
    expect(free[0].width, 149.5);
  });
}
