import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';
import 'spot.dart';

/// [Align], with a baseline.
///
/// `RenderPositionedBox` implements `computeDryLayout` and NOT
/// `computeDryBaseline`, so a box placed inside a plain [Align] reports no
/// baseline at all -- and worse, asking one for a dry baseline THROWS in a
/// debug build, which takes down every paragraph that holds it in a
/// `WidgetSpan` and every flex or grid line that asks its first item where
/// its baseline is.
///
/// Everything else about it is [Align]: the same alignment, the same
/// height factor, the same layout -- unless it is told to let the child
/// [overflow] or [overflowHeight].
class AlignBox extends SingleChildRenderObjectWidget {
  const AlignBox({
    super.key,
    this.alignment = Alignment.center,
    this.widthFactor,
    this.heightFactor,
    this.overflow = false,
    this.overflowHeight = false,
    this.safeX = false,
    this.safeY = false,
    super.child,
  });

  final AlignmentGeometry alignment;
  final double? widthFactor;
  final double? heightFactor;

  /// Whether the child may be wider than this box. A block with a width of
  /// its own keeps it in a narrower container and hangs out of the end
  /// side, its margins -- `auto` ones too -- giving way (CSS 2.1 10.3.3,
  /// 10.3.7); [Align] squeezes it to fit. Where the child does not fit it
  /// hangs out as [alignment] says, or starts at the start edge under
  /// [safeX].
  final bool overflow;

  /// Whether the child may be taller than this box. A flex or grid item is
  /// as tall as its content whatever height its container states, and
  /// `center` or `end` puts one that does not fit out past the start edge
  /// too (css-align-3 4.4); [Align] squeezes it to fit.
  final bool overflowHeight;

  /// Whether a child that does not fit starts at the start edge on that
  /// axis, whatever [alignment] says: the `safe` fallback (css-align-3
  /// 4.4), and what an `auto` margin that gave way comes to (CSS 2.1
  /// 10.3.3, 10.3.7). Only with [overflow] or [overflowHeight]: a child
  /// that cannot overflow never needs the fallback.
  final bool safeX, safeY;

  @override
  RenderAlignBox createRenderObject(BuildContext context) =>
      RenderAlignBox(
          alignment: alignment,
          widthFactor: widthFactor,
          heightFactor: heightFactor,
          textDirection: Directionality.maybeOf(context),
        )
        ..overflow = overflow
        ..overflowHeight = overflowHeight
        ..safeX = safeX
        ..safeY = safeY;

  @override
  void updateRenderObject(BuildContext context, RenderAlignBox renderObject) {
    renderObject
      ..alignment = alignment
      ..widthFactor = widthFactor
      ..heightFactor = heightFactor
      ..textDirection = Directionality.maybeOf(context)
      ..overflow = overflow
      ..overflowHeight = overflowHeight
      ..safeX = safeX
      ..safeY = safeY;
  }
}

class RenderAlignBox extends RenderPositionedBox with AsksGuarded, KeptUnderHatch {
  RenderAlignBox({required super.alignment, super.widthFactor, super.heightFactor, required super.textDirection});

  bool _overflow = false;
  bool get overflow => _overflow;
  set overflow(bool v) {
    if (v == _overflow) return;
    _overflow = v;
    markNeedsLayout();
  }

  bool _overflowHeight = false;
  bool get overflowHeight => _overflowHeight;
  set overflowHeight(bool v) {
    if (v == _overflowHeight) return;
    _overflowHeight = v;
    markNeedsLayout();
  }

  bool _safeX = false;
  bool get safeX => _safeX;
  set safeX(bool v) {
    if (v == _safeX) return;
    _safeX = v;
    markNeedsLayout();
  }

  bool _safeY = false;
  bool get safeY => _safeY;
  set safeY(bool v) {
    if (v == _safeY) return;
    _safeY = v;
    markNeedsLayout();
  }

  /// What the child is laid out under: loosened, and with no bound on an
  /// axis where it may overflow.
  BoxConstraints _inner(BoxConstraints c) {
    final loose = c.loosen();
    return BoxConstraints(
      maxWidth: _overflow ? double.infinity : loose.maxWidth,
      maxHeight: _overflowHeight ? double.infinity : loose.maxHeight,
    );
  }

