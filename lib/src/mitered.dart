import 'package:flutter/painting.dart';

import 'percent_corner.dart';

/// A [Border] on rounded corners whose sides are not all one colour, and
/// one of sides in one colour whose widths differ (below).
///
/// Flutter's [Border] refuses a `borderRadius` over more than one colour
/// (a debug assertion, and square strips in a release build). CSS paints
/// each side over the ring between the outer and inner curves, cut from its
/// neighbours along the line from the outer corner through the inner one
/// (css-backgrounds-3 5.5). This draws it the way Blink does
/// (`BoxBorderPainter::ClipBorderSidePolygon`): each side is the ring
/// clipped to the quad between its two outer corners and its two inner
/// ones, and where the inner corner is rounded, its point moves in along
/// that line to the chord of the inner curve, so the quad holds the whole
/// of the curve on its side.
///
/// A transparent side paints nothing and still takes its half of each
/// corner. A news site's loading spinner is a 40px circle with a 3px border, dark
/// on top and light on the other three sides.
///
/// SIDES OF ONE COLOUR AND DIFFERENT WIDTHS (or moved by different
/// `strokeAlign`s) are one ring, on a square box as on a rounded one:
/// Blink fills the border box less the padding box (`PaintBorderFastPath`,
/// one `drawDRRect` for a solid border, two for a `double` one), where
/// Flutter's `Border` on square corners draws each side a polygon of its
/// own, and two sides anti-aliased along the same diagonal leave the page
/// showing through a seam down it. A `double` border 9px on top and 6px
/// round the rest is two such rings (fixtures/border-thin-double b8).
/// Round corners that overlap are scaled back first (5.5), as Blink
/// scales the border box's before taking the widths off each ring's
/// (`ConstrainRadii`); Flutter's own ring takes the widths off first and
/// scales each curve by itself, and a pill 9px on top and 6px below is
/// then even inside where Chrome's inner curves differ by the 3px
/// (fixtures/border-thin-double b9).
///
/// CORNERS THAT ARE SHARES OF THE BOX are [corners], read at the size the
/// box is painted at in place of the decoration's `borderRadius`: a red top
/// and a white bottom round `50%` of a box the layout sizes meet where
/// the diagonals cut the ellipse (fixtures/border-uneven-shape p3).
class MiteredBorder extends Border {
  const MiteredBorder({super.top, super.right, super.bottom, super.left, this.corners});

  /// The border box's corners as shares of its size, in place of the
  /// decoration's `borderRadius`.
  final PercentCornerBorder? corners;

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    final sides = [top, right, bottom, left];
    final colours = {
      for (final s in sides)
        if (s.style != BorderStyle.none) s.color,
    };
    if (colours.length == 1 &&
        corners == null &&
        !isUniform &&
        shape == BoxShape.rectangle &&
        !sides.any((s) => s.style == BorderStyle.solid && s.width == 0)) {
      BorderSide shown(BorderSide s) => s.style == BorderStyle.none ? BorderSide.none : s;
      final scaled = borderRadius?.toRRect(rect).scaleRadii();
      BoxBorder.paintNonUniformBorder(
        canvas,
        rect,
        borderRadius: scaled == null
            ? null
            : BorderRadius.only(
                topLeft: scaled.tlRadius,
                topRight: scaled.trRadius,
                bottomRight: scaled.brRadius,
                bottomLeft: scaled.blRadius,
              ),
        textDirection: textDirection,
        top: shown(top),
        right: shown(right),
        bottom: shown(bottom),
        left: shown(left),
        color: colours.single,
      );
      return;
    }
    if (corners == null &&
        (borderRadius == null ||
            borderRadius == BorderRadius.zero ||
            shape != BoxShape.rectangle ||
            colours.length < 2)) {
      super.paint(canvas, rect, textDirection: textDirection, shape: shape, borderRadius: borderRadius);
      return;
    }
    double w(BorderSide s) => s.style == BorderStyle.none ? 0 : s.width;
    final (t, r, b, l) = (w(top), w(right), w(bottom), w(left));
    // Radii that overlap are scaled down together first, as CSS scales
    // them, and the inner curve is the outer one less the border beside it.
    final outer = corners?.outer(rect) ?? borderRadius!.toRRect(rect).scaleRadii();
    Radius less(Radius v, double x, double y) =>
        Radius.elliptical((v.x - x).clamp(0, double.infinity), (v.y - y).clamp(0, double.infinity));
    final inner = RRect.fromLTRBAndCorners(
      rect.left + l,
      rect.top + t,
      rect.right - r,
      rect.bottom - b,
      topLeft: less(outer.tlRadius, l, t),
      topRight: less(outer.trRadius, r, t),
      bottomRight: less(outer.brRadius, r, b),
      bottomLeft: less(outer.blRadius, l, b),
    );
    final innerRect = inner.outerRect;

    // The line from outer corner [o] through inner corner [i], met with
    // the chord of the inner curve that starts at [i]; [i] where the
    // corner is square or the two lines never meet.
    Offset corner(Offset o, Offset i, Radius ir, double sx, double sy) {
      if (ir.x <= 0 && ir.y <= 0) return i;
      final d1 = Offset(i.dx + sx * ir.x, i.dy);
      final d2 = Offset(i.dx, i.dy + sy * ir.y);
      final p = i - o;
      final d = d2 - d1;
      final denom = p.dx * d.dy - p.dy * d.dx;
      if (denom == 0) return i;
      final k = ((d1.dx - o.dx) * d.dy - (d1.dy - o.dy) * d.dx) / denom;
      return o + p * k;
    }

    final tl = corner(rect.topLeft, innerRect.topLeft, inner.tlRadius, 1, 1);
    final tr = corner(rect.topRight, innerRect.topRight, inner.trRadius, -1, 1);
    final br = corner(rect.bottomRight, innerRect.bottomRight, inner.brRadius, -1, -1);
    final bl = corner(rect.bottomLeft, innerRect.bottomLeft, inner.blRadius, 1, -1);
    final quads = [
      [rect.topLeft, tl, tr, rect.topRight],
      [rect.topRight, tr, br, rect.bottomRight],
      [rect.bottomRight, br, bl, rect.bottomLeft],
      [rect.bottomLeft, bl, tl, rect.topLeft],
    ];
    // The sides of one colour are ONE fill, so no seam shows where two of
    // them meet.
    final byColour = <Color, Path>{};
    for (var k = 0; k < 4; k++) {
      final s = sides[k];
      if (s.style == BorderStyle.none || s.width <= 0 || s.color.a == 0) continue;
      byColour.putIfAbsent(s.color, Path.new).addPolygon(quads[k], true);
    }
    for (final MapEntry(key: colour, value: quad) in byColour.entries) {
      canvas.save();
      canvas.clipPath(quad);
      canvas.drawDRRect(outer, inner, Paint()..color = colour);
      canvas.restore();
    }
  }

  @override
  bool operator ==(Object other) => other is MiteredBorder && super == other && other.corners == corners;

  @override
  int get hashCode => Object.hash(super.hashCode, corners);
}
