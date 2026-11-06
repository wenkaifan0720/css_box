/// Items on shared tracks, laid out by Flutter alone: CSS Grid Level 1
/// (https://www.w3.org/TR/css-grid-1) as a render object of its own.
///
/// A column that is as wide as the widest item in it across every row, an
/// `fr` that shares out what the sized tracks leave, an item that spans
/// three of them: nothing in Flutter sizes a track from items in OTHER rows,
/// so no composition of stock widgets can say it. [Tracks] is the render
/// object that does, the way [TableBox] is for tables -- written against
/// Flutter's own box protocol and nothing else. Its children are ordinary
/// widgets, measured with Flutter's intrinsic sizes and dry layouts: a
/// track's min-content contribution IS its item's `getMinIntrinsicWidth`,
/// and a height at a width IS a dry layout at that width.
///
/// The algorithm is Taffy's (`compute/grid`), which Chrome's is checked
/// against box for box, step for step: explicit grid, placement (8.5),
/// track sizing (11.4 to 11.8), content alignment (css-align-3 5) and item
/// alignment. The quirks Taffy keeps to match Chrome are kept too, and each
/// is named where it happens. Taffy is MIT licensed: its notice is in this
/// package's NOTICES.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';
import 'edges.dart';
import 'inset.dart';
import 'paint_order.dart';

/// How one row or column of a [Tracks] is sized.
///
/// The sizes that need tracks rather than nested rows and columns are the
/// ones that depend on ITEMS IN OTHER ROWS: [TrackSize.auto] is as large as
/// the largest item anywhere in that track, and [TrackSize.flex] shares
/// out what is left after all of those are settled.
sealed class TrackSize {
  const TrackSize();

  /// Exactly this many pixels.
  const factory TrackSize.fixed(double px) = _Fixed;

  /// A share of the space left after the sized tracks: with `1` and `2`,
  /// the second gets twice the first. On its own it is `minmax(auto, Nfr)`:
  /// never narrower than its items' smallest size.
  const factory TrackSize.flex(double factor) = _Flex;

  /// A fraction of the grid's own width or height: `0.5` is half of it.
  const factory TrackSize.fraction(double of) = _Fraction;

  /// A fraction of the grid's own width or height PLUS a length:
  /// `calc(50% - 672px)` is `TrackSize.affine(-672, 0.5)`.
  const factory TrackSize.affine(double px, double of) = _Affine;

  /// The smaller of two lengths of the grid's own width or height -- each a
  /// [fixed], a [fraction], an [affine] or one of these three --
  /// `min(100vw, 1920px)`: a size of the grid alone, as an [affine] is.
  const factory TrackSize.least(TrackSize a, TrackSize b) = _Least;

  /// The larger of two such lengths: `max(20%, 170px)`.
  const factory TrackSize.most(TrackSize a, TrackSize b) = _Most;

  /// [value] held between [min] and [max], each such a length:
  /// `clamp(360px, 33%, 50%)`, the larger of [min] and the smaller of
  /// [value] and [max].
  const factory TrackSize.clamp(TrackSize min, TrackSize value, TrackSize max) = _Clamp;

  /// As large as the track's items want to be, up to this many pixels:
  /// `fit-content(px)`.
  const factory TrackSize.upTo(double px) = _UpTo;

  /// As large as the track's items want to be, up to this fraction of the
  /// grid's own width or height: `fit-content(30%)`.
  const factory TrackSize.upToFraction(double of) = _UpToFraction;

  /// As large as the largest item in the track.
  static const TrackSize auto = _Keyword(_Kind.auto);

  /// As small as the track's items can be without their content overflowing.
  static const TrackSize minContent = _Keyword(_Kind.minContent);

  /// As large as the track's items would like to be.
  static const TrackSize maxContent = _Keyword(_Kind.maxContent);

  /// Between two limits, each of which may be any size above but a
  /// [between], and the lower of which is neither a [flex] nor an [upTo].
  const factory TrackSize.between(TrackSize min, TrackSize max) = _Between;

  /// [tracks], [count] times over.
  const factory TrackSize.repeat(int count, List<TrackSize> tracks) = _Repeat;

  /// As many copies of [tracks] as fit. Copies that end up empty collapse
  /// and the rest share the room they leave: `repeat(auto-fit, ...)`.
  const factory TrackSize.fit(List<TrackSize> tracks) = _AutoRepeat.fit;

  /// As many copies of [tracks] as fit, empty ones kept:
  /// `repeat(auto-fill, ...)`.
  const factory TrackSize.fill(List<TrackSize> tracks) = _AutoRepeat.fill;
}

class _Fixed extends TrackSize {
  const _Fixed(this.px);
  final double px;
  @override
  bool operator ==(Object o) => o is _Fixed && o.px == px;
  @override
  int get hashCode => Object.hash(_Fixed, px);
}

class _Flex extends TrackSize {
  const _Flex(this.factor);
  final double factor;
  @override
  bool operator ==(Object o) => o is _Flex && o.factor == factor;
  @override
  int get hashCode => Object.hash(_Flex, factor);
}

class _Fraction extends TrackSize {
  const _Fraction(this.of);
  final double of;
  @override
  bool operator ==(Object o) => o is _Fraction && o.of == of;
  @override
  int get hashCode => Object.hash(_Fraction, of);
}

class _Affine extends TrackSize {
  const _Affine(this.px, this.of);
  final double px, of;
  @override
  bool operator ==(Object o) => o is _Affine && o.px == px && o.of == of;
  @override
  int get hashCode => Object.hash(_Affine, px, of);
}

class _Least extends TrackSize {
  const _Least(this.a, this.b);
  final TrackSize a, b;
  @override
  bool operator ==(Object o) => o is _Least && o.a == a && o.b == b;
  @override
  int get hashCode => Object.hash(_Least, a, b);
}

class _Most extends TrackSize {
  const _Most(this.a, this.b);
  final TrackSize a, b;
  @override
  bool operator ==(Object o) => o is _Most && o.a == a && o.b == b;
  @override
  int get hashCode => Object.hash(_Most, a, b);
}

class _Clamp extends TrackSize {
  const _Clamp(this.min, this.value, this.max);
  final TrackSize min, value, max;
  @override
  bool operator ==(Object o) => o is _Clamp && o.min == min && o.value == value && o.max == max;
  @override
  int get hashCode => Object.hash(_Clamp, min, value, max);
}

class _UpTo extends TrackSize {
  const _UpTo(this.px);
  final double px;
  @override
  bool operator ==(Object o) => o is _UpTo && o.px == px;
  @override
  int get hashCode => Object.hash(_UpTo, px);
}

class _UpToFraction extends TrackSize {
  const _UpToFraction(this.of);
  final double of;
  @override
  bool operator ==(Object o) => o is _UpToFraction && o.of == of;
  @override
  int get hashCode => Object.hash(_UpToFraction, of);
}

class _Keyword extends TrackSize {
  const _Keyword(this.kind);
  final _Kind kind;
  @override
  bool operator ==(Object o) => o is _Keyword && o.kind == kind;
  @override
  int get hashCode => Object.hash(_Keyword, kind);
}

class _Between extends TrackSize {
  const _Between(this.min, this.max);
  final TrackSize min, max;
  @override
  bool operator ==(Object o) => o is _Between && o.min == min && o.max == max;
  @override
  int get hashCode => Object.hash(_Between, min, max);
}

class _Repeat extends TrackSize {
  const _Repeat(this.count, this.tracks);
  final int count;
  final List<TrackSize> tracks;
  @override
  bool operator ==(Object o) => o is _Repeat && o.count == count && listEquals(o.tracks, tracks);
  @override
  int get hashCode => Object.hash(_Repeat, count, Object.hashAll(tracks));
}

class _AutoRepeat extends TrackSize {
  const _AutoRepeat.fit(this.tracks) : fits = true;
  const _AutoRepeat.fill(this.tracks) : fits = false;
  final bool fits;
  final List<TrackSize> tracks;
  @override
  bool operator ==(Object o) => o is _AutoRepeat && o.fits == fits && listEquals(o.tracks, tracks);
  @override
  int get hashCode => Object.hash(_AutoRepeat, fits, Object.hashAll(tracks));
}

/// The direction items are placed in when they do not say where they go.
enum TrackFlow { row, column, rowDense, columnDense }

/// Where an item sits in its area on one axis (`align-self`,
/// `justify-self`). The `safe` ones hold while the item fits and fall back
/// to [start] where it would overflow (css-align-3 4.4). [baseline], down
/// the block axis, lines the item's first baseline up with those of the
/// others in its row that say it (css-align-3 9, css-grid-1 11.5 step 1):
/// the item starts its area, pushed down by as far as the row's lowest
/// baseline is below its own. Across the inline axis it is [start].
enum CellAlign { start, end, center, stretch, safeCenter, safeEnd, baseline }

/// Where the TRACKS sit in the room the grid has on one axis
/// (`align-content`, `justify-content`, css-align-3 5): not where an item
/// sits in its area, but where the areas are when the tracks do not fill
/// the box.
enum TrackContent { start, end, center, stretch, spaceBetween, spaceAround, spaceEvenly, safeCenter, safeEnd }

/// A two-dimensional layout on shared tracks.
///
/// Children are placed by their [TrackCell], and a child without one is
/// placed by the grid itself, in [flow] order.
class Tracks extends MultiChildRenderObjectWidget {
  const Tracks({
    super.key,
    this.columns = const [],
    this.rows = const [],
    this.flow = TrackFlow.row,
    this.autoColumns = const [TrackSize.auto],
    this.autoRows = const [TrackSize.auto],
    this.spacing = 0,
    this.runSpacing = 0,
    this.spacingFraction,
    this.runSpacingFraction,
    this.align = CellAlign.stretch,
    this.justify = CellAlign.stretch,
    this.alignContent,
    this.justifyContent,
    this.textDirection,
    this.subgridRows = false,
    this.subgridColumns = false,
    this.subgridFrame = EdgeInsets.zero,
    super.children,
  });

  /// The columns, left to right. Items placed past the end land on
  /// [autoColumns].
  final List<TrackSize> columns;
  final List<TrackSize> rows;

  /// How items that do not name a cell are placed.
  final TrackFlow flow;

  /// The sizes of tracks created beyond [columns] and [rows]. A list of
  /// more than one is a PATTERN: the implicit tracks take its sizes in turn
  /// and start over at the end of it (css-grid-1 7.5).
  final List<TrackSize> autoColumns, autoRows;

  /// Space between columns, and between rows.
  final double spacing, runSpacing;

  /// [spacing] and [runSpacing] as a share of the grid's OWN content box on
  /// the same axis (css-align-3 8.3). Down a box as tall as what it holds
  /// the share has nothing to be a share of, and is zero.
  final double? spacingFraction, runSpacingFraction;

  /// How an item sits in its area, down the block axis and across it.
  final CellAlign align, justify;

  /// Where the tracks sit when they do not fill the box. Null is `normal`,
  /// which stretches the `auto` tracks and otherwise starts them.
  final TrackContent? alignContent, justifyContent;

  /// Which way the COLUMNS run. Right to left (`direction: rtl`) the first
  /// column is the rightmost, and with the columns run every column line,
  /// span and inline alignment -- `start` is the right-hand end of an area
  /// and of the box -- while the rows are unmoved (css-grid-1 7.1, 8.3).
  /// Null reads the ambient [Directionality], as a [Row] does.
  final TextDirection? textDirection;

  /// Whether this grid's ROWS are the grid round it: `grid-template-rows:
  /// subgrid` (css-grid-2 9). The grid is the child of a [TrackCell] with
  /// [TrackCell.subgrid] -- under whatever paints its box -- and has no rows
  /// of its own: its items are sized as items of the grid round it, on the
  /// rows its cell spans, and it is laid out on the lines those rows come
  /// to. Two cards side by side in a listing line their titles, their
  /// prices and their footers up that way, each row as tall as the taller
  /// of the two parts in it.
  ///
  /// Its own [runSpacing] stands centred in the parent's gutter, half the
  /// difference taken off (or given to) the items either side of it, and
  /// [subgridFrame] and its cell's margin are an extra margin on the items
  /// in its first and last rows (css-grid-2 9, "the subgrid's own padding,
  /// border and margin"). A track is never less than nothing, so an item
  /// shorter than the gutter it gives back holds the gutter open. Its items
  /// are placed down its one column as a grid places them -- one that names
  /// a row first, the rest in order -- and each area is then clamped to the
  /// rows it has, so an item past the last row stands on the last row (see
  /// [TrackCell.subgrid]). A grid holding one placed on a column, or two on
  /// the same row, is laid out as a grid of its own, as is one no subgrid
  /// cell holds.
  final bool subgridRows;

  /// Whether this grid's COLUMNS are the grid round it: `grid-template-
  /// columns: subgrid` (css-grid-2 9), the rows its own. The grid is the
  /// child of a [TrackCell] with [TrackCell.subgrid], and has no columns of
  /// its own: its items are placed on the columns its cell spans as a grid
  /// places them, and are sized as items of the grid round it -- "the
  /// subgrid's own grid items participate in the sizing of its parent
  /// grid" -- so a word wider than the share of a `1fr` column keeps THAT
  /// column wide and the others share what is left, as Chrome does. The
  /// grid is then laid out on the columns they came to, and is as tall as
  /// its rows come to at those widths: an item of the grid round it down
  /// the rows (9: "the subgrid is ... a grid item in the other axis").
  ///
  /// Its own [spacing] stands centred in the parent's gutter and
  /// [subgridFrame] and its cell's margin are an extra margin on the items
  /// in its first and last columns, as for [subgridRows]. Its cell is
  /// stretched across its columns, whatever it says. Laid out as a grid of
  /// its own (on no columns: one auto column) where the grid round it
  /// cannot share its columns: one of its items placed past the columns
  /// it spans or on a subgrid of its own, an `auto` margin or a share of
  /// one across, columns that run right to left, a gutter that is a share,
  /// or tracks the grid round it spreads apart (`space-between`, ...).
  final bool subgridColumns;

  /// The padding and border of a [subgridRows] or [subgridColumns] grid's
  /// box: what stands between its cell's area, inside the cell's margin,
  /// and its own tracks.
  final EdgeInsets subgridFrame;

  /// Whether this grid is a subgrid in either axis.
  bool get _subgrid => subgridRows || subgridColumns;

  TextDirection _direction(BuildContext context) =>
      textDirection ?? Directionality.maybeOf(context) ?? TextDirection.ltr;

  @override
  RenderTracks createRenderObject(BuildContext context) => RenderTracks(this, textDirection: _direction(context));

  @override
  void updateRenderObject(BuildContext context, RenderTracks renderObject) => renderObject
    ..config = this
    ..textDirection = _direction(context);
}

/// Where one child of a [Tracks] sits, and the box it asks for there.
class TrackCell extends ParentDataWidget<TrackCellParentData> {
  const TrackCell({
    super.key,
    this.column,
    this.row,
    this.columnEnd,
    this.rowEnd,
    this.columnSpan = 1,
    this.rowSpan = 1,
    this.align,
    this.justify,
    this.margin = EdgeInsets.zero,
    this.autoMargin = AutoEdges.none,
    this.marginShare = EdgeInsets.zero,
    this.width,
    this.widthFraction,
    this.height,
    this.heightFraction,
    this.minWidth,
    this.minWidthFraction,
    this.maxWidth,
    this.maxWidthFraction,
    this.minHeight,
    this.maxHeight,
    this.z = 0,
    this.clips = false,
    this.compressible = false,
    this.room = false,
    this.ratio,
    this.positioned = false,
    this.left,
    this.right,
    this.top,
    this.bottom,
    this.leftFraction,
    this.rightFraction,
    this.topFraction,
    this.bottomFraction,
    this.subgrid = false,
    required super.child,
  });

  /// Zero-based track indices. Null means "wherever the flow puts it", and
  /// a NEGATIVE index counts back from the end of the explicit grid: -1 is
  /// the last track.
  final int? column, row;

  /// The track this item stops BEFORE, zero-based, counting back from the
  /// end when negative: -1 is past the last track. Null leaves the end to
  /// [columnSpan] / [rowSpan].
  final int? columnEnd, rowEnd;

  /// How many tracks this item covers, where no end is given.
  final int columnSpan, rowSpan;

  /// Overrides the grid's [Tracks.align] and [Tracks.justify].
  final CellAlign? align, justify;

  /// Space round the item's box, which may be negative.
  final EdgeInsets margin;

  /// The margin edges that take the room left over instead of a length --
  /// how css-align-3 10.1 centres an item in its area.
  final AutoEdges autoMargin;

  /// The part of each margin edge that is a SHARE of the item's area,
  /// `0.1` for `margin-left: 10%`, added to the edge's [margin] length.
  /// Every side is a share of the area's WIDTH, the top and the bottom as
  /// much as the left and the right (css-grid-1 6.4, CSS 2.1 8.3), and the
  /// margin moves the item inside its area without shrinking the box its
  /// own percentages read. While the tracks are sized that width is not
  /// all known: a share ACROSS is of nothing, the cyclic percentage
  /// css-sizing-3 5.2.1 resolves against zero, and a share DOWN is one of
  /// the width the columns give the item once they are sized.
  final EdgeInsets marginShare;

  /// The size the item asks for, which is part of what sizes the track it
  /// is in (css-grid-1 12.5). Both a length and a fraction is their sum:
  /// `calc(50% + 10px)`. The fractions are of the item's AREA.
  final double? width, widthFraction, height, heightFraction;

  /// The floor and the cap on each axis.
  final double? minWidth, minWidthFraction, maxWidth, maxWidthFraction, minHeight, maxHeight;

  /// Paint order among siblings: lowest first, ties in document order.
  final int z;

  /// Whether the item clips what overflows it: a scroll container, whose
  /// automatic minimum is zero (css-grid-1 6.6) and which a `fit-content()`
  /// track holds only up to its limit.
  final bool clips;

  /// Whether the item is a picture -- a replaced box -- whose share of its
  /// area is OF NOTHING when the tracks ask its least width: a percentage
  /// `width` or `max-width` on a replaced box resolves against zero for
  /// its min-content contribution and as `auto` for its max-content one
  /// (css-sizing-3 5.2.2), so the picture asks an `auto` column for
  /// nothing and grows it only as far as the grid has room. A product site's hero
  /// picture is `width: 1920px; max-width: 100%` in a grid as wide as the
  /// page: Chrome draws it the page's width, and a floor of the 1920 held
  /// the column, and the picture, at 1920
  /// (`fixtures/grid-item-pct-cap-placed`). As [FlexCell.compressible].
  final bool compressible;

  /// Whether the item's AREA is a room ([Inset.room]) for the shares inside
  /// it that are of its containing block ([Inset.ofRoom]): a grid item's
  /// containing block is its grid area (css-grid-1 9, CSS 2.1 10.1), and a
  /// percentage padding is a share of that block's width (CSS 2.1 8.4)
  /// whatever width the item itself comes to. `width: calc(50% + 10px);
  /// min-width: 200px; padding: 0 5%` pads by 5% of the area both where the
  /// share sizes the item and where the floor does. Where the area is not
  /// known -- the item's contribution to the tracks that make it -- a share
  /// of it is nothing (css-sizing-3 5.2.1). The area this grid lays the
  /// item out in; a subgrid's item, in the subgrid's own.
  final bool room;

  /// The item's preferred aspect RATIO, width over height (css-sizing-4
  /// 4.1). It turns a size on one axis into a size on the other, a floor
  /// or a cap included, which is part of what sizes the track the item is
  /// in; and it leaves the item no `auto` size for its area to stretch on
  /// both axes. An item of no stated size whose area stretches it both ways
  /// is then as big as the area on one axis and as the ratio makes it on
  /// the other -- the COVERING box, not the contained one, because its
  /// automatic minimum size is transferred through the ratio from the
  /// stretched axis (css-grid-1 6.6): `aspect-ratio: 2` in a 100x100 area
  /// is 200x100. A floor the page wrote in place of `auto` (`min-width: 0`)
  /// has nothing to transfer, and the item is the contained 100x50.
  final double? ratio;

  /// Whether the item is OUT OF THE FLOW: `position: absolute` in a grid
  /// that is its containing block (css-grid-1 9.1). It takes no cell and
  /// sizes no track; its containing block is the area its lines name,
  /// each line as the edge of the track beside it, and a line it does not
  /// name is this box's own edge -- with no [row] and no [rowEnd] it runs
  /// the grid's whole height. [width] and the other sizes are then shares
  /// of that area, and it stands at its insets inward from it.
  final bool positioned;

  /// A [positioned] item's insets, inward from its area. Null is `auto`:
  /// that edge is wherever the item's size and its other edge leave it,
  /// and with both `auto` the item's alignment places it.
  final double? left, right, top, bottom;

  /// The same insets as shares of the area: [leftFraction] and
  /// [rightFraction] of its width, [topFraction] and [bottomFraction] of
  /// its height. A share is read in place of the length beside it.
  final double? leftFraction, rightFraction, topFraction, bottomFraction;

  /// Whether the item is a grid whose rows are this grid's: the child holds
  /// a [Tracks] with [Tracks.subgridRows]. Its items size this grid's rows
  /// in its place, and it is stretched down the rows it spans. Or whose
  /// COLUMNS are, with [Tracks.subgridColumns]: its items size this grid's
  /// columns, it is stretched across them, and it sizes the rows it spans
  /// as any item does, as tall as it comes to on its columns.
  final bool subgrid;

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as TrackCellParentData;
    if (data.z != z) {
      data.z = z;
      renderObject.parent?.markNeedsPaint();
    }
    final changed =
        data.column != column ||
        data.row != row ||
        data.columnEnd != columnEnd ||
        data.rowEnd != rowEnd ||
        data.columnSpan != columnSpan ||
        data.rowSpan != rowSpan ||
        data.align != align ||
        data.justify != justify ||
        data.margin != margin ||
        data.autoMargin != autoMargin ||
        data.marginShare != marginShare ||
        data.width != width ||
        data.widthFraction != widthFraction ||
        data.height != height ||
        data.heightFraction != heightFraction ||
        data.minWidth != minWidth ||
        data.minWidthFraction != minWidthFraction ||
        data.maxWidth != maxWidth ||
        data.maxWidthFraction != maxWidthFraction ||
        data.minHeight != minHeight ||
        data.maxHeight != maxHeight ||
        data.clips != clips ||
        data.compressible != compressible ||
        data.room != room ||
        data.ratio != ratio ||
        data.positioned != positioned ||
        data.left != left ||
        data.right != right ||
        data.top != top ||
        data.bottom != bottom ||
        data.leftFraction != leftFraction ||
        data.rightFraction != rightFraction ||
        data.topFraction != topFraction ||
        data.bottomFraction != bottomFraction ||
        data.subgrid != subgrid;
    if (!changed) return;
    data
      ..column = column
      ..row = row
      ..columnEnd = columnEnd
      ..rowEnd = rowEnd
      ..columnSpan = columnSpan
      ..rowSpan = rowSpan
      ..align = align
      ..justify = justify
      ..margin = margin
      ..autoMargin = autoMargin
      ..marginShare = marginShare
      ..width = width
      ..widthFraction = widthFraction
      ..height = height
      ..heightFraction = heightFraction
      ..minWidth = minWidth
      ..minWidthFraction = minWidthFraction
      ..maxWidth = maxWidth
      ..maxWidthFraction = maxWidthFraction
      ..minHeight = minHeight
      ..maxHeight = maxHeight
      ..clips = clips
      ..compressible = compressible
      ..room = room
      ..ratio = ratio
      ..positioned = positioned
      ..left = left
      ..right = right
      ..top = top
      ..bottom = bottom
      ..leftFraction = leftFraction
      ..rightFraction = rightFraction
      ..topFraction = topFraction
      ..bottomFraction = bottomFraction
      ..subgrid = subgrid;
    // A subgrid straight under its cell is attached before its cell says
    // it is one (the parent data comes after the child is adopted), so it
    // is handed to the grid round it here.
    if (renderObject is RenderTracks && renderObject.attached) {
      renderObject._unregister();
      if (renderObject._config._subgrid) renderObject._register();
    }
    renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => Tracks;
}

