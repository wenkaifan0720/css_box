// A COLUMN THAT MAY BE LAID OUT WITH NO BOUND DOWN IT HANGS AS ONE HELD TO
// A HEIGHT DOES, wherever a box above holds it to one: down a column of no
// height its items' heights are their own, and held to less it is that
// height and they pass its end (css-flexbox-1 9.7 never shrinks an item
// below its automatic minimum; css-align-3 4.3). A `Column` held to less
// reports what passes its end (`RenderFlex` paints the band and throws);
// the stock pass writes the column inside an `OverflowBox` of no ceiling
// down, from its top: the
// `Column` is its content's height there and the box is the height it is
// held to. A product site's menu columns, a list at `grid-row: 1 / span 2` round
// its share of the grid's rows (css-grid-1 11.5), measured for the track
// with no bound and then held to the share: under `0.5fr` the list of 52 is
// held to 26 (`fixtures/grid-row-share-span-auto` n3). This pins the two
// spellings to the same boxes under shares that hold the list to less than
// its content, to all of it and to more.
// NEGATIVE: the `Column` held to the share without the hang reports the
// overflow, which css_box's line does not.
import 'package:css_box/css_box.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The test font draws every glyph 14px wide and 14px tall at 14px.
const _style = TextStyle(fontSize: 14, height: 20 / 14);
const _keys = [ValueKey('list'), ValueKey('scale'), ValueKey('automations'), ValueKey('after')];

const _items = [
  Text('Scale', key: ValueKey('scale'), style: _style),
  Text('Automations', key: ValueKey('automations'), style: _style),
];

Widget _page(Widget list, double share) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: const Color(0xFF577590),
            child: Tracks(
              rows: [TrackSize.flex(share)],
              children: [
                TrackCell(
                  row: 0,
                  rowSpan: 2,
                  child: ColoredBox(key: const ValueKey('list'), color: const Color(0xFF277DA1), child: list),
                ),
              ],
            ),
          ),
          const SizedBox(key: ValueKey('after'), height: 16),
        ],
      ),
    ),
  ),
);

/// The list as css_box lays it out.
Widget get _line => FlexLine(direction: Axis.vertical, spacing: 12, children: _items);

/// The list as the stock pass writes it.
Widget get _hung => OverflowBox(
  maxHeight: double.infinity,
  fit: OverflowBoxFit.deferToChild,
  alignment: Alignment.topCenter,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: _items,
  ),
);

Future<Map<Key, Rect>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  return {for (final k in _keys) k: t.getRect(find.byKey(k))};
}

void main() {
  for (final share in const [0.5, 1.0, 2.0]) {
    testWidgets('under a share of $share: the hung column stands where the line does', (t) async {
      final line = await _rects(t, _page(_line, share));
      final hung = await _rects(t, _page(_hung, share));
      expect(hung, line);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('NEGATIVE: the column held to the share without the hang reports what passes it', (t) async {
    final line = await _rects(t, _page(_line, 0.5));
    // The list is held under its content: the second item passes its end.
    expect(line[const ValueKey('automations')]!.bottom, greaterThan(line[const ValueKey('list')]!.bottom));
    expect(t.takeException(), isNull);
    await t.pumpWidget(
      _page(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: _items,
        ),
        0.5,
      ),
    );
    expect(t.takeException(), isA<FlutterError>());
  });
}
