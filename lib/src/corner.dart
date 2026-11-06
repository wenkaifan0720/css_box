import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// A box outline whose corners are CSS `corner-shape` curves
/// (css-borders-4 3.7).
///
/// `border-radius` sizes each corner and `superellipse(K)` bends it: the
/// corner is a quarter of the curve |x|^n + |y|^n = 1, n = 2^K, fitted to
/// the corner's radius box. K = 1 is the elliptical corner a
/// [RoundedRectangleBorder] draws, 2 the `squircle`, 0 a `bevel` and
/// infinity a `square` corner; a negative K is the same curve turned in, a
/// `scoop` at -1 and a `notch` at minus infinity.
///
/// A browser vendor's app icons are `border-radius: 45%; corner-shape:
/// superellipse(2)` round a 3px border, and drawn with round corners they
/// were circles.
class CornerShapeBorder extends OutlinedBorder {
  const CornerShapeBorder({super.side, this.borderRadius = BorderRadius.zero, this.curvature = 1});

  /// Each corner's radius box, as `border-radius` gives it.
  final BorderRadiusGeometry borderRadius;

  /// The `superellipse()` parameter every corner is drawn with.
  final double curvature;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.strokeInset);

  @override
  ShapeBorder scale(double t) =>
      CornerShapeBorder(side: side.scale(t), borderRadius: borderRadius * t, curvature: curvature);

  @override
  CornerShapeBorder copyWith({BorderSide? side, BorderRadiusGeometry? borderRadius, double? curvature}) =>
      CornerShapeBorder(
        side: side ?? this.side,
        borderRadius: borderRadius ?? this.borderRadius,
        curvature: curvature ?? this.curvature,
      );

  RRect _box(Rect rect, TextDirection? textDirection) => borderRadius.resolve(textDirection).toRRect(rect).scaleRadii();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(_box(rect, textDirection), curvature);

  /// The padding edge: the border's width in from every side, each radius
  /// that much smaller (css-backgrounds-3 5.2), the corners the same shape.
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(_box(rect, textDirection).deflate(side.strokeInset), curvature);

  /// The outline moved out by [spread] as a shadow's spread moves it, or
  /// null where this cannot say how.
  ///
  /// A BEVEL'S EDGES MOVE OUT PARALLEL: each side [spread] further out and
  /// each corner's straight cut [spread] further out along its normal,
  /// which on a corner of one radius is a bevel of the radius grown by
  /// `(2 - sqrt(2))` of the spread, round the box grown by the spread; a
  /// square corner stays square. Chrome's `0 0 0 10px` shadow round a
  /// `16px` bevel meets the edges 21.86px from the corner of the shadow's
  /// box, and round `8px` spread `20px` 19.7px -- read off its pixels, to
  /// within Skia's anti-aliasing. Any other curve, a corner of two radii,
  /// or a spread that shrinks the outline is not known here: null.
  Path? getSpreadPath(Rect rect, double spread, {TextDirection? textDirection}) {
    if (spread == 0) return getOuterPath(rect, textDirection: textDirection);
    final box = _box(rect, textDirection);
    final radii = [box.tlRadius, box.trRadius, box.brRadius, box.blRadius];
    if (curvature != 0 || spread < 0 || radii.any((r) => r.x != r.y)) return null;
    Radius grow(Radius r) => r.x > 0 ? Radius.circular(r.x + spread * (2 - math.sqrt2)) : Radius.zero;
    return _path(
      RRect.fromRectAndCorners(
        box.outerRect.inflate(spread),
        topLeft: grow(box.tlRadius),
        topRight: grow(box.trRadius),
        bottomRight: grow(box.brRadius),
        bottomLeft: grow(box.blRadius),
      ),
      curvature,
    );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width <= 0) return;
    final outer = _box(rect, textDirection);
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(_path(outer, curvature), Offset.zero)
      ..addPath(_path(outer.deflate(side.width), curvature), Offset.zero);
    canvas.drawPath(ring, Paint()..color = side.color);
  }

  static Path _path(RRect r, double k) {
    // Each corner clockwise from the top left: its point, and the ends of
    // its curve on the edge coming in and on the edge going out.
    final corners = [
      (Offset(r.left, r.top), Offset(r.left, r.top + r.tlRadiusY), Offset(r.left + r.tlRadiusX, r.top)),
      (Offset(r.right, r.top), Offset(r.right - r.trRadiusX, r.top), Offset(r.right, r.top + r.trRadiusY)),
      (Offset(r.right, r.bottom), Offset(r.right, r.bottom - r.brRadiusY), Offset(r.right - r.brRadiusX, r.bottom)),
      (Offset(r.left, r.bottom), Offset(r.left + r.blRadiusX, r.bottom), Offset(r.left, r.bottom - r.blRadiusY)),
    ];
    final path = Path();
    for (var i = 0; i < corners.length; i++) {
      final (p, a, b) = corners[i];
      if (i == 0) {
        path.moveTo(a.dx, a.dy);
      } else {
        path.lineTo(a.dx, a.dy);
      }
      _corner(path, p, a, b, k);
    }
    return path..close();
  }

  static void _corner(Path path, Offset p, Offset a, Offset b, double k) {
    // The curve's centre: the corner of the radius box across from [p].
    final q = a + b - p;
    if (a == p || b == p || k.isInfinite) {
      final turn = k < 0 && k.isInfinite ? q : p;
      path
        ..lineTo(turn.dx, turn.dy)
        ..lineTo(b.dx, b.dy);
      return;
    }
    final e = 2 / math.pow(2, k.abs());
    final span = math.max((a - p).distance, (b - p).distance);
    final steps = (span / 2).ceil().clamp(8, 48);
    for (var i = 1; i < steps; i++) {
      // A turned-in corner is the curve reflected through the middle of its
      // chord, walked the other way so it still runs from [a] to [b].
      final t = (k >= 0 ? i / steps : 1 - i / steps) * math.pi / 2;
      final c = math.pow(math.max(0.0, math.cos(t)), e).toDouble();
      final s = math.pow(math.max(0.0, math.sin(t)), e).toDouble();
      var pt = q + (a - q) * c + (b - q) * s;
      if (k < 0) pt = a + b - pt;
      path.lineTo(pt.dx, pt.dy);
    }
    path.lineTo(b.dx, b.dy);
  }

  @override
  bool operator ==(Object other) =>
      other is CornerShapeBorder &&
      other.side == side &&
      other.borderRadius == borderRadius &&
      other.curvature == curvature;

  @override
  int get hashCode => Object.hash(side, borderRadius, curvature);

  @override
  String toString() => 'CornerShapeBorder($side, $borderRadius, curvature: $curvature)';
}
