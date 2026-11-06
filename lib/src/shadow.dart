import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

import 'corner.dart';
import 'percent_corner.dart';

/// [outer], to have the outline a shadow is cut to added to it: an even-odd
/// path, so what is added inside [outer] is a hole in it.
///
/// `Path.combine(PathOperation.difference, ...)` says the same and Flutter's
/// web renderer does not cut the hole (3.47): a recipe app's search tabs, whose
/// underline is an `inset` shadow, came out as solid blocks of it, and an
/// outer shadow's clip let the shadow under the box. An even-odd fill is
/// drawn alike on every backend, and on the engine it is the same coverage.
/// What is added lies inside [outer]: the reach round each shadow is that.
Path _cut(Rect outer) => Path()
  ..fillType = PathFillType.evenOdd
  ..addRect(outer);

/// The shadows an outer `box-shadow` casts OUTSIDE a box.
///
/// CSS cuts an outer shadow out of the border box (css-backgrounds-3
/// 7.1.1): it falls only outside the box, so a box whose background shows
/// through -- or that has none -- is not in its own shade. A
/// [BoxDecoration]'s `boxShadow` paints the whole silhouette under the box,
/// which only an opaque background hides: a pricing page's plan cards are
/// rounded panels with no fill inside a ring of shadows.
///
/// The list is in PAINT ORDER: the last one is on top, which is the first
/// one `box-shadow` names.
class OuterShadow extends Decoration {
  const OuterShadow({required this.shadows, this.borderRadius, this.corners, this.shape})
    : assert(shape == null || corners == null && borderRadius == null);

  final List<BoxShadow> shadows;

  /// The border box's corners, which the shadows grow from and are cut to.
  final BorderRadius? borderRadius;

  /// The border box's corners as SHARES of its size (`border-radius: 5%`,
  /// css-backgrounds-3 5.1), read at the size the box is painted at; where
  /// given, it is the outline and [borderRadius] is not read. A French news site's video
  /// thumbnails are `border-radius: 5%` pictures with a shadow under them
  /// and no background.
  final PercentCornerBorder? corners;

  /// An outline NO PAIR OF RADII DESCRIBES, given whole: a `corner-shape`
  /// (css-borders-4) bevels or scoops the corner its radius boxes. The
  /// shadows are cast of that outline, moved by their offsets, and cut out
  /// of it, as Blink casts them of the box's contour. A spread grows an
  /// outline by its radii, which this one has none of: a shadow of any
  /// spread is not drawn round it -- but round a [CornerShapeBorder] that
  /// can say where its edges move to ([CornerShapeBorder.getSpreadPath], a
  /// bevel's), which is that.
  final ShapeBorder? shape;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _OuterShadowPainter(this);

  @override
  bool get isComplex => true;

  @override
  bool operator ==(Object other) =>
      other is OuterShadow &&
      other.borderRadius == borderRadius &&
      other.corners == corners &&
      other.shape == shape &&
      other.shadows.length == shadows.length &&
      InnerShadow._same(other.shadows, shadows);

  @override
  int get hashCode => Object.hash(borderRadius, corners, shape, Object.hashAll(shadows));
}

class _OuterShadowPainter extends BoxPainter {
  _OuterShadowPainter(this.deco);

  final OuterShadow deco;

  /// The box's outline moved out by [s] as a spread moves it: each corner
  /// grows by the spread, less where it was sharper than the spread is
  /// long, so a square corner stays square (css-backgrounds-3 7.1.1).
  static RRect _spread(RRect r, double s) {
    if (s == 0) return r;
    double grow(double v) {
      if (s < 0) return math.max(0.0, v + s);
      if (v >= s) return v + s;
      final q = v / s - 1;
      return v + s * (1 + q * q * q);
    }

    final o = r.outerRect.inflate(s);
    if (o.width <= 0 || o.height <= 0) return RRect.zero;
    return RRect.fromRectAndCorners(
      o,
      topLeft: Radius.elliptical(grow(r.tlRadiusX), grow(r.tlRadiusY)),
      topRight: Radius.elliptical(grow(r.trRadiusX), grow(r.trRadiusY)),
      bottomRight: Radius.elliptical(grow(r.brRadiusX), grow(r.brRadiusY)),
      bottomLeft: Radius.elliptical(grow(r.blRadiusX), grow(r.blRadiusY)),
    );
  }

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;
    final box = offset & size;
    var reach = 1.0;
    for (final s in deco.shadows) {
      reach = math.max(reach, s.blurRadius * 3 + s.spreadRadius.abs() + s.offset.distance + 1);
    }
    if (deco.shape case final shape?) {
      final outline = shape.getOuterPath(box, textDirection: configuration.textDirection);
      canvas.save();
      canvas.clipPath(_cut(box.inflate(reach))..addPath(outline, Offset.zero));
      for (final s in deco.shadows) {
        final cast = s.spreadRadius == 0
            ? outline
            : shape is CornerShapeBorder
            ? shape.getSpreadPath(box, s.spreadRadius, textDirection: configuration.textDirection)
            : null;
        if (cast == null) continue;
        canvas.drawPath(cast.shift(s.offset), s.toPaint());
      }
      canvas.restore();
      return;
    }
    final radius = deco.borderRadius?.resolve(configuration.textDirection);
    final edge = deco.corners?.outer(box) ?? (radius == null ? RRect.fromRectXY(box, 0, 0) : radius.toRRect(box));
    final outside = _cut(box.inflate(reach))..addRRect(edge);
    // A SHADOW WITH NO BLUR is its outline less the box's, filled as that
    // one path. Cut out by a clip instead, it leaks where the two share an
    // edge at a fraction of a pixel: the clip's anti-aliased edge and the
    // shadow's each cover part of the pixel, and the product is a seam of
    // the shadow's colour along the box. A docs site's contents links are a
    // `-2px 0 0` rule at their left on no background, 32.59 tall, and each
    // drew a hairline along its top and bottom edges, across its width,
    // that Chrome -- which paints the box snapped to pixels -- does not
    // (fixtures/shadow-hard-edge-seam). A blurred shadow keeps the clip, and
    // so does every shadow on the web, whose renderer combines no paths
    // ([_cut]).
    for (final s in deco.shadows) {
      final cast = _spread(edge, s.spreadRadius);
      if (cast.isEmpty) continue;
      if (s.blurRadius == 0 && !kIsWeb) {
        canvas.drawPath(
          Path.combine(PathOperation.difference, Path()..addRRect(cast.shift(s.offset)), Path()..addRRect(edge)),
          s.toPaint(),
        );
        continue;
      }
      canvas.save();
      canvas.clipPath(outside);
      canvas.drawRRect(cast.shift(s.offset), s.toPaint());
      canvas.restore();
    }
  }
}

