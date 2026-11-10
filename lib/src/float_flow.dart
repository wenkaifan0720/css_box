/// A block formatting context and its floats, laid out by Flutter alone:
/// CSS 2.1 9.4.1, 9.5 and 8.3.1 as render objects of their own.
///
/// A float is taken out of the stack of blocks and pushed against one side
/// of it; the blocks after it keep their width and run on under it, while
/// the LINES in them shorten to the room beside it, and a block that is a
/// formatting context of its own narrows into that room instead. Nothing in
/// Flutter takes a child out of a column and lets the next child's lines
/// know where it went, so no composition of stock widgets says it: a
/// `Stack` puts the float there and cannot shorten a line, a `Row` puts it
/// beside the whole of the next block however tall.
///
/// [FloatFlow] is the render object that does, written against Flutter's
/// box protocol and nothing else. Its children are ordinary widgets,
/// measured with Flutter's intrinsic sizes and dry layouts; the paragraphs
/// whose lines its floats shorten are [FloatText]s, which it sets a line at
/// a time in the room each line has; and a block of the same formatting
/// context is a [FloatFlow] of its own marked [FloatFlow.nested] under the
/// widgets that frame it (its padding, its decoration, its stated size),
/// laid out by the same pass.
///
/// The algorithm is Taffy's (`compute/block.rs`, `compute/float.rs`), which
/// is checked against Chrome box for box: float placement by bands of equal
/// room, clearance, the room a new formatting context finds beside the
/// floats, and the margins that collapse between blocks, through empty ones
/// and through the edges of the blocks that hold them. Taffy is MIT
/// licensed: its notice is in this package's NOTICES.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'content.dart';
import 'dry.dart';
import 'han.dart';
import 'offset_span.dart';

/// Which side a [FloatSlot] is pushed to, out of the stack (`float`).
enum FloatSide { none, left, right }

/// Which earlier floats a [FloatSlot] starts below (`clear`).
enum FloatClear { none, left, right, both }

/// A width written as a keyword rather than a length (css-sizing-3 5.1).
enum FloatWidth { minContent, maxContent, fitContent, stretch }

/// A BLOCK FORMATTING CONTEXT: the children stack down the page in order, a
/// floated one is taken out of that stack and pushed against one side of
/// it, and adjoining margins collapse into the one gap between them (CSS
/// 2.1 8.3.1, 9.4.1, 9.5).
///
/// A `Column` is the closest stock widget and stops short in three places
/// that come up wherever a page still uses floats: it cannot take a child
/// out of the stack, it ADDS margins where CSS collapses them, and it has
/// nothing that makes a later child start below a float or shorten its
/// lines beside one.
///
/// A child without a [FloatSlot] is a plain block: as wide as the box,
/// stacked under the one before it.
class FloatFlow extends MultiChildRenderObjectWidget {
  const FloatFlow({super.key, this.nested = false, this.floatsOut = false, super.children});

  /// Whether this flow is a block INSIDE the formatting context of the
  /// [FloatFlow] above it, rather than a context of its own: its floats and
  /// its lines are that box's to place (CSS 2.1 9.4.1), and it is laid out
  /// by that box's pass. A nested flow the box above cannot reach -- under
  /// a widget that moves or measures it -- is a flow laid out wrong, and
  /// says so.
  final bool nested;

  /// Whether this flow is a box of the page that starts no formatting
  /// context, laid out on its own only because nothing outside it stands
  /// beside its floats: the root of a context grows to hold its floats (CSS
  /// 2.1 10.6.7), and a plain block does not -- its last float hangs under
  /// its last line.
  final bool floatsOut;

  @override
  RenderFloatFlow createRenderObject(BuildContext context) => RenderFloatFlow(nested: nested, floatsOut: floatsOut);

  @override
  void updateRenderObject(BuildContext context, RenderFloatFlow renderObject) => renderObject
    ..nested = nested
    ..floatsOut = floatsOut;
}

/// How one child of a [FloatFlow] takes part.
class FloatSlot extends ParentDataWidget<FloatFlowParentData> {
  const FloatSlot({
    super.key,
    this.float = FloatSide.none,
    this.clear = FloatClear.none,
    this.bfc = false,
    this.width,
    this.widthFraction,
    this.widthKeyword,
    this.minWidthKeyword,
    this.height,
    this.heightFraction,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.minWidthFraction,
    this.maxWidthFraction,
    this.minHeightFraction,
    this.maxHeightFraction,
    this.maxWidthOther,
    this.maxWidthOtherFraction,
    this.margin = EdgeInsets.zero,
    this.marginShare = EdgeInsets.zero,
    this.autoLeft = false,
    this.autoRight = false,
    this.contentBox = false,
    this.frame = EdgeInsets.zero,
    this.onLine = false,
    this.lifted = false,
    required super.child,
  });

  /// Which side this child is pushed to, out of the stack.
  final FloatSide float;

  /// The floats this child starts below.
  final FloatClear clear;

  /// Whether the child is a formatting context of its own -- `overflow`
  /// other than `visible`, `display: flow-root`, a table. Such a box does
  /// not run UNDER a float: it narrows into the room beside it, or moves
  /// down past it where there is none (CSS 2.1 9.5).
  final bool bfc;

  /// The border-box width the child asks for, which the stack has to hear
  /// rather than measure: a float's width is what the room beside it is
  /// measured from.
  final double? width;

  /// [width] as a share of the box's content width.
  final double? widthFraction;

  /// [width] as a keyword. Takes the place of [width] and [widthFraction].
  final FloatWidth? widthKeyword;

  /// `min-width` as a keyword, [FloatWidth.minContent],
  /// [FloatWidth.maxContent] or [FloatWidth.fitContent]: a floor at the
  /// content's own width -- whatever [width] says -- which the pass
  /// measures, no widget between the two may (see [widthKeyword]); the
  /// last is that clamped into the room less the margins -- for a context
  /// of its own beside a float, the room beside it ([bfc]). A `<fieldset>`'s
  /// is `min-content` by default: an audio shop's footer form is one in a
  /// floated flow. It floors whatever [minWidth] does.
  final FloatWidth? minWidthKeyword;

  /// The border-box height the child asks for.
  final double? height;

  /// [height] as a share of the box's content height, where that is known.
  final double? heightFraction;

  /// The floor and the cap on each axis, in pixels.
  final double? minWidth, maxWidth, minHeight, maxHeight;

  /// The floors and the caps as shares of the box's content box. Beside a
  /// length on the same side they are the two summed: `max-width:
  /// calc(100% - 75px)` is `maxWidth: -75, maxWidthFraction: 1`.
  final double? minWidthFraction, maxWidthFraction, minHeightFraction, maxHeightFraction;

  /// A SECOND CAP ACROSS, a length and a share summed as [maxWidth] and
  /// [maxWidthFraction] are, where the child is held to the LARGER of the
  /// two: `max-width: max(50%, 200px)` is `maxWidthFraction: 0.5,
  /// maxWidthOther: 200` -- 200 in a box under 400, half of it past
  /// (css-values-4 10.9). Against a box of no width yet the whole cap is
  /// none, as a share alone is (css-sizing-3 5.2.1). Nothing without one
  /// of the two.
  final double? maxWidthOther, maxWidthOtherFraction;

  /// Space round the child, which the stack collapses down the page and
  /// lays out across it. A margin written into the child instead would be
  /// added where CSS collapses it.
  final EdgeInsets margin;

  /// [margin] where the page wrote it as a share of the containing block's
  /// width, on every side (CSS 2.1 8.3).
  final EdgeInsets marginShare;

  /// Whether the child's left and right margins are `auto`: what is left of
  /// the room once the child has its width goes to them (CSS 2.1 10.3.3).
  final bool autoLeft, autoRight;

  /// Whether a size written as a share of the box is the child's CONTENT
  /// box, its [frame] (or the padding round a hosted child) outside it
  /// (`box-sizing: content-box`). A size in pixels is always the border
  /// box: the stack is told the box the widget comes out as.
  final bool contentBox;

  /// The padding and border inside the child, which it paints itself: the
  /// child is asked in content-box terms and its answer is framed.
  final EdgeInsets frame;

  /// A float met in the middle of a line: its top is that line's, and the
  /// words before it stay beside it (CSS 2.1 9.5.1 rule 6). The child
  /// follows the [FloatText] whose line it stands on, which holds its place
  /// with U+FFFC.
  final bool onLine;

  /// Whether the child paints over the floats wherever it stands in the
  /// flow: a `relative` box, or one that starts a stacking context, paints
  /// with the positioned boxes (CSS 2.1 Appendix E step 8). Any other child
  /// that is no float paints UNDER them -- see [RenderFloatFlow.paint].
  final bool lifted;

  @override
  void applyParentData(RenderObject renderObject) {
    final d = renderObject.parentData! as FloatFlowParentData;
    final changed =
        d.float != float ||
        d.clear != clear ||
        d.bfc != bfc ||
        d.width != width ||
        d.widthFraction != widthFraction ||
        d.widthKeyword != widthKeyword ||
        d.minWidthKeyword != minWidthKeyword ||
        d.height != height ||
        d.heightFraction != heightFraction ||
        d.minWidth != minWidth ||
        d.maxWidth != maxWidth ||
        d.minHeight != minHeight ||
        d.maxHeight != maxHeight ||
        d.minWidthFraction != minWidthFraction ||
        d.maxWidthFraction != maxWidthFraction ||
        d.minHeightFraction != minHeightFraction ||
        d.maxHeightFraction != maxHeightFraction ||
        d.maxWidthOther != maxWidthOther ||
        d.maxWidthOtherFraction != maxWidthOtherFraction ||
        d.margin != margin ||
        d.marginShare != marginShare ||
        d.autoLeft != autoLeft ||
        d.autoRight != autoRight ||
        d.contentBox != contentBox ||
        d.frame != frame ||
        d.onLine != onLine;
    if (d.lifted != lifted) {
      d.lifted = lifted;
      // Laid out again, not only painted: whether the flow paints the
      // floats of a flow nested in the child is its layout's to say.
      final parent = renderObject.parent;
      if (parent is RenderObject) parent.markNeedsLayout();
    }
    if (!changed) return;
    d
      ..float = float
      ..clear = clear
      ..bfc = bfc
      ..width = width
      ..widthFraction = widthFraction
      ..widthKeyword = widthKeyword
      ..minWidthKeyword = minWidthKeyword
      ..height = height
      ..heightFraction = heightFraction
      ..minWidth = minWidth
      ..maxWidth = maxWidth
      ..minHeight = minHeight
      ..maxHeight = maxHeight
      ..minWidthFraction = minWidthFraction
      ..maxWidthFraction = maxWidthFraction
      ..minHeightFraction = minHeightFraction
      ..maxHeightFraction = maxHeightFraction
      ..maxWidthOther = maxWidthOther
      ..maxWidthOtherFraction = maxWidthOtherFraction
      ..margin = margin
      ..marginShare = marginShare
      ..autoLeft = autoLeft
      ..autoRight = autoRight
      ..contentBox = contentBox
      ..frame = frame
      ..onLine = onLine;
    final parent = renderObject.parent;
    if (parent is RenderObject) parent.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => FloatFlow;
}

/// What a [FloatSlot] tells its [FloatFlow]; see there.
class FloatFlowParentData extends ContainerBoxParentData<RenderBox> {
  FloatSide float = FloatSide.none;
  FloatClear clear = FloatClear.none;
  bool bfc = false;
  double? width, widthFraction;
  FloatWidth? widthKeyword, minWidthKeyword;
  double? height, heightFraction;
  double? minWidth, maxWidth, minHeight, maxHeight;
  double? minWidthFraction, maxWidthFraction, minHeightFraction, maxHeightFraction;
  double? maxWidthOther, maxWidthOtherFraction;
  EdgeInsets margin = EdgeInsets.zero;
  EdgeInsets marginShare = EdgeInsets.zero;
  bool autoLeft = false, autoRight = false, contentBox = false, onLine = false, lifted = false;
  EdgeInsets frame = EdgeInsets.zero;
}

// ================================================================= the box

/// The render object behind [FloatFlow].
class RenderFloatFlow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, FloatFlowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, FloatFlowParentData>,
        AsksGuarded,
        KeptUnderHatch {
  RenderFloatFlow({bool nested = false, bool floatsOut = false}) : _nested = nested, _floatsOut = floatsOut;

  /// See [FloatFlow.nested].
  bool get nested => _nested;
  bool _nested;
  set nested(bool v) {
    if (v == _nested) return;
    _nested = v;
    markNeedsLayout();
  }

  /// See [FloatFlow.floatsOut].
  bool get floatsOut => _floatsOut;
  bool _floatsOut;
  set floatsOut(bool v) {
    if (v == _floatsOut) return;
    _floatsOut = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! FloatFlowParentData) child.parentData = FloatFlowParentData();
  }

  /// What this box has already worked out, by question, until it is next
  /// marked dirty: a dry baseline asks every question again from scratch
  /// otherwise.
  final Map<String, Object> _answers = {};

  /// The flow whose pass laid this one out, while it is hosted.
  RenderFloatFlow? _host;

  /// The flow that paints this one's floats and lifted children with its
  /// own, while it does (see [paint]).
  RenderFloatFlow? _painter;

  /// The nested flows under this one's children whose floats and lifted
  /// children it paints, by the child they stand under.
  final Map<RenderBox, RenderFloatFlow> _hoisted = {};

  void _paintedBy(RenderFloatFlow? painter) {
    if (identical(painter, _painter)) return;
    _painter = painter;
    markNeedsPaint();
  }

  /// Whether this box is in the middle of placing its children: a hosted
  /// box it marks dirty then is not news to it.
  bool _placing = false;

  @override
  void markNeedsLayout() {
    _answers.clear();
    super.markNeedsLayout();
    // A hosted flow is laid out by its host's pass: what changes in it
    // changes that pass.
    final h = _host;
    if (h != null && !h._placing) h.markNeedsLayout();
  }

  // ------------------------------------------------------------ intrinsics

  double _intrinsic(_Space across) {
    final key = 'i$across';
    final known = _answers[key];
    if (known is double) return known;
    final pass = _Pass(this);
    final out = pass.lay(pass.root(), _In(size: true, widthOnly: true, aw: across, ah: _Space.maxContent), null);
    final v = out.size.width.isFinite ? out.size.width : 0.0;
    _answers[key] = v;
    return v;
  }

  @override
  double computeMinIntrinsicWidth(double height) => _intrinsic(_Space.minContent);

  @override
  double computeMaxIntrinsicWidth(double height) => _intrinsic(_Space.maxContent);

