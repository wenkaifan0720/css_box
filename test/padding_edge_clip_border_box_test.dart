// THE PADDING EDGE OF A BORDER BOX, for what is placed beneath a block that
// clips (css-overflow-3 3.1): a box at a negative z under a block that is no
// stacking context sits in a stack the size of the block's BORDER box, and
// the block cuts it at its padding edge -- the corners, shares of the border
// box, resolved there and each less the border beside it (css-backgrounds-3
// 5.2). `fixtures/stack-under-clip` n2: 12% corners inside a 3px border.
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

void main() {
  const shape = PercentCornerBorder(all: FractionalRadius(0.1, 0.1));
  const frame = EdgeInsets.fromLTRB(4, 6, 2, 8);

  test('handed the border box, it is the padding edge the padding-box clip draws, moved to the frame', () {
    const border = Size(300, 100);
    final path = const PaddingEdgeClip(shape, frame, borderBox: true).getClip(border);
    final inner = const PaddingEdgeClip(shape, frame).getClip(frame.deflateSize(border)).shift(frame.topLeft);
    expect(path.getBounds(), const Rect.fromLTRB(4, 6, 298, 92));
    expect(inner.getBounds(), path.getBounds());
    // The outer corners are 30 by 10; the top left's inner one is 26 by 4,
    // so (5, 7) -- 1px in from both sides -- is outside the curve there and
    // (5, 40) and (150, 7) on the straight sides are inside.
    for (var x = 0.5; x < 300; x += 3) {
      for (var y = 0.5; y < 100; y += 1.5) {
        final p = Offset(x, y);
        expect(path.contains(p), inner.contains(p), reason: '$p');
      }
    }
    expect(path.contains(const Offset(5, 7)), isFalse);
    expect(path.contains(const Offset(5, 40)), isTrue);
    expect(path.contains(const Offset(150, 7)), isTrue);
  });

  test('an ellipse inside a border is the ellipse the border leaves', () {
    const border = Size(200, 120);
    const oval = PercentCornerBorder(all: FractionalRadius(0.5, 0.5));
    final path = const PaddingEdgeClip(oval, EdgeInsets.all(4), borderBox: true).getClip(border);
    final want = Path()..addOval(const Rect.fromLTRB(4, 4, 196, 116));
    for (var x = 0.5; x < 200; x += 2) {
      for (var y = 0.5; y < 120; y += 2) {
        final p = Offset(x, y);
        // Off the curve by more than a hair, the two agree.
        final e = (p.dx - 100) * (p.dx - 100) / (96 * 96) + (p.dy - 60) * (p.dy - 60) / (56 * 56);
        if ((e - 1).abs() < 0.03) continue;
        expect(path.contains(p), want.contains(p), reason: '$p');
      }
    }
  });

  // NEGATIVE: the padding-box clip handed the border box resolves the
  // shares on a box the frame bigger again, and cuts in by it again.
  test('NEGATIVE: without borderBox the same size is taken for the padding box', () {
    const border = Size(300, 100);
    final path = const PaddingEdgeClip(shape, frame).getClip(border);
    expect(path.getBounds(), const Rect.fromLTRB(0, 0, 300, 100));
  });
}
