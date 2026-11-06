// A STRETCHED ITEM ON THE ONE LINE OF A BOX HANDED ITS DEPTH IS NOT ASKED
// ITS LEAST DEPTH (`flex_line.dart`, `_measureRun`): it is as deep as the
// line whatever its content comes to (css-flexbox-1 9.4 steps 8 and 11).
// Down a column of a width it was handed that is the item's least width,
// which a page's column asked of every block it holds -- and the lowerer
// kept every shrink-to-fit box under one css_box's for it.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

/// A box of [width] by [height] that counts the least widths it is asked.
class _Asked extends LeafRenderObjectWidget {
  const _Asked({super.key, required this.log});
  final List<String> log;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderAsked(log);
}

class _RenderAsked extends RenderBox {
  _RenderAsked(this.log);
  final List<String> log;

  @override
  double computeMinIntrinsicWidth(double height) {
    log.add('least');
    return 300;
  }

  @override
  double computeMaxIntrinsicWidth(double height) => 300;

  @override
  double computeMinIntrinsicHeight(double width) => 20;

  @override
  double computeMaxIntrinsicHeight(double width) => 20;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(const Size(300, 20));

  @override
  void performLayout() => size = computeDryLayout(constraints);
}

Widget _column(List<String> log, {CrossAxisAlignment? align, bool wrap = false}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 200,
      child: FlexLine(
        direction: Axis.vertical,
        wrap: wrap,
        children: [
          FlexCell(
            align: align,
            child: _Asked(key: const ValueKey('item'), log: log),
          ),
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets('p1 a stretched item down a column of a width it was handed is as wide, unasked', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(_column(log));
    expect(log, isEmpty);
    final r = tester.getRect(find.byKey(const ValueKey('item')));
    expect(r.width, 200);
    expect(r.height, 20);
  });

  testWidgets('NEGATIVE: an item that is not stretched is as wide as its content, read from its least', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(_column(log, align: CrossAxisAlignment.start));
    expect(log, isNotEmpty);
    // Fit-content in 200, never under its least of 300 (css-sizing-3 5.2.2).
    expect(tester.getRect(find.byKey(const ValueKey('item'))).width, 300);
  });

  testWidgets('NEGATIVE: a column that wraps reads its stretched items as they come', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(_column(log, wrap: true));
    expect(log, isNotEmpty);
  });

  testWidgets('NEGATIVE: asked its own least width, the column asks its items theirs', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(_column(log));
    final line = tester.renderObject<RenderBox>(find.byType(FlexLine));
    expect(line.getMinIntrinsicWidth(double.infinity), 300);
    expect(log, isNotEmpty);
  });
}