  // How tall this is at THAT width is a dry layout at that width: the same
  // code the real layout runs, so the answer cannot disagree with the size
  // the box ends up at.
  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) {
    final h = _run(width.isFinite ? BoxConstraints.tightFor(width: width) : const BoxConstraints()).size.height;
    return h.isFinite ? h : 0.0;
  }

  // ---------------------------------------------------------------- layout

  /// The pass at [constraints]: the box's size, its first baseline, and
  /// where every child goes.
  _Res _layOut(BoxConstraints constraints, {bool baselines = false}) {
    final tightW = constraints.hasTightWidth, tightH = constraints.hasTightHeight;
    // A minimum handed down from outside is the box's own min-size, and a
    // loose finite maximum its max-size; a box handed a TIGHT size is that
    // long whatever is round it.
    final limits = _Limits(
      minW: constraints.minWidth > 0 ? constraints.minWidth : null,
      minH: constraints.minHeight > 0 ? constraints.minHeight : null,
      maxW: !tightW && constraints.maxWidth.isFinite ? constraints.maxWidth : null,
      maxH: !tightH && constraints.maxHeight.isFinite ? constraints.maxHeight : null,
    );
    final aw = _Space.of(constraints.maxWidth), ah = _Space.of(constraints.maxHeight);
    _Res run(double? kw) {
      final pass = _Pass(this, baselines: baselines);
      return pass.lay(
        pass.root(limits),
        _In(kw: kw, kh: tightH ? constraints.maxHeight : null, pw: aw.option, ph: ah.option, aw: aw, ah: ah),
        null,
      );
    }

    var out = run(tightW ? constraints.maxWidth : null);
    // A box that sizes itself to its content is laid out AT the width that
    // comes to, and a share inside it is of that width.
    if (!tightW && out.size.width.isFinite && _sharesWidth()) out = run(constraints.constrainWidth(out.size.width));
    return out;
  }

  bool _sharesWidth() {
    for (var c = firstChild; c != null; c = (c.parentData! as FloatFlowParentData).nextSibling) {
      final d = c.parentData! as FloatFlowParentData;
      if (d.widthKeyword == null && d.width == null && d.widthFraction != null) return true;
      if (d.minWidthFraction != null || d.maxWidthFraction != null || d.maxWidthOtherFraction != null) return true;
    }
    return false;
  }

  _Res _run(BoxConstraints constraints, {bool baselines = false}) {
    final key = '${constraints.minWidth},${constraints.maxWidth},${constraints.minHeight},${constraints.maxHeight}';
    final have = _answers['b$key'] ?? (baselines ? null : _answers['s$key']);
    if (have is _Res) return have;
    final out = _layOut(constraints, baselines: baselines);
    _answers['${baselines ? 'b' : 's'}$key'] = out;
    return out;
  }

  @override
  @protected
  Size computeDryLayout(covariant BoxConstraints constraints) {
    if (_handed != null && constraints.isTight) return constraints.biggest;
    return constraints.constrain(_run(constraints).size);
  }

  @override
  @protected
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) {
    final h = _handed;
    if (h != null && constraints.isTight) return h.first;
    return _run(constraints, baselines: true).first;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final h = _handed;
    if (h != null) return h.first;
    return _run(constraints, baselines: true).first;
  }

  /// What the flow that hosts this one laid out for it: where each child
  /// goes, the frame the widgets between them keep round this box, the size
  /// the host gave this box's content, and its first baseline.
  _Handed? _handed;

  @override
  void performLayout() {
    final handed = _handed;
    if (handed != null) {
      _place(handed.boxes, handed.pad);
      size = constraints.constrain(handed.size);
      return;
    }
    // A nested flow laid out on its own would hold its floats in and set its
    // lines at its full width: not the layout the page has.
    assert(
      !nested,
      'a nested FloatFlow was not hosted by the FloatFlow round it: '
      'a widget between them is not one the host walks through',
    );
    _paintedBy(null);
    final out = _layOut(constraints);
    _place(out.boxes ?? const [], EdgeInsets.zero);
    size = constraints.constrain(out.size);
  }

  /// Hands each child the box the pass gave it -- and a hosted child the
  /// lines or the flow laid out inside it -- and lays it out at that size.
  /// [inset] is how far this box's origin sits inside its node's border box.
  void _place(List<_Box> boxes, EdgeInsets inset) {
    _placing = true;
    final was = _hoisted.values.toList();
    _hoisted.clear();
    try {
      for (final b in boxes) {
        final n = b.node;
        final child = n.child;
        // Measured at an unbounded width, an item that fills its container
        // comes to an infinite one, and a tight infinite constraint is one
        // no child can be laid out under: its content is the answer there.
        final w = b.size.width.isFinite
            ? b.size.width
            : guardedSize(child, () => child.getMaxIntrinsicWidth(double.infinity));
        final h = b.size.height.isFinite
            ? b.size.height
            : guardedSize(child, () => child.getMaxIntrinsicHeight(w.isFinite ? w : 0));
        final tight = Size(w.isFinite ? w : 0.0, h.isFinite ? h : 0.0);
        final r = b.res;
        final flow = n.flow;
        final text = n.text;
        if (n.kind == _K.flow && flow != null && r != null) {
          flow._host = this;
          flow._handed = _Handed(
            r.boxes ?? const [],
            n.pad,
            Size(tight.width - n.pad.horizontal, tight.height - n.pad.vertical),
            r.first == null ? null : r.first! - n.pad.top,
          );
          // Under the constraints it had last time a clean box is not laid
          // out again, and its children would stay where the last pass put
          // them. Told it needs to be, it runs -- from the callback that
          // lets a box mark its own subtree mid-layout.
          invokeLayoutCallback((_) => flow.markNeedsLayout());
          // Only a block in the flow: a float or a lifted box paints in a
          // layer of its own, which keeps the floats in it.
          final through = _layer(child) == 0 && _paintsThrough(child, flow);
          if (through) _hoisted[child] = flow;
          flow._paintedBy(through ? this : null);
        } else if (n.kind == _K.text && text != null && r != null) {
          text._host = this;
          text._take(r.lines ?? _Laid.none, n.pad);
          // Its widgets stand where the lines put them, which only its own
          // layout places: told it needs one, it runs.
          if (text.firstChild != null) invokeLayoutCallback((_) => text.markNeedsLayout());
        }
        child.layout(BoxConstraints.tight(tight), parentUsesSize: true);
        (child.parentData! as FloatFlowParentData).offset = Offset(b.offset.dx - inset.left, b.offset.dy - inset.top);
      }
      // A flow this one no longer hosts paints its own again.
      for (final f in was) {
        if (identical(f._painter, this) && !_hoisted.containsValue(f)) f._paintedBy(null);
      }
    } finally {
      _placing = false;
    }
  }

  /// Whether the widgets from [child] down to the nested [flow] under it
  /// only move it or paint under it: no layer, alpha, clip or transform of
  /// their own, nothing painted over it. A float paints with the floats of
  /// its stacking context (CSS 2.1 Appendix E step 5), and only a box that
  /// is one keeps them inside it.
  static bool _paintsThrough(RenderBox child, RenderFloatFlow flow) {
    RenderBox? r = child;
    while (r != null && !identical(r, flow)) {
      if (r.isRepaintBoundary) return false;
      if (r is RenderDecoratedBox && r.position != DecorationPosition.background) return false;
      if (r is RenderPadding) {
        r = r.child;
      } else if (r is RenderPositionedBox) {
        r = r.child;
      } else if (r is RenderConstrainedBox ||
          r is RenderFixedWidth ||
          r is RenderDecoratedBox ||
          r is RenderProxyBoxWithHitTestBehavior ||
          r is RenderIgnorePointer ||
          r is RenderSemanticsAnnotations ||
          r is RenderExcludeSemantics) {
        r = (r as RenderProxyBox).child;
      } else {
        return false;
      }
    }
    return r != null;
  }

  /// Which of the three layers [child] paints in (see [paint]).
  static int _layer(RenderBox child) {
    final d = child.parentData! as FloatFlowParentData;
    return d.float != FloatSide.none ? 1 : (d.lifted ? 2 : 0);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (var layer = 2; layer >= 0; layer--) {
      var child = lastChild;
      while (child != null) {
        final d = child.parentData! as FloatFlowParentData;
        if (_layer(child) == layer) {
          final hit = result.addWithPaintOffset(
            offset: d.offset,
            position: position,
            hitTest: (result, transformed) => child!.hitTest(result, position: transformed),
          );
          if (hit) return true;
        }
        child = d.previousSibling;
      }
    }
    return false;
  }

  /// THE FLOATS PAINT OVER THE BLOCKS OF THE FLOW, whatever the order they
  /// stand in: a context paints its in-flow blocks' backgrounds, then its
  /// floats, then the blocks' lines (CSS 2.1 Appendix E steps 4, 5 and 7).
  /// A child here is one widget, background and lines together, and what
  /// of it a float stands over is its background -- its lines are
  /// shortened round the float and a context of its own stands clear of it
  /// (9.5) -- so every child that is no float paints first, then the
  /// floats, then the [FloatSlot.lifted] children, which paint with the
  /// positioned boxes (step 8). A plain block with a background under a
  /// float drew over the float, which went missing.
  ///
  /// The floats of a block of this context are the context's too, painted
  /// over the blocks after it: a nested flow under widgets that only move
  /// it or paint under it paints its blocks alone, and its floats and
  /// lifted children are painted here, each in the place its block stands
  /// in the order of the flow (`fixtures/float-held-by-its-line`, a 50px
  /// float in one row hanging over the background of the next). Not one in
  /// a float or a lifted child, which paints as a context of its own and
  /// keeps its floats (`fixtures/float-pin-box`). Taps still go to the
  /// nested flow first, through the widgets round it.
  @override
  void paint(PaintingContext context, Offset offset) {
    for (var layer = 0; layer <= (_painter == null ? 2 : 0); layer++) {
      _paintLayer(context, offset, layer);
    }
  }

  void _paintLayer(PaintingContext context, Offset offset, int layer) {
    var child = firstChild;
    while (child != null) {
      final d = child.parentData! as FloatFlowParentData;
      final l = _layer(child);
      if (l == layer) {
        context.paintChild(child, d.offset + offset);
      } else if (l == 0 && layer > 0) {
        final inner = _hoisted[child];
        if (inner != null) {
          final at = MatrixUtils.getAsTranslation(inner.getTransformTo(this));
          assert(at != null, 'a nested flow painted through is only moved');
          inner._paintLayer(context, offset + (at ?? Offset.zero), layer);
        }
      }
      child = d.nextSibling;
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(FlagProperty('nested', value: _nested, ifTrue: 'nested'))
      ..add(FlagProperty('floatsOut', value: _floatsOut, ifTrue: 'floatsOut'));
  }
}

/// What a host hands a nested flow; see [RenderFloatFlow._handed].
class _Handed {
  _Handed(this.boxes, this.pad, this.size, this.first);
  final List<_Box> boxes;
  final EdgeInsets pad;
  final Size size;
  final double? first;
}

// ================================================================= values

double _fmax(double a, double b) => a > b ? a : b;
double _fmin(double a, double b) => a < b ? a : b;

/// [v] held between [min] and [max], the floor winning (Taffy's clamp).
double _clamp(double v, double? min, double? max) {
  var x = v;
  if (max != null && x > max) x = max;
  if (min != null && x < min) x = min;
  return x;
}

double? _clampN(double? v, double? min, double? max) => v == null ? null : _clamp(v, min, max);

double? _plus(double? v, double by) => v == null ? null : v + by;

/// The room a box is offered across or down (css-sizing-3 2.1): a length,
/// or one of the two intrinsic questions.
class _Space {
  const _Space.definite(this.value) : kind = 0;
  const _Space._(this.kind) : value = 0;
  static const _Space minContent = _Space._(1);
  static const _Space maxContent = _Space._(2);
  static _Space of(double extent) => extent.isFinite ? _Space.definite(extent) : maxContent;

  final int kind;
  final double value;

  bool get isDefinite => kind == 0;
  bool get isMin => kind == 1;
  double? get option => kind == 0 ? value : null;
  _Space sub(double v) => kind == 0 ? _Space.definite(value - v) : this;
  _Space map(double Function(double) f) => kind == 0 ? _Space.definite(f(value)) : this;

  @override
  String toString() => switch (kind) {
    1 => 'min',
    2 => 'max',
    _ => '$value',
  };
}

/// Margins that meet, collapsed (CSS 2.1 8.3.1): the most positive and the
/// most negative of them, added.
class _Margins {
  const _Margins(this.pos, this.neg);
  static const zero = _Margins(0, 0);
  factory _Margins.of(double m) => m >= 0 ? _Margins(m, 0) : _Margins(0, m);

  final double pos, neg;

  _Margins withMargin(double m) => m >= 0 ? _Margins(_fmax(pos, m), neg) : _Margins(pos, _fmin(neg, m));
  _Margins withSet(_Margins o) => _Margins(_fmax(pos, o.pos), _fmin(neg, o.neg));
  double get resolve => pos + neg;
}

// ======================================================= float placement

/// Taffy `float.rs:FIT_TOLERANCE`: absorbs rounding when checking whether a
/// box fits across (shares that sum to exactly 100% may otherwise exceed the
/// container and spuriously wrap).
const double _fitTolerance = 0.001;

int _sideOf(FloatSide s) => s == FloatSide.right ? 1 : 0;

/// An empty slot beside the floats for lines (Taffy `ContentSlot`).
class _ContentSlot {
  const _ContentSlot(this.segment, this.x, this.y, this.width);
  final int? segment;
  final double x, y, width;
  _ContentSlot shifted(double dx, double dy) => _ContentSlot(segment, x + dx, y + dy, width);
}

/// An empty slot for a box that is a formatting context of its own, whose
/// border box must not overlap a float (Taffy `BfcSlot`).
class _BfcSlot {
  const _BfcSlot(this.segment, this.x, this.y, this.borderWidth, this.stretchWidth);
  final int? segment;

  /// The border box's start edge.
  final double x, y;

  /// The room the border box has between float edges and the margin-inset
  /// containing block edges: the box fits if it is no wider.
  final double borderWidth;

  /// What an auto width comes to (before clamps): the trailing margin off,
  /// except where it overlaps a float.
  final double stretchWidth;
  _BfcSlot shifted(double dx, double dy) => _BfcSlot(segment, x + dx, y + dy, borderWidth, stretchWidth);
  _BfcSlot atY(double ny) => _BfcSlot(segment, x, ny, borderWidth, stretchWidth);
}

/// A band of the context with one room across for its whole height (Taffy
/// `Segment`). Insets: left in slot 0, right in slot 1.
class _Seg {
  _Seg(this.y0, this.y1, this.insets, this.hasFloat);
  double y0, y1;
  final List<double> insets;

  /// Whether a float really occupies each inset: a band made for a float is
  /// seeded with the containing block's insets on both sides.
  final List<bool> hasFloat;
}

/// Whether a float of [width] fits beside the float and containing-block
/// insets that apply to it (Taffy `float_fits_horizontally`): placed at the
/// further in of the float edge and the containing block edge on its side,
/// it must not overlap a float on the other side (rule 3), nor pass the
/// containing block's far edge where a float stands on its own side (rule
/// 7); a float nothing else constrains may overflow the far edge.
bool _floatFits(double width, int lead, double room, List<double> floats, List<double> cb) {
  final trail = 1 - lead;
  final at = _fmax(floats[lead], cb[lead]);
  final clearOfOthers = floats[trail] == 0.0 || at + width <= room - floats[trail] + _fitTolerance;
  final insideBlock = floats[lead] == 0.0 || at + width <= room - cb[trail] + _fitTolerance;
  return clearOfOthers && insideBlock;
}

/// The floats of one block formatting context (Taffy `FloatContext`),
/// placed by CSS 2.1 9.5.1's rules: 1. no further out than its containing
/// block; 2. beside or below every earlier float on its side; 3. clear of
/// the floats on the other side; 4-6. no higher than its containing block,
/// any earlier block or float, or the line it came in on; 7. not past the
/// far edge beside another float on its side; 8-9. as high as it can go,
/// then as far to its side.
class _FloatRoom {
  /// The width of the root of the context.
  double width = 0.0;
  bool hasFloats = false;
  final List<_Seg> _segs = [];

  /// The bands the last float on each side spans, start and end.
  final List<int> _lastStart = [0, 0];
  final List<int> _lastEnd = [0, 0];

  /// The bottom of the lowest float on each side, a float of no size too.
  final List<double?> _clearBottoms = [null, null];

  /// The highest a new float may start (rule 5), a float of no size too.
  double? _ceiling;

  bool hasActiveFloats(double minY) => hasFloats && (_segs.isNotEmpty ? _segs.last.y1 : 0.0) > minY;

  void _subdivide(int i, double at) {
    final old = _segs[i];
    final next = _Seg(at, old.y1, List.of(old.insets), List.of(old.hasFloat));
    old.y1 = at;
    _segs.insert(i + 1, next);
  }

  void _last(int side, int start, int end) {
    if (start > _lastStart[side]) _lastStart[side] = start;
    if (end > _lastEnd[side]) _lastEnd[side] = end;
  }

  /// Places a float whose margin box is [box], no higher than [minY]: its
  /// margin box's top-left in the context's coordinates.
  Offset place(Size box, double minY, List<double> cb, int side, FloatClear clear) {
    hasFloats = true;
    final (xInset, y) = _placeInner(box, minY, cb, side, clear);
    final bottom = y + box.height;
    final cbot = _clearBottoms[side];
    _clearBottoms[side] = cbot == null ? bottom : _fmax(cbot, bottom);
    final ceil = _ceiling;
    _ceiling = ceil == null ? y : _fmax(ceil, y);
    return side == 0 ? Offset(xInset, y) : Offset(width - xInset - box.width, y);
  }

  (double, double) _placeInner(Size box, double minYIn, List<double> cb, int side, FloatClear clear) {
    final minY = _fmax(
      _fmax(minYIn, _ceiling ?? double.negativeInfinity),
      clearedThreshold(clear) ?? double.negativeInfinity,
    );
    final floatStart = math.max(_lastStart[0], _lastStart[1]);
    final hwm = switch (clear) {
      FloatClear.left => math.max(floatStart, _lastEnd[0] + 1),
      FloatClear.right => math.max(floatStart, _lastEnd[1] + 1),
      FloatClear.both => math.max(_lastEnd[0], _lastEnd[1]) + 1,
      FloatClear.none => floatStart,
    };
    var startIdx = _positionFrom(hwm, minY) ?? _segs.length;
    var startY = minY;
    var endIdx = startIdx;
    int? start;
    int? end;
    double placedInset;
    outer:
    while (true) {
      // Nothing above takes it: a new band under every one there is.
      if (startIdx >= _segs.length) {
        start = null;
        end = null;
        placedInset = cb[side];
        break;
      }
      final s = _segs[startIdx];
      if (!_floatFits(box.width, side, width, s.insets, cb)) {
        startIdx += 1;
        endIdx = math.max(endIdx, startIdx);
        continue;
      }
      startY = _fmax(startY, s.y0);
      var slotHeight = s.y1 - startY;
      final floats = [0.0, 0.0];
      void union(List<double> insets) {
        floats[0] = _fmax(floats[0], insets[0]);
        floats[1] = _fmax(floats[1], insets[1]);
      }

      union(s.insets);
      // Its top pinned, the bands under it until it is deep enough, each
      // with room across.
      while (true) {
        if (endIdx >= _segs.length) {
          placedInset = _fmax(floats[side], cb[side]);
          start = startIdx;
          end = null;
          break outer;
        }
        final e = _segs[endIdx];
        union(e.insets);
        if (!_floatFits(box.width, side, width, floats, cb)) {
          startIdx += 1;
          endIdx = math.max(endIdx, startIdx);
          continue outer;
        }
        if (endIdx != startIdx) slotHeight += e.y1 - e.y0;
        if (!(slotHeight >= box.height)) {
          endIdx += 1;
          continue;
        }
        placedInset = _fmax(floats[side], cb[side]);
        start = startIdx;
        end = endIdx;
        break outer;
      }
    }
    // A float of no height takes no band; one of no width still does: its
    // edge is one a new context may not stand outside of.
    if (box.height == 0.0) return (placedInset, startY);
    if (start == null) {
      final lastEnd = _segs.isNotEmpty ? _segs.last.y1 : 0.0;
      if (startY > lastEnd) _segs.add(_Seg(lastEnd, startY, [0.0, 0.0], [false, false]));
      final y = _fmax(lastEnd, startY);
      final insets = List.of(cb);
      insets[side] += box.width;
      final has = [false, false];
      has[side] = true;
      _segs.add(_Seg(y, y + box.height, insets, has));
      final i = _segs.length - 1;
      _last(side, i, i + 1);
      return (cb[side], y);
    }
    var sIdx = start;
    if (startY != _segs[sIdx].y0) {
      _subdivide(sIdx, startY);
      sIdx += 1;
      if (end != null) end += 1;
    }
    int eIdx;
    if (end == null) {
      final lastEnd = _segs.isNotEmpty ? _segs.last.y1 : 0.0;
      if (minY > lastEnd) _segs.add(_Seg(lastEnd, minY, [0.0, 0.0], [false, false]));
      eIdx = _segs.length - 1;
    } else {
      eIdx = end;
      final endY = startY + box.height;
      // The heights summed can land a hair past the band that really holds
      // the end: walk back to it.
      while (eIdx > sIdx && endY <= _segs[eIdx].y0) {
        eIdx -= 1;
      }
      if (_segs[eIdx].y0 < endY && endY < _segs[eIdx].y1) _subdivide(eIdx, endY);
    }
    final edge = placedInset + box.width;
    for (var i = sIdx; i <= eIdx; i++) {
      _segs[i].insets[side] = edge;
      _segs[i].hasFloat[side] = true;
    }
    _last(side, sIdx, eIdx + 1);
    return (placedInset, startY);
  }

  int? _positionFrom(int from, double minY) {
    if (from > _segs.length) return null;
    for (var i = from; i < _segs.length; i++) {
      if (_segs[i].y1 > minY) return i;
    }
    return null;
  }

  int? _clearedSegment(FloatClear clear) {
    final l = _lastEnd[0], r = _lastEnd[1];
    return switch (clear) {
      FloatClear.left => l > 0 ? l : null,
      FloatClear.right => r > 0 ? r : null,
      FloatClear.both => (l > 0 || r > 0) ? math.max(l, r) : null,
      FloatClear.none => null,
    };
  }

  /// The bottom of the lowest float [clear] names.
  double? clearedThreshold(FloatClear clear) {
    switch (clear) {
      case FloatClear.left:
        return _clearBottoms[0];
      case FloatClear.right:
        return _clearBottoms[1];
      case FloatClear.both:
        final l = _clearBottoms[0], r = _clearBottoms[1];
        if (l != null && r != null) return _fmax(l, r);
        return l ?? r;
      case FloatClear.none:
        return null;
    }
  }

  /// The room for lines at [minYIn] (Taffy `find_content_slot`).
  _ContentSlot contentSlot(double minYIn, List<double> cb, FloatClear clear, int? after) {
    _ContentSlot free(double y) => _ContentSlot(null, cb[0], y, width - cb[0] - cb[1]);
    if (!hasActiveFloats(minYIn)) return free(minYIn);
    final minY = _fmax(minYIn, clearedThreshold(clear) ?? double.negativeInfinity);
    final atLeast = after == null ? 0 : after + 1;
    final cleared = _clearedSegment(clear);
    final hwm = math.max(atLeast, cleared == null ? 0 : cleared + 1);
    final i = _positionFrom(hwm, minY);
    if (i == null) {
      // PAST THE LAST BAND content that asked to go below one starts WHERE
      // THAT ONE ENDS, not back at the y it asked from.
      final end = hwm > 0 && hwm <= _segs.length ? _segs[hwm - 1].y1 : minY;
      return free(_fmax(minY, end));
    }
    final s = _segs[i];
    final l = _fmax(s.insets[0], cb[0]), r = _fmax(s.insets[1], cb[1]);
    return _ContentSlot(i, l, _fmax(s.y0, minY), width - l - r);
  }

