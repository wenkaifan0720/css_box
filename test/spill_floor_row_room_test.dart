// A BOX SPILLED DOWN THE PAGE WITH ITS FLOOR KEPT HANDS THE WIDTH ON AS IT
// CAME. `Spill(axis: Axis.vertical, floor: true)` touches the height alone:
// it takes the ceiling off down the page and keeps the floor it is offered
// there (`spill.dart`, `_inner`), and the width -- the room, its floor and
// its ceiling -- reaches the child as it reached the box, whose intrinsic
// widths are the child's. So the room a paragraph in it is laid out in is
// the room above the box, as under a `Spill` that keeps no floor.
// A news site's header: a `<button>` 32px tall round a 24px icon, its label
// centred by the button (css-align-3 4.4, safe: Chrome centres a button's
// content from the top where it overflows), is that box, written first in a
// row of items of their own widths -- the menu button, the logo, the
// section links -- that stands at the start of a `space-between` bar, the
// account links and another such button at its end
// (`fixtures/flex-row-rigid-past-room`). Read as no room at all, the icon's
// line stayed a css_box line box past the pass that writes the row, which
// took the button for an item that may shrink: the row came out unhung with
// a `Flexible` round the button, and the bar's end item passed the room
// left to it with Flutter's band over it -- 178px at 1024. This pins the
// stock spelling the lowerer writes for the bar -- each row of rigid items
// hung from its start in an `OverflowBox` as wide as its slot, the button's
// spill an `OverflowBox` down the page that keeps its floor -- to css_box's
// lines, with the bar wide enough for both rows, short for the end one, and
// short for more than all of it.
// NEGATIVE: the unhung spelling with the `Flexible` round the button reports
// the overflow and shrinks the button; a `Spill` across the page, or both
// ways, lays its child out with no bound on the width, which is no room.
import 'package:css_box/css_box.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The test font draws every glyph 14px wide; a line is 18 tall.
const _style = TextStyle(fontSize: 14, height: 18 / 14);
const _keys = [
  ValueKey('start'),
  ValueKey('menu'),
  ValueKey('menuIcon'),
  ValueKey('logo'),
  ValueKey('US'),
  ValueKey('World'),
  ValueKey('end'),
  ValueKey('Watch'),
  ValueKey('Listen'),
  ValueKey('search'),
  ValueKey('searchIcon'),
];

Widget _page(double width, Widget bar) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: bar),
  ),
);

// The button's content: its icon, centred down a box of 32 by the button.
Widget _icon(String key) => Column(
  mainAxisSize: MainAxisSize.min,
  mainAxisAlignment: MainAxisAlignment.center,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [SizedBox(key: ValueKey('${key}Icon'), width: 24, height: 24)],
);

// css_box's button and the stock one.
Widget _buttonLine(String key) => SizedBox(
  key: ValueKey(key),
  height: 32,
  child: ShrinkWidth(
    child: Spill(axis: Axis.vertical, floor: true, child: _icon(key)),
  ),
);
Widget _buttonStock(String key) => SizedBox(
  key: ValueKey(key),
  height: 32,
  child: IntrinsicWidth(
    child: OverflowBox(
      maxHeight: double.infinity,
      fit: OverflowBoxFit.deferToChild,
      alignment: Alignment.topLeft,
      child: _icon(key),
    ),
  ),
);

Widget _link(String words) => SizedBox(
  height: 40,
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Center(
      widthFactor: 1,
      child: Text(words, key: ValueKey(words), softWrap: false, style: _style),
    ),
  ),
);
Widget _words(String words) => Text(words, key: ValueKey(words), softWrap: false, style: _style);
const _logo = SizedBox(key: ValueKey('logo'), width: 46, height: 22);

/// The bar as css_box lays it out: the start row never shrinks
/// (`flex-shrink: 0`), the end one shrinks by nothing that gives.
Widget _bar() => FlexLine(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    FlexCell(
      shrink: 0,
      child: SizedBox(
        key: const ValueKey('start'),
        height: 40,
        child: FlexLine(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FlexCell(margin: const EdgeInsets.only(right: 24), child: _buttonLine('menu')),
            const FlexCell(child: _logo),
            FlexCell(margin: const EdgeInsets.only(left: 12), child: _link('US')),
            FlexCell(child: _link('World')),
          ],
        ),
      ),
    ),
    FlexCell(
      child: SizedBox(
        key: const ValueKey('end'),
        height: 40,
        child: FlexLine(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FlexCell(margin: const EdgeInsets.only(right: 24), child: _words('Watch')),
            FlexCell(margin: const EdgeInsets.only(right: 24), child: _words('Listen')),
            FlexCell(margin: const EdgeInsets.only(right: 12), child: _buttonLine('search')),
          ],
        ),
      ),
    ),
  ],
);

// A row of rigid items hung from its start in its slot.
Widget _hung(List<Widget> children) => OverflowBox(
  maxWidth: double.infinity,
  fit: OverflowBoxFit.deferToChild,
  alignment: AlignmentDirectional.centerStart,
  child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: children),
);

