// A LINE WHOSE FLEX FACTORS ADD UP TO LESS THAN ONE SHARES THAT PART OF ITS
// INITIAL FREE SPACE (css-flexbox-1 9.7 step 4b), and the gaps are off that
// space already: two `flex: .25 1 0` items 10 apart in 100 share a half of
// the 90 between them, 22.5 each, and two `flex: 0 .25 100px` give up a half
// of the 110 they overflow by, 72.5 each. The gaps taken off a second time
// made them 17.5 and 67.5.
// NEGATIVE: factors that add up to one or more share all of the free space,
// and a line with no gap shares the same part as before.
import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget line(double width, double spacing, List<FlexCell> cells) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: FlexLine(spacing: spacing, children: cells),
    ),
  ),
);

FlexCell cell(int i, {double grow = 0, double shrink = 1, double? basis, double? max}) => FlexCell(
  grow: grow,
  shrink: shrink,
  basis: basis,
  min: 0,
  max: max,
  child: SizedBox(key: ValueKey(i), height: 10),
);

List<double> widths(WidgetTester t, int n) => [for (var i = 0; i < n; i++) t.getSize(find.byKey(ValueKey(i))).width];

void main() {
  testWidgets('growing: a half of the space between the gaps', (t) async {
    await t.pumpWidget(line(100, 10, [cell(0, grow: .25, basis: 0), cell(1, grow: .25, basis: 0)]));
    expect(widths(t, 2), [22.5, 22.5]);
  });

  testWidgets('shrinking: a half of the overflow, gaps and all', (t) async {
    await t.pumpWidget(line(100, 10, [cell(0, shrink: .25, basis: 100), cell(1, shrink: .25, basis: 100)]));
    expect(widths(t, 2), [72.5, 72.5]);
  });

  testWidgets('an item frozen at its cap: the rest share their part of the initial space', (t) async {
    // Three `flex: .2 1 0` items 10 apart in 100: 80 of free space, 0.6 of
    // it (48) shared, 16 each, and the first is capped at 5 and frozen there.
    // The other two then share 0.4 of the INITIAL 80 -- 32, under the 75
    // left -- 16 each.
    await t.pumpWidget(
      line(100, 10, [cell(0, grow: .2, basis: 0, max: 5), cell(1, grow: .2, basis: 0), cell(2, grow: .2, basis: 0)]),
    );
    expect(widths(t, 3), [5, 16, 16]);
  });

  testWidgets('NEGATIVE: factors of one or more share all the free space', (t) async {
    await t.pumpWidget(line(100, 10, [cell(0, grow: .5, basis: 0), cell(1, grow: .5, basis: 0)]));
    expect(widths(t, 2), [45, 45]);
    await t.pumpWidget(line(100, 10, [cell(0, shrink: 1, basis: 100), cell(1, shrink: 1, basis: 100)]));
    expect(widths(t, 2), [45, 45]);
  });

  testWidgets('NEGATIVE: with no gap, the same part as before', (t) async {
    await t.pumpWidget(line(100, 0, [cell(0, grow: .25, basis: 0), cell(1, grow: .25, basis: 0)]));
    expect(widths(t, 2), [25, 25]);
    await t.pumpWidget(line(100, 0, [cell(0, shrink: .25, basis: 100), cell(1, shrink: .25, basis: 100)]));
    expect(widths(t, 2), [75, 75]);
  });
}
