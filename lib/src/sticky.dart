/// A box held to the edges of the view it scrolls in.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';
import 'scroll.dart';

/// `position: sticky` (css-position-3 3.4): the box is laid out where the
/// flow puts it and DRAWN shifted by the least that keeps it inside its
/// scrollport's edges moved in by its insets -- a start inset holds it down
/// from the leading edge, an end inset up from the trailing one -- and never
/// out of its containing block, which caps the shift without reversing it.
///
/// The scrollport is the nearest [StickyPort] or [RenderAbstractViewport]
/// above the box, or the root where there is neither -- a [ScrollBox] as a
/// whole, not the view of each axis it scrolls in, which would hold a box
/// to a view that never moves down -- and the box's place in it is read
/// where it is drawn: that is the one place it is known. So at scroll 0 a
/// bar at the very top with `top: 28px` is drawn 28 down, a bookstore's
/// `top: 156px` filter column 9,621px down the page is not moved at all, and a
/// `bottom: 8px` bar below the fold is drawn up at the window's foot -- as
/// far as its block lets it. The block is the nearest [StickyBlock] above,
/// or the table a cell is in ([TableBox]).
///
/// HELD AS IT SCROLLS. The shift is worked out again at every paint, and
/// the box is painted again as any scroll round it moves
/// ([RenderSticky.scrolls]: each [Scrollable] it is in, out to the page's,
/// as [Scrollable.ensureVisible] walks them). A scroll repaints its view, but
/// a layer cached between the view and the box -- a [RepaintBoundary] of
/// the app's own, a [ListView]'s round each child -- is handed back as it
/// was drawn and moved whole: the box in it would scroll away with it.
/// NEGATIVE: a box out of the tree hears no more of the scrolls it was in.
///
/// A PERCENTAGE INSET is a share of the SCROLLPORT (css-position-3 3.4:
/// "percentages ... are relative to the size of the scrollport" for a
/// sticky box), which is only known where the box is drawn: `left: 100%`
/// is a [leftShare] of 1, and holds the box a whole view across from the
/// view's left edge -- which no box inside it reaches, so its block stops
/// it at the block's right edge. A news site writes its script slots so.
class Sticky extends SingleChildRenderObjectWidget {
  const Sticky({
    super.key,
    this.top,
    this.right,
    this.bottom,
    this.left,
    this.topShare,
    this.rightShare,
    this.bottomShare,
    this.leftShare,
    this.margin = EdgeInsets.zero,
    super.child,
  });

  /// The insets, as lengths. Null is `auto`: that edge holds nothing --
  /// unless its share says something.
  final double? top, right, bottom, left;

  /// The insets' shares of the scrollport, its height for [topShare] and
  /// [bottomShare] and its width for the others, on top of the lengths.
  final double? topShare, rightShare, bottomShare, leftShare;

  /// The box's own margins, which it keeps from its block's edges.
  final EdgeInsets margin;

  @override
  RenderSticky createRenderObject(BuildContext context) => RenderSticky(
    scrolls: scrollsRound(context),
    top: top,
    right: right,
    bottom: bottom,
    left: left,
    topShare: topShare,
    rightShare: rightShare,
    bottomShare: bottomShare,
    leftShare: leftShare,
    margin: margin,
  );

  @override
  void updateRenderObject(BuildContext context, RenderSticky renderObject) => renderObject
    ..scrolls = scrollsRound(context)
    ..top = top
    ..right = right
    ..bottom = bottom
    ..left = left
    ..topShare = topShare
    ..rightShare = rightShare
    ..bottomShare = bottomShare
    ..leftShare = leftShare
    ..margin = margin;
}

/// The scrolls of each [Scrollable] [context] is in, nearest first.
List<ViewportOffset> scrollsRound(BuildContext context) => [
  for (var s = Scrollable.maybeOf(context); s != null; s = Scrollable.maybeOf(s.context)) s.position,
];

