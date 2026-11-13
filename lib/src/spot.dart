/// The STATIC POSITION of an out-of-flow box (CSS 2.1 10.3.7, 10.6.4):
/// where the box would have been had it stayed in the flow.
///
/// A box with `top: auto` and `bottom: auto` is placed at that position,
/// and nothing but the flow knows it -- it is wherever the content before
/// the box ended, which depends on how that content wrapped at this width.
/// So the flow keeps a [SpotMark] where the box was taken out of it, and
/// the box, which is placed in a `Stack` around that flow, is wrapped in a
/// [SpotShift] that moves it down to wherever the mark ended up.
///
/// The two find each other through a [SpotScope] around the stack: the
/// mark is inside the stack's flow child, the shift inside one of its
/// positioned children, and a `Stack` lays its flow child out before its
/// positioned ones, so by the time a shift is laid out its mark is where
/// it is going to be.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';

/// The marks of one containing block, by the name the page gives them.
///
/// Stateful so that the map outlives a rebuild: a mark registers itself
/// once, when its render object is made, and a shift laid out long after
/// has to find it in the same map.
class SpotScope extends StatefulWidget {
  const SpotScope({super.key, required this.child});

  final Widget child;

  /// Where a mark registers and a shift looks, or a map of its own when
  /// there is no scope above it -- a page that leaves a mark with nothing
  /// reading it should draw the same as one that never made it, not throw.
  static Map<Object, RenderBox> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Marks>()?.marks ?? <Object, RenderBox>{};

  @override
  State<SpotScope> createState() => _SpotScopeState();
}

class _SpotScopeState extends State<SpotScope> {
  final Map<Object, RenderBox> marks = {};

  /// ONE MAP FOR THE WHOLE PAGE. A mark's name is unique to its page, and
  /// the box that reads it may be placed in a stack further up than the
  /// frame that keeps the mark: a `fixed` box goes into the viewport's
  /// stack at the root, and the flex or grid container whose content box
  /// places it sits inside a `relative` card with a scope of its own. So a
  /// nested scope registers into the outermost map rather than keeping one
  /// of its own, and a shift anywhere on the page finds the mark.
  @override
  Widget build(BuildContext context) =>
      _Marks(marks: context.dependOnInheritedWidgetOfExactType<_Marks>()?.marks ?? marks, child: widget.child);
}

class _Marks extends InheritedWidget {
  const _Marks({required this.marks, required super.child});

  final Map<Object, RenderBox> marks;

  @override
  bool updateShouldNotify(_Marks old) => !identical(marks, old.marks);
}

/// Where the flow would have put an out-of-flow box: a box of no size at
/// all, in the flow at the point the box was taken out of it.
class SpotMark extends LeafRenderObjectWidget {
  const SpotMark({super.key, required this.id, this.along = 0, this.end = false});

  /// The name the [SpotShift] that reads this mark names it by.
  final Object id;

  /// How far along the mark's own width the point is: `0` its left edge,
  /// `0.5` its middle, `1` its right edge. A mark stretched to its block's
  /// width by the column it stands in is where an INLINE-LEVEL box taken
  /// out of a block container has its static position, and `text-align`
  /// moves that point as it would a line of nothing (css-position-3 3.3):
  /// a pricing page's table hides a label in every centred cell, and each
  /// sits in the cell's middle.
  final double along;

  /// Whether the box shifted to the point puts its END edge on it rather
  /// than its start: under `rtl` a line of nothing starts at its right,
  /// and a box at its static position there ends at the point (CSS 2.1
  /// 10.3.7) -- dba's ad slots, in a right-to-left card. A [SpotShift]
  /// that aligns the box itself says so instead.
  final bool end;

  @override
  RenderSpotMark createRenderObject(BuildContext context) =>
      RenderSpotMark(SpotScope.of(context), id, along: along, end: end);

  @override
  void updateRenderObject(BuildContext context, RenderSpotMark renderObject) => renderObject
    ..register(SpotScope.of(context), id)
    ..along = along
    ..end = end;
}

