import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'dry.dart';
import 'spill.dart';
import 'spot.dart';

/// [ChildLayoutHelper.dryLayoutChild], asked through [guardedSize].
Size _dryLayout(RenderBox child, BoxConstraints constraints) =>
    guardedSize(child, () => child.getDryLayout(constraints));

/// A box whose child is given a fraction of the width the box is offered.
///
/// This is [FractionallySizedBox] with one difference, and the difference is
/// the whole reason it exists: when the box is measured at an unbounded
/// width -- which every intrinsic and dry-layout pass does -- Flutter's
/// widget hands the child a TIGHT width of `infinity * factor`, and a child
/// that is infinitely wide poisons the line-breaking cache of any paragraph
/// it sits inside. CSS has an answer for this case: a percentage width
/// against a containing block with no definite width resolves as `auto`
/// (CSS 2.1 10.2), so the box sizes to its content. That is what this does.
///
/// Bounded, it is [FractionallySizedBox] exactly: the box fills the width it
/// is offered, the child takes `factor` of it, and [alignment] places the
/// child in the leftover -- which is how `margin-left: auto` is drawn.
class FractionalWidth extends SingleChildRenderObjectWidget {
  const FractionalWidth({
    super.key,
    required this.factor,
    this.offset = 0,
    this.min,
    this.max,
    this.minFactor,
    this.minOffset = 0,
    this.minCap,
    this.maxFactor,
    this.maxOffset = 0,
    this.alignment = AlignmentDirectional.topStart,
    this.fill = true,
    super.child,
  });

  /// The share of the offered width the child is given, `1` for `width: 100%`.
  final double factor;

  /// A fixed amount added to the share: a `content-box` percentage states
  /// the CONTENT width, and the padding and border go on top of it, so
  /// `width: 100%; padding: 0 10px` is the offered width plus 20.
  final double offset;

  /// The least and the most that share may come to: a `min-width` and a
  /// `max-width` clamp the width once it is taken, and the minimum wins
  /// where they cross (CSS 2.1 10.4). A clamp AROUND the box clamps the
  /// room instead, and 60% of a room capped at 420 is 252, not 420.
  final double? min, max;

  /// The same clamp where the page states it as a SHARE of the same room
  /// the width is a share of: `width: 100%; max-width: calc(50% + 216px)`
  /// is `factor: 1` with `maxFactor: 0.5, maxOffset: 216`. Which of the
  /// two binds depends on the room -- half of it plus 216 is less than all
  /// of it only past 432 -- so neither can be written as a number here,
  /// and the comparison waits for layout. Offered no width at all there is
  /// no share to compare: a percentage maximum is `none` and a percentage
  /// minimum is zero (CSS 2.1 10.4).
  final double? minFactor, maxFactor;
  final double minOffset, maxOffset;

  /// A CEILING ON THE SHARE FLOOR: `min-width: min(50%, 300px)` is the
  /// smaller of two affine functions of the same room -- half of it up to
  /// 600 and 300 past that -- and which of the two binds is not known until
  /// the room is (css-values-4 10.9). It is `minFactor: 0.5, minCap: 300`.
  /// Null leaves the floor on its own; with no room there is no share
  /// floor to cap.
  final double? minCap;

  /// Where the child sits when it is narrower than the box.
  final AlignmentGeometry alignment;

  /// Whether the box itself is as wide as the room it was offered.
  ///
  /// A BLOCK is: `width: 50%` takes half the containing block and the rest
  /// goes to its margins, which is what [alignment] then places it with. An
  /// ATOMIC INLINE is not -- it stands on a line as one thing, exactly as
  /// wide as its own width, and the rest of the line goes to whatever
  /// follows it. Filled, two `width: 45%` inline-blocks each reported the
  /// whole line as their width and Skia broke the line between them: a
  /// 260px row of a 117px pair came out 69 tall where the page draws 44.
  final bool fill;

  @override
  RenderFractionalWidth createRenderObject(BuildContext context) => RenderFractionalWidth(
    factor: factor,
    offset: offset,
    min: min,
    max: max,
    minFactor: minFactor,
    minOffset: minOffset,
    minCap: minCap,
    maxFactor: maxFactor,
    maxOffset: maxOffset,
    fill: fill,
    alignment: alignment,
    textDirection: Directionality.maybeOf(context),
  );

  @override
  void updateRenderObject(BuildContext context, RenderFractionalWidth renderObject) {
    renderObject
      ..factor = factor
      ..offset = offset
      ..min = min
      ..max = max
      ..minFactor = minFactor
      ..minOffset = minOffset
      ..minCap = minCap
      ..maxFactor = maxFactor
      ..maxOffset = maxOffset
      ..fill = fill
      ..alignment = alignment
      ..textDirection = Directionality.maybeOf(context);
  }
}

