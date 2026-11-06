import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/rendering.dart';

/// A corner's radii as SHARES of the box: [x] of its width across and [y]
/// of its height down (css-backgrounds-3 5.1), each with a length on top
/// ([dx], [dy]) for a corner the page states as one, and held between
/// [minX] and [maxX] (and [minY] and [maxY]) where the page `clamp()`s it.
/// A radius that comes to less than nothing is nothing, and a corner with
/// either radius nothing is square.
///
/// A right-to-left news site's corners are `clamp(0px, -999900% + 1.43586e+07px, 3px)`
/// across: `FractionalRadius(-9999, 0, dx: 14358600, dy: 3, minX: 0,
/// maxX: 3)`, 3px round a box narrower than 1436px and square round a
/// wider one.
///
/// The most may be a share of the box as well, [maxXShare] of the width
/// (and [maxYShare] of the height) on top of [maxX]: the right-to-left news site's round
/// buttons are `clamp(0px, -999900% + 3.85961e+06px, 50%) 50%`, an ellipse
/// round a box narrower than 386px and square round a wider one.
@immutable
class FractionalRadius {
  const FractionalRadius(
    this.x,
    this.y, {
    this.dx = 0,
    this.dy = 0,
    this.minX,
    this.maxX,
    this.maxXShare,
    this.minY,
    this.maxY,
    this.maxYShare,
  });

  final double x, y, dx, dy;
  final double? minX, maxX, minY, maxY;
  final double? maxXShare, maxYShare;

  static const zero = FractionalRadius(0, 0);

  static double? _most(double? px, double? share, double side) =>
      px == null && share == null ? null : (px ?? 0) + (share ?? 0) * side;

  static double _held(double v, double? lo, double? hi) {
    // clamp(lo, v, hi) is max(lo, min(v, hi)) (css-values-4 10.2).
    if (hi != null) v = math.min(v, hi);
    if (lo != null) v = math.max(v, lo);
    return math.max(0, v);
  }

  /// The radii at [size]. A corner either of whose radii is zero is
  /// square (css-backgrounds-3 5.1).
  Radius resolve(Size size) {
    final rx = _held(x * size.width + dx, minX, _most(maxX, maxXShare, size.width)),
        ry = _held(y * size.height + dy, minY, _most(maxY, maxYShare, size.height));
    return rx == 0 || ry == 0 ? Radius.zero : Radius.elliptical(rx, ry);
  }

  @override
  bool operator ==(Object other) =>
      other is FractionalRadius &&
      other.x == x &&
      other.y == y &&
      other.dx == dx &&
      other.dy == dy &&
      other.minX == minX &&
      other.maxX == maxX &&
      other.minY == minY &&
      other.maxY == maxY &&
      other.maxXShare == maxXShare &&
      other.maxYShare == maxYShare;

  @override
  int get hashCode => Object.hash(x, y, dx, dy, minX, maxX, minY, maxY, maxXShare, maxYShare);

  @override
  String toString() =>
      'FractionalRadius($x, $y, dx: $dx, dy: $dy, x in [$minX, $maxX + $maxXShare], '
      'y in [$minY, $maxY + $maxYShare])';
}

/// A box outline whose corners are PERCENTAGES of the box it is drawn
/// round (css-backgrounds-3 5.1): `border-radius: 5%` is 5% of the width
/// across and 5% of the height down, on whatever size the layout gives
/// the box. A `BorderRadius` is a number fixed before layout, so a box
/// whose size the layout decides had no radius to write. Corners that
/// together reach past the side they share are scaled back until they
/// meet (step 3 there), as `RRect.scaleRadii` does, and the border's inner
/// edge is each radius less the border's width (5.2).
///
/// A French news site's video cards are `width: calc(16% - 13px); border-radius: 5%`,
/// and a scheduling site's handle chips `border-radius: 7.38% 26.09%` round a
/// `min-content` box.
///
/// SIDES OF DIFFERENT WIDTHS in one colour are [widths]: the border is
/// then the ring between the outline and the padding edge, each side that
/// far in and each radius less the sides beside it (css-backgrounds-3
/// 5.2), in [side]'s colour and style, [side]'s own width unread. A side
/// of no width paints nothing, and in a corner the one beside it paints
/// it all. A SaaS landing page's avatar rings are a `border-top: 1px` round `50%`
/// corners, a crescent along the top of an ellipse.
class PercentCornerBorder extends OutlinedBorder {
  /// [all] is every corner a corner of its own does not name.
  const PercentCornerBorder({
    super.side,
    this.widths,
    FractionalRadius? all,
    FractionalRadius? topLeft,
    FractionalRadius? topRight,
    FractionalRadius? bottomRight,
    FractionalRadius? bottomLeft,
  }) : topLeft = topLeft ?? all ?? FractionalRadius.zero,
       topRight = topRight ?? all ?? FractionalRadius.zero,
       bottomRight = bottomRight ?? all ?? FractionalRadius.zero,
       bottomLeft = bottomLeft ?? all ?? FractionalRadius.zero;

