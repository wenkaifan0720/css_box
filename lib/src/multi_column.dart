/// A flow set in columns, as a multi-column container sets it.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';

/// A flow of pieces that do not break, set in balanced columns side by
/// side (css-multicol-1).
///
/// A `Column` is ONE column: a flow as tall as everything in it. A
/// multi-column container cuts the same flow into columns as short as they
/// can be, and where it cuts depends on how tall each piece comes out at
/// the column's width. No stock widget measures its children and then
/// chooses where to cut them: a vertical `Wrap` cuts at a height it is
/// handed, and that height is what the cut decides.
///
/// [count] is `column-count` and [width] `column-width`, null for `auto`.
/// How many columns there are and how wide each is follows from the room as
/// css-multicol-1 3.4 works it out: [count] of them where [width] is null;
/// as many at least [width] wide as the room holds, [gap] apart, where
/// [count] is null; and the fewer of the two where both are given. The
/// columns share the room the gaps leave.
///
/// Each child is one PIECE of the flow, laid out at the column's width --
/// tight, as a block of the flow is -- and never cut: a monolithic block
/// (css-break-3 4.4: a replaced box, a scroll container), or a line box --
/// monolithic too -- holding one atomic inline. [spaces] holds the space
/// above each piece: the collapsed margin between it and the piece before,
/// and above the first piece the first piece's own. [end] is the space
/// under the last one. A space that adjoins a column break is truncated
/// (css-break-3 5.5): a piece that starts any column but the first stands
/// at its top.
///
/// [lines] marks the pieces that are line boxes; a run of them is the
/// lines of one paragraph, which a break leaves at least [orphans] of in
/// the column before it and [widows] of in the one after (css-break-3
/// 3.3), where the column can: the break goes up the paragraph to where it
/// does, and where nowhere does, it stays where the column ran out.
/// [MultiColumn.lines] is a flow that is one paragraph.
///
/// THE COLUMNS ARE BALANCED (css-multicol-1 7.1, `column-fill: balance`):
/// as short as they can be with every piece in [count] columns. The first
/// guess is the flow's height over the count, and never under its tallest
/// piece. Where the pieces do not go into that many columns of that height,
/// the guess grows by the least that would have kept one more piece up in
/// the column it left -- the "minimal space shortage" Blink's column
/// balancer stretches its guess by -- until they do. The box is as tall as
/// the columns, and as wide as the room.
class MultiColumn extends MultiChildRenderObjectWidget {
  const MultiColumn({
    super.key,
    this.count,
    this.width,
    this.gap = 0,
    this.spaces = const [],
    this.end = 0,
    List<bool> this.lines = const [],
    this.orphans = 2,
    this.widows = 2,
    this.textDirection,
    super.children,
  });

  /// A flow that is ONE paragraph: every child a line box of it, nothing
  /// between them.
  const MultiColumn.lines({
    super.key,
    this.count,
    this.width,
    this.gap = 0,
    this.orphans = 2,
    this.widows = 2,
    this.textDirection,
    super.children,
  }) : spaces = const [],
       end = 0,
       lines = null;

  /// `column-count`, or null for `auto`.
  final int? count;

  /// `column-width`, or null for `auto`.
  final double? width;

  /// `column-gap`: the room between two columns.
  final double gap;

  /// The space above each child, where it does not start a column after a
  /// break. A child past the end of the list has none.
  final List<double> spaces;

  /// The space under the last child.
  final double end;

  /// Whether each child is a line box; a child past the end of the list is
  /// a block. Null where every child is a line of one paragraph
  /// ([MultiColumn.lines]).
  final List<bool>? lines;

  /// `orphans`: the fewest lines of a paragraph a break leaves before it.
  final int orphans;

  /// `widows`: the fewest lines of a paragraph a break leaves after it.
  final int widows;

  /// Which way the columns run: the first column is at the right under
  /// [TextDirection.rtl]. The ambient [Directionality] where null.
  final TextDirection? textDirection;