/// The registration a mark and an area share: a box under one name in the
/// scope above it, for a [SpotShift] to find.
mixin _Registers on RenderBox {
  late Map<Object, RenderBox> _marks;
  late Object _id;

  /// The rectangle this box named, as it last came out.
  ///
  /// NOT `size`: a shift reads a mark it is nowhere near in the tree, and
  /// `RenderBox.size` may only be read by the box itself and by a parent
  /// that asked for it (`sizeAccessAllowed`). A box may always read its
  /// own, so each one writes it down as it is laid out.
  Size get markSize;

  /// The point in this box a shift lands on: its top-left corner, unless
  /// the box says otherwise.
  Offset get markPoint => Offset.zero;

  /// Whether a shifted box ENDS at [markPoint] rather than starting there.
  bool get markEnd => false;

  /// The point the mark named [id] is at: [markPoint], for a box that
  /// keeps one mark. A paragraph keeps one for every [SpotSpan] in it
  /// ([RenderSpotText]).
  Offset markPointFor(Object id) => markPoint;

  void register(Map<Object, RenderBox> marks, Object id) {
    if (identical(marks, _marks) && id == _id) return;
    if (identical(_marks[_id], this)) _marks.remove(_id);
    _marks = marks;
    _id = id;
    _marks[_id] = this;
  }

  @override
  void dispose() {
    if (identical(_marks[_id], this)) _marks.remove(_id);
    super.dispose();
  }
}

class RenderSpotMark extends RenderBox with _Registers, KeptUnderHatch {
  RenderSpotMark(Map<Object, RenderBox> marks, Object id, {double along = 0, bool end = false})
    : _along = along,
      _end = end {
    _marks = marks;
    _id = id;
    _marks[_id] = this;
  }

  double _along;
  double get along => _along;
  set along(double v) {
    if (_along == v) return;
    _along = v;
    markNeedsLayout();
  }

  bool _end;
  bool get end => _end;
  set end(bool v) {
    if (_end == v) return;
    _end = v;
    markNeedsLayout();
  }

  @override
  bool get markEnd => _end;

  Offset _point = Offset.zero;

  /// A point, not a rectangle.
  @override
  Size get markSize => Size.zero;

  @override
  Offset get markPoint => _point;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => constraints.smallest;

  @override
  void performLayout() {
    _point = Offset(size.width * _along, 0);
  }

  @override
  void paint(PaintingContext context, Offset offset) {}
}

/// The RECTANGLE a static position is measured in, where the flow cannot
/// keep a mark in it.
///
/// An out-of-flow child of a FLEX CONTAINER has no place in the flow to
/// come out of: its static-position rectangle is the container's content
/// box, and the box is aligned in it by the container's own `justify-
/// content` and `align-items` as if it were the sole item (css-flexbox-1
/// 4.1). Where the container is also the containing block, the pass knows
/// that rectangle as a number; where it is not -- a `static` flex row
/// inside a `relative` card -- only layout does, so the container marks
/// its content box and the [SpotShift] on the positioned box reads the
/// corner AND the size off it.
class SpotArea extends SingleChildRenderObjectWidget {
  const SpotArea({super.key, required this.id, super.child});

  /// The name the [SpotShift] that reads this area names it by.
  final Object id;

  @override
  RenderSpotArea createRenderObject(BuildContext context) => RenderSpotArea(SpotScope.of(context), id);

  @override
  void updateRenderObject(BuildContext context, RenderSpotArea renderObject) =>
      renderObject.register(SpotScope.of(context), id);
}

class RenderSpotArea extends RenderProxyBox with ChildDryBaseline, _Registers, KeptUnderHatch {
  RenderSpotArea(Map<Object, RenderBox> marks, Object id) {
    _marks = marks;
    _id = id;
    _marks[_id] = this;
  }

  Size _area = Size.zero;

  @override
  Size get markSize => _area;

  @override
  void performLayout() {
    super.performLayout();
    _area = size;
  }
}

