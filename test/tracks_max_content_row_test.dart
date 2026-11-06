// A `max-content` COLUMN OF ONE ITEM, IN A GRID OF ONE ROW, IS THAT ITEM AT
// ITS OWN WIDTH. Both of the column's sizing functions take the item's
// max-content contribution (css-grid-1 11.5), which css_box asks the item for
// (`tracks.dart`, `getMaxIntrinsicWidth`) and lays it out at, tight; nothing
// stretches the column (11.8 grows `auto` maximums alone), and with one row
// no other item asks it for more. A `Row` lays a rigid child out at no bound
// along it (`RenderFlex._constraintsForNonFlexChild`), where a paragraph --
// and a line box round one -- is as wide as its one line, which is its
// greatest intrinsic width. The empty `auto` column after the items takes
// what they leave, which moves none of them. A price-table site's menu links are
// a grid of `max-content max-content min-content auto` round a 32px icon with
// a 16px margin, a label, and a 16px chevron with an 8px margin, or none; the
// lowerer (`lossy_grid.dart`, `_gridAtL`, `_TrackL.own`) writes them as a
// `Row` of the icon's column, the label and the chevron's, which this pins to
// css_box's boxes centred down the row at two widths, stretched down a row
// held to 48, and asked its least width by the floor of a flex line's item --
// where the label stands in an `IntrinsicWidth`, as the grid answers its
// least width with the column's max-content (12.7)
// (`fixtures/grid-max-content-one-row`).
// NEGATIVE: a room narrower than the row, where the grid hangs its tracks out
// silently and the `Row` says it overflows (the lowerer keeps the grid
// there); a second row whose label is longer widens the first row's column,
// which a `Row` of its own does not; a `min-content` column round a label of
// two words is its longer word, which a rigid child is not; and asked its
// least width, a bare label answers its longest word.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

ValueKey<String> _k(String name) => ValueKey(name);

const _cols = [TrackSize.maxContent, TrackSize.maxContent, TrackSize.minContent, TrackSize.auto];

Widget _label(String key, String text) => LineBox(
  lineHeight: 22.5,
  ascent: 17,
  child: Text(text, key: _k(key), style: const TextStyle(fontSize: 16)),
);

Widget _iconBox() => SizedBox(key: _k('icon'), width: 32, height: 32);
Widget _chevronBox() => SizedBox(key: _k('chevron'), width: 16, height: 16);

/// The link as css_box lays it out.
Widget _grid({String label = 'Ranking', bool chevron = true, CellAlign align = CellAlign.center}) => Tracks(
  columns: _cols,
  align: align,
  children: [
    TrackCell(width: 32, height: 32, margin: const EdgeInsets.only(right: 16), child: _iconBox()),
    _label('label', label),
    if (chevron)
      TrackCell(width: 16, height: 16, clips: true, margin: const EdgeInsets.only(left: 8), child: _chevronBox()),
  ],
);

/// The link as the lowerer writes it: centred down its row, or stretched
/// down a row of a height ([tall]) with the icon and the chevron at its top.
Widget _stock({String label = 'Ranking', bool chevron = true, bool tall = false, bool measure = false}) {
  final text = _label('label', label);
  final at = tall ? AlignmentDirectional.topStart : AlignmentDirectional.centerStart;
  final double? factor = tall ? null : 1;
  final row = Row(
    crossAxisAlignment: tall ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
    children: [
      SizedBox(
        width: 48,
        child: Align(
          alignment: at,
          heightFactor: factor,
          child: Padding(padding: const EdgeInsets.only(right: 16), child: _iconBox()),
        ),
      ),
      measure ? IntrinsicWidth(child: text) : text,
      if (chevron)
        SizedBox(
          width: 24,
          child: Align(
            alignment: at,
            heightFactor: factor,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ClipRect(child: _chevronBox()),
            ),
          ),
        ),
    ],
  );
  return tall ? IntrinsicHeight(child: row) : row;
}

/// The page: the link in a block [width] wide (held to [height] where one
/// is given), and a box under it.
Widget _page(Widget link, {required double width, double? height}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KeyedSubtree(
            key: _k('link'),
            child: height == null ? link : SizedBox(height: height, child: link),
          ),
          const SizedBox(key: ValueKey('under'), height: 21),
        ],
      ),
    ),
  ),
);

/// The rects of the link's boxes, and whether a flex said it overflowed.
Future<(Map<String, Rect>, bool)> _rects(WidgetTester t, Widget w, {bool chevron = true}) async {
  await t.pumpWidget(w);
  final e = t.takeException();
  expect(e == null || e.toString().contains('overflowed'), isTrue, reason: '$e');
  return (
    {
      for (final k in ['icon', 'label', if (chevron) 'chevron', 'link', 'under']) k: t.getRect(find.byKey(_k(k))),
    },
    e != null,
  );
}

