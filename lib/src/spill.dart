/// A box whose content may be bigger than the box.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';

/// `overflow: visible`: the box is the size the room says, and its content
/// is laid out at the size the CONTENT says, painted past the edge where
/// that is larger (CSS 2.1 11.1.1).
///
/// Flutter's box protocol has no way to say this -- a child is never given
/// more room than its parent has -- so a [Column] under a page of content
/// taller than the window lays out short, and `RenderFlex` paints a
/// yellow-and-black striped band over a tenth of itself to say so. That
/// band is not a layout error here: the browser overflows the same box and
/// simply scrolls. The stripes are drawn from inside an `assert` with no
/// switch to turn them off, so the only way to be rid of them is for the
/// flex not to be the box that overflowed.
///
/// So this one takes the overflow instead. It hands the child no ceiling
/// on [axis] (both axes where that is null), reports the size the room
/// would have given it, and paints the child from its own top-left
/// wherever that leaves it -- its top-RIGHT under an `rtl`
/// [Directionality], where what does not fit hangs out of the left. Every
/// intrinsic and the baseline are the child's, unchanged: what the box
/// overflows by is nobody else's business.
class Spill extends SingleChildRenderObjectWidget {
  const Spill({super.key, this.axis, this.fill = false, this.floor = false, this.room = false, super.child});

  /// The axis the content may exceed the box on, or null for both.
  final Axis? axis;

  /// Whether the child still FILLS the room on that axis where it is
  /// smaller than it -- what `MainAxisSize.max` says, and what a flex with
  /// a main size of its own has to keep saying: `justify-content` has free
  /// space to hand out only where the line is as long as its box. The room
  /// goes in as the child's MINIMUM, so it is both at once: the line fills
  /// 1440 with 900 of cards in it, and runs to 1600 with 1600 of them.
  final bool fill;

  /// Whether the child keeps the FLOOR it was offered without being made to
  /// fill the room above it.
  ///
  /// A `min-height` gives a line a main size of its own where its `height`
  /// is `auto`: the content box is at least that tall (css-sizing-3 5.2),
  /// and `justify-content` hands out what is left of it. Zeroed like every
  /// other floor, the column shrink-wrapped its one item and a
  /// `justify-content: center` had nothing to centre in.
  final bool floor;

  /// Whether the height this box is offered is a CONTAINING BLOCK'S, for
  /// the boxes in the flow inside that take a share of it
  /// ([FractionalHeight.ofRoom]).
  ///
  /// A percentage height is of the containing block's content height
  /// where that is definite (CSS 2.1 10.5), whatever else is in the flow:
  /// `height: calc(50% + 10px)` over a 10px box in a 160px grid row is 90,
  /// and the box after it starts at 90. But the flow is a `Column`, and
  /// `RenderFlex` hands every child an unbounded height whatever it was
  /// handed itself -- so the share under it had nothing to be a share of,
  /// and came out as tall as its content (`fixtures/calc-share-height`
  /// n9). The block's flow is written inside this box, which is offered
  /// exactly the block's content height, and the share reads it off here.
  /// A box inside whose share is of it is laid out again when it changes,
  /// since the column's constraints do not.
  final bool room;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderSpill(axis, fill, floor, Directionality.maybeOf(context) ?? TextDirection.ltr, room);

  @override
  void updateRenderObject(BuildContext context, RenderSpill renderObject) {
    renderObject
      ..axis = axis
      ..fill = fill
      ..floor = floor
      ..room = room
      ..direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
  }
}

/// The render object behind [Spill].
class RenderSpill extends RenderProxyBox with ChildDryBaseline, DryLastBaseline, KeptUnderHatch {
  RenderSpill(this._axis, this._fill, [this._floor = false, this._direction = TextDirection.ltr, this._room = false]);

  Axis? _axis;
  bool _fill;
  bool _floor;
  TextDirection _direction;

  /// See [Spill.room].
  bool get room => _room;
  bool _room;
  set room(bool v) {
    if (v == _room) return;
    _room = v;
    markNeedsLayout();
  }

