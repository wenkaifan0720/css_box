import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'percent_corner.dart';

/// An `outline` drawn OUTSIDE the border edge.
///
/// An outline takes no room (css-ui-4 4.1), and `outline-offset` moves it
/// out past the box, where no border can be drawn. Its corners follow the
/// box's `border-radius`, grown by how far out the line runs, as Blink draws
/// them; a square corner stays square. A docs site's command rows are
/// `border-radius: 8px; outline: 1px solid; outline-offset: 4px`.
///
/// CORNERS THAT ARE SHARES OF THE BOX are [corners]: the border box's
/// radii at the size the layout gives it (see [PercentCornerBorder.outer]),
/// grown the same way. Blink fills the ring between its two edges -- the
/// border edge moved out by [offset], and that moved out by [width], each
/// radius grown by as much (css-ui-4 4.3) -- and a share across and a share
/// down make elliptical corners, whose edges a stroke down the middle
/// would not trace; so this one is filled between the two. PULLED IN by a
/// negative [offset], each radius shrinks by as much, and one that would
/// go past nothing is square (Blink's `FloatRoundedRect::Radii::Outset`):
/// a 2px ring at `-1px` round 10% of 200x60 is (19, 5) inside and (21, 7)
/// outside, as Chrome draws it.
///
/// PULLED IN PAST ITS OWN WIDTH the ring is inside the box, filled
/// between its two edges the same way round radii of lengths too (a
/// stroke down its middle would round a corner whose outer radius is left
/// and whose middle one is not): Chrome's 4px ring at `-9px` round 10% of
/// 300x80 is (25, 3) outside and square inside. Blink pulls an outline in
/// no further than half the box; this pulls it in by [offset] whatever
/// the box, and is for boxes at least twice as big.
class OutlineRing extends Decoration {
  const OutlineRing({required this.color, required this.width, this.offset = 0, this.borderRadius, this.corners})
    : assert(corners == null || borderRadius == null);

  final Color color;
  final double width;

  /// How far outside the border edge the line starts.
  final double offset;

  /// The border box's corners, which the ring's grow from.
  final BorderRadius? borderRadius;

  /// The border box's corners as shares of it, in place of [borderRadius].
  final PercentCornerBorder? corners;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _OutlineRingPainter(this);

  @override
  bool operator ==(Object other) =>
      other is OutlineRing &&
      other.color == color &&
      other.width == width &&
      other.offset == offset &&
      other.borderRadius == borderRadius &&
      other.corners == corners;

  @override
  int get hashCode => Object.hash(color, width, offset, borderRadius, corners);
}

class _OutlineRingPainter extends BoxPainter {
  _OutlineRingPainter(this.deco);

  final OutlineRing deco;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || deco.width <= 0) return;
    final corners = deco.corners;
    final r = deco.borderRadius;
    if (corners != null || deco.offset < -deco.width) {
      // Filled between the border edge moved out by the offset and that
      // moved out by the width, each radius grown by as much.
      final base =
          corners?.outer(offset & size) ??
          (r == null ? RRect.fromRectAndRadius(offset & size, Radius.zero) : r.toRRect(offset & size).scaleRadii());
      RRect grown(double by) {
        Radius grow(Radius v) =>
            v.x <= 0 || v.y <= 0 ? Radius.zero : Radius.elliptical(math.max(0.0, v.x + by), math.max(0.0, v.y + by));
        return RRect.fromRectAndCorners(
          base.outerRect.inflate(by),
          topLeft: grow(base.tlRadius),
          topRight: grow(base.trRadius),
          bottomRight: grow(base.brRadius),
          bottomLeft: grow(base.blRadius),
        );
      }

      canvas.drawDRRect(grown(deco.offset + deco.width), grown(deco.offset), Paint()..color = deco.color);
      return;
    }
    // The stroke runs down the middle of the ring.
    final out = deco.offset + deco.width / 2;
    final box = (offset & size).inflate(out);
    if (box.width <= 0 || box.height <= 0) return;
    final paint = Paint()
      ..color = deco.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = deco.width;
    if (r == null) {
      canvas.drawRect(box, paint);
      return;
    }
    Radius grow(Radius v) =>
        v.x <= 0 || v.y <= 0 ? Radius.zero : Radius.elliptical(math.max(0.0, v.x + out), math.max(0.0, v.y + out));
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        box,
        topLeft: grow(r.topLeft),
        topRight: grow(r.topRight),
        bottomRight: grow(r.bottomRight),
        bottomLeft: grow(r.bottomLeft),
      ),
      paint,
    );
  }
}
