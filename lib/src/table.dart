/// Table layout, after CSS 2.1 17 (the box model and the fixed algorithm)
/// and css-tables-3 (the automatic one, which CSS 2.1 leaves to the UA and
/// every browser implements the same way): a grid of cells whose columns
/// are sized from what they hold and whose rows are sized from their cells.
///
/// A table is not a block container and not a grid. Its columns are sized
/// from every cell in them at once, so no cell can be laid out until the
/// whole table has been measured; its rows are as tall as their tallest
/// cell, and a cell FILLS the row it is in whatever its own content came
/// to. That is why it is a render object of its own rather than a
/// composition: nothing in Flutter sizes a column from its content and then
/// shares the surplus the way css-tables-3 8.2 does.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';
import 'paint_order.dart';
import 'sticky.dart';

/// Where a cell's content sits in the row the cell fills (CSS 2.1 17.5.3).
enum TableAlign {
  top,
  middle,
  bottom,

  /// On the row's own baseline, which is the lowest of its cells'.
  baseline,
}

/// A column's sizing state while the table works out its widths.
class _Col {
  /// The column's min-content width: what its cells hold at their
  /// narrowest. A stated width is not in it (css-tables-3 3.9.1: a cell's
  /// `width` is in its max-content width alone) -- except in a fixed
  /// layout, where the stated widths are all there is.
  double min = 0;
  double max = 0;

  /// A `<col>` or single-span cell `width` in px, and as a share of the
  /// table's content width.
  double? fixed;
  double? share;
  double width = 0;
}

class _Row {
  double y = 0;
  double height = 0;
  double baseline = 0;
  double? stated;
}

/// A box that covers a rectangle of the grid and holds no content of its
/// own: a `<tr>`, a row group, a `<colgroup>` or a `<col>`. It is drawn
/// where the grid puts it and is as big as the tracks it covers -- the
/// background of a striped row, the rule under a section.
///
/// [rows] and [columns] count the tracks covered; `null` is all of them.
class TableBand extends SingleChildRenderObjectWidget {
  const TableBand({
    super.key,
    this.row = 0,
    this.rows,
    this.column = 0,
    this.columns,
    this.width,
    this.widthFactor,
    this.height,
    super.child,
  });

  final int row, column;
  final int? rows, columns;

  /// A `<col>`'s own width, which is a floor under the column it covers.
  final double? width;
  final double? widthFactor;

  /// A `<tr>`'s own height, which is a floor under the row.
  final double? height;

  @override
  RenderTableBand createRenderObject(BuildContext context) => RenderTableBand(
    row: row,
    rows: rows,
    column: column,
    columns: columns,
    width: width,
    widthFactor: widthFactor,
    height: height,
  );

  @override
  void updateRenderObject(BuildContext context, RenderTableBand renderObject) => renderObject
    ..row = row
    ..rows = rows
    ..column = column
    ..columns = columns
    ..width = width
    ..widthFactor = widthFactor
    ..height = height;
}

class RenderTableBand extends RenderProxyBox with ChildDryBaseline, KeptUnderHatch {
  RenderTableBand({
    int row = 0,
    int? rows,
    int column = 0,
    int? columns,
    double? width,
    double? widthFactor,
    double? height,
    RenderBox? child,
  }) : _row = row,
       _rows = rows,
       _column = column,
       _columns = columns,
       _width = width,
       _widthFactor = widthFactor,
       _height = height,
       super(child);

  int get row => _row;
  int _row;
  set row(int v) {
    if (_row == v) return;
    _row = v;
    markNeedsLayout();
  }

  int? get rows => _rows;
  int? _rows;
  set rows(int? v) {
    if (_rows == v) return;
    _rows = v;
    markNeedsLayout();
  }

  int get column => _column;
  int _column;
  set column(int v) {
    if (_column == v) return;
    _column = v;
    markNeedsLayout();
  }

  int? get columns => _columns;
  int? _columns;
  set columns(int? v) {
    if (_columns == v) return;
    _columns = v;
    markNeedsLayout();
  }

  double? get width => _width;
  double? _width;
  set width(double? v) {
    if (_width == v) return;
    _width = v;
    markNeedsLayout();
  }

  double? get widthFactor => _widthFactor;
  double? _widthFactor;
  set widthFactor(double? v) {
    if (_widthFactor == v) return;
    _widthFactor = v;
    markNeedsLayout();
  }

  double? get height => _height;
  double? _height;
  set height(double? v) {
    if (_height == v) return;
    _height = v;
    markNeedsLayout();
  }

  /// Where a band over every row -- a `<col>` or a `<colgroup>`: [rows]
  /// null, [columns] set -- paints, in its own coordinates: the cells that
  /// START in its columns, each whole. CSS 2.1 17.5.1: a column's
  /// background "covers exactly the full area of all cells that originate
  /// in the column, even if they span outside the column". An empty slot,
  /// a slot a cell from another column spans into, and the border-spacing
  /// between cells show what is under the table. A cell that spans out of
  /// the columns reaches past the band's own box, which stays those columns
  /// (the box a `<col>` measures), and the band's background is drawn over
  /// all it covers: a band holds nothing but its background. Null where
  /// those cells cover the band exactly, which paints it as laid out; set by
  /// the table at each layout.
  List<Rect>? get under => _under;
  List<Rect>? _under;
  set under(List<Rect>? v) {
    if (listEquals(_under, v)) return;
    _under = v;
    markNeedsPaint();
  }

  final _clip = LayerHandle<ClipPathLayer>();

  @override
  void paint(PaintingContext context, Offset offset) {
    final under = _under;
    if (under == null) {
      _clip.layer = null;
      return super.paint(context, offset);
    }
    if (under.isEmpty || child == null || size.isEmpty) {
      _clip.layer = null;
      return;
    }
    final own = Offset.zero & size;
    final path = Path();
    var cover = own;
    for (final r in under) {
      path.addRect(r);
      cover = cover.expandToInclude(r);
    }
    _clip.layer = context.pushClipPath(
      needsCompositing,
      offset,
      cover,
      path,
      cover == own
          ? super.paint
          : (context, offset) => context.pushTransform(
              needsCompositing,
              offset + cover.topLeft,
              Matrix4.diagonal3Values(cover.width / size.width, cover.height / size.height, 1),
              super.paint,
            ),
      oldLayer: _clip.layer,
    );
  }

  @override
  void dispose() {
    _clip.layer = null;
    super.dispose();
  }
}

