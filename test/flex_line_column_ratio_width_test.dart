// A COLUMN ASKED HOW WIDE IT IS ASKS ITS ITEMS' CONTENT (css-flexbox-1
// 9.9.3), and a ratio turns only a DEFINITE size into the other axis
// (css-sizing-4 2.1). Cards that are `flex: 1 1 0%; aspect-ratio: 1 / 1;
// overflow: hidden` down a column that is `align-items: center` in its own:
// Chrome makes the column as wide as its widest card's words, capped by the
// room, and each card that wide and as deep
// (`fixtures/flex-column-ratio-item-width` p1, p2). FlexLine turned the 64
// the basis and the padding made into a width of 64, and the cards came out
// the width of their longest word. NEGATIVE: a card of a stated height is
// that height wide through its ratio (n1).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

/// A square card: `flex: 1 1 0%; aspect-ratio: 1 / 1; padding: 32px 0`.
FlexCell _card(String words, {required bool clips, double? height}) => FlexCell(
  grow: height == null ? 1 : 0,
  shrink: height == null ? 1 : 0,
  min: clips ? 0 : null,
  mainSize: height,
  frame: const EdgeInsets.symmetric(vertical: 32),
  ratio: 1,
  clips: clips,
  child: Text(words, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28)),
);

/// The column, as wide as its content in a room of 346 (fit-content).
Future<Size> _column(WidgetTester t, List<FlexCell> cards) async {
  t.view
    ..physicalSize = const Size(1440, 900)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 346,
          child: Center(
            child: IntrinsicWidth(
              child: FlexLine(key: const ValueKey('c'), direction: Axis.vertical, spacing: 16, children: cards),
            ),
          ),
        ),
      ),
    ),
  );
  return t.getSize(find.byKey(const ValueKey('c')));
}

void main() {
  for (final clips in const [true, false]) {
    testWidgets('a column of ratio cards of no stated height is as wide as their words, capped by the room '
        '(clips: $clips)', (t) async {
      // The test font's glyphs are 1em square: 'Know your body with
      // confidence' is 30 of them, 840 wide, so the column is the room's
      // 346, and each card 346 deep.
      final size = await _column(t, [
        _card('Know your body with confidence', clips: clips),
        _card('The most customizable wearable', clips: clips),
      ]);
      expect(size, const Size(346, 346 + 16 + 346));
    });
  }

  testWidgets('NEGATIVE: a ratio card of a stated height is that height wide', (t) async {
    final size = await _column(t, [_card('A stated height', clips: true, height: 120)]);
    expect(size, const Size(120, 120));
  });
}
