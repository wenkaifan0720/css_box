// A BOX WITH A z PAINTS IN THE STACKING CONTEXT ABOVE ITS CONTAINING BLOCK
// (CSS 2.1 Appendix E, step 9), over the boxes placed against the blocks
// between, so the lowering places it in the stack of one of those -- and
// its insets and shares are still its own block's. `SpotShift.fill` lays
// its child out at the size of the area the block marks, at the area's
// corner: the child is a `Stack` the block's size holding the box's own
// `Positioned`. Chrome, `fixtures/z-hoist-placed`.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _box = ValueKey('box');

/// Presses that reached the block itself.
var _blockPressed = 0;

// A 300x200 stack whose flow is 40px of something and then the block (the
// area), `block` big; the box placed against the block by `positioned`, in
// the outer stack.
Widget _page(Size block, Widget positioned, {bool fill = true}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SpotScope(
      child: SizedBox(
        width: 300,
        height: 200,
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.passthrough,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: SpotArea(
                    id: 'g',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _blockPressed++,
                      child: SizedBox.fromSize(size: block),
                    ),
                  ),
                ),
              ],
            ),
            Positioned.fill(
              child: SpotShift(
                id: 'g',
                across: true,
                down: true,
                fill: fill,
                child: Stack(clipBehavior: Clip.none, children: [positioned]),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('the box stands at its insets in the block: from the far edges', (t) async {
    await t.pumpWidget(
      _page(
        const Size(100, 80),
        const Positioned(right: 10, bottom: -12, child: SizedBox(key: _box, width: 20, height: 20)),
      ),
    );
    // The block at (20, 40), 100x80: right 10 is x 90, bottom -12 is y 112.
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(90, 112, 20, 20));
  });

  testWidgets('a share is of the block: half its width, all its height', (t) async {
    await t.pumpWidget(
      _page(
        const Size(100, 80),
        const Positioned.fill(
          child: FractionallySizedBox(
            widthFactor: 0.5,
            alignment: Alignment.topLeft,
            child: SizedBox(key: _box),
          ),
        ),
      ),
    );
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(20, 40, 50, 80));
  });

  testWidgets('pressed where it is drawn, and nowhere else in the block', (t) async {
    var pressed = 0;
    await t.pumpWidget(
      _page(
        const Size(100, 80),
        Positioned(
          right: 10,
          top: 10,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => pressed++,
            child: const SizedBox(key: _box, width: 20, height: 20),
          ),
        ),
      ),
    );
    _blockPressed = 0;
    await t.tapAt(const Offset(100, 60));
    expect((pressed, _blockPressed), (1, 0));
    // The rest of the block is the block's: the shift's stack takes no press.
    await t.tapAt(const Offset(30, 100));
    expect((pressed, _blockPressed), (1, 1));
  });

  testWidgets('a block that comes out another size, the stack the same: the box follows it a frame later', (t) async {
    await t.pumpWidget(
      _page(
        const Size(100, 80),
        const Positioned(right: 0, bottom: 0, child: SizedBox(key: _box, width: 20, height: 20)),
      ),
    );
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(100, 100, 20, 20));
    await t.pumpWidget(
      _page(
        const Size(150, 100),
        const Positioned(right: 0, bottom: 0, child: SizedBox(key: _box, width: 20, height: 20)),
      ),
    );
    await t.pump();
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(150, 120, 20, 20));
  });

  testWidgets('NEGATIVE: without fill the child is laid out in the stack, not the block', (t) async {
    await t.pumpWidget(
      _page(
        const Size(100, 80),
        const Positioned(right: 10, bottom: -12, child: SizedBox(key: _box, width: 20, height: 20)),
        fill: false,
      ),
    );
    // The child stack is the outer stack's size (300x200), at the block's corner.
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(20 + 300 - 10 - 20, 40 + 200 + 12 - 20, 20, 20));
  });
}