  /// [RenderPositionedBox]'s own size rule, for a child of [kid] size.
  Size _sized(BoxConstraints c, Size? kid) {
    final wrapWidth = widthFactor != null || c.maxWidth == double.infinity;
    final wrapHeight = heightFactor != null || c.maxHeight == double.infinity;
    return c.constrain(
      Size(
        wrapWidth ? (kid?.width ?? 0) * (widthFactor ?? 1) : double.infinity,
        wrapHeight ? (kid?.height ?? 0) * (heightFactor ?? 1) : double.infinity,
      ),
    );
  }

  /// Where a child of [kid] size goes in a box of [box] size.
  Offset _at(Size box, Size kid) {
    final o = resolvedAlignment.alongOffset(box - kid as Offset);
    final dx = _safeX && _overflow && kid.width > box.width
        ? (textDirection == TextDirection.rtl ? box.width - kid.width : 0.0)
        : o.dx;
    final dy = _safeY && _overflowHeight && kid.height > box.height ? 0.0 : o.dy;
    return Offset(dx, dy);
  }

  /// ASKED AT THE WIDTH IT IS LAID OUT AT. A child that may [overflow] is
  /// laid out with no bound on its width, so it is as wide as it asks to be
  /// -- its widest -- whatever width this box is asked about, and its
  /// height is the one it has there. Asked at this box's width instead, a
  /// child wider than the box answered for a layout it never gets:
  /// a price-table site's coin strip, a 1280 row in a 1248 column, wrapped its
  /// labels to 50 tall where it lays out 32, and the `IntrinsicHeight`
  /// above it held the whole price table 18px too tall at every desktop
  /// width. (A `SizedBox` hands on the width it is asked at, so asking at
  /// no width at all would answer one line where it wraps at its own.)
  double _kidWidth(double width) => _overflow ? (child?.getMaxIntrinsicWidth(double.infinity) ?? 0) : width;

  /// And a child that may [overflowHeight] is laid out with no bound on
  /// its height.
  double _kidHeight(double height) => _overflowHeight ? double.infinity : height;

  @override
  double computeMinIntrinsicHeight(double width) =>
      guardedSize(child, () => super.computeMinIntrinsicHeight(_kidWidth(width)));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      guardedSize(child, () => super.computeMaxIntrinsicHeight(_kidWidth(width)));

  @override
  double computeMinIntrinsicWidth(double height) =>
      guardedSize(child, () => super.computeMinIntrinsicWidth(_kidHeight(height)));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      guardedSize(child, () => super.computeMaxIntrinsicWidth(_kidHeight(height)));

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => guardedSize(child, () {
    if (!_overflow && !_overflowHeight) return super.computeDryLayout(constraints);
    return _sized(constraints, child?.getDryLayout(_inner(constraints)));
  });

  /// What is aligned: the child as it reports itself, or what it lays out
  /// where that is past what it reports ([Overhangs]) -- a share of a
  /// height with a length beyond it, which is the box the page draws:
  /// `height: calc(50% + 60px)` centred in a 90px row is 105 tall and 7.5
  /// above the row, where the room it reports is the row's 90.
  static Size _own(RenderBox k) => switch (k) {
    final Overhangs o => o.laidOut,
    _ => k.size,
  };

  @override
  void performLayout() {
    if (!_overflow && !_overflowHeight) {
      super.performLayout();
      final k = child;
      if (k != null && k is Overhangs) (k.parentData! as BoxParentData).offset = _at(size, _own(k));
      return;
    }
    final k = child;
    if (k == null) {
      size = _sized(constraints, null);
      return;
    }
    k.layout(_inner(constraints), parentUsesSize: true);
    size = _sized(constraints, k.size);
    (k.parentData! as BoxParentData).offset = _at(size, _own(k));
  }

  /// The child's own baseline, moved by however far this box places the
  /// child inside itself. `performLayout` lays the child out under
  /// [_inner], so the dry pass asks under the same ones or it is answering
  /// about a different layout.
  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) {
    final k = child;
    if (k == null) return null;
    final inner = _inner(constraints);
    final b = dryBaselineOf(k, inner, baseline);
    if (b == null) return null;
    return b + _at(getDryLayout(constraints), guardedSize(k, () => k.getDryLayout(inner))).dy;
  }
}
