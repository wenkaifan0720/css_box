// AN ITEM NO WIDER THAN THE WIDTH THE BOXES ABOVE LAY THE GRID OUT AT IS
// PLACED BY AN `Align` WHERE THE GRID PLACES IT. A grid of no columns has one
// `auto` column (css-grid-1 7.5), floored at the widths its items state
// (11.5, 6.6) and stretched into the grid's width (11.8); an item that states
// its width stands at its point of it (css-align-3 6.1) -- the grid's own
// point wherever the grid is at least as wide as the item, which is all an
// `Align` does (`RenderPositionedBox`), and it squeezes only an item wider.
// The lowerer reads that width off the layout where the walk to the room does
// not (`lossy_grid.dart`, `_laidOutAtL`): an item of a flex line css_box keeps
// is never laid out under its floor, its child's least width or its own
// length, whichever is less (`flex_line.dart`, 4.5 and 9.7) -- a 20px tile's
// least is 20 -- and a rigid child of a `Row` is laid out with no bound along
// it (`RenderFlex._constraintsForNonFlexChild`). A product site's icon buttons are
// 20px `display: grid; place-items: center` boxes round a 13px `overflow:
// hidden` icon in such lines and rows; this pins the `Align` to css_box's
// boxes in a line with room to spare and one too narrow for the tile (the
// line floors it), with the item held to its own length or grown from
// nothing, in an inner line of an item that may shrink under it, rigid in a
// row, and stretched down its row at its end
// (`fixtures/grid-item-stated-unread-room`). A price-table site's menu is laid
// over the page in a box of the window's size, held at its corner by a
// `Positioned` that pins no width (`StackParentData.
// positionedChildConstraints`), its stack's fill, and the `OverflowBox` a
// `LayoutBuilder` returns round a floor of 32, which lets out at least what
// the builder is handed (`_RenderLayoutBuilder.performLayout`); this pins
// the `Align` there too, from the narrowest window up.
// NEGATIVE: an item of the line that states a floor of nothing (`min-width:
// 0`), which the line shrinks under the icon, where css_box hangs the icon
// out of the grid and the `Align` squeezes it; an icon wider than its tile;
// and the menu's stack held 10 wide, which leaves the tile nothing.
import 'dart:math' as math;

import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

ValueKey<String> _k(String name) => ValueKey(name);

Widget _icon(double w) => SizedBox(
  key: _k('icon'),
  width: w,
  height: w,
  child: ClipRect(
    child: SizedBox(width: w, height: w),
  ),
);

/// The tile as css_box lays it out, and as the lowerer writes it.
Widget _grid(double w) => Tracks(
  align: CellAlign.center,
  justify: CellAlign.center,
  children: [TrackCell(width: w, height: w, clips: true, child: _icon(w))],
);
Widget _stock(double w) => Align(child: _icon(w));

Widget _tile(Widget grid) => SizedBox(key: _k('tile'), width: 20, height: 20, child: grid);

/// The tile as an item of a flex line beside a label.
Widget _line(Widget grid, {double? mainSize, double? min, double grow = 0, double? basis}) => FlexLine(
  children: [
    FlexCell(mainSize: mainSize, min: min, grow: grow, basis: basis, child: _tile(grid)),
    FlexCell(child: Text('Linear', key: _k('label'))),
  ],
);

/// The page: [w] in a room [room] wide.
Widget _page(Widget w, double room) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(key: _k('room'), width: room, child: w),
  ),
);

/// The rects of the icon, the tile and the label, laid out in [room].
Future<Map<String, Rect>> _rects(WidgetTester t, Widget w, double room) async {
  await t.pumpWidget(_page(w, room));
  final e = t.takeException();
  expect(e == null || e.toString().contains('overflowed'), isTrue, reason: '$e');
  return {
    for (final k in ['icon', 'tile', 'label']) k: t.getRect(find.byKey(_k(k))),
  };
}