/// The box whose edges a box [held] inside it is held to: the nearest
/// [RenderStickyPort] or [RenderAbstractViewport] round it -- a [ScrollBox]
/// as a whole, not the view of each axis it scrolls in -- or the root where
/// there is neither ([Sticky]).
RenderBox? stickyPortOf(RenderObject held) {
  RenderBox? port;
  for (var p = held.parent; p != null; p = p.parent) {
    if (p is RenderBox) port = p;
    if (p is RenderScrollPort) continue;
    if (p is RenderAbstractViewport || p is RenderStickyPort) break;
  }
  return port;
}

/// A box painted again as any of its [scrolls] moves: one drawn where it is
/// held as they scroll ([Sticky]).
mixin HearsScrolls on RenderObject {
  List<ViewportOffset> _heard = const [];

  /// The scrolls round the box: as any of them moves, the box is painted
  /// again where it is held, though a layer between them is not.
  List<ViewportOffset> get scrolls => _heard;
  set scrolls(List<ViewportOffset> value) {
    if (listEquals(value, _heard)) return;
    if (attached) {
      for (final s in _heard) {
        s.removeListener(markNeedsPaint);
      }
    }
    _heard = value;
    if (attached) {
      for (final s in _heard) {
        s.addListener(markNeedsPaint);
      }
    }
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    for (final s in _heard) {
      s.addListener(markNeedsPaint);
    }
  }

  @override
  void detach() {
    for (final s in _heard) {
      s.removeListener(markNeedsPaint);
    }
    super.detach();
  }
}

/// A box that is the containing block of the [Sticky] boxes inside it: what
/// they are shifted to, less its [inset], and no further. A [StickyBlock],
/// and a table, which is its cells' ([TableBox]).
abstract interface class HoldsSticky implements RenderBox {
  EdgeInsets get inset;
}

/// The containing block of the [Sticky] boxes inside it: this box less its
/// [inset], which is where a sticky child may be shifted to and no further.
class StickyBlock extends SingleChildRenderObjectWidget {
  const StickyBlock({super.key, this.inset = EdgeInsets.zero, super.child});

  /// The box's padding and border. What is inside them is its CONTENT box,
  /// which is a sticky child's containing block (CSS 2.1 10.1): a `right:
  /// 0` bar that runs past a padded body is not pulled back over the
  /// padding.
  final EdgeInsets inset;

  @override
  RenderStickyBlock createRenderObject(BuildContext context) => RenderStickyBlock(inset);

  @override
  void updateRenderObject(BuildContext context, RenderStickyBlock renderObject) => renderObject.inset = inset;
}

/// A scroll container's padding box, for the [Sticky] boxes inside it: the
/// scrollport they are held to the edges of (css-position-3 3.4), where the
/// box only clips what it would scroll and is no [RenderAbstractViewport].
/// At scroll 0 its edges are where it is.
class StickyPort extends SingleChildRenderObjectWidget {
  const StickyPort({super.key, super.child});

  @override
  RenderStickyPort createRenderObject(BuildContext context) => RenderStickyPort();
}

class RenderStickyPort extends RenderProxyBox with ChildDryBaseline, KeptUnderHatch {}

class RenderStickyBlock extends RenderProxyBox with ChildDryBaseline, KeptUnderHatch implements HoldsSticky {
  RenderStickyBlock(this._inset);

  @override
  EdgeInsets get inset => _inset;
  EdgeInsets _inset;
  set inset(EdgeInsets value) {
    if (_inset == value) return;
    _inset = value;
    markNeedsPaint();
  }
}

class RenderSticky extends RenderProxyBox with ChildDryBaseline, KeptUnderHatch, HearsScrolls {
  RenderSticky({
    double? top,
    double? right,
    double? bottom,
    double? left,
    double? topShare,
    double? rightShare,
    double? bottomShare,
    double? leftShare,
    EdgeInsets margin = EdgeInsets.zero,
    List<ViewportOffset> scrolls = const [],
  }) : _top = top,
       _right = right,
       _bottom = bottom,
       _left = left,
       _topShare = topShare,
       _rightShare = rightShare,
       _bottomShare = bottomShare,
       _leftShare = leftShare,
       _margin = margin {
    _heard = scrolls;
  }

  double? get topShare => _topShare;
  double? _topShare;
  set topShare(double? v) {
    if (_topShare == v) return;
    _topShare = v;
    markNeedsPaint();
  }