/// One cell of a table -- a `<td>` or a `<th>` -- in the slot the grid
/// gives it.
///
/// The cell's BOX fills its row however short its content is, and the
/// content sits in it the way [align] says, which is what makes a table row
/// a row rather than four boxes of different heights.
class TableSlot extends SingleChildRenderObjectWidget {
  const TableSlot({
    super.key,
    required this.row,
    required this.column,
    this.rowSpan = 1,
    this.colSpan = 1,
    this.align = TableAlign.baseline,
    this.width,
    this.widthFactor,
    this.height,
    this.z = 0,
    super.child,
  });

  final int row, column, rowSpan, colSpan;
  final TableAlign align;

  /// Where the cell paints among the table's cells: by [z], lowest first,
  /// those of one [z] in the order the table holds them, and a press finds
  /// them the other way round. A positioned cell with a `z-index` paints
  /// in that order (CSS 2.1 appendix E), and so do the cells of a
  /// positioned row or row group with one, the stacking context they paint
  /// in: a table head that sticks to the top as the page scrolls, at
  /// `z-index: 2`, paints over the later rows scrolling under it, where in
  /// the order held they would paint over it. A band paints at 0.
  final int z;

  /// A `width` of the cell's own, which is a floor under its column.
  final double? width;

  /// The same, stated as a share of the table's content width.
  final double? widthFactor;

  /// A `height` of the cell's own, which is a floor under its ROW (CSS 2.1
  /// 17.5.3): the cell is as tall as the row comes to, and its content is
  /// aligned in that -- a box of the stated height round the content would
  /// hold the content to the top of it.
  final double? height;

  @override
  RenderTableSlot createRenderObject(BuildContext context) => RenderTableSlot(
    row: row,
    column: column,
    rowSpan: rowSpan,
    colSpan: colSpan,
    align: align,
    width: width,
    widthFactor: widthFactor,
    height: height,
    z: z,
  );

  @override
  void updateRenderObject(BuildContext context, RenderTableSlot renderObject) => renderObject
    ..row = row
    ..column = column
    ..rowSpan = rowSpan
    ..colSpan = colSpan
    ..align = align
    ..width = width
    ..widthFactor = widthFactor
    ..height = height
    ..z = z;
}

class RenderTableSlot extends RenderShiftedBox with AsksGuarded, KeptUnderHatch {
  RenderTableSlot({
    required int row,
    required int column,
    int rowSpan = 1,
    int colSpan = 1,
    TableAlign align = TableAlign.baseline,
    double? width,
    double? widthFactor,
    double? height,
    int z = 0,
    RenderBox? child,
  }) : _row = row,
       _column = column,
       _rowSpan = rowSpan,
       _colSpan = colSpan,
       _align = align,
       _width = width,
       _widthFactor = widthFactor,
       _height = height,
       _z = z,
       super(child);

  /// Where the cell paints among the table's cells ([TableSlot.z]).
  int get z => _z;
  int _z;
  set z(int v) {
    if (_z == v) return;
    _z = v;
    parent?.markNeedsPaint();
  }

  double? get height => _height;
  double? _height;
  set height(double? v) {
    if (_height == v) return;
    _height = v;
    markNeedsLayout();
  }

  int get row => _row;
  int _row;
  set row(int v) {
    if (_row == v) return;
    _row = v;
    markNeedsLayout();
  }

  int get column => _column;
  int _column;
  set column(int v) {
    if (_column == v) return;
    _column = v;
    markNeedsLayout();
  }

  int get rowSpan => _rowSpan;
  int _rowSpan;
  set rowSpan(int v) {
    if (_rowSpan == v) return;
    _rowSpan = v;
    markNeedsLayout();
  }

  int get colSpan => _colSpan;
  int _colSpan;
  set colSpan(int v) {
    if (_colSpan == v) return;
    _colSpan = v;
    markNeedsLayout();
  }

  TableAlign get align => _align;
  TableAlign _align;
  set align(TableAlign v) {
    if (_align == v) return;
    _align = v;
    markNeedsLayout();
  }

  double? get width => _width;
  double? _width;
  set width(double? v) {
    if (_width == v) return;
    _width = v;
    markNeedsLayout();
  }

  double? get widthFactor => _widthFactor;
  double? _widthFactor;
  set widthFactor(double? v) {
    if (_widthFactor == v) return;
    _widthFactor = v;
    markNeedsLayout();
  }

  /// How far down the cell's content sits in it, set by [RenderTableBox]
  /// between the two times it lays the cell out: once at a loose height, to
  /// ask how tall the cell wants to be, and once at the row's height, which
  /// is what the cell comes to.
  double shift = 0;

  /// What the cell came to on its own, and where its first baseline was.
  double natural = 0;
  double? contentBaseline;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final w = constraints.maxWidth;
    final tall = constraints.minHeight >= constraints.maxHeight ? constraints.maxHeight : null;
    if (tall != null) return Size(w, tall);
    return Size(w, child?.getDryLayout(constraints).height ?? 0);
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) =>
      child == null ? null : dryBaselineOf(child!, constraints, baseline);

  @override
  void performLayout() {
    final w = constraints.maxWidth;
    final tall = constraints.minHeight >= constraints.maxHeight ? constraints.maxHeight : null;
    final child = this.child;
    if (child == null) {
      natural = 0;
      contentBaseline = null;
      size = Size(w, tall ?? 0);
      return;
    }
    // The cell's own box FILLS the row, so the row's height is handed
    // straight to it; what the alignment moves is the content inside, which
    // a [TableShift] in there reads back off [shift].
    child.layout(constraints, parentUsesSize: true);
    natural = child.size.height;
    contentBaseline = child.getDistanceToBaseline(TextBaseline.alphabetic, onlyReal: true);
    (child.parentData! as BoxParentData).offset = Offset.zero;
    size = Size(w, tall ?? natural);
  }
}

/// The content of a table cell, which the row's alignment moves without
/// moving the cell.
///
/// A cell fills its row however short its content is, and the content sits
/// at the top, the middle, the bottom, or on the row's shared baseline (CSS
/// 2.1 17.5.3). The box that fills is the cell; the box that moves is this
/// one, inside the cell's padding, and how far it moves is not known until
/// every cell in the row has been measured -- so it is read from the
/// [RenderTableSlot] above at layout rather than written in.
class TableShift extends SingleChildRenderObjectWidget {
  const TableShift({super.key, super.child});