/// What a [TrackCell] tells its [Tracks]. A child without one has these
/// defaults: placed by the flow, one track each way, stretched.
class TrackCellParentData extends ContainerBoxParentData<RenderBox> {
  int? column, row, columnEnd, rowEnd;
  int columnSpan = 1, rowSpan = 1;
  CellAlign? align, justify;
  EdgeInsets margin = EdgeInsets.zero;
  AutoEdges autoMargin = AutoEdges.none;
  EdgeInsets marginShare = EdgeInsets.zero;
  double? width, widthFraction, height, heightFraction;
  double? minWidth, minWidthFraction, maxWidth, maxWidthFraction, minHeight, maxHeight;
  int z = 0;
  bool clips = false;
  bool compressible = false;
  bool room = false;
  double? ratio;
  bool positioned = false;
  double? left, right, top, bottom, leftFraction, rightFraction, topFraction, bottomFraction;
  bool subgrid = false;

  /// A copy of this item's data, its margin [extra] wider and its
  /// alignments [align] and [justify] where it states none: the item as an
  /// item of the grid round its subgrid ([_Grid._leaves]).
  TrackCellParentData _widened(EdgeInsets extra, CellAlign align, CellAlign justify) => TrackCellParentData()
    ..column = column
    ..row = row
    ..columnEnd = columnEnd
    ..rowEnd = rowEnd
    ..columnSpan = columnSpan
    ..rowSpan = rowSpan
    ..align = this.align ?? align
    ..justify = this.justify ?? justify
    ..margin = margin + extra
    ..autoMargin = autoMargin
    ..marginShare = marginShare
    ..width = width
    ..widthFraction = widthFraction
    ..height = height
    ..heightFraction = heightFraction
    ..minWidth = minWidth
    ..minWidthFraction = minWidthFraction
    ..maxWidth = maxWidth
    ..maxWidthFraction = maxWidthFraction
    ..minHeight = minHeight
    ..maxHeight = maxHeight
    ..clips = clips
    ..compressible = compressible
    ..ratio = ratio;
}

class RenderTracks extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, TrackCellParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, TrackCellParentData>,
        PaintOrder,
        AsksGuarded,
        KeptUnderHatch
    implements RoomHost {
  RenderTracks(this._config, {TextDirection textDirection = TextDirection.ltr}) : _textDirection = textDirection;

  /// Which way the columns run: see [Tracks.textDirection].
  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection v) {
    if (v == _textDirection) return;
    _textDirection = v;
    markNeedsLayout();
  }

  Tracks _config;
  set config(Tracks v) {
    final same =
        listEquals(_config.columns, v.columns) &&
        listEquals(_config.rows, v.rows) &&
        _config.flow == v.flow &&
        listEquals(_config.autoColumns, v.autoColumns) &&
        listEquals(_config.autoRows, v.autoRows) &&
        _config.spacing == v.spacing &&
        _config.runSpacing == v.runSpacing &&
        _config.spacingFraction == v.spacingFraction &&
        _config.runSpacingFraction == v.runSpacingFraction &&
        _config.align == v.align &&
        _config.justify == v.justify &&
        _config.alignContent == v.alignContent &&
        _config.justifyContent == v.justifyContent &&
        _config.subgridRows == v.subgridRows &&
        _config.subgridColumns == v.subgridColumns &&
        _config.subgridFrame == v.subgridFrame;
    final registers = _config._subgrid != v._subgrid;
    _config = v;
    if (registers && attached) {
      _unregister();
      if (v._subgrid) _register();
    }
    if (!same) markNeedsLayout();
  }

  // --------------------------------------------------------------- subgrids

  /// The grid round this one where its rows or its columns are that grid's
  /// ([Tracks.subgridRows], [Tracks.subgridColumns]), and the child of it
  /// this one is under.
  RenderTracks? _host;
  RenderBox? _hostCell;

  /// The subgrids in this grid's items, by the child each is under.
  final Map<RenderBox, RenderTracks> _subgrids = {};

  /// The sizes of this grid's rows, where it is a subgrid its host has
  /// laid out: its host's tracks, their gutters shared out as css-grid-2 9
  /// says (see [_Grid._imposed]).
  List<double>? _imposed;
  bool _imposing = false;

  /// The sizes of this grid's columns, where its columns are its host's
  /// ([Tracks.subgridColumns], [_Grid._subgridColumns]).
  List<double>? _imposedColumns;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (_config._subgrid) _register();
  }

  @override
  void detach() {
    _unregister();
    super.detach();
  }

  /// Hands this grid to the nearest grid above it, where the child of that
  /// grid it is under is a [TrackCell.subgrid] cell.
  void _register() {
    RenderObject child = this;
    var node = parent;
    while (node != null && node is! RenderTracks) {
      child = node;
      node = node.parent;
    }
    if (node is! RenderTracks || child is! RenderBox) return;
    final data = child.parentData;
    if (data is! TrackCellParentData || !data.subgrid) return;
    _host = node;
    _hostCell = child;
    node._subgrids[child] = this;
    if (!(node.owner?.debugDoingLayout ?? false)) node.markNeedsLayout();
  }

  void _unregister() {
    final host = _host, cell = _hostCell;
    if (host != null && cell != null && identical(host._subgrids[cell], this)) host._subgrids.remove(cell);
    _host = null;
    _hostCell = null;
    _imposed = null;
    _imposedColumns = null;
  }

  /// Lays this grid out on [rows] from now on (see [_imposed]).
  void _impose(List<double> rows) {
    if (_imposed != null && listEquals(_imposed, rows)) return;
    _imposed = rows;
    _imposing = true;
    try {
      markNeedsLayout();
    } finally {
      _imposing = false;
    }
  }

  /// Lays this grid out on [columns] from now on (see [_imposedColumns]).
  void _imposeColumns(List<double> columns) {
    if (_imposedColumns != null && listEquals(_imposedColumns, columns)) return;
    _imposedColumns = columns;
    _imposing = true;
    try {
      markNeedsLayout();
    } finally {
      _imposing = false;
    }
  }

  /// The grid's own words, or where it is a subgrid its host has laid out,
  /// the rows its host gave it, started at its top -- or the columns,
  /// started at its start.
  Tracks get _effective {
    if (_host == null) return _config;
    if (_imposedColumns case final columns? when _config.subgridColumns) return _onColumnsOf(columns);
    final rows = _imposed;
    if (rows == null) return _config;
    return _onRowsOf(rows);
  }

  /// This grid's words on the [rows] its host sized for it.
  Tracks _onRowsOf(List<double> rows) {
    final c = _config;
    return Tracks(
      columns: c.columns,
      rows: [for (final r in rows) TrackSize.fixed(r)],
      flow: c.flow,
      autoColumns: c.autoColumns,
      autoRows: c.autoRows,
      spacing: c.spacing,
      runSpacing: c.runSpacing,
      spacingFraction: c.spacingFraction,
      runSpacingFraction: c.runSpacingFraction,
      align: c.align,
      justify: c.justify,
      alignContent: TrackContent.start,
      justifyContent: c.justifyContent,
      textDirection: c.textDirection,
      subgridRows: true,
      subgridFrame: c.subgridFrame,
    );
  }

  /// This grid's words on the [columns] its host sized for it.
  Tracks _onColumnsOf(List<double> columns) {
    final c = _config;
    return Tracks(
      columns: [for (final w in columns) TrackSize.fixed(w)],
      rows: c.rows,
      flow: c.flow,
      autoColumns: c.autoColumns,
      autoRows: c.autoRows,
      spacing: c.spacing,
      runSpacing: c.runSpacing,
      runSpacingFraction: c.runSpacingFraction,
      align: c.align,
      justify: c.justify,
      alignContent: c.alignContent,
      justifyContent: TrackContent.start,
      textDirection: c.textDirection,
      subgridColumns: true,
      subgridFrame: c.subgridFrame,
    );
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! TrackCellParentData) child.parentData = TrackCellParentData();
  }

  /// What this box has already worked out, by question, until it is next
  /// marked dirty. Flutter keeps intrinsics and dry layouts itself, except
  /// while `RenderObject.debugCheckingIntrinsics` is set -- which is how a
  /// dry baseline is asked in debug ([dryBaselineOf]) -- and a grid asks
  /// each child several questions, so a nest of them would work every one
  /// out again from scratch.
  final Map<String, Object> _answers = {};

  @override
  void markNeedsLayout() {
    _answers.clear();
    super.markNeedsLayout();
    // What its items ask for sizes its host's rows: a change in them is a
    // change in the host -- except the rows the host itself hands it.
    if (!_imposing) _host?.markNeedsLayout();
  }

  List<RenderBox> get _children {
    final out = <RenderBox>[];
    for (var child = firstChild; child != null; child = (child.parentData! as TrackCellParentData).nextSibling) {
      out.add(child);
    }
    return out;
  }

  _Grid get _grid => _Grid(
    _effective,
    _children,
    rtl: _textDirection == TextDirection.rtl,
    subgrids: _subgrids,
    imposed: _imposed != null && _host != null,
  );

  // ------------------------------------------------------------ intrinsics

  double _intrinsic(_Space width, _Space height, bool horizontal) {
    final key = 'i$width,$height,$horizontal';
    final known = _answers[key];
    if (known is double) return known;
    final grid = _grid;
    final v = grid
        .run(
          known: const _Pair(null, null),
          parent: _Pair(width.option, height.option),
          available: (width, height),
          measure: horizontal ? _Measure.horizontal : _Measure.vertical,
        )
        .size;
    final out = horizontal ? v.w : v.h;
    // No box has an infinite intrinsic size: content is finite.
    final answer = out.isFinite ? out : 0.0;
    _answers[key] = answer;
    return answer;
  }

  static _Space _space(double extent) => extent.isFinite ? _Space.definite(extent) : _Space.maxContent;

  @override
  double computeMinIntrinsicWidth(double height) => _intrinsic(_Space.minContent, _space(height), true);

  @override
  double computeMaxIntrinsicWidth(double height) => _intrinsic(_Space.maxContent, _space(height), true);

  // How tall this is at THAT width is a dry layout at that width: the same
  // code the real layout runs, so the answer cannot disagree with the size
  // the box ends up at. With no width to run at, the sizing pass is asked.
  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) {
    final h = width.isFinite ? _run(BoxConstraints.tightFor(width: width)).$1.height : double.infinity;
    return h.isFinite ? h : _intrinsic(_Space.maxContent, _Space.maxContent, false);
  }

  // ---------------------------------------------------------------- layout

  /// The box's size at [constraints], its first baseline where [baselines]
  /// asks for it, and the items where [place] asks for them.
  (Size, double?, List<_Item>) _layOut(BoxConstraints constraints, {bool baselines = false}) {
    final tightW = constraints.hasTightWidth, tightH = constraints.hasTightHeight;
    // A minimum handed down from outside is the container's own min-size
    // (the tracks stretch into it), and a loose finite maximum its
    // max-size: a box handed a TIGHT size is that long whatever is round it.
    final min = _Pair(
      constraints.minWidth > 0 ? constraints.minWidth : null,
      constraints.minHeight > 0 ? constraints.minHeight : null,
    );
    final max = _Pair(
      !tightW && constraints.maxWidth.isFinite ? constraints.maxWidth : null,
      !tightH && constraints.maxHeight.isFinite ? constraints.maxHeight : null,
    );
    final available = (_space(constraints.maxWidth), _space(constraints.maxHeight));
    final known = _Pair(tightW ? constraints.maxWidth : null, tightH ? constraints.maxHeight : null);
    final parent = _Pair(available.$1.option, available.$2.option);
    final grid = _grid..baselines = baselines;
    var out = grid.run(known: known, parent: parent, available: available, min: min, max: max);
    // A box that sizes itself to its content is laid out AT the width that
    // comes to, and a percentage inside it is of that width -- a box out of
    // the flow's too, whose share is of its area.
    if (known.w == null && out.size.w.isFinite && _children.any(_sharesWidth)) {
      out = grid.run(
        known: _Pair(constraints.constrainWidth(out.size.w), known.h),
        parent: parent,
        available: available,
        min: min,
        max: max,
      );
    }
    return (constraints.constrain(Size(out.size.w, out.size.h)), out.baseline, out.items);
  }

  /// Whether [child] takes a bare share of a width: what [_layOut] lays
  /// the grid out again for, in the flow or out of it.
  static bool _sharesWidth(RenderBox child) {
    final d = child.parentData! as TrackCellParentData;
    return (d.width == null && d.widthFraction != null) ||
        (d.minWidth == null && d.minWidthFraction != null) ||
        (d.maxWidth == null && d.maxWidthFraction != null);
  }

  (Size, double?) _run(BoxConstraints constraints, {bool baselines = false}) {
    final key = '${constraints.minWidth},${constraints.maxWidth},${constraints.minHeight},${constraints.maxHeight}';
    final known = _answers['b$key'] ?? (baselines ? null : _answers['s$key']);
    if (known is (Size, double?)) return known;
    final (size, baseline, _) = _layOut(constraints, baselines: baselines);
    final out = (size, baseline);
    _answers['${baselines ? 'b' : 's'}$key'] = out;
    return out;
  }

  @override
  @protected
  Size computeDryLayout(covariant BoxConstraints constraints) => _run(constraints).$1;

  // css-grid-1 10.8: the grid's baseline is its first row's -- the first
  // item in it, and an item with no baseline of its own gives its bottom
  // edge.
  @override
  @protected
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) =>
      firstChild == null ? null : _run(constraints, baselines: true).$2;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      firstChild == null ? null : _run(constraints, baselines: true).$2;

  // ------------------------------------------------------------- rooms

  /// The width of the area each item that is a room ([TrackCell.room]) was
  /// last placed in, infinite while the tracks that make it are sized.
  final Map<RenderBox, double> _rooms = {};

  /// The boxes inside each such item whose shares are of its area.
  final Map<RenderBox, Set<RenderInset>> _roomers = {};

  @override
  void dropChild(RenderObject child) {
    _rooms.remove(child);
    _roomers.remove(child);
    super.dropChild(child);
  }

  @override
  double? roomOf(RenderObject child, RenderInset dependant) {
    if (child is! RenderBox || child.parentData is! TrackCellParentData) return null;
    if (!(child.parentData! as TrackCellParentData).room) return null;
    (_roomers[child] ??= {}).add(dependant);
    return _rooms[child] ?? double.infinity;
  }

  @override
  void forget(RenderInset dependant) {
    for (final set in _roomers.values) {
      set.remove(dependant);
    }
  }

  /// The area [child] is placed in is [width] wide, for the shares inside
  /// it ([roomOf]) -- or none yet, infinite.
  void _offerRoom(RenderBox child, double width) {
    if (!(child.parentData! as TrackCellParentData).room) return;
    touchesRoom();
    _rooms[child] = width;
  }

  @override
  void performLayout() {
    // What an area comes to is only known once the tracks are sized, and a
    // box inside that reads it measured at the last one: every box that
    // does is laid out again, and measured again, with this grid.
    final roomers = [for (final set in _roomers.values) ...set];
    if (roomers.isNotEmpty) {
      _imposing = true;
      try {
        invokeLayoutCallback<BoxConstraints>((_) {
          for (final d in roomers) {
            d.markNeedsLayout();
          }
        });
      } finally {
        _imposing = false;
      }
    }
    final (size, _, items) = _layOut(constraints);
    this.size = size;
    for (final item in items) {
      final w = item.outW.isFinite
          ? item.outW
          : guardedSize(item.child, () => item.child.getMaxIntrinsicWidth(double.infinity));
      final h = item.outH.isFinite
          ? item.outH
          : guardedSize(item.child, () => item.child.getMaxIntrinsicHeight(w.isFinite ? w : 0));
      if ((item.subgrid, item.imposed) case (final sub?, final rows?)) {
        invokeLayoutCallback<BoxConstraints>((_) => sub._impose(rows));
      }
      if ((item.columnSubgrid, item.imposedColumns) case (final sub?, final columns?)) {
        invokeLayoutCallback<BoxConstraints>((_) => sub._imposeColumns(columns));
      }
      item.child.layout(BoxConstraints.tight(Size(w.isFinite ? w : 0, h.isFinite ? h : 0)), parentUsesSize: true);
      (item.child.parentData! as TrackCellParentData).offset = Offset(item.x, item.outY);
    }
  }

  // ------------------------------------------------------------------ paint

  /// The children in paint order: by [TrackCellParentData.z], ties in
  /// document order.
  @override
  List<RenderBox> get paintOrder => _painted();

  List<RenderBox> _painted() {
    final kids = <(int, int, RenderBox)>[];
    var i = 0;
    for (final child in _children) {
      kids.add(((child.parentData! as TrackCellParentData).z, i++, child));
    }
    kids.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
    return [for (final k in kids) k.$3];
  }

  bool get _stacked => _children.any((c) => (c.parentData! as TrackCellParentData).z != 0);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (!_stacked) return defaultHitTestChildren(result, position: position);
    for (final child in _painted().reversed) {
      final data = child.parentData! as TrackCellParentData;
      final hit = result.addWithPaintOffset(
        offset: data.offset,
        position: position,
        hitTest: (r, p) => child.hitTest(r, position: p),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_stacked) return defaultPaint(context, offset);
    for (final child in _painted()) {
      context.paintChild(child, (child.parentData! as TrackCellParentData).offset + offset);
    }
  }
}

// =================================================================== values

/// The space a box is offered on one axis (css-sizing-3 2.1): a length, or
/// one of the two intrinsic questions.
class _Space {
  const _Space.definite(this.value) : kind = 0;
  const _Space._(this.kind) : value = 0;
  static const _Space minContent = _Space._(1);
  static const _Space maxContent = _Space._(2);

  final int kind;
  final double value;

  bool get isDefinite => kind == 0;
  bool get isMin => kind == 1;
  bool get isMax => kind == 2;
  double? get option => kind == 0 ? value : null;

  _Space or(_Space o) => isDefinite ? this : o;
  _Space set(double? v) => v == null ? this : _Space.definite(v);
  _Space map(double Function(double) f) => isDefinite ? _Space.definite(f(value)) : this;
  _Space sub(double? v) => v == null ? this : map((x) => x - v);

  double freeSpace(double used) => switch (kind) {
    2 => double.infinity,
    1 => 0.0,
    _ => value - used,
  };

  @override
  bool operator ==(Object o) => o is _Space && o.kind == kind && o.value == value;
  @override
  int get hashCode => Object.hash(kind, value);
  @override
  String toString() => switch (kind) {
    1 => 'min',
    2 => 'max',
    _ => '$value',
  };
}

/// A width and a height, either of which may be unknown.
class _Pair {
  const _Pair(this.w, this.h);
  final double? w, h;

  double? get(bool inline) => inline ? w : h;
  _Pair or(_Pair o) => _Pair(w ?? o.w, h ?? o.h);
  _Pair clamp(_Pair min, _Pair max) => _Pair(_clampN(w, min.w, max.w), _clampN(h, min.h, max.h));
  _Pair floor(_Pair o) => _Pair(_maxN(w, o.w), _maxN(h, o.h));
  _Pair less(_Pair o) => _Pair(_subN(w, o.w), _subN(h, o.h));

  /// The one size a [ratio] makes of the other where only one is known
  /// (css-sizing-4 4.1): width over height.
  _Pair ratio(double? ratio) {
    if (ratio == null) return this;
    if (w != null && h == null) return _Pair(w, w! / ratio);
    if (h != null && w == null) return _Pair(h! * ratio, h);
    return this;
  }
}

/// A width and a height.
class _Sz {
  const _Sz(this.w, this.h);
  final double w, h;
}

/// An item's four margin edges, null where `auto`.
typedef _Edges = ({double? left, double? right, double? top, double? bottom});

double _fmax(double a, double b) => a > b ? a : b;
double _fmin(double a, double b) => a < b ? a : b;

double? _maxN(double? a, double? b) => a == null ? null : (b == null ? a : _fmax(a, b));
double? _subN(double? a, double? b) => a == null ? null : (b == null ? a : a - b);
double? _clampN(double? a, double? min, double? max) => a == null ? null : _clamp(a, min, max);

double _clamp(double a, double? min, double? max) {
  var v = a;
  if (max != null && v > max) v = max;
  if (min != null && v < min) v = min;
  return v;
}

/// A size the item states: a length, a share of its area, both (an affine
/// `calc()`), or nothing.
class _Dim {
  const _Dim(this.px, this.fraction);
  final double? px, fraction;

  static _Dim of(double? px, double? fraction) => _Dim(px, fraction);

  bool get isAuto => px == null && fraction == null;

  /// A bare percentage, which is what makes a container sized by its
  /// content lay itself out again at the width it came to.
  bool get isPercent => px == null && fraction != null;

  /// Whether a share is any part of the size, bare or in a `calc()`.
  bool get usesShare => fraction != null && (px == null || fraction != 0);

  double? resolve(double? basis) {
    final f = fraction;
    if (f == null) return px;
    if (px == null) return basis == null ? null : basis * f;
    // `calc(px + f%)`: a share of nothing is nothing, unless there is no
    // share at all.
    return f == 0 ? px : (basis == null ? null : px! + f * basis);
  }

  /// [resolve] for a FLOOR: the share in a `calc()` of a width not known
  /// is taken of nothing (css-sizing-3 5.2.1, "for min size properties
  /// ... a cyclic percentage is resolved against zero"), so `min-width:
  /// calc(200px + 10%)` still floors an item's contribution to its tracks
  /// at 200 -- where a size or a cap with a share in it is no size at all.
  double? floorOf(double? basis) => basis == null && px != null && fraction != null ? px : resolve(basis);
}

// ============================================================ track sizes

enum _Kind { length, percent, calc, auto, minContent, maxContent, fitPx, fitPercent, fr }

/// One side of a track's `minmax()`: Taffy's `MinTrackSizingFunction` and
/// `MaxTrackSizingFunction`.
class _Fn {
  const _Fn(this.kind, [this.value = 0, this.px = 0, this.math]);
  final _Kind kind;

  /// A `min()`, `max()` or `clamp()` ([TrackSize.least], [TrackSize.most],
  /// [TrackSize.clamp]): a `calc()` whose length is the expression's,
  /// resolved against the basis as the engine resolves its `CalcExpr`.
  final TrackSize? math;

  /// The length, the fraction (`50%` is 0.5), the `fit-content()` limit or
  /// the flex factor; a `calc()`'s share of the basis.
  final double value;

  /// A `calc()`'s length.
  final double px;

  static const zero = _Fn(_Kind.length, 0);
  static const auto = _Fn(_Kind.auto);