/// The least width [link] answers, and its boxes laid out at it: the link as
/// the first item of a flex line css_box keeps, grown from nothing, which
/// floors the item at its least width (css-flexbox-1 4.5), in a room too
/// narrow for it.
Future<Map<String, Rect>> _least(WidgetTester t, Widget link) async {
  await t.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 60,
          child: FlexLine(
            children: [
              FlexCell(
                grow: 1,
                basis: 0,
                child: KeyedSubtree(key: _k('link'), child: link),
              ),
              const FlexCell(child: SizedBox(key: ValueKey('under'), width: 10, height: 10)),
            ],
          ),
        ),
      ),
    ),
  );
  final e = t.takeException();
  expect(e == null || e.toString().contains('overflowed'), isTrue, reason: '$e');
  return {
    for (final k in ['icon', 'label', 'link', 'under']) k: t.getRect(find.byKey(_k(k))),
  };
}

void main() {
  for (final width in const [360.0, 184.0]) {
    for (final chevron in const [true, false]) {
      testWidgets('icon, label${chevron ? ' and chevron' : ''} centred in a row, in a block $width wide', (t) async {
        final (css, _) = await _rects(
          t,
          _page(_grid(chevron: chevron), width: width),
          chevron: chevron,
        );
        final (out, over) = await _rects(
          t,
          _page(_stock(chevron: chevron), width: width),
          chevron: chevron,
        );
        expect(out, css);
        expect(over, isFalse);
        // The label right after the icon's 48, the chevron 8 after it.
        expect(css['label']!.left, 48);
        if (chevron) expect(css['chevron']!.left, css['label']!.right + 8);
      });
    }
    testWidgets(
      'the label stretched down a row held to 48, the icon and the chevron at its top, in a block $width wide',
      (t) async {
        final (css, _) = await _rects(t, _page(_grid(align: CellAlign.stretch), width: width, height: 48));
        final (out, _) = await _rects(t, _page(_stock(tall: true), width: width, height: 48));
        expect(out, css);
        // The icon and the chevron at the top of the row, not in its middle.
        expect(css['icon']!.top, css['link']!.top);
        expect(css['chevron']!.top, css['link']!.top);
      },
    );
  }

  for (final label in const ['Ranking', 'New listings']) {
    testWidgets('asked its least width, "$label" answers its max-content in an IntrinsicWidth', (t) async {
      final css = await _least(t, _grid(label: label, chevron: false));
      final out = await _least(t, _stock(label: label, chevron: false, measure: true));
      expect(out, css);
    });
  }

  testWidgets('NEGATIVE: in a room narrower than the row, the Row says it overflows', (t) async {
    final (css, overCss) = await _rects(t, _page(_grid(), width: 120));
    final (out, over) = await _rects(t, _page(_stock(), width: 120));
    expect(out, css);
    expect(overCss, isFalse);
    expect(over, isTrue);
  });

  testWidgets('NEGATIVE: a second row whose label is longer widens the column', (t) async {
    await t.pumpWidget(
      _page(
        Tracks(
          columns: _cols,
          align: CellAlign.center,
          children: [
            _label('label', 'Ranking'),
            SizedBox(key: _k('icon'), width: 16, height: 16),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            _label('chevron', 'Ranking and more'),
          ],
        ),
        width: 360,
      ),
    );
    final css = t.getRect(find.byKey(_k('icon')));
    await t.pumpWidget(
      _page(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _label('label', 'Ranking'),
                SizedBox(key: _k('icon'), width: 16, height: 16),
              ],
            ),
            Row(children: [_label('chevron', 'Ranking and more')]),
          ],
        ),
        width: 360,
      ),
    );
    expect(t.getRect(find.byKey(_k('icon'))).left, isNot(css.left));
  });

  testWidgets('NEGATIVE: a min-content column round two words is the longer word', (t) async {
    const cols = [TrackSize.maxContent, TrackSize.minContent, TrackSize.auto];
    await t.pumpWidget(
      _page(
        Tracks(columns: cols, children: [_label('label', 'Ranking'), _label('chevron', 'New listings')]),
        width: 360,
      ),
    );
    final css = t.getRect(find.byKey(_k('chevron')));
    await t.pumpWidget(
      _page(Row(children: [_label('label', 'Ranking'), _label('chevron', 'New listings')]), width: 360),
    );
    expect(t.getRect(find.byKey(_k('chevron'))).width, isNot(css.width));
  });

  testWidgets('NEGATIVE: asked its least width, a bare label answers its longest word', (t) async {
    final css = await _least(t, _grid(label: 'New listings', chevron: false));
    final out = await _least(t, _stock(label: 'New listings', chevron: false));
    expect(out, isNot(css));
  });
}