  @override
  RenderTableShift createRenderObject(BuildContext context) => RenderTableShift();
}

class RenderTableShift extends RenderShiftedBox with AsksGuarded, PassesBaseline, KeptUnderHatch {
  RenderTableShift({RenderBox? child}) : super(child);

  double get _shift {
    for (RenderObject? p = parent; p != null; p = p.parent) {
      if (p is RenderTableSlot) return p.shift;
      if (p is RenderTableBox) break;
    }
    return 0;
  }

  BoxConstraints _forChild(BoxConstraints c) =>
      BoxConstraints(minWidth: c.minWidth, maxWidth: c.maxWidth, maxHeight: c.maxHeight);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return constraints.constrain(guardedSize(child, () => child.getDryLayout(_forChild(constraints))));
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) {
    final child = this.child;
    if (child == null) return null;
    return dryBaselineOf(child, _forChild(constraints), baseline);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final b = super.computeDistanceToActualBaseline(baseline);
    return b == null ? null : b + _shift;
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_forChild(constraints), parentUsesSize: true);
    (child.parentData! as BoxParentData).offset = Offset(0, _shift);
    size = constraints.constrain(child.size);
  }
}

/// Rows of a table held to the edges of the view they scroll in, as one
/// box: a `position: sticky` row group (css-position-3 3.4), [rows] rows
/// from [row]. A start inset holds it down from the leading edge, an end
/// inset up from the trailing one, and the table is its block: a pricing
/// table's head of plan names and their buttons stays under the page's bar
/// as the rows go by, and goes up with the last of them. As [Sticky] reads
/// them, the insets are lengths and shares of the scrollport's height.
@immutable
class StickyRows {
  const StickyRows({this.row = 0, this.rows = 1, this.top, this.bottom, this.topShare, this.bottomShare});

  final int row, rows;

  /// The insets, as lengths; null is `auto`, unless its share says more.
  final double? top, bottom;

  /// The insets' shares of the scrollport's height, on top of the lengths.
  final double? topShare, bottomShare;

  @override
  bool operator ==(Object other) =>
      other is StickyRows &&
      other.row == row &&
      other.rows == rows &&
      other.top == top &&
      other.bottom == bottom &&
      other.topShare == topShare &&
      other.bottomShare == bottomShare;

  @override
  int get hashCode => Object.hash(row, rows, top, bottom, topShare, bottomShare);
}

/// The table itself: the cells, and the bands drawn behind them.
///
/// It is the BLOCK of the [Sticky] boxes in its cells, and holds its own
/// [sticky] rows: a cell held as the page scrolls stays in the table, and
/// goes with it once its last row goes by.
class TableBox extends MultiChildRenderObjectWidget {
  const TableBox({
    super.key,
    this.spacing = Size.zero,
    this.fixed = false,
    this.width,
    this.widthFactor,
    this.minWidth,
    this.maxWidth,
    this.height,
    this.sticky = const [],
    super.children,
  });

  /// The rows held to the edges of the view as it scrolls ([StickyRows]).
  final List<StickyRows> sticky;

  /// `border-spacing`, which `border-collapse: collapse` makes zero.
  final Size spacing;

  /// `table-layout: fixed`: the columns are sized from the first row and the
  /// column boxes alone, and every other cell takes what that leaves.
  final bool fixed;

  /// A `width` of the table's own, which is a FLOOR rather than the width: a
  /// table never gets narrower than its columns' minimums (CSS 2.1 17.5.2).
  final double? width;
  final double? widthFactor;
  final double? minWidth, maxWidth;

  /// A `height` of the table's own, whose surplus its rows share.
  final double? height;

  @override
  RenderTableBox createRenderObject(BuildContext context) => RenderTableBox(
    spacing: spacing,
    fixed: fixed,
    width: width,
    widthFactor: widthFactor,
    minWidth: minWidth,
    maxWidth: maxWidth,
    height: height,
    sticky: sticky,
    scrolls: sticky.isEmpty ? const [] : scrollsRound(context),
    textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
  );

  @override
  void updateRenderObject(BuildContext context, RenderTableBox renderObject) => renderObject
    ..sticky = sticky
    ..scrolls = sticky.isEmpty ? const [] : scrollsRound(context)
    ..textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr
    ..spacing = spacing
    ..fixed = fixed
    ..width = width
    ..widthFactor = widthFactor
    ..minWidth = minWidth
    ..maxWidth = maxWidth
    ..height = height;
}

class TableBoxParentData extends ContainerBoxParentData<RenderBox> {}

