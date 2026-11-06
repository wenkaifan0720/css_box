/// A scroll container: what runs past a box, scrolled to.
library;

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'clip.dart';
import 'dry.dart';
import 'extent.dart';
import 'paint_order.dart';
import 'sticky.dart';

/// `overflow: auto | scroll` (css-overflow-3 3.1): the box is a scroll
/// container, and what its content runs past it on a [vertical] or a
/// [horizontal] axis is scrolled to rather than cut off.
///
/// THE CONTENT IS LAID OUT AS THE CLIP ROUND IT LAYS IT OUT -- at the box's
/// own size, running out of it where the source's content ran out -- and
/// the box scrolls over the furthest edge anything in it reaches
/// ([furthestEdge]), the way [DocumentExtent] reads a page. So at rest the
/// picture is the clip's, and nothing moves but what is scrolled. It cuts
/// nothing itself: [ClipBox] builds it inside its own clip, which `overflow`
/// puts on both axes of a scroll container (css-overflow-3 3.1: `visible`
/// computes to `auto` beside a `scroll` or `auto`), and which cuts the
/// content where it is drawn.
///
/// An app's whole page can be one `overflow-y: scroll` box a window tall
/// with every card below the fold inside it, and its rows of chips and
/// cards `overflow-x: scroll`: cut instead, every page of the first app
/// that did it was a screen that never moved.
///
/// Both axes scroll as two views, the horizontal one inside the vertical
/// one, which reads the content through it.
///
/// Its baselines are its content's, where the content rests. Asked of a
/// box that has not been laid out, they are asked of the content itself,
/// not through the [Scrollable] round it: Flutter's own proxies assert in
/// debug where the content answers none (flutter#189711, 3.41 to 3.47).
class ScrollBox extends StatelessWidget {
  const ScrollBox({
    super.key,
    this.vertical = false,
    this.horizontal = false,
    this.takesPointer = true,
    required this.child,
  }) : assert(vertical || horizontal);

  /// Whether the box scrolls on each axis: `auto` or `scroll` there.
  final bool vertical, horizontal;

  /// Whether the box takes a pointer where nothing in it does: false for a
  /// box that is `pointer-events: none` (css-ui-4 8.1), which is no target
  /// itself -- a press on it is what is drawn under it, and one on what it
  /// holds that says `auto` again is that one's, and scrolls it. A
  /// [Scrollable] is hit over its whole port, so a page's window-sized
  /// layer that scrolls and says `none` took every press under it.
  final bool takesPointer;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // NO CHROME: the platform's scrollbars and overscroll glow or stretch
    // are not the page's. The stretch is a `Transform` scaled about the
    // view's centre, which reads its own size wherever a box below it is
    // located -- by a `SpotShift` placing a bar during layout, which
    // asserted on every page of an app with a pinned bar. Dragged by what
    // drags the rest of the app ([ScrollConfiguration]).
    final behavior = ScrollConfiguration.of(context).copyWith(scrollbars: false, overscroll: false);
    var view = child;
    final hits = takesPointer ? HitTestBehavior.opaque : HitTestBehavior.deferToChild;
    if (horizontal) view = _view(Axis.horizontal, behavior, hits, view);
    if (vertical) view = _view(Axis.vertical, behavior, hits, view);
    return _ScrollFrame(views: (vertical ? 1 : 0) + (horizontal ? 1 : 0), child: view);
  }

  static Widget _view(Axis axis, ScrollBehavior behavior, HitTestBehavior hits, Widget child) => Scrollable(
    axisDirection: axis == Axis.vertical ? AxisDirection.down : AxisDirection.right,
    scrollBehavior: behavior,
    hitTestBehavior: hits,
    viewportBuilder: (context, offset) => _ScrollPort(axis: axis, offset: offset, child: child),
  );
}

/// Where a [ScrollBox]'s baselines are asked: of the content, under the
/// [views] it scrolls in. It is the scrollport of the [Sticky] boxes inside
/// (a [RenderStickyPort]), past every view, so a box is held to the edges
/// of the box whichever way it scrolls.
class _ScrollFrame extends SingleChildRenderObjectWidget {
  const _ScrollFrame({required this.views, super.child});

  final int views;

  @override
  _RenderScrollFrame createRenderObject(BuildContext context) => _RenderScrollFrame(views);

  @override
  void updateRenderObject(BuildContext context, _RenderScrollFrame renderObject) {
    renderObject.views = views;
  }
}

class _RenderScrollFrame extends RenderStickyPort with DryLastBaseline, AsksGuarded {
  _RenderScrollFrame(this.views);

  int views;

  /// The content: the child of the innermost of the [views] under this box,
  /// past the [Scrollable]s' own proxies, which each hold one child.
  RenderBox? get _content {
    RenderObject? o = child;
    var seen = 0;
    while (o != null) {
      if (o is RenderScrollPort && ++seen == views) return o.child;
      RenderObject? next;
      o.visitChildren((c) => next ??= c);
      o = next;
    }
    return null;
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) {
    final content = _content;
    return content == null ? null : dryBaselineOf(content, constraints, baseline);
  }

  @override
  double? dryLastBaseline(BoxConstraints constraints, TextBaseline baseline) {
    final content = _content;
    return content == null ? null : dryLastBaselineOf(content, constraints, baseline);
  }
}

class _ScrollPort extends SingleChildRenderObjectWidget {
  const _ScrollPort({required this.axis, required this.offset, super.child});

  final Axis axis;
  final ViewportOffset offset;

  @override
  RenderScrollPort createRenderObject(BuildContext context) => RenderScrollPort(axis: axis, offset: offset);