  bool get isAuto => kind == _Kind.auto;
  bool get isMinContent => kind == _Kind.minContent;
  bool get isMaxContent => kind == _Kind.maxContent;
  bool get isFr => kind == _Kind.fr;
  bool get isFitContent => kind == _Kind.fitPx || kind == _Kind.fitPercent;
  bool get isIntrinsic => isAuto || isMinContent || isMaxContent || isFitContent;
  bool get isMaxContentAlike => isAuto || isMaxContent || isFitContent;
  bool get isMaxOrFitContent => isMaxContent || isFitContent;
  bool get isMinOrMaxContent => isMinContent || isMaxContent;
  bool get isLengthOrPercentage => kind == _Kind.length || kind == _Kind.percent;
  bool get usesPercentage => kind == _Kind.percent || kind == _Kind.fitPercent || kind == _Kind.calc;

  /// `fr` and `fit-content()` have an `auto` minimum.
  _Fn get asMin => (isFr || isFitContent) ? auto : this;

  bool hasDefiniteValue(double? parent) => switch (kind) {
    _Kind.length => true,
    _Kind.percent || _Kind.calc => parent != null,
    _ => false,
  };

  double? definiteValue(double? parent) => switch (kind) {
    _Kind.length => value,
    _Kind.percent => parent == null ? null : value * parent,
    _Kind.calc when math != null => _resolve(math!, parent),
    _Kind.calc => value == 0 ? px : (parent == null ? null : px + value * parent),
    _ => null,
  };

  /// As [definiteValue], but a `fit-content()` argument counts as a limit.
  double? definiteLimit(double? parent) => switch (kind) {
    _Kind.fitPx => value,
    _Kind.fitPercent => parent == null ? null : value * parent,
    _ => definiteValue(parent),
  };

  double? resolvedPercentageSize(double parent) => switch (kind) {
    _Kind.percent => value * parent,
    _Kind.calc when math != null => _resolve(math!, parent),
    _Kind.calc => value == 0 ? px : px + value * parent,
    _ => null,
  };
}

/// The length the expression [t] -- a [_Least], [_Most] or [_Clamp] over
/// lengths and shares -- comes to against [parent]: null where a share has
/// no basis, as the engine's `CalcExpr.resolve` answers, in the same order
/// of operations, so that the two come to the same doubles.
double? _resolve(TrackSize t, double? parent) {
  switch (t) {
    case _Fixed(:final px):
      return px;
    // A share of nothing needs no basis: the engine's `0%` is a length.
    case _Fraction(:final of):
      final pct = _share(of);
      return pct == 0 ? 0 : (parent == null ? null : pct * parent);
    case _Affine(:final px, :final of):
      final pct = _share(of);
      return pct == 0 ? px : (parent == null ? null : px + pct * parent);
    case _Least(:final a, :final b) || _Most(:final a, :final b):
      final x = _resolve(a, parent), y = _resolve(b, parent);
      if (x == null || y == null) return null;
      return t is _Least ? math.min(x, y) : math.max(x, y);
    case _Clamp(:final min, :final value, :final max):
      final lo = _resolve(min, parent), mid = _resolve(value, parent), hi = _resolve(max, parent);
      if (lo == null || mid == null || hi == null) return null;
      return math.max(lo, math.min(mid, hi));
    default:
      return null;
  }
}

/// Whether [t] is a length [_resolve] reads: a fixed length, a share, an
/// affine of the two, or a `min()`, `max()` or `clamp()` of those, every
/// number in it finite.
bool _mathOk(TrackSize t) => switch (t) {
  _Fixed(:final px) => px.isFinite,
  _Fraction(:final of) => (of * 100).isFinite,
  _Affine(:final px, :final of) => px.isFinite && (of * 100).isFinite,
  _Least(:final a, :final b) || _Most(:final a, :final b) => _mathOk(a) && _mathOk(b),
  _Clamp(:final min, :final value, :final max) => _mathOk(min) && _mathOk(value) && _mathOk(max),
  _ => false,
};

/// A share as the grid reads it: the fraction goes out as a percentage and
/// comes back as that percentage over a hundred, which is not always the
/// same double.
double _share(double of) => of * 100 / 100;

/// A breadth: the one side of a track any single size can be. Null where
/// CSS could not say it -- a size that is not a finite number, a negative
/// `fr` -- which makes the whole list `none`.
_Fn? _breadth(TrackSize t) {
  switch (t) {
    case _Fixed(:final px):
      return px.isFinite ? _Fn(_Kind.length, px) : null;
    case _Flex(:final factor):
      return !factor.isFinite || factor.isNegative ? null : _Fn(_Kind.fr, factor);
    case _Fraction(:final of):
      return (of * 100).isFinite ? _Fn(_Kind.percent, _share(of)) : null;
    case _Affine(:final px, :final of):
      if (!px.isFinite || !(of * 100).isFinite) return null;
      final pct = _share(of);
      if (pct == 0) return _Fn(_Kind.length, px);
      if (px == 0) return _Fn(_Kind.percent, pct);
      return _Fn(_Kind.calc, pct, px);
    case _UpTo(:final px):
      return px.isFinite ? _Fn(_Kind.fitPx, px) : null;
    case _UpToFraction(:final of):
      return (of * 100).isFinite ? _Fn(_Kind.fitPercent, _share(of)) : null;
    case _Keyword(:final kind):
      return _Fn(kind);
    case _Least() || _Most() || _Clamp():
      return _mathOk(t) ? _Fn(_Kind.calc, 0, 0, t) : null;
    case _Between() || _Repeat() || _AutoRepeat():
      return null;
  }
}

/// A single track's `minmax()`, or null where it is not one CSS can say.
(_Fn, _Fn)? _single(TrackSize t) {
  if (t is _Between) {
    final min = _breadth(t.min), max = _breadth(t.max);
    if (min == null || max == null || min.isFr || min.isFitContent) return null;
    return (min, max);
  }
  final max = _breadth(t);
  return max == null ? null : (max.asMin, max);
}

/// One component of a track list: a single track or a `repeat()`.
class _Component {
  _Component.single(this.single) : tracks = const [], count = 0, auto = false, fits = false;
  _Component.repeat(this.tracks, this.count, {this.auto = false, this.fits = false}) : single = null;

  final (_Fn, _Fn)? single;
  final List<(_Fn, _Fn)> tracks;
  final int count;
  final bool auto, fits;

  bool get isAutoRepetition => single == null && auto;

  /// A `<fixed-breadth>` on either side (css-grid-1 7.2.3.1): a length or
  /// a percentage, and so a `calc()`, `min()`, `max()` or `clamp()` of
  /// them -- `minmax(min(112px, 100%), 1fr)` is the fixed size an
  /// auto-repeat repeats. Read as none, the whole template was `none` and
  /// the items stood in one implicit column (`fixtures/grid-auto-repeat-math-track`).
  static bool _fixedComponent((_Fn, _Fn) t) => _fixedBreadth(t.$1) || _fixedBreadth(t.$2);
  static bool _fixedBreadth(_Fn f) => f.isLengthOrPercentage || f.kind == _Kind.calc;
  bool get hasFixedComponent => single != null ? _fixedComponent(single!) : tracks.every(_fixedComponent);
}

/// A written track list, or null where one of its parts is not a track --
/// which makes the whole list `none`, as a declaration CSS cannot parse is.
List<_Component>? _template(List<TrackSize> list) {
  if (list.isEmpty) return null;
  final out = <_Component>[];
  for (final t in list) {
    final repeated = switch (t) {
      _Repeat(:final tracks) || _AutoRepeat(:final tracks) => tracks,
      _ => null,
    };
    if (repeated == null) {
      final s = _single(t);
      if (s == null) return null;
      out.add(_Component.single(s));
      continue;
    }
    final inner = <(_Fn, _Fn)>[];
    for (final x in repeated) {
      final s = _single(x);
      if (s == null) return null;
      inner.add(s);
    }
    if (inner.isEmpty) return null;
    switch (t) {
      case _Repeat(:final count):
        if (count <= 0) return null;
        out.add(_Component.repeat(inner, count > 65535 ? 65535 : count));
      case _AutoRepeat(:final fits):
        out.add(_Component.repeat(inner, 0, auto: true, fits: fits));
      default:
        return null;
    }
  }
  return out;
}

/// `grid-auto-columns` / `grid-auto-rows`: single tracks only, and `auto`
/// where the list is empty or cannot be read.
List<(_Fn, _Fn)> _autoTracks(List<TrackSize> list) {
  const fallback = [(_Fn.auto, _Fn.auto)];
  if (list.isEmpty) return fallback;
  final out = <(_Fn, _Fn)>[];
  for (final t in list) {
    final s = _single(t);
    if (s == null) return fallback;
    out.add(s);
  }
  return out;
}

// ================================================================== grid

const int _maxTracks = 10000;
const int _i16Min = -32768, _i16Max = 32767;

int _clampI16(int v) => v < _i16Min ? _i16Min : (v > _i16Max ? _i16Max : v);

/// Taffy's `GridTrack`: a track or a gutter, and its sizing state.
class _Track {
  _Track.track(this.min, this.max) : gutter = false;
  _Track.gutter(_Fn size) : gutter = true, min = size, max = size;

  final bool gutter;
  bool collapsed = false;
  _Fn min, max;
  double offset = 0;
  double base = 0;
  double limit = 0;
  double alignAdjust = 0;
  double incurred = 0;
  double basePlanned = 0;
  double limitPlanned = 0;
  bool infinitelyGrowable = false;

  void collapse() {
    collapsed = true;
    min = _Fn.zero;
    max = _Fn.zero;
  }

  bool get isFlexible => max.isFr;
  bool get usesPercentage => min.usesPercentage || max.usesPercentage;
  bool get hasIntrinsic => min.isIntrinsic || max.isIntrinsic;
  double get flexFactor => max.isFr ? max.value : 0.0;

  double fitLimit(double? space) => switch (max.kind) {
    _Kind.fitPx => max.value,
    _Kind.fitPercent => space == null ? double.infinity : space * max.value,
    _ => double.infinity,
  };

  double fitLimitedGrowth(double? space) => _fmin(limit, fitLimit(space));
}

/// Taffy's `TrackCounts`, in OriginZero lines: 0 is the start of the
/// explicit grid.
class _Counts {
  const _Counts(this.negative, this.explicit, this.positive);
  final int negative, explicit, positive;
  int get len => negative + explicit + positive;
  int get startLine => -negative;
  int get endLine => explicit + positive;
  int nextTrack(int oz) => oz + negative;
  int prevLine(int index) => index - negative;
}

/// The track vector index of an OriginZero line: lines at even indices,
/// tracks at odd ones.
int _vecIndex(int oz, _Counts c) {
  assert(oz >= -c.negative && oz <= c.explicit + c.positive);
  return 2 * (oz + c.negative);
}

enum _Cell { definite, auto }

/// A run of occupied cells of one track: `[start, end)` along it.
class _Run {
  _Run(this.start, this.end, this.state);
  int start, end;
  _Cell state;
  bool overlaps(int s, int e) => start < e && end > s;
  _Run copy() => _Run(start, end, state);
}

/// The occupied cells of one track, sorted and disjoint.
class _Runs {
  final List<_Run> runs = [];

  bool get isEmpty => runs.isEmpty;

  void paint(int s, int e, _Cell state) {
    if (s >= e) return;
    if (runs.isEmpty) {
      runs.add(_Run(s, e, state));
      return;
    }
    final last = runs.last;
    if (last.end <= s) {
      if (last.state == state && last.end == s) {
        last.end = e;
      } else {
        runs.add(_Run(s, e, state));
      }
      return;
    }
    final out = <_Run>[];
    for (final r in runs) {
      if (r.end <= s) {
        out.add(r.copy());
      } else if (r.start < s) {
        out.add(_Run(r.start, s, r.state));
      }
    }
    if (out.isNotEmpty && out.last.state == state && out.last.end == s) {
      out.last.end = e;
    } else {
      out.add(_Run(s, e, state));
    }
    for (final r in runs) {
      _Run t;
      if (r.start >= e) {
        t = r.copy();
      } else if (r.end > e) {
        t = _Run(e, r.end, r.state);
      } else {
        continue;
      }
      if (out.last.state == t.state && out.last.end == t.start) {
        out.last.end = t.end;
      } else {
        out.add(t);
      }
    }
    runs
      ..clear()
      ..addAll(out);
  }

  int? collision(int s, int e) {
    for (var k = runs.length - 1; k >= 0; k--) {
      if (runs[k].overlaps(s, e)) return runs[k].end - 1;
    }
    return null;
  }

  int? lastOf(_Cell state) {
    for (var k = runs.length - 1; k >= 0; k--) {
      if (runs[k].state == state) return runs[k].end - 1;
    }
    return null;
  }
}

/// Taffy's `CellOccupancyMatrix`. `horizontal` is the column axis.
class _Occupancy {
  _Occupancy(this.columns, this.rows)
    : _byRow = List.generate(rows.len, (_) => _Runs()),
      _byColumn = List.generate(columns.len, (_) => _Runs());

  _Counts columns, rows;
  final List<_Runs> _byRow, _byColumn;

  List<_Runs> _lists(bool horizontal) => horizontal ? _byColumn : _byRow;
  _Counts counts(bool horizontal) => horizontal ? columns : rows;

  void _expand((int, int) rowSpan, (int, int) colSpan) {
    final negRows = math.max(-rows.negative - rowSpan.$1, 0);
    final posRows = math.max(rowSpan.$2 - rows.endLine, 0);
    final negCols = math.max(-columns.negative - colSpan.$1, 0);
    final posCols = math.max(colSpan.$2 - columns.endLine, 0);
    if (negRows > 0) _byRow.insertAll(0, List.generate(negRows, (_) => _Runs()));
    if (posRows > 0) _byRow.addAll(List.generate(posRows, (_) => _Runs()));
    if (negCols > 0) _byColumn.insertAll(0, List.generate(negCols, (_) => _Runs()));
    if (posCols > 0) _byColumn.addAll(List.generate(posCols, (_) => _Runs()));
    rows = _Counts(rows.negative + negRows, rows.explicit, rows.positive + posRows);
    columns = _Counts(columns.negative + negCols, columns.explicit, columns.positive + posCols);
  }

  void mark(bool primaryHorizontal, (int, int) primary, (int, int) secondary, _Cell state) {
    final rowSpan = primaryHorizontal ? secondary : primary;
    final colSpan = primaryHorizontal ? primary : secondary;
    _expand(rowSpan, colSpan);
    final rs = rows.nextTrack(rowSpan.$1), re = rows.nextTrack(rowSpan.$2);
    final cs = columns.nextTrack(colSpan.$1), ce = columns.nextTrack(colSpan.$2);
    for (var r = rs; r < re; r++) {
      _byRow[r].paint(colSpan.$1, colSpan.$2, state);
    }
    for (var c = cs; c < ce; c++) {
      _byColumn[c].paint(rowSpan.$1, rowSpan.$2, state);
    }
  }

  int? collisionJump(bool primaryHorizontal, (int, int) primary, (int, int) secondary) {
    final lists = _lists(!primaryHorizontal);
    final c = counts(!primaryHorizontal);
    final s = math.max(c.nextTrack(secondary.$1), 0);
    final e = math.min(c.nextTrack(secondary.$2), lists.length);
    int? extent;
    for (var i = s; i < e; i++) {
      final cell = lists[i].collision(primary.$1, primary.$2);
      if (cell == null) continue;
      extent = extent == null ? cell : math.max(extent, cell);
    }
    return extent == null ? null : extent + 1;
  }

  int? occupiedJump(bool horizontal, (int, int) span) {
    final c = counts(horizontal);
    final lists = _lists(horizontal);
    final s = math.max(c.nextTrack(span.$1), 0);
    final e = math.min(c.nextTrack(span.$2), lists.length);
    for (var i = e - 1; i >= s; i--) {
      if (!lists[i].isEmpty) return c.prevLine(i) + 1;
    }
    return null;
  }

  bool rowOccupied(int i) => i >= 0 && i < _byRow.length && !_byRow[i].isEmpty;
  bool columnOccupied(int i) => i >= 0 && i < _byColumn.length && !_byColumn[i].isEmpty;

  int? lastOf(bool trackHorizontal, int startAt, _Cell state) {
    final c = counts(!trackHorizontal);
    final idx = c.nextTrack(startAt);
    final lists = _lists(!trackHorizontal);
    if (idx < 0 || idx >= lists.length) return null;
    return lists[idx].lastOf(state);
  }
}

/// A grid line as the item wrote it, before the grid knows how many tracks
/// it has.
sealed class _Place {
  const _Place();
}

class _Auto extends _Place {
  const _Auto();
}

class _Line extends _Place {
  const _Line(this.line);
  final int line;
}

class _SpanOf extends _Place {
  const _SpanOf(this.span);
  final int span;
}

/// CSS grid line coordinates (1 is the explicit grid's start, -1 its end)
/// to OriginZero ones, clamped to the limited grid.
_Place _toOz(_Place p, int explicit) => switch (p) {
  _Auto() => p,
  _SpanOf(:final span) => _SpanOf(span < 1 ? 1 : (span > _maxTracks ? _maxTracks : span)),
  _Line(:final line) =>
    line == 0
        ? const _Auto()
        : _Line(() {
            final oz = line > 0 ? line - 1 : line + explicit + 1;
            return oz < -_maxTracks ? -_maxTracks : (oz > _maxTracks ? _maxTracks : oz);
          }()),
};

bool _definite((_Place, _Place) p) => p.$1 is _Line || p.$2 is _Line;

int _indefiniteSpan((_Place, _Place) p) {
  final s = p.$1, e = p.$2;
  if (s is _SpanOf) return s.span;
  if (e is _SpanOf) return e.span;
  return 1;
}

/// css-grid-1 8.3.1: two lines, a line and a span, or one line.
(int, int) _definiteLines((_Place, _Place) p) {
  final s = p.$1, e = p.$2;
  if (s is _Line && e is _Line) {
    if (s.line == e.line) return (s.line, s.line + 1);
    return (math.min(s.line, e.line), math.max(s.line, e.line));
  }
  if (s is _Line && e is _SpanOf) return (s.line, s.line + e.span);
  if (s is _Line) return (s.line, s.line + 1);
  if (s is _SpanOf && e is _Line) return (e.line - s.span, e.line);
  if (e is _Line) return (e.line - 1, e.line);
  throw StateError('not a definite placement');
}

(int, int) _spanAt(int position, int span) =>
    (position.clamp(_i16Min, _i16Max), (position + span).clamp(_i16Min, _i16Max));

/// The item's own start and end lines, as its [TrackCell] states them.
(_Place, _Place) _written(int? start, int? end, int span) => (
  start == null ? const _Auto() : _Line(_clampI16(start >= 0 ? start + 1 : start - 1)),
  end != null
      ? _Line(_clampI16(end >= 0 ? end + 1 : end))
      // `span 0` is no span at all, and a negative one is one track.
      : span == 0
      ? const _Auto()
      : _SpanOf(span < 0 ? 0 : (span > 65535 ? 65535 : span)),
);

/// The placement [p] across a COLUMN subgrid of [count] columns, clamped
/// onto them: "each grid item's grid area is clamped to the subgrid's
/// explicit grid (using the same procedure as for clamping placement in an
/// overly-large grid)" (css-grid-2 9) -- an area that runs past the last
/// line stops there, one wholly past it is the last track alone, and one
/// wholly before the first is the first (css-grid-1 "Clamping Overly Large
/// Grids"); a span the flow places is at most [count]. Across, the axis the
/// flow runs along, Chrome clamps BEFORE the flow runs, so the flow wraps
/// at the subgrid's last column: `grid-column: 5` after three items in a
/// subgrid of three stands on the third column a row down, not over the
/// third item. (Down its rows, the axis the flow adds tracks to, it clamps
/// after: [_Grid._onRows].) Null for a line BEFORE the first: Chrome's
/// flow then runs over as many more columns as the line is in front --
/// `grid-column: -9 / 2` in a subgrid of three lands a `span 5` after it
/// past the third column, and the clamp stands it on the third, over the
/// item there -- which no clamp of the one item says.
(_Place, _Place)? _clampAcross((_Place, _Place) p, int count) {
  final (a, b) = p;
  int? line(_Place x) => x is _Line ? (x.line > 0 ? x.line - 1 : count + 1 + x.line) : null;
  final x = line(a), y = line(b);
  if ((x != null && x < 0) || (y != null && y < 0)) return null;
  int from, to;
  if (x != null && y != null) {
    (from, to) = x < y ? (x, y) : (x == y ? (x, x + 1) : (y, x));
  } else if (x != null) {
    (from, to) = (x, x + (b is _SpanOf ? b.span : 1));
  } else if (y != null) {
    (from, to) = (y - (a is _SpanOf ? a.span : 1), y);
  } else {
    final n = a is _SpanOf ? a.span : (b is _SpanOf ? b.span : 1);
    return n > count ? (const _Auto(), _SpanOf(count)) : p;
  }
  if (to <= 0 || from < 0) return null;
  if (from >= count) {
    (from, to) = (count - 1, count);
  } else {
    (from, to) = (math.max(from, 0), math.min(to, count));
  }
  return (_Line(from + 1), _Line(to + 1));
}

enum _Measure { layout, horizontal, vertical }

/// One child's measurements over one pass: Taffy's per-node cache, which
/// hands back a size it measured for a question that differs only in what
/// the answer does not depend on.
class _Cache {
  final List<_Key?> keys = List.filled(9, null);
  final List<_Sz?> sizes = List.filled(9, null);
  int next = 0;
  _Key? lastKey;
  _Leaf? last;

  /// Forgets every answer: what it measured was a question about columns
  /// that have since moved ([_Grid._subgridColumns]).
  void clear() {
    keys.fillRange(0, 9, null);
    sizes.fillRange(0, 9, null);
    next = 0;
    lastKey = null;
    last = null;
  }
}

class _Key {
  _Key(this.kw, this.kh, this.pw, this.ph, this.aw, this.ah, this.axis);
  final double? kw, kh, pw, ph;
  final _Space aw, ah;

  /// 0 both, 1 horizontal, 2 vertical.
  final int axis;

  static Object _either(double? k, _Space a) => k == null ? a : ('k', k);

  bool measures(_Key o) =>
      _either(kw, aw) == _either(o.kw, o.aw) &&
      _either(kh, ah) == _either(o.kh, o.ah) &&
      pw == o.pw &&
      (axis == 0 || axis == o.axis);

  bool exact(_Key o) =>
      kw == o.kw && kh == o.kh && pw == o.pw && ph == o.ph && aw == o.aw && ah == o.ah && axis == o.axis;
}

/// A child laid out as a leaf: its size, whether its margins could
/// collapse through it (which keeps it out of the cache), and its baseline.
class _Leaf {
  const _Leaf(this.size, {this.through = false, this.baseline});
  final _Sz size;
  final bool through;
  final double? baseline;
}

/// Taffy's `GridItem`: one child during one run of the algorithm.
class _Item {
  _Item(this.child, this.cache, this.data, this.column, this.row, this.source, _Grid grid)
    : alignSelf = data.align ?? grid.config.align,
      _justifySelf = data.justify ?? grid.config.justify;

  final RenderBox child;
  final _Cache cache;
  final TrackCellParentData data;
  final int source;

  /// OriginZero lines.
  final (int, int) column, row;