/// The render object for [FractionalWidth].
class RenderFractionalWidth extends RenderAligningShiftedBox
    with DryLastBaseline, AsksGuarded, PassesBaseline, KeptUnderHatch {
  RenderFractionalWidth({
    super.child,
    required double factor,
    double offset = 0,
    double? min,
    double? max,
    double? minFactor,
    double minOffset = 0,
    double? minCap,
    double? maxFactor,
    double maxOffset = 0,
    bool fill = true,
    super.alignment,
    required super.textDirection,
  }) : _factor = factor,
       _offset = offset,
       _min = min,
       _max = max,
       _minFactor = minFactor,
       _minOffset = minOffset,
       _minCap = minCap,
       _maxFactor = maxFactor,
       _maxOffset = maxOffset,
       _fill = fill;

  double get factor => _factor;
  double _factor;
  set factor(double value) {
    if (_factor == value) return;
    _factor = value;
    markNeedsLayout();
  }

  double get offset => _offset;
  double _offset;
  set offset(double value) {
    if (_offset == value) return;
    _offset = value;
    markNeedsLayout();
  }

  double? get min => _min;
  double? _min;
  set min(double? value) {
    if (_min == value) return;
    _min = value;
    markNeedsLayout();
  }

  double? get max => _max;
  double? _max;
  set max(double? value) {
    if (_max == value) return;
    _max = value;
    markNeedsLayout();
  }

  /// See [FractionalWidth.minFactor].
  double? _minFactor, _maxFactor;
  double _minOffset = 0, _maxOffset = 0;

  set minFactor(double? value) {
    if (_minFactor == value) return;
    _minFactor = value;
    markNeedsLayout();
  }

  set maxFactor(double? value) {
    if (_maxFactor == value) return;
    _maxFactor = value;
    markNeedsLayout();
  }

  set minOffset(double value) {
    if (_minOffset == value) return;
    _minOffset = value;
    markNeedsLayout();
  }

  set maxOffset(double value) {
    if (_maxOffset == value) return;
    _maxOffset = value;
    markNeedsLayout();
  }

  /// See [FractionalWidth.minCap].
  double? _minCap;
  set minCap(double? value) {
    if (_minCap == value) return;
    _minCap = value;
    markNeedsLayout();
  }

  /// See [FractionalWidth.fill].
  bool get fill => _fill;
  bool _fill;
  set fill(bool value) {
    if (_fill == value) return;
    _fill = value;
    markNeedsLayout();
  }

  /// [width] clamped, where [room] is the width the box was offered -- the
  /// one a share of a clamp is a share OF, and null where there is none.
  double _clamp(double width, [double? room]) {
    var w = width;
    var hi = _max, lo = _min;
    if (room != null && _maxFactor != null) {
      final v = room * _maxFactor! + _maxOffset;
      hi = hi == null ? v : math.min(hi, v);
    }
    if (room != null && _minFactor != null) {
      var v = room * _minFactor! + _minOffset;
      if (_minCap != null && _minCap! < v) v = _minCap!;
      lo = lo == null ? v : math.max(lo, v);
    }
    if (hi != null && w > hi) w = hi;
    if (lo != null && w < lo) w = lo;
    return w;
  }

  /// The child's width out of [width] offered: the share, the fixed
  /// amount on top of it, and the clamp on the sum.
  ///
  /// A WIDTH IS NEVER LESS THAN NOTHING. `calc(50% - 20.5px)` of a room
  /// narrower than 41px resolves below zero, and a width that does is
  /// clamped to zero before the floor and the cap are applied (css-values-4
  /// 10.12, css-sizing-3 5.2), as [FractionalHeight]'s share is.
  /// A science magazine's archive sidebar is such a column in a float, and the
  /// flow asked its depth at a width of -20.5 -- an assertion on every
  /// layout of the page.
  double _share(double width) => _clamp(math.max(0.0, (_factor == 0 ? 0.0 : width * _factor) + _offset), width);

  BoxConstraints _inner(BoxConstraints constraints) {
    if (!constraints.maxWidth.isFinite) {
      // Shrink-to-fit (CSS 2.1 10.3.5): with no width to take a share OF,
      // the box is as wide as its content wants to be. The child is ASKED
      // for that width rather than handed the infinity, because a
      // stretching column answers an unbounded width with an unbounded
      // SIZE -- and an unbounded child inside a paragraph poisons its
      // line breaking for good.
      final wanted = _clamp(guardedSize(child, () => child?.getMaxIntrinsicWidth(double.infinity) ?? 0.0));
      return BoxConstraints(
        minWidth: wanted.isFinite ? wanted : 0.0,
        maxWidth: wanted.isFinite ? wanted : double.infinity,
        minHeight: constraints.minHeight,
        maxHeight: constraints.maxHeight,
      );
    }
    final width = _share(constraints.maxWidth);
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      minHeight: constraints.minHeight,
      maxHeight: constraints.maxHeight,
    );
  }

  Size _size(BoxConstraints constraints, ChildLayouter layoutChild) {
    final child = this.child;
    if (child == null) return constraints.constrain(Size.zero);
    final inner = layoutChild(child, _inner(constraints));
    // The box itself fills what it was offered so the alignment has room to
    // work; with nothing to fill -- or standing on a line, where the room
    // past its own width belongs to what comes next -- it is as wide as
    // what it holds.
    final width = _fill && constraints.maxWidth.isFinite ? constraints.maxWidth : inner.width;
    return constraints.constrain(Size(width, inner.height));
  }

  // NOT what [FractionallySizedBox] answers, which is the width that would
  // give the child all it wants: the child's width divided by its share.
  // A container sized by its content treats a percentage width as `auto`
  // while it asks (css-sizing-3 5.2.1, css-grid-1 11.5) -- a max-content
  // track over a `width: 70%` item is as wide as the item's text, and the
  // item is then 70% of that and breaks its line.
  @override
  double computeMinIntrinsicWidth(double height) =>
      _clamp(guardedSize(child, () => child?.getMinIntrinsicWidth(height) ?? 0.0));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _clamp(guardedSize(child, () => child?.getMaxIntrinsicWidth(height) ?? 0.0));

  @override
  double computeMinIntrinsicHeight(double width) =>
      guardedSize(child, () => child?.getMinIntrinsicHeight(_share(width)) ?? 0.0);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      guardedSize(child, () => child?.getMaxIntrinsicHeight(_share(width)) ?? 0.0);

  @override
  @protected
  Size computeDryLayout(covariant BoxConstraints constraints) => _size(constraints, _dryLayout);

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) =>
      _dry(constraints, baseline, dryBaselineOf);

  @override
  double? dryLastBaseline(BoxConstraints constraints, TextBaseline baseline) =>
      _dry(constraints, baseline, dryLastBaselineOf);

  double? _dry(
    BoxConstraints constraints,
    TextBaseline baseline,
    double? Function(RenderBox, BoxConstraints, TextBaseline) of,
  ) {
    final child = this.child;
    if (child == null) return null;
    final inner = _inner(constraints);
    final result = of(child, inner, baseline);
    if (result == null) return null;
    final childSize = _dryLayout(child, inner);
    final size = _size(constraints, _dryLayout);
    return result + resolvedAlignment.alongOffset(size - childSize as Offset).dy;
  }

  @override
  void performLayout() {
    size = _size(constraints, ChildLayoutHelper.layoutChild);
    if (child != null) alignChild();
  }
}

