/// `clip-path` basic shapes that are not a rectangle: a circle, an
/// ellipse, a polygon and a ring, each read off the box it cuts at the
/// size it is laid out at.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'gradient.dart' show OvalExtent;

/// A point of a `clip-path` shape: a length in px plus a share of the
/// box along each axis (css-shapes-1 3.1: a `<length-percentage>` of the
/// reference box's width across and its height down). `100%
/// calc(100% - 24px)` is `ClipPoint(xShare: 1, y: -24, yShare: 1)`.
@immutable
class ClipPoint {
  const ClipPoint({this.x = 0, this.xShare = 0, this.y = 0, this.yShare = 0});

  final double x, xShare, y, yShare;

  Offset at(Size size) => Offset(x + xShare * size.width, y + yShare * size.height);

  @override
  bool operator ==(Object other) =>
      other is ClipPoint && other.x == x && other.xShare == xShare && other.y == y && other.yShare == yShare;

  @override
  int get hashCode => Object.hash(x, xShare, y, yShare);
}

/// `clip-path: circle(r at x y)` (css-shapes-1 3.1.2): what of the box
/// lies inside a circle whose radius is a length plus a share of the
/// box's diagonal over root two -- the `closest-side`-free reading of a
/// percentage radius -- centred at [center]. `circle(50%)` on a square
/// box is its inscribed circle; on a wider one it runs past the short
/// sides. A SaaS landing page's avatars are `circle(50%)` round a box the layout sizes.
///
/// Or the radius is how far [center] is from the side of the box the
/// [extent] names -- `circle(closest-side at 30% 40%)` reaches the nearer
/// of the left side and the top on a box wide enough, and the nearer of
/// all four whatever its size -- and [radius] and [radiusShare] are not
/// read.
class CircleClip extends CustomClipper<Path> {
  const CircleClip({
    this.radius = 0,
    this.radiusShare = 0,
    this.center = const ClipPoint(xShare: 0.5, yShare: 0.5),
    this.extent,
  });

  /// The radius in px, and as a share of `sqrt(w² + h²) / sqrt(2)`.
  final double radius, radiusShare;

  final ClipPoint center;

  /// The side the radius reaches, where a keyword says it:
  /// `closest-side` or `farthest-side` (or a corner, as a radial
  /// gradient's).
  final OvalExtent? extent;

  @override
  Path getClip(Size size) {
    final c = center.at(size);
    final double r;
    if (extent case final e?) {
      final l = c.dx.abs(), rt = (size.width - c.dx).abs(), t = c.dy.abs(), b = (size.height - c.dy).abs();
      r = switch (e) {
        OvalExtent.closestSide => math.min(math.min(l, rt), math.min(t, b)),
        OvalExtent.farthestSide => math.max(math.max(l, rt), math.max(t, b)),
        OvalExtent.closestCorner => math.sqrt(math.pow(math.min(l, rt), 2) + math.pow(math.min(t, b), 2)),
        OvalExtent.farthestCorner => math.sqrt(math.pow(math.max(l, rt), 2) + math.pow(math.max(t, b), 2)),
      };
    } else {
      r = math.max(0.0, radius + radiusShare * math.sqrt((size.width * size.width + size.height * size.height) / 2));
    }
    return Path()..addOval(Rect.fromCircle(center: c, radius: r));
  }

  @override
  bool shouldReclip(CircleClip old) =>
      old.radius != radius || old.radiusShare != radiusShare || old.center != center || old.extent != extent;
}

/// `clip-path: ellipse(rx ry at x y)` (css-shapes-1 3.1.3): what of the
/// box lies inside an ellipse centred at [center], each radius a length
/// plus a share of the box along its own axis -- [radiusX] and
/// [radiusXShare] of the width across, [radiusY] and [radiusYShare] of the
/// height down -- or, where [extentX] (or [extentY]) names a side, how far
/// [center] is from the nearer or farther side ON THAT AXIS
/// (`closest-side` and `farthest-side` measure an ellipse's radius in its
/// own dimension, where a circle's takes the nearer of all four). No
/// radius stated is `closest-side` both ways.
/// `ellipse(closest-side farthest-side at 30% 40%)` on a 200x100 box is 60
/// across and 60 down.
class EllipseClip extends CustomClipper<Path> {
  const EllipseClip({
    this.radiusX = 0,
    this.radiusXShare = 0,
    this.radiusY = 0,
    this.radiusYShare = 0,
    this.center = const ClipPoint(xShare: 0.5, yShare: 0.5),
    this.extentX,
    this.extentY,
  }) : assert(extentX != OvalExtent.closestCorner && extentX != OvalExtent.farthestCorner),
       assert(extentY != OvalExtent.closestCorner && extentY != OvalExtent.farthestCorner);

