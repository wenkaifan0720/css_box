/// A box as wide as its content wants, within the room it has.
library;

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'dry.dart';

/// Shrink-to-fit: `min(max(min-content, room), max-content)`.
///
/// This is the width a browser gives a box that was not handed one -- a
/// float, an inline-block, an item on a line that does not stretch (CSS
/// 2.1 10.3.5) -- and the one width Flutter has no widget for. The two it
/// has are the ends of the same range: a stretching [Column] takes ALL the
/// room, and [IntrinsicWidth] takes the content's width whatever the room
/// is, and answers that same number to every intrinsic question, so a
/// [Row] or a flex line above it cannot make the box give any of it back.
///
/// This one narrows when the room is tight and stops at its content's
/// width when the room is wide, and it passes both of its child's answers
/// up unchanged: its minimum is the child's min-content, which is what
/// lets a line shrink it, and its maximum the child's max-content.
class ShrinkWidth extends SingleChildRenderObjectWidget {
  const ShrinkWidth({
    super.key,
    this.roomFactor,
    this.roomOffset = 0,
    this.capFactor,
    this.capOffset = 0,
    this.spill = false,
    this.spillAlign = -1,
    this.atHeight = false,
    this.floor,
    super.child,
  });

  /// The least the box narrows to, where that is not its content's
  /// min-content: a flex item that is a scroll container, or that clips and
  /// states `min-width`, gives way down to that floor in its own line
  /// (css-flexbox-1 4.5), while what it CONTRIBUTES to whatever measures it
  /// is still its content's (9.9.1) -- so the box still answers its child's
  /// intrinsic widths, and only its fit reads this. Null: the child's
  /// min-content, as ever. A scroller of four 120px cards beside a label
  /// gives way to its row of 360, and a table measuring such an item hears
  /// its content.
  final double? floor;

  /// Whether the content is asked what width it wants AT THE HEIGHT this
  /// box is held to, where the room makes one tight. A flex item stretched
  /// to a line of definite height has that height (css-flexbox-1 9.4 step
  /// 11), and a picture at `min-height: 100%; max-height: 100%` with a
  /// ratio is as wide as that height transfers -- a telecom's app card is
  /// 334.78 wide in a 240px line, and asked with no height it answered its
  /// natural 604. Only where the line's height is definite: a line as tall
  /// as its content hands the same tight height down, and a share of THAT
  /// is `auto` (CSS 2.1 10.5).
  final bool atHeight;

  /// Whether a min-content wider than the room hangs out of it. The fit is
  /// `min(max(min-content, room), max-content)` (css-sizing-3 5.1), so a
  /// box whose narrowest is past the room is that narrowest -- a framework
  /// site's `fit-content` link round an 800px image in a 358px column is 802
  /// wide. This box still reports the room; the child it lays out at the wider
  /// width is the box the page draws.
  final bool spill;

  /// Which way the child hangs out where it is wider than the box: its
  /// start on the box's start (-1, a word too long for its line), the
  /// overflow split over both edges (0), or its end on the box's end (1).
  /// An item a column does not stretch is as wide as its fit-content, and
  /// fit-content has a min-content floor (css-flexbox-1 9.4 step 7): a link
  /// round a 46px icon is 46 wide in a 40px `align-items: center` column
  /// and sits 3px past both edges. Start and end are the inline axis's
  /// under the [Directionality] the box is built in.
  final double spillAlign;

  /// The room the box shrinks into where that is not all of the width it is
  /// offered: this share of it, plus [roomOffset]. An absolutely positioned
  /// box at `left: 50%` has only the half of its containing block past that
  /// edge (CSS 2.1 10.3.7), and it still keeps its longest word where even
  /// that is too little.
  final double? roomFactor;
  final double roomOffset;

  /// The most the box may come to, as a share of the width it is offered
  /// plus [capOffset]: a percentage `max-width` is a share of the whole
  /// containing block (CSS 2.1 10.4), not of the room past an inset.
  final double? capFactor;
  final double capOffset;

  @override
  RenderShrinkWidth createRenderObject(BuildContext context) => RenderShrinkWidth()
    ..roomFactor = roomFactor
    ..roomOffset = roomOffset
    ..capFactor = capFactor
    ..capOffset = capOffset
    ..spill = spill
    ..spillAlign = spillAlign
    ..direction = Directionality.maybeOf(context) ?? TextDirection.ltr
    ..atHeight = atHeight
    ..floor = floor;

  @override
  void updateRenderObject(BuildContext context, RenderShrinkWidth renderObject) {
    renderObject
      ..roomFactor = roomFactor
      ..roomOffset = roomOffset
      ..capFactor = capFactor
      ..capOffset = capOffset
      ..spill = spill
      ..spillAlign = spillAlign
      ..direction = Directionality.maybeOf(context) ?? TextDirection.ltr
      ..atHeight = atHeight
      ..floor = floor;
  }
}

/// The render object behind [ShrinkWidth].
class RenderShrinkWidth extends RenderProxyBox with DryLastBaseline, AsksGuarded, PassesBaseline, KeptUnderHatch {
  RenderShrinkWidth([super.child]);