/// A floor and a cap on the width, each a share of the width the box is
/// offered plus a fixed amount: `max-width: 80%` is `maxFactor: 0.8`, and
/// `max-width: calc(100% - 32px)` is `maxFactor: 1, maxOffset: -32`.
///
/// [ConstrainedBox] takes numbers, and a percentage `min-width` or
/// `max-width` is not a number until the room is known -- which it is only
/// here, at layout. Offered no width at all, a percentage has nothing to be
/// a share OF and the clamp does nothing (CSS 2.1 10.4: it is `none` for a
/// maximum and zero for a minimum).
class FractionalConstraints extends SingleChildRenderObjectWidget {
  const FractionalConstraints({
    super.key,
    this.minFactor,
    this.minOffset = 0,
    this.maxFactor,
    this.maxOffset = 0,
    this.otherMaxFactor,
    this.otherMaxOffset = 0,
    this.otherMaxLarger = false,
    this.compressible = false,
    this.textDirection = TextDirection.ltr,
    super.child,
  });

  final double? minFactor, maxFactor;
  final double minOffset, maxOffset;

  /// A SECOND CAP of the same room, where the page caps the box at the
  /// smaller of two shares that each add a length: `max-width: min(50% +
  /// 40px, 70% + 10px)` is `maxFactor: 0.5, maxOffset: 40` and
  /// `otherMaxFactor: 0.7, otherMaxOffset: 10`. Which of the two binds is
  /// the room's to say -- the second under 150, the first past it
  /// (css-values-4 10.9) -- and a cap nested inside another would take its
  /// share of what the outer one leaves, not of the room. Both are of the
  /// width THIS box is offered; the floor still wins over either (CSS 2.1
  /// 10.4). Nothing without [otherMaxFactor].
  final double? otherMaxFactor;
  final double otherMaxOffset;

  /// Whether the box is held to the LARGER of the two caps rather than the
  /// smaller: `max-width: max(50%, 200px)` is `maxFactor: 0.5` and
  /// `otherMaxFactor: 0, otherMaxOffset: 200` -- 200 in a room under 400,
  /// half of it past (css-values-4 10.9). Nothing without
  /// [otherMaxFactor].
  final bool otherMaxLarger;