/// The bar as the lowerer writes it; [regressed], as it wrote it with the
/// button taken for an item that may shrink.
Widget _barStock({bool regressed = false}) {
  Widget start = regressed
      ? Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Padding(padding: const EdgeInsets.only(right: 24), child: _buttonStock('menu')),
            ),
            _logo,
            Padding(padding: const EdgeInsets.only(left: 12), child: _link('US')),
            _link('World'),
          ],
        )
      : _hung([
          Padding(padding: const EdgeInsets.only(right: 24), child: _buttonStock('menu')),
          _logo,
          Padding(padding: const EdgeInsets.only(left: 12), child: _link('US')),
          _link('World'),
        ]);
  final endItems = [
    Padding(padding: const EdgeInsets.only(right: 24), child: _words('Watch')),
    Padding(padding: const EdgeInsets.only(right: 24), child: _words('Listen')),
    regressed
        ? Flexible(
            child: Padding(padding: const EdgeInsets.only(right: 12), child: _buttonStock('search')),
          )
        : Padding(padding: const EdgeInsets.only(right: 12), child: _buttonStock('search')),
  ];
  final end = regressed
      ? IntrinsicWidth(
          child: SizedBox(
            key: const ValueKey('end'),
            height: 40,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: endItems,
            ),
          ),
        )
      : OverflowBox(
          maxWidth: double.infinity,
          fit: OverflowBoxFit.deferToChild,
          alignment: AlignmentDirectional.topStart,
          child: IntrinsicWidth(
            child: SizedBox(
              key: const ValueKey('end'),
              height: 40,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: endItems,
              ),
            ),
          ),
        );
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      IntrinsicWidth(
        child: SizedBox(key: const ValueKey('start'), height: 40, child: start),
      ),
      Flexible(child: end),
    ],
  );
}

Future<Map<Key, Rect>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  return {for (final k in _keys) k: t.getRect(find.byKey(k))};
}

void main() {
  // The start row is 24 + 24 + 46 + 12 + 52 + 94 = 252 wide, the end row
  // 70 + 24 + 84 + 24 + 24 + 12 = 238: 490 in all.
  // Never short of the start row's 252: the bar the lowerer writes as a
  // `Row` is one its rows fit at every window it reads.
  for (final width in const [640.0, 490.0, 400.0, 300.0, 260.0]) {
    testWidgets('a bar $width wide: the stock rows stand where css_box lays them, and none reports an overflow', (
      t,
    ) async {
      final line = await _rects(t, _page(width, _bar()));
      final stock = await _rects(t, _page(width, _barStock()));
      expect(t.takeException(), isNull);
      expect(stock, line);
      // The buttons keep their icons' width, and the icons stand in their
      // middles, down a box of 32.
      for (final b in const ['menu', 'search']) {
        expect(stock[ValueKey(b)]!.size, const Size(24, 32));
        expect(stock[ValueKey('${b}Icon')]!.top - stock[ValueKey(b)]!.top, 4);
      }
      // Short of room the end row starts where the start row ends, and
      // runs past the bar.
      if (width < 490) expect(stock[const ValueKey('end')]!.left, 252);
    });
  }

  testWidgets(
    'NEGATIVE: unhung, with the button taken for an item that may shrink, the end row reports what passes its slot',
    (t) async {
      await t.pumpWidget(_page(400, _barStock(regressed: true)));
      expect(t.takeException(), isA<FlutterError>());
      final narrow = t.getRect(find.byKey(const ValueKey('search')));
      expect(narrow.width, lessThan(24));
    },
  );

  // The room a box spilled down the page hands its child: as wide as
  // [width] at the most, 20 tall exactly.
  Widget offer(double? width, Widget Function(Widget) spill) => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width ?? double.infinity, minHeight: 20, maxHeight: 20),
        child: spill(Text('copper stint dunlin', key: const ValueKey('words'), style: _style)),
      ),
    ),
  );

  for (final width in const [400.0, 120.0, 60.0]) {
    testWidgets('a spill down the page that keeps its floor lays its words out in the room above it, $width wide', (
      t,
    ) async {
      await t.pumpWidget(offer(width, (w) => Spill(axis: Axis.vertical, child: w)));
      final plain = t.getRect(find.byKey(const ValueKey('words')));
      await t.pumpWidget(offer(width, (w) => Spill(axis: Axis.vertical, floor: true, child: w)));
      final floored = t.getRect(find.byKey(const ValueKey('words')));
      // The same width at the same place; the floor is the height's.
      expect(floored.topLeft, plain.topLeft);
      expect(floored.width, plain.width);
      expect(floored.width, width < 266 ? lessThanOrEqualTo(width) : 266);
      expect(floored.height, greaterThanOrEqualTo(20));
    });
  }

  testWidgets('a spill down the page that keeps its floor answers its child\'s widths', (t) async {
    await t.pumpWidget(
      offer(null, (w) => Spill(key: const ValueKey('spill'), axis: Axis.vertical, floor: true, child: w)),
    );
    final box = t.renderObject<RenderBox>(find.byKey(const ValueKey('spill')));
    final words = t.renderObject<RenderBox>(find.byKey(const ValueKey('words')));
    for (final h in const [20.0, double.infinity]) {
      expect(box.getMinIntrinsicWidth(h), words.getMinIntrinsicWidth(h));
      expect(box.getMaxIntrinsicWidth(h), words.getMaxIntrinsicWidth(h));
    }
  });

  testWidgets('NEGATIVE: a spill across the page, or both ways, lays its words out with no bound on the width', (
    t,
  ) async {
    for (final axis in const [Axis.horizontal, null]) {
      await t.pumpWidget(offer(60, (w) => Spill(axis: axis, child: w)));
      expect(t.getRect(find.byKey(const ValueKey('words'))).width, 266, reason: '$axis');
    }
  });
}