  @override
  RenderMultiColumn createRenderObject(BuildContext context) => RenderMultiColumn(
    count: count,
    width: width,
    gap: gap,
    spaces: spaces,
    end: end,
    lines: lines,
    orphans: orphans,
    widows: widows,
    textDirection: textDirection ?? Directionality.maybeOf(context) ?? TextDirection.ltr,
  );

  @override
  void updateRenderObject(BuildContext context, RenderMultiColumn renderObject) {
    renderObject
      ..count = count
      ..width = width
      ..gap = gap
      ..spaces = spaces
      ..end = end
      ..lines = lines
      ..orphans = orphans
      ..widows = widows
      ..textDirection = textDirection ?? Directionality.maybeOf(context) ?? TextDirection.ltr;
  }
}

/// Where a [RenderMultiColumn] puts a child.
class MultiColumnParentData extends ContainerBoxParentData<RenderBox> {}

/// The render object of [MultiColumn].
class RenderMultiColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, MultiColumnParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, MultiColumnParentData>,
        AsksGuarded,
        KeptUnderHatch {
  RenderMultiColumn({
    int? count,
    double? width,
    double gap = 0,
    List<double> spaces = const [],
    double end = 0,
    List<bool>? lines = const [],
    int orphans = 2,
    int widows = 2,
    TextDirection textDirection = TextDirection.ltr,
    List<RenderBox>? children,
  }) : _count = count,
       _width = width,
       _gap = gap,
       _spaces = spaces,
       _end = end,
       _lines = lines,
       _orphans = orphans,
       _widows = widows,
       _textDirection = textDirection {
    addAll(children);
  }

  int? _count;
  int? get count => _count;
  set count(int? value) {
    if (_count == value) return;
    _count = value;
    markNeedsLayout();
  }

  double? _width;
  double? get width => _width;
  set width(double? value) {
    if (_width == value) return;
    _width = value;
    markNeedsLayout();
  }

  double _gap;
  double get gap => _gap;
  set gap(double value) {
    if (_gap == value) return;
    _gap = value;
    markNeedsLayout();
  }

  List<double> _spaces;
  List<double> get spaces => _spaces;
  set spaces(List<double> value) {
    if (listEquals(_spaces, value)) return;
    _spaces = value;
    markNeedsLayout();
  }

  double _end;
  double get end => _end;
  set end(double value) {
    if (_end == value) return;
    _end = value;
    markNeedsLayout();
  }

  List<bool>? _lines;
  List<bool>? get lines => _lines;
  set lines(List<bool>? value) {
    if (identical(_lines, value) || (_lines != null && value != null && listEquals(_lines, value))) return;
    _lines = value;
    markNeedsLayout();
  }

  int _orphans;
  int get orphans => _orphans;
  set orphans(int value) {
    if (_orphans == value) return;
    _orphans = value;
    markNeedsLayout();
  }

  int _widows;
  int get widows => _widows;
  set widows(int value) {
    if (_widows == value) return;
    _widows = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! MultiColumnParentData) child.parentData = MultiColumnParentData();
  }

  double get _gutter => math.max(0.0, _gap);

  /// How many columns there are in [room], and how wide each one is
  /// (css-multicol-1 3.4).
  (int, double) _columns(double room) {
    final g = _gutter;
    final asked = math.max(1, _count ?? 1);
    var n = asked;
    final w = _width;
    if (w != null && room.isFinite) {
      final each = math.max(w, 0.0) + g;
      final fit = each <= 0 ? asked : math.max(1, ((room + g) / each).floor());
      n = _count == null ? fit : math.min(asked, fit);
    }
    return (n, math.max(0.0, (room + g) / n - g));
  }

  /// The room the columns share at [constraints]: all of it, as a block of
  /// the flow takes, and the content's own width where it has no end.
  double _room(BoxConstraints constraints) {
    if (constraints.hasBoundedWidth) return constraints.maxWidth;
    return constraints.constrainWidth(getMaxIntrinsicWidth(double.infinity));
  }

  double _space(int i) => i < _spaces.length ? math.max(0.0, _spaces[i]) : 0.0;

  /// [heights] set in at most [n] columns, balanced (see [MultiColumn]):
  /// how tall the columns are, and the first piece of each. [lines] is
  /// null where every piece is a line of one paragraph.
  @visibleForTesting
  static ({double height, List<int> starts}) balance(
    List<double> heights,
    List<double> spaces,
    double end,
    int n, {
    List<bool>? lines = const [],
    int orphans = 2,
    int widows = 2,
  }) {
    if (heights.isEmpty) return (height: 0.0, starts: const <int>[]);
    final plan = _Plan(heights, spaces, lines, math.max(1, orphans), math.max(1, widows));
    var total = math.max(0.0, end), tallest = 0.0;
    for (var i = 0; i < heights.length; i++) {
      total += plan.space(i) + heights[i];
      tallest = math.max(tallest, heights[i]);
    }
    var height = math.max(total / math.max(1, n), tallest);
    // Each pass keeps at least one more piece up in a column it broke
    // before, so the passes are bounded by the pieces; the bound is only a
    // guard against a height that does not grow by a representable step.
    for (var pass = 0; pass <= heights.length + 1; pass++) {
      final (starts, short) = plan.fill(height);
      if (starts.length <= n || !short.isFinite) return (height: height, starts: starts);
      height += short;
    }
    return (height: height, starts: plan.fill(height).$1);
  }

  List<RenderBox> get _kids {
    final out = <RenderBox>[];
    for (var c = firstChild; c != null; c = childAfter(c)) {
      out.add(c);
    }
    return out;
  }

  ({double height, List<int> starts}) _plan(List<double> heights, int n) =>
      balance(heights, _spaces, _end, n, lines: _lines, orphans: _orphans, widows: _widows);

  @override
  double computeMinIntrinsicWidth(double height) => _intrinsicWidth(least: true);

  @override
  double computeMaxIntrinsicWidth(double height) => _intrinsicWidth(least: false);

  /// The container's least or most width, from its content's (Blink's
  /// `ColumnLayoutAlgorithm::ComputeMinMaxSizes`, after css-sizing-3's
  /// 2016 draft): a column is as wide as its widest piece, and the
  /// container is [count] of them and the gaps between -- except that a
  /// [width] caps the least width at itself and floors the most, and with
  /// a [width] the least width is ONE column, the count and the gaps left
  /// out.
  double _intrinsicWidth({required bool least}) {
    var lo = 0.0, hi = 0.0;
    for (final c in _kids) {
      lo = math.max(lo, guardedSize(c, () => c.getMinIntrinsicWidth(double.infinity)));
      hi = math.max(hi, guardedSize(c, () => c.getMaxIntrinsicWidth(double.infinity)));
    }
    final w = _width;
    if (w != null) {
      lo = math.min(lo, w);
      hi = math.max(math.max(hi, w), lo);
    }
    final n = math.max(1, _count ?? 1);
    final gaps = _gutter * (n - 1);
    if (least) return w == null ? lo * n + gaps : lo;
    return hi * n + gaps;
  }

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(width, least: true);

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(width, least: false);

  double _intrinsicHeight(double width, {required bool least}) {
    final kids = _kids;
    if (kids.isEmpty) return 0;
    final room = width.isFinite ? width : getMaxIntrinsicWidth(double.infinity);
    final (n, w) = _columns(room);
    final heights = [
      for (final c in kids) guardedSize(c, () => least ? c.getMinIntrinsicHeight(w) : c.getMaxIntrinsicHeight(w)),
    ];
    return _plan(heights, n).height;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final kids = _kids;
    final room = _room(constraints);
    if (kids.isEmpty) return constraints.constrain(Size(room, 0));
    final (n, w) = _columns(room);
    final inner = BoxConstraints.tightFor(width: w);
    final plan = _plan([for (final c in kids) guardedSize(c, () => c.getDryLayout(inner)).height], n);
    return constraints.constrain(Size(room, plan.height));
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) {
    final first = firstChild;
    if (first == null) return null;
    final (_, w) = _columns(_room(constraints));
    final b = dryBaselineOf(first, BoxConstraints.tightFor(width: w), baseline);
    return b == null ? null : b + _space(0);
  }

  @override
  void performLayout() {
    final kids = _kids;
    final room = _room(constraints);
    if (kids.isEmpty) {
      size = constraints.constrain(Size(room, 0));
      return;
    }
    final (n, w) = _columns(room);
    final inner = BoxConstraints.tightFor(width: w);
    final heights = <double>[];
    for (final c in kids) {
      c.layout(inner, parentUsesSize: true);
      heights.add(c.size.height);
    }
    final plan = _plan(heights, n);
    final rtl = _textDirection == TextDirection.rtl;
    var column = -1;
    var y = 0.0;
    for (var i = 0; i < kids.length; i++) {
      if (column + 1 < plan.starts.length && plan.starts[column + 1] == i) {
        column++;
        // The space above a piece that starts a column after a break is
        // truncated; the first column keeps the flow's own.
        y = i == 0 ? _space(0) : 0.0;
      } else {
        y += _space(i);
      }
      final x = column * (w + _gutter);
      (kids[i].parentData! as MultiColumnParentData).offset = Offset(rtl ? room - w - x : x, y);
      y += heights[i];
    }
    size = constraints.constrain(Size(room, plan.height));
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('count', _count, defaultValue: null))
      ..add(DoubleProperty('width', _width, defaultValue: null))
      ..add(DoubleProperty('gap', _gap, defaultValue: 0.0))
      ..add(IterableProperty<double>('spaces', _spaces, defaultValue: const <double>[]))
      ..add(DoubleProperty('end', _end, defaultValue: 0.0))
      ..add(FlagProperty('lines', value: _lines == null, ifTrue: 'one paragraph'))
      ..add(IntProperty('orphans', _orphans, defaultValue: 2))
      ..add(IntProperty('widows', _widows, defaultValue: 2))
      ..add(EnumProperty<TextDirection>('textDirection', _textDirection));
  }
}