  /// The room for a box that is a context of its own (Taffy
  /// `find_bfc_slot`): its margins resolve against the containing block's
  /// edges and may overlap a float; its border box may not.
  _BfcSlot bfcSlot(double minYIn, List<double> cb, List<double> margins, FloatClear clear, int? after) {
    final mi = [cb[0] + margins[0], cb[1] + margins[1]];
    final freeWidth = width - mi[0] - mi[1];
    final free = _BfcSlot(null, mi[0], minYIn, freeWidth, freeWidth);
    if (!hasActiveFloats(minYIn)) return free;
    final minY = _fmax(minYIn, clearedThreshold(clear) ?? double.negativeInfinity);
    final atLeast = after == null ? 0 : after + 1;
    final cleared = _clearedSegment(clear);
    final hwm = math.max(atLeast, cleared == null ? 0 : cleared + 1);
    final i = _positionFrom(hwm, minY);
    if (i == null) {
      final lastEnd = _segs.isNotEmpty ? _segs.last.y1 : minY;
      return free.atY(_fmax(lastEnd, minY));
    }
    final s = _segs[i];
    final fit = [0.0, 0.0], stretch = [0.0, 0.0];
    fit[0] = s.hasFloat[0] ? _fmax(s.insets[0], mi[0]) : mi[0];
    stretch[0] = fit[0];
    // A positive trailing margin may overflow the containing block (it does
    // not decide the fit); a negative one widens the border box's room.
    fit[1] = s.hasFloat[1] ? _fmax(s.insets[1], cb[1]) : _fmin(mi[1], cb[1]);
    stretch[1] = s.hasFloat[1] ? _fmax(s.insets[1], mi[1]) : mi[1];
    return _BfcSlot(i, fit[0], _fmax(s.y0, minY), width - fit[0] - fit[1], width - stretch[0] - stretch[1]);
  }
}

/// The floats' share of a block's intrinsic width (Taffy
/// `FloatIntrinsicWidthCalculator`, with Blink's line-ending in-flow child).
class _FloatWidths {
  _FloatWidths(this.available);
  final _Space available;
  final List<double> _sums = [0.0, 0.0];
  double _contribution = 0.0;
  double _widest = 0.0;

  void addFloat(double width, int side, FloatClear clear) {
    if (!available.isMin) {
      // A float that clears a side goes below that side's floats.
      if (clear == FloatClear.left || clear == FloatClear.both) _sums[0] = 0.0;
      if (clear == FloatClear.right || clear == FloatClear.both) _sums[1] = 0.0;
      _sums[side] += width;
      _contribution = _fmax(_contribution, _sums[0] + _sums[1]);
    } else {
      _contribution = _fmax(_contribution, width);
    }
    _widest = _fmax(_widest, width);
  }

  /// A CHILD IN FLOW ENDS THE FLOATS' LINE (Blink `ComputeMinMaxSizes`):
  /// one that makes a new formatting context stands beside them and adds
  /// its width; either way the floats after it start a new line.
  void addInFlow(double width, {required bool newFc, required FloatClear clear}) {
    if (available.isMin) return;
    if (newFc) {
      if (clear == FloatClear.left || clear == FloatClear.both) _sums[0] = 0.0;
      if (clear == FloatClear.right || clear == FloatClear.both) _sums[1] = 0.0;
      _contribution = _fmax(_contribution, _sums[0] + _sums[1] + width);
    }
    _sums[0] = 0.0;
    _sums[1] = 0.0;
  }

  double get result => available.isDefinite ? _fmax(_fmin(_contribution, available.value), _widest) : _contribution;
}

/// One block's view of its formatting context (Taffy `BlockContext`).
class _Ctx {
  _Ctx._(this.room, {required this.yOffset, required this.insets, required this.isRoot, List<bool>? adjoining})
    : contentInsets = List.of(insets),
      adjoining = adjoining ?? [false, false];

  factory _Ctx.root() => _Ctx._(_FloatRoom(), yOffset: 0.0, insets: const [0.0, 0.0], isRoot: true);

  final _FloatRoom room;

  /// The block's border-box top, from the top of the context's root.
  final double yOffset;

  /// The block's border box, in from each side of the root.
  final List<double> insets;

  /// Its content box, in from each side of the root.
  List<double> contentInsets;

  /// How far down the block its floats reach (`-inf` with none).
  double floatContribution = double.negativeInfinity;
  final bool isRoot;

  /// Whether a float was placed, per side, while the block's current
  /// collapsing margin was still unresolved: a margin collapsing into it
  /// could still move it, so a cleared box whose margin adjoins it gets
  /// clearance whatever its position says.
  List<bool> adjoining;
  List<bool>? _topAdjoining;

  _Ctx sub(double dy, List<double> childInsets) => _Ctx._(
    room,
    yOffset: yOffset + dy,
    insets: [insets[0] + childInsets[0], insets[1] + childInsets[1]],
    isRoot: false,
    adjoining: List.of(adjoining),
  );

  void applyContentInset(List<double> c) => contentInsets = [insets[0] + c[0], insets[1] + c[1]];

  bool hasActiveFloats(double minY) => room.hasActiveFloats(minY + yOffset);

  Offset placeFloat(Size box, double minY, int side, FloatClear clear, bool adjoinsUnresolved) {
    if (adjoinsUnresolved) adjoining[side] = true;
    final p = room.place(box, minY + yOffset, contentInsets, side, clear);
    final pos = Offset(p.dx - insets[0], p.dy - yOffset);
    floatContribution = _fmax(floatContribution, pos.dy + box.height);
    return pos;
  }

  _ContentSlot contentSlot(double minY, FloatClear clear, int? after) =>
      room.contentSlot(minY + yOffset, contentInsets, clear, after).shifted(-insets[0], -yOffset);

  _BfcSlot bfcSlot(double minY, List<double> margins, FloatClear clear, int? after) =>
      room.bfcSlot(minY + yOffset, contentInsets, margins, clear, after).shifted(-insets[0], -yOffset);

  double? clearedThreshold(FloatClear clear) {
    final t = room.clearedThreshold(clear);
    return t == null ? null : t - yOffset;
  }

  bool hasAdjoiningFloat(FloatClear clear) => switch (clear) {
    FloatClear.left => adjoining[0],
    FloatClear.right => adjoining[1],
    FloatClear.both => adjoining[0] || adjoining[1],
    FloatClear.none => false,
  };

  void mergeAdjoining(List<bool> f) {
    adjoining[0] = adjoining[0] || f[0];
    adjoining[1] = adjoining[1] || f[1];
  }

  /// In-flow content was committed: the current margin's position is
  /// resolved, and the floats placed before it no longer adjoin it.
  void commitStrut() {
    _topAdjoining ??= List.of(adjoining);
    adjoining = [false, false];
  }

  List<bool> get topAdjoining => _topAdjoining ?? adjoining;

  void addChildContribution(double v) => floatContribution = _fmax(floatContribution, v);
}

// =============================================================== the pass

enum _K { flow, text, leaf }

/// A floor and a cap handed down from outside: the root's own min- and
/// max-size.
class _Limits {
  const _Limits({this.minW, this.maxW, this.minH, this.maxH});
  final double? minW, maxW, minH, maxH;
}

/// A box the pass lays out: the flow's root, a flow or a paragraph it
/// hosts, or a Flutter child it measures.
class _Node {
  _Node(
    this.kind,
    this.child,
    this.data, {
    this.flow,
    this.text,
    this.pad = EdgeInsets.zero,
    this.limits,
    this.reportsBaseline = false,
  });

  final _K kind;

  /// What the flow lays out at the box the pass gives the node (the root:
  /// the flow itself).
  final RenderBox child;

  /// The slot's word on the child; null for the root.
  final FloatFlowParentData? data;
  final RenderFloatFlow? flow;
  final RenderFloatText? text;

  /// The frame the widgets between a hosted child and its slot keep round
  /// it.
  final EdgeInsets pad;

  /// The root's constraints.
  final _Limits? limits;

  /// Whether the leaf says where its text sits: the root's own children do,
  /// where a baseline is asked for.
  final bool reportsBaseline;

  List<_Node> kids = const [];

  /// The floats that stand on a paragraph's lines, in the order it holds
  /// their places.
  final List<_Node> onLine = [];

  /// Whether this leaf is a float on a paragraph's line.
  bool inLine = false;

  FloatSide get side => data?.float ?? FloatSide.none;
  bool get floated => side != FloatSide.none;
  FloatClear get clear => data?.clear ?? FloatClear.none;

  /// A box in its parent's formatting context: not floated, not a context
  /// of its own.
  bool get sameBfc => !floated && !(data?.bfc ?? false);

  /// The padding round the node's content: a paragraph's is the frame the
  /// widgets between keep round it; a flow's is that where there is one,
  /// else its slot's frame; a leaf's is its slot's frame.
  EdgeInsets get padding => switch (kind) {
    _K.text => pad,
    _K.flow => pad != EdgeInsets.zero ? pad : (data?.frame ?? EdgeInsets.zero),
    _K.leaf => data?.frame ?? EdgeInsets.zero,
  };

  /// Whether the node's sizes are content-box ones (`box-sizing`), which
  /// only a share of the containing block makes them.
  bool get contentBox {
    final d = data;
    if (d == null || !d.contentBox) return false;
    final shared =
        d.widthFraction != null ||
        d.minWidthFraction != null ||
        d.maxWidthFraction != null ||
        d.maxWidthOtherFraction != null;
    return kind != _K.leaf && pad != EdgeInsets.zero ? shared || d.heightFraction != null : shared;
  }

  FloatWidth? get keyword => data?.widthKeyword;
  FloatWidth? get minKeyword => data?.minWidthKeyword;

  /// A length, a share of [basis], or both -- `calc(100% - 75px)` -- which
  /// is their sum; a share of nothing is nothing.
  static double? _len(double? px, double? share, double? basis) =>
      share == null ? px : (basis == null ? null : (px ?? 0) + share * basis);

  /// The sizes, resolved against [bw] across and [bh] down: null is `auto`,
  /// a keyword, or a share of nothing.
  double? width(double? bw) => data == null || keyword != null ? null : _len(data!.width, data!.widthFraction, bw);
  double? height(double? bh) => data == null ? null : _len(data!.height, data!.heightFraction, bh);
  double? minW(double? bw) => data == null ? limits?.minW : _len(data!.minWidth, data!.minWidthFraction, bw);
  double? maxW(double? bw) {
    final d = data;
    if (d == null) return limits?.maxW;
    final cap = _len(d.maxWidth, d.maxWidthFraction, bw);
    if (d.maxWidthOther == null && d.maxWidthOtherFraction == null) return cap;
    // The larger of two caps, each of the same box ([FloatSlot.maxWidthOther]);
    // a share of nothing makes the whole cap none.
    final other = _len(d.maxWidthOther, d.maxWidthOtherFraction, bw);
    return cap == null || other == null ? null : math.max(cap, other);
  }

  double? minH(double? bh) => data == null ? limits?.minH : _len(data!.minHeight, data!.minHeightFraction, bh);
  double? maxH(double? bh) => data == null ? limits?.maxH : _len(data!.maxHeight, data!.maxHeightFraction, bh);

  static double? _edge(double px, double share, double? basis) =>
      share != 0 ? (basis == null ? null : share * basis) : px;

  /// The margins against [basis]: null across is `auto`, and a share of
  /// nothing is null too.
  double? mLeft(double? basis) =>
      data == null ? 0.0 : (data!.autoLeft ? null : _edge(data!.margin.left, data!.marginShare.left, basis));
  double? mRight(double? basis) =>
      data == null ? 0.0 : (data!.autoRight ? null : _edge(data!.margin.right, data!.marginShare.right, basis));
  double? mTop(double? basis) => data == null ? 0.0 : _edge(data!.margin.top, data!.marginShare.top, basis);
  double? mBottom(double? basis) => data == null ? 0.0 : _edge(data!.margin.bottom, data!.marginShare.bottom, basis);
}

/// What the pass asks of one box (Taffy's `LayoutInput`).
class _In {
  const _In({
    this.size = false,
    this.widthOnly = false,
    this.kw,
    this.kh,
    this.pw,
    this.ph,
    required this.aw,
    required this.ah,
    this.c0 = false,
    this.c1 = false,
    this.bare = false,
  });

  /// Whether only the box's size is wanted (`RunMode::ComputeSize`), and of
  /// that only its width.
  final bool size, widthOnly;

  /// The size the box is known to be.
  final double? kw, kh;

  /// The containing block its shares are of.
  final double? pw, ph;

  /// The room it is offered.
  final _Space aw, ah;

  /// Whether its top and its bottom margins may collapse with its
  /// children's.
  final bool c0, c1;

  /// Whether the box's own `width` and its clamps across are set aside:
  /// what is asked is its CONTENT's width, which a keyword floor on it is
  /// (css-sizing-3 5.1 -- a box's min- and max-content sizes are its
  /// content's, whatever its `width` says).
  final bool bare;

  _In known(double? w, double? h) =>
      _In(size: size, widthOnly: widthOnly, kw: w, kh: h, pw: pw, ph: ph, aw: aw, ah: ah, c0: c0, c1: c1, bare: bare);
}

/// What a box's pass comes to (Taffy's `LayoutOutput`), and where it put
/// what is inside it.
class _Res {
  _Res(
    this.size, {
    this.top = _Margins.zero,
    this.bottom = _Margins.zero,
    this.through = false,
    this.first,
    this.last,
    this.noLast = false,
    this.boxes,
    this.lines,
  });

  final Size size;
  final _Margins top, bottom;

  /// Whether its margins collapse through it.
  final bool through;
  final double? first, last;
  final bool noLast;

  /// A flow's children, placed.
  final List<_Box>? boxes;

  /// A paragraph's lines.
  final _Laid? lines;
}

/// Where the pass put one node, in its container's border box.
class _Box {
  _Box(this.node, this.size, this.offset, [this.res]);
  final _Node node;
  final Size size;
  final Offset offset;
  final _Res? res;
}

/// One child of a block, read for one pass (Taffy `BlockItem`).
class _Item {
  _Item(this.node, this.w, this.h, this.minW, this.maxW, this.minH, this.maxH, {this.fit, this.fitAt});
  final _Node node;
  final double? w, h, minW, maxW, minH, maxH;

  /// A `fit-content` floor asked before its room was known: the content's
  /// min- and max-content widths, which the room it is offered clamps
  /// between (see [_Pass.itemsOf]).
  final (double, double)? fit;

  /// A `fit-content` floor asked where the room WAS known: the content's
  /// min- and max-content widths and the floor the box states beside the
  /// keyword. [minW] is the floor in the block's room; a context of its
  /// own beside a float is offered the room beside it instead ([floorIn]).
  final (double, double, double?)? fitAt;
  bool through = false;

  /// The floor in [room] -- the width across less the margins: a
  /// `fit-content` one clamped into it (css-sizing-3 5.1:
  /// min(max-content, max(min-content, stretch-fit))), any other [minW].
  double? floorIn(double room) => switch (fitAt) {
    (final lo, final hi, final own) => math.max(own ?? 0.0, math.min(hi, math.max(lo, room))),
    null => minW,
  };
}

class _Flowed {
  _Flowed(this.boxes, this.height, this.firstTop, this.lastBottom, this.first, this.last);
  final List<_Box> boxes;
  final double height;
  final _Margins firstTop, lastBottom;
  final double? first, last;
}

/// One pass of the block algorithm over a flow and the flows it hosts.
class _Pass {
  _Pass(this.box, {this.baselines = false});

  final RenderFloatFlow box;

  /// Whether the root's children report where their text sits: a dry
  /// baseline is a text layout, and a pass that never reads one should not
  /// pay for it.
  final bool baselines;

  // ------------------------------------------------------------ the nodes

  _Node root([_Limits? limits]) {
    final n = _Node(_K.flow, box, null, flow: box, limits: limits);
    n.kids = kidsOf(box, baselines: baselines);
    return n;
  }

  /// A [FloatText], or a [FloatFlow] of THIS formatting context, under the
  /// widgets that frame it -- its padding, its decoration, its stated size
  /// -- is laid out by this pass: the paragraph's lines shorten beside this
  /// context's floats, and the flow's floats and clears are this context's
  /// (CSS 2.1 9.5). A child that is a context of its own, or a float, is a
  /// leaf, as is anything under a widget that moves or measures its child.
  static (RenderBox, EdgeInsets)? hostable(RenderBox child, FloatFlowParentData data, RenderFloatFlow host) {
    if (data.float != FloatSide.none || data.bfc) return null;
    var pad = EdgeInsets.zero;
    RenderBox? r = child;
    while (r != null) {
      if (r is RenderFloatText || (r is RenderFloatFlow && !identical(r, host))) return (r, pad);
      if (r is RenderPadding) {
        pad += r.padding.resolve(r.textDirection ?? TextDirection.ltr);
        r = r.child;
        continue;
      }
      // A box aligned to its start at its own size is where it was.
      if (r is RenderPositionedBox) {
        if ((r.heightFactor ?? 1) != 1 ||
            (r.widthFactor ?? 1) != 1 ||
            r.alignment.resolve(TextDirection.ltr) != Alignment.topLeft) {
          return null;
        }
        r = r.child;
        continue;
      }
      // A positioned box's containing block prints the boxes placed against
      // it round its own content: its first child that is not positioned.
      // Those placed under the flow come before it, in the order they paint
      // (CSS 2.1 Appendix E step 8: positioned boxes paint in tree order, so
      // labels ahead of a lifted flow in the tree paint under it), and the
      // stack lays its content out first wherever it stands
      // (`RenderStack._computeSize`), so the content is where the flow put
      // it either way. NEGATIVE: a stack of nothing but positioned boxes has
      // no content to host.
      if (r is RenderStack) {
        if ((r.fit != StackFit.loose && r.fit != StackFit.passthrough) ||
            r.alignment.resolve(TextDirection.ltr) != Alignment.topLeft) {
          return null;
        }
        var first = r.firstChild;
        while (first != null && (first.parentData! as StackParentData).isPositioned) {
          first = r.childAfter(first);
        }
        if (first == null) return null;
        r = first;
        continue;
      }
      // The widgets that change what is painted, or what is heard, and
      // nothing about where the child goes -- NAMED, not inferred -- and a
      // stated size, which is the size the pass was told.
      if (r is RenderConstrainedBox ||
          r is RenderFixedWidth ||
          r is RenderDecoratedBox ||
          r is RenderProxyBoxWithHitTestBehavior ||
          r is RenderRepaintBoundary ||
          r is RenderOpacity ||
          r is RenderTransform ||
          r is RenderFractionalTranslation ||
          r is RenderClipRect ||
          r is RenderClipRRect ||
          r is RenderClipPath ||
          r is RenderBackdropFilter ||
          r is RenderIgnorePointer ||
          r is RenderPointerListener ||
          r is RenderSemanticsAnnotations ||
          r is RenderExcludeSemantics ||
          r is RenderMetaData ||
          (r is RenderCustomPaint && r.child != null)) {
        r = (r as RenderProxyBox).child;
        continue;
      }
      return null;
    }
    return null;
  }