  @override
  void updateRenderObject(BuildContext context, RenderScrollPort renderObject) {
    renderObject
      ..axis = axis
      ..offset = offset;
  }
}

/// The view a [ScrollBox] scrolls on one [axis]: its content laid out at
/// the view's own size and drawn moved back by the [offset].
class RenderScrollPort extends RenderProxyBox with ChildDryBaseline, KeptUnderHatch implements RenderAbstractViewport {
  RenderScrollPort({required Axis axis, required ViewportOffset offset, RenderBox? child})
    : _axis = axis,
      _offset = offset,
      super(child);

  Axis get axis => _axis;
  Axis _axis;
  set axis(Axis value) {
    if (value == _axis) return;
    _axis = value;
    markNeedsLayout();
  }

  ViewportOffset get offset => _offset;
  ViewportOffset _offset;
  set offset(ViewportOffset value) {
    if (value == _offset) return;
    if (attached) _offset.removeListener(_moved);
    _offset = value;
    if (attached) _offset.addListener(_moved);
    markNeedsLayout();
  }

  void _moved() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _offset.addListener(_moved);
  }

  @override
  void detach() {
    _offset.removeListener(_moved);
    super.detach();
  }

  // NOT A REPAINT BOUNDARY, though a scroll view in Flutter is one: a
  // layer of its own is composited at the box's fractional offset, and its
  // edges come out a level or three off the clip it stands in for -- 20
  // pixels over three pages of one app. Scrolled, the content is
  // repainted with the boundary above it.

  /// Where the content is drawn: moved back along [axis] by the scroll.
  Offset get _shift {
    final px = _offset.hasPixels ? _offset.pixels : 0.0;
    return _axis == Axis.vertical ? Offset(0, -px) : Offset(-px, 0);
  }

  @override
  void performLayout() {
    super.performLayout();
    final child = this.child;
    var far = 0.0;
    // A box's size may be read during layout only by its parent (a debug
    // assertion); a layout callback lifts that for the walk.
    if (child != null) {
      invokeLayoutCallback((BoxConstraints _) {
        far = furthestEdge(child, _axis);
      });
    }
    final view = _axis == Axis.vertical ? size.height : size.width;
    _offset.applyViewportDimension(view);
    _offset.applyContentDimensions(0, math.max(0, far - view));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child != null) context.paintChild(child, offset + _shift);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final shift = _shift;
    transform.translateByDouble(shift.dx, shift.dy, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintOffset(
      offset: _shift,
      position: position,
      hitTest: (result, transformed) => _hitDrawn(child, result, transformed),
    );
  }

  /// The content is hit where it is drawn. Laid out at the view's size, it
  /// runs out of its own box -- everything scrolled into view is past it,
  /// and past every box between the view and the row or column that runs
  /// on (a carousel's padding and the box it spills from, each the view's
  /// width) -- and a box hit-tests only inside itself. So a box the point
  /// is past is asked of its children directly, each where it is painted,
  /// down to one the point is inside of, which hit-tests as any box does;
  /// each box passed is on the path, as an element is under what is
  /// pressed in it. Not past what cuts its child there
  /// ([RenderObject.describeApproximatePaintClip]) or lets no press
  /// through ([RenderIgnorePointer], [RenderAbsorbPointer],
  /// [RenderOffstage]): nothing of it is drawn there to be hit.
  static bool _hitDrawn(RenderBox box, BoxHitTestResult result, Offset at) {
    if (box.size.contains(at)) return box.hitTest(result, position: at);
    if (box is RenderIgnorePointer && box.ignoring ||
        box is RenderAbsorbPointer && box.absorbing ||
        box is RenderOffstage && box.offstage) {
      return false;
    }
    // The last painted is on top ([childrenInPaintOrder]).
    for (final child in childrenInPaintOrder(box).whereType<RenderBox>().toList().reversed) {
      final clip = box.describeApproximatePaintClip(child);
      if (clip != null && !clip.contains(at)) continue;
      final transform = Matrix4.identity();
      box.applyPaintTransform(child, transform);
      final hit = result.addWithPaintTransform(
        transform: transform,
        position: at,
        hitTest: (result, local) => _hitDrawn(child, result, local),
      );
      if (hit) {
        result.add(BoxHitTestEntry(box, at));
        return true;
      }
    }
    return false;
  }

  @override
  RevealedOffset getOffsetToReveal(RenderObject target, double alignment, {Rect? rect, Axis? axis}) {
    rect ??= target.paintBounds;
    final child = this.child;
    final at = _offset.hasPixels ? _offset.pixels : 0.0;
    // One axis: what is asked of the other is not this view's to move.
    if (child == null || target is! RenderBox || (axis != null && axis != _axis)) {
      return RevealedOffset(offset: at, rect: rect);
    }
    final bounds = MatrixUtils.transformRect(target.getTransformTo(child), rect);
    final vertical = _axis == Axis.vertical;
    final lead = vertical ? bounds.top : bounds.left;
    final extent = vertical ? bounds.height : bounds.width;
    final view = vertical ? size.height : size.width;
    final to = lead - (view - extent) * alignment;
    return RevealedOffset(offset: to, rect: bounds.shift(vertical ? Offset(0, -to) : Offset(-to, 0)));
  }

  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    if (!_offset.allowImplicitScrolling) {
      return super.showOnScreen(descendant: descendant, rect: rect, duration: duration, curve: curve);
    }
    final shown = RenderViewportBase.showInViewport(
      descendant: descendant,
      viewport: this,
      offset: _offset,
      rect: rect,
      duration: duration,
      curve: curve,
    );
    super.showOnScreen(rect: shown, duration: duration, curve: curve);
  }
}
