/// A box as wide as the narrowest its content can be drawn.
library;

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'clamp.dart';
import 'dry.dart';

/// `width: min-content`: as narrow as the box can be without its content
/// overflowing (css-sizing-3 5.1) -- the width of the longest thing in it
/// that cannot be broken.
///
/// The other two ends of the same range already have widgets: `max-content`
/// is what Flutter's own [IntrinsicWidth] asks for, and `fit-content` is
/// `ShrinkWidth`. This is the third.
class MinContentWidth extends SingleChildRenderObjectWidget {
  const MinContentWidth({super.key, super.child});

  @override
  RenderMinContentWidth createRenderObject(BuildContext context) => RenderMinContentWidth();
}

/// The render object behind [MinContentWidth].
class RenderMinContentWidth extends RenderProxyBox with AsksGuarded, KeptUnderHatch {
  RenderMinContentWidth([super.child]);

  /// The width the box settles on in [constraints]'s room. A min-content
  /// width is the box's own answer whatever the room is, so a room too
  /// narrow for it is a room the content overflows.
  double _fit(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.minWidth;
    final least = guardedSize(child, () => child.getMinIntrinsicWidth(double.infinity));
    return constraints.constrainWidth(least.isFinite ? least : 0.0);
  }

  @override
  double computeMaxIntrinsicWidth(double height) => computeMinIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) {
    final child = this.child;
    if (child == null) return 0.0;
    return guardedSize(
      child,
      () => child.getMaxIntrinsicHeight(math.max(width, _fit(BoxConstraints(maxWidth: width)))),
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return constraints.constrain(
      guardedSize(child, () => child.getDryLayout(constraints.tighten(width: _fit(constraints)))),
    );
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) =>
      child == null ? null : dryBaselineOf(child!, constraints.tighten(width: _fit(constraints)), baseline);

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints.tighten(width: _fit(constraints)), parentUsesSize: true);
    size = constraints.constrain(child.size);
  }
}

/// A box exactly [width] wide, which answers a HEIGHT question at that
/// width.
///
/// `SizedBox(width: 100)` is the same box until something asks it how tall
/// it is. `RenderConstrainedBox` hands the question's own width straight to
/// its child and ignores the tight one it imposes, so a 100px column of
/// text asked for its height at 300 answers with one line -- and that
/// answer is what sizes the flex line or the grid track around it. A box
/// with BOTH sizes never had the problem: it answers its own height.
class FixedWidth extends SingleChildRenderObjectWidget {
  const FixedWidth({super.key, required this.width, super.child});

  final double width;

  @override
  RenderFixedWidth createRenderObject(BuildContext context) => RenderFixedWidth(width);

  @override
  void updateRenderObject(BuildContext context, RenderFixedWidth renderObject) => renderObject.width = width;
}

/// The render object behind [FixedWidth].
class RenderFixedWidth extends RenderProxyBox with StatedWidth, DryLastBaseline, AsksGuarded, KeptUnderHatch {
  RenderFixedWidth(this._width, [RenderBox? child]) : super(child);

  double _width;
  double get width => _width;
  set width(double value) {
    if (value == _width) return;
    _width = value;
    markNeedsLayout();
  }

  /// What a `SizedBox` of this width hands its child: the width tight at
  /// whatever the room allows, and the block axis untouched.
  BoxConstraints _inner(BoxConstraints c) => c.tighten(width: c.constrainWidth(_width));

  @override
  double computeMinIntrinsicWidth(double height) => _width;

  @override
  double computeMaxIntrinsicWidth(double height) => _width;

  /// The width the child is laid out at in [width] of room: the box's own,
  /// where the room has it ([_inner]). ASKED IN LESS ROOM THAN ITS WIDTH,
  /// the box is laid out at the room, and so is its child: answered at its
  /// own width, a 40px column round an 80px box of text came out 98 tall
  /// for the 154 its words wrapped to, and an `IntrinsicHeight` round it
  /// cut the last four lines off.
  double _laidAt(double width) => _inner(BoxConstraints(maxWidth: width)).maxWidth;

  @override
  double computeMinIntrinsicHeight(double width) =>
      guardedSize(child, () => child?.getMinIntrinsicHeight(_laidAt(width)) ?? 0.0);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      guardedSize(child, () => child?.getMaxIntrinsicHeight(_laidAt(width)) ?? 0.0);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    final inner = _inner(constraints);
    if (child == null) return inner.constrain(Size.zero);
    return guardedSize(child, () => child.getDryLayout(inner));
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) =>
      child == null ? null : dryBaselineOf(child!, _inner(constraints), baseline);

  /// Its last line is its child's at the width it offers it, as its first
  /// is: asked at the room it was handed, the words come to one long line
  /// and the walk ([dryLastBaselineOf]) answers the first.
  @override
  double? dryLastBaseline(BoxConstraints constraints, TextBaseline baseline) => child == null
      ? null
      : lastNotAboveFirst(
          dryLastBaselineOf(child!, _inner(constraints), baseline),
          () => computeDryBaseline(constraints, baseline),
        );

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = _inner(constraints).constrain(Size.zero);
      return;
    }
    child.layout(_inner(constraints), parentUsesSize: true);
    size = child.size;
  }
}
