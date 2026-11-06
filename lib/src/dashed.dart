/// Dashed and dotted borders, laid out the way Blink lays them out.
library;

import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'percent_corner.dart';

/// A square border whose sides are `dashed` or `dotted` (css-backgrounds-3
/// 4.2), which Flutter's [BorderStyle] cannot say.
///
/// Each side is stroked along its middle over the whole of the border box
/// it runs beside, and cut from its neighbours along the diagonal from the
/// outer corner to the inner one, as a solid side is. The dashes are
/// Blink's (`StyledStrokeData`, `EnforceDotsAtEndpoints`): `3w` long with
/// a `2w` gap on a side thinner than 3px and `2w` with a `w` gap from 3px
/// up, as many as leave the gap nearest that, a dash at both ends; a dot
/// `w` long a dot apart, with the two end dots drawn apart and the side's
/// odd pixels given to the gaps beside them; a side with room for two and
/// no more gets the pair, scaled to fit; and a side no longer than two
/// drawn solid. A space agency site's link underlines are `border-bottom: 1px
/// dashed`. A `dotted` side wider than 3px is ROUND dots the side wide, a
/// dot apart as near as whole dots allow, the end ones inside its ends.
///
/// ROUND A ROUNDED BOX Blink paints a side one of two ways, by whether
/// its inner edge bends (`BorderWillArcInnerEdge`: an inner corner at
/// either end with a radius left once the widths are taken off). A side
/// whose inner edge is straight is drawn as above and clipped to the
/// outer curve; a vehicle listing's `3px dotted` boxes with `3px` corners are. A
/// side whose inner edge bends is the rounded rectangle down the middle of
/// the border stroked WHOLE (`DrawDashedDottedBoxSideFromPath`): from the
/// top edge's left end, clockwise, `2.2w` thick and clipped to the ring
/// between the outer and inner curves, dashed over the path's length in
/// whole pixels as a CLOSED path (`SelectBestDashGap`, no dash owed at an
/// end) -- a `dotted` one a dot a dot apart with no gap chosen. A SaaS landing page's
/// dashed avatar rings are `1px dashed` circles 20px across: 12 dashes a
/// 1.917px gap apart.
///
/// CORNERS THAT ARE SHARES OF THE BOX (`border-radius: 50%` on a box the
/// layout sizes, an ellipse) are [corners], read at the size the box is
/// painted at in place of the decoration's `borderRadius`, and each side
/// bends or not by the radii they come to, as above: a dashed ellipse as
/// wide as the page is a stated size no box has before layout.
///
/// It is a [BoxBorder] and not a [Border]: a [BoxDecoration] pulls its
/// colour in by half of every opaque solid side of a [Border], to keep it
/// from bleeding past the stroke, and the gaps here would show the page
/// through that half. The background is the border box's
/// (`background-clip: border-box`), under the dashes and between them.
class DashedBorder extends BoxBorder {
  const DashedBorder({
    this.top = BorderSide.none,
    this.right = BorderSide.none,
    this.bottom = BorderSide.none,
    this.left = BorderSide.none,
    this.dotted = false,
    this.corners,
  });

  /// Every side [side].
  const DashedBorder.fromBorderSide(BorderSide side, {this.dotted = false, this.corners})
    : top = side,
      right = side,
      bottom = side,
      left = side;

  @override
  final BorderSide top, bottom;

  final BorderSide right, left;

  /// `dotted` rather than `dashed`.
  final bool dotted;

  /// The border box's corners as shares of its size, in place of the
  /// decoration's `borderRadius`.
  final PercentCornerBorder? corners;

  @override
  EdgeInsetsGeometry get dimensions =>
      EdgeInsets.fromLTRB(left.strokeInset, top.strokeInset, right.strokeInset, bottom.strokeInset);

  @override
  bool get isUniform => top == right && top == bottom && top == left;