  /// `align-self` and `justify-self`, the grid's where the item has none.
  final CellAlign alignSelf, _justifySelf;

  /// A COLUMN SUBGRID'S CELL is stretched across its columns whatever it
  /// says: "the justify-self property on it is ignored, as are any
  /// specified width constraints" (css-grid-2 9).
  CellAlign get justifySelf => columnSubgrid != null ? CellAlign.stretch : _justifySelf;
  bool get _widthless => columnSubgrid != null;

  /// How wide an item of a row subgrid with columns of its own is in it
  /// ([_Grid._ownWidths]): the one width it is asked its height at, as an
  /// item of the grid round the subgrid.
  double? imposedWidth;

  /// Whether the item stands in for the EDGE OF A SUBGRID with no item on
  /// it ([_Grid._leaves]): it is nothing but the margin it carries, and
  /// its child, the subgrid, is not measured for it.
  bool hollow = false;

  (int, int) columnIdx = (0, 0), rowIdx = (0, 0);
  bool flexColumn = false, flexRow = false, intrinsicColumn = false, intrinsicRow = false;

  _Pair? areaCache;
  double? minContentW, minContentH, maxContentW, maxContentH, minimumW, minimumH;

  /// Where the item came to, for the grid's baseline and its layout.
  double outY = 0, outW = 0, outH = 0, x = 0;
  double? baseline;

  /// The subgrid under the item, where it is a [TrackCell.subgrid] cell
  /// that holds one ([_Grid._leaves]), and the rows it is laid out on.
  RenderTracks? subgrid;
  List<double>? imposed;

  /// The subgrid under the item where its COLUMNS are this grid's
  /// ([_Grid._columnLeaves]), and the columns it is laid out on.
  RenderTracks? columnSubgrid;
  List<double>? imposedColumns;

  /// Where the item's first baseline is as its row lines it up -- its
  /// min-content layout's, below its top margin -- and the room above it
  /// that puts it on the row's lowest (Taffy `baseline`, `baseline_shim`).
  double? rowBaseline;
  double shim = 0;

  /// Whether the item lines its baseline up with its row's (css-align-3 9,
  /// css-grid-1 "row-align"): it says `baseline`, no `auto` margin down the
  /// block axis takes the room instead, and its height is not a share of a
  /// row its content sizes, which would make each wait on the other.
  bool get baselined =>
      alignSelf == CellAlign.baseline &&
      !data.autoMargin.top &&
      !data.autoMargin.bottom &&
      !(_h.usesShare && (intrinsicRow || flexRow));

  bool get clips => data.clips;

  /// The preferred aspect ratio, width over height.
  double? get ratio => data.ratio;

  _Dim get _w => _widthless
      ? const _Dim(null, null)
      : imposedWidth != null
      ? _Dim(imposedWidth, null)
      : _Dim.of(data.width, data.widthFraction);
  _Dim get _h => _Dim.of(data.height, data.heightFraction);
  _Dim get _minW =>
      _widthless || imposedWidth != null ? const _Dim(null, null) : _Dim.of(data.minWidth, data.minWidthFraction);
  _Dim get _minH => _Dim.of(data.minHeight, null);
  _Dim get _maxW =>
      _widthless || imposedWidth != null ? const _Dim(null, null) : _Dim.of(data.maxWidth, data.maxWidthFraction);
  _Dim get _maxH => _Dim.of(data.maxHeight, null);

  bool get sharesWidth => _w.isPercent || _minW.isPercent || _maxW.isPercent;

  /// A [TrackCell.compressible] item's min-content width: its width and
  /// its cap with each share in them taken of nothing, over its floor.
  /// Null where it is not compressible, or no share is in either.
  double? get squeezedWidth {
    if (!data.compressible || !(_w.usesShare || _maxW.usesShare)) return null;
    final w = _w.resolve(0.0), cap = _maxW.resolve(0.0);
    final v = w == null ? cap : (cap == null ? w : math.min(w, cap));
    if (v == null) return null;
    return math.max(math.max(v, _minW.floorOf(null) ?? 0.0), 0.0);
  }

  _Pair size(_Pair basis) => _Pair(_w.resolve(basis.w), _h.resolve(basis.h));
  _Pair minSize(_Pair basis) => _Pair(_minW.floorOf(basis.w), _minH.resolve(basis.h));
  _Pair maxSize(_Pair basis) => _Pair(_maxW.resolve(basis.w), _maxH.resolve(basis.h));

  /// The margin edges, null where `auto`: each the length plus its share
  /// of [basis], the width of the item's area, or of nothing where that is
  /// not known.
  _Edges margin(double? basis) {
    final m = data.margin, share = data.marginShare, auto = data.autoMargin, b = basis ?? 0.0;
    double? edge(bool isAuto, double px, double of) => isAuto ? null : (of != 0 ? px + of * b : px);
    return (
      left: edge(auto.left, m.left, share.left),
      right: edge(auto.right, m.right, share.right),
      top: edge(auto.top, m.top, share.top),
      bottom: edge(auto.bottom, m.bottom, share.bottom),
    );
  }

  /// The margins a size contribution adds on each axis, an `auto` one as
  /// nothing and the baseline [shim] on top (Taffy
  /// `margins_axis_sums_with_baseline_shims`): a share ACROSS is of nothing,
  /// since the width it is a share of is the one being sized, and a share
  /// DOWN is of [basis].
  _Sz margins(double? basis) {
    final across = margin(0.0), down = margin(basis);
    return _Sz((across.left ?? 0) + (across.right ?? 0), ((down.top ?? 0) + shim) + (down.bottom ?? 0));
  }

  (int, int) placement(bool inline) => inline ? column : row;
  (int, int) indexes(bool inline) => inline ? columnIdx : rowIdx;
  int span(bool inline) => math.max(placement(inline).$2 - placement(inline).$1, 0);
  bool crossesFlex(bool inline) => inline ? flexColumn : flexRow;
  bool crossesIntrinsic(bool inline) => inline ? intrinsicColumn : intrinsicRow;

  List<_Track> spanned(bool inline, List<_Track> tracks) => tracks.sublist(indexes(inline).$1 + 1, indexes(inline).$2);

  bool spansMatching(bool inline, List<_Track> tracks, bool Function(_Track) test) {
    final (s, e) = (indexes(inline).$1 + 1, indexes(inline).$2);
    for (var i = s; i < e; i++) {
      if (test(tracks[i])) return true;
    }
    return false;
  }

  double? spannedLimit(bool inline, List<_Track> tracks, double? parent) {
    var limit = 0.0;
    for (final t in spanned(inline, tracks)) {
      final v = t.max.definiteLimit(parent);
      if (v == null) return null;
      limit += v;
    }
    return limit;
  }

  double? spannedFixedLimit(bool inline, List<_Track> tracks, double? parent) {
    var limit = 0.0;
    for (final t in spanned(inline, tracks)) {
      final v = t.max.definiteValue(parent);
      if (v == null) return null;
      limit += v;
    }
    return limit;
  }

  static bool _stretches(CellAlign a) => a == CellAlign.stretch;

  /// The sizes the item is measured at: what it states, else the area it
  /// stretches to (Taffy `GridItem::known_dimensions`). A ratio turns a
  /// size on one axis into one on the other, the stretched one included.
  _Pair known(_Pair area) {
    final m = margins(area.w);
    final inherent = size(area).ratio(ratio);
    final min = minSize(area).ratio(ratio), max = maxSize(area).ratio(ratio);
    final room = area.less(_Pair(m.w, m.h)).floor(const _Pair(0, 0));
    var width = inherent.w;
    if (width == null && !data.autoMargin.left && !data.autoMargin.right && _stretches(justifySelf)) width = room.w;
    final across = _Pair(width, inherent.h).ratio(ratio);
    width = across.w;
    var height = across.h;
    if (height == null && !data.autoMargin.top && !data.autoMargin.bottom && _stretches(alignSelf)) height = room.h;
    return _Pair(width, height).ratio(ratio).clamp(min, max);
  }

  /// Taffy `GridItem::grid_area_size`.
  _Pair area(
    bool inline,
    List<_Track> axisTracks,
    List<_Track> otherTracks,
    _Pair inner,
    double? Function(_Track, double?) estimate,
  ) {
    double? axisSum = 0.0;
    final basis = inner.get(inline);
    for (final t in spanned(inline, axisTracks)) {
      final min = t.min.definiteValue(basis), max = t.max.definiteValue(basis);
      if (min == null || max == null || min != max) {
        axisSum = null;
        break;
      }
      axisSum = axisSum! + t.base;
    }
    double? otherSum = 0.0;
    final otherBasis = inner.get(!inline);
    for (final t in spanned(!inline, otherTracks)) {
      final est = estimate(t, otherBasis);
      if (est == null) {
        otherSum = null;
        break;
      }
      otherSum = otherSum! + est + t.alignAdjust;
    }
    return inline ? _Pair(axisSum, otherSum) : _Pair(otherSum, axisSum);
  }

  /// The margins a contribution adds on one axis, a share down the block
  /// axis one of [basis] (see [margins]).
  double marginSum(bool inline, double? basis) => inline ? margins(basis).w : margins(basis).h;
}

/// One run of the grid algorithm over the children as they are now.
class _Grid {
  _Grid(this.config, List<RenderBox> children, {this.rtl = false, this.subgrids = const {}, this.imposed = false})
    : kids = children {
    for (final c in children) {
      caches[c] = _Cache();
    }
  }

  final Tracks config;

  /// Whether the columns run from the right.
  final bool rtl;

  /// Whether any item lines its baseline up with its row's, which has every
  /// child's layout report where its text sits.
  late final bool aligned =
      config.align == CellAlign.baseline ||
      kids.any((c) => (c.parentData! as TrackCellParentData).align == CellAlign.baseline);
  final List<RenderBox> kids;
  final Map<RenderBox, _Cache> caches = {};

  /// The columns each column subgrid's cell was last measured on: its
  /// cache holds answers about those columns and no others.
  final Map<RenderBox, List<double>> _measuredOn = {};

  /// The subgrids in the items, by the child each is under.
  final Map<RenderBox, RenderTracks> subgrids;

  /// Whether the rows are a subgrid's, handed down by the grid round it
  /// ([RenderTracks._effective]). Its columns were sized as an item of
  /// that grid, BEFORE any row was (css-grid-2 9: the subgrid is an
  /// ordinary item in the axis it does not subgrid), so no row's size
  /// reaches them: a picture held at a ratio by its padding is as wide as
  /// its column in Chrome, and asked its width at the row's height it
  /// would answer the height times the ratio -- dba's framed card, 288 in
  /// a 286 column.
  final bool imposed;

  // ------------------------------------------------------------- subgrids

  /// Where each item of a subgrid -- [c], its [children], the boxes out of
  /// the flow left out, its own subgrids in [subgrids] -- stands on the
  /// [rows] rows its cell spans, and on the subgrid's OWN columns: the
  /// first and the end of each, zero-based, in child order. Null where
  /// this grid cannot share its rows, which is what [_leaves] reads;
  /// [imposed] is the subgrid's own run, on the rows its host gave it.
  ///
  /// A SUBGRID PLACES ITS ITEMS AS ANY GRID DOES (css-grid-1 8.5), on its
  /// own columns and on as many rows as its cell spans: an item that names
  /// its row takes it, first, in the first column free there -- two that
  /// name the same row stand side by side, the second in a column of its
  /// own if need be -- and the rest go along the rows in order from a
  /// cursor that only moves on, on rows past the last if need be. Only
  /// then does it show it has no rows of its own to add: "each grid item's
  /// grid area is clamped to the subgrid's explicit grid (using the same
  /// procedure as for clamping placement in an overly-large grid)"
  /// (css-grid-2 9), so an area that runs past the last row stops at its
  /// end and one that starts past it is the last row alone (css-grid-1,
  /// "Clamping Overly Large Grids"). dba's card with a line more than its
  /// three rows stands it on the third, OVER the price already there
  /// (`fixtures/grid-row-subgrid` p8); one with its spec at `grid-row: 2`
  /// has its subtitle a row further down (`grid-row-subgrid-pair` p6).
  /// AN ITEM ON A COLUMN BEFORE THE FIRST -- a line counted from the end
  /// of none, `grid-column: -2` -- makes an implicit column in front of it
  /// (css-grid-1 7.5, 8.3): across, a subgrid in the rows alone is an
  /// ordinary grid (css-grid-2 9), so the column is its own, and the flow
  /// starts from it. Its areas are origin-zero, 0 the first explicit line.
  /// COLUMNS REPEATED TO FILL ITS WIDTH repeat ONCE ([_countsOnce]).
  /// Refused: an item on a row before the first, a margin the rows cannot
  /// hold, and a subgrid inside it whose repeated columns Chrome counts in
  /// a width its cell states ([_statesWidth]).
  static List<((int, int), (int, int))>? _onRows(
    Tracks c,
    List<RenderBox> children,
    Map<RenderBox, RenderTracks> subgrids,
    int rows, {
    bool imposed = false,
  }) {
    if (!c.subgridRows || rows < 1 || c.runSpacingFraction != null || c.flow != TrackFlow.row) return null;
    if (!imposed && c.rows.isNotEmpty) return null;
    final kids = [
      for (final k in children)
        if (!(k.parentData! as TrackCellParentData).positioned) k,
    ];
    final written = <(RenderBox, TrackCellParentData, (_Place, _Place), (_Place, _Place))>[];
    for (final k in kids) {
      final d = k.parentData! as TrackCellParentData;
      if (d.autoMargin.top || d.autoMargin.bottom || d.marginShare != EdgeInsets.zero) return null;
      written.add((k, d, _written(d.column, d.columnEnd, d.columnSpan), _written(d.row, d.rowEnd, d.rowSpan)));
    }
    final grid = _Grid(
      Tracks(
        columns: c.columns,
        rows: List.filled(rows, const TrackSize.fixed(0)),
        flow: c.flow,
        autoColumns: c.autoColumns,
        autoRows: c.autoRows,
      ),
      kids,
    );
    final (_, columns) = _explicitCount(_template(c.columns), null, false, _Fn(_Kind.length, c.spacing));
    final (estCols, estRows) = _estimate(columns, rows, written);
    final placed = grid._place(_Occupancy(estCols, estRows), written, columns, rows);
    final out = List<((int, int), (int, int))>.filled(kids.length, ((0, 0), (0, 0)));
    for (final (_, d, column, row, i) in placed) {
      var (a, b) = row;
      if (a < 0) return null;
      if (a >= rows) {
        (a, b) = (rows - 1, rows);
      } else if (b > rows) {
        b = rows;
      }
      final nested = d.subgrid ? subgrids[kids[i]] : null;
      if (nested != null &&
          (_statesWidth(d, nested) || _onRows(nested._config, nested._children, nested._subgrids, b - a) == null)) {
        return null;
      }
      out[i] = ((a, b), column);
    }
    return out;
  }

  /// The CAP ACROSS a row subgrid's cell [d] states on its border box, a
  /// length and a share of its area: stretched across the area, the cell is
  /// the smaller of the two (css-grid-1 11.3, css-align-3 6.1 "stretch"
  /// under a max size), and a subgrid in the rows alone is an ordinary item
  /// across (css-grid-2 9). Null where it states none, or a width or a
  /// floor as well.
  static (double, double)? _capOf(TrackCellParentData d) =>
      (d.maxWidth != null || d.maxWidthFraction != null) &&
          d.width == null &&
          d.widthFraction == null &&
          (d.minWidth ?? 0) <= 0 &&
          d.minWidthFraction == null
      ? (d.maxWidth ?? 0.0, d.maxWidthFraction ?? 0.0)
      : null;

  /// Whether a row subgrid's own columns REPEATED TO FILL ITS WIDTH
  /// (`repeat(auto-fill, ..)`) repeat ONCE: a subgrid's grid is placed
  /// with its host's, before any column is sized (css-grid-2 9), and a
  /// width that is only the area it is stretched across is not known
  /// then, so "the specified track list repeats only once" (css-grid-1
  /// 7.2.3.2). Chrome, measured: `repeat(auto-fill, minmax(90px, 1fr))`
  /// in a 280px body is one 280px column, and an item beside the first on
  /// its row takes an implicit one; in a plain grid item of that width it
  /// is three. Once in the subgrid's own run on its host's rows too.
  static bool _countsOnce(Tracks c) => c.subgridRows && c.columns.any((t) => t is _AutoRepeat);

  /// Whether the cell [d] of the row subgrid [sub], whose columns repeat
  /// to fill ([_countsOnce]), states a width, a cap or a floor: Chrome
  /// counts the repetitions in that (css-grid-1 7.2.3.2, "a definite size
  /// or max size"), which the rows it shares do not wait for -- refused.
  /// Not a cap that is a SHARE alone: a share of an area not yet sized when
  /// the grid is placed is no definite size, and Chrome repeats once there
  /// as under no cap (`fixtures/grid-row-subgrid-cap` p6: `max-width: 80%`
  /// round `repeat(auto-fill, 90px)` is one column in a 250px body).
  static bool _statesWidth(TrackCellParentData d, RenderTracks sub) =>
      _countsOnce(sub._config) &&
      (d.width != null ||
          d.widthFraction != null ||
          d.maxWidth != null ||
          (d.minWidth ?? 0) > 0 ||
          d.minWidthFraction != null);

  /// Whether the items of the row subgrid [sub], on [rows] rows, stand on
  /// more than the one column of it -- its own or a subgrid's inside it --
  /// or in a subgrid inside it held to a CAP ([_capOf]), which has each
  /// measured at its own column's width ([_ownWidths]). dba's card is a
  /// subgrid and its body one inside it: a body held to 180px in a 280px
  /// area wraps its title at 180, and the row it stands on is that tall
  /// (`fixtures/grid-row-subgrid-cap` p2).
  static bool _acrossColumns(RenderTracks sub, int rows) {
    final areas = _onRows(sub._config, sub._children, sub._subgrids, rows);
    if (areas == null) return false;
    if (_countsOnce(sub._config) || areas.any((x) => x.$2 != (0, 1))) return true;
    var at = 0;
    for (final child in sub._children) {
      final d = child.parentData! as TrackCellParentData;
      if (d.positioned) continue;
      final ((a, b), column) = areas[at++];
      final nested = d.subgrid ? sub._subgrids[child] : null;
      if (nested != null && (_capOf(d) != null || _acrossColumns(nested, b - a))) return true;
    }
    return false;
  }

  /// How wide each item of the row subgrid [sub] is, [width] its content
  /// box and [rows] the rows it spans, into [out] by child -- the items of
  /// its own subgrids too, inside the widths they come to. It is laid out
  /// as it will be, its columns sized before any row (css-grid-2 9: the
  /// subgrid is an ordinary item across, and its own grid there), on rows
  /// of nothing: no width of an item waits on a row.
  static void _ownWidths(RenderTracks sub, double width, int rows, Map<RenderBox, double> out) {
    final grid = _Grid(
      sub._onRowsOf(List.filled(rows, 0.0)),
      sub._children,
      rtl: sub._textDirection == TextDirection.rtl,
      subgrids: sub._subgrids,
      imposed: true,
    );
    final items = grid
        .run(
          known: _Pair(width, null),
          parent: _Pair(width, null),
          available: (_Space.definite(width), _Space.maxContent),
        )
        .items;
    for (final item in items) {
      final nested = item.data.subgrid ? sub._subgrids[item.child] : null;
      if (nested != null && nested._config.subgridRows) {
        _ownWidths(
          nested,
          _fmax(item.outW - nested._config.subgridFrame.horizontal, 0.0),
          item.row.$2 - item.row.$1,
          out,
        );
      } else {
        out[item.child] = item.outW;
      }
    }
  }

  /// The items of the subgrid [sub], under the item [cell], as items of
  /// THIS grid on the rows [cell] spans: each with its own margin and, on
  /// the side of each gutter it stands beside, half the difference between
  /// the subgrid's gutter and this grid's [gap], and on the subgrid's own
  /// edges [edge] -- its cell's margin, its frame, and the edges of the
  /// subgrids round it (css-grid-2 9). A subgrid's own subgrids give up
  /// their items the same way, on the rows their cells span.
  ///
  /// AN EDGE ROW NO ITEM STANDS ON STILL HOLDS THE EDGE: the subgrid's
  /// margin, border and padding there are contributed to the track sizing
  /// as a hypothetical item on that row (css-grid-2 9, "for each edge of a
  /// subgrid ... a hypothetical item is contributed"), of no size and that
  /// [edge] -- no gutter's half difference of the subgrid's own, which
  /// lies inside its edge. dba's card whose subtitle stands beside its
  /// title leaves the last row of its body empty, and the body's 16px
  /// bottom margin is still under it in Chrome.
  void _leaves(RenderTracks sub, _Item cell, int from, int rows, EdgeInsets edge, double gap, List<_Item> out) {
    final own = sub._config;
    final half = (own.runSpacing - gap) / 2;
    final areas = _onRows(own, sub._children, sub._subgrids, rows)!;
    var at = 0;
    var first = false, last = false;
    for (final child in sub._children) {
      final d = child.parentData! as TrackCellParentData;
      if (d.positioned) continue;
      final ((a, b), _) = areas[at++];
      if (a == 0) first = true;
      if (b == rows) last = true;
      final top = a == 0 ? edge.top : half, bottom = b == rows ? edge.bottom : half;
      final nested = d.subgrid ? sub._subgrids[child] : null;
      if (nested != null) {
        final f = nested._config.subgridFrame;
        _leaves(
          nested,
          cell,
          from + a,
          b - a,
          EdgeInsets.fromLTRB(
            edge.left + d.margin.left + f.left,
            top + d.margin.top + f.top,
            edge.right + d.margin.right + f.right,
            bottom + d.margin.bottom + f.bottom,
          ),
          gap,
          out,
        );
        continue;
      }
      final data = d._widened(EdgeInsets.fromLTRB(edge.left, top, edge.right, bottom), own.align, own.justify);
      out.add(_Item(child, _Cache(), data, cell.column, (from + a, from + b), cell.source, this));
    }
    void hollow(int row, double top, double bottom) {
      if (top + bottom <= 0) return;
      final data = TrackCellParentData()
        ..align = CellAlign.start
        ..margin = EdgeInsets.only(top: top, bottom: bottom);
      out.add(_Item(sub, _Cache(), data, cell.column, (from + row, from + row + 1), cell.source, this)..hollow = true);
    }

    if (rows == 1) {
      if (!first) hollow(0, edge.top, edge.bottom);
    } else {
      if (!first) hollow(0, edge.top, 0);
      if (!last) hollow(rows - 1, 0, edge.bottom);
    }
  }