/// A MARK INSIDE A WORD: the static position of a box taken out of a line
/// between two letters no line breaks between.
///
/// A [SpotMark] is a placeholder, and Skia breaks a line before and after
/// every placeholder, whatever stands beside it: the object replacement
/// character it is in the text breaks both ways (UAX #14 LB20), and a
/// word joiner either side does not hold it. The box is not on the line
/// (CSS 2.1 9.3), so a browser keeps the two letters one word -- `ab`, a
/// box out of the flow, `cd` in 30px is `abcd` on one line in Chrome, and
/// was `ab` / `cd` here. This span holds no text at all, which breaks
/// nothing; the [SpotText] round the paragraph reads the point off the
/// paragraph's own layout, at the text offset the span stands at.
class SpotSpan extends TextSpan {
  const SpotSpan({required this.id}) : super(text: '');

  /// The name the [SpotShift] that reads this mark names it by.
  final Object id;

  @override
  bool operator ==(Object other) => other is SpotSpan && other.id == id && super == other;

  @override
  int get hashCode => Object.hash(super.hashCode, id);
}

/// The paragraph the [SpotSpan]s in it are the marks of.
///
/// Round a `Text.rich` -- and the boxes of one child each the line is set
/// in, a `LineBox`, an `Opacity` -- it finds the paragraph under it and
/// registers itself under the name of every [SpotSpan] the paragraph's
/// text holds. A mark's point is the CARET at the span's text offset:
/// across, where the letter after it starts; down, the top of the strut
/// on its line, which a forced strut makes the line box's own top --
/// where a box taken out of the line has its static position (CSS 2.1
/// 10.3.7, 10.6.4).
class SpotText extends SingleChildRenderObjectWidget {
  const SpotText({super.key, super.child});

  @override
  RenderSpotText createRenderObject(BuildContext context) => RenderSpotText(SpotScope.of(context));

  @override
  void updateRenderObject(BuildContext context, RenderSpotText renderObject) =>
      renderObject.marks = SpotScope.of(context);
}

class RenderSpotText extends RenderProxyBox with _Registers, KeptUnderHatch {
  RenderSpotText(Map<Object, RenderBox> marks) {
    _marks = marks;
    // The one name the mixin keeps is no mark's: this box is registered
    // under every span's name instead ([_scan]).
    _id = Object();
  }

  set marks(Map<Object, RenderBox> v) {
    if (identical(v, _marks)) return;
    _unregister();
    _marks = v;
    markNeedsLayout();
  }

  /// Each span's name, and the text offset it stands at.
  final Map<Object, int> _offsets = {};

  /// How long the paragraph's text is, in code units.
  int _length = 0;

  /// A point, not a rectangle.
  @override
  Size get markSize => Size.zero;

  /// The paragraph under this box, through boxes of one child each.
  RenderParagraph? get _paragraph {
    RenderObject? r = child;
    while (r != null) {
      if (r is RenderParagraph) return r;
      r = r is RenderObjectWithChildMixin<RenderObject> ? r.child : null;
    }
    return null;
  }

  void _unregister() {
    for (final id in _offsets.keys) {
      if (identical(_marks[id], this)) _marks.remove(id);
    }
  }

  /// Every [SpotSpan] in the paragraph, at the code unit it stands at: a
  /// run counts its text, a placeholder the one character it stands for.
  void _scan() {
    _unregister();
    _offsets.clear();
    final p = _paragraph;
    if (p == null) return;
    var at = 0;
    p.text.visitChildren((span) {
      if (span is SpotSpan) _offsets[span.id] = at;
      if (span is TextSpan) {
        at += span.text?.length ?? 0;
      } else if (span is PlaceholderSpan) {
        at += 1;
      }
      return true;
    });
    _length = at;
    for (final id in _offsets.keys) {
      _marks[id] = this;
    }
  }

  @override
  Offset markPointFor(Object id) {
    final p = _paragraph, at = _offsets[id];
    if (p == null || at == null || !p.hasSize) return Offset.zero;
    // The letter AFTER the span is where the point is, and at the text's
    // end the one before it.
    final caret = p.getOffsetForCaret(
      TextPosition(offset: at, affinity: at >= _length ? TextAffinity.upstream : TextAffinity.downstream),
      Rect.zero,
    );
    return MatrixUtils.transformPoint(p.getTransformTo(this), caret);
  }

