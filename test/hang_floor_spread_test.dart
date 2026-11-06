// A SPREAD LINE SHORT OF ROOM FALLS BACK TO ITS START, AND A BOX THAT KEEPS
// ITS FLOOR HOLDS IT THERE WITHOUT THE OVERFLOW BAND (css-align-3 4.3, 4.4:
// `space-between` falls back to its start, `space-around` and
// `space-evenly` to `safe center`, the start of a subject that overflows).
// A `RenderFlex` packs a line it has no room for at its start too -- it
// clamps the free space at nothing -- but paints its band over the end and
// reports a `FlutterError`. The lowerer
// writes three such lines hung in a box of no ceiling along them and the
// slot's floor kept, so each spreads what is left where it fits:
//   - a ROW of rigid items past the most a box above offers it
//     (`fixtures/flex-overflow-justify` b26: three 90px items in a 200px
//     `space-around` row): `OverflowBox(maxWidth: double.infinity,
//     alignment: Alignment.centerLeft, child: Row(...))`;
//   - a COLUMN whose items give nothing up, one round a block with a
//     `min-height` of its own, in an item its card shrinks
//     (`fixtures/flex-column-never-short` d4): `OverflowBox(fit:
//     OverflowBoxFit.deferToChild, maxHeight: double.infinity, alignment:
//     Alignment.topCenter, child: Column(...))`;
//   - a BLOCK's content under `align-content: safe end` (and the two
//     spreads, which fall back to `safe center`) taller than the box
//     (`fixtures/safe-align` b27):
//     `Spill(axis: Axis.vertical, floor: true, child: Column(...))`, which
//     the stock pass writes `OverflowBox(maxHeight: double.infinity, fit:
//     OverflowBoxFit.deferToChild, alignment: Alignment.topLeft, ...)`.
// This pins each to css_box's line (the first two) or to CSS's own numbers
// (the third) with the room shorter than the content, as long as it and
// longer.
// NEGATIVE: the same lines unhung report the overflow; an UNSAFE `end` is
// not the start, which is why the lowerer leaves it alone.
import 'package:css_box/css_box.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The test font draws every glyph 14px wide and 14px tall at 14px.
const _style = TextStyle(fontSize: 14, height: 18 / 14);

Widget _page(Widget w) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(alignment: Alignment.topLeft, child: w),
);

Future<Map<Key, Rect>> _rects(WidgetTester t, Widget w, List<Key> keys) async {
  await t.pumpWidget(_page(w));
  return {for (final k in keys) k: t.getRect(find.byKey(k))};
}

// ------------------------------------------------------------------ rows

const _rowKeys = [ValueKey('row'), ValueKey('a'), ValueKey('b'), ValueKey('c')];

List<Widget> get _boxes => [
  for (final k in const ['a', 'b', 'c']) SizedBox(key: ValueKey(k), width: 90, height: 40),
];

Widget _slot(double width, Widget row) => SizedBox(key: const ValueKey('row'), width: width, height: 40, child: row);

Widget _rowLine(MainAxisAlignment main) => FlexLine(
  mainAxisAlignment: main,
  children: [for (final b in _boxes) FlexCell(shrink: 0, mainSize: 90, child: b)],
);

Widget _rowHung(MainAxisAlignment main) => OverflowBox(
  maxWidth: double.infinity,
  alignment: Alignment.centerLeft,
  child: Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: main,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: _boxes,
  ),
);

// --------------------------------------------------------------- columns

const _colKeys = [ValueKey('card'), ValueKey('inner'), ValueKey('first'), ValueKey('second')];

Widget get _first => ColoredBox(
  key: const ValueKey('first'),
  color: const Color(0xFFFF9F1C),
  child: ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 30),
    child: const Text('olive', style: _style),
  ),
);
const _second = ColoredBox(
  key: ValueKey('second'),
  color: Color(0xFFCBF3F0),
  child: Text('wigeon', style: _style),
);

Widget _card(double height, Widget inner) => SizedBox(
  key: const ValueKey('card'),
  width: 300,
  height: height,
  child: FlexLine(
    direction: Axis.vertical,
    spacing: 16,
    children: [
      const FlexCell(mainSize: 40, min: 0, clips: true, child: SizedBox.shrink()),
      FlexCell(
        grow: 1,
        crossSizeFraction: 0.618,
        min: 0,
        child: KeyedSubtree(key: const ValueKey('inner'), child: inner),
      ),
    ],
  ),
);

Widget get _colLine => FlexLine(
  direction: Axis.vertical,
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  spacing: 8,
  children: [
    FlexCell(child: _first),
    const FlexCell(child: _second),
  ],
);