  /// Where each item of a COLUMN subgrid -- [c], its [children], the boxes
  /// out of the flow left out -- stands on the [columns] columns its cell
  /// spans: the first and the end, zero-based, in child order. Null where
  /// the grid round it cannot share them ([Tracks.subgridColumns]).
  ///
  /// The items are placed as the subgrid itself places them on that many
  /// columns of its own (css-grid-1 8.5), so the two cannot disagree: the
  /// flow runs along its rows and wraps at the last column, and it has
  /// rows of its own to wrap onto. An item on a line past its columns is
  /// CLAMPED onto them first ([_clampAcross]). Refused: an item on a line
  /// before its first, an item that is a subgrid itself, and a margin
  /// across the columns cannot hold -- `auto`, or a share of the width
  /// being sized.
  static List<(int, int)>? _onColumns(Tracks c, List<RenderBox> children, int columns) {
    if (!c.subgridColumns || c.subgridRows || columns < 1) return null;
    if (c.columns.isNotEmpty || c.spacingFraction != null) return null;
    if (c.flow != TrackFlow.row && c.flow != TrackFlow.rowDense) return null;
    if (c.rows.any((t) => t is _AutoRepeat)) return null;
    final kids = [
      for (final k in children)
        if (!(k.parentData! as TrackCellParentData).positioned) k,
    ];
    for (final k in kids) {
      final d = k.parentData! as TrackCellParentData;
      if (d.subgrid || d.autoMargin.left || d.autoMargin.right) return null;
      if (d.marginShare.left != 0 || d.marginShare.right != 0) return null;
    }
    final grid = _Grid(
      Tracks(columns: List.filled(columns, const TrackSize.fixed(0)), rows: c.rows, flow: c.flow, autoRows: c.autoRows),
      kids,
    );
    final written = <(RenderBox, TrackCellParentData, (_Place, _Place), (_Place, _Place))>[
      for (final k in kids)
        () {
          final d = k.parentData! as TrackCellParentData;
          return (k, d, _written(d.column, d.columnEnd, d.columnSpan), _written(d.row, d.rowEnd, d.rowSpan));
        }(),
    ];
    for (var i = 0; i < written.length; i++) {
      final (k, d, across, down) = written[i];
      final clamped = _clampAcross(across, columns);
      if (clamped == null) return null;
      written[i] = (k, d, clamped, down);
    }
    final (_, rowCount) = _explicitCount(_template(c.rows), null, false, _Fn(_Kind.length, c.runSpacing));
    final (estCols, estRows) = _estimate(columns, rowCount, written);
    final placed = grid._place(_Occupancy(estCols, estRows), written, columns, rowCount);
    final out = List<(int, int)>.filled(kids.length, (0, 0));
    for (final (_, _, column, _, i) in placed) {
      if (column.$1 < 0 || column.$2 > columns) return null;
      out[i] = column;
    }
    return out;
  }

  /// The items of the COLUMN subgrid [sub], under the item [cell], as items
  /// of THIS grid on the columns [areas] give them from the cell's first:
  /// each with its own margin, half the difference between the subgrid's
  /// gutter and this grid's [gap] on the side of each gutter it stands
  /// beside, and [edge] -- the cell's margin and the subgrid's frame -- on
  /// the subgrid's own edges (css-grid-2 9). They size the columns, and
  /// no row: the subgrid's rows are its own, and the cell sizes the rows
  /// it spans ([_subgridHeight]). An edge column no item stands on holds
  /// the edge all the same, as a row does ([_leaves]): a `padding-right:
  /// 60px` subgrid with nothing on its last `1fr` keeps that column 60
  /// wide in Chrome.
  void _columnLeaves(
    RenderTracks sub,
    _Item cell,
    List<(int, int)> areas,
    int columns,
    EdgeInsets edge,
    double gap,
    List<_Item> out,
  ) {
    final own = sub._config;
    final half = (own.spacing - gap) / 2;
    var at = 0;
    var first = false, last = false;
    for (final child in sub._children) {
      final d = child.parentData! as TrackCellParentData;
      if (d.positioned) continue;
      final (a, b) = areas[at++];
      if (a == 0) first = true;
      if (b == columns) last = true;
      final left = a == 0 ? edge.left : half, right = b == columns ? edge.right : half;
      final data = d._widened(EdgeInsets.fromLTRB(left, 0, right, 0), own.align, own.justify);
      out.add(_Item(child, _Cache(), data, (cell.column.$1 + a, cell.column.$1 + b), cell.row, cell.source, this));
    }
    void hollow(int column, double left, double right) {
      if (left + right <= 0) return;
      final data = TrackCellParentData()
        ..align = CellAlign.start
        ..justify = CellAlign.start
        ..margin = EdgeInsets.only(left: left, right: right);
      out.add(
        _Item(sub, _Cache(), data, (cell.column.$1 + column, cell.column.$1 + column + 1), cell.row, cell.source, this)
          ..hollow = true,
      );
    }

    if (columns == 1) {
      if (!first) hollow(0, edge.left, edge.right);
    } else {
      if (!first) hollow(0, edge.left, 0);
      if (!last) hollow(columns - 1, 0, edge.right);
    }
  }

  /// The sizes of the columns of [item]'s COLUMN subgrid, from the start of
  /// its own box: its host's [columns] as they were sized -- nothing here
  /// spreads them apart, see [Tracks.subgridColumns] -- each gutter the
  /// subgrid's own centred in the host's, the first and the last track
  /// short by its frame and its cell's margin (css-grid-2 9).
  List<double> _subgridColumns(_Item item, List<_Track> columns) {
    final sub = item.columnSubgrid!;
    final f = sub._config.subgridFrame, m = item.data.margin, g = sub._config.spacing;
    final first = item.columnIdx.$1 + 1, n = (item.columnIdx.$2 - item.columnIdx.$1) ~/ 2;
    final starts = <double>[], ends = <double>[];
    var at = 0.0;
    for (var j = 0; j < n; j++) {
      starts.add(at);
      at += columns[first + 2 * j].base;
      ends.add(at);
      if (j < n - 1) at += columns[first + 2 * j + 1].base;
    }
    final left = m.left + f.left, right = at - m.right - f.right;
    return [
      for (var j = 0; j < n; j++)
        _fmax(
          (j == n - 1 ? right : ends[j] + (starts[j + 1] - ends[j] - g) / 2) -
              (j == 0 ? left : starts[j] - (starts[j] - ends[j - 1] - g) / 2),
          0.0,
        ),
    ];
  }

  /// How big [item]'s COLUMN subgrid's box is at the width [known] holds it
  /// to, or the columns come to: laid out on the columns this grid sized
  /// for it, its rows its own, its frame round them. It is asked here and
  /// not through the widgets round it, which keep what they answered for a
  /// width whatever columns it stood for.
  _Sz _subgridHeight(_Item item, _Pair known) {
    final sub = item.columnSubgrid!, columns = item.imposedColumns!;
    final f = sub._config.subgridFrame;
    var sum = 0.0;
    for (final w in columns) {
      sum += w;
    }
    final w = known.w ?? sum + (columns.length - 1) * sub._config.spacing + f.horizontal;
    if (known.h != null) return _Sz(w, known.h!);
    final inner = _fmax(w - f.horizontal, 0.0);
    final grid = _Grid(sub._onColumnsOf(columns), sub._children, subgrids: sub._subgrids);
    final h = grid
        .run(
          known: _Pair(inner, null),
          parent: _Pair(inner, null),
          available: (_Space.definite(inner), _Space.maxContent),
          measure: _Measure.vertical,
        )
        .size
        .h;
    return _Sz(w, h + f.vertical);
  }

  /// The sizes of the rows of [item]'s subgrid, down from the top of its
  /// own box: its host's tracks where they stand, each gutter the
  /// subgrid's own centred in the host's, the first and the last track
  /// short by its frame and its cell's margin (css-grid-2 9).
  List<double> _imposed(_Item item, List<_Track> rowTracks) {
    final sub = item.subgrid!;
    final frame = sub._config.subgridFrame;
    final g = sub._config.runSpacing;
    final top = item.outY + frame.top;
    final height = item.outH - frame.top - frame.bottom;
    final first = item.rowIdx.$1 + 1, n = (item.rowIdx.$2 - item.rowIdx.$1) ~/ 2;
    double start(int j) => rowTracks[first + 2 * j].offset;
    double end(int j) => rowTracks[first + 2 * j + 1].offset;
    return [
      for (var j = 0; j < n; j++)
        _fmax(
          (j == n - 1 ? height : end(j) + (start(j + 1) - end(j) - g) / 2 - top) -
              (j == 0 ? 0.0 : start(j) - (start(j) - end(j - 1) - g) / 2 - top),
          0.0,
        ),
    ];
  }

  /// Whether each item's baseline is worked out: only a question about the
  /// grid's own baseline needs them, and each is a dry layout.
  bool baselines = false;

  List<_Item> items = const [];

  // ------------------------------------------------------------ one leaf

  /// A child laid out as a leaf of the box tree: Taffy's
  /// `compute_leaf_layout` over the item's own box, with Flutter measuring
  /// what is inside it -- the item's margins, size and clamps are the
  /// grid's to apply, and the child is asked only about its content.
  _Leaf _leaf(_Item item, _Pair known, _Pair parent, (_Space, _Space) available, _Measure run) {
    final cache = item.cache;
    final axis = switch (run) {
      _Measure.horizontal => 1,
      _Measure.vertical => 2,
      _ => 0,
    };
    final key = _Key(known.w, known.h, parent.w, parent.h, available.$1, available.$2, axis);
    if (run == _Measure.layout) {
      if (cache.lastKey != null && cache.lastKey!.exact(key)) return cache.last!;
    } else {
      for (var i = 0; i < 9; i++) {
        final k = cache.keys[i];
        if (k != null && k.measures(key)) return _Leaf(cache.sizes[i]!);
      }
    }
    final out = _computeLeaf(item, known, parent, available, run);
    if (run == _Measure.layout) {
      cache.lastKey = key;
      cache.last = out;
    } else if (!out.through) {
      var stored = false;
      for (var i = 0; i < 9; i++) {
        final k = cache.keys[i];
        if (k != null && k.exact(key)) {
          cache.sizes[i] = out.size;
          stored = true;
          break;
        }
      }
      if (!stored) {
        cache.keys[cache.next] = key;
        cache.sizes[cache.next] = out.size;
        cache.next = (cache.next + 1) % 9;
      }
    }
    return out;
  }

  _Leaf _computeLeaf(_Item item, _Pair known, _Pair parent, (_Space, _Space) available, _Measure run) {
    final sizing = run != _Measure.layout;
    final ratio = item.ratio;
    // A MIN-CONTENT WIDTH is asked of a box that can be any width, so a
    // share of a width no one has settled transfers no height through the
    // ratio, and a floor across it transfers no width.
    final minContentWidth = known.w == null && available.$1.isMin;
    // The style size BEFORE the ratio fills in an automatic axis: an axis
    // that is automatic here is the one a clamp on the other re-derives.
    final stated = item.size(parent);
    var styleSize = minContentWidth && item._w.isPercent && stated.w == null
        ? _Pair(null, stated.h)
        : stated.ratio(ratio);
    // A width the item is HELD to over the one it states re-derives the
    // automatic height through the ratio.
    if (ratio != null && known.w != null && stated.h == null && styleSize.h != null) {
      styleSize = _Pair(styleSize.w, known.w! / ratio);
    }
    final rawMin = item.minSize(parent);
    final transferred = rawMin.ratio(ratio);
    final takesTransfer = !minContentWidth && known.w == null && stated.w == null;
    final nodeSize = known.or(styleSize);
    final nodeMin = takesTransfer ? transferred : _Pair(rawMin.w, transferred.h);
    final nodeMax = item.maxSize(parent);
    // What stops the box's own margins collapsing through it -- which is
    // also what lets a measurement of a box of known size skip its content.
    final prevents = item.clips || (nodeSize.h != null && nodeSize.h! > 0) || (nodeMin.h != null && nodeMin.h! > 0);
    if (sizing && prevents && nodeSize.w != null && nodeSize.h != null) {
      final w = _clamp(nodeSize.w!, nodeMin.w, nodeMax.w);
      var h = _clamp(nodeSize.h!, nodeMin.h, nodeMax.h);
      // A width the clamp moved takes its automatic height with it.
      if (ratio != null && w != nodeSize.w && known.h == null && stated.h == null) {
        h = _clamp(w / ratio, nodeMin.h, nodeMax.h);
      }
      return _Leaf(_Sz(_fmax(w, 0), _fmax(h, 0)));
    }
    // The margins are the item's, `auto` as none and a share as one of the
    // width it is laid out in, or of nothing before that is known.
    final margin = item.margin(parent.w);
    final mx = (margin.left ?? 0.0) + (margin.right ?? 0.0);
    final my = (margin.top ?? 0.0) + (margin.bottom ?? 0.0);
    final aw = (known.w != null ? _Space.definite(known.w!) : available.$1)
        .sub(mx)
        .set(known.w)
        .set(nodeSize.w)
        .map((s) => _clamp(s, nodeMin.w, nodeMax.w));
    final ah = (known.h != null ? _Space.definite(known.h!) : available.$2)
        .sub(my)
        .set(known.h)
        .set(nodeSize.h)
        .map((s) => _clamp(s, nodeMin.h, nodeMax.h));
    final ownWidth = known.w ?? _clampN(nodeSize.w, nodeMin.w, nodeMax.w);
    final asked = sizing || ownWidth != null
        ? _Pair(
            ownWidth == null ? null : _fmax(0.0, ownWidth),
            known.h == null || !sizing ? null : _fmax(0.0, known.h!),
          )
        : const _Pair(null, null);
    final measured = item.columnSubgrid != null && item.imposedColumns != null
        ? _subgridHeight(item, asked)
        : _measure(item.child, asked, (aw, ah), ratio);
    final baseW = known.w ?? nodeSize.w ?? measured.w, baseH = known.h ?? nodeSize.h ?? measured.h;
    var w = _clamp(baseW, nodeMin.w, nodeMax.w);
    var h = _clamp(baseH, nodeMin.h, nodeMax.h);
    // CSS 2.1 10.4 through the ratio: a clamp on one automatic axis
    // re-derives the other, and otherwise the ratio's height is the least
    // an automatic height can be -- held by its own floor and cap.
    final autoW = known.w == null && stated.w == null, autoH = known.h == null && stated.h == null;
    if (ratio != null && w != baseW && autoH) {
      h = _clamp(w / ratio, nodeMin.h, nodeMax.h);
    } else if (ratio != null && h != baseH && autoW && !minContentWidth) {
      w = _clamp(h * ratio, nodeMin.w, nodeMax.w);
    } else if (ratio != null && autoH) {
      h = _fmax(h, _clamp(w / ratio, nodeMin.h, nodeMax.h));
    }
    final size = _Sz(_fmax(w, 0), _fmax(h, 0));
    double? baseline;
    if (!sizing && (baselines || aligned)) {
      baseline = dryBaselineOf(item.child, BoxConstraints.tight(Size(size.w, size.h)), TextBaseline.alphabetic);
    }
    return _Leaf(size, through: !prevents && size.h == 0 && measured.h == 0, baseline: baseline);
  }

  /// A Flutter child answering the grid's question. Every case is a question
  /// Flutter already knows how to answer: a min-content width is the min
  /// intrinsic width, a width in the room there is is a dry layout in that
  /// room, and a height at a width is a dry layout at that width.
  static _Sz _measure(RenderBox child, _Pair known, (_Space, _Space) available, [double? ratio]) {
    if (known.w != null && known.h != null) return _Sz(known.w!, known.h!);
    return guardedSize(child, () => _measured(child, known, available, ratio));
  }

  static _Sz _measured(RenderBox child, _Pair known, (_Space, _Space) available, double? ratio) {
    final at = known.h ?? double.infinity;
    final space = available.$1;
    // A child with a ratio is as tall as the ratio makes it at the width it
    // is offered, which is the room its own content is laid out in.
    final width =
        known.w ??
        (space.isMin
            ? child.getMinIntrinsicWidth(at)
            : space.isMax
            ? child.getMaxIntrinsicWidth(at)
            : math.max(
                child.getMinIntrinsicWidth(at),
                child
                    .getDryLayout(
                      known.h != null
                          ? BoxConstraints(maxWidth: math.max(0.0, space.value), minHeight: at, maxHeight: at)
                          : ratio != null && ratio > 0
                          ? BoxConstraints(
                              maxWidth: math.max(0.0, space.value),
                              maxHeight: math.max(0.0, space.value) / ratio,
                            )
                          : BoxConstraints(maxWidth: math.max(0.0, space.value)),
                    )
                    .width,
              ));
    // A height at a width the item is HELD to is a dry layout at that width,
    // not the height of a box merely offered it; an unbounded answer is no
    // answer, and the intrinsic is the same question asked of the content.
    final held = known.h == null && known.w != null
        ? child.getDryLayout(BoxConstraints.tightFor(width: width)).height
        : null;
    return _Sz(width, known.h ?? (held != null && held.isFinite ? held : child.getMaxIntrinsicHeight(width)));
  }

  /// A measurement of [item] on one axis (Taffy `measure_child_size`).
  double _size(_Item item, _Pair known, _Pair parent, (_Space, _Space) available, bool inline) {
    final out = _leaf(item, known, parent, available, inline ? _Measure.horizontal : _Measure.vertical).size;
    return inline ? out.w : out.h;
  }

  double _minContent(_Item item, bool inline, _Pair area, _Pair available) {
    if (item.hollow) return 0.0;
    final cached = inline ? item.minContentW : item.minContentH;
    if (cached != null) return cached;
    final v =
        (inline ? item.squeezedWidth : null) ??
        _size(item, item.known(area), area, (
          available.w == null ? _Space.minContent : _Space.definite(available.w!),
          available.h == null ? _Space.minContent : _Space.definite(available.h!),
        ), inline);
    if (inline) {
      item.minContentW = v;
    } else {
      item.minContentH = v;
    }
    return v;
  }

  double _maxContent(_Item item, bool inline, _Pair area, _Pair available) {
    if (item.hollow) return 0.0;
    final cached = inline ? item.maxContentW : item.maxContentH;
    if (cached != null) return cached;
    final v = _size(item, item.known(area), area, (
      available.w == null ? _Space.maxContent : _Space.definite(available.w!),
      available.h == null ? _Space.maxContent : _Space.definite(available.h!),
    ), inline);
    if (inline) {
      item.maxContentW = v;
    } else {
      item.maxContentH = v;
    }
    return v;
  }

  /// css-grid-1 6.6: the smallest the item may be, which is its stated size
  /// or minimum where it has one, nothing where it clips, and its
  /// min-content size capped by the fixed tracks it spans otherwise.
  double _minimum(_Item item, bool inline, List<_Track> axisTracks, _Pair area, _Pair inner) {
    if (item.hollow) return 0.0;
    final cached = inline ? item.minimumW : item.minimumH;
    if (cached != null) return cached;
    double compute() {
      if (inline && item.squeezedWidth != null) return _minContent(item, inline, area, area);
      final v =
          item.size(area).ratio(item.ratio).get(inline) ??
          item.minSize(area).ratio(item.ratio).get(inline) ??
          (item.clips ? 0.0 : null);
      if (v != null) return v;
      final (s, e) = (item.indexes(inline).$1 + 1, item.indexes(inline).$2);
      // QUIRK (Taffy): every track of the axis is tested here, not only
      // the ones the item spans.
      final spansAutoMin = axisTracks.any((t) => t.min.isAuto);
      final onlyOne = (e - s) == 1;
      final spansFlex = axisTracks.any((t) => t.max.isFr);
      if (!(spansAutoMin && (onlyOne || !spansFlex))) return 0.0;
      // QUIRK (Taffy): asked with the area as the available space, and
      // sharing its cache with the contribution asked without it.
      final mc = _minContent(item, inline, area, area);
      final limit = item.spannedFixedLimit(inline, axisTracks, inner.get(inline));
      return limit == null ? mc : _fmin(mc, limit);
    }

    final v = compute();
    if (inline) {
      item.minimumW = v;
    } else {
      item.minimumH = v;
    }
    return v;
  }

  // -------------------------------------------------------------- the run