class RenderTableBox extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, TableBoxParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, TableBoxParentData>,
        KeptUnderHatch,
        PaintOrder,
        HearsScrolls
    implements HoldsSticky {
  RenderTableBox({
    Size spacing = Size.zero,
    bool fixed = false,
    double? width,
    double? widthFactor,
    double? minWidth,
    double? maxWidth,
    double? height,
    List<StickyRows> sticky = const [],
    List<ViewportOffset> scrolls = const [],
    TextDirection textDirection = TextDirection.ltr,
    List<RenderBox>? children,
  }) : _sticky = sticky,
       _spacing = spacing,
       _textDirection = textDirection,
       _fixed = fixed,
       _width = width,
       _widthFactor = widthFactor,
       _minWidth = minWidth,
       _maxWidth = maxWidth,
       _height = height {
    this.scrolls = scrolls;
    addAll(children);
  }

  /// The rows held as the view scrolls ([TableBox.sticky]).
  List<StickyRows> get sticky => _sticky;
  List<StickyRows> _sticky;
  set sticky(List<StickyRows> v) {
    if (listEquals(_sticky, v)) return;
    _sticky = v;
    markNeedsPaint();
  }

  /// The table is its cells' block, with nothing between ([HoldsSticky]):
  /// its own padding and border are round it.
  @override
  EdgeInsets get inset => EdgeInsets.zero;

  /// Where each row starts and ends down the table, as last laid out.
  List<double> _rowTops = const [], _rowEnds = const [];

  /// The table's `direction`, from the [Directionality] round it: right to
  /// left the first column is the rightmost (CSS 2.1 17.5), and every cell
  /// and band is mirrored across the table.
  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection v) {
    if (_textDirection == v) return;
    _textDirection = v;
    markNeedsLayout();
  }

  Size get spacing => _spacing;
  Size _spacing;
  set spacing(Size v) {
    if (_spacing == v) return;
    _spacing = v;
    markNeedsLayout();
  }

  bool get fixed => _fixed;
  bool _fixed;
  set fixed(bool v) {
    if (_fixed == v) return;
    _fixed = v;
    markNeedsLayout();
  }

  double? get width => _width;
  double? _width;
  set width(double? v) {
    if (_width == v) return;
    _width = v;
    markNeedsLayout();
  }

  double? get widthFactor => _widthFactor;
  double? _widthFactor;
  set widthFactor(double? v) {
    if (_widthFactor == v) return;
    _widthFactor = v;
    markNeedsLayout();
  }

  double? get minWidth => _minWidth;
  double? _minWidth;
  set minWidth(double? v) {
    if (_minWidth == v) return;
    _minWidth = v;
    markNeedsLayout();
  }

  double? get maxWidth => _maxWidth;
  double? _maxWidth;
  set maxWidth(double? v) {
    if (_maxWidth == v) return;
    _maxWidth = v;
    markNeedsLayout();
  }

  double? get height => _height;
  double? _height;
  set height(double? v) {
    if (_height == v) return;
    _height = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! TableBoxParentData) child.parentData = TableBoxParentData();
  }

  RenderBox? _next(RenderBox child) => (child.parentData! as TableBoxParentData).nextSibling;

  List<RenderTableSlot> get _cells {
    final out = <RenderTableSlot>[];
    for (var child = firstChild; child != null; child = _next(child)) {
      if (child is RenderTableSlot) out.add(child);
    }
    return out;
  }

  int get _columnCount {
    var n = 0;
    for (var child = firstChild; child != null; child = _next(child)) {
      if (child is RenderTableSlot) {
        n = math.max(n, child.column + child.colSpan);
      } else if (child is RenderTableBand && child.columns != null) {
        n = math.max(n, child.column + child.columns!);
      }
    }
    return n;
  }

  int get _rowCount {
    var n = 0;
    for (var child = firstChild; child != null; child = _next(child)) {
      if (child is RenderTableSlot) {
        n = math.max(n, child.row + child.rowSpan);
      } else if (child is RenderTableBand && child.rows != null) {
        n = math.max(n, child.row + child.rows!);
      }
    }
    return n;
  }

  /// The columns, sized from what their cells hold (css-tables-3 8.1).
  List<_Col> _measure(int columns) {
    final cols = [for (var i = 0; i < columns; i++) _Col()];
    if (columns == 0) return cols;
    // A `<col>`'s own width is what the column it covers asks for.
    for (var child = firstChild; child != null; child = _next(child)) {
      if (child is! RenderTableBand || child.columns != 1 || child.column >= columns) continue;
      final col = cols[child.column];
      if (child.width != null) col.fixed = math.max(col.fixed ?? 0, child.width!);
      if (child.widthFactor != null) col.share = math.max(col.share ?? 0, child.widthFactor!);
    }
    for (final cell in _cells) {
      if (fixed && cell.row != 0) continue;
      if (cell.colSpan == 1 && cell.column < columns) {
        final col = cols[cell.column];
        if (cell.width != null) col.fixed = math.max(col.fixed ?? 0, cell.width!);
        if (cell.widthFactor != null) col.share = math.max(col.share ?? 0, cell.widthFactor!);
      }
      if (fixed) continue;
      if (cell.colSpan == 1 && cell.column < columns) {
        final col = cols[cell.column];
        guardedSize(cell, () {
          col.min = math.max(col.min, cell.getMinIntrinsicWidth(double.infinity));
          col.max = math.max(col.max, math.max(cell.getMaxIntrinsicWidth(double.infinity), cell.width ?? 0));
        });
      }
    }
    if (!fixed) {
      // A spanning cell's content is a floor on the columns it covers,
      // spread over them in proportion to what they ask for already
      // (css-tables-3 8.1, "distributing width to spanned columns").
      for (final cell in _cells) {
        if (cell.colSpan == 1) continue;
        final span = [for (var i = cell.column; i < cell.column + cell.colSpan && i < columns; i++) cols[i]];
        if (span.isEmpty) continue;
        final gaps = spacing.width * (span.length - 1);
        guardedSize(cell, () {
          _spread(span, cell.getMinIntrinsicWidth(double.infinity) - gaps, (c) => c.min, (c, v) => c.min = v);
          _spread(span, cell.getMaxIntrinsicWidth(double.infinity) - gaps, (c) => c.max, (c, v) => c.max = v);
        });
      }
    }
    for (final col in cols) {
      if (col.fixed != null) {
        if (fixed) col.min = math.max(col.min, col.fixed!);
        col.max = math.max(col.max, col.fixed!);
      }
      col.max = math.max(col.max, col.min);
    }
    return cols;
  }

  /// The width the table comes to in [room], and its columns at that width.
  ///
  /// A TIGHT [room] IS A WIDTH THE TABLE WAS GIVEN, not room to shrink into.
  /// A table is shrink-to-fit in a block flow (CSS 2.1 17.5.2) and is only
  /// ever handed a tight width by a box that already worked one out for it
  /// -- a `width: 100%` table in a stretching column, a `width: 50%` one
  /// under the fraction that took its share -- and the grid inside it then
  /// shares THAT out rather than shrinking inside it.
  (double, List<_Col>) _widths(double room, {bool given = false}) {
    final columns = _columnCount;
    final cols = _measure(columns);
    final spacingWidth = spacing.width * (columns + 1);
    final gridMin = cols.fold(0.0, (a, c) => a + c.min) + spacingWidth;
    final gridMax = cols.fold(0.0, (a, c) => a + c.max) + spacingWidth;
    final stated =
        width ??
        (widthFactor != null && room.isFinite ? widthFactor! * room : null) ??
        (given && room.isFinite ? room : null);
    var table = stated != null
        ? math.max(stated, fixed ? 0.0 : gridMin)
        : math.max(gridMin, math.min(gridMax, room.isFinite ? room : gridMax));
    if (maxWidth != null) table = math.min(table, maxWidth!);
    if (minWidth != null) table = math.max(table, minWidth!);
    final content = math.max(table - spacingWidth, 0.0);
    if (fixed) {
      // CSS 2.1 17.5.2.1: the columns the markup sizes take their width; the
      // rest share what is left, equally.
      var used = 0.0, autoCount = 0;
      for (final col in cols) {
        if (col.share != null) {
          col.width = content * col.share!;
        } else if (col.fixed != null) {
          col.width = col.fixed!;
        } else {
          autoCount++;
          continue;
        }
        used += col.width;
      }
      // PERCENTAGES THAT DO NOT FIT BESIDE THE PX COLUMNS SHRINK INTO THE
      // ROOM THOSE LEAVE, in proportion, and to nothing where the px columns
      // fill the table. CSS 2.1 17.5.2.1 says nothing of columns that ask
      // for more than the table has; Chrome keeps the px columns and scales
      // the percentages: a 500 wide table of `<col>`s of 200px, 50% and 50%
      // draws them 200, 150 and 150 -- not 200, 250 and 250, running 200
      // past its edge -- and a column with no width beside them gets none.
      var sized = 0.0, shares = 0.0;
      for (final col in cols) {
        if (col.share != null) {
          shares += col.width;
        } else if (col.fixed != null) {
          sized += col.width;
        }
      }
      if (shares > 0 && sized + shares > content) {
        final k = math.max(content - sized, 0.0) / shares;
        for (final col in cols) {
          if (col.share != null) col.width *= k;
        }
        used = sized + shares * k;
      }
      final share = autoCount == 0 ? 0.0 : math.max(content - used, 0.0) / autoCount;
      for (final col in cols) {
        if (col.share == null && col.fixed == null) col.width = share;
      }
      if (autoCount == 0 && used > 0 && content > used) {
        final scale = content / used;
        for (final col in cols) {
          col.width *= scale;
        }
      }
    } else {
      _distribute(cols, content);
    }
    return (table, cols);
  }

  double _columnOffset(List<_Col> cols, int index) {
    var x = 0.0;
    for (var i = 0; i < index && i < cols.length; i++) {
      x += cols[i].width + spacing.width;
    }
    return x;
  }

  double _columnSpan(List<_Col> cols, int start, int span) {
    var w = 0.0;
    for (var i = start; i < start + span && i < cols.length; i++) {
      w += cols[i].width;
    }
    return w + spacing.width * (span - 1);
  }

  /// CSS 2.1 17.5.2: a table is never narrower than its grid, and a stated
  /// width is what it comes to when the grid fits inside it. The intrinsic
  /// widths say the same thing, so a shrink-to-fit parent hands the table the
  /// width the markup asked for instead of the width its text happens to want.
  double _stated(double grid) {
    var table = width != null ? math.max(width!, fixed ? 0.0 : grid) : grid;
    if (maxWidth != null) table = math.min(table, maxWidth!);
    if (minWidth != null) table = math.max(table, minWidth!);
    return table;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final columns = _columnCount;
    return _stated(_measure(columns).fold(0.0, (a, c) => a + c.min) + spacing.width * (columns + 1));
  }

  /// A TABLE THAT STATES ITS WIDTH IS THAT WIDE AT ITS WIDEST TOO: what
  /// its columns would take at their max-content is shared out inside the
  /// width (css-tables-3 3.9.3), and only its min-content widens it (CSS
  /// 2.1 17.5.2). Answered as its grid's max-content, a `width: 500px`
  /// table of `<col>`s of 100 beside a column of 238 came out 538 in the
  /// `ShrinkWidth` round it, the grid 500 inside
  /// (`fixtures/table-col-width-squeezed` p1).
  @override
  double computeMaxIntrinsicWidth(double height) {
    final columns = _columnCount;
    final cols = _measure(columns);
    final grid = width != null ? cols.fold(0.0, (a, c) => a + c.min) : cols.fold(0.0, (a, c) => a + c.max);
    return _stated(grid + spacing.width * (columns + 1));
  }

  @override
  double computeMinIntrinsicHeight(double width) => _layout(BoxConstraints(maxWidth: width), dry: true).height;

  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => _layout(constraints, dry: true);

  @override
  void performLayout() {
    size = _layout(constraints, dry: false);
  }

  /// The rows, at the widths the columns came to, and then everything in
  /// its place.
  Size _layout(BoxConstraints constraints, {required bool dry}) {
    final columns = _columnCount;
    if (columns == 0) return constraints.constrain(Size.zero);
    final (table, cols) = _widths(constraints.maxWidth, given: constraints.hasTightWidth);
    final rowCount = _rowCount;
    final rows = [for (var i = 0; i < rowCount; i++) _Row()];
    for (var child = firstChild; child != null; child = _next(child)) {
      if (child is RenderTableBand && child.rows == 1 && child.height != null && child.row < rowCount) {
        final row = rows[child.row];
        row.stated = math.max(row.stated ?? 0, child.height!);
      }
      if (child is RenderTableSlot && child.rowSpan == 1 && child.height != null && child.row < rowCount) {
        final row = rows[child.row];
        row.stated = math.max(row.stated ?? 0, child.height!);
      }
    }

    // A cell is laid out at its columns' width; the row is as tall as its
    // tallest cell. The cells that share a baseline have to hold the
    // DEEPEST of them and the tallest tail below it, which is more than any
    // one of them is tall (CSS 2.1 17.5.3).
    final cells = _cells;
    final heights = <RenderTableSlot, double>{};
    final baselines = <RenderTableSlot, double?>{};
    for (var i = 0; i < rowCount; i++) {
      var height = 0.0, baseline = 0.0, below = 0.0;
      for (final cell in cells) {
        if (cell.row != i) continue;
        final w = _columnSpan(cols, cell.column, cell.colSpan);
        final room = BoxConstraints(minWidth: w, maxWidth: w);
        double h;
        double? b;
        if (dry) {
          h = guardedSize(cell, () => cell.getDryLayout(room)).height;
          // ONLY A CELL ON THE ROW'S BASELINE IS ASKED ITS OWN. A top,
          // middle or bottom cell, or one over several rows, is placed by
          // its height (17.5.3), and asked dry its baseline asks every box
          // in it again: a market table's 510 middle-aligned cells, asked at
          // every dry pass of the table, were half of each layout of its
          // page, and nothing read what they answered.
          b = cell.align == TableAlign.baseline && cell.rowSpan == 1
              ? dryBaselineOf(cell, room, TextBaseline.alphabetic)
              : null;
        } else {
          cell.shift = 0;
          cell.layout(room, parentUsesSize: true);
          h = cell.natural;
          b = cell.contentBaseline;
        }
        heights[cell] = h;
        baselines[cell] = b;
        if (cell.rowSpan != 1) continue;
        if (cell.align == TableAlign.baseline && b != null) {
          baseline = math.max(baseline, b);
          below = math.max(below, h - b);
        } else {
          height = math.max(height, h);
        }
      }
      rows[i].height = math.max(math.max(height, baseline + below), rows[i].stated ?? 0);
      rows[i].baseline = baseline;
    }
    // A row-spanning cell only grows the rows it covers if they are short.
    for (final cell in cells) {
      if (cell.rowSpan == 1) continue;
      final covered = [for (var j = cell.row; j < cell.row + cell.rowSpan && j < rowCount; j++) rows[j]];
      if (covered.isEmpty) continue;
      final have = covered.fold(0.0, (a, r) => a + r.height) + spacing.height * (covered.length - 1);
      // The cell's own stated height is a floor under the rows it spans.
      final want = math.max(heights[cell] ?? 0, cell.height ?? 0);
      if (want <= have) continue;
      final extra = (want - have) / covered.length;
      for (final r in covered) {
        r.height += extra;
      }
    }

    // A table taller than its rows hands the difference to them (17.5.3).
    var grid = rows.fold(0.0, (a, r) => a + r.height) + spacing.height * (rowCount + 1);
    if (height != null && rowCount > 0 && height! > grid) {
      final extra = (height! - grid) / rowCount;
      for (final r in rows) {
        r.height += extra;
      }
      grid = height!;
    }
    final size = constraints.constrain(Size(table, grid));
    if (dry) return size;

    var y = spacing.height;
    for (var i = 0; i < rowCount; i++) {
      rows[i].y = y;
      y += rows[i].height + spacing.height;
    }
    _rowTops = [for (final r in rows) r.y];
    _rowEnds = [for (final r in rows) r.y + r.height];
    double spanned(int start, int span) {
      var h = 0.0;
      for (var j = start; j < start + span && j < rowCount; j++) {
        h += rows[j].height + (j > start ? spacing.height : 0);
      }
      return h;
    }

    // Where a thing [w] wide that starts [x] in from the table's start edge
    // stands from its left.
    double across(double x, double w) => textDirection == TextDirection.rtl ? size.width - x - w : x;

    for (final cell in cells) {
      if (cell.row >= rowCount) continue;
      final row = rows[cell.row];
      final tall = spanned(cell.row, cell.rowSpan);
      final b = baselines[cell];
      final natural = heights[cell] ?? 0;
      cell.shift = switch (cell.align) {
        TableAlign.top => 0.0,
        TableAlign.middle => (tall - natural) / 2,
        TableAlign.bottom => tall - natural,
        TableAlign.baseline => b == null ? 0.0 : row.baseline - b,
      };
      final w = _columnSpan(cols, cell.column, cell.colSpan);
      // A height as well as a width this time: it is what the cell comes to
      // AND what tells Flutter the cell has to be laid out again.
      cell.layout(BoxConstraints.tightFor(width: w, height: tall), parentUsesSize: true);
      (cell.parentData! as TableBoxParentData).offset = Offset(
        across(spacing.width + _columnOffset(cols, cell.column), w),
        row.y,
      );
    }

    // The column each slot's cell starts in (-1 where none), read by the
    // `<col>` and `<colgroup>` bands ([RenderTableBand.under]).
    List<int>? origins;
    for (var child = firstChild; child != null; child = _next(child)) {
      if (child is! RenderTableBand) continue;
      final startRow = child.rows == null ? 0 : child.row;
      final startCol = child.columns == null ? 0 : child.column;
      final top = child.rows == null ? spacing.height : (startRow < rowCount ? rows[startRow].y : y);
      final tall = child.rows == null ? math.max(grid - spacing.height * 2, 0.0) : spanned(startRow, child.rows!);
      final wide = child.columns == null
          ? math.max(table - spacing.width * 2, 0.0)
          : _columnSpan(cols, startCol, child.columns!);
      final box = Offset(across(spacing.width + _columnOffset(cols, startCol), wide), top) & Size(wide, tall);
      List<Rect>? under;
      if (child.rows == null && child.columns != null) {
        // A `<col>` or `<colgroup>` covers the cells that start in it
        // ([RenderTableBand.under]): where they leave a slot, or a gap of
        // spacing, it paints round them; where one spans out of it, it
        // paints over that cell too.
        origins ??= _origins(cells, rowCount, columns);
        final endCol = startCol + child.columns!;
        final mine = [
          for (final cell in cells)
            if (cell.row < rowCount && cell.column >= startCol && cell.column < endCol) cell,
        ];
        var whole = (rowCount < 2 || spacing.height == 0) && (child.columns! < 2 || spacing.width == 0);
        for (final cell in mine) {
          if (cell.column + cell.colSpan > endCol) whole = false;
        }
        for (var r = 0; whole && r < rowCount; r++) {
          for (var c = startCol; whole && c < endCol && c < columns; c++) {
            final o = origins[r * columns + c];
            if (o < startCol || o >= endCol) whole = false;
          }
        }
        if (!whole) {
          under = [
            for (final cell in mine) ((cell.parentData! as TableBoxParentData).offset & cell.size).shift(-box.topLeft),
          ];
        }
      }
      child.under = under;
      child.layout(BoxConstraints.tightFor(width: box.width, height: box.height));
      (child.parentData! as TableBoxParentData).offset = box.topLeft;
    }
    return size;
  }

  /// The column the cell over each slot of the grid starts in, row by row
  /// ([columns] to a row); -1 where no cell covers it.
  static List<int> _origins(List<RenderTableSlot> cells, int rows, int columns) {
    final out = List<int>.filled(rows * columns, -1);
    for (final cell in cells) {
      for (var r = cell.row; r < cell.row + cell.rowSpan && r < rows; r++) {
        for (var c = cell.column; c < cell.column + cell.colSpan && c < columns; c++) {
          out[r * columns + c] = cell.column;
        }
      }
    }
    return out;
  }

  /// A table stands on the baseline of the first row that has one
  /// (CSS 2.1 10.8.1).
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    for (final cell in _cells) {
      if (cell.row != 0) continue;
      final b = cell.getDistanceToActualBaseline(baseline);
      if (b != null) return b + (cell.parentData! as TableBoxParentData).offset.dy;
    }
    return null;
  }

  // ------------------------------------------------------------------ paint

  static int _zOf(RenderBox child) => child is RenderTableSlot ? child.z : 0;

  bool get _stacked {
    if (_sticky.isNotEmpty) return true;
    for (var c = firstChild; c != null; c = childAfter(c)) {
      if (_zOf(c) != 0) return true;
    }
    return false;
  }

  /// The held rows ([sticky]) [child] is in: a cell of one, or a band
  /// across no row outside it; null where none.
  StickyRows? _heldOf(RenderBox child) {
    if (_sticky.isEmpty) return null;
    final (from, to) = switch (child) {
      RenderTableSlot c => (c.row, c.row + 1),
      RenderTableBand b when b.rows != null => (b.row, b.row + b.rows!),
      _ => (-1, -1),
    };
    if (from < 0) return null;
    for (final h in _sticky) {
      if (from >= h.row && to <= h.row + h.rows) return h;
    }
    return null;
  }

  /// How far the rows [h] are drawn down from where they were laid out:
  /// the least that keeps them inside the scrollport's edges moved in by
  /// their insets ([stickyPortOf]), and never out of the table, which caps
  /// the shift without reversing it -- as [RenderSticky.shift] holds a box.
  double _shiftOf(StickyRows h) {
    final last = math.min(h.row + h.rows, _rowTops.length) - 1;
    if (!attached || !hasSize || h.row < 0 || h.row > last) return 0;
    final port = stickyPortOf(this);
    if (port == null || !port.hasSize) return 0;
    final table = MatrixUtils.transformPoint(getTransformTo(port), Offset.zero).dy;
    final top = table + _rowTops[h.row], end = table + _rowEnds[last];
    final room = port.size.height;
    double? inset(double? length, double? share) =>
        length == null && share == null ? null : (length ?? 0) + (share ?? 0) * room;
    final t = inset(h.top, h.topShare), b = inset(h.bottom, h.bottomShare);
    var dy = 0.0;
    if (t != null) dy = math.max(0.0, t - top);
    if (dy == 0.0 && b != null) dy = math.min(0.0, (room - b) - end);
    return dy > 0 ? math.min(dy, math.max(0.0, table + size.height - end)) : math.max(dy, math.min(0.0, table - top));
  }

  /// How far [child] is drawn down from where it was laid out: the shift of
  /// the held rows it is in ([sticky]), or none.
  double heldShiftOf(RenderBox child) {
    final h = _heldOf(child);
    return h == null ? 0 : _shiftOf(h);
  }

  /// The children in paint order: the cells by [RenderTableSlot.z], the
  /// bands at 0, those of one z in the order held -- but the held rows'
  /// ([sticky]) after the rest at their z, as a positioned box paints after
  /// the boxes of the flow (CSS 2.1 appendix E).
  @override
  List<RenderBox> get paintOrder => _painted();

  List<RenderBox> _painted() {
    final kids = <(int, int, int, RenderBox)>[];
    var i = 0;
    for (var c = firstChild; c != null; c = childAfter(c)) {
      kids.add((_zOf(c), _heldOf(c) == null ? 0 : 1, i++, c));
    }
    kids.sort(
      (a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : (a.$2 != b.$2 ? a.$2.compareTo(b.$2) : a.$3.compareTo(b.$3)),
    );
    return [for (final k in kids) k.$4];
  }

  Offset _drawnAt(RenderBox child) {
    final at = (child.parentData! as TableBoxParentData).offset;
    final dy = heldShiftOf(child);
    return dy == 0 ? at : at.translate(0, dy);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_stacked) return defaultPaint(context, offset);
    for (final child in _painted()) {
      context.paintChild(child, _drawnAt(child) + offset);
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final at = _drawnAt(child);
    transform.multiply(Matrix4.translationValues(at.dx, at.dy, 0));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (!_stacked) return defaultHitTestChildren(result, position: position);
    for (final child in _painted().reversed) {
      final hit = result.addWithPaintOffset(
        offset: _drawnAt(child),
        position: position,
        hitTest: (r, p) => child.hitTest(r, position: p),
      );
      if (hit) return true;
    }
    return false;
  }
}

