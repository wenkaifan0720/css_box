import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'percent_corner.dart' show PercentCornerBorder;

/// Turns a [LinearGradient] that runs left to right into one that runs at
/// a CSS angle through the middle of the box.
///
/// CSS measures a `linear-gradient` angle clockwise from straight up, and
/// makes the gradient exactly as long as the box is across at that angle,
/// so its first and last colours land on two of the box's corners
/// (css-images-3 3.1.1). [LinearGradient.begin] and [LinearGradient.end]
/// are points in the box, and two corners are only that line when the box
/// is square; this works the line out at paint time from the box it is
/// painted in, so the gradient keeps its angle at any size.
///
/// Leave [LinearGradient.begin] and [LinearGradient.end] at their defaults.
class GradientAngle extends GradientTransform {
  /// [degrees] clockwise from straight up, as `linear-gradient(135deg, ...)`
  /// states it. [inset] is the box a background is DRAWN in where that is
  /// not the box a decoration paints: `background-origin` is the padding
  /// box, and a `BoxDecoration` knows only the border one.
  const GradientAngle(double this.degrees, {this.inset}) : corner = null;

  /// Toward a [corner] of the box, as `linear-gradient(to top right, ...)`
  /// states it: the middle of the gradient runs through the other two
  /// corners, so the angle is the box's shape to decide.
  const GradientAngle.toward(Alignment this.corner, {this.inset}) : degrees = null;

  /// What to take off the box before the gradient is laid out in it.
  final EdgeInsets? inset;

  /// The angle, clockwise from straight up; null when [corner] decides it.
  final double? degrees;

  /// The corner the gradient runs toward; null when [degrees] decides it.
  final Alignment? corner;

  /// How long the CSS gradient line is in [bounds]: as long as the box it
  /// is laid out in is across at the angle (css-images-3 3.1.1).
  double lineLength(Rect bounds) {
    final box = inset == null ? bounds : inset!.deflateRect(bounds);
    final w = box.width, h = box.height;
    if (w <= 0 || h <= 0) return 0;
    final radians = switch (corner) {
      final c? => math.atan2(c.x * h, -c.y * w),
      null => degrees! * math.pi / 180,
    };
    return (w * math.sin(radians)).abs() + (h * math.cos(radians)).abs();
  }

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    // The shader's own space is the box the decoration paints; the
    // gradient is laid out in the box inside the border, and the two are
    // one only where there is no border between them.
    final outer = bounds;
    final box = inset == null ? bounds : inset!.deflateRect(bounds);
    final w = box.width, h = box.height;
    if (w <= 0 || h <= 0 || outer.width <= 0) return null;
    final radians = switch (corner) {
      // Square to the diagonal between the other two corners.
      final c? => math.atan2(c.x * h, -c.y * w),
      null => degrees! * math.pi / 180,
    };
    final length = (w * math.sin(radians)).abs() + (h * math.cos(radians)).abs();
    final center = box.center;
    return Matrix4.translationValues(center.dx, center.dy, 0)
      ..multiply(Matrix4.rotationZ(radians - math.pi / 2))
      ..multiply(Matrix4.diagonal3Values(length / outer.width, 1, 1))
      ..multiply(Matrix4.translationValues(-outer.center.dx, -outer.center.dy, 0));
  }

  @override
  bool operator ==(Object other) =>
      other is GradientAngle && other.degrees == degrees && other.corner == corner && other.inset == inset;

  @override
  int get hashCode => Object.hash(degrees, corner, inset);

  @override
  String toString() => corner == null ? 'GradientAngle($degrees)' : 'GradientAngle.toward($corner)';
}

/// Turns a [LinearGradient] into one PERIOD of a `repeating-linear-gradient`,
/// laid along the CSS gradient line and tiled over the whole box.
///
/// A repeating gradient states its stops in px along a line that is as long
/// as the box is across at the gradient's angle (css-images-3 3.1.1, 3.6),
/// and repeats them in both directions for as long as the line is. Neither
/// half of that is a fraction of anything a stop list can hold: the period
/// is px and the line is the box's. So the stops are written as fractions
/// of ONE PERIOD, [TileMode.repeated] lays that period out end to end, and
/// this puts the period where the first stop is and turns it to the angle.
///
/// Leave [LinearGradient.begin] and [LinearGradient.end] at their defaults
/// and set `tileMode: TileMode.repeated`.
class GradientStripe extends GradientTransform {
  /// [degrees] clockwise from straight up, [start] the first stop's offset
  /// in px from the start of the gradient line, [period] the px the stop
  /// list spans.
  const GradientStripe({required double this.degrees, required this.start, required this.period, this.inset})
    : corner = null;