  @override
  void performLayout() {
    super.performLayout();
    _scan();
  }

  /// READ AGAIN HERE, as [RenderSpotShift] reads its mark: a span renamed
  /// in a paragraph that lays out as it did leaves this box's layout alone.
  @override
  void paint(PaintingContext context, Offset offset) {
    _scan();
    super.paint(context, offset);
  }

  @override
  void dispose() {
    _unregister();
    super.dispose();
  }
}

/// Moves its child to where the named [SpotMark] ended up.
///
/// On the axes the insets left to the flow, and no others: an inset the
/// page states has already settled its axis, and the child keeps the size
/// the stack gives it. Written directly inside a `Positioned` whose stated
/// edge on each shifted axis is 0, so where the mark is in the stack is
/// exactly how far the child moves.
class SpotShift extends SingleChildRenderObjectWidget {
  const SpotShift({
    super.key,
    required this.id,
    this.across = false,
    this.down = true,
    this.alignX,
    this.alignY,
    this.safeX = false,
    this.safeY = false,
    this.margin = EdgeInsets.zero,
    this.fill = false,
    super.child,
  });

  final Object id;

  /// Whether the child is laid out AT THE AREA'S SIZE and stood at its
  /// corner: a box whose containing block is the area's box, painted in a
  /// stack further out than that block. A box with a `z-index` paints in
  /// the stacking context above its containing block, over boxes placed
  /// against the blocks between (CSS 2.1 Appendix E, step 9), so it is
  /// placed in the stack of one of those -- and its insets and shares are
  /// still the block's: the child is a `Stack` the block's size, holding
  /// the box's `Positioned` as the block's own stack would. Written inside
  /// a `Positioned.fill`, so that the stack lays it out again whenever its
  /// own size changes.
  final bool fill;

  /// The child's own margins, on an axis it is ALIGNED on ([alignX],
  /// [alignY]): the MARGIN box is what is aligned in the area (css-flexbox-1
  /// 4.1, css-align-3 4.4), and the child stands its near margin inside
  /// that -- `alignY * (area - child - top - bottom) + top` down. A `safe`
  /// alignment asks whether the margin box fits: `align-self: safe center`
  /// on a 32px box with `margin-top: 4px` in a 32px row stands it 4 down,
  /// its margin at the row's top. On an axis the child is not aligned on,
  /// nothing.
  final EdgeInsets margin;

  /// Whether the mark settles the child's place across the stack, down it,
  /// or both.
  final bool across, down;

  /// Where in a [SpotArea] the child sits on each axis: `0` at the start
  /// edge, `0.5` centred, `1` at the end. Null is the area's own corner,
  /// which is what a zero-sized [SpotMark] can offer and what a start
  /// alignment comes to anyway.
  final double? alignX, alignY;

  /// Whether the alignment on each axis is `safe` (css-align-3 4.4): a
  /// child that does not fit the area starts at its start edge instead of
  /// hanging out of it.
  final bool safeX, safeY;

  @override
  RenderSpotShift createRenderObject(BuildContext context) {
    // WITH NO SCOPE ROUND IT THE SHIFT READS A MAP OF ITS OWN, which no
    // mark is in: the box would stand at the stack's corner, silently.
    assert(
      context.getInheritedWidgetOfExactType<_Marks>() != null,
      'SpotShift(id: $id) has no SpotScope round it, and reads no mark',
    );
    return RenderSpotShift(
      SpotScope.of(context),
      id,
      across: across,
      down: down,
      alignX: alignX,
      alignY: alignY,
      safeX: safeX,
      safeY: safeY,
      margin: margin,
      fill: fill,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderSpotShift renderObject) => renderObject
    ..marks = SpotScope.of(context)
    ..id = id
    ..across = across
    ..down = down
    ..alignX = alignX
    ..alignY = alignY
    ..safeX = safeX
    ..safeY = safeY
    ..margin = margin
    ..fill = fill;
}

/// A box that reports no more than the room it was offered while what it
/// lays out is past it -- a share of a height with a length beyond the
/// share (`FractionalHeight`). A [SpotShift] aligning one aligns what it
/// lays out, which is the box the page draws: `height: 150%` centred in a
/// 32px row is 48 tall and 8 above the row.
abstract interface class Overhangs {
  /// The size of what the box lays out.
  Size get laidOut;
}

class RenderSpotShift extends RenderShiftedBox with KeptUnderHatch {
  RenderSpotShift(
    this._marks,
    this._id, {
    bool across = false,
    bool down = true,
    double? alignX,
    double? alignY,
    bool safeX = false,
    bool safeY = false,
    EdgeInsets margin = EdgeInsets.zero,
    bool fill = false,
  }) : _margin = margin,
       _fill = fill,
       _across = across,
       _down = down,
       _alignX = alignX,
       _alignY = alignY,
       _safeX = safeX,
       _safeY = safeY,
       super(null);

