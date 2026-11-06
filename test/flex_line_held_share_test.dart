// A SHARE OF ALL OF A COLUMN HELD AT ITS CONTENT OR MORE IS WHAT THE OTHERS
// LEAVE (css-flexbox-1 9.7): a music store's discover cards are columns of
// `height: 100%` stretched to their grid row, a picture over a body of
// `height: 100%`. Measured, the row has no height and the share is its
// content; laid out, the row is a definite height (css-grid-1 6.2, 6.6) no
// less than the card's content, every item but the body is frozen at its
// content and the body ends at what they leave. The lowerer (`lossy_flex.dart`,
// `_heldShareL`) spells that line an `Expanded` in a `Column` held in an
// `IntrinsicHeight` -- handed the row tight, or measured as its content
// (RenderIntrinsicHeight; RenderFlex `_getIntrinsicSize`, one flexed child
// being its own) -- and fixtures/flex-column-share-held-row is the page. This
// pins the two spellings to the same boxes with the row shorter than, as
// tall as and taller than the card, wide and narrow (the body's words wrap).
// The picture here is a box of a stated height. The column round it is
// written in a `ShrinkWidth` as any column measured across and asked its
// least width is (`lossy_flex.dart`, `_mostForLeastL`), which answers a
// height at the width it would shrink to: what grows with the width past
// its content -- a ratio, which keeps the line round such a column
// (`_ratioCellL`) -- is that wrapper's question, not the share's.
// NEGATIVE: half the column, whose base leaves room and grows by none, and a
// picture of no floor, which shrinks beside the share, are other lines: the
// stock spelling is not theirs, and the lowerer keeps css_box's for them.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _keys = [ValueKey('label'), ValueKey('picture'), ValueKey('body'), ValueKey('foot'), ValueKey('other')];

Widget _grid(Widget card, {required double width, required double other}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: Tracks(
        columns: const [TrackSize.flex(1), TrackSize.flex(1)],
        spacing: 28,
        children: [
          Stack(
            fit: StackFit.passthrough,
            children: [
              const Positioned.fill(child: SizedBox.shrink()),
              card,
            ],
          ),
          SizedBox(key: const ValueKey('other'), height: other),
        ],
      ),
    ),
  ),
);

const _picture = ColoredBox(key: ValueKey('picture'), color: Color(0xFF3060A0), child: SizedBox(height: 90));
const _body = Padding(
  padding: EdgeInsets.symmetric(vertical: 10.5),
  child: Text('Alien Metal', key: ValueKey('body')),
);

/// The card as css_box lays it out: the body a share of all of the column.
Widget _line({double share = 1, double? pictureMin}) => FlexLine(
  direction: Axis.vertical,
  spacing: 6,
  children: [
    const FlexCell(child: Text('Label', key: ValueKey('label'))),
    FlexCell(crossSizeFraction: 1, min: pictureMin, clips: pictureMin != null, child: _picture),
    FlexCell(mainSizeFraction: share, frame: const EdgeInsets.symmetric(vertical: 10.5), child: _body),
    const FlexCell(child: Text('Foot', key: ValueKey('foot'))),
  ],
);

/// The card as the lowerer writes it.
Widget _stock() => IntrinsicHeight(
  child: ShrinkWidth(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: const [
        Text('Label', key: ValueKey('label')),
        _picture,
        Expanded(child: _body),
        Text('Foot', key: ValueKey('foot')),
      ],
    ),
  ),
);

Future<Map<Key, Rect>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  return {for (final k in _keys) k: t.getRect(find.byKey(k))};
}

void main() {
  for (final width in const [600.0, 240.0]) {
    for (final other in const [0.0, 180.0, 420.0]) {
      testWidgets('the share is what the others leave: $width wide, beside $other', (t) async {
        final line = await _rects(t, _grid(_line(), width: width, other: other));
        final stock = await _rects(t, _grid(_stock(), width: width, other: other));
        expect(stock, line);
        // Beside a taller item the card is stretched to the row: the body
        // ends where the foot leaves, the foot at the row's end.
        if (other > 400) expect(line[const ValueKey('foot')]!.bottom, other);
      });
    }
  }

  testWidgets('NEGATIVE: half the column leaves room the stock spelling fills', (t) async {
    final line = await _rects(t, _grid(_line(share: 0.5), width: 600, other: 420));
    final stock = await _rects(t, _grid(_stock(), width: 600, other: 420));
    expect(stock[const ValueKey('foot')], isNot(line[const ValueKey('foot')]));
  });

  testWidgets('NEGATIVE: a picture of no floor shrinks beside the share', (t) async {
    final line = await _rects(t, _grid(_line(pictureMin: 0), width: 600, other: 420));
    final stock = await _rects(t, _grid(_stock(), width: 600, other: 420));
    expect(stock[const ValueKey('body')]!.top, isNot(line[const ValueKey('body')]!.top));
  });
}