  /// The direction of the line or the block the box is laid out in, which
  /// says which side a floor past the room takes it over. A box wider than
  /// its room keeps its START edge on the room's and hangs off the END --
  /// the right under `ltr`, the LEFT under `rtl` -- on a line (css-text-3
  /// 7.1: an overflowing line is start-aligned) as in a block (CSS 2.1
  /// 10.3.3: in an over-constrained box the end margin is the one that
  /// gives). `min-width: 340px` at `width: stretch` in a 300px `rtl` block
  /// shows its first 40px past the block's left.
  final TextDirection textDirection;

  /// Whether the box can be squeezed to nothing, so the least room it asks
  /// for is zero (css-sizing-3 5.2.2): a PICTURE capped by a percentage is,
  /// and a 1280px image at `max-width: 100%` does not push the grid column
  /// it sits in open to 1280. A box of text still asks for its longest word.
  final bool compressible;

  @override
  RenderFractionalConstraints createRenderObject(BuildContext context) => RenderFractionalConstraints()
    ..minFactor = minFactor
    ..minOffset = minOffset
    ..maxFactor = maxFactor
    ..maxOffset = maxOffset
    ..otherMaxFactor = otherMaxFactor
    ..otherMaxOffset = otherMaxOffset
    ..otherMaxLarger = otherMaxLarger
    ..compressible = compressible
    ..textDirection = textDirection;

  @override
  void updateRenderObject(BuildContext context, RenderFractionalConstraints renderObject) {
    renderObject
      ..minFactor = minFactor
      ..minOffset = minOffset
      ..maxFactor = maxFactor
      ..maxOffset = maxOffset
      ..otherMaxFactor = otherMaxFactor
      ..otherMaxOffset = otherMaxOffset
      ..otherMaxLarger = otherMaxLarger
      ..compressible = compressible
      ..textDirection = textDirection;
  }
}

/// The render object for [FractionalConstraints].
class RenderFractionalConstraints extends RenderProxyBox with AsksGuarded, KeptUnderHatch {
  double? _minFactor, _maxFactor;
  double _minOffset = 0, _maxOffset = 0;

  set minFactor(double? v) {
    if (_minFactor == v) return;
    _minFactor = v;
    markNeedsLayout();
  }

  set maxFactor(double? v) {
    if (_maxFactor == v) return;
    _maxFactor = v;
    markNeedsLayout();
  }

  set minOffset(double v) {
    if (_minOffset == v) return;
    _minOffset = v;
    markNeedsLayout();
  }

  set maxOffset(double v) {
    if (_maxOffset == v) return;
    _maxOffset = v;
    markNeedsLayout();
  }

  /// See [FractionalConstraints.otherMaxFactor].
  double? _otherMaxFactor;
  double _otherMaxOffset = 0;
  set otherMaxFactor(double? v) {
    if (_otherMaxFactor == v) return;
    _otherMaxFactor = v;
    markNeedsLayout();
  }

  set otherMaxOffset(double v) {
    if (_otherMaxOffset == v) return;
    _otherMaxOffset = v;
    markNeedsLayout();
  }

  bool _otherMaxLarger = false;
  set otherMaxLarger(bool v) {
    if (_otherMaxLarger == v) return;
    _otherMaxLarger = v;
    markNeedsLayout();
  }

  bool _compressible = false;
  set compressible(bool v) {
    if (_compressible == v) return;
    _compressible = v;
    markNeedsLayout();
  }

  TextDirection _textDirection = TextDirection.ltr;
  set textDirection(TextDirection v) {
    if (_textDirection == v) return;
    _textDirection = v;
    markNeedsPaint();
  }