  final FractionalRadius topLeft, topRight, bottomRight, bottomLeft;

  /// Each side's width, where the sides differ; null where every side is
  /// [side].
  final EdgeInsets? widths;

  /// The border box's outline at [rect]'s size.
  RRect outer(Rect rect) => RRect.fromRectAndCorners(
    rect,
    topLeft: topLeft.resolve(rect.size),
    topRight: topRight.resolve(rect.size),
    bottomRight: bottomRight.resolve(rect.size),
    bottomLeft: bottomLeft.resolve(rect.size),
  ).scaleRadii();

  /// The padding edge inside [outer]: [frame] in from each side, and each
  /// radius less the sides beside it, square where either comes to
  /// nothing (css-backgrounds-3 5.2).
  static RRect paddingEdge(RRect outer, EdgeInsets frame) {
    Radius less(Radius r, double x, double y) {
      final rx = r.x - x, ry = r.y - y;
      return rx <= 0 || ry <= 0 ? Radius.zero : Radius.elliptical(rx, ry);
    }

    return RRect.fromRectAndCorners(
      frame.deflateRect(outer.outerRect),
      topLeft: less(outer.tlRadius, frame.left, frame.top),
      topRight: less(outer.trRadius, frame.right, frame.top),
      bottomRight: less(outer.brRadius, frame.right, frame.bottom),
      bottomLeft: less(outer.blRadius, frame.left, frame.bottom),
    );
  }

  RRect _inner(Rect rect, double inset) =>
      widths == null ? outer(rect).deflate(inset) : paddingEdge(outer(rect), widths!);

  @override
  EdgeInsetsGeometry get dimensions => widths ?? EdgeInsets.all(side.strokeInset);

  @override
  ShapeBorder scale(double t) => copyWith(side: side.scale(t));

  @override
  PercentCornerBorder copyWith({BorderSide? side}) => PercentCornerBorder(
    side: side ?? this.side,
    widths: widths,
    topLeft: topLeft,
    topRight: topRight,
    bottomRight: bottomRight,
    bottomLeft: bottomLeft,
  );

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()..addRRect(outer(rect));

  /// The padding edge: the border's width in from every side, each radius
  /// that much smaller and none below zero (css-backgrounds-3 5.2).
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path()..addRRect(_inner(rect, side.strokeInset));

  @override
  bool get preferPaintInterior => true;

  @override
  void paintInterior(Canvas canvas, Rect rect, Paint paint, {TextDirection? textDirection}) =>
      canvas.drawRRect(outer(rect), paint);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || (widths == null ? side.width <= 0 : widths == EdgeInsets.zero)) return;
    canvas.drawDRRect(outer(rect), _inner(rect, side.width), Paint()..color = side.color);
  }

  @override
  bool operator ==(Object other) =>
      other is PercentCornerBorder &&
      other.side == side &&
      other.widths == widths &&
      other.topLeft == topLeft &&
      other.topRight == topRight &&
      other.bottomRight == bottomRight &&
      other.bottomLeft == bottomLeft;

  @override
  int get hashCode => Object.hash(side, widths, topLeft, topRight, bottomRight, bottomLeft);

  @override
  String toString() =>
      'PercentCornerBorder($side${widths == null ? '' : ', $widths'}, $topLeft, $topRight, $bottomRight, $bottomLeft)';
}

/// The PADDING EDGE of a box whose border box has [shape]'s corners, as a
/// clip of the padding box: `overflow` clips there (css-overflow-3 3.2).
/// The corners are shares of the border box -- the padding box grown by
/// [frame], the border's widths -- resolved and scaled back there, and
/// each radius is then less the border on its side, square where either
/// comes to nothing (css-backgrounds-3 5.2). The right-to-left news site's buttons clip their
/// labels inside a 1px transparent border round `clamp(0px, -999900% +
/// 3.85961e+06px, 3px)` corners.
///
/// With [borderBox] the box clipped is the BORDER box -- the stack of the
/// boxes placed against the block, which sits there -- and the corners are
/// resolved on the size the clip is handed, the padding edge [frame] in
/// from it: a box at a negative z under a block that clips is cut at that
/// edge too (css-overflow-3 3.1; `fixtures/stack-under-clip` n2).
class PaddingEdgeClip extends CustomClipper<Path> {
  const PaddingEdgeClip(this.shape, this.frame, {this.borderBox = false});

  final PercentCornerBorder shape;
  final EdgeInsets frame;

  /// Whether the size the clip is handed is the border box's rather than
  /// the padding box's.
  final bool borderBox;

  @override
  Path getClip(Size size) {
    final o = shape.outer(
      borderBox
          ? Offset.zero & size
          : Rect.fromLTRB(-frame.left, -frame.top, size.width + frame.right, size.height + frame.bottom),
    );
    return Path()..addRRect(PercentCornerBorder.paddingEdge(o, frame));
  }

  @override
  bool shouldReclip(PaddingEdgeClip old) => old.shape != shape || old.frame != frame || old.borderBox != borderBox;
}