  /// Taffy `compute_grid_layout` for a box with no padding, border or
  /// stated size of its own: those are the widgets' round it.
  ({_Sz size, double? baseline, List<_Item> items}) run({
    required _Pair known,
    required _Pair parent,
    required (_Space, _Space) available,
    _Pair min = const _Pair(null, null),
    _Pair max = const _Pair(null, null),
    _Measure measure = _Measure.layout,
  }) {
    final sizing = measure != _Measure.layout;
    final alignContent = config.alignContent ?? TrackContent.stretch;
    final justifyContent = config.justifyContent ?? TrackContent.stretch;
    final gapW = config.spacingFraction != null
        ? _Fn(_Kind.percent, config.spacingFraction!)
        : _Fn(_Kind.length, config.spacing);
    final gapH = config.runSpacingFraction != null
        ? _Fn(_Kind.percent, config.runSpacingFraction!)
        : _Fn(_Kind.length, config.runSpacing);

    // 1. The available grid space.
    final sizeOrAvailable = (
      known.w != null ? _Space.definite(known.w!) : available.$1,
      known.h != null ? _Space.definite(known.h!) : available.$2,
    );
    final availableGrid = (
      sizeOrAvailable.$1.map((v) => _fmax(_clamp(v, min.w, max.w), 0)),
      sizeOrAvailable.$2.map((v) => _fmax(_clamp(v, min.h, max.h), 0)),
    );
    final outer = known.clamp(min, max).floor(const _Pair(0, 0));
    if (sizing) {
      if (outer.w != null && outer.h != null) return (size: _Sz(outer.w!, outer.h!), baseline: null, items: const []);
      if (measure == _Measure.horizontal && outer.w != null) {
        return (size: _Sz(outer.w!, 0), baseline: null, items: const []);
      }
    }
    var inner = outer;

    // 2. The explicit grid.
    final autoFitSize = outer.or(max).or(min).clamp(min, max).floor(const _Pair(0, 0));
    final fitsW = (outer.w ?? max.w) != null, fitsH = (outer.h ?? max.h) != null;
    final colTemplate = _template(config.columns), rowTemplate = _template(config.rows);
    // A subgrid's own repeated columns repeat once, its width not known
    // when its host placed its grid ([_Grid._countsOnce]).
    final once = imposed && _countsOnce(config);
    final (colRepeats, colCount) = _explicitCount(colTemplate, once ? null : autoFitSize.w, !once && fitsW, gapW);
    final (rowRepeats, rowCount) = _explicitCount(rowTemplate, autoFitSize.h, fitsH, gapH);
    final explicitCols = math.min(colCount, _maxTracks), explicitRows = math.min(rowCount, _maxTracks);

    // 3. The items, in document order (nothing here has an `order`).
    final written = <(RenderBox, TrackCellParentData, (_Place, _Place), (_Place, _Place))>[];
    // A box out of the flow takes no cell and sizes no track.
    final out = <RenderBox>[];
    for (final child in kids) {
      final d = child.parentData! as TrackCellParentData;
      if (child.parent case final RenderTracks host when d.room) host._offerRoom(child, double.infinity);
      if (d.positioned) {
        out.add(child);
        continue;
      }
      written.add((child, d, _written(d.column, d.columnEnd, d.columnSpan), _written(d.row, d.rowEnd, d.rowSpan)));
    }
    // A SUBGRID ON ITS HOST'S ROWS stands each item where its host stood it
    // ([_onRows]): on its own columns, on the rows the clamp left it -- two
    // of them on the one row where the clamp put them there.
    if (imposed) {
      if (_onRows(config, kids, subgrids, explicitRows, imposed: true) case final areas?) {
        // A column line before the first explicit one is counted back from
        // the end of the explicit columns (css-grid-1 8.3), past line 1.
        _Place across(int x) => _Line(x >= 0 ? x + 1 : x - explicitCols - 1);
        for (var i = 0; i < written.length; i++) {
          final ((a, b), (ca, cb)) = areas[i];
          written[i] = (written[i].$1, written[i].$2, (across(ca), across(cb)), _written(a, b, b - a));
        }
      }
    }
    // A COLUMN SUBGRID ON ITS HOST'S COLUMNS clamps each item onto them
    // before its flow runs ([_clampAcross]), as its host placed it
    // ([_onColumns]).
    if (config.subgridColumns && config.columns.isNotEmpty) {
      for (var i = 0; i < written.length; i++) {
        final (child, d, across, down) = written[i];
        written[i] = (child, d, _clampAcross(across, explicitCols) ?? across, down);
      }
    }
    final (estCols, estRows) = _estimate(explicitCols, explicitRows, written);
    final occupancy = _Occupancy(estCols, estRows);
    final placed = _place(occupancy, written, explicitCols, explicitRows);
    final cols = occupancy.columns, rows = occupancy.rows;

    // 4. The tracks.
    final columns = _initTracks(
      cols,
      colTemplate,
      _autoTracks(config.autoColumns),
      colRepeats,
      gapW,
      occupancy.columnOccupied,
    );
    final rowTracks = _initTracks(
      rows,
      rowTemplate,
      _autoTracks(config.autoRows),
      rowRepeats,
      gapH,
      occupancy.rowOccupied,
    );

    final items = <_Item>[
      for (var i = 0; i < placed.length; i++)
        _Item(placed[i].$1, caches[placed[i].$1]!, placed[i].$2, placed[i].$3, placed[i].$4, placed[i].$5, this),
    ];
    this.items = items;
    for (final item in items) {
      item.columnIdx = (_vecIndex(item.column.$1, cols), _vecIndex(item.column.$2, cols));
      item.rowIdx = (_vecIndex(item.row.$1, rows), _vecIndex(item.row.$2, rows));
      item.flexColumn = item.spansMatching(true, columns, (t) => t.isFlexible);
      item.intrinsicColumn = item.spansMatching(true, columns, (t) => t.hasIntrinsic);
      item.flexRow = item.spansMatching(false, rowTracks, (t) => t.isFlexible);
      item.intrinsicRow = item.spansMatching(false, rowTracks, (t) => t.hasIntrinsic);
    }

    // THE COLUMNS ARE SIZED BY A COLUMN SUBGRID'S ITEMS, not by the
    // subgrid: each is an item of this grid on the columns the subgrid
    // places it on inside its cell's ([_columnLeaves]), and the cell sizes
    // no column of its own. It sizes its rows, as tall as it comes to on
    // the columns they came to ([_subgridHeight]).
    final colItems = <_Item>[];
    final colGap = config.spacingFraction == null ? config.spacing : null;
    final spreads = switch (justifyContent) {
      TrackContent.spaceBetween || TrackContent.spaceAround || TrackContent.spaceEvenly => true,
      _ => false,
    };
    for (final item in items) {
      final sub = item.data.subgrid ? subgrids[item.child] : null;
      final span = item.column.$2 - item.column.$1;
      final d = item.data;
      final areas =
          sub == null ||
              colGap == null ||
              rtl ||
              sub._textDirection == TextDirection.rtl ||
              spreads ||
              d.autoMargin.left ||
              d.autoMargin.right ||
              d.marginShare.left != 0 ||
              d.marginShare.right != 0
          ? null
          : _onColumns(sub._config, sub._children, span);
      if (sub == null || areas == null) {
        colItems.add(item);
        continue;
      }
      item.columnSubgrid = sub;
      final m = d.margin, f = sub._config.subgridFrame;
      _columnLeaves(
        sub,
        item,
        areas,
        span,
        EdgeInsets.fromLTRB(m.left + f.left, 0, m.right + f.right, 0),
        colGap!,
        colItems,
      );
    }
    for (final item in colItems) {
      if (identical(item.cache, caches[item.child])) continue;
      item.columnIdx = (_vecIndex(item.column.$1, cols), _vecIndex(item.column.$2, cols));
      item.rowIdx = (_vecIndex(item.row.$1, rows), _vecIndex(item.row.$2, rows));
      item.flexColumn = item.spansMatching(true, columns, (t) => t.isFlexible);
      item.intrinsicColumn = item.spansMatching(true, columns, (t) => t.hasIntrinsic);
      item.flexRow = item.spansMatching(false, rowTracks, (t) => t.isFlexible);
      item.intrinsicRow = item.spansMatching(false, rowTracks, (t) => t.hasIntrinsic);
    }

    // THE ROWS ARE SIZED BY A SUBGRID'S ITEMS, not by the subgrid: each is
    // an item of this grid on the rows its cell spans ([_leaves]), and the
    // cell sizes no row of its own. Where they stand on columns of the
    // subgrid's own, each is as tall as it comes to at ITS column's width
    // ([_ownWidths]), which the cell's is shared out into once this grid's
    // columns are sized -- so the cell is stretched across them.
    final rowItems = <_Item>[];
    final acrossOwn = <_Item, List<_Item>>{};
    final gap = config.runSpacingFraction == null ? config.runSpacing : null;
    for (final item in items) {
      final sub = item.data.subgrid ? subgrids[item.child] : null;
      final span = item.row.$2 - item.row.$1;
      if (sub == null ||
          gap == null ||
          _statesWidth(item.data, sub) ||
          _onRows(sub._config, sub._children, sub._subgrids, span) == null) {
        rowItems.add(item);
        continue;
      }
      final d = item.data;
      // A CAPPED CELL is narrower than its area where the cap binds, and
      // its items are measured at the width it comes to ([_capOf]), which
      // only the imposed widths say.
      final across = _acrossColumns(sub, span) || _capOf(d) != null;
      if (across &&
          (!_Item._stretches(item.justifySelf) ||
              !item._w.isAuto ||
              d.autoMargin.left ||
              d.autoMargin.right ||
              d.marginShare.left != 0 ||
              d.marginShare.right != 0)) {
        rowItems.add(item);
        continue;
      }
      item.subgrid = sub;
      final m = d.margin, f = sub._config.subgridFrame;
      final first = rowItems.length;
      _leaves(
        sub,
        item,
        item.row.$1,
        span,
        EdgeInsets.fromLTRB(m.left + f.left, m.top + f.top, m.right + f.right, m.bottom + f.bottom),
        gap,
        rowItems,
      );
      if (across) acrossOwn[item] = rowItems.sublist(first);
    }
    for (final item in rowItems) {
      if (identical(item.cache, caches[item.child])) continue;
      item.columnIdx = (_vecIndex(item.column.$1, cols), _vecIndex(item.column.$2, cols));
      item.rowIdx = (_vecIndex(item.row.$1, rows), _vecIndex(item.row.$2, rows));
      item.flexColumn = item.spansMatching(true, columns, (t) => t.isFlexible);
      item.intrinsicColumn = item.spansMatching(true, columns, (t) => t.hasIntrinsic);
      item.flexRow = item.spansMatching(false, rowTracks, (t) => t.isFlexible);
      item.intrinsicRow = item.spansMatching(false, rowTracks, (t) => t.hasIntrinsic);
    }

    double? maxEstimate(_Track t, double? parent) => t.max.definiteValue(parent);
    double? baseEstimate(_Track t, double? parent) => t.base;

    // 5. Track sizing: the columns, then the rows at those columns.
    _sizeTracks(
      true,
      min.w,
      max.w,
      justifyContent,
      alignContent,
      availableGrid,
      inner,
      columns,
      rowTracks,
      colItems,
      imposed ? (_Track t, double? parent) => null : maxEstimate,
    );
    final columnSum = _sum(columns);
    inner = _Pair(inner.w ?? columnSum, inner.h);
    void imposeColumns() {
      for (final item in items) {
        if (item.columnSubgrid == null) continue;
        final fresh = _subgridColumns(item, columns);
        if (!listEquals(_measuredOn[item.child], fresh)) item.cache.clear();
        _measuredOn[item.child] = fresh;
        item.imposedColumns = fresh;
      }
      for (final MapEntry(key: cell, value: leaves) in acrossOwn.entries) {
        final sub = cell.subgrid!;
        // The cell's area as the columns came to, its gutters inside it.
        var area = 0.0;
        for (var i = cell.columnIdx.$1 + 1; i < cell.columnIdx.$2; i++) {
          area += columns[i].base;
        }
        var width = area - cell.data.margin.horizontal - sub._config.subgridFrame.horizontal;
        if (_capOf(cell.data) case (final px, final share)?) {
          width = math.min(width, px + share * area - sub._config.subgridFrame.horizontal);
        }
        final widths = <RenderBox, double>{};
        _ownWidths(sub, _fmax(width, 0.0), cell.row.$2 - cell.row.$1, widths);
        for (final leaf in leaves) {
          final fresh = widths[leaf.child];
          if (fresh == leaf.imposedWidth) continue;
          leaf.cache.clear();
          leaf.imposedWidth = fresh;
          leaf.areaCache = null;
          leaf.minContentH = null;
          leaf.maxContentH = null;
          leaf.minimumH = null;
        }
      }
    }

    imposeColumns();
    for (final item in items) {
      item.areaCache = null;
    }
    for (final item in colItems) {
      item.areaCache = null;
    }
    for (final item in rowItems) {
      item.areaCache = null;
    }
    _sizeTracks(
      false,
      min.h,
      max.h,
      alignContent,
      justifyContent,
      availableGrid,
      inner,
      rowTracks,
      columns,
      rowItems,
      baseEstimate,
    );
    final rowSum = _sum(rowTracks);
    inner = _Pair(inner.w, inner.h ?? rowSum);

    // 6. The container.
    var boxW = _fmax(_clamp(known.w ?? columnSum, min.w, max.w), 0);
    var boxH = _fmax(_clamp(known.h ?? rowSum, min.h, max.h), 0);
    var contentW = _fmax(0.0, boxW), contentH = _fmax(0.0, boxH);
    // A measurement stops here where nothing below can change its answer
    // (the block size is indefinite, so the re-resolution has nothing to
    // distribute).
    if (sizing && outer.h == null && min.h == null) return (size: _Sz(boxW, boxH), baseline: null, items: items);

    // 7. Percentage tracks against a container sized by its content.
    if (!availableGrid.$1.isDefinite) {
      for (final t in columns) {
        t.base = _clamp(t.base, t.min.resolvedPercentageSize(contentW), t.max.resolvedPercentageSize(contentW));
      }
    }
    if (!availableGrid.$2.isDefinite) {
      for (final t in rowTracks) {
        t.base = _clamp(t.base, t.min.resolvedPercentageSize(contentH), t.max.resolvedPercentageSize(contentH));
      }
    }

    // css-grid-2 12.1: the columns again, once, where the rows changed what
    // an item crossing an intrinsic column wants.
    final percentColumn = columns.any((t) => t.usesPercentage);
    final percentRow = rowTracks.any((t) => t.usesPercentage);
    var rerunColumns = !imposed && !available.$1.isDefinite && percentColumn;
    var columnChanged = false;
    if (imposed) {
      // Sized before the rows, and not again ([imposed]).
    } else if (!rerunColumns) {
      for (final item in colItems) {
        if (!item.intrinsicColumn || item.hollow) continue;
        final area = item.area(true, columns, rowTracks, inner, baseEstimate);
        final fresh =
            item.squeezedWidth ?? _size(item, item.known(area), area, (_Space.minContent, _space(area.h)), true);
        final changed = fresh != item.minContentW;
        item.areaCache = area;
        item.minContentW = fresh;
        item.maxContentW = null;
        item.minimumW = null;
        if (changed) {
          columnChanged = true;
          break;
        }
      }
      rerunColumns = columnChanged;
    } else {
      for (final item in colItems) {
        item.areaCache = null;
        item.minContentW = null;
        item.maxContentW = null;
        item.minimumW = null;
      }
    }
    var rowChanged = false;
    if (rerunColumns) {
      _sizeTracks(
        true,
        min.w,
        max.w,
        justifyContent,
        alignContent,
        availableGrid,
        inner,
        columns,
        rowTracks,
        colItems,
        baseEstimate,
      );
      imposeColumns();
      var rerunRows = !available.$2.isDefinite && percentRow;
      if (!rerunRows) {
        for (final item in rowItems) {
          // As Taffy: the items that cross an intrinsic COLUMN.
          if (!item.intrinsicColumn || item.hollow) continue;
          final area = item.area(false, rowTracks, columns, inner, baseEstimate);
          final fresh = _size(item, item.known(area), area, (_space(area.w), _Space.minContent), false);
          final changed = fresh != item.minContentH;
          item.areaCache = area;
          item.minContentH = fresh;
          item.maxContentH = null;
          item.minimumH = null;
          if (changed) {
            rowChanged = true;
            break;
          }
        }
        rerunRows = rowChanged;
      } else {
        for (final item in rowItems) {
          item.areaCache = null;
          item.minContentH = null;
          item.maxContentH = null;
          item.minimumH = null;
        }
      }
      if (rerunRows) {
        _sizeTracks(
          false,
          min.h,
          max.h,
          alignContent,
          justifyContent,
          availableGrid,
          inner,
          rowTracks,
          columns,
          rowItems,
          baseEstimate,
        );
      }
    }
    if ((columnChanged && !percentColumn) || (rowChanged && !percentRow)) {
      if (columnChanged && !percentColumn) {
        boxW = _fmax(_clamp(known.w ?? _sum(columns), min.w, max.w), 0);
        contentW = _fmax(0.0, boxW);
      }
      if (rowChanged && !percentRow) {
        boxH = _fmax(_clamp(known.h ?? _sum(rowTracks), min.h, max.h), 0);
        contentH = _fmax(0.0, boxH);
      }
    }
    if (sizing) return (size: _Sz(boxW, boxH), baseline: null, items: items);

    // 8. The tracks in the box, the columns from the right where they run
    // that way.
    _alignTracks(contentW, columns, justifyContent, reversed: rtl);
    _alignTracks(contentH, rowTracks, alignContent);

    // 9. The items in their areas, in document order. Right to left an
    // area's left edge is its last column's, and its right edge the line
    // before its first.
    _stableSort(items, (a, b) => a.source.compareTo(b.source));
    for (final item in items) {
      final (first, end) = item.columnIdx;
      _position(
        item,
        columns[rtl ? end - 1 : first + 1].offset,
        columns[rtl ? first : end].offset,
        rowTracks[item.rowIdx.$1 + 1].offset,
        rowTracks[item.rowIdx.$2].offset,
      );
      if (item.subgrid != null) item.imposed = _imposed(item, rowTracks);
    }

    // 10. The boxes out of the flow, each in the area its lines name: a line
    // as a start edge is the start of the track after it, as an end edge
    // the end of the track before it -- the gap beside a line is outside
    // the area, as it is for an item in the flow -- and a line it does not
    // name is this box's own edge.
    final placedOut = <_Item>[];
    for (final child in out) {
      final d = child.parentData! as TrackCellParentData;
      final c = _outLines(d.column, d.columnEnd, d.columnSpan, explicitCols, cols);
      final r = _outLines(d.row, d.rowEnd, d.rowSpan, explicitRows, rows);
      final item = _Item(child, caches[child]!, d, (0, 0), (0, 0), -1, this);
      _positionOut(
        item,
        rtl ? (c.$2 == null ? 0.0 : _rtlEndEdge(columns, c.$2!)) : (c.$1 == null ? 0.0 : _startEdge(columns, c.$1!)),
        rtl ? (c.$1 == null ? boxW : _rtlStartEdge(columns, c.$1!)) : (c.$2 == null ? boxW : _endEdge(columns, c.$2!)),
        r.$1 == null ? 0.0 : _startEdge(rowTracks, r.$1!),
        r.$2 == null ? boxH : _endEdge(rowTracks, r.$2!),
      );
      placedOut.add(item);
    }
    if (items.isEmpty) return (size: _Sz(boxW, boxH), baseline: null, items: placedOut);

    // The first row gives the grid its baseline: the first item in it that
    // lines its baseline up with the row's, else its first item -- and an
    // item with none of its own gives the one its row lined up, else its
    // bottom edge.
    final byRow = [...items];
    _stableSort(byRow, (a, b) => a.rowIdx.$1.compareTo(b.rowIdx.$1));
    final firstRow = byRow.takeWhile((i) => i.rowIdx.$1 == byRow.first.rowIdx.$1);
    final first = firstRow.firstWhere((i) => i.baselined, orElse: () => byRow.first);
    return (
      size: _Sz(boxW, boxH),
      baseline: first.outY + (first.baseline ?? first.rowBaseline ?? first.outH),
      items: [...items, ...placedOut],
    );
  }

  /// The track vector indexes of the lines a box out of the flow names,
  /// null where it names none (Taffy `resolve_absolutely_positioned_grid_
  /// tracks`): two lines, a line and a span, or one line and the box's own
  /// edge -- a start with no end and a span of one is a start alone
  /// (css-grid-1 9.3) -- and a line past the grid is none.
  static (int?, int?) _outLines(int? start, int? end, int span, int explicit, _Counts counts) {
    final w = _written(start, end, span);
    final s = _toOz(w.$1, explicit);
    final e = end == null && span == 1 ? const _Auto() : _toOz(w.$2, explicit);
    int? index(int oz) =>
        oz < -counts.negative || oz > counts.explicit + counts.positive ? null : _vecIndex(oz, counts);
    return switch ((s, e)) {
      (_Line(line: final a), _Line(line: final b)) =>
        a == b ? (index(a), index(a + 1)) : (index(math.min(a, b)), index(math.max(a, b))),
      (_Line(line: final a), _SpanOf(:final span)) => (index(a), index(a + span)),
      (_Line(line: final a), _) => (index(a), null),
      (_SpanOf(:final span), _Line(line: final b)) => (index(b - span), index(b)),
      (_, _Line(line: final b)) => (null, index(b)),
      _ => (null, null),
    };
  }

  /// A line used as a start edge: the start of the track after it.
  static double _startEdge(List<_Track> tracks, int index) =>
      (index + 1 < tracks.length ? tracks[index + 1] : tracks[index]).offset;

  /// A line used as an end edge: the end of the track before it.
  static double _endEdge(List<_Track> tracks, int index) =>
      index == 0 ? (tracks.length > 1 ? tracks[1] : tracks[0]).offset : tracks[index].offset;

  /// Right to left, a line used as a start edge: the right edge of the
  /// track after it, which is where the line's own gutter starts; with no
  /// track after it, the line itself.
  static double _rtlStartEdge(List<_Track> tracks, int index) {
    if (tracks.length > index + 1) return tracks[index].offset;
    if (index == 0) return tracks[0].offset;
    return tracks[index - 1].offset;
  }

  /// Right to left, a line used as an end edge: the left edge of the track
  /// before it.
  static double _rtlEndEdge(List<_Track> tracks, int index) => index == 0 ? tracks[0].offset : tracks[index - 1].offset;

  static _Space _space(double? v) => v == null ? _Space.minContent : _Space.definite(v);

  static double _sum(List<_Track> tracks) {
    var s = 0.0;
    for (final t in tracks) {
      s += t.base;
    }
    return s;
  }

  // ---------------------------------------------------- the explicit grid

  /// Taffy `compute_explicit_grid_size_in_axis`: how many times an
  /// auto-repeat repeats, and how many tracks the template makes.
  static (int, int) _explicitCount(List<_Component>? template, double? size, bool fitsWithin, _Fn gap) {
    if (template == null || template.isEmpty) return (0, 0);
    var fixedCount = 0;
    for (final c in template) {
      final n = c.single != null ? 1 : (c.auto ? 0 : c.count * c.tracks.length);
      fixedCount = math.min(fixedCount + n, _maxTracks);
    }
    final autoRepeats = template.where((c) => c.isAutoRepetition).length;
    final allFixed = template.every((c) => c.hasFixedComponent);
    if (!(autoRepeats == 0 || (autoRepeats == 1 && allFixed))) return (0, 0);
    if (autoRepeats == 0) return (0, fixedCount);

    var insertAt = 0;
    late _Component repetition;
    for (final c in template) {
      if (c.single != null) {
        insertAt += 1;
      } else if (c.auto) {
        repetition = c;
        break;
      } else {
        insertAt += c.count * c.tracks.length;
      }
    }
    final perCount = math.min(repetition.tracks.length, 65535);

    double definite((_Fn, _Fn) t, double parent) {
      final mx = t.$2.definiteValue(parent), mn = t.$1.definiteValue(parent);
      if (mx != null) return mn == null ? mx : _fmax(mx, mn);
      return mn!;
    }

    int repetitions;
    if (size == null) {
      repetitions = 1;
    } else {
      var used = 0.0;
      for (final c in template) {
        if (c.single != null) {
          used += definite(c.single!, size);
        } else if (!c.auto) {
          var sum = 0.0;
          for (final t in c.tracks) {
            sum += definite(t, size);
          }
          used += sum * c.count;
        }
      }
      final gapSize = gap.definiteValue(size) ?? 0.0;
      var per = 0.0;
      for (final t in repetition.tracks) {
        per += definite(t, size);
      }
      final firstAndFixed = used + per + math.max(fixedCount + perCount - 1, 0) * gapSize;
      if (firstAndFixed > size) {
        repetitions = 1;
      } else {
        final perWithGaps = per + perCount * gapSize;
        final fit = (size - firstAndFixed) / perWithGaps;
        var n = fitsWithin ? fit.floorToDouble() : fit.ceilToDouble();
        if (n.isNaN || n < 0) n = 0;
        repetitions = n >= 4294967295.0 ? 4294967295 : n.toInt() + 1;
      }
    }
    final remaining = math.max(_maxTracks - insertAt, 0);
    if (remaining == 0) {
      repetitions = 0;
    } else {
      repetitions = repetitions.clamp(1, (remaining + perCount - 1) ~/ perCount);
    }
    return (repetitions, math.min(fixedCount + perCount * repetitions, _maxTracks));
  }

  /// Taffy `initialize_grid_tracks`: the explicit tracks, the implicit ones
  /// round them, and a gutter between every two.
  static List<_Track> _initTracks(
    _Counts counts,
    List<_Component>? template,
    List<(_Fn, _Fn)> auto,
    int repeats,
    _Fn gap,
    bool Function(int) hasItems,
  ) {
    final tracks = <_Track>[_Track.gutter(gap)];
    void implicit(int count, (_Fn, _Fn) Function(int) at) {
      for (var i = 0; i < count; i++) {
        final d = at(i);
        tracks
          ..add(_Track.track(d.$1, d.$2))
          ..add(_Track.gutter(gap));
      }
    }

    if (counts.negative > 0) {
      final offset = auto.length - (counts.negative % auto.length);
      implicit(counts.negative, (i) => auto[(offset + i) % auto.length]);
    }
    var current = counts.negative;
    final limit = counts.negative + counts.explicit;
    if (counts.explicit > 0 && template != null) {
      for (final c in template) {
        if (c.single case final s?) {
          if (current < limit) {
            tracks
              ..add(_Track.track(s.$1, s.$2))
              ..add(_Track.gutter(gap));
            current += 1;
          }
          continue;
        }
        if (!c.auto) {
          final n = math.min(c.tracks.length * c.count, limit - current);
          for (var i = 0; i < n; i++) {
            final f = c.tracks[i % c.tracks.length];
            tracks
              ..add(_Track.track(f.$1, f.$2))
              ..add(_Track.gutter(gap));
            current += 1;
          }
          continue;
        }
        final n = math.min(c.tracks.length * repeats, limit - current);
        for (var i = 0; i < n; i++) {
          final f = c.tracks[i % c.tracks.length];
          final track = _Track.track(f.$1, f.$2);
          final gutter = _Track.gutter(gap);
          // Empty auto-fit tracks collapse, and the gutter after each.
          if (c.fits && !hasItems(current)) {
            track.collapse();
            gutter.collapse();
          }
          tracks
            ..add(track)
            ..add(gutter);
          current += 1;
        }
        if (c.fits && current == counts.len) {
          for (var i = tracks.length - 1; i >= 0; i--) {
            final t = tracks[i];
            if (!t.gutter && !t.collapsed) break;
            t.collapse();
          }
        }
      }
    }
    final rest = (counts.negative + counts.explicit) - current;
    implicit(counts.positive + rest, (i) => auto[i % auto.length]);
    tracks.first.collapse();
    tracks.last.collapse();
    return tracks;
  }

