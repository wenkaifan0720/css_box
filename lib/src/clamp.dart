import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';

/// Which content width a [KeywordClamp] bound is (css-sizing-3 5.1).
enum ContentWidth { min, max, fit }

/// A box whose own intrinsic width is a width it STATES rather than one it
/// measures -- a `SizedBox`, a clamp, a share of the room.
///
/// css-sizing-3 5.1 works a box's min-content and max-content sizes out of
/// its CONTENT: `width`, `min-width` and `max-width` are not part of the
/// answer, they are what the answer is then used to settle. So a keyword
/// bound asks past every box that only restates a number.
mixin StatedWidth on RenderProxyBox {}

/// The min- or max-content width of [box], past any width it states.
double contentIntrinsicWidth(RenderBox box, {required bool max, required double height}) {
  if (box is StatedWidth) {
    final inner = box.child;
    if (inner != null) return contentIntrinsicWidth(inner, max: max, height: height);
  }
  return max ? box.getMaxIntrinsicWidth(height) : box.getMinIntrinsicWidth(height);
}

/// A `min-width` or `max-width` stated as a SIZING KEYWORD.
///
/// `min-width: min-content` is a floor at the narrowest the box can be
/// drawn, `max-width: max-content` a cap at the widest it would ever want,
/// and `fit-content` the stretch fit between the two. None of them is a
/// number until the box has been measured, so the bound is worked out here
/// -- off the child's own intrinsics -- and applied to the constraints the
/// child is then laid out under.
class KeywordClamp extends SingleChildRenderObjectWidget {
  const KeywordClamp({super.key, this.floor, this.ceiling, this.textDirection = TextDirection.ltr, super.child});

  /// The keyword `min-width` states, and the one `max-width` states.
  final ContentWidth? floor, ceiling;

  /// The direction of the line or the block the box is laid out in, which
  /// says which side a floor past the room takes it over. A minimum wins
  /// over the width the box is handed (CSS 2.1 10.4), and a box wider than
  /// its room keeps its START edge on the room's and hangs off the END --
  /// the right under `ltr`, the LEFT under `rtl` -- on a line (css-text-3
  /// 7.1: an overflowing line is start-aligned) as in a block (CSS 2.1
  /// 10.3.3: in an over-constrained box the end margin is the one that
  /// gives). `min-width: max-content` round words wider than a 300px `rtl`
  /// line shows the words' first pixels past the line's left.
  final TextDirection textDirection;

  @override
  RenderKeywordClamp createRenderObject(BuildContext context) =>
      RenderKeywordClamp(floor, ceiling)..textDirection = textDirection;

  @override
  void updateRenderObject(BuildContext context, RenderKeywordClamp renderObject) => renderObject
    ..floor = floor
    ..ceiling = ceiling
    ..textDirection = textDirection;
}

class RenderKeywordClamp extends RenderProxyBox with ChildDryBaseline, KeptUnderHatch {
  RenderKeywordClamp(this._floor, this._ceiling);

  TextDirection _textDirection = TextDirection.ltr;
  set textDirection(TextDirection v) {
    if (_textDirection == v) return;
    _textDirection = v;
    markNeedsPaint();
  }

  /// Where the child stands in a box narrower than it: its start edge on
  /// the box's, so under `rtl` it is moved left by what it hangs over
  /// ([KeywordClamp.textDirection]).
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

  ContentWidth? _floor;
  ContentWidth? get floor => _floor;
  set floor(ContentWidth? v) {
    if (_floor == v) return;
    _floor = v;
    markNeedsLayout();
  }

  ContentWidth? _ceiling;
  ContentWidth? get ceiling => _ceiling;
  set ceiling(ContentWidth? v) {
    if (_ceiling == v) return;
    _ceiling = v;
    markNeedsLayout();
  }

  BoxConstraints _bounded(BoxConstraints c) {
    final child = this.child;
    if (child == null) return c;
    // The intrinsic is asked at an UNBOUNDED height: the question is how
    // wide the content wants to be, and a height it has not been given yet
    // is not part of it.
    double of(bool max) => contentIntrinsicWidth(child, max: max, height: double.infinity);
    double at(ContentWidth w) => switch (w) {
      ContentWidth.min => of(false),
      ContentWidth.max => of(true),
      // The stretch fit, clamped between the two (css-sizing-3 5.1).
      ContentWidth.fit => math.min(of(true), math.max(of(false), c.maxWidth)),
    };
    var lo = c.minWidth, hi = c.maxWidth;
    guardedSize(child, () {
      if (_floor case final f?) lo = math.max(lo, at(f));
      if (_ceiling case final k?) hi = math.min(hi, at(k));
    });
    // A minimum wins over a maximum (CSS 2.1 10.4).
    if (hi < lo) hi = lo;
    if (lo > hi) lo = hi;
    return BoxConstraints(minWidth: lo, maxWidth: hi, minHeight: c.minHeight, maxHeight: c.maxHeight);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    final c = _bounded(constraints);
    return constraints.constrain(guardedSize(child, () => child.getDryLayout(c)));
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    final c = _bounded(constraints);
    child.layout(c, parentUsesSize: true);
    size = constraints.constrain(child.size);
  }
}