/// Raise the columns' values so they sum to at least [target], in proportion
/// to what they hold already.
void _spread(List<_Col> span, double target, double Function(_Col) get, void Function(_Col, double) set) {
  final have = span.fold(0.0, (a, c) => a + get(c));
  if (have >= target || target <= 0) return;
  final extra = target - have;
  if (have <= 0) {
    for (final c in span) {
      set(c, get(c) + extra / span.length);
    }
    return;
  }
  for (final c in span) {
    set(c, get(c) + extra * get(c) / have);
  }
}

/// css-tables-3 3.9.3: the table's content width over its columns -- between
/// their minimum and maximum content widths, then any surplus in proportion
/// to what each column would take at most.
///
/// A TABLE TOO NARROW FOR ITS STATED WIDTHS SQUEEZES THEM. The columns are
/// sized from GUESSES: every column at its min-content width; then each
/// percentage column at its share; then each column that states a width at
/// that width (its min-content where that is more); then every column at
/// its max-content width. A width between two guesses is the same linear
/// mix of the two for every column, so below the third guess a stated
/// column gives up as much of its width as the table is short of it, and a
/// column that states none keeps its min-content width. A market tracker's
/// `width: 100%` price table of `<col>`s of 50 to 200 held every stated
/// width and left its names 240 of their 298: each broke over two or three
/// lines, the table 542px too long (`fixtures/table-col-width-squeezed`).
void _distribute(List<_Col> cols, double width) {
  double pct(_Col c) => math.max(c.min, width * c.share!);
  final g0 = [for (final c in cols) c.min];
  final g1 = [for (final c in cols) c.share != null ? pct(c) : c.min];
  final g2 = [for (final c in cols) c.share != null ? pct(c) : (c.fixed != null ? math.max(c.min, c.fixed!) : c.min)];
  double sum(List<double> g) => g.fold(0.0, (a, v) => a + v);
  final s0 = sum(g0), s1 = sum(g1), s2 = sum(g2);
  if (width < s2 - 1e-9) {
    final (lo, hi, a, b) = width < s1 - 1e-9 ? (g0, g1, s0, s1) : (g1, g2, s1, s2);
    final t = b - a <= 0 ? 0.0 : ((width - a) / (b - a)).clamp(0.0, 1.0);
    for (var i = 0; i < cols.length; i++) {
      cols[i].width = lo[i] + t * (hi[i] - lo[i]);
    }
    return;
  }
  for (var i = 0; i < cols.length; i++) {
    cols[i].width = g2[i];
  }
  var remaining = width - s2;
  if (remaining <= 0) return;
  final auto = [
    for (final c in cols)
      if (c.share == null) c,
  ];
  if (auto.isEmpty) {
    final total = cols.fold(0.0, (a, c) => a + c.width);
    if (total > 0) {
      for (final c in cols) {
        c.width += remaining * c.width / total;
      }
    }
    return;
  }
  // What each column may still take before its max-content width: from
  // the third guess, where a stated column already stands at its width.
  final room = {for (final c in auto) c: math.max(0.0, c.max - c.width)};
  final slack = room.values.fold(0.0, (a, v) => a + v);
  if (slack > 0) {
    final take = math.min(remaining, slack);
    for (final c in auto) {
      c.width += take * room[c]! / slack;
    }
    remaining -= take;
  }
  if (remaining <= 0) return;
  // Space beyond every column's max-content goes to the columns the markup
  // did NOT size (CSS 2.1 17.5.2.2): a `width: 300px` cell in a 600px table
  // stays 300 and the auto column beside it takes the other 300. Only when
  // every column is sized does the surplus spread over all of them.
  final loose = [
    for (final c in auto)
      if (c.fixed == null) c,
  ];
  final take = loose.isEmpty ? auto : loose;
  final maxTotal = take.fold(0.0, (a, c) => a + c.max);
  for (final c in take) {
    c.width += maxTotal > 0 ? remaining * c.max / maxTotal : remaining / take.length;
  }
}