  /// Toward a [corner] of the box, as `repeating-linear-gradient(to top
  /// right, ...)` states it.
  const GradientStripe.toward(Alignment this.corner, {required this.start, required this.period, this.inset})
    : degrees = null;

  final double? degrees;
  final Alignment? corner;

  /// The first stop's offset along the gradient line, in px.
  final double start;

  /// What the stop list spans, in px: one tile.
  final double period;

  /// What to take off the box before the gradient is laid out in it: the
  /// border, which `background-origin` puts the background inside of.
  final EdgeInsets? inset;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final outer = bounds;
    final box = inset == null ? bounds : inset!.deflateRect(bounds);
    final w = box.width, h = box.height;
    if (w <= 0 || h <= 0 || period <= 0 || outer.width <= 0) return null;
    final radians = switch (corner) {
      final c? => math.atan2(c.x * h, -c.y * w),
      null => degrees! * math.pi / 180,
    };
    // The line the stops are measured along: through the middle of the box
    // at the angle, and as long as the box is across it.
    final length = (w * math.sin(radians)).abs() + (h * math.cos(radians)).abs();
    final dir = Offset(math.sin(radians), -math.cos(radians));
    final middle = box.center + dir * (start + period / 2 - length / 2);
    return Matrix4.translationValues(middle.dx, middle.dy, 0)
      ..multiply(Matrix4.rotationZ(radians - math.pi / 2))
      ..multiply(Matrix4.diagonal3Values(period / outer.width, 1, 1))
      ..multiply(Matrix4.translationValues(-outer.center.dx, -outer.center.dy, 0));
  }

  @override
  bool operator ==(Object other) =>
      other is GradientStripe &&
      other.degrees == degrees &&
      other.corner == corner &&
      other.start == start &&
      other.period == period &&
      other.inset == inset;

  @override
  int get hashCode => Object.hash(degrees, corner, start, period, inset);

  @override
  String toString() => 'GradientStripe(${corner ?? degrees}, start: $start, period: $period)';
}

/// A [LinearGradient] whose stops are placed partly in PX along the
/// gradient line. `black 160px` and `black calc(100% - 160px)` are
/// fractions only of a line the box decides the length of (css-images-3
/// 3.5.1): a SaaS landing page fades its logo rows and price digits out over 160px at
/// each end, however wide the row is.
///
/// A stop is [stops] of the line plus [lengths] px along it, worked out at
/// paint time. A stop behind the one before it is moved up to it, and the
/// line is cut at its ends where a stop falls off one, as CSS does.
class LengthStopsGradient extends LinearGradient {
  const LengthStopsGradient({
    super.begin,
    super.end,
    required super.colors,
    required List<double> super.stops,
    required this.lengths,
    super.tileMode,
    super.transform,
  });

  /// Each stop's px along the gradient line, on top of its share of it.
  final List<double> lengths;

  @override
  Shader createShader(Rect rect, {TextDirection? textDirection}) {
    final t = transform;
    final length = t is GradientAngle
        ? t.lineLength(rect)
        : (end.resolve(textDirection).withinRect(rect) - begin.resolve(textDirection).withinRect(rect)).distance;
    final at = <double>[];
    for (var i = 0; i < colors.length; i++) {
      var p = stops![i] + (length > 0 ? lengths[i] / length : 0);
      if (at.isNotEmpty && p < at.last) p = at.last;
      at.add(p);
    }
    Color inkAt(double p) {
      var i = 0;
      while (i < at.length - 1 && at[i + 1] < p) {
        i++;
      }
      if (i == at.length - 1) return colors.last;
      final span = at[i + 1] - at[i];
      return Color.lerp(colors[i], colors[i + 1], span == 0 ? 1 : ((p - at[i]) / span).clamp(0.0, 1.0))!;
    }

    final points = <double>[];
    final inks = <Color>[];
    void put(double p, Color c) {
      points.add(p);
      inks.add(c);
    }

    if (at.first > 0) put(0, colors.first);
    if (at.first < 0) put(0, inkAt(0));
    for (var i = 0; i < at.length; i++) {
      if (at[i] >= 0 && at[i] <= 1) put(at[i], colors[i]);
    }
    if (at.last > 1) put(1, inkAt(1));
    if (at.last < 1) put(1, colors.last);
    return LinearGradient(
      begin: begin,
      end: end,
      colors: inks,
      stops: points,
      tileMode: tileMode,
      transform: transform,
    ).createShader(rect, textDirection: textDirection);
  }