  /// One node per child of [flow]; the floats on a paragraph's lines go to
  /// that paragraph, each to the next place it holds.
  static List<_Node> kidsOf(RenderFloatFlow flow, {bool baselines = false}) {
    final out = <_Node>[];
    final places = <_Node>[];
    for (var child = flow.firstChild; child != null;) {
      final d = child.parentData! as FloatFlowParentData;
      final hosted = hostable(child, d, flow);
      if (hosted == null) {
        if (d.onLine && places.isNotEmpty) {
          final leaf = _Node(_K.leaf, child, d)..inLine = true;
          places.removeAt(0).onLine.add(leaf);
        } else {
          out.add(_Node(_K.leaf, child, d, reportsBaseline: baselines));
        }
      } else {
        final (target, pad) = hosted;
        if (target is RenderFloatText) {
          final n = _Node(_K.text, child, d, text: target, pad: pad);
          for (var i = 0; i < target._anchors.length; i++) {
            places.add(n);
          }
          out.add(n);
        } else {
          final inner = target as RenderFloatFlow;
          final n = _Node(_K.flow, child, d, flow: inner, pad: pad);
          n.kids = kidsOf(inner);
          out.add(n);
        }
      }
      child = d.nextSibling;
    }
    return out;
  }

  // -------------------------------------------------------------- dispatch

  /// [n] laid out for [i] (the engine's `compute_child_layout`), in [ctx]
  /// where it is a block of its parent's formatting context.
  _Res lay(_Node n, _In i, _Ctx? ctx) {
    switch (n.kind) {
      case _K.leaf:
        return leaf(n, i, (kw, kh, aw, ah) => measure(n, kw, kh, aw));
      case _K.flow:
        // A box with nothing in it is a leaf of no size.
        if (n.kids.isEmpty) return leaf(n, i, (kw, kh, aw, ah) => Size.zero, heldWidth: false);
        return block(n, i, ctx);
      case _K.text:
        return inline(n, i, ctx);
    }
  }

  // ------------------------------------------------------------- a leaf

  /// A leaf's box (Taffy `compute_leaf_layout`): the box model round what
  /// [measureContent] says of its content box.
  _Res leaf(
    _Node n,
    _In i,
    Size Function(double? kw, double? kh, _Space aw, _Space ah) measureContent, {
    bool heldWidth = true,
  }) {
    final pw = i.pw, ph = i.ph;
    final ml = n.mLeft(pw) ?? 0.0, mr = n.mRight(pw) ?? 0.0;
    final mt = n.mTop(pw) ?? 0.0, mb = n.mBottom(pw) ?? 0.0;
    final pb = n.padding;
    final adj = n.contentBox ? pb : EdgeInsets.zero;
    final styleW = i.bare ? null : _plus(n.width(pw), adj.horizontal), styleH = _plus(n.height(ph), adj.vertical);
    final minW = i.bare ? null : _plus(n.minW(pw), adj.horizontal),
        maxW = i.bare ? null : _plus(n.maxW(pw), adj.horizontal);
    final minH = _plus(n.minH(ph), adj.vertical), maxH = _plus(n.maxH(ph), adj.vertical);
    final nodeW = i.kw ?? styleW, nodeH = i.kh ?? styleH;
    final preventing = pb.top > 0 || pb.bottom > 0 || (nodeH != null && nodeH > 0) || (minH != null && minH > 0);
    if (i.size && preventing && nodeW != null && nodeH != null) {
      return _Res(Size(_fmax(_clamp(nodeW, minW, maxW), pb.horizontal), _fmax(_clamp(nodeH, minH, maxH), pb.vertical)));
    }
    var aw = (i.kw != null ? _Space.definite(i.kw!) : i.aw).sub(ml + mr);
    if (nodeW != null) aw = _Space.definite(nodeW);
    aw = aw.map((s) => _clamp(s, minW, maxW) - pb.horizontal);
    var ah = (i.kh != null ? _Space.definite(i.kh!) : i.ah).sub(mt + mb);
    if (nodeH != null) ah = _Space.definite(nodeH);
    ah = ah.map((s) => _clamp(s, minH, maxH) - pb.vertical);
    final ownW = i.kw ?? _clampN(styleW, minW, maxW);
    final told = i.size || (ownW != null && (i.kw == null || heldWidth));
    final measured = measureContent(
      told && ownW != null ? _fmax(0.0, ownW - pb.horizontal) : null,
      told && i.size && i.kh != null ? _fmax(0.0, i.kh! - pb.vertical) : null,
      aw,
      ah,
    );
    final w = _clamp(i.kw ?? styleW ?? measured.width + pb.horizontal, minW, maxW);
    final h = _clamp(i.kh ?? styleH ?? measured.height + pb.vertical, minH, maxH);
    final size = Size(_fmax(w, pb.horizontal), _fmax(h, pb.vertical));
    double? first;
    if (baselines && n.reportsBaseline) {
      first = dryBaselineOf(n.child, BoxConstraints.tight(size), TextBaseline.alphabetic);
    }
    return _Res(size, through: !preventing && size.height == 0 && measured.height == 0, first: first);
  }

  /// A Flutter child answering what the pass asks of its content box: the
  /// child paints its own [FloatSlot.frame], so the question goes out with
  /// the frame added and the answer comes back with it taken off.
  Size measure(_Node n, double? kw, double? kh, _Space aw) {
    final floated = n.inLine || n.floated;
    final frame = n.data?.frame ?? EdgeInsets.zero;
    if (frame == EdgeInsets.zero) return ask(n.child, kw, kh, aw, floated: floated);
    final fx = frame.horizontal, fy = frame.vertical;
    final outer = ask(
      n.child,
      kw == null ? null : kw + fx,
      kh == null ? null : kh + fy,
      aw.map((v) => v + fx),
      floated: floated,
    );
    return Size(math.max(0.0, outer.width - fx), math.max(0.0, outer.height - fy));
  }

  /// A Flutter child's size, asked the way the engine asks it: every
  /// question is one Flutter already knows how to answer.
  static Size ask(RenderBox child, double? kw, double? kh, _Space aw, {required bool floated}) {
    if (kw != null && kh != null) return Size(kw, kh);
    return guardedSize(child, () => _asked(child, kw, kh, aw, floated: floated));
  }

  static Size _asked(RenderBox child, double? kw, double? kh, _Space aw, {required bool floated}) {
    final at = kh ?? double.infinity;
    final double width;
    if (kw != null) {
      width = kw;
    } else if (aw.kind == 1) {
      width = child.getMinIntrinsicWidth(at);
    } else if (aw.kind == 2) {
      width = child.getMaxIntrinsicWidth(at);
    } else if (floated && kh == null) {
      // A FLOAT's auto width is shrink-to-fit (CSS 2.1 10.3.5):
      // min(max(min-content, room), max-content), whatever its content
      // would do with the room.
      width = math.max(
        child.getMinIntrinsicWidth(at),
        math.min(math.max(0.0, aw.value), child.getMaxIntrinsicWidth(at)),
      );
    } else {
      final v = math.max(0.0, aw.value);
      width = math.max(
        child.getMinIntrinsicWidth(at),
        child
            .getDryLayout(
              kh != null ? BoxConstraints(maxWidth: v, minHeight: at, maxHeight: at) : BoxConstraints(maxWidth: v),
            )
            .width,
      );
    }
    // A height at a width the box is HELD to is a dry layout, not an
    // intrinsic: a box offered a width may take less of it, and a box held
    // to it may not.
    final held = kh == null && kw != null ? child.getDryLayout(BoxConstraints.tightFor(width: width)).height : null;
    return Size(width, kh ?? (held != null && held.isFinite ? held : child.getMaxIntrinsicHeight(width)));
  }

  // -------------------------------------------------------------- a block

  /// A block container (Taffy `compute_block_layout`): its own sizes, then
  /// its children in its parent's formatting context [ctx], or in a new one.
  _Res block(_Node n, _In i, _Ctx? ctx) {
    final pb = n.padding;
    final adj = n.contentBox ? pb : EdgeInsets.zero;
    final pw = i.pw, ph = i.ph;
    final minW = i.bare ? null : _plus(n.minW(pw), adj.horizontal),
        maxW = i.bare ? null : _plus(n.maxW(pw), adj.horizontal);
    final minH = _plus(n.minH(ph), adj.vertical), maxH = _plus(n.maxH(ph), adj.vertical);
    final sw = i.bare ? null : _clampN(_plus(n.width(pw), adj.horizontal), minW, maxW);
    final sh = _clampN(_plus(n.height(ph), adj.vertical), minH, maxH);
    // With both a floor and a cap and the cap under the floor, the floor is
    // the size.
    final mmW = minW != null && maxW != null && maxW <= minW ? minW : null;
    final mmH = minH != null && maxH != null && maxH <= minH ? minH : null;
    final kw0 = i.kw ?? mmW ?? sw, kh0 = i.kh ?? mmH ?? sh;
    final kw = kw0 == null ? null : _fmax(kw0, pb.horizontal);
    final kh = kh0 == null ? null : _fmax(kh0, pb.vertical);
    if (i.size) {
      if (kw != null && kh != null) return _Res(Size(kw, kh));
      if (i.widthOnly && kw != null) return _Res(Size(kw, 0.0));
    }
    return inner(n, i.known(kw, kh), ctx ?? _Ctx.root());
  }

  /// Taffy `compute_inner`.
  _Res inner(_Node n, _In i, _Ctx ctx) {
    final pb = n.padding;
    ctx.applyContentInset([pb.left, pb.right]);
    final adj = n.contentBox ? pb : EdgeInsets.zero;
    final pw = i.pw, ph = i.ph;
    final sizeH = _plus(n.height(ph), adj.vertical);
    final minW = i.bare ? null : _plus(n.minW(pw), adj.horizontal),
        maxW = i.bare ? null : _plus(n.maxW(pw), adj.horizontal);
    final minH = _plus(n.minH(ph), adj.vertical), maxH = _plus(n.maxH(ph), adj.vertical);
    final kw = i.kw, kh = i.kh;
    final innerW0 = kw == null ? null : kw - pb.horizontal;
    final innerH0 = kh == null ? null : kh - pb.vertical;
    final own0 = i.c0 && pb.top == 0.0;
    final own1 = i.c1 && pb.bottom == 0.0 && sizeH == null;
    final preventing =
        ctx.isRoot || pb.top > 0.0 || pb.bottom > 0.0 || (sizeH != null && sizeH > 0.0) || (minH != null && minH > 0.0);
    var items = itemsOf(n, innerW0, innerH0);
    final pctH = kh ?? (sizeH == null ? null : (minH == null ? sizeH : _fmax(sizeH, minH)));
    final double outerW;
    if (kw != null) {
      outerW = kw;
    } else {
      final availW = i.aw.sub(pb.horizontal);
      final pctIn = pctH == null ? null : pctH - pb.vertical;
      double under(_Space s) => contentWidth(items, s, pctIn);
      // css-sizing-3 5.2.2: a shrink-to-fit width is min(max-content,
      // max(min-content, available)).
      final double innerW;
      if (availW.isDefinite) {
        final maxc = under(_Space.maxContent);
        innerW = maxc <= availW.value ? maxc : _fmax(under(_Space.minContent), availW.value);
      } else {
        innerW = under(availW);
      }
      outerW = _fmax(_clamp(innerW + pb.horizontal, minW, maxW), pb.horizontal);
    }
    if (i.size && kh != null) return _Res(Size(outerW, kh));
    if (i.size && i.widthOnly) return _Res(Size(outerW, 0.0));
    // ONCE A SHRINK-TO-FIT WIDTH IS SOLVED IT IS THE CONTAINING BLOCK: the
    // shares refused while it was being solved resolve against it now.
    if (innerW0 == null) items = itemsOf(n, _fmax(outerW - pb.horizontal, 0.0), innerH0);
    final f = inFlow(items, outerW, pctH, pb, own0, own1, ctx, i.size);
    var contentH = f.height;
    // Root contexts contain floats (CSS 2.1 10.6.7): the box ends at the
    // bottom edge of the lowest float, and its own padding goes on after
    // that. A root that is one box of a page, and starts no context there,
    // does not ([FloatFlow.floatsOut]).
    if (ctx.isRoot && !(identical(n.child, box) && box.floatsOut)) {
      contentH = _fmax(contentH, ctx.floatContribution + pb.bottom);
    }
    final outerH = _fmax(_fmax(0.0, kh ?? _clamp(contentH, minH, maxH)), pb.vertical);
    // The bottom margin of an auto-height block collapses with its last
    // child's only where `min-height` did not decide its height (8.3.1).
    final byMin = minH != null && minH > 0.0 && minH >= outerH;
    final bottomCollapses = own1 && !byMin;
    final through = !preventing && items.every((it) => it.node.floated || it.through);
    return _Res(
      Size(outerW, outerH),
      top: own0 ? f.firstTop : _Margins.of(n.mTop(pw) ?? 0.0),
      bottom: bottomCollapses ? f.lastBottom : _Margins.of(n.mBottom(pw) ?? 0.0),
      through: through,
      first: f.first,
      last: f.last,
      noLast: f.last == null && f.first != null,
      boxes: f.boxes,
    );
  }

  /// Taffy `generate_item_list`: each child's own sizes against the content
  /// box [w] x [h], a share of what is not known yet unresolved.
  List<_Item> itemsOf(_Node n, double? w, double? h) {
    final out = <_Item>[];
    for (final k in n.kids) {
      final adj = k.contentBox ? k.padding : EdgeInsets.zero;
      var minW = _plus(k.minW(w), adj.horizontal);
      final own = minW;
      (double, double)? fit;
      (double, double, double?)? fitAt;
      // A KEYWORD FLOOR IS THE CONTENT'S border-box width, whatever the
      // box's own `width` says -- measured with that set aside ([_In.bare]):
      // a `<fieldset>` at `width: 100px` round words wider than that is as
      // wide as they are. `fit-content` is the content clamped into the
      // room less the margins (css-sizing-3 5.1: min(max-content,
      // max(min-content, stretch-fit))); asked before the room is known it
      // waits for it ([_Item.fit]).
      if (k.minKeyword case final kw? when kw != FloatWidth.stretch) {
        double content(_Space at) => lay(
          k,
          _In(size: true, widthOnly: true, bare: true, pw: w, ph: h, aw: at, ah: _Space.maxContent, c0: true, c1: true),
          null,
        ).size.width;
        final lo = kw == FloatWidth.maxContent ? null : content(_Space.minContent);
        final hi = kw == FloatWidth.minContent ? null : content(_Space.maxContent);
        if (kw != FloatWidth.fitContent) {
          minW = math.max(minW ?? 0, lo ?? hi!);
        } else if (w == null) {
          fit = (lo!, hi!);
        } else {
          final room = w - (k.mLeft(w) ?? 0.0) - (k.mRight(w) ?? 0.0);
          minW = math.max(minW ?? 0, math.min(hi!, math.max(lo!, room)));
          fitAt = (lo, hi, own);
        }
      }
      out.add(
        _Item(
          k,
          _plus(k.width(w), adj.horizontal),
          _plus(k.height(h), adj.vertical),
          minW,
          _plus(k.maxW(w), adj.horizontal),
          _plus(k.minH(h), adj.vertical),
          _plus(k.maxH(h), adj.vertical),
          fit: fit,
          fitAt: fitAt,
        ),
      );
    }
    return out;
  }

  /// The width a block's children come to in [aw] (Taffy
  /// `determine_content_based_container_width`).
  double contentWidth(List<_Item> items, _Space aw, double? pctH) {
    var widest = 0.0;
    final floats = _FloatWidths(aw);
    for (final it in items) {
      final n = it.node;
      final kw = _clampN(it.w, it.minW, it.maxW);
      final kh = _clampN(it.h, it.minH, it.maxH);
      // The container's width depends on this, so a share of margin is
      // cyclic and resolves against nothing (css-sizing-3 5.2.1).
      final xm = (n.mLeft(null) ?? 0.0) + (n.mRight(null) ?? 0.0);
      double width;
      if (kw != null) {
        width = kw;
      } else {
        final space = switch (n.keyword) {
          FloatWidth.minContent => _Space.minContent,
          FloatWidth.maxContent => _Space.maxContent,
          _ => aw.sub(xm),
        };
        width = lay(
          n,
          _In(size: true, widthOnly: true, kh: kh, ph: pctH, aw: space, ah: _Space.minContent, c0: true, c1: true),
          null,
        ).size.width;
      }
      // The keyword floor holds whatever the question: a `max-content`
      // floor is the item's contribution at min-content too.
      if (kw == null && n.minKeyword != null && it.minW != null) width = _fmax(width, it.minW!);
      if (it.fit case (final lo, final hi)) {
        final room = aw.sub(xm);
        width = _fmax(width, room.isDefinite ? math.min(hi, math.max(lo, room.value)) : (room.isMin ? lo : hi));
      }
      final outer = _fmax(width, n.padding.horizontal) + xm;
      if (n.floated) {
        floats.addFloat(outer, _sideOf(n.side), n.clear);
        continue;
      }
      widest = _fmax(widest, outer);
      floats.addInFlow(outer, newFc: !n.sameBfc, clear: n.clear);
    }
    return _fmax(widest, floats.result);
  }