  bool _fill;
  bool get fill => _fill;
  set fill(bool v) {
    if (_fill == v) return;
    _fill = v;
    markNeedsLayout();
  }

  /// The area's size the child was last laid out at ([fill]).
  Size? _laidArea;

  /// The size of the area the mark names, as it last came out; nothing
  /// where it is not laid out. A copy: the area's own `size` is its to
  /// hand out, and debug builds hold a box to the sizes of its children.
  Size? get _area {
    final mark = _marks[_id];
    if (mark == null || !mark.attached || !mark.hasSize || mark is! _Registers) return null;
    final s = mark.markSize;
    return Size(s.width, s.height);
  }

  EdgeInsets _margin;
  EdgeInsets get margin => _margin;
  set margin(EdgeInsets v) {
    if (_margin == v) return;
    _margin = v;
    markNeedsLayout();
  }

  bool _safeX;
  bool get safeX => _safeX;
  set safeX(bool v) {
    if (_safeX == v) return;
    _safeX = v;
    markNeedsLayout();
  }

  bool _safeY;
  bool get safeY => _safeY;
  set safeY(bool v) {
    if (_safeY == v) return;
    _safeY = v;
    markNeedsLayout();
  }

  double? _alignX;
  double? get alignX => _alignX;
  set alignX(double? v) {
    if (_alignX == v) return;
    _alignX = v;
    markNeedsLayout();
  }

  double? _alignY;
  double? get alignY => _alignY;
  set alignY(double? v) {
    if (_alignY == v) return;
    _alignY = v;
    markNeedsLayout();
  }

  bool _across;
  bool get across => _across;
  set across(bool v) {
    if (_across == v) return;
    _across = v;
    markNeedsLayout();
  }

  bool _down;
  bool get down => _down;
  set down(bool v) {
    if (_down == v) return;
    _down = v;
    markNeedsLayout();
  }

  Map<Object, RenderBox> _marks;
  Map<Object, RenderBox> get marks => _marks;
  set marks(Map<Object, RenderBox> v) {
    if (identical(_marks, v)) return;
    _marks = v;
    markNeedsLayout();
  }

  Object _id;
  Object get id => _id;
  set id(Object v) {
    if (_id == v) return;
    _id = v;
    markNeedsLayout();
  }