/// A table's CAPTIONS round its box (CSS 2.1 17.4): the table wrapper box,
/// which holds the table box -- the grid, with the table's own border,
/// padding and background -- and the caption boxes over it ([above],
/// `caption-side: top`) or under it ([below]), each a block as wide as the
/// wrapper. The table's margins are the wrapper's, and go round this.
///
/// The wrapper is as wide as the table box, or as the widest caption's
/// MIN-CONTENT width where that is more (css-tables-3, CAPMIN): a
/// caption wraps at the table's width and widens it only by what it cannot
/// break, and the table box then fills the wider wrapper, sharing the
/// surplus over its columns. So it answers its max-content width as the
/// larger of the table's max-content and the captions' min-content -- a
/// caption's max-content widens nothing.
///
/// A caption's margins are inside the wrapper and collapse with nothing:
/// the lowering puts them round the caption.
class TableCaptions extends MultiChildRenderObjectWidget {
  TableCaptions({super.key, List<Widget> above = const [], required Widget table, List<Widget> below = const []})
    : _above = above.length,
      super(children: [...above, table, ...below]);

  final int _above;

  @override
  RenderTableCaptions createRenderObject(BuildContext context) => RenderTableCaptions(above: _above);

  @override
  void updateRenderObject(BuildContext context, RenderTableCaptions renderObject) => renderObject.above = _above;
}