/// The shadows an `inset` `box-shadow` casts INSIDE a box.
///
/// An inner shadow is what the box would be in the shade of if everything
/// outside its padding edge were opaque (css-backgrounds-3 7.1.1): the
/// same blurred silhouette an outer shadow paints, only of the hole rather
/// than of the box, and clipped to the padding box so none of it lands on
/// the border. A [BoxDecoration]'s `boxShadow` paints outside the box and
/// cannot say that, so this is a decoration of its own -- painted over the
/// background and under the content, which is where CSS puts it.
///
/// The list is in PAINT ORDER: the last one is on top, which is the first
/// one `box-shadow` names.
class InnerShadow extends Decoration {
  const InnerShadow({required this.shadows, this.inset, this.borderRadius, this.corners})
    : assert(corners == null || borderRadius == null);

  final List<BoxShadow> shadows;

  /// What to take off the box to reach the padding edge: the border.
  final EdgeInsets? inset;

  /// The padding box's corners, which the shadow is cut to.
  final BorderRadius? borderRadius;

  /// The BORDER box's corners as shares of its size, in place of
  /// [borderRadius]: read at the size the box is painted at, and the
  /// padding edge [inset] in from them, each radius less the sides beside
  /// it (see [PercentCornerBorder.paddingEdge]). A Russian news site's avatar rings are
  /// `inset` shadows on `border-radius: 50%`.
  final PercentCornerBorder? corners;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _InnerShadowPainter(this);

  @override
  bool get isComplex => true;

  @override
  Path getClipPath(Rect rect, TextDirection textDirection) => Path()..addRRect(_edge(rect, textDirection));

  /// The padding edge of a box painted at [rect]: the shadow's clip.
  RRect _edge(Rect rect, TextDirection? textDirection) {
    if (corners case final corners?) {
      final outer = corners.outer(rect);
      return inset == null ? outer : PercentCornerBorder.paddingEdge(outer, inset!);
    }
    final box = inset == null ? rect : inset!.deflateRect(rect);
    return borderRadius?.resolve(textDirection).toRRect(box) ?? RRect.fromRectXY(box, 0, 0);
  }

  @override
  bool operator ==(Object other) =>
      other is InnerShadow &&
      other.inset == inset &&
      other.borderRadius == borderRadius &&
      other.corners == corners &&
      other.shadows.length == shadows.length &&
      _same(other.shadows, shadows);

  static bool _same(List<BoxShadow> a, List<BoxShadow> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(inset, borderRadius, corners, Object.hashAll(shadows));
}

class _InnerShadowPainter extends BoxPainter {
  _InnerShadowPainter(this.deco);

  final InnerShadow deco;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;
    final outer = offset & size;
    final clip = deco._edge(outer, configuration.textDirection);
    final box = clip.outerRect;
    if (box.isEmpty) return;
    canvas.save();
    canvas.clipRRect(clip);
    for (final s in deco.shadows) {
      // The hole the light comes through: the padding box, pulled in by
      // the spread and moved by the offset. Everything outside it is in
      // shadow, and the clip keeps only the part inside the box.
      final hole = clip.deflate(s.spreadRadius).shift(s.offset);
      final reach = s.blurRadius * 3 + s.spreadRadius.abs() + s.offset.distance + 1;
      // A spread that closes the hole leaves the whole box in shadow.
      final shade = _cut(box.inflate(reach));
      if (!hole.isEmpty) shade.addRRect(hole);
      canvas.drawPath(shade, s.toPaint());
    }
    canvas.restore();
  }
}
