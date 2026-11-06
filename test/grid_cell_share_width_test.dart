// A GRID ITEM OF A STATED WIDTH IN A SHARE OF A ROW THE GRID STRETCHES IS
// THAT WIDE, AND AS TALL AS ITS CONTENT AT THAT WIDTH (css-grid-1 6.2;
// css-align-3 6.1: only an `auto` width is stretched over the area; css-grid-1
// 11.7, an `fr` of what the room leaves). The stock pass writes such a row as
// an `IntrinsicHeight` round a `Row` of `Expanded` shares, and asks each
// item its height at its share's width (`RenderFlex._getIntrinsicSize`).
// Under an `Align` and a `SizedBox` of the item's width that question
// reaches the content at the SHARE's width
// (`RenderConstrainedBox.computeMaxIntrinsicHeight` passes the width it is
// asked at on), so text narrower than its column was measured a line short:
// `fixtures/grid-cell-own-width` p2, a card of `width: 200px` in the first of
// two `1fr` columns, 21 tall where it is 42. The lowerer writes the item a `Row` of it -- which asks
// a child it does not flex its height at the child's own greatest width --
// hung from its area in an `OverflowBox` of no width bound, so the item may
// pass a column narrower than it as CSS lets it:
//   OverflowBox(minWidth: 0, maxWidth: double.infinity,
//       fit: OverflowBoxFit.deferToChild,
//       alignment: AlignmentDirectional.centerStart,
//       child: Row(mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.stretch, children: [item]))
// This pins it to CSS's numbers with the column wider than the item, as wide
// as its text, and narrower than it.
// NEGATIVE: the `Align` it replaces measures the text at the column's width;
// the `Row` alone reports what the item passes a narrower column by.
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The test font draws every glyph 14px wide; a line is 18 tall.
const _style = TextStyle(fontSize: 14, height: 18 / 14);
// 18 glyphs: 252 on one line; at 200, `abcdef ghijkl` (182) and `mnop`.
const _text = 'abcdef ghijkl mnop';
const _item = ValueKey('item');
const _grid = ValueKey('grid');

Widget get _card => const SizedBox(
  key: _item,
  width: 200,
  child: Text(_text, style: _style),
);

Widget _hung() => OverflowBox(
  minWidth: 0,
  maxWidth: double.infinity,
  fit: OverflowBoxFit.deferToChild,
  alignment: AlignmentDirectional.centerStart,
  child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [_card]),
);

Widget _aligned() => Align(
  alignment: AlignmentDirectional.centerStart,
  child: SizedBox(height: double.infinity, child: _card),
);

Widget _rowAlone() => Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_card]);

// Two `1fr` columns, the item in the first, the row stretched.
Widget _page(double width, Widget cell) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      key: _grid,
      width: width,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: cell),
            const Spacer(),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  // The grid 300, 500 and 1408 wide: columns of 150, 250 and 704.
  for (final width in const [300.0, 500.0, 1408.0]) {
    testWidgets('an item of a stated width in a share is that wide and its text\'s height there: grid $width', (
      t,
    ) async {
      await t.pumpWidget(_page(width, _hung()));
      expect(t.takeException(), isNull);
      final item = t.getRect(find.byKey(_item));
      // CSS: 200 wide at the area's start, two lines at 200, and the row as
      // tall as it.
      expect(item, const Rect.fromLTWH(0, 0, 200, 36));
      expect(t.getRect(find.byKey(_grid)).height, 36);
    });
  }

  testWidgets('NEGATIVE: under an Align the text is measured at the column\'s width', (t) async {
    await t.pumpWidget(_page(1408, _aligned()));
    // Asked at 704, one line: the row stands 18 tall and holds the item to it.
    expect(t.getRect(find.byKey(_grid)).height, 18);
    expect(t.getRect(find.byKey(_item)).height, isNot(36));
    // In a column narrower than the item, the `Align` holds it to the column.
    await t.pumpWidget(_page(300, _aligned()));
    expect(t.getRect(find.byKey(_item)).width, 150);
  });

  testWidgets('NEGATIVE: the Row alone reports what the item passes a narrower column by', (t) async {
    await t.pumpWidget(_page(300, _rowAlone()));
    expect(t.takeException(), isA<FlutterError>());
  });
}