  /// The height this [room] was last offered.
  double? _offered;

  /// The boxes inside whose shares are of this [room]'s height.
  final Set<RenderBox> _dependants = {};

  /// The height the boxes inside take their shares of, where this is a
  /// [room] -- null where it is not, or was offered none -- and [dependant]
  /// is laid out again when it changes.
  double? roomFor(RenderBox dependant) {
    if (!_room) return null;
    _dependants.add(dependant);
    final h = _offered;
    return h != null && h.isFinite ? h : null;
  }

  /// Stops laying [dependant] out again for a room it no longer reads.
  void forget(RenderBox dependant) => _dependants.remove(dependant);

  /// Takes the height this box is offered, for the boxes inside whose
  /// shares are of it, and has them laid out again where it changed --
  /// from the callback that lets a box mark its own subtree mid-layout.
  void _offer(double height, {required bool laying}) {
    if (!_room) return;
    touchesRoom();
    final was = _offered;
    _offered = height;
    if (laying && was != height && _dependants.isNotEmpty) {
      invokeLayoutCallback((_) {
        for (final d in _dependants) {
          d.markNeedsLayout();
        }
      });
    }
  }

  set direction(TextDirection v) {
    if (v == _direction) return;
    _direction = v;
    markNeedsPaint();
  }

  set floor(bool v) {
    if (v == _floor) return;
    _floor = v;
    markNeedsLayout();
  }

  set axis(Axis? v) {
    if (v == _axis) return;
    _axis = v;
    markNeedsLayout();
  }

  set fill(bool v) {
    if (v == _fill) return;
    _fill = v;
    markNeedsLayout();
  }

  /// Where the child hangs out of a narrower box on the inline axis: past
  /// the END edge, which is the right under `ltr` and the LEFT under `rtl`
  /// -- an overflowing line is start-aligned whatever `text-align` says
  /// (css-text-3 7.1), so a 240px inline-block in a 200px rtl paragraph
  /// keeps its right edge on the box's and shows its first 40px past the
  /// left.
  Offset get _shift {
    final c = child;
    if (c == null || _axis == Axis.vertical || _direction == TextDirection.ltr) return Offset.zero;
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
  double? dryLastBaseline(BoxConstraints constraints, TextBaseline baseline) {
    final c = child;
    return c == null ? null : dryLastBaselineOf(c, _inner(constraints), baseline);
  }

  BoxConstraints _inner(BoxConstraints c) {
    var minW = c.minWidth, maxW = c.maxWidth;
    var minH = c.minHeight, maxH = c.maxHeight;
    // The floor goes with the ceiling. A block flow is as tall as what is
    // in it (CSS 2.1 10.6.3) and a `Column` shrink-wraps the same way, so
    // a tight offer must not reach the content -- only the BOX has to
    // report it, which `constrain` does. [fill] is the exception and is
    // the whole of what it means.
    if (_axis != Axis.vertical) {
      if (_fill && maxW.isFinite && maxW > minW) minW = maxW;
      if (!_fill && !_floor) minW = 0;
      maxW = double.infinity;
    }
    if (_axis != Axis.horizontal) {
      if (_fill && maxH.isFinite && maxH > minH) minH = maxH;
      if (!_fill && !_floor) minH = 0;
      maxH = double.infinity;
    }
    return BoxConstraints(minWidth: minW, maxWidth: maxW, minHeight: minH, maxHeight: maxH);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final c = child;
    // A dry pass is the same pass for the boxes inside: they read the
    // height they are a share of from here ([room]).
    _offer(constraints.maxHeight, laying: false);
    return c == null
        ? constraints.smallest
        : constraints.constrain(guardedSize(c, () => c.getDryLayout(_inner(constraints))));
  }

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    _offer(constraints.maxHeight, laying: true);
    c.layout(_inner(constraints), parentUsesSize: true);
    // The box is what the room said and the child is what its content
    // said. `constrain` is both at once: a tight room gives the room back,
    // a loose one the child's own size.
    size = constraints.constrain(c.size);
  }
}