  /// Where the child stands in a box narrower than it: its start edge on
  /// the box's, so under `rtl` it is moved left by what it hangs over
  /// ([FractionalConstraints.textDirection]).
  Offset get _shift {
    final c = child;
    if (c == null || _textDirection == TextDirection.ltr) return Offset.zero;
    final over = c.size.width - size.width;
    return over > 0 ? Offset(-over, 0) : Offset.zero;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = child;
    if (c != null) context.paintChild(c, offset + _shift);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final c = child;
    if (c == null) return false;
    return result.addWithPaintOffset(
      offset: _shift,
      position: position,
      hitTest: (r, p) => c.hitTest(r, position: p),
    );
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    final s = _shift;
    if (s != Offset.zero) transform.translateByDouble(s.dx, s.dy, 0, 1);
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _compressible ? 0.0 : guardedSize(child, () => super.computeMinIntrinsicWidth(height));

  BoxConstraints _inner(BoxConstraints c) {
    if (!c.hasBoundedWidth) return c;
    final room = c.maxWidth;
    var lo = c.minWidth, hi = c.maxWidth;
    if (_maxFactor != null && _otherMaxFactor != null && _otherMaxLarger) {
      final cap = math.max(room * _maxFactor! + _maxOffset, room * _otherMaxFactor! + _otherMaxOffset);
      hi = math.max(0.0, math.min(hi, cap));
    } else {
      if (_maxFactor != null) hi = math.max(0.0, math.min(hi, room * _maxFactor! + _maxOffset));
      if (_otherMaxFactor != null) hi = math.max(0.0, math.min(hi, room * _otherMaxFactor! + _otherMaxOffset));
    }
    if (_minFactor != null) lo = math.max(lo, room * _minFactor! + _minOffset);
    // CSS 2.1 10.4: where the two disagree the minimum wins -- even past
    // the room, which the child then overflows.
    if (lo > hi) hi = lo;
    if (lo > hi) lo = hi;
    return BoxConstraints(minWidth: math.min(lo, hi), maxWidth: hi, minHeight: c.minHeight, maxHeight: c.maxHeight);
  }

  /// THE WIDTH THE CHILD IS ASKED A HEIGHT AT is the width it is laid out
  /// at in the room [width] offers: [performLayout] hands it that room loose
  /// ([_inner]), and a child narrower than the room -- a picture of a stated
  /// width, `width: 127px; max-width: 100%` (CSS 2.1 10.4) -- stays its own
  /// width in it. Asked at the whole room, a `SizedBox(width: 127)` round an
  /// `AspectRatio` hands the room on past its own width
  /// (`RenderConstrainedBox` passes the width it is asked at through), and
  /// the ratio answered the room's height: three logos in groups 192 and
  /// 103 wide under an `IntrinsicHeight` came out 36px taller than they are,
  /// and the page under them stood 36px low. A child that fills the room it
  /// is handed -- an `AspectRatio` of no width, whatever its picture's own
  /// width -- is the room wide and is asked there, as before; and where the
  /// child answers no width or none it can say (a picture not yet sized),
  /// the room is asked as before.
  double _heightAskedAt(double width) {
    final inner = _inner(BoxConstraints(maxWidth: width));
    final room = inner.constrainWidth(width);
    final child = this.child;
    if (child == null || !room.isFinite) return room;
    final laid = _dryLayout(child, inner).width;
    return laid.isFinite && laid > 0 && laid < room ? laid : room;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      guardedSize(child, () => child?.getMinIntrinsicHeight(_heightAskedAt(width)) ?? 0.0);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      guardedSize(child, () => child?.getMaxIntrinsicHeight(_heightAskedAt(width)) ?? 0.0);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return constraints.constrain(_dryLayout(child, _inner(constraints)));
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) =>
      child == null ? null : dryBaselineOf(child!, _inner(constraints), baseline);

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_inner(constraints), parentUsesSize: true);
    size = constraints.constrain(child.size);
  }
}

/// A box as tall as a share of the height it is OFFERED: `height: 50%`.
///
/// The transpose of [FractionalWidth], and it exists for the same reason
/// its sibling does -- offered no height to take a share of, the
/// percentage is `auto` (CSS 2.1 10.5) and the box is as tall as its
/// content, where [FractionallySizedBox] would hand the child a tight
/// `infinity * factor`.
///
/// A percentage height is offered a height far less often than a width is:
/// a block flow is as tall as what is in it, and `RenderFlex` hands its
/// children an unbounded main axis whatever it was given itself. Where
/// the height IS offered -- an item stretched across a flex line, an item
/// whose main size the line settled, a box whose `aspect-ratio` fixed its
/// height (css-flexbox-1 9.8, css-sizing-4 5.1) -- the share is what CSS
/// says the box is, and dropping it left taffy's
/// `blockflex_percentage_height_in_stretched_flex_item` a 50px box at 0.
///
/// Unlike [FractionalWidth] the box does NOT fill what it was offered: a
/// short box in a tall block is short, and only its containing block is
/// tall. Where the offer is tight it fills it all the same, because a box
/// may not report a size its constraints forbid.
///
/// A LENGTH FLOOR OR CAP holds the share itself (CSS 2.1 10.7): the box is
/// the share, no taller than [max] and no shorter than [min], the floor
/// winning where the two cross. Stated round the box instead, a floor is
/// one the tight share inside it never sees -- a Russian news site's scrollbar thumb is
/// `height: 49.01%; min-height: 33px`, and in a short track the box
/// reported 33 while what it painted stayed the share.
class FractionalHeight extends SingleChildRenderObjectWidget {
  const FractionalHeight({
    super.key,
    required this.factor,
    this.offset = 0,
    this.min = 0,
    this.max = double.infinity,
    this.maxFactor,
    this.maxOffset = 0,
    this.minFactor,
    this.minOffset = 0,
    this.ofRoom = false,
    super.child,
  });

  /// The share of the offered height the box is given, `1` for `height: 100%`.
  final double factor;