  double? get rightShare => _rightShare;
  double? _rightShare;
  set rightShare(double? v) {
    if (_rightShare == v) return;
    _rightShare = v;
    markNeedsPaint();
  }

  double? get bottomShare => _bottomShare;
  double? _bottomShare;
  set bottomShare(double? v) {
    if (_bottomShare == v) return;
    _bottomShare = v;
    markNeedsPaint();
  }

  double? get leftShare => _leftShare;
  double? _leftShare;
  set leftShare(double? v) {
    if (_leftShare == v) return;
    _leftShare = v;
    markNeedsPaint();
  }

  /// An inset of [length] and [share] of [room]; null where both are.
  static double? _inset(double? length, double? share, double room) =>
      length == null && share == null ? null : (length ?? 0) + (share ?? 0) * room;

  double? get top => _top;
  double? _top;
  set top(double? v) {
    if (_top == v) return;
    _top = v;
    markNeedsPaint();
  }

  double? get right => _right;
  double? _right;
  set right(double? v) {
    if (_right == v) return;
    _right = v;
    markNeedsPaint();
  }

  double? get bottom => _bottom;
  double? _bottom;
  set bottom(double? v) {
    if (_bottom == v) return;
    _bottom = v;
    markNeedsPaint();
  }

  double? get left => _left;
  double? _left;
  set left(double? v) {
    if (_left == v) return;
    _left = v;
    markNeedsPaint();
  }

  EdgeInsets get margin => _margin;
  EdgeInsets _margin;
  set margin(EdgeInsets v) {
    if (_margin == v) return;
    _margin = v;
    markNeedsPaint();
  }

  /// Where the box is drawn from where it was laid out.
  Offset get shift {
    if (!hasSize || !attached) return Offset.zero;
    RenderBox? port;
    HoldsSticky? block;
    for (var p = parent; p != null; p = p.parent) {
      if (block == null && p is HoldsSticky) block = p;
      if (p is RenderBox) port = p;
      if (p is RenderScrollPort) continue;
      if (p is RenderAbstractViewport || p is RenderStickyPort) break;
    }
    if (port == null || !port.hasSize) return Offset.zero;
    final at = MatrixUtils.transformPoint(getTransformTo(port), Offset.zero);
    final room = port.size;
    double toward(double d, double room) => d > 0 ? math.min(d, math.max(0.0, room)) : math.max(d, math.min(0.0, room));
    final top = _inset(_top, _topShare, room.height), bottom = _inset(_bottom, _bottomShare, room.height);
    final left = _inset(_left, _leftShare, room.width), right = _inset(_right, _rightShare, room.width);
    var dy = 0.0, dx = 0.0;
    if (top case final t?) dy = math.max(0.0, t - at.dy);
    if (dy == 0.0 && bottom != null) dy = math.min(0.0, (room.height - bottom) - (at.dy + size.height));
    if (left case final l?) dx = math.max(0.0, l - at.dx);
    if (dx == 0.0 && right != null) dx = math.min(0.0, (room.width - right) - (at.dx + size.width));
    if (block != null && block.hasSize) {
      final b = MatrixUtils.transformPoint(block.getTransformTo(port), Offset.zero);
      final e = block.inset;
      dy = toward(
        dy,
        dy > 0
            ? (b.dy + block.size.height - e.bottom - _margin.bottom) - (at.dy + size.height)
            : (b.dy + e.top + _margin.top) - at.dy,
      );
      dx = toward(
        dx,
        dx > 0
            ? (b.dx + block.size.width - e.right - _margin.right) - (at.dx + size.width)
            : (b.dx + e.left + _margin.left) - at.dx,
      );
    }
    return Offset(dx, dy);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = child;
    if (c != null) context.paintChild(c, offset + shift);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final s = shift;
    if (s != Offset.zero) transform.multiply(Matrix4.translationValues(s.dx, s.dy, 0));
  }

  /// Hit where it is drawn, which may be outside where it was laid out.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!hitTestChildren(result, position: position)) return false;
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final c = child;
    if (c == null) return false;
    return result.addWithPaintOffset(
      offset: shift,
      position: position,
      hitTest: (r, p) => c.hitTest(r, position: p),
    );
  }
}