  @override
  bool operator ==(Object other) {
    if (other is! LengthStopsGradient || !(super == other) || other.lengths.length != lengths.length) return false;
    for (var i = 0; i < lengths.length; i++) {
      if (other.lengths[i] != lengths[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(super.hashCode, Object.hashAll(lengths));
}

/// A [RadialGradient] whose stops are placed partly in PX along the
/// gradient ray, the ending shape's horizontal radius, which the box
/// decides (css-images-3 3.2.1, 3.5.1): a weather site's table cells shade a corner
/// with `radial-gradient(at 100% 100%, rgba(0, 0, 0, .2), transparent
/// 8px)`, over a ray as long as the cell is wide.
///
/// A stop is [stops] of the ray plus [lengths] px along it, worked out at
/// paint time; a stop behind the one before it is moved up to it. A stop
/// past the ending shape carries the gradient on past it, as CSS does:
/// the shape the shader draws is grown to the farthest stop and every stop
/// taken as a share of that. [transform] is the [GradientOval] that says
/// the shape; leave [center] and [radius] as [GradientOval] asks.
class LengthStopsRadialGradient extends RadialGradient {
  const LengthStopsRadialGradient({
    required super.colors,
    required List<double> super.stops,
    required this.lengths,
    super.tileMode,
    required GradientOval super.transform,
  });

  /// Each stop's px along the gradient ray, on top of its share of it.
  final List<double> lengths;

  @override
  Shader createShader(Rect rect, {TextDirection? textDirection}) {
    final oval = transform! as GradientOval;
    final ray = oval.ray(rect) ?? 0;
    final at = <double>[];
    for (var i = 0; i < colors.length; i++) {
      var p = stops![i] + (ray > 0 ? lengths[i] / ray : 0);
      if (at.isNotEmpty && p < at.last) p = at.last;
      at.add(p);
    }
    Color inkAt(double p) {
      var i = 0;
      while (i < at.length - 1 && at[i + 1] < p) {
        i++;
      }
      if (i == at.length - 1) return colors.last;
      final span = at[i + 1] - at[i];
      return Color.lerp(colors[i], colors[i + 1], span == 0 ? 1 : ((p - at[i]) / span).clamp(0.0, 1.0))!;
    }

    // The shape grown to the farthest stop, and each stop a share of it.
    final grow = math.max(1.0, at.last);
    final points = <double>[];
    final inks = <Color>[];
    void put(double p, Color c) {
      points.add(p / grow);
      inks.add(c);
    }

    if (at.first > 0) put(0, colors.first);
    if (at.first < 0) put(0, inkAt(0));
    for (var i = 0; i < at.length; i++) {
      if (at[i] >= 0) put(at[i], colors[i]);
    }
    if (at.last < grow) put(grow, colors.last);
    return RadialGradient(
      colors: inks,
      stops: points,
      tileMode: tileMode,
      transform: grow == 1 ? oval : _GrownOval(oval, grow),
    ).createShader(rect, textDirection: textDirection);
  }

  @override
  bool operator ==(Object other) {
    if (other is! LengthStopsRadialGradient || !(super == other) || other.lengths.length != lengths.length) {
      return false;
    }
    for (var i = 0; i < lengths.length; i++) {
      if (other.lengths[i] != lengths[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(super.hashCode, Object.hashAll(lengths));
}

/// A [GradientOval]'s ending shape grown [by] a factor about its centre.
class _GrownOval extends GradientTransform {
  const _GrownOval(this.oval, this.by);
  final GradientOval oval;
  final double by;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final m = oval.transform(bounds, textDirection: textDirection);
    if (m == null) return null;
    final c = bounds.center;
    return m
      ..multiply(Matrix4.translationValues(c.dx, c.dy, 0))
      ..multiply(Matrix4.diagonal3Values(by, by, 1))
      ..multiply(Matrix4.translationValues(-c.dx, -c.dy, 0));
  }
}

/// One `background-image` layer that does not cover the box: a BAND of it,
/// as wide or as tall as the tile `background-size` asked for, where
/// `background-position` puts it (css-backgrounds-3 3.7, 3.9).
///
/// A dotted rule under a heading is written this way -- a gradient four
/// pixels wide and one tall, repeated along the foot of the box -- and so
/// is the hairline down the side of a column. A `BoxDecoration` gradient
/// always fills the box it is on, so those had nowhere to go.
///
/// Only the axis the tile states a size on is a band; the other fills. The
/// gradient repeats along the band by its own [TileMode], which is what
/// the tiling amounts to when the tile is one period of it.
///
/// It is also the background of a box whose border you can see through,
/// which is the one place the border box and the padding box a background
/// is laid out in come apart: see [repeatX] and [clipInset].
class GradientBand extends Decoration {
  const GradientBand({
    required this.gradient,
    this.width,
    this.height,
    this.widthFactor,
    this.heightFactor,
    this.x = 0,
    this.y = 0,
    this.dx = 0,
    this.dy = 0,
    this.inset,
    this.borderRadius,
    this.corners,
    this.repeatX = false,
    this.repeatY = false,
    this.spaceX = false,
    this.spaceY = false,
    this.clipInset = false,
  });

  final Gradient gradient;

  /// The band in px; null on an axis it fills. With a factor on that axis,
  /// the length added to the share (`calc(100% - 64px)`).
  final double? width, height;

  /// The band as a SHARE of the box it is placed in, where the page states
  /// one (`background-size: 200% 100%`, css-backgrounds-3 3.9): read at the
  /// size the box is painted at. A tile larger than the box is cut to it.
  /// A monitoring site's and a restaurant site's buttons are a gradient twice their width, one
  /// half of it showing, slid across on hover.
  final double? widthFactor, heightFactor;

  /// Where the band sits on an axis it does not fill, as the share of the
  /// room left over that goes before it -- `background-position`'s own
  /// measure, where `0%` is against one edge and `100%` the other.
  final double x, y;

  /// A length the band is moved by on top of [x] and [y]
  /// (`background-position: 0 32px`); a repeated band moves every copy.
  final double dx, dy;

  /// What to take off the box before the band is placed in it: the
  /// border, which `background-origin` puts the background inside of.
  final EdgeInsets? inset;

  /// The box's own corners, which its background is cut to.
  final BorderRadius? borderRadius;

  /// The box's own corners as SHARES OF IT, where the page states them as
  /// percentages (css-backgrounds-3 5.1): in place of [borderRadius], read
  /// at the size the box is painted at, and cut inside [inset] the same
  /// way where [clipInset] says so, each radius less the border beside it
  /// (5.2): a `50% 100%` dome whose fill and radial wash are cut to the
  /// padding box inside a clear 4px border, which shows what is under it.
  final PercentCornerBorder? corners;

  /// Whether the tile is repeated across the whole box on that axis
  /// (`background-repeat`, css-backgrounds-3 3.4). A background is painted
  /// under the border by default and laid out inside it, so under a border
  /// you can see through the page shows the NEXT tile: the far edge of the
  /// gradient, where a shader would clamp its near colour.
  final bool repeatX, repeatY;

  /// Whether the tile is SPACED along that axis (`background-repeat: space`,
  /// css-backgrounds-3 3.4): as many whole copies as fit the box, the first
  /// against its near edge, the last against its far one and the rest
  /// spread evenly between -- the position ([x], [dx]) not read -- unless
  /// fewer than two fit, when the one tile is placed as a `no-repeat` one.
  /// How many fit is the box's to say where the tile is a share of it and
  /// a length (`calc(30% + 4px)`): counted when the box is painted, in
  /// Blink's 1/64 px (`GetSpaceBetweenImageTiles`: the tile truncated to a
  /// layout unit, the count the whole number of tiles in the box, the room
  /// left over shared between the gaps and truncated again).
  final bool spaceX, spaceY;

  /// Whether the background is cut to the box inside [inset] and its
  /// corners -- `background-clip: padding-box` -- and not to the border box.
  final bool clipInset;

  /// Where the copies of a tile at [start], [tile] long, begin along an
  /// axis the box runs from [near] to [far]: once at [start], again and
  /// again ([repeat]) over the whole box, or [space]d across it.
  static List<double> copies(
    double near,
    double far,
    double start,
    double tile, {
    required bool repeat,
    required bool space,
  }) {
    if (space) {
      // In layout units: 1/64 px, a length truncated into one.
      int unit(double v) => (v * 64 + 1e-6).truncate();
      final area = unit(far - near), step = unit(tile);
      final n = step > 0 ? area ~/ step : 0;
      if (n > 1) {
        final gap = (area - n * step) ~/ (n - 1);
        return [for (var k = 0; k < n; k++) near + k * (step + gap) / 64];
      }
      return [start];
    }
    if (!repeat || tile <= 0) return [start];
    int from(double at) => ((at - start) / tile).floor();
    return [for (var i = from(near); i <= from(far - 1e-6); i++) start + i * tile];
  }

  /// The corners [outer] has inside [inset]: each radius less the border
  /// beside it (css-backgrounds-3 5.2).
  static RRect innerOf(RRect outer, EdgeInsets inset) => RRect.fromLTRBAndCorners(
    outer.left + inset.left,
    outer.top + inset.top,
    outer.right - inset.right,
    outer.bottom - inset.bottom,
    topLeft: Radius.elliptical(math.max(0, outer.tlRadiusX - inset.left), math.max(0, outer.tlRadiusY - inset.top)),
    topRight: Radius.elliptical(math.max(0, outer.trRadiusX - inset.right), math.max(0, outer.trRadiusY - inset.top)),
    bottomRight: Radius.elliptical(
      math.max(0, outer.brRadiusX - inset.right),
      math.max(0, outer.brRadiusY - inset.bottom),
    ),
    bottomLeft: Radius.elliptical(
      math.max(0, outer.blRadiusX - inset.left),
      math.max(0, outer.blRadiusY - inset.bottom),
    ),
  );

  Rect bandOf(Rect outer) {
    final box = inset == null ? outer : inset!.deflateRect(outer);
    double side(double? share, double? px, double of) => share == null ? px ?? of : math.max(0, share * of + (px ?? 0));
    final w = side(widthFactor, width, box.width), h = side(heightFactor, height, box.height);
    return Rect.fromLTWH(box.left + (box.width - w) * x + dx, box.top + (box.height - h) * y + dy, w, h);
  }

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _BandPainter(this);

  @override
  bool get isComplex => borderRadius != null || corners != null || clipInset;

  @override
  Path getClipPath(Rect rect, TextDirection textDirection) => Path()
    ..addRRect(
      corners?.outer(rect) ?? borderRadius?.resolve(textDirection).toRRect(rect) ?? RRect.fromRectXY(rect, 0, 0),
    );

  @override
  bool operator ==(Object other) =>
      other is GradientBand &&
      other.gradient == gradient &&
      other.width == width &&
      other.height == height &&
      other.widthFactor == widthFactor &&
      other.heightFactor == heightFactor &&
      other.x == x &&
      other.y == y &&
      other.dx == dx &&
      other.dy == dy &&
      other.inset == inset &&
      other.borderRadius == borderRadius &&
      other.corners == corners &&
      other.repeatX == repeatX &&
      other.repeatY == repeatY &&
      other.spaceX == spaceX &&
      other.spaceY == spaceY &&
      other.clipInset == clipInset;

  @override
  int get hashCode => Object.hash(
    gradient,
    width,
    height,
    widthFactor,
    heightFactor,
    x,
    y,
    dx,
    dy,
    inset,
    borderRadius,
    corners,
    repeatX,
    repeatY,
    spaceX,
    spaceY,
    clipInset,
  );
}

class _BandPainter extends BoxPainter {
  _BandPainter(this.band);

  final GradientBand band;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;
    final box = offset & size;
    final rect = band.bandOf(box);
    if (rect.isEmpty) return;
    final direction = configuration.textDirection;
    final radius = band.borderRadius;
    final tiled = band.repeatX || band.repeatY || band.spaceX || band.spaceY;
    if (radius == null && band.corners == null && !tiled && !band.clipInset) {
      // Laid out over the tile, painted only where the box is.
      final shown = rect.intersect(box);
      if (shown.isEmpty) return;
      canvas.drawRect(shown, Paint()..shader = band.gradient.createShader(rect, textDirection: direction));
      return;
    }
    // The band is cut to the box's corners like any other background --
    // or to the corners inside the border, where the page clips it there.
    canvas.save();
    var clip = band.corners?.outer(box) ?? (radius ?? BorderRadius.zero).resolve(direction).toRRect(box);
    if (band.clipInset && band.inset != null) clip = GradientBand.innerOf(clip, band.inset!);
    canvas.clipRRect(clip);
    // Each tile is the gradient laid out again in a rect of its own: a
    // repeated one over the whole box it paints, a spaced one spread over
    // the box it is placed in.
    final area = band.inset == null ? box : band.inset!.deflateRect(box);
    final xs = band.spaceX
        ? GradientBand.copies(area.left, area.right, rect.left, rect.width, repeat: false, space: true)
        : GradientBand.copies(box.left, box.right, rect.left, rect.width, repeat: band.repeatX, space: false);
    final ys = band.spaceY
        ? GradientBand.copies(area.top, area.bottom, rect.top, rect.height, repeat: false, space: true)
        : GradientBand.copies(box.top, box.bottom, rect.top, rect.height, repeat: band.repeatY, space: false);
    for (final x in xs) {
      for (final y in ys) {
        final tile = Rect.fromLTWH(x, y, rect.width, rect.height);
        canvas.drawRect(tile, Paint()..shader = band.gradient.createShader(tile, textDirection: direction));
      }
    }
    canvas.restore();
  }
}

/// Turns a [RadialGradient] into the ENDING SHAPE a CSS `radial-gradient`
/// states: an ellipse or a circle, centred where `at` puts it, sized by an
/// extent keyword or by radii of its own (css-images-3 3.2).
///
/// Flutter's radial gradient is a circle whose radius is a share of the
/// box's shorter side, and CSS's is neither a circle nor measured off that
/// side. So the gradient is written as the unit circle Flutter draws by
/// default -- `center: Alignment.center, radius: 0.5` -- and this maps it
/// onto the shape the box says, at paint time, when the box has a size.
///
/// Leave [RadialGradient.center] at `Alignment.center` and
/// [RadialGradient.radius] at `0.5`.
class GradientOval extends GradientTransform {
  const GradientOval({
    this.x = 0,
    this.xShare = 0.5,
    this.y = 0,
    this.yShare = 0.5,
    this.extent = OvalExtent.farthestCorner,
    this.circle = false,
    this.rx,
    this.rxShare,
    this.ry,
    this.ryShare,
    this.inset,
    this.period,
  });

  /// The centre, from the box's top-left: px plus a share of the box.
  final double x, xShare, y, yShare;

  /// Which of the box's sides or corners the ending shape reaches.
  final OvalExtent extent;

  /// A circle has one radius, measured the same way on both axes; an
  /// ellipse's two are measured off the box's width and its height.
  final bool circle;

  /// The ending shape stated outright, in px plus a share of the box.
  /// Both halves of an axis are null where [extent] decides it.
  final double? rx, rxShare, ry, ryShare;

  /// What to take off the box before the gradient is laid out in it: the
  /// border, which `background-origin` puts the background inside of.
  final EdgeInsets? inset;

  /// A REPEATING gradient's period, in px along the ray: the ending shape
  /// scaled until its horizontal radius is one period, its shape kept, so
  /// that a shader tiling the unit circle (`TileMode.repeated`) rings out
  /// from the centre a period apart -- and the rings of an ellipse closer
  /// together down than across, as the shape is (css-images-3 3.4).
  final double? period;

  /// The gradient RAY in [bounds]: the ending shape's radius along the
  /// horizontal (css-images-3 3.2.1), which a stop's px are measured
  /// along. Null where the shape comes to nothing.
  double? ray(Rect bounds) => _shape(bounds)?.ax;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final shape = _shape(bounds);
    if (shape == null) return null;
    var (:cx, :cy, :ax, :ay) = shape;
    if (period case final p?) {
      ay *= p / ax;
      ax = p;
    }
    final outer = bounds;
    // What the shader draws before this: a circle at the middle of the
    // box the decoration paints, half its shorter side across.
    final r0 = outer.shortestSide / 2;
    return Matrix4.translationValues(cx, cy, 0)
      ..multiply(Matrix4.diagonal3Values(ax / r0, ay / r0, 1))
      ..multiply(Matrix4.translationValues(-outer.center.dx, -outer.center.dy, 0));
  }

  /// The ending shape in [bounds]: its centre and its two radii.
  ({double cx, double cy, double ax, double ay})? _shape(Rect bounds) {
    final outer = bounds;
    final box = inset == null ? bounds : inset!.deflateRect(bounds);
    if (box.width <= 0 || box.height <= 0 || outer.shortestSide <= 0) return null;
    final cx = box.left + x + xShare * box.width;
    final cy = box.top + y + yShare * box.height;
    // How far the centre is from each edge: every extent keyword is one of
    // these four, or the corner two of them meet at.
    final l = (cx - box.left).abs(), r = (box.right - cx).abs();
    final t = (cy - box.top).abs(), b = (box.bottom - cy).abs();
    double ax, ay;
    if (rx != null || rxShare != null || ry != null || ryShare != null) {
      ax = (rx ?? 0) + (rxShare ?? 0) * box.width;
      ay = circle ? ax : (ry ?? 0) + (ryShare ?? 0) * box.height;
    } else if (circle) {
      final near = extent == OvalExtent.closestSide || extent == OvalExtent.closestCorner;
      if (extent == OvalExtent.closestSide || extent == OvalExtent.farthestSide) {
        ax = ay = near ? math.min(math.min(l, r), math.min(t, b)) : math.max(math.max(l, r), math.max(t, b));
      } else {
        // The corner itself: a circle through it is as far away as it is.
        final dx = near ? math.min(l, r) : math.max(l, r);
        final dy = near ? math.min(t, b) : math.max(t, b);
        ax = ay = math.sqrt(dx * dx + dy * dy);
      }
    } else {
      final near = extent == OvalExtent.closestSide || extent == OvalExtent.closestCorner;
      ax = near ? math.min(l, r) : math.max(l, r);
      ay = near ? math.min(t, b) : math.max(t, b);
      if (extent == OvalExtent.closestCorner || extent == OvalExtent.farthestCorner) {
        // An ellipse through a corner has the SIDE ellipse's SHAPE, grown
        // until it meets the corner (css-images-3 3.2.1). That corner sits
        // at exactly the side ellipse's two radii, so the growth is the
        // same root two whichever corner it is.
        ax *= math.sqrt2;
        ay *= math.sqrt2;
      }
    }
    if (ax <= 0 || ay <= 0) return null;
    return (cx: cx, cy: cy, ax: ax, ay: ay);
  }

  @override
  bool operator ==(Object other) =>
      other is GradientOval &&
      other.x == x &&
      other.xShare == xShare &&
      other.y == y &&
      other.yShare == yShare &&
      other.extent == extent &&
      other.circle == circle &&
      other.rx == rx &&
      other.rxShare == rxShare &&
      other.ry == ry &&
      other.ryShare == ryShare &&
      other.inset == inset &&
      other.period == period;

  @override
  int get hashCode => Object.hash(x, xShare, y, yShare, extent, circle, rx, rxShare, ry, ryShare, inset, period);
}

/// Which of the box's sides or corners a [GradientOval]'s ending shape
/// reaches: `radial-gradient`'s own four keywords.
enum OvalExtent { closestSide, closestCorner, farthestSide, farthestCorner }
