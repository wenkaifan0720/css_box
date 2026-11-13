// A TURNED BOX SHRINKING INTO ITS ROOM, OFFERED NO HEIGHT, IS AS WIDE AS
// THE COLUMNS IT SETS. A `writing-mode: vertical-rl` box positioned at the
// top of its containing block with its height capped sets its lines as
// columns at the cap, and is as wide as those columns come to
// (css-writing-modes-4 7.3). Lowered, the cap is a `ConstrainedBox` round
// a `RotatedBox`, in a `ShrinkWidth` with a `roomFactor` that is offered no
// height. The intrinsic question cannot see the cap: `RenderConstrainedBox`
// asks what it holds at the height it was asked, not the one it caps, and
// at no height the turned lines never wrap. Asked, the box came out a
// column short and its columns drew a column's width off their place
// (`fixtures/writing-mode-turned-blocks`, 20px). Laid out in the width it
// is offered, it is the columns it sets (`shrink.dart`, `_fit`).
// NEGATIVE: the same box with no cap sets each line in one column, which
// the intrinsic question answers too.
import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _box = ValueKey('box');

// The test font draws every glyph 14px wide at 14px.
const _style = TextStyle(fontSize: 14, height: 1.0);

/// A turned block of two paragraphs, `aa` and `aaaa bbbb`, its height
/// capped at [cap], at the top of a 400x300 containing block that offers
/// it its width and no height.
Widget _page({double? cap}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 400,
      height: 300,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topLeft,
              heightFactor: 1,
              child: ShrinkWidth(
                key: _box,
                roomFactor: 1,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: cap ?? double.infinity),
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: ShrinkWidth(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: const [
                          Text('aa', style: _style),
                          Text('aaaa bbbb', style: _style),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets('offered no height, a turned box under a height cap is as wide as the columns it sets', (t) async {
    // At 70 tall `aaaa bbbb` (126) sets in two columns of 14: three in all.
    await t.pumpWidget(_page(cap: 70));
    expect(t.takeException(), isNull);
    expect(t.getSize(find.byKey(_box)), const Size(42, 70));
    // The first paragraph's column stands at the right edge, the second's two
    // to its left, all inside the box.
    final box = t.getTopLeft(find.byKey(_box));
    expect(t.getRect(find.text('aa')).shift(-box), rectMoreOrLessEquals(const Rect.fromLTRB(28, 0, 42, 70)));
    expect(t.getRect(find.text('aaaa bbbb')).shift(-box), rectMoreOrLessEquals(const Rect.fromLTRB(0, 0, 28, 70)));
  });

  testWidgets('NEGATIVE: with no cap, each paragraph is one column, as the intrinsic question says', (t) async {
    await t.pumpWidget(_page());
    expect(t.takeException(), isNull);
    expect(t.getSize(find.byKey(_box)), const Size(28, 126));
  });
}
