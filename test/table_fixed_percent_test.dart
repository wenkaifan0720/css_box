import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

// A `table-layout: fixed` table whose first row asks for more than it has:
// the percentage columns shrink into the room the px columns leave, in
// proportion (as Chrome draws it; CSS 2.1 17.5.2.1 leaves it open), and an
// auto column beside them gets nothing. The px columns keep their widths.

/// A fixed table [width] wide whose first row's cells say [widths]: a
/// number is px, a string `'50%'` a share, null no width.
Widget _table(double width, List<Object?> widths, List<GlobalKey> keys, {Size spacing = Size.zero}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: TableBox(
      fixed: true,
      width: width,
      spacing: spacing,
      children: [
        for (var i = 0; i < widths.length; i++)
          TableSlot(
            row: 0,
            column: i,
            align: TableAlign.top,
            width: widths[i] is num ? (widths[i]! as num).toDouble() : null,
            widthFactor: widths[i] is String ? double.parse((widths[i]! as String).replaceAll('%', '')) / 100 : null,
            child: SizedBox(key: keys[i], height: 10),
          ),
      ],
    ),
  ),
);

Future<List<double>> _widths(
  WidgetTester tester,
  double width,
  List<Object?> widths, {
  Size spacing = Size.zero,
}) async {
  final keys = [for (final _ in widths) GlobalKey()];
  // A fresh table each time: a cell whose width changes in place does not lay its table out again.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(_table(width, widths, keys, spacing: spacing));
  return [for (final k in keys) tester.getSize(find.byKey(k)).width];
}

void main() {
  testWidgets('percentages past the room the px columns leave share that room', (tester) async {
    expect(await _widths(tester, 500, [200, '50%', '50%']), [200, 150, 150]);
    expect(await _widths(tester, 500, [100, 100, '50%', '50%']), [100, 100, 150, 150]);
    expect(await _widths(tester, 500, ['100%', 100]), [400, 100]);
  });

  testWidgets('a column with no width beside percentages scaled down gets none', (tester) async {
    expect(await _widths(tester, 500, [200, '40%', '40%', null]), [200, 150, 150, 0]);
  });

  testWidgets('percentages over the whole table alone scale to it', (tester) async {
    final w = await _widths(tester, 500, ['50%', '60%']);
    expect(w[0], moreOrLessEquals(500 * 50 / 110));
    expect(w[1], moreOrLessEquals(500 * 60 / 110));
  });

  testWidgets('px columns that fill the table leave the percentages nothing', (tester) async {
    expect(await _widths(tester, 500, [600, '50%', '50%']), [600, 0, 0]);
  });

  testWidgets('the room is the table less its border-spacing', (tester) async {
    // 500 less 4 gaps of 10: 460, of which the px column takes 200.
    expect(await _widths(tester, 500, [200, '50%', '50%'], spacing: const Size(10, 0)), [200, 130, 130]);
  });

  testWidgets('NEGATIVE: percentages that fit beside the px columns keep their share', (tester) async {
    expect(await _widths(tester, 500, [200, '50%', null]), [200, 250, 50]);
    expect(await _widths(tester, 500, [200, '30%', '30%']), [200, 150, 150]);
  });

  testWidgets('NEGATIVE: px columns alone that overflow the table keep their widths', (tester) async {
    expect(await _widths(tester, 500, [300, 300]), [300, 300]);
    expect(await _widths(tester, 500, [300, 300, null]), [300, 300, 0]);
  });
}