class TableCaptionsParentData extends ContainerBoxParentData<RenderBox> {}

/// The render object behind [TableCaptions].
class RenderTableCaptions extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, TableCaptionsParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, TableCaptionsParentData>,
        AsksGuarded,
        KeptUnderHatch {
  RenderTableCaptions({required int above}) : _above = above;

  /// How many of the children are captions over the table; the next is the
  /// table box, the rest the captions under it.
  int get above => _above;
  int _above;
  set above(int v) {
    if (v == _above) return;
    _above = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! TableCaptionsParentData) child.parentData = TableCaptionsParentData();
  }

  RenderBox get _table {
    var c = firstChild!;
    for (var i = 0; i < _above; i++) {
      c = childAfter(c)!;
    }
    return c;
  }

  Iterable<RenderBox> get _captions sync* {
    final table = _table;
    for (var c = firstChild; c != null; c = childAfter(c)) {
      if (!identical(c, table)) yield c;
    }
  }

  /// CAPMIN: the widest caption's min-content width.
  double get _capMin =>
      _captions.fold(0.0, (a, c) => math.max(a, guardedSize(c, () => c.getMinIntrinsicWidth(double.infinity))));

  @override
  double computeMinIntrinsicWidth(double height) =>
      math.max(guardedSize(_table, () => _table.getMinIntrinsicWidth(double.infinity)), _capMin);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      math.max(guardedSize(_table, () => _table.getMaxIntrinsicWidth(double.infinity)), _capMin);

  double _height(double width, double Function(RenderBox, double) of) {
    var h = 0.0;
    for (var c = firstChild; c != null; c = childAfter(c)) {
      h += of(c, width);
    }
    return h;
  }

  @override
  double computeMinIntrinsicHeight(double width) => _height(width, (c, w) => c.getMinIntrinsicHeight(w));

  @override
  double computeMaxIntrinsicHeight(double width) => _height(width, (c, w) => c.getMaxIntrinsicHeight(w));

  /// The table box's constraints: never narrower than CAPMIN, where the
  /// room allows.
  BoxConstraints _forTable(BoxConstraints constraints) {
    final floor = math.min(_capMin, constraints.maxWidth);
    return BoxConstraints(minWidth: math.max(constraints.minWidth, floor), maxWidth: constraints.maxWidth);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final w = guardedSize(_table, () => _table.getDryLayout(_forTable(constraints))).width;
    var h = 0.0;
    for (var c = firstChild; c != null; c = childAfter(c)) {
      final k = c;
      h += guardedSize(k, () => k.getDryLayout(BoxConstraints.tightFor(width: w))).height;
    }
    return constraints.constrain(Size(w, h));
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) {
    final table = _table;
    final w = guardedSize(table, () => table.getDryLayout(_forTable(constraints))).width;
    var y = 0.0;
    for (var c = firstChild; c != null && !identical(c, table); c = childAfter(c)) {
      final k = c;
      y += guardedSize(k, () => k.getDryLayout(BoxConstraints.tightFor(width: w))).height;
    }
    final b = dryBaselineOf(table, _forTable(constraints), baseline);
    return b == null ? null : y + b;
  }

  @override
  void performLayout() {
    final table = _table;
    table.layout(_forTable(constraints), parentUsesSize: true);
    final w = table.size.width;
    var y = 0.0;
    for (var c = firstChild; c != null; c = childAfter(c)) {
      if (!identical(c, table)) c.layout(BoxConstraints.tightFor(width: w), parentUsesSize: true);
      (c.parentData! as TableCaptionsParentData).offset = Offset(0, y);
      y += c.size.height;
    }
    size = constraints.constrain(Size(w, y));
  }

  /// The table's: the baseline of its first row, where the captions over
  /// it put the table box.
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final table = _table;
    final b = table.getDistanceToActualBaseline(baseline);
    return b == null ? null : b + (table.parentData! as TableCaptionsParentData).offset.dy;
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