  /// The radius across in px, and as a share of the box's width.
  final double radiusX, radiusXShare;

  /// The radius down in px, and as a share of the box's height.
  final double radiusY, radiusYShare;

  final ClipPoint center;

  /// The side each radius reaches, where a keyword says it (only
  /// `closestSide` and `farthestSide`); [radiusX] and [radiusXShare] (or
  /// the `Y` pair) are not read then.
  final OvalExtent? extentX, extentY;

  @override
  Path getClip(Size size) {
    final c = center.at(size);
    double side(OvalExtent e, double near, double far) =>
        e == OvalExtent.farthestSide ? math.max(near.abs(), far.abs()) : math.min(near.abs(), far.abs());
    final rx = extentX != null
        ? side(extentX!, c.dx, size.width - c.dx)
        : math.max(0.0, radiusX + radiusXShare * size.width);
    final ry = extentY != null
        ? side(extentY!, c.dy, size.height - c.dy)
        : math.max(0.0, radiusY + radiusYShare * size.height);
    return Path()..addOval(Rect.fromCenter(center: c, width: 2 * rx, height: 2 * ry));
  }

  @override
  bool shouldReclip(EllipseClip old) =>
      old.radiusX != radiusX ||
      old.radiusXShare != radiusXShare ||
      old.radiusY != radiusY ||
      old.radiusYShare != radiusYShare ||
      old.center != center ||
      old.extentX != extentX ||
      old.extentY != extentY;
}

/// `clip-path: polygon(...)` (css-shapes-1 3.1.4): what of the box lies
/// inside the polygon through [points], filled by the non-zero rule or,
/// with [evenOdd], the even-odd one. A record catalogue's tabs end in a `::after`
/// cut to the triangle `polygon(0 0, 0 100%, 100% 0)`.
class PolygonClip extends CustomClipper<Path> {
  const PolygonClip(this.points, {this.evenOdd = false});

  final List<ClipPoint> points;

  final bool evenOdd;

  @override
  Path getClip(Size size) => Path()
    ..fillType = evenOdd ? PathFillType.evenOdd : PathFillType.nonZero
    ..addPolygon([for (final p in points) p.at(size)], true);

  @override
  bool shouldReclip(PolygonClip old) {
    if (old.evenOdd != evenOdd || old.points.length != points.length) return true;
    for (var i = 0; i < points.length; i++) {
      if (old.points[i] != points[i]) return true;
    }
    return false;
  }
}

/// What of a box lies between two of its edges: the border box (or the box
/// [outer] cuts from it) less the one [inner] cuts from it, each with the
/// corners of [borderRadius] brought in as far as its edge is -- the inner
/// radius CSS gives a padding or content box (css-backgrounds-3 5.1:
/// the radius less the border and padding beside it, never below 0).
///
/// It is what mask layers of one opaque colour, each in the border,
/// padding or content box, composite to (css-masking-1 7.9): a price-table site's
/// gradient borders are a content-box layer `exclude`d from a border-box
/// one, which keeps the ring of padding between them.
class RingClip extends CustomClipper<Path> {
  const RingClip({this.borderRadius = BorderRadius.zero, this.outer = EdgeInsets.zero, this.inner});

  final BorderRadius borderRadius;

  /// Taken off the border box for the outer edge.
  final EdgeInsets outer;

  /// Taken off the border box for the inner edge; null for none.
  final EdgeInsets? inner;

  static RRect _cut(RRect r, EdgeInsets e) {
    Radius less(Radius c, double x, double y) => Radius.elliptical(math.max(0, c.x - x), math.max(0, c.y - y));
    return RRect.fromRectAndCorners(
      Rect.fromLTRB(
        r.left + e.left,
        r.top + e.top,
        math.max(r.left + e.left, r.right - e.right),
        math.max(r.top + e.top, r.bottom - e.bottom),
      ),
      topLeft: less(r.tlRadius, e.left, e.top),
      topRight: less(r.trRadius, e.right, e.top),
      bottomRight: less(r.brRadius, e.right, e.bottom),
      bottomLeft: less(r.blRadius, e.left, e.bottom),
    );
  }

  @override
  Path getClip(Size size) {
    final box = borderRadius.toRRect(Offset.zero & size);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(_cut(box, outer));
    if (inner case final i?) {
      final hole = _cut(box, i);
      if (!hole.isEmpty) path.addRRect(hole);
    }
    return path;
  }

  @override
  bool shouldReclip(RingClip old) => old.borderRadius != borderRadius || old.outer != outer || old.inner != inner;
}
