// DOWN A COLUMN AN ITEM CONTRIBUTES ITS HYPOTHETICAL LENGTH (css-flexbox-1
// 9.3 step 4; Blink's `FlexLayoutAlgorithm::MainAxisContentExtent`). A
// column whose height nobody stated is as tall as its items' hypothetical
// outer main sizes and the gaps between them -- each base size held by its
// own floor and cap -- and not 9.9.1's contributions, where a `height`
// beside a basis of the item's own counted. A docs site's code sandboxes are
// each a column of `max-height: 406px` round a body of `flex: 1;
// min-height: 0; height: 60px`, two of them side by side in a wrapping row
// over a tab bar: Chrome draws the columns and the body 0 deep and the tab
// bar 1 down (`fixtures/flex-wrap-runs-whole-frame` n2), where FlexLine
// made the column 60 and put everything under it 60 low.
// `fixtures/flex-column-hypothetical-height` is the column alone. This pins
// FlexLine's column to those boxes, laid out and asked its height, at
// several widths: a `0%` basis of a column with no height is the body's
// content (7.2.3) -- nothing (p1), or the 30 it holds (p2) -- and a basis
// of `0px` under a written floor of 0 is nothing round 30 of content (p3).
// NEGATIVE: a height that IS the basis, 60 (n1); a basis of 0 whose
// automatic floor is the content's 30 (n2, 4.5); a column of a stated
// height, which the body grows into (n3).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

Widget _frame(Widget child, double width) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: child),
  ),
);

/// The body: a box of [content] (none where null), the item's own.
Widget _body({double? content}) => ColoredBox(
  key: const ValueKey('b'),
  color: const Color(0xFF336699),
  child: content == null ? null : SizedBox(height: content),
);

/// The docs site's column: `display: flex; flex-direction: column; max-height:
/// 406px` round one item.
Widget _column(FlexCell body) =>
    FlexLine(key: const ValueKey('c'), direction: Axis.vertical, maxExtent: 406, children: [body]);

/// `flex: 1; min-height: 0; height: 60px`: a `0%` basis, written where the
/// column has no height as the content it stands for.
FlexCell _react({double? content}) => FlexCell(
  grow: 1,
  mainSize: 60,
  min: 0,
  basisKeyword: FlexKeyword.content,
  child: _body(content: content),
);

Future<List<Rect>> _rects(WidgetTester t, Widget w, [List<String> keys = const ['c', 'b']]) async {
  t.view
    ..physicalSize = const Size(1440, 900)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(w);
  return [for (final k in keys) t.getRect(find.byKey(ValueKey(k)))];
}

void main() {
  for (final width in const [499.5, 300.0, 120.0]) {
    for (final asked in const [false, true]) {
      Widget at(FlexCell body) {
        final column = _column(body);
        return _frame(asked ? IntrinsicHeight(child: column) : column, width);
      }

      final how = asked ? 'asked its height' : 'laid out';
      testWidgets('p1: a height beside a basis of nothing is not counted, $width wide, $how', (t) async {
        expect(await _rects(t, at(_react())), [Rect.fromLTWH(0, 0, width, 0), Rect.fromLTWH(0, 0, width, 0)]);
      });
      testWidgets('p2: the content the basis stands for is, $width wide, $how', (t) async {
        expect(await _rects(t, at(_react(content: 30))), [
          Rect.fromLTWH(0, 0, width, 30),
          Rect.fromLTWH(0, 0, width, 30),
        ]);
      });
      testWidgets('p3: a basis of 0 under a written floor of 0 is nothing round content, $width wide, $how', (t) async {
        final body = FlexCell(grow: 1, basis: 0, mainSize: 60, min: 0, child: _body(content: 30));
        expect(await _rects(t, at(body)), [Rect.fromLTWH(0, 0, width, 0), Rect.fromLTWH(0, 0, width, 0)]);
      });
      testWidgets('n1: NEGATIVE, a height that is the basis is counted, $width wide, $how', (t) async {
        expect(await _rects(t, at(FlexCell(mainSize: 60, child: _body()))), [
          Rect.fromLTWH(0, 0, width, 60),
          Rect.fromLTWH(0, 0, width, 60),
        ]);
      });
      testWidgets('n2: NEGATIVE, a basis of 0 is held at its content by its automatic floor, $width wide, $how', (
        t,
      ) async {
        final body = FlexCell(grow: 1, basis: 0, child: _body(content: 30));
        expect(await _rects(t, at(body)), [Rect.fromLTWH(0, 0, width, 30), Rect.fromLTWH(0, 0, width, 30)]);
      });
    }
    testWidgets('n3: NEGATIVE, a column of a stated height is grown into, $width wide', (t) async {
      final w = _frame(SizedBox(height: 200, child: _column(_react(content: 30))), width);
      expect(await _rects(t, w), [Rect.fromLTWH(0, 0, width, 200), Rect.fromLTWH(0, 0, width, 200)]);
    });
  }

  // The docs site's desktop sandbox, Chrome's boxes off `fixtures/flex-wrap-
  // runs-whole-frame` n2 (the line at 16,754): two growers of `min-width:
  // 431px` side by side, the first the column, over a tab bar of `width:
  // 100%; padding: 4px`, in a wrap 1000 wide with a 1px gap.
  testWidgets('p4: the sandbox row: the columns 0 deep, the tab bar 1 down', (t) async {
    FlexCell grower(Widget child) =>
        FlexCell(grow: 1, basisFraction: 0, mainSizeFraction: 1, min: 431, crossMax: 406, child: child);
    final row = FlexLine(
      key: const ValueKey('row'),
      wrap: true,
      spacing: 1,
      runSpacing: 1,
      children: [
        grower(ConstrainedBox(constraints: const BoxConstraints(maxHeight: 406), child: _column(_react()))),
        grower(
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 406),
            child: const ColoredBox(key: ValueKey('d'), color: Color(0xFF993366)),
          ),
        ),
        FlexCell(
          mainSizeFraction: 1,
          frame: const EdgeInsets.all(4),
          child: const Padding(key: ValueKey('t'), padding: EdgeInsets.all(4), child: SizedBox(height: 20)),
        ),
      ],
    );
    expect(await _rects(t, _frame(row, 1000), const ['row', 'c', 'b', 'd', 't']), [
      const Rect.fromLTWH(0, 0, 1000, 29),
      const Rect.fromLTWH(0, 0, 499.5, 0),
      const Rect.fromLTWH(0, 0, 499.5, 0),
      const Rect.fromLTWH(500.5, 0, 499.5, 0),
      const Rect.fromLTWH(0, 1, 1000, 28),
    ]);
  });
}