  // ------------------------------------------------------------ placement

  /// Taffy `compute_grid_size_estimate`: the implicit grid's size before
  /// placement, which placement may grow.
  static (_Counts, _Counts) _estimate(
    int explicitCols,
    int explicitRows,
    List<(RenderBox, TrackCellParentData, (_Place, _Place), (_Place, _Place))> written,
  ) {
    var colMin = 0, colMax = 0, colSpan = 0, rowMin = 0, rowMax = 0, rowSpan = 0;
    (int, int, int) bounds((_Place, _Place) p, int explicit) {
      final oz = (_toOz(p.$1, explicit), _toOz(p.$2, explicit));
      final s = oz.$1, e = oz.$2;
      int lo, hi;
      if (s is _Line && e is _Line) {
        lo = s.line == e.line ? s.line : math.min(s.line, e.line);
        hi = s.line == e.line ? s.line + 1 : math.max(s.line, e.line);
      } else if (s is _Line) {
        lo = s.line;
        hi = e is _SpanOf ? s.line + e.span : s.line + 1;
      } else if (e is _Line) {
        lo = s is _SpanOf ? e.line - s.span : e.line - 1;
        hi = e.line;
      } else {
        lo = 0;
        hi = 0;
      }
      final span = (s is! _Line && e is! _Line) ? _indefiniteSpan(oz) : 1;
      return (math.max(lo, -_maxTracks), math.min(hi, _maxTracks), span);
    }

    for (final w in written) {
      final (cl, ch, cs) = bounds(w.$3, explicitCols);
      final (rl, rh, rs) = bounds(w.$4, explicitRows);
      colMin = math.min(colMin, cl);
      colMax = math.max(colMax, ch);
      colSpan = math.max(colSpan, cs);
      rowMin = math.min(rowMin, rl);
      rowMax = math.max(rowMax, rh);
      rowSpan = math.max(rowSpan, rs);
    }
    final negCols = colMin < 0 ? -colMin : 0;
    var posCols = colMax > explicitCols ? colMax - explicitCols : 0;
    final negRows = rowMin < 0 ? -rowMin : 0;
    var posRows = rowMax > explicitRows ? rowMax - explicitRows : 0;
    if (negCols + explicitCols + posCols < colSpan) posCols = colSpan - explicitCols - negCols;
    if (negRows + explicitRows + posRows < rowSpan) posRows = rowSpan - explicitRows - negRows;
    return (_Counts(negCols, explicitCols, posCols), _Counts(negRows, explicitRows, posRows));
  }

  /// Taffy `place_grid_items` (css-grid-1 8.5): the items with both lines
  /// first, then those with a row (or column) of their own, then the rest
  /// in flow order.
  List<(RenderBox, TrackCellParentData, (int, int), (int, int), int)> _place(
    _Occupancy m,
    List<(RenderBox, TrackCellParentData, (_Place, _Place), (_Place, _Place))> written,
    int explicitCols,
    int explicitRows,
  ) {
    final flow = config.flow;
    final primaryH = flow == TrackFlow.row || flow == TrackFlow.rowDense;
    final dense = flow == TrackFlow.rowDense || flow == TrackFlow.columnDense;
    final out = <(RenderBox, TrackCellParentData, (int, int), (int, int), int)>[];
    final oz = [
      for (final w in written)
        (
          (_toOz(w.$3.$1, explicitCols), _toOz(w.$3.$2, explicitCols)),
          (_toOz(w.$4.$1, explicitRows), _toOz(w.$4.$2, explicitRows)),
        ),
    ];
    (_Place, _Place) along(int i, bool horizontal) => horizontal ? oz[i].$1 : oz[i].$2;

    void record(int i, (int, int) primary, (int, int) secondary, _Cell state) {
      (int, int) clampSpan((int, int) s) {
        final start = s.$1.clamp(-_maxTracks, _maxTracks - 1);
        return (start, s.$2.clamp(start + 1, _maxTracks));
      }

      final p = clampSpan(primary), s = clampSpan(secondary);
      m.mark(primaryH, p, s, state);
      out.add((written[i].$1, written[i].$2, primaryH ? p : s, primaryH ? s : p, i));
    }

    // 1. Both lines definite.
    for (var i = 0; i < written.length; i++) {
      if (!(_definite(along(i, true)) && _definite(along(i, false)))) continue;
      record(i, _definiteLines(along(i, primaryH)), _definiteLines(along(i, !primaryH)), _Cell.definite);
    }
    // 2. A definite secondary line only.
    for (var i = 0; i < written.length; i++) {
      if (!(_definite(along(i, !primaryH)) && !_definite(along(i, primaryH)))) continue;
      final secondary = _definiteLines(along(i, !primaryH));
      final startLine = m.counts(primaryH).startLine;
      var position = dense ? startLine : (m.lastOf(primaryH, secondary.$1, _Cell.auto) ?? startLine);
      final span = _indefiniteSpan(along(i, primaryH));
      while (true) {
        final primary = _spanAt(position, span);
        final jump = m.collisionJump(primaryH, primary, secondary);
        if (jump == null) {
          record(i, primary, secondary, _Cell.auto);
          break;
        }
        position = jump;
      }
    }
    // 4. The rest.
    final start = (m.counts(primaryH).startLine, m.counts(!primaryH).startLine);
    var cursor = start;
    for (var i = 0; i < written.length; i++) {
      if (_definite(along(i, !primaryH))) continue;
      final primaryStyle = along(i, primaryH), secondaryStyle = along(i, !primaryH);
      final secondarySpan = _indefiniteSpan(secondaryStyle);
      final primaryStart = m.counts(primaryH).startLine, primaryEnd = m.counts(primaryH).endLine;
      final secondaryStart = m.counts(!primaryH).startLine;
      var (p, s) = cursor;
      (int, int) primary, secondary;
      if (_definite(primaryStyle)) {
        primary = _definiteLines(primaryStyle);
        s = dense ? secondaryStart : (primary.$1 < p ? math.min(s + 1, _i16Max) : s);
        while (true) {
          final sec = _spanAt(s, secondarySpan);
          final jump = m.collisionJump(!primaryH, sec, primary);
          if (jump != null) {
            s = jump;
            continue;
          }
          secondary = sec;
          break;
        }
      } else {
        final primarySpan = _indefiniteSpan(primaryStyle);
        final spansAll = primarySpan >= m.counts(primaryH).len;
        while (true) {
          final pr = _spanAt(p, primarySpan);
          final sec = _spanAt(s, secondarySpan);
          if (pr.$2 > primaryEnd) {
            if (p == primaryStart) {
              primary = pr;
              secondary = sec;
              break;
            }
            s = math.min(s + 1, _i16Max);
            p = primaryStart;
            continue;
          }
          if (spansAll) {
            final jump = m.occupiedJump(!primaryH, sec);
            if (jump != null) {
              s = jump;
              p = primaryStart;
              continue;
            }
            primary = pr;
            secondary = sec;
            break;
          }
          final jump = m.collisionJump(primaryH, pr, sec);
          if (jump != null) {
            p = jump;
            continue;
          }
          primary = pr;
          secondary = sec;
          break;
        }
      }
      record(i, primary, secondary, _Cell.auto);
      // Sparse packing carries on after the item -- where it asked to go,
      // before the limited grid clamped it -- and dense starts over.
      cursor = dense ? start : (primary.$2, secondary.$1);
    }
    return out;
  }

  // --------------------------------------------------------- track sizing

  /// Taffy `track_sizing_algorithm` (css-grid-1 11.3) on one axis.
  void _sizeTracks(
    bool inline,
    double? axisMin,
    double? axisMax,
    TrackContent alignment,
    TrackContent otherAlignment,
    (_Space, _Space) availableGrid,
    _Pair inner,
    List<_Track> tracks,
    List<_Track> other,
    List<_Item> items,
    double? Function(_Track, double?) estimate,
  ) {
    final innerAxis = inner.get(inline);
    // 11.4 Initialise track sizes.
    final basis = innerAxis ?? axisMin;
    for (final t in tracks) {
      t.base = t.min.definiteValue(basis) ?? 0.0;
      t.limit = t.max.definiteValue(basis) ?? double.infinity;
      if (t.limit < t.base) t.limit = t.base;
    }
    // 11.5 step 1, the baseline shims: Taffy works them out as the columns
    // are sized, the fixed ones too.
    if (inline && items.any((i) => i.baselined)) _shimBaselines(items, inner);
    // Every track fixed: the sizes are final.
    if (tracks.every((t) => t.base == t.limit && t.min.definiteValue(basis) != null)) return;

    // The extra room content alignment will put in each gutter the item
    // spans in the OTHER axis, where both it and the tracks are definite.
    final adjust = _gutterAdjustment(otherAlignment, inner.get(!inline), estimate, other);
    if (other.length > 3) {
      for (var i = 2; i < other.length; i += 2) {
        other[i].alignAdjust = adjust;
      }
    }

    final space = inline ? availableGrid.$1 : availableGrid.$2;
    // 11.5 Resolve intrinsic track sizes.
    _intrinsicSizes(inline, tracks, other, items, space, inner, estimate);
    // 11.6 Maximise tracks.
    _maximise(tracks, innerAxis, space);
    // Only a size of the container's own is room to expand into: an offer
    // with no size of the box's own is a max-content one.
    final expansion = innerAxis != null
        ? _Space.definite(innerAxis)
        : (space.isMin ? _Space.minContent : _Space.maxContent);
    // 11.7 Expand flexible tracks.
    _expandFlexible(inline, tracks, other, items, axisMin, axisMax, expansion, inner, estimate);
    // 11.8 Stretch auto tracks.
    if (alignment == TrackContent.stretch) _stretchAuto(tracks, axisMin, expansion);
  }

  /// Taffy `resolve_item_baselines` (css-grid-1 11.5 step 1): in each row
  /// with more than one item that lines its baseline up, each of those is
  /// laid out at its min-content size, and shimmed down by as far as the
  /// row's lowest baseline is below its own. [items] end up in row order,
  /// as Taffy leaves them.
  void _shimBaselines(List<_Item> items, _Pair inner) {
    _stableSort(items, (a, b) => a.row.$1.compareTo(b.row.$1));
    var start = 0;
    while (start < items.length) {
      final row = items[start].row.$1;
      var end = start;
      while (end < items.length && items[end].row.$1 == row) {
        end++;
      }
      final inRow = items.sublist(start, end);
      start = end;
      if (inRow.where((i) => i.baselined).length <= 1) continue;
      for (final item in inRow) {
        if (!item.baselined) continue;
        final out = _leaf(item, const _Pair(null, null), inner, (
          _Space.minContent,
          _Space.minContent,
        ), _Measure.layout);
        final h = out.size.h;
        // A scroll container's baseline is held to its box (csswg-drafts
        // #7660).
        final b = item.clips ? _fmax(_fmin(out.baseline ?? h, h), 0.0) : (out.baseline ?? h);
        item.rowBaseline = b + (item.margin(inner.w).top ?? 0.0);
      }
      var lowest = double.negativeInfinity;
      for (final item in inRow) {
        if (item.baselined) lowest = _fmax(lowest, item.rowBaseline ?? 0.0);
      }
      for (final item in inRow) {
        if (item.baselined) item.shim = lowest - (item.rowBaseline ?? 0.0);
      }
    }
  }

  /// Taffy `compute_alignment_gutter_adjustment`.
  static double _gutterAdjustment(
    TrackContent alignment,
    double? size,
    double? Function(_Track, double?) estimate,
    List<_Track> tracks,
  ) {
    if (tracks.length <= 1) return 0.0;
    final outerWeight = switch (alignment) {
      TrackContent.stretch || TrackContent.spaceBetween => 0,
      _ => 1,
    };
    final innerWeight = switch (alignment) {
      TrackContent.spaceBetween || TrackContent.spaceEvenly => 1,
      TrackContent.spaceAround => 2,
      _ => 0,
    };
    if (innerWeight == 0) return 0.0;
    if (size == null) return 0.0;
    double? sum = 0.0;
    for (final t in tracks) {
      final e = estimate(t, size);
      if (e == null) {
        sum = null;
        break;
      }
      sum = sum! + e;
    }
    final free = sum == null ? 0.0 : _fmax(0.0, size - sum);
    final weighted = ((tracks.length - 3) ~/ 2) * innerWeight + 2 * outerWeight;
    return (free / weighted) * innerWeight;
  }

  _Pair _areaOf(
    _Item item,
    bool inline,
    List<_Track> tracks,
    List<_Track> other,
    _Pair inner,
    double? Function(_Track, double?) estimate,
  ) => item.areaCache ??= item.area(inline, tracks, other, inner, estimate);

  double _contribution(
    _Item item,
    bool inline,
    List<_Track> tracks,
    List<_Track> other,
    _Pair inner,
    double? Function(_Track, double?) estimate,
    int which,
  ) {
    final area = _areaOf(item, inline, tracks, other, inner, estimate);
    final available = inline ? _Pair(null, area.h) : _Pair(area.w, null);
    final v = switch (which) {
      0 => _minContent(item, inline, area, available),
      1 => _maxContent(item, inline, area, available),
      _ => _minimum(item, inline, tracks, area, inner),
    };
    return v + item.marginSum(inline, available.w);
  }

  /// AN ITEM THAT STATES ITS LEAST SIZE gives a grid sized under a
  /// min-content constraint that least, not its min-content: Chrome sizes
  /// an `auto` minimum by its items' MINIMUM contributions there too
  /// (css-grid-1 6.6, 11.5 step 2: the stated `min-width` where it is not
  /// `auto`), where Taffy takes the limited min-content contribution of
  /// every item that is not a scroll container. So a grid of links of
  /// `min-width: 0` has no least width from them, and a share of a grid it
  /// is an item of has no floor from it (its content-based minimum, 6.6, is
  /// that min-content). Chrome, measured: a docs site's mega menu at 240, link
  /// lists of `min-width: 0` in the menu's `repeat(3, 1fr)`, stood every
  /// share at 57.3, where these lists floored them at their words, 73.6,
  /// 83.5 and 59.2 (`fixtures/grid-share-nested-grid-least` p4).
  /// NEGATIVE: an item of `min-width: auto` gives its min-content (its
  /// content-based minimum), limited as before; one that clips, nothing
  /// (6.6), as before.
  bool _statesLeast(
    _Item item,
    bool inline,
    List<_Track> tracks,
    List<_Track> other,
    _Pair inner,
    double? Function(_Track, double?) estimate,
  ) {
    final area = _areaOf(item, inline, tracks, other, inner, estimate);
    return item.minSize(area).ratio(item.ratio).get(inline) != null;
  }

  /// Taffy `resolve_intrinsic_track_sizes` (css-grid-1 11.5).
  void _intrinsicSizes(
    bool inline,
    List<_Track> tracks,
    List<_Track> other,
    List<_Item> items,
    _Space space,
    _Pair inner,
    double? Function(_Track, double?) estimate,
  ) {
    // Ascending span, the items crossing a flexible track last.
    _stableSort(items, (a, b) {
      final fa = a.crossesFlex(inline), fb = b.crossesFlex(inline);
      if (!fa && fb) return -1;
      if (fa && !fb) return 1;
      final c = a.span(inline).compareTo(b.span(inline));
      return c != 0 ? c : a.placement(inline).$1.compareTo(b.placement(inline).$1);
    });
    final innerAxis = inner.get(inline);
    double minC(_Item i) => _contribution(i, inline, tracks, other, inner, estimate, 0);
    double maxC(_Item i) => _contribution(i, inline, tracks, other, inner, estimate, 1);
    double minimum(_Item i) => _contribution(i, inline, tracks, other, inner, estimate, 2);
    final contentSized = !space.isDefinite;

    var index = 0;
    var flexDone = false;
    while (!flexDone && index < items.length) {
      final first = items[index];
      final batchSpan = first.span(inline);
      final isFlex = first.crossesFlex(inline);
      int end;
      if (isFlex) {
        end = items.length;
      } else {
        end = items.length;
        for (var i = 0; i < items.length; i++) {
          if (items[i].crossesFlex(inline) || items[i].span(inline) > batchSpan) {
            end = i;
            break;
          }
        }
      }
      final batch = items.sublist(index, end);
      index = end;
      if (isFlex) flexDone = true;

      // Items of span one, not crossing a flexible track.
      if (!isFlex && batchSpan == 1) {
        for (final item in batch) {
          final track = tracks[item.indexes(inline).$1 + 1];
          final double newBase;
          switch (track.min.kind) {
            case _Kind.minContent:
              newBase = _fmax(track.base, minC(item));
            // An unresolved percentage is treated as min-content, as
            // Chrome does; calc() likewise.
            case _Kind.percent || _Kind.calc:
              newBase = innerAxis == null ? _fmax(track.base, minC(item)) : track.base;
            case _Kind.maxContent:
              newBase = _fmax(track.base, maxC(item));
            case _Kind.auto:
              final double s;
              // QUIRK (Taffy, after browsers): the limited min-content
              // contribution under a min-/max-content constraint, only for
              // items that are not scroll containers -- nor items that
              // state their least size ([_statesLeast]).
              if (contentSized && !item.clips && !_statesLeast(item, inline, tracks, other, inner, estimate)) {
                final floor = minimum(item);
                final mc = minC(item);
                final limit = track.max.definiteLimit(innerAxis);
                s = _fmax(limit == null ? mc : _fmin(mc, limit), floor);
              } else {
                s = minimum(item);
              }
              newBase = _fmax(track.base, s);
            case _Kind.length:
              newBase = track.base;
            case _Kind.fitPx || _Kind.fitPercent || _Kind.fr:
              throw StateError('not a minimum');
          }
          final limitMin = !item.clips ? minC(item) : null;
          final limitMax = maxC(item);
          final limitIntrinsicMin = minC(item);
          track.base = newBase;
          if (track.max.isFitContent) {
            if (limitMin != null) track.limitPlanned = _fmax(track.limitPlanned, limitMin);
            track.limitPlanned = _fmax(track.limitPlanned, _fmin(limitMax, track.fitLimit(innerAxis)));
          } else if (track.max.isMaxContentAlike || (track.max.usesPercentage && innerAxis == null)) {
            track.limitPlanned = _fmax(track.limitPlanned, limitMax);
          } else if (track.max.isIntrinsic) {
            track.limitPlanned = _fmax(track.limitPlanned, limitIntrinsicMin);
          }
        }
        for (final t in tracks) {
          if (t.limitPlanned > 0.0) {
            t.limit = t.limit == double.infinity ? t.limitPlanned : _fmax(t.limit, t.limitPlanned);
          }
          t.infinitelyGrowable = false;
          t.limitPlanned = 0.0;
          if (t.limit < t.base) t.limit = t.base;
        }
        continue;
      }

      // 1. Intrinsic minimums.
      for (final item in batch) {
        if (!item.crossesIntrinsic(inline)) continue;
        final double s;
        if (contentSized && !item.clips && !_statesLeast(item, inline, tracks, other, inner, estimate)) {
          final floor = minimum(item);
          final mc = minC(item);
          final limit = item.spannedLimit(inline, tracks, innerAxis);
          final limited = _fmax(limit == null ? mc : _fmin(mc, limit), floor);
          if (isFlex) {
            final spanned = item.spanned(inline, tracks);
            var inflexible = 0.0;
            for (final t in spanned) {
              if (!t.isFlexible) inflexible += t.base;
            }
            final scale = _fmin(_flexSum(spanned), 1.0);
            final excess = _fmax(limited - inflexible, 0.0);
            s = _fmax(floor, inflexible + excess * scale);
          } else {
            s = limited;
          }
        } else {
          s = minimum(item);
        }
        final spanned = item.spanned(inline, tracks);
        if (s > 0.0) {
          bool intrinsicMin(_Track t) => t.min.definiteValue(innerAxis) == null;
          _toBase(
            isFlex,
            s,
            spanned,
            intrinsicMin,
            item.clips ? (t) => t.fitLimitedGrowth(innerAxis) : (t) => t.limit,
            false,
            innerAxis,
          );
        }
      }
      _flushBase(tracks);

      // 2. Content-based minimums.
      bool minOrMaxMin(_Track t) => t.min.isMinOrMaxContent;
      for (final item in batch) {
        if (!item.spansMatching(inline, tracks, minOrMaxMin)) continue;
        final s = minC(item);
        final spanned = item.spanned(inline, tracks);
        if (s > 0.0) {
          _toBase(
            isFlex,
            s,
            spanned,
            minOrMaxMin,
            item.clips ? (t) => t.fitLimitedGrowth(innerAxis) : (t) => t.limit,
            false,
            innerAxis,
          );
        }
      }
      _flushBase(tracks);

      // 3. Max-content minimums, under a max-content constraint.
      if (space.isMax) {
        bool autoMin(_Track t) => t.min.isAuto && !t.max.isMinContent;
        // The same flooring the other way up: a max BELOW the min is
        // ignored and the track is its min alone (css-grid-1 7.2.1), and
        // `min-content` can never be more than `max-content` -- so
        // `minmax(max-content, min-content)` is min-content BOTH ways and
        // its min is not a max-content min (taffy's xgrid_span_2_max_-
        // content_minmax_max_content_min_content_indefinite: 60/20).
        bool maxContentMin(_Track t) => t.min.isMaxContent && !t.max.isMinContent;
        for (final item in batch) {
          if (!item.spansMatching(inline, tracks, (t) => autoMin(t) || maxContentMin(t))) continue;
          final limit = item.spannedLimit(inline, tracks, innerAxis);
          final mc = maxC(item);
          var s = limit == null ? mc : _fmin(mc, limit);
          if (isFlex) {
            final spanned = item.spanned(inline, tracks);
            var inflexible = 0.0;
            for (final t in spanned) {
              if (!t.isFlexible) inflexible += t.base;
            }
            final scale = _fmin(_flexSum(spanned), 1.0);
            s = inflexible + _fmax(s - inflexible, 0.0) * scale;
          }
          final spanned = item.spanned(inline, tracks);
          if (s > 0.0) {
            // Chrome and Firefox give max-content minimums first.
            if (spanned.any(maxContentMin)) {
              _toBase(isFlex, s, spanned, maxContentMin, (_) => double.infinity, true, innerAxis);
            } else {
              _toBase(isFlex, s, spanned, autoMin, (t) => t.fitLimitedGrowth(innerAxis), true, innerAxis);
            }
          }
        }
        _flushBase(tracks);
      }

      // Max-content minimums always grow to the max-content contribution.
      bool maxContentMin(_Track t) => t.min.isMaxContent && !t.max.isMinContent;
      for (final item in batch) {
        if (!item.spansMatching(inline, tracks, maxContentMin)) continue;
        final s = maxC(item);
        final spanned = item.spanned(inline, tracks);
        if (s > 0.0) _toBase(isFlex, s, spanned, maxContentMin, (t) => t.limit, true, innerAxis);
      }
      _flushBase(tracks);

      // 4. Growth limits under base sizes are raised to them.
      for (final t in tracks) {
        if (t.limit < t.base) t.limit = t.base;
      }

      if (!isFlex) {
        // 5. Intrinsic maximums.
        bool intrinsicMax(_Track t) => !t.max.hasDefiniteValue(innerAxis);
        for (final item in batch) {
          if (!item.spansMatching(inline, tracks, intrinsicMax)) continue;
          final s = minC(item);
          final spanned = item.spanned(inline, tracks);
          if (s > 0.0) _toLimit(s, spanned, intrinsicMax, innerAxis);
        }
        _flushLimit(tracks, true);

        // 6. Max-content maximums.
        bool maxContentMax(_Track t) => t.max.isMaxContentAlike || (t.max.usesPercentage && innerAxis == null);
        for (final item in batch) {
          if (!item.spansMatching(inline, tracks, maxContentMax)) continue;
          final s = maxC(item);
          final spanned = item.spanned(inline, tracks);
          if (s > 0.0) _toLimit(s, spanned, maxContentMax, innerAxis);
        }
        _flushLimit(tracks, false);
      }
    }

    // A track whose growth limit is still infinite takes its base size.
    for (final t in tracks) {
      if (t.limit == double.infinity) t.limit = t.base;
    }
  }