  /// The children's boxes, down the page (Taffy
  /// `perform_final_layout_on_in_flow_children`).
  _Flowed inFlow(
    List<_Item> items,
    double outerW,
    double? pctHIn,
    EdgeInsets pb,
    bool own0,
    bool own1,
    _Ctx ctx,
    bool sizeRun,
  ) {
    final innerW = _fmax(outerW - pb.horizontal, 0.0);
    final pctH = pctHIn == null ? null : pctHIn - pb.vertical;
    if (ctx.isRoot) {
      ctx.room.width = outerW;
      ctx.applyContentInset([pb.left, pb.right]);
    }
    // A block whose top margin does not collapse with its children's has
    // its own strut: floats adjoining an ancestor's do not adjoin it.
    if (!own0) ctx.commitStrut();
    final boxes = <_Box>[];
    var committed = pb.top;
    var yForAbs = pb.top;
    var firstTop = _Margins.zero;
    var active = _Margins.zero;
    var collapsingWithFirst = true;
    double? first, last;
    var activeHasClearance = false;
    var hasActiveFloats = ctx.hasActiveFloats(committed);

    for (final it in items) {
      final n = it.node;
      final mlA = n.mLeft(innerW), mrA = n.mRight(innerW);
      final mt = n.mTop(innerW) ?? 0.0, mb = n.mBottom(innerW) ?? 0.0;
      final ml = mlA ?? 0.0, mr = mrA ?? 0.0;
      final xm = ml + mr;

      if (n.floated) {
        hasActiveFloats = true;
        // A `width: auto` float is shrink-to-fit sized in the room there is.
        final room = _fmax(innerW - xm, 0.0);
        double? fkw;
        var faw = _Space.definite(room);
        switch (n.keyword) {
          case FloatWidth.minContent:
            faw = _Space.minContent;
          case FloatWidth.maxContent:
            faw = _Space.maxContent;
          case FloatWidth.stretch:
            fkw = room;
          case FloatWidth.fitContent || null:
            break;
        }
        final r = lay(n, _In(kw: fkw, pw: innerW, ph: pctH, aw: faw, ah: _Space.maxContent), null);
        final marginBox = Size(r.size.width + xm, r.size.height + mt + mb);
        // A float between collapsing margins stands as if it had an
        // otherwise empty block round it in the flow: the margins pending
        // so far are over it, unless they collapse with the container's own
        // and apply outside it -- then its place is not settled yet, and a
        // cleared box whose margin adjoins the same strut is cleared past it
        // whatever.
        final adjoins = collapsingWithFirst && own0;
        final y = adjoins ? committed : committed + active.resolve;
        final placed = ctx.placeFloat(marginBox, y, _sideOf(n.side), n.clear, adjoins);
        boxes.add(_Box(n, r.size, Offset(placed.dx + ml, placed.dy + mt), r));
        continue;
      }

      var yMarginOffset = 0.0;
      var avoids = false;
      var pushedBelow = false;
      double measureAs(_Space s) => lay(
        n,
        _In(size: true, widthOnly: true, pw: innerW, ph: pctH, aw: s, ah: _Space.maxContent, c0: true, c1: true),
        null,
      ).size.width;
      // A min- or max-content width is the content's whatever the room, so
      // it -- not the room beside a float -- decides where the box fits.
      final double? contentW = switch (n.keyword) {
        FloatWidth.minContent => measureAs(_Space.minContent),
        FloatWidth.maxContent => measureAs(_Space.maxContent),
        _ => null,
      };
      final double stretchWidth;
      var fx = 0.0, fy = 0.0;
      if (n.sameBfc) {
        stretchWidth = _fmax(innerW - xm, 0.0);
      } else {
        if (!collapsingWithFirst || !own0) yMarginOffset = active.withMargin(mt).resolve;
        final minY = committed + yMarginOffset;
        if (hasActiveFloats || ctx.hasActiveFloats(minY)) {
          // An auto width comes to at least the margins' negation (a margin
          // box of no less than nothing, CSS 2.1 10.3.3).
          final minAuto = -xm;
          int? seg;
          _BfcSlot slot;
          // A `fit-content` FLOOR IS CLAMPED INTO THE ROOM BESIDE THE FLOATS
          // it is tried in, as a `fit-content` width is: the stretch-fit
          // size is the room the box is offered there, less its margins
          // (css-sizing-3 5.1, CSS 2.1 9.5), so the floor is the box's
          // min-content at the least, and it fits wherever that does.
          // Clamped into the block's room instead, a floor of words wider
          // than the room beside a float does not fit there and takes the
          // box down past the float, where it breaks its words beside it.
          // `fixtures/fieldset-in-float-flow` n6: a `<fieldset>` of `width:
          // 90px; min-width: fit-content` round 107px of words beside a
          // float in a 220px column, one line 127.41 wide beside it.
          while (true) {
            slot = ctx.bfcSlot(minY, [ml, mr], n.clear, seg);
            final s = slot.segment;
            if (s == null) break;
            final auto = _fmax(_fmax(slot.stretchWidth, minAuto), 0.0);
            final w = _clamp(it.w ?? contentW ?? auto, it.floorIn(auto), it.maxW);
            if (w <= slot.borderWidth + _fitTolerance) break;
            seg = s;
          }
          // Moving down past a float separates the box from it: like
          // clearance, its top margin no longer collapses with its parent's.
          if (slot.y > minY) pushedBelow = true;
          hasActiveFloats = slot.segment != null;
          avoids = true;
          stretchWidth = _fmax(_fmax(slot.stretchWidth, minAuto), 0.0);
          fx = slot.x;
          fy = slot.y;
        } else {
          stretchWidth = _fmax(innerW - xm, 0.0);
          fx = pb.left;
          fy = minY;
        }
      }

      // The width: stated, a keyword, or the stretch.
      final double? keywordW = switch (n.keyword) {
        FloatWidth.stretch => stretchWidth,
        FloatWidth.fitContent => measureAs(_Space.definite(stretchWidth)),
        FloatWidth.minContent || FloatWidth.maxContent => contentW,
        null => null,
      };
      final kw = _clamp(it.w ?? keywordW ?? stretchWidth, it.floorIn(stretchWidth), it.maxW);
      final kh = _clampN(it.h, it.minH, it.maxH);
      final childIn = _In(
        size: sizeRun,
        kw: kw,
        kh: kh,
        pw: innerW,
        ph: pctH,
        aw: _Space.definite(stretchWidth),
        ah: _Space.maxContent,
        c0: n.sameBfc,
        c1: n.sameBfc,
      );

      final clearThreshold = ctx.clearedThreshold(n.clear);
      final clearPos = clearThreshold ?? double.negativeInfinity;

      final _Res r;
      if (n.sameBfc) {
        // An auto margin takes its share of the room the width leaves, and
        // the box's lines shorten beside the floats where it STANDS.
        final autoAcross = (mlA == null ? 1 : 0) + (mrA == null ? 1 : 0);
        final autoLeft = mlA ?? (autoAcross > 0 ? _fmax(0.0, stretchWidth - kw) / autoAcross : 0.0);
        final insetLeft = autoLeft + pb.left;
        final insetRight = outerW - kw - insetLeft;
        // THE BOX'S FLOATS AND LINES STAND WHERE ITS BORDER BOX DOES. A top
        // margin that collapses through the container's own top (CSS 2.1
        // 8.3.1) goes above the container with every margin pending before
        // it, and the box's border edge is the container's content edge,
        // here: its lines are set beside the floats from there. Counted
        // from its margin's foot, they were set that much lower against the
        // floats than the box is drawn -- a bank's contact form, a note of
        // `margin-top: 12px` after an empty block whose floats fill the
        // first 34px, broke its line at 22 where Chrome breaks it at 34
        // (`fixtures/fieldset-floats-contained` n1).
        final atBorder = collapsingWithFirst && own0 ? committed : yForAbs + mt;
        final childCtx = ctx.sub(_fmax(atBorder, clearPos), [insetLeft, insetRight]);
        r = lay(n, childIn, childCtx);
        ctx.addChildContribution(yForAbs + childCtx.floatContribution);
        ctx.mergeAdjoining(childCtx.topAdjoining);
      } else {
        r = lay(n, childIn, null);
      }
      final size = r.size;
      final topSet = r.top.withMargin(mt);
      final bottomSet = r.bottom.withMargin(mb);
      // Auto margins fill the free room across; down the page they are
      // nothing (CSS 2.1 10.6.3).
      final freeX = _fmax(0.0, stretchWidth - size.width);
      final autoCount = (mlA == null ? 1 : 0) + (mrA == null ? 1 : 0);
      final xAuto = autoCount > 0 ? freeX / autoCount : 0.0;
      final left = mlA ?? xAuto;

      if (n.sameBfc && (!collapsingWithFirst || !own0)) yMarginOffset = active.withSet(topSet).resolve;
      // CLEARANCE (CSS 2.1 9.5.2): where the top border edge's position
      // with the margins collapsed would not be past the floats it clears,
      // the edge goes at their bottom.
      var hasClearance = false;
      if (n.sameBfc && clearThreshold != null) {
        final hypothetical = committed + active.withSet(topSet).resolve;
        final forced = ctx.hasAdjoiningFloat(n.clear);
        if (forced || hypothetical < clearThreshold) {
          hasClearance = true;
          final escaped = collapsingWithFirst && own0 ? active.resolve : 0.0;
          yMarginOffset = clearThreshold - committed - escaped;
        }
      }
      // A CONTEXT OF ITS OWN IS NEVER COLLAPSED THROUGH: the margins of a
      // box that starts a block formatting context do not adjoin each other
      // (CSS 2.1 8.3.1), so an empty one is a box at its place, and the
      // flow goes on below it. The clearfix's `::after { display: table;
      // clear: both }` is one: below the floats it clears, it is where the
      // block round it ends. Collapsed through, a byline header whose
      // avatar floats in a flow of floats (its float the outer context's)
      // ended at its line, 24 tall, not at the float's 80
      // (`fixtures/clearfix-float-pulled-out` b1); and its `::before` let
      // the first child's top margin collapse through the box, which the
      // clearfix is there to stop.
      it.through = r.through && !hasClearance && n.sameBfc;
      final Offset location;
      if (n.sameBfc) {
        location = Offset(pb.left + left, committed + yMarginOffset);
      } else {
        // Avoiding the floats, the box's own margins are in the slot's edge
        // already: only what `auto` adds is added.
        location = Offset(fx + (avoids ? left - ml : left), fy);
      }
      if (first == null && r.first != null) first = location.dy + r.first!;
      final childLast = r.last ?? (r.noLast ? null : r.first);
      if (childLast != null) last = location.dy + childLast;
      boxes.add(_Box(n, size, location, r));
      // The floats on a paragraph's lines stand in the paragraph's box.
      final laid = r.lines;
      if (laid != null) {
        for (final f in laid.floats) {
          boxes.add(_Box(f.node, f.size, location + f.offset));
        }
      }

      if (collapsingWithFirst && pushedBelow) collapsingWithFirst = false;
      if (collapsingWithFirst && hasClearance) {
        collapsingWithFirst = false;
      } else if (collapsingWithFirst) {
        if (it.through) {
          firstTop = firstTop.withSet(topSet).withSet(bottomSet);
        } else {
          firstTop = firstTop.withSet(topSet);
          collapsingWithFirst = false;
        }
      }

      if (it.through) {
        active = active.withSet(topSet).withSet(bottomSet);
        yForAbs = committed + size.height + yMarginOffset;
      } else {
        committed = location.dy + size.height;
        // A box of nothing with clearance is not collapsed through, but its
        // margins still collapse with each other and with what follows: its
        // border edge sits its top margin inside the collapsed one.
        if (hasClearance && r.through) {
          committed -= topSet.resolve;
          active = topSet.withSet(bottomSet);
          activeHasClearance = true;
        } else {
          active = bottomSet;
          activeHasClearance = false;
        }
        yForAbs = committed + active.resolve;
        ctx.commitStrut();
      }
    }

    // The margins of a box of nothing with clearance do not collapse with
    // the parent's bottom margin: they stay inside it.
    final lastBottom = activeHasClearance ? _Margins.zero : active;
    final bottomOffset = activeHasClearance ? active.resolve : (own1 ? 0.0 : lastBottom.resolve);
    committed += pb.bottom + bottomOffset;
    return _Flowed(boxes, _fmax(0.0, committed), firstTop, lastBottom, first, last);
  }

  // ---------------------------------------------------------- a paragraph

  /// A paragraph (the engine's inline formatting context, over Flutter's
  /// line breaking): a leaf whose content is its lines, set beside the
  /// floats of [ctx].
  _Res inline(_Node n, _In i, _Ctx? ctx) {
    final t = n.text!;
    final onLine = n.onLine.length <= t._anchors.length ? n.onLine : n.onLine.sublist(0, t._anchors.length);
    if (!t._hasWords && onLine.isEmpty) return leaf(n, i, (kw, kh, aw, ah) => Size.zero);
    final pb = n.padding;
    _Laid? laid;
    final out = leaf(n, i, (kw, kh, aw, ah) {
      final w = kw ?? aw.option;
      final maxW = aw.isMin && kw == null ? 0.0 : w;
      // Lines beside floats need a definite width and a context: the
      // parent's, where earlier siblings' floats intrude too, or a private
      // one for the paragraph's own.
      _Ctx? host;
      var own = false;
      if (w != null && maxW != null && maxW > 0 && (ctx != null || onLine.isNotEmpty)) {
        if (ctx != null) {
          host = ctx;
        } else {
          host = _Ctx.root();
          host.room.width = w + pb.horizontal;
          own = true;
        }
        host.applyContentInset([pb.left, pb.right]);
      }
      final l = t._layLines(host == null ? null : this, host, maxW, w, pb, host == null ? const [] : onLine);
      var width = l.width;
      if (host == null && onLine.isNotEmpty) {
        // Measured for its intrinsic width, a float on the line is a word
        // of its own: alone on its line at min-content, beside the words
        // round it at max-content.
        final widths = [
          for (final f in onLine)
            lay(
                  f,
                  _In(
                    size: true,
                    widthOnly: true,
                    pw: w,
                    aw: maxW == 0 ? _Space.minContent : _Space.maxContent,
                    ah: _Space.maxContent,
                  ),
                  null,
                ).size.width +
                (f.mLeft(w) ?? 0.0) +
                (f.mRight(w) ?? 0.0),
        ];
        width = t._widthWithFloats(l, widths, minContent: maxW == 0);
      }
      // A shrink-to-fit width is the room itself once a line has broken
      // softly in it (css-sizing-3 5.2.2).
      if (kw == null && maxW != null && maxW > 0 && l.softWrapped) width = _fmax(width, maxW);
      var height = l.lines.isEmpty ? 0.0 : l.lines.last.y + l.lines.last.height - pb.top;
      // A context of its own grows to hold its floats (CSS 2.1 10.6.7).
      if (host != null && own) height = _fmax(height, host.floatContribution - pb.top);
      laid = l;
      return Size(width, height);
    });
    final l = laid;
    if (l == null) return out;
    return _Res(
      out.size,
      through: out.through,
      first: l.lines.isEmpty ? null : l.lines.first.y + l.lines.first.baseline,
      last: l.lines.isEmpty ? null : l.lines.last.y + l.lines.last.baseline,
      lines: l,
    );
  }
}

// ============================================================ paragraphs

/// A PARAGRAPH BESIDE A FLOAT. A float is out of flow for the blocks round
/// it and IN flow for their lines (CSS 2.1 9.5): the block keeps its width
/// and runs on under the float while each line box inside it shortens to
/// the room beside it, and runs full width again below. A `Text` is one
/// paragraph as wide as its box, and nothing shortens one line of it -- so
/// this paragraph is laid out by the [FloatFlow] it stands in, a line at a
/// time, each line broken and set by Flutter in the room its line has.
///
/// A line with no room for its first word beside a float moves down until
/// the word fits or the floats run out; a float met in the middle of a line
/// (U+FFFC holds its place, and the [FloatSlot.onLine] child after this one
/// is the float) stands on that line where the words before it leave it
/// room (CSS 2.1 9.5.1 rule 6), and at the top of the next line where not.
///
/// A line is [lineHeight] tall, unless something on it is taller. Stood
/// anywhere but in a [FloatFlow] it lays itself out the same way, with no
/// floats to shorten anything; a `Text` is the cheaper widget for that.
///
/// The spans are text: a [TextSpan] tree with styles, and nothing on the
/// line that is a widget of its own. A newline is a forced break (`<br>`),
/// and a line may break after a hyphen between letters, as the browser
/// breaks it.
///
/// A READER IS TOLD the words with each span's [TextSpan.semanticsLabel]
/// in that span's place, as [Text] tells them (`Dr.` read as `Doctor`).
/// The rest of what a [Text] tells of its spans is not told: a span's
/// spell-out, locale and [TextSpan.recognizer] actions.
///
/// UNDER `rtl` A LINE STARTS AT ITS RIGHT ([textDirection]): it is set in
/// the room its line has from the right, the words on it in the order
/// UAX #9 gives them, and a line wider than its room runs out of it to the
/// left. The browser resolves the PARAGRAPH's levels and reorders each
/// line (UAX #9 3.3, L1), where each line here is set, and resolved, on
/// its own: a neutral or a number at the line's edge takes its direction
/// from the paragraph's, not from the letter across the break. So where
/// that letter is of the other direction -- a Latin word in an `rtl` block
/// broken after `Hello,` -- the line is set between marks of its class
/// (U+200E, U+200F, U+061C; see `IndentedText`), and resolves as the whole
/// paragraph does. An explicit embedding, an isolate, or a number across
/// the break is not carried over.
///
/// The text scales for the reader as a [Text]'s does ([textScaler]), its
/// strut with it -- and only the text: a [WidgetSpan]'s widget is laid out
/// at its own size, unlike a [RichText]'s.
class FloatText extends MultiChildRenderObjectWidget {
  const FloatText(
    this.text, {
    super.key,
    this.style,
    this.lineHeight,
    this.ascent,
    this.textAlign = TextAlign.start,
    this.textDirection = TextDirection.ltr,
    this.softWrap = true,
    this.textScaler,
  });

  /// The paragraph's runs. A [WidgetSpan] among them is an atomic inline:
  /// a box of its own on the line, as tall and as wide as the widget is,
  /// standing on the baseline as its [PlaceholderSpan.alignment] says. An
  /// [OffsetSpan] is painted off its place on each line it is on, as
  /// `OffsetSpans` paints a paragraph's.
  final InlineSpan text;

  static final _widgets = Expando<List<Widget>>();

  /// The widgets on the lines, in the order they stand ([WidgetSpan]s).
  @override
  List<Widget> get children => _widgets[this] ??= WidgetSpan.extractFromInlineSpan(text, TextScaler.noScaling);

  /// The block's own font, merged over the ambient [DefaultTextStyle]: the
  /// strut every line stands on is made from it.
  final TextStyle? style;

  /// `line-height`, in logical pixels: the height of a line with nothing on
  /// it taller than the strut. Null is `normal`, the font's own.
  final double? lineHeight;

  /// How much of [lineHeight] the strut keeps ABOVE the baseline, as Blink
  /// splits it, as [LineBox.ascent] is. Null reads it off the face.
  ///
  /// WHERE THE FAMILY'S NAME DOES NOT SAY ITS FACE. Blink on macOS lifts the
  /// ascent of Times, Helvetica and Courier (see [RenderFloatText]), and it
  /// asks the face it drew, not the name a stylesheet gave it; this widget
  /// has only the name. A page's `sans-serif` that Chrome drew in Helvetica
  /// ships as a family named for the generic, and read off the face alone
  /// every line stood a pixel high. Told the strut's ascent, the lines stand
  /// on it -- and a run in the block's own family stands on the same face, so
  /// it is lifted, or not, as the strut is.
  final double? ascent;

  final TextAlign textAlign;

  /// The block's `direction`: which side its lines start on, which
  /// [TextAlign.start] and [TextAlign.end] are, and the paragraph's own
  /// direction for UAX #9.
  final TextDirection textDirection;

  /// `white-space: nowrap` where false.
  final bool softWrap;

  /// How the paragraph's TEXT is scaled for the reader (`MediaQuery`'s
  /// text scale, an accessibility setting); null is the ambient
  /// [MediaQuery.textScalerOf], as a [Text]'s is. [TextScaler.noScaling]
  /// keeps every length as written, as a layout of fixed pixel metrics
  /// needs.
  ///
  /// The glyphs of every run and the strut every line stands on --
  /// [lineHeight] and [ascent] with them -- scale together, so the lines
  /// grow with what they hold. ONLY TEXT SCALES: a [WidgetSpan]'s widget
  /// is laid out at its own size, and the text inside it scales once, by
  /// its own `Text` -- as CSS text zoom scales each font once and no box --
  /// where a [RichText] scales a [WidgetSpan]'s box as a whole, and the
  /// text in it a second time.
  final TextScaler? textScaler;

  @override
  RenderFloatText createRenderObject(BuildContext context) => RenderFloatText(
    text: text,
    style: DefaultTextStyle.of(context).style.merge(style),
    lineHeight: lineHeight,
    ascent: ascent,
    textAlign: textAlign,
    textDirection: textDirection,
    softWrap: softWrap,
    textScaler: textScaler ?? MediaQuery.textScalerOf(context),
  );

  @override
  void updateRenderObject(BuildContext context, RenderFloatText renderObject) {
    renderObject
      ..text = text
      ..style = DefaultTextStyle.of(context).style.merge(style)
      ..lineHeight = lineHeight
      ..ascent = ascent
      ..textAlign = textAlign
      ..textDirection = textDirection
      ..softWrap = softWrap
      ..textScaler = textScaler ?? MediaQuery.textScalerOf(context);
  }
}