  /// A fixed amount added to the share: a `content-box` percentage states
  /// the CONTENT height, and the padding and border go on top of it.
  final double offset;

  /// The least height the box is, share or no share: `min-height`.
  final double min;

  /// The most height the box is, below [min]: `max-height`.
  final double max;

  /// A CAP THAT IS A SHARE of the same offered height, and [maxOffset]
  /// beside it: `max-height: calc(50% + 20px)` is `maxFactor: 0.5,
  /// maxOffset: 20`. A percentage `max-height` is of the containing
  /// block's height as the `height` is (CSS 2.1 10.7), so the two are
  /// affine in the same room and which one binds turns on the room:
  /// `height: 100%; max-height: calc(50% + 20px)` is the room up to 40px
  /// and the cap past it. Taken with [max] (the smaller binds) and under
  /// [min] (the floor wins). Offered no height, the share is `none`, as
  /// a percentage against an indefinite height is.
  final double? maxFactor;

  /// The length beside [maxFactor]'s share.
  final double maxOffset;

  /// A FLOOR THAT IS A SHARE of the same offered height, and [minOffset]
  /// beside it: `min-height: calc(40% + 10px)` is `minFactor: 0.4,
  /// minOffset: 10`, of the containing block's height as the `height` is
  /// (CSS 2.1 10.7). Beside `height: 49.01%` it binds under 102px of room
  /// and not past it, so which one the box is waits for the room -- the Russian news site's
  /// thumb at that floor (`fixtures/abs-share-height-floor` p7). Taken with
  /// [min] (the larger binds) and over any cap (the floor wins). Offered no
  /// height, the share is nothing, as a percentage floor against an
  /// indefinite height is.
  final double? minFactor;

  /// The length beside [minFactor]'s share.
  final double minOffset;

  /// Whether, OFFERED NO HEIGHT, the share is of the height the nearest
  /// [Spill.room] above was offered: the content height of the block whose
  /// flow this box is in, beside other boxes in a `Column` that hands it
  /// none. Offered a height, the share is of that, as it is without this;
  /// with no room above, or one offered no height, it is `auto`.
  final bool ofRoom;

  @override
  RenderFractionalHeight createRenderObject(BuildContext context) => RenderFractionalHeight(
    factor: factor,
    offset: offset,
    min: min,
    max: max,
    maxFactor: maxFactor,
    maxOffset: maxOffset,
    minFactor: minFactor,
    minOffset: minOffset,
    ofRoom: ofRoom,
  );

  @override
  void updateRenderObject(BuildContext context, RenderFractionalHeight renderObject) {
    renderObject
      ..factor = factor
      ..offset = offset
      ..min = min
      ..max = max
      ..maxFactor = maxFactor
      ..maxOffset = maxOffset
      ..minFactor = minFactor
      ..minOffset = minOffset
      ..ofRoom = ofRoom;
  }
}

/// The render object for [FractionalHeight].
///
/// What it lays out is the box the page draws, and may be taller than the
/// room it reports: a floor past the room, a length past the share, a share
/// past the whole ([Overhangs]).
class RenderFractionalHeight extends RenderProxyBox with AsksGuarded, KeptUnderHatch implements Overhangs {
  RenderFractionalHeight({
    RenderBox? child,
    required double factor,
    double offset = 0,
    double min = 0,
    double max = double.infinity,
    double? maxFactor,
    double maxOffset = 0,
    double? minFactor,
    double minOffset = 0,
    bool ofRoom = false,
  }) : _factor = factor,
       _offset = offset,
       _min = min,
       _max = max,
       _maxFactor = maxFactor,
       _maxOffset = maxOffset,
       _minFactor = minFactor,
       _minOffset = minOffset,
       _ofRoom = ofRoom,
       super(child);

  double get factor => _factor;
  double _factor;
  set factor(double value) {
    if (_factor == value) return;
    _factor = value;
    markNeedsLayout();
  }

  double get offset => _offset;
  double _offset;
  set offset(double value) {
    if (_offset == value) return;
    _offset = value;
    markNeedsLayout();
  }

  double get min => _min;
  double _min;
  set min(double value) {
    if (_min == value) return;
    _min = value;
    markNeedsLayout();
  }

  double get max => _max;
  double _max;
  set max(double value) {
    if (_max == value) return;
    _max = value;
    markNeedsLayout();
  }

  /// See [FractionalHeight.maxFactor].
  double? get maxFactor => _maxFactor;
  double? _maxFactor;
  set maxFactor(double? value) {
    if (_maxFactor == value) return;
    _maxFactor = value;
    markNeedsLayout();
  }

  /// See [FractionalHeight.maxOffset].
  double get maxOffset => _maxOffset;
  double _maxOffset;
  set maxOffset(double value) {
    if (_maxOffset == value) return;
    _maxOffset = value;
    markNeedsLayout();
  }