  static double _flexSum(List<_Track> tracks) {
    var s = 0.0;
    for (final t in tracks) {
      if (t.isFlexible) s += t.flexFactor;
    }
    return s;
  }

  static void _flushBase(List<_Track> tracks) {
    for (final t in tracks) {
      t.base += t.basePlanned;
      t.basePlanned = 0.0;
    }
  }

  static void _flushLimit(List<_Track> tracks, bool growable) {
    for (final t in tracks) {
      if (t.limitPlanned > 0.0) {
        t.limit = t.limit == double.infinity ? t.base + t.limitPlanned : t.limit + t.limitPlanned;
        t.infinitelyGrowable = growable;
      } else {
        t.infinitelyGrowable = false;
      }
      t.limitPlanned = 0.0;
    }
  }

  /// Taffy `distribute_item_space_to_base_size` (css-grid-1 11.5.1).
  static void _toBase(
    bool isFlex,
    double space,
    List<_Track> tracks,
    bool Function(_Track) affected,
    double Function(_Track) limit,
    bool maximum,
    double? innerAxis,
  ) {
    if (isFlex) {
      bool filter(_Track t) => t.isFlexible && affected(t);
      var sum = 0.0;
      for (final t in tracks) {
        if (filter(t)) sum += t.flexFactor;
      }
      _toBaseInner(space, tracks, filter, sum > 0.0 ? (t) => t.flexFactor : (_) => 1.0, limit, maximum, innerAxis);
    } else {
      _toBaseInner(space, tracks, affected, (_) => 1.0, limit, maximum, innerAxis);
    }
  }

  static void _toBaseInner(
    double space,
    List<_Track> tracks,
    bool Function(_Track) affected,
    double Function(_Track) share,
    double Function(_Track) limit,
    bool maximum,
    double? innerAxis,
  ) {
    if (space == 0.0 || !tracks.any(affected)) return;
    var sizes = 0.0;
    for (final t in tracks) {
      sizes += t.base;
    }
    var extra = _fmax(0.0, space - sizes);
    extra = _upToLimits(extra, tracks, affected, share, (t) => t.base, limit);
    if (extra > 0.000001) {
      bool Function(_Track) filter = maximum ? (t) => t.max.isMaxOrFitContent : (t) => t.max.isIntrinsic;
      if (!tracks.any((t) => affected(t) && filter(t))) filter = (_) => true;
      final f = filter;
      _upToLimits(extra, tracks, (t) => affected(t) && f(t), share, (t) => t.base, (t) => t.fitLimit(innerAxis));
    }
    for (final t in tracks) {
      if (t.incurred > t.basePlanned) t.basePlanned = t.incurred;
      t.incurred = 0.0;
    }
  }

  /// Taffy `distribute_item_space_to_growth_limit`.
  static void _toLimit(double space, List<_Track> tracks, bool Function(_Track) affected, double? innerAxis) {
    if (space == 0.0 || !tracks.any(affected)) return;
    var sizes = 0.0;
    for (final t in tracks) {
      sizes += t.limit == double.infinity ? t.base : t.limit;
    }
    final extra = _fmax(0.0, space - sizes);
    bool growable(_Track t) => t.infinitelyGrowable || t.fitLimitedGrowth(innerAxis) == double.infinity;
    final count = tracks.where((t) => affected(t) && growable(t)).length;
    if (count > 0) {
      final each = extra / count;
      for (final t in tracks) {
        if (affected(t) && growable(t)) t.incurred = each;
      }
    } else {
      _upToLimits(
        extra,
        tracks,
        affected,
        (_) => 1.0,
        (t) => t.limit == double.infinity ? t.base : t.limit,
        (t) => t.fitLimit(innerAxis),
      );
    }
    for (final t in tracks) {
      if (t.incurred > t.limitPlanned) t.limitPlanned = t.incurred;
      t.incurred = 0.0;
    }
  }

  /// Taffy `distribute_space_up_to_limits`: in proportion, each track frozen
  /// at its limit. What is left over.
  static double _upToLimits(
    double space,
    List<_Track> tracks,
    bool Function(_Track) affected,
    double Function(_Track) share,
    double Function(_Track) property,
    double Function(_Track) limit,
  ) {
    const threshold = 0.01;
    bool growable(_Track t) => property(t) + t.incurred < limit(t);
    for (var iter = 0; iter < tracks.length + 1; iter++) {
      if (space <= threshold) break;
      var sum = 0.0;
      for (final t in tracks) {
        if (growable(t) && affected(t)) sum += share(t);
      }
      if (sum == 0.0) break;
      double? least;
      for (final t in tracks) {
        if (!(growable(t) && affected(t))) continue;
        final v = (limit(t) - property(t) - t.incurred) / share(t);
        least = least == null ? v : _fmin(least, v);
      }
      final step = _fmin(least!, space / sum);
      for (final t in tracks) {
        if (!affected(t)) continue;
        final increase = step * share(t);
        if (increase > 0.0 && property(t) + t.incurred + increase <= limit(t) + threshold) {
          t.incurred += increase;
          space -= increase;
        }
      }
    }
    return space;
  }

  /// Taffy `maximise_tracks` (css-grid-1 11.6).
  static void _maximise(List<_Track> tracks, double? innerAxis, _Space space) {
    final free = space.freeSpace(_sum(tracks));
    if (free == double.infinity) {
      for (final t in tracks) {
        t.base = t.limit;
      }
    } else if (free > 0.0) {
      _upToLimits(free, tracks, (_) => true, (_) => 1.0, (t) => t.base, (t) => t.fitLimitedGrowth(innerAxis));
      for (final t in tracks) {
        t.base += t.incurred;
        t.incurred = 0.0;
      }
    }
  }

  /// Taffy `expand_flexible_tracks` (css-grid-1 11.7).
  void _expandFlexible(
    bool inline,
    List<_Track> tracks,
    List<_Track> other,
    List<_Item> items,
    double? axisMin,
    double? axisMax,
    _Space space,
    _Pair inner,
    double? Function(_Track, double?) estimate,
  ) {
    final double fraction;
    if (space.isDefinite) {
      final free = space.value - _sum(tracks);
      fraction = free <= 0.0 ? 0.0 : _frSize(tracks, space.value);
    } else if (space.isMin) {
      fraction = 0.0;
    } else {
      var trackMax = 0.0;
      var any = false;
      for (final t in tracks) {
        if (!t.max.isFr) continue;
        final f = t.flexFactor;
        final v = f > 1.0 ? t.base / f : t.base;
        trackMax = any ? _fmax(trackMax, v) : v;
        any = true;
      }
      var itemMax = 0.0;
      var anyItem = false;
      for (final item in items) {
        if (!item.crossesFlex(inline)) continue;
        final mc = _contribution(item, inline, tracks, other, inner, estimate, 1);
        final v = _frSize(item.spanned(inline, tracks), mc);
        itemMax = anyItem ? _fmax(itemMax, v) : v;
        anyItem = true;
      }
      final ff = _fmax(any ? trackMax : 0.0, anyItem ? itemMax : 0.0);
      var hypothetical = 0.0;
      for (final t in tracks) {
        hypothetical += t.max.isFr ? _fmax(t.base, t.max.value * ff) : t.base;
      }
      final minSize = axisMin ?? 0.0;
      final maxSize = axisMax ?? double.infinity;
      if (hypothetical < minSize) {
        fraction = _frSize(tracks, minSize);
      } else if (hypothetical > maxSize) {
        fraction = _frSize(tracks, maxSize);
      } else {
        fraction = ff;
      }
    }
    for (final t in tracks) {
      if (!t.max.isFr) continue;
      t.base = _fmax(t.base, t.max.value * fraction);
    }
  }

  /// Taffy `find_size_of_fr` (css-grid-1 11.7.1).
  static double _frSize(List<_Track> tracks, double fill) {
    if (fill == 0.0) return 0.0;
    var size = double.infinity;
    for (var iter = 0; iter < tracks.length + 1; iter++) {
      var used = 0.0;
      var factors = 0.0;
      for (final t in tracks) {
        if (t.max.isFr && t.max.value * size >= t.base) {
          factors += t.max.value;
        } else {
          used += t.base;
        }
      }
      final previous = size;
      size = (fill - used) / _fmax(factors, 1.0);
      final valid = tracks.every((t) {
        if (!t.max.isFr) return true;
        final f = t.max.value;
        return f * size >= t.base || f * previous < t.base;
      });
      if (valid) break;
    }
    return size;
  }

  /// Taffy `stretch_auto_tracks` (css-grid-1 11.8).
  static void _stretchAuto(List<_Track> tracks, double? axisMin, _Space space) {
    final n = tracks.where((t) => t.max.isAuto).length;
    if (n == 0) return;
    final used = _sum(tracks);
    final free = space.isDefinite ? space.freeSpace(used) : (axisMin == null ? 0.0 : axisMin - used);
    if (free <= 0.0) return;
    final each = free / n;
    for (final t in tracks) {
      if (t.max.isAuto) t.base += each;
    }
  }

  // ------------------------------------------------------------- alignment

  /// Taffy `align_tracks` (css-align-3 5): where the tracks sit in the box.
  /// [reversed] walks them from the right, the columns of a right-to-left
  /// grid, with the alignment's start at that end.
  static void _alignTracks(double size, List<_Track> tracks, TrackContent alignment, {bool reversed = false}) {
    final free = size - _sum(tracks);
    var count = 0;
    for (var i = 1; i < tracks.length; i += 2) {
      if (!tracks[i].collapsed) count++;
    }
    var mode = _fallback(free, count, alignment);
    if (reversed) mode = _reverse(mode);
    var at = count == 0 ? _offset(free, count, mode, true) : 0.0;
    var seen = false;
    // A gutter is at an even place whichever way the tracks are walked:
    // there is one more of them than there are tracks.
    for (var i = 0; i < tracks.length; i++) {
      final t = tracks[reversed ? tracks.length - 1 - i : i];
      final real = i.isOdd && !t.collapsed;
      final offset = real ? _offset(free, count, mode, !seen) : 0.0;
      t.offset = at + offset;
      at = at + offset + t.base;
      if (real) seen = true;
    }
  }

  /// css-align-3 5.3 and 6.1: distribution falls back with one track or no
  /// room, and `safe` falls back to the start with no room.
  static _Mode _fallback(double free, int count, TrackContent a) {
    var mode = switch (a) {
      TrackContent.start => _Mode.flexStart,
      TrackContent.end || TrackContent.safeEnd => _Mode.flexEnd,
      TrackContent.center || TrackContent.safeCenter => _Mode.center,
      TrackContent.stretch => _Mode.stretch,
      TrackContent.spaceBetween => _Mode.spaceBetween,
      TrackContent.spaceAround => _Mode.spaceAround,
      TrackContent.spaceEvenly => _Mode.spaceEvenly,
    };
    var safe = a == TrackContent.safeCenter || a == TrackContent.safeEnd;
    if (count <= 1 || free <= 0) {
      switch (mode) {
        case _Mode.stretch || _Mode.spaceBetween:
          mode = _Mode.flexStart;
          safe = true;
        case _Mode.spaceAround || _Mode.spaceEvenly:
          mode = _Mode.center;
          safe = true;
        default:
          break;
      }
    }
    if (free <= 0 && safe) mode = _Mode.start;
    return mode;
  }

  /// The same alignment from the other end (Taffy `AlignContent::reversed`),
  /// `stretch` included: what the `auto` tracks have not already taken sits
  /// after the tracks, which walked from the right is before them.
  static _Mode _reverse(_Mode mode) => switch (mode) {
    _Mode.start || _Mode.flexStart || _Mode.stretch => _Mode.flexEnd,
    _Mode.flexEnd => _Mode.flexStart,
    _ => mode,
  };

  static double _offset(double free, int count, _Mode mode, bool first) {
    if (first) {
      return switch (mode) {
        _Mode.start || _Mode.flexStart || _Mode.stretch || _Mode.spaceBetween => 0.0,
        _Mode.flexEnd => free,
        _Mode.center => free / 2,
        _Mode.spaceAround => free >= 0 ? (free / count) / 2 : free / 2,
        _Mode.spaceEvenly => free >= 0 ? free / (count + 1) : free / 2,
      };
    }
    final fs = _fmax(free, 0);
    return 0.0 +
        switch (mode) {
          _Mode.spaceBetween => fs / (count - 1),
          _Mode.spaceAround => fs / count,
          _Mode.spaceEvenly => fs / (count + 1),
          _ => 0.0,
        };
  }

  /// Taffy `align_and_position_item`: the item's size in its area, and
  /// where it sits there.
  void _position(_Item item, double left, double right, double top, double bottom) {
    final area = _Pair(right - left, bottom - top);
    if (item.child.parent case final RenderTracks host when item.data.room) host._offerRoom(item.child, area.w!);
    final ratio = item.ratio;
    final inherent = item.size(area).ratio(ratio);
    final min = item.minSize(area).or(const _Pair(0, 0)).floor(const _Pair(0, 0));
    final max = item.maxSize(area).ratio(ratio);
    // Every margin is a share of the area's WIDTH where it states one.
    final margin = item.margin(area.w);
    final room = _Pair(
      _fmax(area.w! - (margin.left ?? 0) - (margin.right ?? 0), 0.0),
      _fmax(area.h! - (margin.top ?? 0) - (margin.bottom ?? 0) - item.shim, 0.0),
    );
    // A RATIO STRETCHED BOTH WAYS COVERS ITS AREA: its automatic minimum
    // on each axis is the other axis's stretch through the ratio (css-grid-1
    // 6.6), and only a floor the page wrote on that axis takes its place.
    final stretched = _Item._stretches(item.justifySelf) && _Item._stretches(item.alignSelf);
    final covers =
        ratio != null &&
        inherent.w == null &&
        inherent.h == null &&
        stretched &&
        margin.left != null &&
        margin.right != null &&
        margin.top != null &&
        margin.bottom != null;
    final floors = item.minSize(area);
    final coverWidth = covers && floors.w == null ? room.h! * ratio : null;
    final coverHeight = covers && floors.h == null ? room.w! / ratio : null;
    var width = inherent.w;
    if (width == null && margin.left != null && margin.right != null && _Item._stretches(item.justifySelf)) {
      width = room.w;
    }
    if (coverWidth != null && width != null && width < coverWidth) width = coverWidth;
    final across = _Pair(width, inherent.h).ratio(ratio);
    width = across.w;
    var height = across.h;
    if (height == null && margin.top != null && margin.bottom != null && _Item._stretches(item.alignSelf)) {
      height = room.h;
    }
    if (coverHeight != null && height != null && height < coverHeight) {
      height = coverHeight;
      width = null;
    }
    final wh = _Pair(width, height).ratio(ratio).clamp(min, max);
    final out = _leaf(item, wh, area, (_Space.definite(room.w!), _Space.definite(room.h!)), _Measure.layout);
    final fw = _clamp(wh.w ?? out.size.w, min.w, max.w);
    final fh = _clamp(wh.h ?? out.size.h, min.h, max.h);
    item.x = _within(left, right, item.justifySelf, fw, margin.left, margin.right, rtl);
    item.outY = _within(top, bottom, item.alignSelf, fh, margin.top, margin.bottom, false, item.shim);
    item.outW = fw;
    item.outH = fh;
    final b = out.baseline;
    item.baseline = b == null ? null : (item.clips ? _fmax(_fmin(b, fh), 0.0) : b);
  }

  /// Taffy `align_item_within_area` on one axis, for an item in the flow:
  /// [rtl] on the inline axis of a right-to-left grid, whose `start` is the
  /// right-hand end of the area, and [shim] the room a baseline puts above
  /// the item's margin down the block axis.
  static double _within(
    double start,
    double end,
    CellAlign align,
    double size,
    double? before,
    double? after, [
    bool rtl = false,
    double shim = 0.0,
  ]) {
    final fixedBefore = (before ?? 0.0) + shim, fixedAfter = after ?? 0.0;
    final areaSize = _fmax(end - start, 0.0);
    final free = _fmax(areaSize - size - (fixedBefore + fixedAfter), 0.0);
    final autos = (before == null ? 1 : 0) + (after == null ? 1 : 0);
    final autoSize = autos > 0 ? free / autos : 0.0;
    final mStart = (before ?? autoSize) + shim, mEnd = after ?? autoSize;
    final overflows = size + (fixedBefore + fixedAfter) > areaSize;
    final safe = align == CellAlign.safeCenter || align == CellAlign.safeEnd;
    final keyword = safe && overflows ? CellAlign.start : align;
    final double offset = switch (keyword) {
      CellAlign.start || CellAlign.stretch || CellAlign.baseline => rtl ? areaSize - size - mEnd : mStart,
      CellAlign.end || CellAlign.safeEnd => rtl ? mStart : areaSize - size - mEnd,
      CellAlign.center || CellAlign.safeCenter => (areaSize - size + mStart - mEnd) / 2.0,
    };
    return start + offset;
  }

  /// Taffy `align_and_position_item` for a box OUT OF THE FLOW: its sizes
  /// shares of its area, a width both horizontal insets leave where it
  /// states none (and a height both vertical ones do), measured where
  /// neither says, and never stretched. The shares are of the area as its
  /// lines leave it, which a line past the far one leaves less than nothing
  /// (Taffy's `grid_area_size`); the room inside the margins is never less.
  void _positionOut(_Item item, double left, double right, double top, double bottom) {
    final d = item.data;
    final area = _Pair(right - left, bottom - top);
    if (item.child.parent case final RenderTracks host when d.room) host._offerRoom(item.child, area.w!);
    final ratio = item.ratio;
    final inherent = item.size(area).ratio(ratio);
    final min = item.minSize(area).or(const _Pair(0, 0)).floor(const _Pair(0, 0));
    final max = item.maxSize(area).ratio(ratio);
    // An inset is a share of the area where it states one, else a length.
    double? inset(double? px, double? share, double basis) => share != null ? share * basis : px;
    final l = inset(d.left, d.leftFraction, area.w!), r = inset(d.right, d.rightFraction, area.w!);
    final t = inset(d.top, d.topFraction, area.h!), b = inset(d.bottom, d.bottomFraction, area.h!);
    final margin = item.margin(area.w);
    final room = _Pair(
      _fmax(area.w! - (margin.left ?? 0) - (margin.right ?? 0), 0.0),
      _fmax(area.h! - (margin.top ?? 0) - (margin.bottom ?? 0), 0.0),
    );
    var width = inherent.w;
    if (width == null && l != null && r != null) width = _fmax(room.w! - l - r, 0.0);
    final across = _Pair(width, inherent.h).ratio(ratio);
    width = across.w;
    var height = across.h;
    if (height == null && t != null && b != null) height = _fmax(room.h! - t - b, 0.0);
    final wh = _Pair(width, height).ratio(ratio).clamp(min, max);
    final available = (_Space.definite(room.w!), _Space.definite(room.h!));
    // A box of no settled size is measured both ways first, and laid out
    // at what that comes to.
    var settled = wh;
    if (wh.w == null || wh.h == null) {
      final m = _leaf(item, wh, area, available, _Measure.vertical).size;
      settled = _Pair(m.w, m.h);
    }
    final out = _leaf(item, settled, area, available, _Measure.layout);
    final fw = _clamp(settled.w ?? out.size.w, min.w, max.w);
    final fh = _clamp(settled.h ?? out.size.h, min.h, max.h);
    item.x = _outOf(left, right, item.justifySelf, fw, margin.left, margin.right, l, r, rtl);
    item.outY = _outOf(top, bottom, item.alignSelf, fh, margin.top, margin.bottom, t, b);
    item.outW = fw;
    item.outH = fh;
  }

  /// Taffy `align_item_within_area` on one axis, for a box out of the flow:
  /// at its start inset where it has one, else at its end inset, else
  /// where its alignment puts it. Nothing it overflows makes it safe.
  /// [rtl], on the inline axis of a right-to-left grid, stands a box with
  /// both insets at its right one and turns its alignment round.
  static double _outOf(
    double start,
    double end,
    CellAlign align,
    double size,
    double? before,
    double? after,
    double? insetStart,
    double? insetEnd, [
    bool rtl = false,
  ]) {
    final areaSize = _fmax(end - start, 0.0);
    final fixedBefore = before ?? 0.0, fixedAfter = after ?? 0.0;
    // The offset within the area first, then the area's start: the engine's
    // order, so that the two land on the same double.
    if (insetStart != null && !(rtl && insetEnd != null)) return start + (insetStart + fixedBefore);
    if (insetEnd != null) return start + (areaSize - insetEnd - size - fixedAfter);
    final free = _fmax(areaSize - size - (fixedBefore + fixedAfter), 0.0);
    final autos = (before == null ? 1 : 0) + (after == null ? 1 : 0);
    final autoSize = autos > 0 ? free / autos : 0.0;
    final mStart = before ?? autoSize, mEnd = after ?? autoSize;
    final double offset = switch (align) {
      CellAlign.start || CellAlign.stretch || CellAlign.baseline => rtl ? areaSize - size - mEnd : mStart,
      CellAlign.end || CellAlign.safeEnd => rtl ? mStart : areaSize - size - mEnd,
      CellAlign.center || CellAlign.safeCenter => (areaSize - size + mStart - mEnd) / 2.0,
    };
    return start + offset;
  }
}

enum _Mode { start, flexStart, flexEnd, center, stretch, spaceBetween, spaceAround, spaceEvenly }

/// A stable sort: Dart's `List.sort` is not one, and Taffy's is.
void _stableSort<T>(List<T> list, int Function(T, T) compare) {
  final indexed = List.generate(list.length, (i) => (i, list[i]));
  indexed.sort((a, b) {
    final c = compare(a.$2, b.$2);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  for (var i = 0; i < list.length; i++) {
    list[i] = indexed[i].$2;
  }
}