/// One line of a [FloatText], as the pass set it.
class _Line {
  _Line(this.start, this.end, this.x, this.y, this.room, this.width, this.height, this.baseline, {this.soft = false});

  /// The code units of the paragraph's words it holds.
  final int start, end;

  /// Whether it ends where the text did not force it to and words follow:
  /// a line `text-align: justify` stretches to its room, where the last
  /// line and one a forced break ends are set at the start (css-text-3
  /// 7.1, `text-align-last: auto`).
  final bool soft;

  /// Its left edge and top in the paragraph's border box, and the room it
  /// was set in.
  final double x, y, room;

  /// Its words' width, its height, and where its baseline is under its top.
  final double width, height, baseline;
}

/// A float on a paragraph's line, where it went in the paragraph's box.
class _OnLine {
  _OnLine(this.node, this.size, this.offset);
  final _Node node;
  final Size size;
  final Offset offset;
}

/// A paragraph's lines, as one pass laid them out.
class _Laid {
  _Laid(this.lines, this.floats, this.width, this.softWrapped, [this.held = const [], this.room]);
  static final none = _Laid(const [], const [], 0.0, false);

  final List<_Line> lines;
  final List<_OnLine> floats;

  /// The widest line's words, and whether a line broke where the text did
  /// not force it to.
  final double width;
  final bool softWrapped;

  /// The widgets on the lines as they were measured, and the width they
  /// were offered (null: unbounded).
  final List<PlaceholderDimensions> held;
  final double? room;
}

/// Where a widget on a [FloatText]'s lines stands.
class _Held extends TextParentData {
  /// Its offset in the paragraph's box, and whether a line holds it.
  Offset at = Offset.zero;
  bool shown = false;
}

/// The render object behind [FloatText].
class RenderFloatText extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, TextParentData>, AsksGuarded, KeptUnderHatch {
  RenderFloatText({
    required InlineSpan text,
    required TextStyle style,
    double? lineHeight,
    double? ascent,
    TextAlign textAlign = TextAlign.start,
    TextDirection textDirection = TextDirection.ltr,
    bool softWrap = true,
    TextScaler textScaler = TextScaler.noScaling,
  }) : _textScaler = textScaler,
       _text = text,
       _style = style,
       _lineHeight = lineHeight,
       _ascent = ascent,
       _textAlign = textAlign,
       _textDirection = textDirection,
       _softWrap = softWrap {
    _read();
  }

  InlineSpan _text;
  set text(InlineSpan v) {
    if (identical(v, _text) || v == _text) return;
    _text = v;
    _read();
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  TextStyle _style;
  set style(TextStyle v) {
    if (v == _style) return;
    _style = v;
    _read();
    markNeedsLayout();
  }

  double? _lineHeight;
  set lineHeight(double? v) {
    if (v == _lineHeight) return;
    _lineHeight = v;
    _forgetExtents();
    markNeedsLayout();
  }

  double? _ascent;
  set ascent(double? v) {
    if (v == _ascent) return;
    _ascent = v;
    _forgetExtents();
    markNeedsLayout();
  }

  TextAlign _textAlign;
  set textAlign(TextAlign v) {
    if (v == _textAlign) return;
    _textAlign = v;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection v) {
    if (v == _textDirection) return;
    _textDirection = v;
    markNeedsLayout();
  }

  bool get _rtl => _textDirection == TextDirection.rtl;

  /// See [FloatText.textScaler].
  TextScaler get textScaler => _textScaler;
  TextScaler _textScaler;
  set textScaler(TextScaler v) {
    if (v == _textScaler) return;
    _textScaler = v;
    _forgetExtents();
    markNeedsLayout();
  }

  /// What the block's text is scaled by, as a factor of its own size: the
  /// strut's [_lineHeight] and [_ascent] are lengths and scale with it.
  double get _k {
    if (_textScaler == TextScaler.noScaling) return 1.0;
    final fs = _style.fontSize ?? 14.0;
    return fs <= 0 ? 1.0 : _textScaler.scale(fs) / fs;
  }

  /// [t] at the size its text is drawn: its own scaled by [_textScaler].
  TextStyle _drawn(TextStyle t) =>
      _textScaler == TextScaler.noScaling ? t : t.copyWith(fontSize: _textScaler.scale(t.fontSize ?? 14.0));

  bool _softWrap;
  set softWrap(bool v) {
    if (v == _softWrap) return;
    _softWrap = v;
    _read();
    markNeedsLayout();
  }

  /// The words, with the floats' places taken out and a break allowed after
  /// a hyphen between letters; and where each place was, in the words.
  late TextSpan _words;
  late String _plain;

  /// Where each [OffsetSpan] with an offset stands in the words, and its
  /// offset: each line paints its piece of one moved ([_paintLine]).
  List<(int, int, Offset)> _moved = const [];

  /// How many code units a painter's text has before the words it was cut
  /// to start: the mark that sets their direction ([_painter]).
  final _leads = Expando<int>();

  /// What a reader is told: the words as [_text] spells them, each span's
  /// [TextSpan.semanticsLabel] in that span's place, with no float's place
  /// (U+FFFC) nor break (U+200B) in them.
  late String _spoken;
  List<int> _anchors = const [];

  /// Where each widget on the lines stands in the words (its U+FFFC), and
  /// its span, in the order of the children.
  List<int> _holders = const [];
  List<PlaceholderSpan> _spans = const [];

  /// The widgets' sizes the painters are set with: those of the layout,
  /// or of the question, at hand.
  List<PlaceholderDimensions> _dims = const [];

  /// Whether the words are more than document white space (css-text-3
  /// 4.1: space, tab, line feed, carriage return, form feed): a no-break
  /// space is a letter and puts a line in the flow, where `String.trim`
  /// takes it away with the rest of Unicode's spaces.
  bool get _hasWords => _plain.codeUnits.any((u) => u != 0x20 && u != 0x09 && u != 0x0A && u != 0x0D && u != 0x0C);

  static final _hyphen = RegExp(r'(?<=[A-Za-z0-9]-)(?=[A-Za-z0-9])');

  void _read() {
    final anchors = <int>[];
    final holders = <int>[];
    final spans = <PlaceholderSpan>[];
    final runs = <({int start, int end, TextStyle style})>[];
    final ends = _ends = Expando<List<int>>();
    var at = 0;
    var spaced = false;
    final moved = <(int, int, Offset)>[];
    TextSpan strip(TextSpan s, TextStyle inherited) {
      final style = s.style == null ? inherited : inherited.merge(s.style);
      if (_spacing(style)) spaced = true;
      final from = at;
      String? text;
      final own = s.text;
      if (own != null) {
        final b = StringBuffer();
        final parts = own.split('￼');
        for (var i = 0; i < parts.length; i++) {
          if (i > 0) anchors.add(at);
          // Skia does not break after a hyphen; the browser does, between
          // letters (UAX #14 HY).
          final p = _softWrap ? parts[i].replaceAll(_hyphen, '​') : parts[i];
          b.write(p);
          if (p.isNotEmpty) runs.add((start: at, end: at + p.length, style: style));
          at += p.length;
        }
        text = b.toString();
      }
      InlineSpan held(PlaceholderSpan k) {
        if (k.style != null && _spacing(style.merge(k.style))) spaced = true;
        holders.add(at);
        spans.add(k);
        at += 1;
        return k;
      }

      final kids = <InlineSpan>[
        for (final k in s.children ?? const <InlineSpan>[])
          if (k is TextSpan) strip(k, style) else if (k is PlaceholderSpan) held(k),
      ];
      final out = TextSpan(text: text, style: s.style, children: kids.isEmpty ? null : kids);
      if (s is OffsetSpan && s.offset != Offset.zero && at > from) moved.add((from, at, s.offset));
      if (kids.isNotEmpty) {
        var end = text?.length ?? 0;
        ends[out] = [for (final k in kids) end += k is TextSpan ? (ends[k]?.last ?? k.text?.length ?? 0) : 1];
      }
      return out;
    }

    final root = _text;
    _words = root is TextSpan ? strip(root, _style) : const TextSpan(text: '');
    _moved = moved;
    _plain = _words.toPlainText(includeSemanticsLabels: false);
    _bidi = _plain.codeUnits.any(_bidiUnit);
    _embedded = _plain.codeUnits.any(_embeddingUnit);
    _spaced = spaced;
    _spoken = root is TextSpan
        ? root.toPlainText(includePlaceholders: false).replaceAll('\u200B', '').replaceAll('\uFFFC', '')
        : '';
    _anchors = anchors;
    _holders = holders;
    _spans = spans;
    _runs = runs;
    _forgetExtents();
  }

  /// The words' runs, each in the style its spans give it over the block's.
  List<({int start, int end, TextStyle style})> _runs = const [];

  /// For each span of [_words] that has children: where each child ends,
  /// counted in code units from the span's start, its own text first --
  /// what [_cut] finds the children of a range by.
  Expando<List<int>> _ends = Expando();

  /// Whether the words hold a right-to-left letter or a bidi control:
  /// their levels are resolved over the whole paragraph (UAX #9), and a
  /// line is read off a cut only where a letter past it settles them
  /// ([_lineEnd], [_leveled]).
  bool _bidi = false;

  /// Whether the words hold an embedding, an override or an isolate
  /// (UAX #9 X1-X8): what one opens is closed, or its direction found,
  /// anywhere after it, and a line is set from all the rest
  /// ([_lineEnd]).
  bool _embedded = false;

  static bool _embeddingUnit(int u) => (u >= 0x202A && u <= 0x202E) || (u >= 0x2066 && u <= 0x2069);

  /// Whether a letter spacing or a word spacing other than 0 is on any of
  /// the words or the widgets among them: Skia spaces the paragraph in one
  /// pass, and a line is set from all the rest of it ([_lineEnd]).
  bool _spaced = false;

  static bool _spacing(TextStyle s) => (s.letterSpacing ?? 0) != 0 || (s.wordSpacing ?? 0) != 0;

  static bool _bidiUnit(int u) =>
      (u >= 0x0590 && u <= 0x08FF) ||
      (u >= 0xFB1D && u <= 0xFDFF) ||
      (u >= 0xFE70 && u <= 0xFEFF) ||
      u == 0xD802 ||
      u == 0xD803 ||
      u == 0xD83A ||
      u == 0xD83B ||
      u == 0x061C ||
      u == 0x200E ||
      u == 0x200F ||
      (u >= 0x202A && u <= 0x202E) ||
      (u >= 0x2066 && u <= 0x2069);

  /// The first index of [sorted] whose value is past [x] (at least [x],
  /// with [orEqual]); its length where none is.
  static int _firstPast(List<int> sorted, int x, {bool orEqual = false}) {
    var lo = 0, hi = sorted.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (sorted[mid] > x || orEqual && sorted[mid] == x) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }

  /// The first of [_runs] that ends past [x].
  int _firstRunPast(int x) {
    var lo = 0, hi = _runs.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_runs[mid].end > x) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }

  RenderFloatFlow? _host;

  /// Whether a [FloatFlow] laid these lines out: this box's own layout
  /// would set them without the floats.
  bool _hosted = false;

  _Laid? _laid;
  EdgeInsets _shift = EdgeInsets.zero;

  /// The lines the flow that hosts this paragraph set, in the border box
  /// of its node, which starts [pad] outside this box.
  void _take(_Laid laid, EdgeInsets pad) {
    _hosted = true;
    _laid = laid;
    _shift = pad;
    markNeedsPaint();
  }

  @override
  void markNeedsLayout() {
    super.markNeedsLayout();
    final h = _host;
    if (h != null && !h._placing) h.markNeedsLayout();
  }

  // -------------------------------------------------------------- painters

  /// The words from code unit [from] to [to], their styles kept, and
  /// fullwidth punctuation that meets closed up as the browser sets it (see
  /// [han]).
  ///
  /// A child of a span that ends before [from], or starts at [to] or past
  /// it, holds nothing of the range, and is passed over by where it ends
  /// ([_ends]) without being read: a line costs its own words and the
  /// spans it is in, not the paragraph before and after it.
  TextSpan _cut(int from, int to) {
    TextSpan? walk(TextSpan s, int s0) {
      final own = s.text ?? '';
      final kids = <InlineSpan>[];
      if (own.isNotEmpty) {
        final a = math.max(from, s0), b = math.min(to, s0 + own.length);
        if (a < b) kids.add(han(own.substring(a - s0, b - s0)));
      }
      final children = s.children;
      final ends = _ends[s];
      if (children != null && ends != null) {
        // The first child that ends past [from]: a placeholder at [from]
        // ends one past it.
        var i = _firstPast(ends, from - s0);
        var at = s0 + (i == 0 ? own.length : ends[i - 1]);
        for (; i < children.length && at < to; i++) {
          final k = children[i];
          if (k is PlaceholderSpan) {
            if (at >= from) kids.add(k);
          } else if (k is TextSpan) {
            final c = walk(k, at);
            if (c != null) kids.add(c);
          }
          at = s0 + ends[i];
        }
      }
      if (kids.isEmpty) return null;
      return TextSpan(style: s.style, children: kids);
    }

    return walk(_words, 0) ?? const TextSpan(text: '');
  }

  /// The words from code unit [from] to [to], set in the paragraph's
  /// direction; [marked], a line drawn, between the marks that resolve it
  /// as the whole paragraph does (see [_markAt]).
  TextPainter _painter(int from, int to, {int? maxLines, TextAlign? align, bool marked = false}) {
    final before = marked ? _markAt(from, to, start: true) : null;
    final after = marked ? _markAt(from, to, start: false) : null;
    final tp = TextPainter(
      text: TextSpan(
        style: _style,
        children: [
          if (before != null) TextSpan(text: before),
          _cut(from, to),
          if (after != null) TextSpan(text: after),
        ],
      ),
      textAlign: align ?? _textAlign,
      textDirection: _textDirection,
      maxLines: maxLines,
      textScaler: _textScaler,
    );
    if (before != null) _leads[tp] = before.length;
    if (_holders.isNotEmpty) {
      // The widgets in the range, found by where the first is: the places
      // run in the words' order.
      final held = <PlaceholderDimensions>[];
      for (var i = _firstPast(_holders, from, orEqual: true); i < _holders.length && i < _dims.length; i++) {
        if (_holders[i] >= to) break;
        held.add(_dims[i]);
      }
      if (held.isNotEmpty) tp.setPlaceholderDimensions(held);
    }
    return tp;
  }

  /// The widgets on the lines as a line box holds them: laid out in
  /// [room], the paragraph's width (null: unbounded), their baselines
  /// where they have one -- or, for an intrinsic question, as wide as
  /// they are at min-content ([min]) or max-content ([max]).
  List<PlaceholderDimensions> _heldIn(double? room, {bool min = false, bool max = false}) {
    if (_spans.isEmpty) return const [];
    final out = <PlaceholderDimensions>[];
    var child = firstChild;
    for (final span in _spans) {
      if (child == null) break;
      final kid = child;
      if (min || max) {
        final w = guardedSize(
          kid,
          () => min ? kid.getMinIntrinsicWidth(double.infinity) : kid.getMaxIntrinsicWidth(double.infinity),
        );
        out.add(PlaceholderDimensions(size: Size(w, 0), alignment: span.alignment, baseline: span.baseline));
      } else {
        final c = BoxConstraints(maxWidth: room ?? double.infinity);
        final size = guardedSize(kid, () => kid.getDryLayout(c));
        final base = span.alignment == PlaceholderAlignment.baseline
            ? dryBaselineOf(child, c, span.baseline ?? TextBaseline.alphabetic)
            : null;
        out.add(
          PlaceholderDimensions(
            size: size,
            alignment: span.alignment,
            baseline: span.baseline,
            baselineOffset: base ?? size.height,
          ),
        );
      }
      child = childAfter(child);
    }
    return out;
  }