/// The pieces of a flow, filled into columns of a height.
class _Plan {
  _Plan(this.heights, this.spaces, this.lines, this.orphans, this.widows);

  final List<double> heights, spaces;
  final List<bool>? lines;
  final int orphans, widows;

  /// What a column may run past the height it was given by and still hold
  /// a piece: rounding, not room.
  static const _slack = 1e-6;

  double space(int i) => i < spaces.length ? math.max(0.0, spaces[i]) : 0.0;

  bool _line(int i) {
    final l = lines;
    return l == null || (i < l.length && l[i]);
  }

  /// The paragraph piece [i] is a line of, as the first line and the one
  /// past the last.
  (int, int) _paragraph(int i) {
    var from = i, to = i + 1;
    while (from > 0 && _line(from - 1)) {
      from--;
    }
    while (to < heights.length && _line(to)) {
      to++;
    }
    return (from, to);
  }

  /// Whether a break before piece [b], in a column that starts at piece
  /// [top], is one css-break-3 has nothing against: between two blocks, at
  /// the edge of a paragraph, or inside one with [orphans] of its lines
  /// before the break in this column and [widows] after it.
  bool _clean(int b, int top) {
    if (!_line(b - 1) || !_line(b)) return true;
    final (from, to) = _paragraph(b);
    return b - math.max(from, top) >= orphans && to - b >= widows;
  }

  /// Where the column that starts at [top] breaks, where piece [over] does
  /// not fit in it: the last clean break from [over] up, or [over] itself
  /// where none is.
  int _breakAt(int over, int top) {
    for (var b = over; b > top; b--) {
      if (_clean(b, top)) return b;
    }
    return over;
  }

  /// The pieces filled into columns [height] tall: where each column
  /// starts, and the least more height that would have kept a piece up in
  /// the column before it.
  (List<int>, double) fill(double height) {
    final starts = <int>[0];
    var short = double.infinity;
    var top = 0;
    var used = space(0) + heights[0];
    var i = 1;
    while (i < heights.length) {
      final next = used + space(i) + heights[i];
      if (next <= height + _slack) {
        used = next;
        i++;
        continue;
      }
      short = math.min(short, next - height);
      final b = _breakAt(i, top);
      starts.add(b);
      top = b;
      used = heights[b];
      for (var j = b + 1; j < i; j++) {
        used += space(j) + heights[j];
      }
      i = b == i ? i + 1 : i;
    }
    return (starts, short);
  }
}