void main() {
  for (final room in const [300.0, 40.0, 10.0]) {
    for (final (name, mainSize, grow, basis) in const [
      ('of its content', null, 0.0, null),
      ('held to its 20', 20.0, 0.0, null),
      ('grown from nothing', null, 1.0, 0.0),
    ]) {
      testWidgets('an item of a flex line $name, in a room $room wide', (t) async {
        final css = await _rects(t, _line(_grid(13), mainSize: mainSize, grow: grow, basis: basis), room);
        final out = await _rects(t, _line(_stock(13), mainSize: mainSize, grow: grow, basis: basis), room);
        expect(out, css);
        // The line never lays the tile out under its least width.
        expect(css['tile']!.width, greaterThanOrEqualTo(20));
        expect(css['icon']!.left - css['tile']!.left, (css['tile']!.width - 13) / 2);
      });
    }
    testWidgets('in an inner line of an item that may shrink under it, in a room $room wide', (t) async {
      Widget page(Widget grid) => FlexLine(
        children: [
          const FlexCell(grow: 1, basisFraction: 0, child: SizedBox(height: 10)),
          FlexCell(min: 0, child: _line(grid)),
        ],
      );
      final css = await _rects(t, page(_grid(13)), room);
      final out = await _rects(t, page(_stock(13)), room);
      expect(out, css);
    });
    testWidgets('rigid in a row, in a room $room wide', (t) async {
      Widget page(Widget grid) => Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Padding(padding: const EdgeInsets.only(left: 8), child: _tile(grid)),
              ),
            ],
          ),
          Text('Linear', key: _k('label')),
        ],
      );
      final css = await _rects(t, page(_grid(13)), room);
      final out = await _rects(t, page(_stock(13)), room);
      expect(out, css);
      expect(css['tile']!.width, 20);
    });
    testWidgets('stretched down its row, at its end, in a room $room wide', (t) async {
      Widget page(Widget grid) => FlexLine(
        children: [
          FlexCell(
            mainSize: 28,
            child: SizedBox(key: _k('tile'), width: 28, height: 28, child: grid),
          ),
          FlexCell(child: Text('Inbox', key: _k('label'))),
        ],
      );
      final css = await _rects(
        t,
        page(
          Tracks(
            justify: CellAlign.end,
            children: [TrackCell(width: 13, child: SizedBox(key: _k('icon'), width: 13))],
          ),
        ),
        room,
      );
      final out = await _rects(
        t,
        page(
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: SizedBox(
              height: double.infinity,
              child: SizedBox(key: _k('icon'), width: 13),
            ),
          ),
        ),
        room,
      );
      expect(out, css);
      expect(css['icon']!.height, 28);
    });
  }

  /// The menu over the page: the tile in a column of a `LayoutBuilder`'s
  /// box round a floor of 32, in the fill of a stack held by [hold].
  Widget menu(Widget grid, Widget Function(Widget stack) hold) => Stack(
    children: [
      Positioned(
        left: 0,
        top: 0,
        child: FixedLayer(
          child: hold(
            Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, box) => OverflowBox(
                            maxWidth: math.max(box.maxWidth, 32),
                            fit: OverflowBoxFit.deferToChild,
                            alignment: AlignmentDirectional.topStart,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 32),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _tile(grid),
                                    Text('Linear', key: _k('label')),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
  for (final window in const [320.0, 400.0]) {
    testWidgets('in a menu over the page, in a window $window wide', (t) async {
      Widget page(Widget grid) => MediaQuery(
        data: MediaQueryData(size: Size(window, 600)),
        child: Builder(
          builder: (context) =>
              menu(grid, (stack) => SizedBox.fromSize(size: MediaQuery.sizeOf(context), child: stack)),
        ),
      );
      final css = await _rects(t, page(_grid(13)), window);
      final out = await _rects(t, page(_stock(13)), window);
      expect(out, css);
      expect(css['tile']!.width, window - 32);
    });
  }

  testWidgets('NEGATIVE: the menu\'s stack held 10 wide leaves the tile nothing', (t) async {
    Widget page(Widget grid) => menu(grid, (stack) => SizedBox(width: 10, height: 600, child: stack));
    final css = await _rects(t, page(_grid(13)), 320);
    final out = await _rects(t, page(_stock(13)), 320);
    expect(css['tile']!.width, 0);
    expect(out['icon'], isNot(css['icon']));
  });

  testWidgets('NEGATIVE: an item of a line that states a floor of nothing is shrunk under the icon', (t) async {
    final css = await _rects(t, _line(_grid(13), min: 0), 10);
    final out = await _rects(t, _line(_stock(13), min: 0), 10);
    expect(css['tile']!.width, lessThan(13));
    expect(css['icon']!.width, 13);
    expect(out['icon'], isNot(css['icon']));
  });

  testWidgets('NEGATIVE: an icon wider than its tile', (t) async {
    final css = await _rects(t, _line(_grid(30)), 300);
    final out = await _rects(t, _line(_stock(30)), 300);
    expect(css['icon']!.width, 30);
    expect(out['icon'], isNot(css['icon']));
  });
}
