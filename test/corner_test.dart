import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

void main() {
  const box = Rect.fromLTWH(0, 0, 80, 80);
  const r = BorderRadius.all(Radius.circular(36));

  // The corner's curve at 45 degrees, `d` in from the corner along both axes.
  double in45(double k) => 36 * (1 - math.pow(math.cos(math.pi / 4), 2 / math.pow(2, k)).toDouble());

  test('superellipse(1) is the round corner', () {
    final path = const CornerShapeBorder(borderRadius: r).getOuterPath(box);
    final d = in45(1);
    expect(path.contains(Offset(d + 0.3, d + 0.3)), isTrue);
    expect(path.contains(Offset(d - 0.3, d - 0.3)), isFalse);
  });

  test('superellipse(2) is fuller than round', () {
    final path = const CornerShapeBorder(borderRadius: r, curvature: 2).getOuterPath(box);
    final d = in45(2);
    expect(d, lessThan(in45(1)));
    expect(path.contains(Offset(d + 0.3, d + 0.3)), isTrue);
    expect(path.contains(Offset(d - 0.3, d - 0.3)), isFalse);
    // The edges are straight past the radius box.
    expect(path.contains(const Offset(40, 0.2)), isTrue);
  });

  test('bevel, square and scoop', () {
    final bevel = const CornerShapeBorder(borderRadius: r, curvature: 0).getOuterPath(box);
    expect(bevel.contains(const Offset(18.5, 18.5)), isTrue);
    expect(bevel.contains(const Offset(17.5, 17.5)), isFalse);
    final square = const CornerShapeBorder(borderRadius: r, curvature: double.infinity).getOuterPath(box);
    expect(square.contains(const Offset(0.5, 0.5)), isTrue);
    final scoop = const CornerShapeBorder(borderRadius: r, curvature: -1).getOuterPath(box);
    // A quarter circle cut out round the corner point.
    expect(scoop.contains(const Offset(24, 24)), isFalse);
    expect(scoop.contains(const Offset(27, 27)), isTrue);
  });

  test('the inner edge is the border width in, radii that much smaller', () {
    const border = CornerShapeBorder(side: BorderSide(width: 3), borderRadius: r, curvature: 2);
    final inner = border.getInnerPath(box);
    expect(inner.getBounds(), const Rect.fromLTRB(3, 3, 77, 77));
    final d = 3 + 33 * (1 - math.pow(math.cos(math.pi / 4), 0.5).toDouble());
    expect(inner.contains(Offset(d + 0.3, d + 0.3)), isTrue);
    expect(inner.contains(Offset(d - 0.3, d - 0.3)), isFalse);
  });

  test('a radius past half the side is scaled down with the others', () {
    final path = const CornerShapeBorder(
      borderRadius: BorderRadius.all(Radius.circular(60)),
      curvature: 2,
    ).getOuterPath(box);
    expect(path.getBounds(), box);
    expect(path.contains(const Offset(40, 0.3)), isTrue);
  });

  // Chrome's `0 0 0 10px` shadow round a 200x100 box with `16px` bevelled
  // corners meets its edges 21.86px from the corner of the shadow's box
  // (16 + 10 * (2 - sqrt(2))): each edge of the bevel moved out parallel.
  test("a bevel's spread moves its edges out parallel", () {
    const shape = CornerShapeBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
      curvature: 0,
    );
    const rect = Rect.fromLTWH(0, 0, 200, 100);
    final path = shape.getSpreadPath(rect, 10)!;
    expect(path.getBounds(), rect.inflate(10));
    // The top-right corner's cut: x - y = 200 + 10 - 21.86 - (-10) from
    // the grown box's corner (210, -10) back along the top.
    const cut = 21.857864376269049;
    expect(path.contains(const Offset(210 - cut - 0.2, -9.9)), isTrue);
    expect(path.contains(const Offset(210 - cut + 0.3, -9.9)), isFalse);
    // Parallel: the cut is 10 out from the box's own, along its normal.
    const mid = Offset(200 - 8, 8); // the middle of the box's own cut
    final out = mid + const Offset(1, -1) / math.sqrt2 * 10;
    expect(path.contains(out - const Offset(0.1, -0.1)), isTrue);
    expect(path.contains(out + const Offset(0.1, -0.1)), isFalse);
    // A square corner stays square: the bottom left, where the top left
    // is cut.
    expect(path.contains(const Offset(-9.9, 109.9)), isTrue);
    expect(path.contains(const Offset(-9.9, -9.9)), isFalse);
    // No spread is the outline; a curve, two radii or a shrinking spread
    // are not known.
    expect(shape.getSpreadPath(rect, 0)!.getBounds(), rect);
    expect(
      const CornerShapeBorder(borderRadius: BorderRadius.all(Radius.circular(16)), curvature: 2).getSpreadPath(rect, 4),
      isNull,
    );
    expect(
      const CornerShapeBorder(
        borderRadius: BorderRadius.all(Radius.elliptical(16, 8)),
        curvature: 0,
      ).getSpreadPath(rect, 4),
      isNull,
    );
    expect(shape.getSpreadPath(rect, -4), isNull);
  });
}