  double? _roomFactor;
  set roomFactor(double? v) {
    if (_roomFactor == v) return;
    _roomFactor = v;
    markNeedsLayout();
  }

  double _roomOffset = 0;
  set roomOffset(double v) {
    if (_roomOffset == v) return;
    _roomOffset = v;
    markNeedsLayout();
  }

  double? _capFactor;
  set capFactor(double? v) {
    if (_capFactor == v) return;
    _capFactor = v;
    markNeedsLayout();
  }

  double _capOffset = 0;
  set capOffset(double v) {
    if (_capOffset == v) return;
    _capOffset = v;
    markNeedsLayout();
  }

  bool _spill = false;
  set spill(bool v) {
    if (_spill == v) return;
    _spill = v;
    markNeedsLayout();
  }

  double _spillAlign = -1;
  set spillAlign(double v) {
    if (_spillAlign == v) return;
    _spillAlign = v;
    markNeedsLayout();
  }

  TextDirection _direction = TextDirection.ltr;
  set direction(TextDirection v) {
    if (_direction == v) return;
    _direction = v;
    markNeedsLayout();
  }

  /// How far the child was set left of this box: nothing until it is wider
  /// than the box, then its overflow, shared out as [ShrinkWidth.spillAlign]
  /// says.
  double _shift = 0;

  double? _floor;
  set floor(double? v) {
    if (_floor == v) return;
    _floor = v;
    markNeedsLayout();
  }

  bool _atHeight = false;
  set atHeight(bool v) {
    if (_atHeight == v) return;
    _atHeight = v;
    markNeedsLayout();
  }

  /// The width the box settles on in [constraints]'s room.
  double _fit(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.minWidth;
    // Shrinking into a share of its room, the box is offered that room
    // loose, and one no wider than nothing is still loose: a box at the
    // end of a containing block 0 wide takes its content's width.
    final slot = _roomFactor != null;
    if (constraints.hasTightWidth && !(slot && constraints.maxWidth == 0)) return constraints.minWidth;
    // How wide it would be with no bound at all is what it wants, which a
    // box laid out asks its content and the intrinsic question need not
    // say the same: a column that wraps into two answers one column's
    // width, and a ratio no width at all.
    final at = _atHeight && constraints.hasTightHeight ? constraints.maxHeight : double.infinity;
    return guardedSize(child, () {
      final wanted = slot
          ? child.getDryLayout(BoxConstraints(maxHeight: constraints.maxHeight)).width
          : child.getMaxIntrinsicWidth(at);
      if (!constraints.hasBoundedWidth) return constraints.constrainWidth(wanted.isFinite ? wanted : 0.0);
      final least = _floor ?? child.getMinIntrinsicWidth(at);
      final f = _roomFactor;
      final room = f == null ? constraints.maxWidth : math.max(0.0, constraints.maxWidth * f + _roomOffset);
      var fit = math.min(math.max(least, room), wanted);
      if (_capFactor case final c?) fit = math.min(fit, math.max(0.0, constraints.maxWidth * c + _capOffset));
      if (f == null && !_spill) return constraints.constrainWidth(fit);
      return math.max(constraints.minWidth, fit);
    });
  }

  /// What the child is laid out under: exactly the width the box settles
  /// on -- which, shrinking into a share of the room, may be past the room
  /// itself: the child keeps its longest word and hangs out of the end.
  BoxConstraints _inner(BoxConstraints c) {
    final w = _fit(c);
    if (w <= c.maxWidth) return c.tighten(width: w);
    return BoxConstraints(minWidth: w, maxWidth: w, minHeight: c.minHeight, maxHeight: c.maxHeight);
  }

  /// What the child is laid out under in [constraints] ([_inner]), for a
  /// box above that measures down through this one without laying it out
  /// (a line clamp finding where its cut ends).
  BoxConstraints childConstraints(BoxConstraints constraints) => _inner(constraints);

  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      guardedSize(child, () => child?.getMaxIntrinsicHeight(_fit(BoxConstraints(maxWidth: width))) ?? 0.0);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return constraints.constrain(guardedSize(child, () => child.getDryLayout(_inner(constraints))));
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) =>
      child == null ? null : dryBaselineOf(child!, _inner(constraints), baseline);

  @override
  double? dryLastBaseline(BoxConstraints constraints, TextBaseline baseline) =>
      child == null ? null : dryLastBaselineOf(child!, _inner(constraints), baseline);

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_inner(constraints), parentUsesSize: true);
    size = constraints.constrain(child.size);
    final over = child.size.width - size.width;
    final end = _direction == TextDirection.ltr ? (_spillAlign + 1) / 2 : (1 - _spillAlign) / 2;
    _shift = over > 0 ? -over * end : 0.0;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child != null) context.paintChild(child, offset + Offset(_shift, 0));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    return child != null &&
        result.addWithPaintOffset(
          offset: Offset(_shift, 0),
          position: position,
          hitTest: (result, transformed) => child.hitTest(result, position: transformed),
        );
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    transform.translateByDouble(_shift, 0, 0, 1);
  }
}
