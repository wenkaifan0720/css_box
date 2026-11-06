// A ROOM AS WIDE AS WHAT IS INSIDE IT (`Inset.fits`): an inline-level flex
// container of no stated width. A percentage padding of an item is a share
// of the container's width (CSS 2.1 8.4), which is worked out from the
// content with the share at nothing (css-sizing-3 5.2.1) -- and the share
// is then of the width that came out, so the item hangs out of it. Chrome,
// `fixtures/flex-item-pct-padding` b13: an `inline-flex` round `e` at
// `padding: 0 10%` and `f` is the two words' 15.25 wide, `e` is its word
// and 1.525 a side, and `f` starts 3.05 past the container's end. Here the
// words are a 60px and a 40px box in a 300px line.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _room = ValueKey('room');
const _padded = ValueKey('padded');
const _word = ValueKey('word');
const _next = ValueKey('next');

Widget _page({required bool fits}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 300,
      child: Align(
        alignment: Alignment.topLeft,
        child: Inset(
          key: _room,
          insets: EdgeInsets.zero,
          room: true,
          fits: fits,
          child: Spill(
            axis: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Inset(
                  key: _padded,
                  insets: EdgeInsets.zero,
                  shares: const EdgeInsets.symmetric(horizontal: 0.1),
                  ofRoom: true,
                  child: const SizedBox(key: _word, width: 60, height: 10),
                ),
                const SizedBox(key: _next, width: 40, height: 10),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('the room is its content with the share at nothing, and the share is of that', (t) async {
    await t.pumpWidget(_page(fits: true));
    expect(t.getRect(find.byKey(_room)), const Rect.fromLTWH(0, 0, 100, 10));
    expect(t.getRect(find.byKey(_padded)), const Rect.fromLTWH(0, 0, 80, 10));
    expect(t.getRect(find.byKey(_word)), const Rect.fromLTWH(10, 0, 60, 10));
    expect(t.getRect(find.byKey(_next)), const Rect.fromLTWH(80, 0, 40, 10));
    // And again, laid out a second time: the share is not taken of the
    // width the last pass left behind.
    t.renderObject<RenderBox>(find.byKey(_room)).markNeedsLayout();
    await t.pump();
    expect(t.getRect(find.byKey(_room)), const Rect.fromLTWH(0, 0, 100, 10));
    expect(t.getRect(find.byKey(_next)), const Rect.fromLTWH(80, 0, 40, 10));
  });

  testWidgets('NEGATIVE: a room as wide as it is offered is that width', (t) async {
    await t.pumpWidget(_page(fits: false));
    // Offered the line's 300: the share is 30 a side.
    expect(t.getRect(find.byKey(_word)), const Rect.fromLTWH(30, 0, 60, 10));
  });
}
