import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'dry.dart';

/// A box whose height follows its width through an [aspectRatio], and which
/// is never shorter than what is inside it.
///
/// Flutter's `AspectRatio` is the first half. The second is css-sizing-4
/// 4.3: a box with a preferred aspect ratio is FLOORED at its min-content
/// size in the ratio-dependent axis, unless it clips its overflow or states
/// a minimum of its own. A card at `aspect-ratio: 2` holding a 100px child
/// is 100 tall, not 60 -- and the flex line it sits in has to hear 100 when
/// it asks how tall the card would be, or the line comes out 60 and the
/// card spills into the row below.
class RatioBox extends SingleChildRenderObjectWidget {
  const RatioBox({super.key, required this.aspectRatio, this.maxFloor, this.oneLine = false, super.child})
    : assert(aspectRatio > 0);

  /// Width divided by height.
  final double aspectRatio;

  /// Whether the content floor is measured against an INDEFINITE inline
  /// size rather than at the width this box has.
  ///
  /// css-flexbox-1 9.9.2: the min-content cross size of a SINGLE-LINE flex
  /// container is "the largest of the flex items' min-content cross sizes",
  /// and each item is asked that against an indefinite inline size -- so an
  /// item's text is measured on ONE LINE. That is the size css-sizing-4 4.3
  /// floors the ratio-dependent axis at, and it is NOT the height the same
  /// words lay out at inside the box's own width: `fixtures/ratio-content-
  /// floor` g1 is the pair, a `max-width: 60px; aspect-ratio: 2` BLOCK that
  /// is 72 tall because its words wrap to three lines, beside a single-line
  /// flex row holding the same words that is 30, the ratio's own extent,
  /// with the text overflowing it. Wrap the row, or turn it into a column,
  /// and the lines are measured for real again.
  final bool oneLine;

  /// The most the content can hold the box open to: the floor stops at the
  /// box's maximum height, which a maximum WIDTH sets too, carried through
  /// the ratio -- at `max-width: 40px` and a ratio of 2, text that wraps to
  /// 60 still leaves the box 20 tall.
  final double? maxFloor;

  @override
  RenderRatioBox createRenderObject(BuildContext context) => RenderRatioBox(aspectRatio)
    ..maxFloor = maxFloor
    ..oneLine = oneLine;

  @override
  void updateRenderObject(BuildContext context, RenderRatioBox renderObject) {
    renderObject
      ..aspectRatio = aspectRatio
      ..maxFloor = maxFloor
      ..oneLine = oneLine;
  }
}

class RenderRatioBox extends RenderProxyBox with AsksGuarded, KeptUnderHatch {
  RenderRatioBox(this._aspectRatio, [RenderBox? child]) : super(child);

  double _aspectRatio;
  double get aspectRatio => _aspectRatio;
  set aspectRatio(double value) {
    if (value == _aspectRatio) return;
    _aspectRatio = value;
    markNeedsLayout();
  }

  double? _maxFloor;
  set maxFloor(double? value) {
    if (value == _maxFloor) return;
    _maxFloor = value;
    markNeedsLayout();
  }

  /// See [RatioBox.oneLine].
  bool _oneLine = false;
  set oneLine(bool value) {
    if (value == _oneLine) return;
    _oneLine = value;
    markNeedsLayout();
  }

  /// The width this box takes: the room it is HELD to, or -- where the room
  /// is only an offer -- what its content asks for.
  ///
  /// A box STRETCHED to its slot is given that width tight and takes it. A
  /// box that is not stretched is `width: auto` in a slot that only caps
  /// it, and `auto` there is the shrink-to-fit width (css-sizing-3 5.1):
  /// `fixtures/grid-ratio-stretch-which` d5 is an empty `aspect-ratio: 2`
  /// item at `place-self: start` in a 100x100 area, and Chrome draws it
  /// 0x0 -- neither axis was given a length, so the ratio has none to work
  /// from. Filling the offer instead drew it 100x50.
  double _width(BoxConstraints constraints) {
    if (constraints.hasTightWidth) return constraints.maxWidth;
    final child = this.child;
    return constraints.constrainWidth(
      child == null ? 0.0 : guardedSize(child, () => child.getMaxIntrinsicWidth(double.infinity)),
    );
  }

  double _height(double width) {
    final child = this.child;
    final byRatio = width / _aspectRatio;
    if (child == null) return byRatio;
    // AN INDEFINITE INLINE SIZE IS THE CONTENT'S OWN MAX-CONTENT WIDTH, not
    // an infinite one: `RenderParagraph` lays its text out at `minWidth:
    // width` to answer an intrinsic height, and `double.infinity` is no
    // width to lay anything out at. Asked at the width its words want, the
    // text does not wrap, which is the measurement css-flexbox-1 9.9.2
    // asks for (see [RatioBox.oneLine]).
    return guardedSize(child, () {
      final at = _oneLine ? child.getMaxIntrinsicWidth(double.infinity) : width;
      return math.max(byRatio, math.min(child.getMaxIntrinsicHeight(at), _maxFloor ?? double.infinity));
    });
  }

  // Asked at a height, the ratio answers from it, as `AspectRatio` does: a
  // row that stretches an empty `aspect-ratio: 2` item to 100 hears 200.
  @override
  double computeMinIntrinsicWidth(double height) =>
      height.isFinite ? height * _aspectRatio : child?.getMinIntrinsicWidth(height) ?? 0.0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      height.isFinite ? height * _aspectRatio : child?.getMaxIntrinsicWidth(height) ?? 0.0;

  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => width.isFinite ? _height(width) : 0.0;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final width = _width(constraints);
    return constraints.constrain(Size(width, _height(width)));
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) {
    final child = this.child;
    if (child == null) return null;
    final size = computeDryLayout(constraints);
    return dryBaselineOf(child, BoxConstraints.tight(size), baseline);
  }

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
    child?.layout(BoxConstraints.tight(size));
  }
}
