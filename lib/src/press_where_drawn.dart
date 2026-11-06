/// A press lands on what is drawn where it lands.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';
import 'paint_order.dart';
import 'scroll.dart';

/// A PRESS LANDS ON WHAT IS DRAWN WHERE IT LANDS, as a browser hits a page
/// (CSS 2.1 Appendix E: the box painted last at the point), not only on
/// what every box round it holds. A box hit-tests only inside itself, and
/// a lowered page hangs boxes out of the boxes round them -- a bar placed
/// at the foot of a box of no height and drawn above it, a dialog moved to
/// the middle of the window from where its parent stands -- so a press on
/// one asked nothing of it and landed on what was drawn under it.
///
/// So a screen asks, beside what its boxes hit, each control in it -- what
/// takes a press: a gesture detector's listener, a text field, a line of
/// text with a link in it -- that a box round it is past at the point, no
/// clip round it cuts there and nothing round it ignores presses at. The
/// one of them painted last takes the press, over what the boxes hit where
/// it is painted over that, with every box round it on the path, as an
/// element is under what is pressed in it -- painted in the order each box
/// round them paints its children ([childrenInPaintOrder]), so a page's
/// sticky bar takes the press over the content scrolled under it. What the
/// boxes hit is the first box on their path: a press on a letter is hit in
/// the line of text it is in, so words painted over a hung control take
/// the press on their letters as off them. A control inside every box
/// round it is hit as any box is, and so is one a scroll port hits where
/// it is drawn ([RenderScrollPort]).
class PressWhereDrawn extends SingleChildRenderObjectWidget {
  const PressWhereDrawn({super.key, super.child});

  @override
  RenderPressWhereDrawn createRenderObject(BuildContext context) => RenderPressWhereDrawn();
}

/// The screen of a [PressWhereDrawn].
class RenderPressWhereDrawn extends RenderProxyBox with KeptUnderHatch {
  RenderPressWhereDrawn({RenderBox? child}) : super(child);

  /// Each control under this box, with its box in this one's, until the
  /// next frame lays out or paints anything again.
  List<(RenderBox, Rect)>? _controls;

  List<(RenderBox, Rect)> get _drawn {
    if (_controls case final controls?) return controls;
    final found = <(RenderBox, Rect)>[];
    void walk(RenderObject o) {
      if (o is RenderPressWhereDrawn) return;
      if (o is RenderBox && o.hasSize && _takesPresses(o)) {
        found.add((o, MatrixUtils.transformRect(o.getTransformTo(this), Offset.zero & o.size)));
      }
      o.visitChildren(walk);
    }

    if (child case final child?) walk(child);
    SchedulerBinding.instance.addPostFrameCallback((_) => _controls = null);
    return _controls = found;
  }