  /// See [FractionalHeight.minFactor].
  double? get minFactor => _minFactor;
  double? _minFactor;
  set minFactor(double? value) {
    if (_minFactor == value) return;
    _minFactor = value;
    markNeedsLayout();
  }

  /// See [FractionalHeight.minOffset].
  double get minOffset => _minOffset;
  double _minOffset;
  set minOffset(double value) {
    if (_minOffset == value) return;
    _minOffset = value;
    markNeedsLayout();
  }

  /// See [FractionalHeight.ofRoom].
  bool get ofRoom => _ofRoom;
  bool _ofRoom;
  set ofRoom(bool value) {
    if (_ofRoom == value) return;
    _ofRoom = value;
    markNeedsLayout();
  }

  /// The [Spill.room] this box last read its height off.
  RenderSpill? _roomAbove;

  /// The height the share is of: the one this box is offered, or where it
  /// is offered none and the share is [ofRoom], the one the nearest room
  /// above was -- which lays this box out again when it changes.
  double _basis(BoxConstraints constraints) {
    final offered = constraints.maxHeight;
    if (offered.isFinite || !_ofRoom) return offered;
    touchesRoom();
    for (var p = parent; p != null; p = p.parent) {
      if (p is RenderSpill && p.room) {
        if (!identical(_roomAbove, p)) _roomAbove?.forget(this);
        _roomAbove = p;
        return p.roomFor(this) ?? offered;
      }
    }
    return offered;
  }

  @override
  void detach() {
    _roomAbove?.forget(this);
    _roomAbove = null;
    super.detach();
  }

  /// [height] under the cap and over the floor, the shares of the cap and
  /// the floor taken of [room] where there is one.
  double _held(double height, [double? room]) {
    var hi = _max, lo = _min;
    if (room != null && _maxFactor != null) hi = math.min(hi, math.max(0.0, room * _maxFactor! + _maxOffset));
    if (room != null && _minFactor != null) lo = math.max(lo, room * _minFactor! + _minOffset);
    return math.max(lo, math.min(hi, height));
  }

  double _share(double height) => _held(math.max(0.0, (_factor == 0 ? 0.0 : height * _factor) + _offset), height);

  BoxConstraints _inner(BoxConstraints constraints) {
    final room = _basis(constraints);
    // Offered no height the share is `auto`, and the floor and cap hold
    // the content's height instead.
    if (!room.isFinite) {
      if (_min == 0 && _max == double.infinity) return constraints;
      final lo = math.max(constraints.minHeight, _min);
      return BoxConstraints(
        minWidth: constraints.minWidth,
        maxWidth: constraints.maxWidth,
        minHeight: lo,
        maxHeight: math.max(lo, math.min(constraints.maxHeight, _max)),
      );
    }
    final height = _share(room);
    return BoxConstraints(
      minWidth: constraints.minWidth,
      maxWidth: constraints.maxWidth,
      minHeight: height,
      maxHeight: height,
    );
  }

  Size _size(BoxConstraints constraints, ChildLayouter layoutChild) {
    final child = this.child;
    if (child == null) {
      final room = _basis(constraints);
      return constraints.constrain(Size(0, room.isFinite ? _share(room) : _held(0)));
    }
    return constraints.constrain(layoutChild(child, _inner(constraints)));
  }

  // A box sized by its CONTENT treats a percentage height as `auto` while
  // it asks (css-sizing-3 5.2.1), so both answers are the child's own.
  @override
  double computeMinIntrinsicHeight(double width) =>
      _held(guardedSize(child, () => child?.getMinIntrinsicHeight(width) ?? 0.0));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _held(guardedSize(child, () => child?.getMaxIntrinsicHeight(width) ?? 0.0));

  @override
  @protected
  Size computeDryLayout(covariant BoxConstraints constraints) => _size(constraints, _dryLayout);

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) {
    final child = this.child;
    if (child == null) return null;
    return dryBaselineOf(child, _inner(constraints), baseline);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => child?.getDistanceToActualBaseline(baseline);

  @override
  void performLayout() {
    size = _size(constraints, ChildLayoutHelper.layoutChild);
    _laidOut = child?.size;
  }

  /// The child's size at the last layout, kept here: the box that reads it
  /// ([Overhangs]) is above this one, and may not read the child's own.
  Size? _laidOut;

  @override
  Size get laidOut => _laidOut ?? size;
}

