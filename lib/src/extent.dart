/// The height a document scrolls to, and the layer that never scrolls.
library;

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';
import 'scroll.dart';

/// The size a document scrolls over: its child's box, or the furthest
/// bottom edge of anything laid out inside it, whichever is lower.
///
/// A viewport scrolls over the border box of every box in the document,
/// not over the root's box alone (css-overflow-3 2.2): a news site's body is
/// `height: 100%` with 4928px of content running out of it, a pricing page's
/// root is one window tall over a 12873px body, a car listing's body is
/// `position: absolute` in a root that holds nothing else, and another news
/// site's sticky header is stated 6931px tall and pulled up by a negative
/// margin over 4747px of content. Each is one viewport by its own box and
/// several by what is in it, and a `SingleChildScrollView` round the root
/// scrolled over the box: the render photographed one band of the first
/// where the browser has six.
///
/// A clipped subtree ends at its clip, an inner scroller at its viewport,
/// and a [FixedLayer] never scrolls (css-position-3 3.3), so none is
/// entered. Only the height: the document is as wide as the window.
class DocumentExtent extends SingleChildRenderObjectWidget {
  const DocumentExtent({super.key, super.child});

  @override
  RenderDocumentExtent createRenderObject(BuildContext context) => RenderDocumentExtent();
}

/// The render object behind [DocumentExtent].
class RenderDocumentExtent extends RenderProxyBox with ChildDryBaseline, KeptUnderHatch {
  RenderDocumentExtent({RenderBox? child}) : super(child);

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    // A box's size may be read during layout only by its parent (a debug
    // assertion); a layout callback lifts that for the walk.
    var far = 0.0;
    invokeLayoutCallback((BoxConstraints _) {
      far = furthestEdge(child, Axis.vertical);
    });
    size = constraints.constrain(Size(child.size.width, math.max(child.size.height, far)));
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => child == null
      ? constraints.smallest
      : constraints.constrain(guardedSize(child, () => child!.getDryLayout(constraints)));
}

/// The furthest edge on [axis] -- the lowest bottom, or the rightmost right
/// -- of anything laid out under [child], in [child]'s own coordinates. The
/// transform is carried down the tree rather than asked of each box, which
/// walks to the root every time. Read during layout, it must be asked from
/// a layout callback (`invokeLayoutCallback`): only a box's parent may read
/// its size there otherwise.
///
/// AN `ALIGN` UNDER A `FRACTIONALTRANSLATION` IS NO BOX OF THE PAGE. It is how
/// `left: 68%; top: 28%` stands an absolute box in its containing block: the
/// `Align` is as big as the block so that the fractions are of the block, and
/// the translation carries all of it, empty, that far over and down. Only what
/// it places counts (css-overflow-3 2.2), or a map's labels at the foot of a
/// page ran the document 206 past its end with nothing on it.
///
/// A CLIP THAT LEAVES THE FAR EDGE OPEN is entered, and what is under it
/// counts out to the clip's own edge: a box that clips on one axis
/// (`overflow-x: clip` beside a `visible`, css-overflow-3 3.1) cuts only
/// across, as a `ClipRect` whose rectangle runs far past the box above and
/// below (`InsetClip`), and the document scrolls on down to what hangs
/// out of it. A news site's body is one window tall and clipped across
/// over 7000px of page. A clip of the box itself, or any other shape,
/// still ends the walk, and so does a scroller: what is inside it is
/// scrolled to inside it (css-overflow-3 2.2) -- all but a [ScrollBox]'s
/// port across [axis], which scrolls the other way, clips nothing and
/// holds the content of a box that scrolls both ways.
double furthestEdge(RenderBox child, Axis axis) {
  final down = axis == Axis.vertical;
  var far = 0.0;
  void visit(RenderObject o, Matrix4 m, double cap) {
    if (o is RenderFixedLayer) return;
    if (o is RenderBox) {
      if (!o.hasSize) return;
      if (o is! RenderPositionedBox || o.parent is! RenderFractionalTranslation) {
        final r = MatrixUtils.transformRect(m, Offset.zero & o.size);
        final edge = math.min(down ? r.bottom : r.right, cap);
        if (edge > far) far = edge;
      }
      if (o is RenderClipRect) {
        final clip = o.clipper?.getClip(o.size);
        if (clip == null || (down ? clip.bottom <= o.size.height : clip.right <= o.size.width)) return;
        final at = MatrixUtils.transformRect(m, clip);
        cap = math.min(cap, down ? at.bottom : at.right);
      } else if (o is RenderScrollPort && o.axis != axis) {
        // Enter it.
      } else if (o is RenderClipRRect || o is RenderClipPath || o is RenderClipOval || o is RenderAbstractViewport) {
        return;
      }
    }
    o.visitChildren((c) {
      final cm = m.clone();
      o.applyPaintTransform(c, cm);
      visit(c, cm, cap);
    });
  }

  visit(child, Matrix4.identity(), double.infinity);
  return far;
}