  /// What takes a press: a gesture detector's listener, a text field, a
  /// line of text with a link in it.
  static bool _takesPresses(RenderBox box) => switch (box) {
    RenderPointerListener(onPointerDown: _?) => true,
    RenderEditable() => true,
    RenderParagraph(:final text) => !text.visitChildren((s) => !(s is TextSpan && s.recognizer != null)),
    _ => false,
  };

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    List<RenderObject>? hung;
    for (final (control, box) in _drawn) {
      if (!box.contains(position) || !control.attached) continue;
      final down = _hungAt(control, position);
      if (down != null && (hung == null || _over(control, hung.last))) hung = down;
    }
    if (hung != null) {
      final boxes = BoxHitTestResult();
      super.hitTest(boxes, position: position);
      // The first box on the path: a press on a letter is hit in the span
      // of it, before the paragraph that lays it out.
      final under = boxes.path.map((e) => e.target).whereType<RenderObject>().firstOrNull;
      if ((under == null || under == this || !_over(under, hung.last)) && _force(hung, 0, result, position)) {
        result.add(BoxHitTestEntry(this, position));
        return true;
      }
    }
    return super.hitTest(result, position: position);
  }

  /// The boxes from this one down to [control], where [control] is drawn
  /// at [position] past a box round it -- one that hit-tests only inside
  /// itself -- no clip round it cuts there, nothing round it lets no press
  /// through, and it takes the press there; else null. Under a scroll port
  /// no box is passed until one is entered: the port hits its content where
  /// it is drawn, past every box laid out at the view's size, down to one
  /// the point is inside of ([RenderScrollPort]).
  ///
  /// A CONTROL TAKES THE PRESS WHERE ITS OWN HIT TEST SAYS SO: a gesture
  /// detector that defers to its child, as wide as the window and holding a
  /// button at one end, is drawn over the whole of it and takes a press on
  /// its button alone. Taken as the one painted last at every point of it,
  /// it was handed the press, took none, and the press went to what the
  /// boxes hit -- past a control hung under it that would have taken it: a
  /// page's sticky table head under a fixed layer's full-window caption.
  List<RenderObject>? _hungAt(RenderBox control, Offset position) {
    final down = <RenderObject>[control];
    for (var o = control.parent; o != null && o != this; o = o.parent) {
      down.add(o);
    }
    down.add(this);
    final chain = down.reversed.toList();
    var at = position;
    var past = false, drawn = false;
    for (var i = 0; i + 1 < chain.length; i++) {
      final box = chain[i], child = chain[i + 1];
      if (box is RenderIgnorePointer && box.ignoring ||
          box is RenderAbsorbPointer && box.absorbing ||
          box is RenderOffstage && box.offstage) {
        return null;
      }
      if (box is RenderBox) {
        if (!box.hasSize) return null;
        final inside = box.size.contains(at);
        if (inside) drawn = false;
        // A transform asks what it holds wherever the point is.
        if (i > 0 && !inside && !drawn && box is! RenderTransform && box is! RenderFractionalTranslation) {
          past = true;
        }
      }
      if (box is RenderScrollPort) drawn = true;
      final clip = box.describeApproximatePaintClip(child);
      if (clip != null && !clip.contains(at)) return null;
      final transform = Matrix4.identity();
      box.applyPaintTransform(child, transform);
      final back = Matrix4.tryInvert(transform);
      if (back == null) return null;
      at = MatrixUtils.transformPoint(back, at);
    }
    return past && control.size.contains(at) && control.hitTest(BoxHitTestResult(), position: at) ? chain : null;
  }

  /// [chain] hit down to its last box at [at], each box on the way on the
  /// path, but this one, which its caller adds.
  static bool _force(List<RenderObject> chain, int i, BoxHitTestResult result, Offset at) {
    final box = chain[i];
    if (i == chain.length - 1) return (box as RenderBox).hitTest(result, position: at);
    final transform = Matrix4.identity();
    box.applyPaintTransform(chain[i + 1], transform);
    final hit = result.addWithPaintTransform(
      transform: transform,
      position: at,
      hitTest: (result, local) => _force(chain, i + 1, result, local),
    );
    if (hit && i > 0 && box is RenderBox) result.add(BoxHitTestEntry(box, at));
    return hit;
  }

  /// Whether [a] is painted over [b]: inside it, or in a child of the box
  /// both are in that it paints after the one [b] is in
  /// ([childrenInPaintOrder]).
  static bool _over(RenderObject a, RenderObject b) {
    final ups = <RenderObject>[];
    for (RenderObject? o = a; o != null; o = o.parent) {
      ups.add(o);
    }
    RenderObject? fromB;
    RenderObject? common = b;
    while (common != null && !ups.contains(common)) {
      fromB = common;
      common = common.parent;
    }
    if (common == null || common == a) return false;
    if (common == b) return true;
    final fromA = ups[ups.indexOf(common) - 1];
    final order = childrenInPaintOrder(common);
    return order.indexOf(fromA) > order.indexOf(fromB!);
  }
}