Widget _colHung({bool hung = true}) {
  final column = Column(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 8,
    children: [_first, _second],
  );
  return hung
      ? OverflowBox(
          fit: OverflowBoxFit.deferToChild,
          maxHeight: double.infinity,
          alignment: Alignment.topCenter,
          child: column,
        )
      : column;
}

// ---------------------------------------------------------------- blocks

const _blockKeys = [ValueKey('box'), ValueKey('one'), ValueKey('two')];

Widget _block(double height, MainAxisAlignment along, {required String spelling}) {
  final column = Column(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: along,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: const [
      SizedBox(key: ValueKey('one'), height: 40),
      SizedBox(key: ValueKey('two'), height: 40),
    ],
  );
  return SizedBox(
    key: const ValueKey('box'),
    width: 120,
    height: height,
    child: switch (spelling) {
      'spill' => Spill(axis: Axis.vertical, floor: true, child: column),
      'stock' => OverflowBox(
        maxHeight: double.infinity,
        fit: OverflowBoxFit.deferToChild,
        alignment: Alignment.topLeft,
        child: column,
      ),
      _ => column,
    },
  );
}

void main() {
  for (final main in const [
    MainAxisAlignment.spaceBetween,
    MainAxisAlignment.spaceAround,
    MainAxisAlignment.spaceEvenly,
  ]) {
    for (final width in const [200.0, 270.0, 300.0, 420.0]) {
      testWidgets('a ${main.name} row hung with its floor stands where the line does, $width wide', (t) async {
        final line = await _rects(t, _slot(width, _rowLine(main)), _rowKeys);
        final hung = await _rects(t, _slot(width, _rowHung(main)), _rowKeys);
        expect(t.takeException(), isNull);
        expect(hung, line);
        // Short of room the items are at the start, one after another.
        if (width < 270) expect(hung[const ValueKey('b')]!.left, 90);
      });
    }
  }

  testWidgets('NEGATIVE: the row unhung reports what passes its end', (t) async {
    await t.pumpWidget(
      _page(
        _slot(
          200,
          Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.spaceAround, children: _boxes),
        ),
      ),
    );
    expect(t.takeException(), isA<FlutterError>());
  });

  for (final height in const [50.0, 72.0, 120.0, 200.0]) {
    testWidgets(
      'a spread column of items that give nothing up, hung with its floor, stands where the line does: card $height',
      (t) async {
        final line = await _rects(t, _card(height, _colLine), _colKeys);
        final hung = await _rects(t, _card(height, _colHung()), _colKeys);
        expect(t.takeException(), isNull);
        expect(hung, line);
        // The first item keeps its block's floor.
        expect(hung[const ValueKey('first')]!.height, 30);
      },
    );
  }

  testWidgets('NEGATIVE: the column unhung, in the item its card shrinks, reports what passes its end', (t) async {
    await t.pumpWidget(_page(_card(50, _colHung(hung: false))));
    expect(t.takeException(), isA<FlutterError>());
  });

  for (final (along, at) in const [(MainAxisAlignment.end, 1.0), (MainAxisAlignment.center, 0.5)]) {
    for (final height in const [60.0, 80.0, 140.0]) {
      testWidgets(
        'a block aligned safe ${along.name}, $height tall: the content at its place where it fits, at the top where not',
        (t) async {
          // CSS: the free space is the box's height less the content's 80,
          // handed out where it is not negative, and nothing where it is.
          final free = height - 80 > 0 ? (height - 80) * at : 0.0;
          for (final spelling in const ['spill', 'stock']) {
            final r = await _rects(t, _block(height, along, spelling: spelling), _blockKeys);
            expect(t.takeException(), isNull, reason: spelling);
            expect(r[const ValueKey('box')]!.height, height, reason: spelling);
            expect(r[const ValueKey('one')]!.top, free, reason: spelling);
            expect(r[const ValueKey('two')]!.top, free + 40, reason: spelling);
          }
        },
      );
    }
  }

  testWidgets('NEGATIVE: the block unspilled reports what passes its end', (t) async {
    await t.pumpWidget(_page(_block(60, MainAxisAlignment.end, spelling: 'plain')));
    expect(t.takeException(), isA<FlutterError>());
  });

  testWidgets('NEGATIVE: an UNSAFE end hangs the content out of the top, which the spill does not', (t) async {
    // CSS: 20 of the 80 above the box's top (css-align-3 4.4, `unsafe`).
    final r = await _rects(t, _block(60, MainAxisAlignment.end, spelling: 'spill'), _blockKeys);
    expect(r[const ValueKey('one')]!.top, isNot(60 - 80));
    expect(r[const ValueKey('one')]!.top, 0);
  });
}