  /// Where in the stack the mark ended up. Nothing, where the mark is not
  /// in this stack at all or has not been laid out -- a page that draws a
  /// positioned box before its flow would rather have it at the corner
  /// than not at all.
  Offset _spotAt(Size own) {
    final mark = _marks[_id];
    if (mark == null || !mark.attached || !mark.hasSize) return Offset.zero;
    RenderObject? stack;
    for (RenderObject? p = parent; p != null; p = p.parent) {
      if (p is RenderStack) {
        stack = p;
        break;
      }
    }
    if (stack == null) return Offset.zero;
    // The mark need not be INSIDE that stack: a `fixed` box is placed in
    // the viewport's stack at the root, and the mark that places it is in
    // the page's flow beside it. `getTransformTo` goes through the two's
    // common ancestor, so the mark's place is read in the stack's own
    // coordinates wherever it is on the page.
    final at = MatrixUtils.transformPoint(
      mark.getTransformTo(stack),
      mark is _Registers ? mark.markPointFor(_id) : Offset.zero,
    );
    // In an AREA, the box is aligned in the rectangle rather than stood at
    // its corner -- and a box wider than the rectangle hangs out of it,
    // because an alignment that is not `safe` lets it (css-align-3 4.4).
    // A `safe` one stands a box that does not fit at the start edge.
    // The MARGIN box is what is aligned, and the child stands its near
    // margin inside it ([SpotShift.margin]).
    final fx = _alignX, fy = _alignY, m = _margin;
    final area = mark is _Registers ? mark.markSize : Size.zero;
    var ox = fx == null
        ? (mark is _Registers && mark.markEnd ? -own.width : 0.0)
        : fx * (area.width - own.width - m.horizontal);
    var oy = fy == null ? 0.0 : fy * (area.height - own.height - m.vertical);
    if (_safeX && ox < 0) ox = 0;
    if (_safeY && oy < 0) oy = 0;
    if (fx != null) ox += m.left;
    if (fy != null) oy += m.top;
    return Offset(_across ? at.dx + ox : 0, _down ? at.dy + oy : 0);
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _fill ? 0 : guardedSize(child, () => child?.getMinIntrinsicWidth(height) ?? 0);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _fill ? 0 : guardedSize(child, () => child?.getMaxIntrinsicWidth(height) ?? 0);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _fill ? 0 : guardedSize(child, () => child?.getMinIntrinsicHeight(width) ?? 0);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _fill ? 0 : guardedSize(child, () => child?.getMaxIntrinsicHeight(width) ?? 0);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => child == null || _fill
      ? constraints.smallest
      : constraints.constrain(guardedSize(child, () => child!.getDryLayout(constraints)));

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    if (_fill) {
      // The area is laid out first: it is in the stack's flow, and a stack
      // lays its flow out before its positioned children. The child is
      // stood at it first, so that a mark inside it is read through the
      // place it stands at.
      final area = _laidArea = _area ?? Size.zero;
      (child.parentData! as BoxParentData).offset = _spotAt(area);
      child.layout(BoxConstraints.tight(area));
      size = constraints.smallest;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(child.size);
    // The size is the box's own; where it is DRAWN is the mark's place,
    // and the stack it sits in does not clip.
    (child.parentData! as BoxParentData).offset = _spotAt(_own);
  }

  /// What is aligned: the child as it reports itself, or what it lays out
  /// where that is past what it reports ([Overhangs]).
  Size get _own => switch (child) {
    final Overhangs o => o.laidOut,
    _ => size,
  };

  /// READ AGAIN HERE, and not only at layout: the mark moves when the
  /// content above it changes height, and that leaves this box's own
  /// constraints exactly as they were -- so `RenderObject.layout` returns
  /// without running, and a shift written only at layout would be the one
  /// from the width before. By paint the whole stack is placed.
  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child != null) (child.parentData! as BoxParentData).offset = _spotAt(_fill ? _laidArea ?? Size.zero : _own);
    // AN AREA THAT CAME OUT ANOTHER SIZE with the stack's own size as it
    // was leaves this box's constraints alone, and its layout with them:
    // laid out again after the frame, where nothing is being laid out or
    // painted that the change could upset.
    if (_fill && child != null) {
      final area = _area;
      if (area != null && area != _laidArea) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (attached) markNeedsLayout();
        });
      }
    }
    super.paint(context, offset);
  }

  /// PRESSED WHERE IT IS DRAWN. The box keeps the place the stack gave it
  /// and the child is drawn at the mark, outside that box; Flutter asks a
  /// child only inside its parent's box, so a press on what was moved went
  /// to whatever lay under it. A recipe app's search field holds a scan
  /// icon laid out at the field's top and drawn 25px down at its middle,
  /// and every press on the icon went to the field. As a `Transform` is,
  /// the child is asked wherever it is drawn, and nothing else is hit.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!hitTestChildren(result, position: position)) return false;
    result.add(BoxHitTestEntry(this, position));
    return true;
  }
}