  @override
  DashedBorder scale(double t) => DashedBorder(
    top: top.scale(t),
    right: right.scale(t),
    bottom: bottom.scale(t),
    left: left.scale(t),
    dotted: dotted,
    corners: corners,
  );

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    double w(BorderSide s) => s.style == BorderStyle.none ? 0 : s.width;
    final (t, r, b, l) = (w(top), w(right), w(bottom), w(left));
    final inner = Rect.fromLTRB(rect.left + l, rect.top + t, rect.right - r, rect.bottom - b);
    final outer =
        corners?.outer(rect) ??
        (borderRadius == null || borderRadius == BorderRadius.zero ? null : borderRadius.toRRect(rect).scaleRadii());
    if (outer != null) {
      // Each corner less the widths of its two sides, across and down.
      Radius less(Radius o, double across, double down) =>
          Radius.elliptical(math.max(0, o.x - across), math.max(0, o.y - down));
      final (tl, tr, br, bl) = (
        less(outer.tlRadius, l, t),
        less(outer.trRadius, r, t),
        less(outer.brRadius, r, b),
        less(outer.blRadius, l, b),
      );
      bool bends(Radius a, Radius z) => a != Radius.zero || z != Radius.zero;
      final ring = RRect.fromRectAndCorners(inner, topLeft: tl, topRight: tr, bottomRight: br, bottomLeft: bl);
      final uniform = top == right && top == bottom && top == left && w(top) > 0;
      if (uniform && bends(tl, tr) && bends(tr, br) && bends(br, bl) && bends(bl, tl)) {
        if (top.color.a == 0) return;
        canvas.save();
        canvas.clipPath(
          Path()
            ..fillType = PathFillType.evenOdd
            ..addRRect(outer)
            ..addRRect(ring),
        );
        _strokeRound(canvas, outer, t, top.color);
        canvas.restore();
        return;
      }
      if (uniform && (bends(tl, tr) || bends(tr, br) || bends(br, bl) || bends(bl, tl))) {
        if (top.color.a == 0) return;
        _paintSomeBent(canvas, rect, outer, ring, t, top.color, [
          bends(tl, tr),
          bends(tr, br),
          bends(br, bl),
          bends(bl, tl),
        ]);
        return;
      }
      canvas.save();
      canvas.clipRRect(outer);
    }
    final quads = [
      [rect.topLeft, inner.topLeft, inner.topRight, rect.topRight],
      [rect.topRight, inner.topRight, inner.bottomRight, rect.bottomRight],
      [rect.bottomRight, inner.bottomRight, inner.bottomLeft, rect.bottomLeft],
      [rect.bottomLeft, inner.bottomLeft, inner.topLeft, rect.topLeft],
    ];
    final lines = [
      (Offset(rect.left, rect.top + t / 2), Offset(rect.right, rect.top + t / 2)),
      (Offset(rect.right - r / 2, rect.top), Offset(rect.right - r / 2, rect.bottom)),
      (Offset(rect.left, rect.bottom - b / 2), Offset(rect.right, rect.bottom - b / 2)),
      (Offset(rect.left + l / 2, rect.top), Offset(rect.left + l / 2, rect.bottom)),
    ];
    final sides = [top, right, bottom, left];
    for (var k = 0; k < 4; k++) {
      final s = sides[k];
      if (w(s) <= 0 || s.color.a == 0) continue;
      canvas.save();
      canvas.clipPath(Path()..addPolygon(quads[k], true));
      _stroke(canvas, lines[k].$1, lines[k].$2, s.width, s.color);
      canvas.restore();
    }
    if (outer != null) canvas.restore();
  }

  /// FOUR SIDES ALIKE, SOME BENDING AND SOME NOT (one corner rounded and
  /// the others square, or shares of the box that leave a radius inside
  /// some corners and none inside others). Blink clips the whole border to
  /// the ring between the outer and inner curves, and paints each side by
  /// itself: a side whose inner edge bends [bent] is the whole rounded
  /// rectangle dashed round ([_strokeRound]) clipped to the side's quad --
  /// its outer corners and its inner ones, each inner one moved along the
  /// diagonal to the chord of a rounded inner corner -- without
  /// anti-aliasing, the colours matching at the corner (a hard miter,
  /// `ClipBorderSidePolygon`); a side whose inner edge is straight is
  /// dashed along the side as on a square box, uncut, the neighbours being
  /// of its style and colour (no miter). A `1px dashed` box with `16px 0 0
  /// 0` corners is the ring's dashes round the top and left sides from the
  /// top edge's left end, and the line's down the right and along the
  /// bottom (fixtures/border-dashed-rounded d12).
  void _paintSomeBent(Canvas canvas, Rect rect, RRect outer, RRect ring, double width, Color color, List<bool> bent) {
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRRect(outer)
        ..addRRect(ring),
    );
    final inner = ring.outerRect;
    // The line from outer corner [o] through inner corner [i], met with the
    // chord of the inner curve that starts at [i] (Blink's
    // `FindIntersection`); [i] where the inner corner is square.
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

    final tl = corner(rect.topLeft, inner.topLeft, ring.tlRadius, 1, 1);
    final tr = corner(rect.topRight, inner.topRight, ring.trRadius, -1, 1);
    final br = corner(rect.bottomRight, inner.bottomRight, ring.brRadius, -1, -1);
    final bl = corner(rect.bottomLeft, inner.bottomLeft, ring.blRadius, 1, -1);
    final quads = [
      [rect.topLeft, tl, tr, rect.topRight],
      [rect.topRight, tr, br, rect.bottomRight],
      [rect.bottomRight, br, bl, rect.bottomLeft],
      [rect.bottomLeft, bl, tl, rect.topLeft],
    ];
    final lines = [
      (Offset(rect.left, rect.top + width / 2), Offset(rect.right, rect.top + width / 2)),
      (Offset(rect.right - width / 2, rect.top), Offset(rect.right - width / 2, rect.bottom)),
      (Offset(rect.left, rect.bottom - width / 2), Offset(rect.right, rect.bottom - width / 2)),
      (Offset(rect.left + width / 2, rect.top), Offset(rect.left + width / 2, rect.bottom)),
    ];
    for (var k = 0; k < 4; k++) {
      if (!bent[k]) {
        _stroke(canvas, lines[k].$1, lines[k].$2, width, color);
        continue;
      }
      canvas.save();
      canvas.clipPath(Path()..addPolygon(quads[k], true), doAntiAlias: false);
      _strokeRound(canvas, outer, width, color);
      canvas.restore();
    }
    canvas.restore();
  }

  /// The rounded rectangle [outer] less half of [width] all round IN WHOLE
  /// PIXELS (`CenterOutsets` is `PhysicalBoxStrut::FromInts(width * 0.5)`:
  /// a 1px border's path is its outer edge, a 3px one's a pixel in), as
  /// Skia adds one (`addRRect`, start index 0: the top edge's left end,
  /// conics clockwise), stroked in dashes along its whole length. Read off
  /// Chrome 151 at eight radii and widths, to the fifth decimal of the
  /// dash period.
  void _strokeRound(Canvas canvas, RRect outer, double width, Color color) {
    final h = (width * 0.5).truncateToDouble();
    final c = RRect.fromLTRBAndCorners(
      outer.left + h,
      outer.top + h,
      outer.right - h,
      outer.bottom - h,
      topLeft: Radius.elliptical(math.max(0, outer.tlRadiusX - h), math.max(0, outer.tlRadiusY - h)),
      topRight: Radius.elliptical(math.max(0, outer.trRadiusX - h), math.max(0, outer.trRadiusY - h)),
      bottomRight: Radius.elliptical(math.max(0, outer.brRadiusX - h), math.max(0, outer.brRadiusY - h)),
      bottomLeft: Radius.elliptical(math.max(0, outer.blRadiusX - h), math.max(0, outer.blRadiusY - h)),
    );
    const k = math.sqrt1_2;
    final path = Path()
      ..moveTo(c.left + c.tlRadiusX, c.top)
      ..lineTo(c.right - c.trRadiusX, c.top)
      ..conicTo(c.right, c.top, c.right, c.top + c.trRadiusY, k)
      ..lineTo(c.right, c.bottom - c.brRadiusY)
      ..conicTo(c.right, c.bottom, c.right - c.brRadiusX, c.bottom, k)
      ..lineTo(c.left + c.blRadiusX, c.bottom)
      ..conicTo(c.left, c.bottom, c.left, c.bottom - c.blRadiusY, k)
      ..lineTo(c.left, c.top + c.tlRadiusY)
      ..conicTo(c.left, c.top, c.left + c.tlRadiusX, c.top, k)
      ..close();
    // Doubled and a tenth, for the ring's clip to cut (Blink's
    // `thickness_multiplier`).
    final paint = Paint()
      ..color = color
      ..strokeWidth = width * 2.2
      ..style = PaintingStyle.stroke;
    final metrics = path.computeMetrics().toList();
    // Blink hands the pattern the length and the dash's width in whole
    // pixels (`{static_cast<int>(path.length()), border_thickness,
    // IsClosed()}`), the length Skia's `SkPathMeasure` finds -- which is
    // `PathMetric`'s, and the dashes run along the path by the same.
    final length = metrics.fold(0.0, (a, m) => a + m.length).truncateToDouble();
    final dw = width >= 1 ? width.truncateToDouble() : paint.strokeWidth;
    if (dotted && dw > 3) {
      // Round dots the border wide, a dot apart as near as whole dots
      // allow (`kRound_Cap` on zero-length dashes, `gap + w - 0.01`).
      final dot = Paint()..color = color;
      final step = length < 2 * dw ? double.infinity : closedGapFor(length, dw, dw) + dw - 0.01;
      for (final m in metrics) {
        for (var at = 0.0; at <= m.length; at += step) {
          canvas.drawCircle(m.getTangentForOffset(at)!.position, width / 2, dot);
        }
      }
      return;
    }
    final dash = dotted ? dw : dw * (dw >= 3 ? 2 : 3);
    final gap = dotted ? dw : dw * (dw >= 3 ? 1 : 2);
    final double on, off;
    if (length <= 2 * dash) {
      for (final m in metrics) {
        canvas.drawPath(m.extractPath(0, m.length), paint);
      }
      return;
    } else if (length <= 2 * dash + 2 * gap) {
      // Two dashes and, round a closed path, two gaps (Blink's
      // `two_dashes_with_gap_length`), scaled to fit.
      final f = length / (2 * dash + 2 * gap);
      (on, off) = (dash * f, gap * f);
    } else {
      (on, off) = (dash, dotted ? gap : closedGapFor(length, dash, gap));
    }
    for (final m in metrics) {
      for (var at = 0.0; at < m.length - 1e-6; at += on + off) {
        canvas.drawPath(m.extractPath(at, math.min(at + on, m.length)), paint);
      }
    }
  }

  /// The gap between [dash]es round a CLOSED path of [length] nearest
  /// [gap]: as many gaps as dashes, and none owed at an end (Blink's
  /// `SelectBestDashGap` with `closed_path`).
  static double closedGapFor(double length, double dash, double gap) {
    final few = (length / (dash + gap)).floorToDouble();
    final fewGap = (length - few * dash) / few;
    final manyGap = (length - (few + 1) * dash) / (few + 1);
    return manyGap <= 0 || (fewGap - gap).abs() < (manyGap - gap).abs() ? fewGap : manyGap;
  }

  void _stroke(Canvas canvas, Offset a, Offset b, double width, Color color) {
    final length = (b - a).distance;
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;
    final along = (b - a) / length;
    void dashes(Offset from, Offset to, double dash, double gap) {
      final run = (to - from).distance;
      for (var at = 0.0; at < run - 1e-6; at += dash + gap) {
        canvas.drawLine(from + along * at, from + along * math.min(at + dash, run), paint);
      }
    }

    // Blink decides on the side's whole pixels (`DrawLineWithStyle`).
    final len = length.roundToDouble();
    // ROUND DOTS on a side wider than 3px (`StrokeIsDashed` is false for
    // them): zero-length dashes with round caps, each a circle the side
    // wide, the line's ends moved in by half a dot so the end dots stand
    // inside the side. A dot apart as near as whole dots allow over the
    // side's whole length (`SelectBestDashGap`, open), less a hundredth so
    // the last dot is not lost to rounding; a side too short for two gets
    // the first alone.
    final wide = width.round();
    if (dotted && wide > 3) {
      final dot = Paint()..color = color;
      final from = a + along * (wide / 2), to = b - along * (wide / 2);
      final run = (to - from).distance;
      final step = len < 2 * wide ? 2.0 * wide : gapFor(len, wide.toDouble(), wide.toDouble()) + wide - 0.01;
      canvas.drawCircle(from, width / 2, dot);
      if (!step.isFinite) return;
      for (var at = step; at <= run + 1e-9; at += step) {
        canvas.drawCircle(from + along * at, width / 2, dot);
      }
      return;
    }
    final dash = dotted ? width : width * (width >= 3 ? 2 : 3);
    final gap = dotted ? width : width * (width >= 3 ? 1 : 2);
    if (len <= 2 * dash) {
      canvas.drawLine(a, b, paint);
      return;
    }
    // Room for two and no more: the pair, scaled to fill it.
    if (len <= 2 * dash + gap) {
      final m = length / (2 * dash + gap);
      dashes(a, b, dash * m, gap * m);
      return;
    }
    if (!dotted) {
      dashes(a, b, dash, gapFor(len, dash, gap));
      return;
    }
    // A DOT AT EACH END, and the dots between a dot apart
    // (`EnforceDotsAtEndpoints`): Blink draws the end dots itself, grown
    // or moved by a pixel as the side's length falls, and runs the pattern
    // between them from the start of the second dot.
    final w = width.round(), n = len.toInt(), mod4 = n % 4, mod6 = n % 6;
    var startDot = false, endDot = false;
    var startGrowth = 0, startOffset = 0, endGrowth = 0;
    if ((w == 1 && n.isEven) || (w == 3 && mod6 == 0)) {
      startDot = true;
      startGrowth = 1;
      startOffset = 1;
    }
    if ((w == 2 && (mod4 == 0 || mod4 == 1)) || (w == 3 && (mod6 == 1 || mod6 == 2))) {
      startDot = true;
      startOffset = -1;
    }
    if ((w == 2 && mod4 == 0) || (w == 3 && mod6 == 1)) endDot = true;
    if ((w == 2 && mod4 == 3) || (w == 3 && (mod6 == 4 || mod6 == 5))) {
      startDot = true;
      startOffset = 1;
    }
    if (w == 3 && mod6 == 5) {
      endDot = true;
    } else if (w == 3 && mod6 == 0) {
      endDot = true;
      endGrowth = 1;
    }
    var from = a, to = b;
    if (startDot) {
      canvas.drawLine(a, a + along * (width + startGrowth), paint);
      from = a + along * (2 * width + startOffset);
    }
    if (endDot) {
      canvas.drawLine(b - along * (width + endGrowth), b, paint);
      to = b - along * (width + endGrowth + 1);
    }
    dashes(from, to, width, width);
  }

  /// The gap between [dash]es along [length] nearest [gap] that puts a
  /// dash at both ends (Blink's `SelectBestDashGap`, open path).
  static double gapFor(double length, double dash, double gap) {
    final few = ((length + gap) / (dash + gap)).floorToDouble();
    final fewGap = (length - few * dash) / (few - 1);
    final manyGap = (length - (few + 1) * dash) / few;
    return manyGap <= 0 || (fewGap - gap).abs() < (manyGap - gap).abs() ? fewGap : manyGap;
  }

  @override
  bool operator ==(Object other) =>
      other is DashedBorder &&
      other.dotted == dotted &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom &&
      other.left == left &&
      other.corners == corners;

  @override
  int get hashCode => Object.hash(top, right, bottom, left, dotted, corners);
}