  /// The class UAX #9 gives the LETTER [c]: `L`, `R` or `AL` (an Arabic,
  /// Syriac or Thaana one); null for anything that is not a letter (as
  /// `IndentedText` reads it).
  static String? _strong(int c) {
    if (!_letter.hasMatch(String.fromCharCode(c))) return null;
    if ((c >= 0x0600 && c <= 0x07BF) ||
        (c >= 0x0860 && c <= 0x08FF) ||
        (c >= 0xFB50 && c <= 0xFDFF) ||
        (c >= 0xFE70 && c <= 0xFEFF) ||
        (c >= 0x1EE00 && c <= 0x1EEFF)) {
      return 'AL';
    }
    if ((c >= 0x0590 && c <= 0x05FF) ||
        (c >= 0x07C0 && c <= 0x085F) ||
        (c >= 0xFB1D && c <= 0xFB4F) ||
        (c >= 0x10800 && c <= 0x10FFF) ||
        (c >= 0x1E800 && c <= 0x1EDFF)) {
      return 'R';
    }
    return 'L';
  }

  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);

  /// The mark the line from code unit [from] to [to] of the words is set
  /// after ([start]: before), or null where none is needed. A neutral or a
  /// number at the line's start takes its direction from the last letter
  /// before it in the paragraph (UAX #9 W2, W7, N1), and one at its end
  /// from the first letter after it (N1); set alone, the line resolves
  /// them against the paragraph's direction instead (X10: `sos`, `eos`),
  /// which is that letter's only where the letter is of the paragraph's
  /// direction. Where it is not, a mark of its class stands for it.
  /// NEGATIVE: a line that starts (ends) on a letter has nothing at that
  /// edge to resolve, and is set as it is; nor does an Arabic letter after
  /// an `rtl` line, which counts as `R` there (W3).
  ///
  /// Read in place, from the line's edge outwards to the first letter,
  /// with no copy of the words before or after it.
  String? _markAt(int from, int to, {required bool start}) {
    if (to <= from) return null;
    if (_strong(start ? _runeAt(from, to) : _runeBefore(to, from)) != null) return null;
    String? letter;
    if (start) {
      for (var i = from; i > 0 && letter == null;) {
        final c = _runeBefore(i, 0);
        i -= c > 0xFFFF ? 2 : 1;
        letter = _strong(c);
      }
    } else {
      for (var i = to; i < _plain.length && letter == null;) {
        final c = _runeAt(i, _plain.length);
        i += c > 0xFFFF ? 2 : 1;
        letter = _strong(c);
      }
    }
    if (letter == null || letter == (_rtl ? 'R' : 'L') || letter == 'AL' && _rtl && !start) return null;
    return switch (letter) {
      'L' => '\u200E',
      'R' => '\u200F',
      _ => '\u061C',
    };
  }

  /// The character at code unit [i] of the words, read no further than
  /// [end]: a surrogate pair as its one character, a lone half as itself
  /// (as [String.runes] reads them).
  int _runeAt(int i, int end) {
    final u = _plain.codeUnitAt(i);
    if (u >= 0xD800 && u <= 0xDBFF && i + 1 < end) {
      final v = _plain.codeUnitAt(i + 1);
      if (v >= 0xDC00 && v <= 0xDFFF) return 0x10000 + ((u - 0xD800) << 10) + (v - 0xDC00);
    }
    return u;
  }

  /// The character that ends before code unit [i] of the words, read no
  /// further back than [begin] (see [_runeAt]).
  int _runeBefore(int i, int begin) {
    final v = _plain.codeUnitAt(i - 1);
    if (v >= 0xDC00 && v <= 0xDFFF && i - 2 >= begin) {
      final u = _plain.codeUnitAt(i - 2);
      if (u >= 0xD800 && u <= 0xDBFF) return 0x10000 + ((u - 0xD800) << 10) + (v - 0xDC00);
    }
    return v;
  }

  static bool _space(int c) => c == 0x20 || c == 0x09;
  static bool _forced(int c) => c == 0x0A || c == 0x2028 || c == 0x2029;

  static bool _cjk(int c) =>
      (c >= 0x2E80 && c <= 0x9FFF) ||
      (c >= 0xAC00 && c <= 0xD7AF) ||
      (c >= 0xF900 && c <= 0xFAFF) ||
      (c >= 0xFF00 && c <= 0xFFEF);

  int _unit(int i) => _plain.codeUnitAt(i);

  /// Whether a line may end before code unit [i] of the words.
  bool _breaksAt(int i) {
    if (i <= 0 || i >= _plain.length) return true;
    final a = _unit(i - 1), b = _unit(i);
    // AN ATOMIC INLINE HAS A BREAK BEFORE IT AND AFTER IT, even beside a
    // character that would keep them (css-text-3 5.1): a word and the box
    // that touches it part where the box does not fit.
    if (b == 0xFFFC) return true;
    return _space(a) ||
        _space(b) ||
        _forced(a) ||
        _forced(b) ||
        a == 0x200B ||
        a == 0x2D ||
        a == 0xFFFC ||
        _cjk(a) ||
        _cjk(b);
  }

  /// Where the unbroken run that starts at [from] ends.
  int _chunkEnd(int from) {
    var i = from;
    while (i < _plain.length && _space(_unit(i))) {
      i++;
    }
    if (i < _plain.length && !_forced(_unit(i))) i++;
    while (i < _plain.length && !_breaksAt(i)) {
      i++;
    }
    return i;
  }

  int _skipSpaces(int i) {
    var j = i;
    while (j < _plain.length && _space(_unit(j))) {
      j++;
    }
    return j;
  }

  double _widthOf(int from, int to) {
    if (to <= from) return 0.0;
    final tp = _painter(from, to)..layout();
    final w = tp.maxIntrinsicWidth;
    tp.dispose();
    return w;
  }

  /// The first line of the words from [from] in [room]: where its words
  /// end, where the spaces after them end (a float whose place is there
  /// stands on this line), where the next line's words begin, and whether
  /// the text forced the break.
  (int, int, int, bool) _lineFrom(int from, double room) {
    var brk = _lineEnd(from, room.isFinite ? math.max(0.0, room) : double.infinity);
    if (brk <= from) brk = math.min(_plain.length, from + 1);
    if (brk > _plain.length) brk = _plain.length;
    var end = brk;
    while (end > from && (_space(_unit(end - 1)) || _forced(_unit(end - 1)))) {
      end--;
    }
    // A word too wide for its line runs out of it whole (`overflow-wrap:
    // normal`), where Skia would break it anywhere.
    if (end < _plain.length && end > from && !_breaksAt(end)) {
      end = _chunkEnd(from);
      while (end < _plain.length && !_breaksAt(end)) {
        end++;
      }
    }
    final spaceEnd = _skipSpaces(end);
    var next = spaceEnd;
    var forced = false;
    if (next < _plain.length && _forced(_unit(next))) {
      next++;
      forced = true;
    }
    return (end, spaceEnd, next, forced);
  }

  /// WHERE SKIA ENDS THE FIRST LINE of the words from [from] in [maxWidth]
  /// (its trailing spaces in it), as all the rest of the paragraph sets
  /// it: read off the words up to a cut not far past the line where that
  /// is the same ([_lineEnd]'s window), else off one paragraph of all the
  /// rest, its breaks read again for each line after it as wide
  /// ([_restLineEnd]). Set from all the rest for every line, each line
  /// shaped what was left, and a long paragraph in a narrow column grew as
  /// the square of its length.
  ///
  /// THE WORDS AFTER THE CUT CANNOT MOVE A BREAK BEFORE IT. The cut is a
  /// break either way ([_cutAfter]): after a run of spaces, or between two
  /// ideographs. Where the line ends before the cut with two whole words
  /// of the cut text after it ([_settled]), the word that did not fit and
  /// the one after it were shaped and broken as all the rest of the text
  /// shapes and breaks them -- and what comes after only makes that word
  /// longer, if anything (a break UAX #14 keeps across spaces), so it
  /// still does not fit. Else the cut is taken twice as far, and at the
  /// last the line is read off all the rest.
  ///
  /// WORDS SET RIGHT TO LEFT, OR WITH A RIGHT-TO-LEFT LETTER IN THEM, ARE
  /// LEVELED OVER ALL THE REST (UAX #9), and the cut is read off only where
  /// the levels up to the word that did not fit are theirs in all of it
  /// ([_leveled]): a letter after that word and before the cut. The rules
  /// that look forward -- a run of neutrals (N1, N2) and of terminators
  /// next to a number (W5), a separator between two numbers (W4) -- stop
  /// at a letter, and the ones that look back (W2, W7) read the same
  /// words; the paragraph's level is the painter's own. NEGATIVE: words
  /// with an embedding, an override or an isolate in them ([_embedded])
  /// are read off all the rest at every line: what one opens is closed
  /// (X6a), or its direction found (FSI, X5c), anywhere after it.
  ///
  /// NEGATIVE: NOR ARE WORDS WITH A LETTER OR WORD SPACING ANYWHERE IN
  /// THEM read off a cut. Skia spaces such a paragraph in one pass over
  /// all of it, and a break can move with what comes long after: in a
  /// paragraph that mixes a `wordSpacing: 4` span with other styles, a
  /// line of 33 letters stood 31 once a letter was added 300 letters past
  /// it, inside the spaced span; read off cuts, 46 of 72 such paragraphs
  /// came out otherwise (`float_text_line_cut_test`). They are read off
  /// all the rest, at every line.
  int _lineEnd(int from, double maxWidth) {
    if (debugWholeRest) return _lineEndIn(from, _plain.length, maxWidth);
    if (!_embedded && !_spaced) {
      final leveled = _rtl || _bidi;
      for (var span = 256; from + span < _plain.length; span *= 2) {
        final to = _cutAfter(from + span, from + 2 * span);
        if (to == null) break;
        final end = _lineEndIn(from, to, maxWidth);
        if (_settled(end, to) && (!leveled || _leveled(end, to))) return end;
      }
    }
    return _restLineEnd(from, maxWidth);
  }

  /// Whether the levels of the words up to the end of the one after code
  /// unit [end] are the same set from a cut at [to] as from all the rest:
  /// a letter stands after that word and before the cut ([_lineEnd]).
  bool _leveled(int end, int to) {
    final word = _chunkEnd(end);
    for (var i = to; i > word;) {
      final c = _runeBefore(i, word);
      if (_strong(c) != null) return true;
      i -= c > 0xFFFF ? 2 : 1;
    }
    return false;
  }

  /// THE FIRST LINE OF ALL THE REST FROM [from] IN [maxWidth], READ OFF ONE
  /// PARAGRAPH OF IT: all the rest is laid out once at that width, and the
  /// line that starts at [from] in it -- and each line after it -- ends
  /// where it does in that paragraph. Skia breaks a paragraph a line at a
  /// time from where the line before it ended (greedy), shaping and
  /// spacing all of it in one pass, so the paragraph's line from a start
  /// breaks where the one-line painter of all the rest from that start
  /// ends: over the sweep of spaced paragraphs that a cut moved, all 72
  /// came out the same, and so did every sweep of
  /// `float_text_line_cut_test`. A line of another width -- beside a
  /// float, below one -- or one that starts where no line of the
  /// paragraph does lays all the rest out again, from it: the work is all
  /// the rest once for each width the lines change to, not once a line.
  int _restLineEnd(int from, double maxWidth) {
    if (_rest case (final width, final ends) when width == maxWidth) {
      if (ends[from] case final end?) return end;
    }
    final tp = _painter(from, _plain.length)..layout(maxWidth: maxWidth);
    final ends = <int, int>{};
    final length = _plain.length - from;
    // Each line of the paragraph, by where the lines are set from after
    // the one before it ends ([_nextAfter]).
    var key = from;
    for (var at = 0; at < length;) {
      final end = tp.getLineBoundary(TextPosition(offset: at)).end;
      if (end <= at) {
        // A forced break between two lines is on neither.
        at++;
        continue;
      }
      ends[key] = from + end;
      key = _nextAfter(from + end);
      at = end;
    }
    tp.dispose();
    _rest = (maxWidth, ends);
    return ends[from] ?? _lineEndIn(from, _plain.length, maxWidth);
  }

  /// Where the lines are set from after a line that Skia ends at [brk]:
  /// past its trailing spaces and its forced break, as [_lineFrom] finds.
  int _nextAfter(int brk) {
    var end = brk;
    while (end > 0 && (_space(_unit(end - 1)) || _forced(_unit(end - 1)))) {
      end--;
    }
    var next = _skipSpaces(end);
    if (next < _plain.length && _forced(_unit(next))) next++;
    return next;
  }

  /// The line ends [_restLineEnd] last read off all the rest, by where
  /// each line starts, and the width they were set in; set aside each
  /// time the lines are laid ([_layLines]).
  (double, Map<int, int>)? _rest;

  /// Sets every line from all the rest of the paragraph, as before
  /// [_lineEnd] read it off a cut: what a test compares the two with.
  @visibleForTesting
  static bool debugWholeRest = false;

  int _lineEndIn(int from, int to, double maxWidth) {
    final tp = _painter(from, to, maxLines: 1)..layout(maxWidth: maxWidth);
    final end = from + tp.getLineBoundary(const TextPosition(offset: 0)).end;
    tp.dispose();
    return end;
  }

  /// Whether a line that ends at [end] in the words cut at [to] ends there
  /// in all of them: before the cut, with the word after it and one more
  /// whole before the cut.
  bool _settled(int end, int to) {
    if (end >= to) return false;
    final next = _chunkEnd(end);
    return next < to && _chunkEnd(next) < to;
  }

  /// The first code unit from [at] up to [most] that the words may be cut
  /// before and break there whatever comes after: the start of a word
  /// after spaces -- a word that starts with a letter, a digit or ASCII
  /// punctuation, no mark that would join the space -- or an ideograph or
  /// a kana after one. Null where there is none.
  int? _cutAfter(int at, int most) {
    for (var i = math.max(at, 1); i < _plain.length && i <= most; i++) {
      final a = _unit(i - 1), b = _unit(i);
      if (a == 0x20 && _starts(b) || _ideograph(a) && _ideograph(b)) return i;
    }
    return null;
  }

  /// A character that starts a cluster and a word after a space: a
  /// Hebrew or an Arabic letter too, which joins nothing across the space
  /// (no mark, no tatweel).
  static bool _starts(int c) =>
      (c > 0x20 && c < 0x7F) ||
      (c >= 0xC0 && c <= 0x24F && c != 0xD7 && c != 0xF7) ||
      (c >= 0x391 && c <= 0x3C9) ||
      (c >= 0x400 && c <= 0x481) ||
      (c >= 0x5D0 && c <= 0x5EA) ||
      (c >= 0x621 && c <= 0x63A) ||
      (c >= 0x641 && c <= 0x64A) ||
      (c >= 0x671 && c <= 0x6D3) ||
      _ideograph(c) ||
      (c >= 0xAC00 && c <= 0xD7A3);

  /// A CJK ideograph, or a kana that is not a small one: a break may come
  /// before it and after it whatever is around them (UAX #14 ID).
  static bool _ideograph(int c) =>
      (c >= 0x4E00 && c <= 0x9FFF) ||
      (c >= 0x3400 && c <= 0x4DBF) ||
      (c >= 0x3042 && c <= 0x3093 && !_smallKana.contains(c)) ||
      (c >= 0x30A2 && c <= 0x30F3 && !_smallKana.contains(c));

  static const _smallKana = {
    0x3043, 0x3045, 0x3047, 0x3049, 0x3063, 0x3083, 0x3085, 0x3087, 0x308E, //
    0x30A3, 0x30A5, 0x30A7, 0x30A9, 0x30C3, 0x30E3, 0x30E5, 0x30E7, 0x30EE,
  };

  /// A LINE BOX IS THE STRUT AND THE RUNS ON IT, EACH LEADED (CSS 2.1
  /// 10.8.1): every inline box is as tall as its `line-height`, the leading
  /// split about its content area, and the line reaches from the highest
  /// top of them to the lowest bottom, its baseline where theirs are -- the
  /// strut is the block's own font at [lineHeight]. A run's `line-height`
  /// is its style's `height` where it has one, and the block's where not.
  /// Returned: the line's height and its baseline under its top.
  (double, double) _measureLine(int from, int to) {
    var (above, below) = _extentOf(_style, strut: true);
    // The runs on the line, from the first that ends past its start: the
    // runs, like the places below, are in the words' order.
    for (var i = _firstRunPast(from); i < _runs.length && _runs[i].start < to; i++) {
      final (a, b) = _extentOf(_runs[i].style, strut: false);
      if (a > above) above = a;
      if (b > below) below = b;
    }
    // AN ATOMIC INLINE IS ITS MARGIN BOX ON THE LINE (10.8.1): its baseline
    // on the line's, or -- with none, or `aboveBaseline` -- its bottom.
    for (var i = _firstPast(_holders, from, orEqual: true); i < _holders.length && i < _dims.length; i++) {
      if (_holders[i] >= to) break;
      final d = _dims[i];
      final h = d.size.height;
      final (a, b) = switch (d.alignment) {
        PlaceholderAlignment.baseline => (d.baselineOffset ?? h, h - (d.baselineOffset ?? h)),
        PlaceholderAlignment.belowBaseline => (0.0, h),
        _ => (h, 0.0),
      };
      if (a > above) above = a;
      if (b > below) below = b;
    }
    return (above + below, above);
  }

  /// Each style's leaded extent over and under the baseline, and the strut's.
  final Map<(TextStyle, bool), (double, double)> _extents = {};

  void _forgetExtents() {
    _extents.clear();
    _lift = null;
  }

  /// [t]'s leaded extent as Blink sets it: the content area is the face's
  /// ascent and descent rounded to whole pixels ([_faceOf]), the half-leading
  /// of the line height is added about it, and the leaded ascent is FLOORED,
  /// the rest of the line height going under the baseline
  /// (`FontHeight::AddLeading`) -- so an odd half-leading sits below it.
  ///
  /// At the size the text is drawn ([_drawn]): a scaled run's face and
  /// leading are a larger font's, and the strut's told lengths scale by
  /// the block's factor ([_k]).
  (double, double) _extentOf(TextStyle t, {required bool strut}) => _extents[(t, strut)] ??= () {
    final k = _k;
    final d = _drawn(t);
    final f = _faceOf(d, lifted: t.fontFamily == _style.fontFamily ? _strutLifted : null);
    final lh = _leadOf(d, f, strut: strut, k: k);
    final above = strut && _ascent != null ? _ascent! * k : _aboveOf(f, lh);
    return (above, lh - above);
  }();

  /// [t]'s line height: its own `height` for a run, the block's for the
  /// strut -- [_lineHeight] scaled by [k] with the text. A length is kept
  /// to Blink's 1/64 px; `normal` is the face's own.
  double _leadOf(TextStyle t, ({double ascent, double descent, double gap}) f, {required bool strut, double k = 1}) {
    final fs = t.fontSize ?? 14.0;
    return !strut && t.height != null
        ? (t.height! * fs * 64).roundToDouble() / 64
        : _lineHeight != null
        ? (_lineHeight! * k * 64).roundToDouble() / 64
        : (f.ascent + f.descent + f.gap).roundToDouble() / fs * fs;
  }

  /// The leaded ascent of face [f] in a line [lh] tall, floored.
  static double _aboveOf(({double ascent, double descent, double gap}) f, double lh) =>
      (f.ascent + (lh - (f.ascent + f.descent)) / 2).floorToDouble();

  /// Whether the block's face is lifted as Blink lifts Times, Helvetica and
  /// Courier, where its name does not say so: the strut's [FloatText.ascent]
  /// is the lifted face's where its name's answer misses it. Null -- no
  /// ascent told, or one either reading stands on -- leaves it to the name.
  bool? get _strutLifted => (_lift ??= (lifted: _readLift())).lifted;
  ({bool? lifted})? _lift;

  bool? _readLift() {
    final told = _ascent;
    if (told == null) return null;
    final named = _namesLift(_style.fontFamily);
    final f = _faceOf(_style, lifted: !named);
    if ((_aboveOf(f, _leadOf(_style, f, strut: true)) - told).abs() > 1 / 128) return null;
    final g = _faceOf(_style, lifted: named);
    if ((_aboveOf(g, _leadOf(_style, g, strut: true)) - told).abs() <= 1 / 128) return null;
    return !named;
  }

  /// A face's vertical metrics at [t]'s size as Blink lays lines out on
  /// them: its ascent and descent, each rounded to a whole pixel
  /// (`SimpleFontData::PlatformInit`), the ascent of Times, Helvetica and
  /// Courier lifted by 15% of the two as Blink on macOS lifts it
  /// (`FontMetrics::AscentDescentWithHacks`), and the gap `normal` adds.
  /// Read off Flutter's own line metrics of the face with no `height`,
  /// which would lead them.
  ///
  /// SKIA'S ASCENT AND DESCENT ARE LEADED BY HALF THE FACE'S LINE GAP EACH
  /// (`Run::calculateMetrics`: `fCorrectAscent = fAscent - fLeading / 2`),
  /// where Blink rounds the bare ascent, the bare descent and the gap each
  /// on its own. A strut of no leading, forced, stands on the bare ascent,
  /// and the gap is twice what the leaded ascent passes it by. Hiragino Sans
  /// (a gap of half an em) at 14px is 12 + 2 + 7 to Blink, its strut 15
  /// over the baseline and 6 under; read off the leaded 15.82 and 5.18 it
  /// was 16 and 5, and a Japanese news site's phone section heading -- a link alone on
  /// a line beside a floated title -- stood a 22px line, the link 1px low,
  /// and the page under it with it (fixtures/float-line-gap-strut). Where
  /// the strut stands on another face than the run's (a family that lacks
  /// the glyph), or the face has no gap, the leaded metrics are read as
  /// they were.
  static ({double ascent, double descent, double gap}) _faceOf(TextStyle t, {bool? lifted}) {
    final bare = TextStyle(
      fontFamily: t.fontFamily,
      fontFamilyFallback: t.fontFamilyFallback,
      fontSize: t.fontSize,
      fontWeight: t.fontWeight,
      fontStyle: t.fontStyle,
      fontVariations: t.fontVariations,
      fontFeatures: t.fontFeatures,
    );
    final tp = TextPainter(
      text: TextSpan(text: 'x', style: bare),
      textDirection: TextDirection.ltr,
    )..layout();
    final lm = tp.computeLineMetrics().first;
    tp.dispose();
    final sp = TextPainter(
      text: TextSpan(text: 'x', style: bare),
      strutStyle: StrutStyle(
        fontFamily: t.fontFamily,
        fontFamilyFallback: t.fontFamilyFallback,
        fontSize: t.fontSize,
        fontWeight: t.fontWeight,
        fontStyle: t.fontStyle,
        leading: 0,
        forceStrutHeight: true,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final bareAscent = sp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final bareHeight = sp.height;
    sp.dispose();
    // Half the gap over the ascent -- where the strut's face is the run's:
    // the bare ascent and descent it is then laid out at, rounded, are the
    // line height it answers.
    final half = lm.ascent - bareAscent;
    final lead = half > 1 / 64 && (lm.ascent + lm.descent - 2 * half - bareHeight).abs() <= 0.5 ? half : 0.0;
    final gap = lead > 0 ? 2 * lead : lm.height - lm.ascent - lm.descent;
    final a = (lm.ascent - lead).roundToDouble(), d = (lm.descent - lead).roundToDouble();
    final lift = lifted ?? _namesLift(t.fontFamily)
        // Blink's arithmetic is float's: 70 * 0.15f is past 10.5.
        ? ((a + d) * 0.15000000596046448 + 0.5).floorToDouble()
        : 0.0;
    return (ascent: a + lift, descent: d, gap: gap < 0 ? 0.0 : gap);
  }

  /// Whether [family]'s name is one of the faces Blink lifts.
  static bool _namesLift(String? family) => const {
    'times',
    'helvetica',
    'courier',
  }.contains((family ?? '').split('__').first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''));

  // ------------------------------------------------------------- the lines

  /// The paragraph's lines, in a border box whose content starts [pad] in:
  /// in [host] where a context's floats may shorten them, [maxW] wide where
  /// not (null: unbounded; 0: every break taken). The floats on the lines
  /// are [onLine], in order, laid out by [pass]; their shares are of [w].
  _Laid _layLines(_Pass? pass, _Ctx? host, double? maxW, double? w, EdgeInsets pad, List<_Node> onLine) {
    final held = _dims = _heldIn(w);
    _rest = null;
    final lines = <_Line>[];
    final placed = <_OnLine>[];
    ({double x, double width, double y, int? segment}) band(double at, int? after) {
      if (host == null) return (x: pad.left, width: maxW ?? double.infinity, y: at, segment: null);
      final s = host.contentSlot(at, FloatClear.none, after);
      return (x: s.x, width: s.width, y: s.y, segment: s.segment);
    }

    var y = pad.top;
    var cur = band(y, null);
    y = _fmax(y, cur.y);

    // A float on a line is shrink-to-fit sized in the paragraph's content
    // box, once.
    final laidFloats = <_Node, _Res>{};
    _Res layFloat(_Node f) => laidFloats[f] ??= pass!.lay(
      f,
      _In(
        pw: w,
        aw: _Space.definite(_fmax((w ?? 0.0) - (f.mLeft(w) ?? 0.0) - (f.mRight(w) ?? 0.0), 0.0)),
        ah: _Space.maxContent,
      ),
      null,
    );
    double marginBoxWidth(_Node f) => layFloat(f).size.width + (f.mLeft(w) ?? 0.0) + (f.mRight(w) ?? 0.0);
    void place(_Node f, double at) {
      final r = layFloat(f);
      final ml = f.mLeft(w) ?? 0.0, mr = f.mRight(w) ?? 0.0, mt = f.mTop(w) ?? 0.0, mb = f.mBottom(w) ?? 0.0;
      final pos = host!.placeFloat(
        Size(r.size.width + ml + mr, r.size.height + mt + mb),
        at,
        _sideOf(f.side),
        f.clear,
        false,
      );
      placed.add(_OnLine(f, r.size, Offset(pos.dx + ml, pos.dy + mt)));
    }

    // A LINE BOX WITH NO ROOM BESIDE A FLOAT MOVES DOWN (CSS 2.1 9.5): where
    // [need] does not fit it goes down until it does or the floats run out.
    void roomFor(double need) {
      if (host == null || cur.segment == null) return;
      var nb = cur;
      while (nb.segment != null && need > nb.width + 1e-6) {
        final next = band(nb.y, nb.segment);
        if (next.y <= nb.y && next.width <= nb.width + 1e-6) break;
        nb = next;
      }
      if (nb.y > cur.y + 1e-6 || nb.width > cur.width + 1e-6) {
        cur = nb;
        y = _fmax(y, nb.y);
      }
    }

    final withFloats = host != null && pass != null;
    var k = 0;
    if (!_hasWords) {
      // Floats alone: each at the top of the line box there is none of.
      if (withFloats) {
        for (final f in onLine) {
          place(f, y);
        }
      }
      return _Laid(lines, placed, 0.0, false, held, w);
    }

    final pending = <_Node>[];
    var from = _skipSpaces(0);
    var widest = 0.0;
    var softWrapped = false;
    double room() => _softWrap ? cur.width : double.infinity;
    while (from < _plain.length) {
      // A float whose place is before the line's first word goes at the top
      // of the line, and the line is set beside it.
      while (withFloats && k < onLine.length && _anchors[k] <= from) {
        place(onLine[k++], y);
        cur = band(y, null);
      }
      if (_softWrap) roomFor(_widthOf(from, _chunkEnd(from)));
      var (end, spaceEnd, next, forced) = _lineFrom(from, room());
      // A float whose place is on this line: beside the words before it
      // where they leave it room, else at the top of the next line.
      while (withFloats && k < onLine.length && _anchors[k] <= spaceEnd) {
        final f = onLine[k++];
        if (_widthOf(from, _anchors[k - 1]) + marginBoxWidth(f) <= cur.width + 1e-6) {
          place(f, y);
          cur = band(y, null);
          (end, spaceEnd, next, forced) = _lineFrom(from, room());
        } else {
          pending.add(f);
        }
      }
      if (next < _plain.length && !forced) softWrapped = true;
      final width = _widthOf(from, end);
      final (h, base) = _measureLine(from, end);
      lines.add(_Line(from, end, cur.x, y, cur.width, width, h, base, soft: next < _plain.length && !forced));
      widest = _fmax(widest, width);
      y += h;
      from = _skipSpaces(next);
      // Floats that did not fit beside the finished line go at the top of
      // the next one.
      if (host != null) {
        for (final f in pending) {
          place(f, y);
        }
        pending.clear();
        cur = band(y, null);
        y = _fmax(y, cur.y);
      }
    }
    // The floats whose places are past the last word stand at the top of
    // the line after it.
    while (withFloats && k < onLine.length) {
      place(onLine[k++], y);
    }
    return _Laid(lines, placed, widest, softWrapped, held, w);
  }

  /// The paragraph's width with the floats on its lines as words of their
  /// own ([widths], margin boxes), for an intrinsic question. Lines that do
  /// not wrap keep their floats beside their words at min-content too: the
  /// break before and after a float is a soft one, and `nowrap` takes none.
  double _widthWithFloats(_Laid laid, List<double> widths, {required bool minContent}) {
    var widest = laid.width;
    if (minContent && _softWrap) {
      for (final fw in widths) {
        widest = _fmax(widest, fw);
      }
      return widest;
    }
    // Every float on the line its place is on, beside that line's words.
    final extra = List<double>.filled(math.max(1, laid.lines.length), 0.0);
    for (var k = 0; k < widths.length && k < _anchors.length; k++) {
      var line = 0;
      for (var j = 0; j < laid.lines.length; j++) {
        if (laid.lines[j].start <= _anchors[k]) line = j;
      }
      extra[line] += widths[k];
    }
    for (var j = 0; j < extra.length; j++) {
      widest = _fmax(widest, (j < laid.lines.length ? laid.lines[j].width : 0.0) + extra[j]);
    }
    return widest;
  }

  /// The paragraph's width in [space] (its intrinsic contribution): the
  /// widest word at min-content, the whole on one line at max-content.
  double _measureWidth(_Space space) {
    if (!_hasWords) return 0.0;
    _dims = _heldIn(null, min: space.isMin && _softWrap, max: !(space.isMin && _softWrap));
    final tp = _painter(0, _plain.length)..layout();
    final min = tp.minIntrinsicWidth, max = tp.maxIntrinsicWidth;
    tp.dispose();
    if (space.isMin && _softWrap) return min;
    return max;
  }

  // --------------------------------------------------------------- the box

  @override
  double computeMinIntrinsicWidth(double height) => _measureWidth(_Space.minContent);

  @override
  double computeMaxIntrinsicWidth(double height) => _measureWidth(_Space.maxContent);

  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _own(width.isFinite ? BoxConstraints.tightFor(width: width) : const BoxConstraints()).$2.height;

  /// This paragraph on its own in [c]: its lines at the width it is held
  /// to, or the room it is offered, and the size they come to.
  (_Laid, Size) _own(BoxConstraints c) {
    final kw = c.hasTightWidth ? c.maxWidth : null;
    final w = kw ?? (c.maxWidth.isFinite ? c.maxWidth : null);
    final l = _hasWords ? _layLines(null, null, w, w, EdgeInsets.zero, const []) : _Laid.none;
    var width = kw ?? l.width;
    if (kw == null && w != null && w > 0 && l.softWrapped) width = _fmax(width, w);
    final h = l.lines.isEmpty ? 0.0 : l.lines.last.y + l.lines.last.height;
    return (l, c.constrain(Size(width, h)));
  }

  @override
  @protected
  Size computeDryLayout(covariant BoxConstraints constraints) {
    if (_hosted && constraints.isTight) return constraints.biggest;
    return _own(constraints).$2;
  }

  @override
  @protected
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) {
    final l = _hosted && constraints.isTight ? _laid : _own(constraints).$1;
    if (l == null || l.lines.isEmpty) return null;
    final shift = _hosted && constraints.isTight ? _shift.top : 0.0;
    return l.lines.first.y + l.lines.first.baseline - shift;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final l = _laid;
    if (l == null || l.lines.isEmpty) return null;
    return l.lines.first.y + l.lines.first.baseline - _shift.top;
  }

  @override
  void performLayout() {
    // A hosted paragraph was set by the flow round it, and is told a tight
    // size.
    if (_hosted && constraints.isTight) {
      size = constraints.biggest;
      _placeHeld();
      return;
    }
    _hosted = false;
    final (l, s) = _own(constraints);
    _laid = l;
    _shift = EdgeInsets.zero;
    size = s;
    _placeHeld();
  }

  /// Lays the widgets on the lines out in the width they were measured in,
  /// and stands each where its line's painter holds its place.
  void _placeHeld() {
    if (firstChild == null) return;
    final laid = _laid ?? _Laid.none;
    final c = BoxConstraints(maxWidth: laid.room ?? double.infinity);
    var child = firstChild;
    while (child != null) {
      child.layout(c, parentUsesSize: true);
      (child.parentData! as _Held).shown = false;
      child = childAfter(child);
    }
    _dims = laid.held;
    final kids = <RenderBox>[];
    for (var k = firstChild; k != null; k = childAfter(k)) {
      kids.add(k);
    }
    // The lines run in the words' order, and so do the places: the first
    // place on a line is found from the last line's.
    var first = 0;
    for (final l in laid.lines) {
      while (first < _holders.length && _holders[first] < l.start) {
        first++;
      }
      if (first >= _holders.length || _holders[first] >= l.end) continue;
      final (tp, at) = _linePainter(l);
      final boxes = tp.inlinePlaceholderBoxes ?? const <TextBox>[];
      // A widget anchored to the baseline stands on the line's own: Skia's
      // box for one above it sits half a pixel under the baseline it sets
      // the words on when the line's strut is fractional.
      final base = l.y - _shift.top + l.baseline;
      for (var k = 0; k < boxes.length && first + k < kids.length; k++) {
        final d = kids[first + k].parentData! as _Held;
        final dim = first + k < _dims.length ? _dims[first + k] : null;
        final y = switch (dim?.alignment) {
          PlaceholderAlignment.aboveBaseline => base - dim!.size.height,
          PlaceholderAlignment.baseline => base - (dim!.baselineOffset ?? dim.size.height),
          PlaceholderAlignment.belowBaseline => base,
          _ => at.dy + boxes[k].top,
        };
        d
          ..at = Offset(at.dx + boxes[k].left, y)
          ..shown = true;
      }
      tp.dispose();
    }
  }

  /// [l]'s painter, laid out, and where its origin goes in this box.
  (TextPainter, Offset) _linePainter(_Line l) {
    // Set in the room of its own line; a line wider than that room runs
    // out of it from its start -- under `rtl` its right, the room's, or
    // the box's where the room is unbounded.
    final fits = l.room.isFinite && l.width <= l.room + 0.01;
    if (fits && l.soft && _textAlign == TextAlign.justify) {
      if (_justified(l) case final j?) return j;
    }
    final tp = _painter(
      l.start,
      l.end,
      maxLines: 1,
      align: fits ? null : (_rtl ? TextAlign.right : TextAlign.left),
      marked: true,
    );
    var x = l.x;
    if (fits) {
      final r = math.max(l.room, l.width);
      tp.layout(minWidth: r, maxWidth: r);
    } else {
      tp.layout();
      if (_rtl) x = (l.room.isFinite ? l.x + l.room : size.width + _shift.left) - tp.width;
    }
    // On the line's baseline, wherever Skia's own would have put it. Skia
    // ANSWERS the baseline its line asked for but DRAWS on it rounded, and
    // snaps the origin to the pixel apart from it: Inter 16 answers 15.5
    // and draws at 16, so a line at 231.25 set 0.5 down came out on 248
    // where Blink rounds 247.25 to 247 (`fixtures/float-lines-normal`).
    final base = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic).roundToDouble();
    return (tp, Offset(x - _shift.left, l.y - _shift.top + l.baseline - base));
  }

  /// A JUSTIFIED LINE IS STRETCHED TO ITS ROOM by its spaces (css-text-3
  /// 7.1.1), and Skia stretches a line only where it does not end its
  /// paragraph: so [l]'s painter holds its words and the run the pass
  /// broke before, one line in [l]'s room, which must break where the
  /// pass broke it and come out stretched (a line with no space between
  /// its words does not). Nothing on it may be a widget ([_placeHeld]
  /// reads one line's boxes). Else null, and the line is set at its start
  /// as one that is not justified. NEGATIVE: the last line, and one a
  /// forced break ends, are not [_Line.soft].
  (TextPainter, Offset)? _justified(_Line l) {
    final to = _chunkEnd(_skipSpaces(l.end));
    if (to <= l.end || to > _plain.length) return null;
    final held = _firstPast(_holders, l.start, orEqual: true);
    if (held < _holders.length && _holders[held] < to) return null;
    final lead = _markAt(l.start, to, start: true)?.length ?? 0;
    final tp = _painter(l.start, to, maxLines: 1, align: TextAlign.justify, marked: true)
      ..layout(minWidth: l.room, maxWidth: l.room);
    var end = l.start + tp.getLineBoundary(TextPosition(offset: lead)).end - lead;
    while (end > l.start && end <= _plain.length && (_space(_unit(end - 1)) || _forced(_unit(end - 1)))) {
      end--;
    }
    final m = tp.computeLineMetrics();
    if (end != l.end || !tp.didExceedMaxLines || m.length != 1 || m.single.width < l.room - 0.01) {
      tp.dispose();
      return null;
    }
    final base = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic).roundToDouble();
    return (tp, Offset(l.x - _shift.left, l.y - _shift.top + l.baseline - base));
  }

  /// How wide each line is drawn: its words, or its whole room where it is
  /// justified ([_justified]).
  @visibleForTesting
  List<double> get debugDrawnWidths => [
    for (final l in _laid?.lines ?? const <_Line>[])
      if (l.end > l.start)
        () {
          final (tp, _) = _linePainter(l);
          final w = tp.computeLineMetrics().first.width;
          tp.dispose();
          return w;
        }(),
  ];

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _Held) child.parentData = _Held();
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final d = child.parentData! as _Held;
    transform.translateByDouble(d.at.dx, d.at.dy, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    var child = lastChild;
    while (child != null) {
      final d = child.parentData! as _Held;
      if (d.shown) {
        final hit = result.addWithPaintOffset(
          offset: d.at,
          position: position,
          hitTest: (result, p) => child!.hitTest(result, position: p),
        );
        if (hit) return true;
      }
      child = d.previousSibling;
    }
    return false;
  }

  /// The lines as the last layout set them, in this box's coordinates:
  /// each line's words, where they start once the line is aligned in its
  /// room, its top, its baseline, and its words' width.
  @visibleForTesting
  List<({String text, double x, double y, double baseline, double width})> get debugLines => [
    for (final l in _laid?.lines ?? const <_Line>[])
      (
        text: _plain.substring(l.start, l.end).replaceAll('\u200B', ''),
        x: l.x - _shift.left + _alignOffset(l),
        y: l.y - _shift.top,
        baseline: l.y - _shift.top + l.baseline,
        width: l.width,
      ),
  ];

  double _alignOffset(_Line l) {
    if (!l.room.isFinite) return 0.0;
    final free = l.room - l.width;
    if (l.width > l.room) return _rtl ? free : 0.0;
    // A justified line fills its room ([_justified]).
    if (_textAlign == TextAlign.justify && l.soft && _rtl) {
      final j = _justified(l);
      j?.$1.dispose();
      if (j != null) return 0.0;
    }
    return switch (_textAlign) {
      TextAlign.center => free / 2,
      TextAlign.right => free,
      TextAlign.left => 0.0,
      TextAlign.end => _rtl ? 0.0 : free,
      _ => _rtl ? free : 0.0,
    };
  }

  @override
  bool hitTestSelf(Offset position) => true;

  /// [l], set by [tp], painted at [at]: as it is, and each piece of an
  /// [OffsetSpan] on it painted off its place, as `OffsetSpans` paints a
  /// paragraph's (CSS 2.1 9.4.3) -- a line here is a paragraph of its own.
  void _paintLine(Canvas canvas, _Line l, TextPainter tp, Offset at) {
    final pieces = <(Offset, List<Rect>)>[];
    final lead = _leads[tp] ?? 0;
    for (final (from, to, by) in _moved) {
      final a = math.max(from, l.start), b = math.min(to, l.end);
      if (a >= b) continue;
      final boxes = tp.getBoxesForSelection(
        TextSelection(baseOffset: a - l.start + lead, extentOffset: b - l.start + lead),
        boxHeightStyle: ui.BoxHeightStyle.max,
      );
      if (boxes.isNotEmpty) pieces.add((by, [for (final x in boxes) x.toRect()]));
    }
    if (pieces.isEmpty) {
      tp.paint(canvas, at);
      return;
    }
    paintMoved(canvas, at, (at & tp.size).inflate(tp.size.longestSide + 1e4), pieces, (by) => tp.paint(canvas, at + by));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final laid = _laid;
    if (laid == null) return;
    _dims = laid.held;
    for (final l in laid.lines) {
      if (l.end <= l.start) continue;
      final (tp, at) = _linePainter(l);
      _paintLine(context.canvas, l, tp, offset + at);
      tp.dispose();
    }
    var child = firstChild;
    while (child != null) {
      final d = child.parentData! as _Held;
      if (d.shown) context.paintChild(child, offset + d.at);
      child = d.nextSibling;
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..label = _spoken
      ..textDirection = _textDirection;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('text', _plain))
      ..add(DoubleProperty('lineHeight', _lineHeight, defaultValue: null))
      ..add(DoubleProperty('ascent', _ascent, defaultValue: null))
      ..add(DiagnosticsProperty<TextScaler>('textScaler', _textScaler, defaultValue: TextScaler.noScaling))
      ..add(IntProperty('lines', _laid?.lines.length ?? 0));
  }
}