/// A box as tall as its content and no shorter than a SHARE of the height
/// it is offered: `min-height: 100%` on a box of `auto` height (CSS 2.1
/// 10.7), [factor] the share and [offset] a length beside it --
/// `min-height: calc(50% + 10px)` is `factor: 0.5, offset: 10`.
///
/// The share is of the containing block's height, which is definite where
/// the block hands one on -- a grid row that stretched its item, a line
/// that settled it -- and is not a number until layout. Offered no height,
/// the share is nothing, as a percentage floor against an indefinite
/// height is. A recipe app's planner page is a stretched grid item holding
/// a grid at `min-height: 100%` whose `1fr` row holds the tab bar: with the
/// floor dropped the grid was as tall as its content, and the bar hung
/// halfway up the window.
///
/// Content taller than the room is laid out at its own height and hangs out
/// of the box, which reports no more than it was offered (`overflow:
/// visible`); what measures what it lays out reads
/// [RenderFractionalMinHeight.laidOut].
class FractionalMinHeight extends SingleChildRenderObjectWidget {
  const FractionalMinHeight({super.key, required this.factor, this.offset = 0, super.child});

  /// The share of the offered height the box is at least, `1` for
  /// `min-height: 100%`.
  final double factor;

  /// A length added to the share: a `content-box` floor states the
  /// CONTENT height, and the padding and border go on top of it.
  final double offset;

  @override
  RenderFractionalMinHeight createRenderObject(BuildContext context) =>
      RenderFractionalMinHeight(factor: factor, offset: offset);

  @override
  void updateRenderObject(BuildContext context, RenderFractionalMinHeight renderObject) {
    renderObject
      ..factor = factor
      ..offset = offset;
  }
}

/// The render object for [FractionalMinHeight].
class RenderFractionalMinHeight extends RenderProxyBox with AsksGuarded, KeptUnderHatch implements Overhangs {
  RenderFractionalMinHeight({RenderBox? child, required double factor, double offset = 0})
    : _factor = factor,
      _offset = offset,
      super(child);

  double get factor => _factor;
  double _factor;
  set factor(double value) {
    if (_factor == value) return;
    _factor = value;
    markNeedsLayout();
  }

  double get offset => _offset;
  double _offset;
  set offset(double value) {
    if (_offset == value) return;
    _offset = value;
    markNeedsLayout();
  }

  /// The floor taken of the room, with no ceiling: the content may be
  /// taller than the room. Offered no room, the constraints as they came.
  BoxConstraints _inner(BoxConstraints constraints) {
    if (!constraints.maxHeight.isFinite) return constraints;
    final floor = math.max(0.0, constraints.maxHeight * _factor + _offset);
    return BoxConstraints(
      minWidth: constraints.minWidth,
      maxWidth: constraints.maxWidth,
      minHeight: math.max(constraints.minHeight, floor),
      maxHeight: double.infinity,
    );
  }

  // A box sized by its CONTENT treats a percentage height as `auto` while
  // it asks (css-sizing-3 5.2.1), so both answers are the child's own.
  @override
  double computeMinIntrinsicHeight(double width) =>
      guardedSize(child, () => child?.getMinIntrinsicHeight(width) ?? 0.0);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      guardedSize(child, () => child?.getMaxIntrinsicHeight(width) ?? 0.0);

  @override
  @protected
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.constrain(Size.zero);
    return constraints.constrain(_dryLayout(child, _inner(constraints)));
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) {
    final child = this.child;
    if (child == null) return null;
    return dryBaselineOf(child, _inner(constraints), baseline);
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size.zero);
      _laidOut = null;
      return;
    }
    child.layout(_inner(constraints), parentUsesSize: true);
    size = constraints.constrain(child.size);
    _laidOut = child.size;
  }

  /// The child's size at the last layout (see [RenderFractionalHeight.laidOut]).
  Size? _laidOut;

  @override
  Size get laidOut => _laidOut ?? size;
}

/// A box that passes on the room it was given without the obligation to
/// fill it.
///
/// A flex line hands a stretched item a TIGHT cross size, and a box may
/// not report a size its constraints forbid -- so the tightness reaches
/// the item's content, and a block inside a 100px-tall item came out 100
/// tall where CSS makes it as tall as its own `height: 50%` says. A block
/// flow normally loosens that on the way past (a `Column` shrink-wraps its
/// main axis), and this is what loosens it where there is no column to do
/// it: the room stays the ceiling, and the floor goes to zero.
class LooseHeight extends SingleChildRenderObjectWidget {
  const LooseHeight({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => RenderLooseHeight();
}

/// The render object for [LooseHeight].
class RenderLooseHeight extends RenderProxyBox with AsksGuarded, KeptUnderHatch {
  static BoxConstraints _inner(BoxConstraints c) =>
      BoxConstraints(minWidth: c.minWidth, maxWidth: c.maxWidth, minHeight: 0, maxHeight: c.maxHeight);

  @override
  @protected
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    return child == null ? constraints.smallest : constraints.constrain(_dryLayout(child, _inner(constraints)));
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) =>
      child == null ? null : dryBaselineOf(child!, _inner(constraints), baseline);

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_inner(constraints), parentUsesSize: true);
    size = constraints.constrain(child.size);
  }
}