/// The layer of a page that is placed against the window and never scrolls
/// with the document: its `position: fixed` boxes (css-position-3 3.3).
/// [DocumentExtent] does not look inside it.
///
/// HELD WHERE THE WINDOW IS. The layer is laid out at the corner of the
/// document -- where the window stands while nothing is scrolled -- and
/// the document scrolls in the [Scrollable] round it, so a header or a
/// bottom bar laid out there would scroll away with the first screen and
/// lie over whatever the scroll brought under it. It is painted, pressed
/// and reported moved by as far as that scroll has gone
/// ([RenderFixedLayer.shift]), which is where the window is: the bar stays
/// at the window's foot over every screen, as a browser keeps it.
/// Unscrolled it is painted exactly where it is laid out.
///
/// NEGATIVE: a layer in no [Scrollable] stays where it is laid out, and so
/// does one in a scroll that runs up or to the left, whose content does
/// not start at the corner the layer stands at. A layer inside an inner
/// scroller would hold to that one: the lowering never writes one there,
/// as a fixed box stays out of every box that clips.
class FixedLayer extends SingleChildRenderObjectWidget {
  const FixedLayer({super.key, super.child});

  @override
  RenderFixedLayer createRenderObject(BuildContext context) =>
      RenderFixedLayer(scroll: Scrollable.maybeOf(context)?.position);

  @override
  void updateRenderObject(BuildContext context, RenderFixedLayer renderObject) {
    renderObject.scroll = Scrollable.maybeOf(context)?.position;
  }
}

/// The render object behind [FixedLayer].
class RenderFixedLayer extends RenderProxyBox with ChildDryBaseline, KeptUnderHatch {
  RenderFixedLayer({RenderBox? child, ViewportOffset? scroll}) : _scroll = scroll, super(child);

  /// The scroll of the document the layer stands in, or null.
  ViewportOffset? get scroll => _scroll;
  ViewportOffset? _scroll;
  set scroll(ViewportOffset? value) {
    if (identical(value, _scroll)) return;
    if (attached) _scroll?.removeListener(_scrolled);
    _scroll = value;
    if (attached) _scroll?.addListener(_scrolled);
    _scrolled();
  }

  void _scrolled() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scroll?.addListener(_scrolled);
  }

  @override
  void detach() {
    _scroll?.removeListener(_scrolled);
    super.detach();
  }

  /// How far the layer is drawn from where it is laid out: as far as the
  /// document has scrolled, down or to the right.
  Offset get shift {
    final s = _scroll;
    if (s == null || !s.hasPixels) return Offset.zero;
    if (s case ScrollPosition(:final axisDirection)) {
      return switch (axisDirection) {
        AxisDirection.down => Offset(0, s.pixels),
        AxisDirection.right => Offset(s.pixels, 0),
        _ => Offset.zero,
      };
    }
    return Offset(0, s.pixels);
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

  /// Pressed where it is drawn: its box moved as far as it is drawn, and
  /// tested as any box is (a press off the box misses all of it).
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!((Offset.zero & size).shift(shift)).contains(position)) return false;
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
