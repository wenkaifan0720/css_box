// A PADDING THAT IS A SHARE IS OF THE CONTAINING BLOCK'S WIDTH, on every
// side (CSS 2.1 8.4), and a float's containing block is its flow's content
// box (10.1) -- a width the float's own, laid out at a width of its own,
// says nothing of. `FloatSlot.frameShare` hands the share to the flow's
// pass, which resolves it against the width it lays the child out in and
// adds it to the child's frame (`float_flow.dart`, `padIn`, `frameIn`). A
// ratio spacer is such a float: a furniture maker's tiles are `::before {
// float: left; width: 1px; margin-left: -1px; padding-bottom: 56.25% }`
// held in by a clearfix, round pictures placed `inset: 0`, so each tile is
// 16:9 of its width. This pins the spacer, and the flow it holds open, at
// that height at several widths, again after the flow changes width under
// the same boxes, beside a length the child holds and a share up, and in a
// flow hosted through 20px of padding a side, whose width the share is of.
// NEGATIVE: a flow working its own width out counts the share as nothing
// (css-sizing-3 5.2.1) and resolves it against the width that comes out.
import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _ratio = 0.5625;

/// The spacer: 1px wide, its margin taking that back, its padding down a
/// share of the flow.
Widget _spacer({EdgeInsets frame = EdgeInsets.zero, EdgeInsets share = const EdgeInsets.only(bottom: _ratio)}) =>
    FloatSlot(
      float: FloatSide.left,
      clear: FloatClear.both,
      bfc: true,
      width: 1,
      margin: const EdgeInsets.only(left: -1),
      frame: frame,
      frameShare: share,
      child: Padding(key: const ValueKey('spacer'), padding: frame, child: const SizedBox(width: 1)),
    );

/// The clearfix after it.
const Widget _clearfix = FloatSlot(clear: FloatClear.both, bfc: true, child: SizedBox.shrink());

Widget _page(double? width, Widget flow) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: width == null ? flow : SizedBox(width: width, child: flow),
  ),
);

Widget _tile(double width, [Widget? spacer]) =>
    _page(width, FloatFlow(key: const ValueKey('flow'), children: [spacer ?? _spacer(), _clearfix]));

Size _size(WidgetTester t, String key) => t.getSize(find.byKey(ValueKey(key)));

void main() {
  Future<void> pump(WidgetTester t, Widget w) {
    t.view.physicalSize = const Size(1600, 1200);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    return t.pumpWidget(w);
  }

  testWidgets('the spacer, and the flow it holds open, are the share of the flow down, at every width', (t) async {
    for (final w in [309.0, 390.0, 1440.0]) {
      await pump(t, _tile(w));
      expect(_size(t, 'spacer'), Size(1, _ratio * w), reason: 'at $w');
      expect(_size(t, 'flow').height, moreOrLessEquals(_ratio * w, epsilon: 1e-9), reason: 'at $w');
    }
  });

  testWidgets('the same boxes in a flow that changes width follow it', (t) async {
    for (final w in [1440.0, 309.0, 1024.0]) {
      await pump(t, _tile(w));
      expect(_size(t, 'spacer').height, moreOrLessEquals(_ratio * w, epsilon: 1e-9), reason: 'at $w');
      expect(_size(t, 'flow').height, moreOrLessEquals(_ratio * w, epsilon: 1e-9), reason: 'at $w');
    }
  });

  testWidgets('beside a length the child holds, and with a share up as well', (t) async {
    await pump(
      t,
      _tile(400, _spacer(frame: const EdgeInsets.only(top: 4), share: const EdgeInsets.only(top: 0.1, bottom: 0.5))),
    );
    expect(_size(t, 'spacer').height, moreOrLessEquals(4 + 0.6 * 400, epsilon: 1e-9));
    expect(_size(t, 'flow').height, moreOrLessEquals(4 + 0.6 * 400, epsilon: 1e-9));
  });

  testWidgets('in a flow hosted through 20px of padding a side, the share is of that flow, 40 narrower', (t) async {
    for (final w in [390.0, 1440.0]) {
      await pump(
        t,
        _page(
          w,
          FloatFlow(
            key: const ValueKey('flow'),
            children: [
              FloatSlot(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FloatFlow(nested: true, children: [_spacer()]),
                ),
              ),
              _clearfix,
            ],
          ),
        ),
      );
      expect(_size(t, 'spacer').height, moreOrLessEquals(_ratio * (w - 40), epsilon: 1e-9), reason: 'at $w');
      expect(_size(t, 'flow').height, moreOrLessEquals(_ratio * (w - 40), epsilon: 1e-9), reason: 'at $w');
    }
  });

  testWidgets('NEGATIVE: a flow working its own width out counts a share across as nothing, then resolves it', (
    t,
  ) async {
    // A shrink-to-fit flow round an empty float with half the flow for its
    // padding on the left, and a block 100 wide: the flow is the block's
    // 100, and the float half of that.
    await pump(
      t,
      _page(
        null,
        IntrinsicWidth(
          child: FloatFlow(
            key: const ValueKey('flow'),
            children: const [
              FloatSlot(
                float: FloatSide.left,
                frameShare: EdgeInsets.only(left: 0.5),
                child: SizedBox.shrink(key: ValueKey('float')),
              ),
              FloatSlot(child: SizedBox(width: 100, height: 10)),
            ],
          ),
        ),
      ),
    );
    expect(_size(t, 'flow').width, 100);
    expect(_size(t, 'float'), const Size(50, 0));
  });
}
