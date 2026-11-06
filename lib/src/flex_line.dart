/// One line of flex items, laid out by the two rules `Row` and `Column`
/// cannot express.
library;

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';
import 'edges.dart';
import 'flex_balance.dart';
import 'paint_order.dart';

/// A [Row] or [Column] that lays its children out the way CSS lays out a
/// flex line (css-flexbox-1 §9), and nothing else: no wrapping, no grid, no
/// layout engine behind it -- a [RenderBox] over [RenderBox] children.
///
/// Two of the rules it follows have no equivalent in Flutter's own flex:
///
///  * **Everyone gives up room, in proportion to how much they asked for**
///    (§9.7). When the items do not fit, each gives up `shrink × its base
///    size` of the overflow, and its base size is what the child measures
///    at -- which nothing outside the child knows before layout, so no
///    `Flexible(flex: …)` written in the source can say it.
///  * **An item stops shrinking at its own content** (§4.5). Its automatic
///    minimum along the line is its min-content size: its longest word, its
///    widest cell. A `Flexible` has no floor and crushes the word. An item
///    that wants none says so with `min: 0` or [FlexCell.clips].
///
/// Everything else is the ordinary flex line: `flex-grow`, a flex basis, an
/// item's own main and cross size, min and max along both axes, margins
/// (auto ones included), a gap, `justify-content` and `align-items` --
/// [MainAxisAlignment] and [CrossAxisAlignment] say those two, since they
/// are the same six and five keywords.
///
/// The line asks its children what it needs through Flutter's own
/// protocol: a max-content size is [RenderBox.getMaxIntrinsicWidth], a
/// min-content size is [RenderBox.getMinIntrinsicWidth], the size a child
/// takes in the room there is, or at a length it is held to, is a dry
/// layout.
///
/// A child that takes part on CSS's own terms -- it shrinks, it never
/// grows, it starts from its own content -- needs no wrapper at all. A
/// [FlexCell] says the rest.
class FlexLine extends MultiChildRenderObjectWidget {
  const FlexLine({
    super.key,
    this.direction = Axis.horizontal,
    this.reverse = false,
    this.maxExtent,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.spacing = 0,
    this.spacingFraction,
    this.wrap = false,
    this.runSpacing = 0,
    this.runSpacingFraction,
    this.alignContent,
    this.reverseLines = false,
    this.balance = false,
    this.lineCount = 1,
    this.textDirection = TextDirection.ltr,
    this.safeMainAxis = false,
    this.safeCrossAxis = false,
    this.textBaseline = TextBaseline.alphabetic,
    super.children,
  });

  /// Which way the line runs. The cross axis is the other one.
  final Axis direction;

  /// `row-reverse` and `column-reverse`: whether the items run from the
  /// far end of [direction] back to its near one. The first child is then
  /// the rightmost of a row, the bottom one of a column, and the main
  /// START of the line is the edge they begin at -- so a reversed row
  /// under [MainAxisAlignment.start] packs against its right edge.
  ///
  /// Only the ORDER along the line turns round. Each item keeps its own
  /// margins on the sides they are written on, and the children paint in
  /// the order they are written, because CSS paints flex items in document
  /// order whichever way the line runs (css-flexbox-1 5.4).
  final bool reverse;

  /// `justify-content`: what happens to the room left along the line. Where
  /// there is none to give -- the items overflow -- CSS still centres or
  /// ends them, so the line hangs out of both edges, which is what
  /// [MainAxisAlignment.center] does here and not what a [Row] does.
  final MainAxisAlignment mainAxisAlignment;

  /// `align-items`: where the items sit across the line.
  /// [CrossAxisAlignment.stretch] is CSS's default and makes every item as
  /// deep as the line.
  final CrossAxisAlignment crossAxisAlignment;

  /// `max-width` down a row, `max-height` down a column: the longest the
  /// box may be ALONG the line, whatever room it is offered. It is a
  /// ceiling on the box, so it is a ceiling on the room the items are laid
  /// out in: they shrink into it as they would into a slot that size, and
  /// a wrapping line whose length is left to its content breaks against
  /// it. A floor the box is held to still wins over it, as CSS's does
  /// (css-sizing-3 5.1).
  final double? maxExtent;

  /// `gap`: the room between one item and the next.
  final double spacing;

  /// [spacing] and [runSpacing] as a SHARE of the line's own content box
  /// along the same axis: a percentage `column-gap` is of the box's width,
  /// a `row-gap` of its height (css-align-3 8.3). The box has that length
  /// where it was handed it -- a tight constraint on that axis -- and
  /// nowhere else: a gap that is a share of a length the box is still
  /// working out is cyclic, and resolves against zero. Added to the pixels
  /// beside it, so `calc(5% + 4px)` is a share of `0.05` and 4.
  final double? spacingFraction, runSpacingFraction;

  /// `flex-wrap`: whether the items that do not fit start another line
  /// instead of shrinking past their floors (css-flexbox-1 9.3 step 5).
  /// Every line then flexes on its own, and the box is as deep as all of
  /// them together.
  final bool wrap;

  /// `align-content`: where the LINES sit across a box that wraps, and
  /// nothing at all where it does not -- a box of one line has no room
  /// left between its lines to give away (css-flexbox-1 8.4). `null` is
  /// CSS's `normal`, which on a flex box is `stretch`: every line grows by
  /// an equal share of the room left over. Anything else packs the lines
  /// at the size they came to.
  final WrapAlignment? alignContent;

  /// `row-gap` where the line is a row, `column-gap` where it is a column:
  /// the room between one line and the next. It is no room at all where
  /// there is only one line.
  final double runSpacing;

  /// `flex-wrap: wrap-reverse`: the lines of a box that [wrap]s stack from
  /// the FAR side of the cross axis -- up from the bottom of a row, in from
  /// the right of a column -- and what `flex-start` names across a line
  /// turns round with them (css-flexbox-1 5.2). An item aligned to `start`
  /// sits at the bottom of its row, `stretch` is `start` wherever it cannot
  /// fill, items on one baseline are packed down against the line's bottom
  /// edge, and [alignContent]'s `start` packs the lines at the bottom of
  /// the box. The items still break into lines in the order they are
  /// written and each line runs the way it did; the box's first baseline
  /// comes from the line that is first on the page, the LAST one written
  /// (css-flexbox-1 8.5). A line that does not wrap has one line and
  /// nothing to stack.
  final bool reverseLines;

  /// `flex-wrap: balance` (css-flexbox-2 5.2): the lines of a box that
  /// [wrap]s come out as alike in length as they can be. The box makes as
  /// many lines as plain wrapping would -- [lineCount] where that is more,
  /// and never more than one per item -- and divides its items among them
  /// in the order they are written so that the sum of the lines' squared
  /// lengths is least, ties going to the most items on the earliest lines.
  /// No line of two or more items is longer than the box, and an item of
  /// no length stays at the end of the line before it. The box's own
  /// max-content length is then its longest line, the items balanced
  /// across [lineCount] lines with no length to stop them, and a column
  /// whose height nobody stated is as tall as its tallest line.
  final bool balance;

  /// `flex-line-count` (css-flexbox-2 6.1): the fewest lines a [balance]d
  /// box divides its items into, and how many lines share the room ACROSS
  /// it. Every item is measured in one line's share: the room less the
  /// [runSpacing] between the lines, divided by the count, so a sentence in
  /// a column of two lines wraps at half the column's width. Where the gaps
  /// leave no room to share, the room is not divided at all. A length the
  /// item states across the line is still the length it is measured at,
  /// and a share of the box's depth ([FlexCell.crossSizeFraction]) is of
  /// the whole of it: "Percentages continue to resolve as normal." A box
  /// that does not balance takes the count as nothing at all -- it neither
  /// adds lines nor shares the room, which is what Chrome draws for a plain
  /// `wrap` (`fixtures/flex-line-count-wrap`) -- and a box that does not
  /// wrap has one line.
  final int lineCount;

  /// `direction`: which way the INLINE axis runs -- a row's main axis, a
  /// column's cross axis (css-flexbox-1 5.1). Right to left, a row runs
  /// from its right edge, as [reverse] makes it, and the two compose: a
  /// reversed right-to-left row runs left to right. A column puts what is
  /// aligned to `start` at its right edge, and a column that wraps stacks
  /// its lines in from the right. Every margin stays on the side it is
  /// written on. Unlike a [Row], and like the flex box it stands for, the
  /// line does not read the [Directionality] round it: it runs left to
  /// right unless it is told.
  final TextDirection textDirection;

  /// `safe` in front of `justify-content` (css-align-3 4.4): the
  /// [mainAxisAlignment] holds while the items fit the line, and where they
  /// overflow it they are packed at the START of the axis instead -- the
  /// left of a row, the right of a right-to-left one, the top of a column,
  /// reversed or not -- so nothing is pushed out of reach past that edge.
  final bool safeMainAxis;

  /// `safe` in front of `align-items`: an item deeper than its line sits at
  /// the start of the cross axis -- the top of a row, the left of a column,
  /// its right under `rtl` -- instead of where [crossAxisAlignment] puts
  /// it. An item with an `align-self` of its own ([FlexCell.align]) says
  /// for itself ([FlexCell.safe]).
  final bool safeCrossAxis;

  /// Which baseline [CrossAxisAlignment.baseline] lines the items up on.
  final TextBaseline textBaseline;

  @override
  RenderFlexLine createRenderObject(BuildContext context) => RenderFlexLine(
    direction: direction,
    reverse: reverse,
    maxExtent: maxExtent,
    mainAxisAlignment: mainAxisAlignment,
    crossAxisAlignment: crossAxisAlignment,
    spacing: spacing,
    spacingFraction: spacingFraction,
    wrap: wrap,
    runSpacing: runSpacing,
    runSpacingFraction: runSpacingFraction,
    alignContent: alignContent,
    reverseLines: reverseLines,
    balance: balance,
    lineCount: lineCount,
    textDirection: textDirection,
    safeMainAxis: safeMainAxis,
    safeCrossAxis: safeCrossAxis,
    textBaseline: textBaseline,
  );

  @override
  void updateRenderObject(BuildContext context, RenderFlexLine renderObject) {
    renderObject
      ..direction = direction
      ..reverse = reverse
      ..maxExtent = maxExtent
      ..mainAxisAlignment = mainAxisAlignment
      ..crossAxisAlignment = crossAxisAlignment
      ..spacing = spacing
      ..spacingFraction = spacingFraction
      ..wrap = wrap
      ..runSpacing = runSpacing
      ..runSpacingFraction = runSpacingFraction
      ..alignContent = alignContent
      ..reverseLines = reverseLines
      ..balance = balance
      ..lineCount = lineCount
      ..textDirection = textDirection
      ..safeMainAxis = safeMainAxis
      ..safeCrossAxis = safeCrossAxis
      ..textBaseline = textBaseline;
  }
}

/// A size a flex item states as a KEYWORD rather than a length, which only
/// the item's own content answers (css-sizing-3 5.1, css-flexbox-1 7.2.3).
enum FlexKeyword {
  /// `flex-basis: content`: what the item holds, with any length it states
  /// along the line left out of the question.
  content,

  /// `min-content`: as short along the line as its content can be drawn --
  /// its longest word, its widest box.
  minContent,

  /// `max-content`: as long as its content would like to be.
  maxContent,

  /// `fit-content`: its content in the room the line has -- the room where
  /// the content is longer, never under its min-content.
  fitContent,

  /// `stretch`: the whole of the line's length, less the item's margins.
  stretch,
}

/// What one child of a [FlexLine] asks for. Everything here is a CSS
/// property under its CSS default, so a cell that says nothing is the same
/// child unwrapped.
class FlexCell extends ParentDataWidget<FlexLineParentData> {
  const FlexCell({
    super.key,
    this.grow = 0,
    this.shrink = 1,
    this.basis,
    this.basisFraction,
    this.basisCap,
    this.basisCapFraction,
    this.basisFloor,
    this.basisFloorFraction,
    this.mainSize,
    this.mainSizeFraction,
    this.crossSize,
    this.crossSizeFraction,
    this.min,
    this.minFraction,
    this.minCap,
    this.minCapFraction,
    this.max,
    this.maxFraction,
    this.crossMin,
    this.crossMinFraction,
    this.crossMax,
    this.crossMaxFraction,
    this.margin = EdgeInsets.zero,
    this.autoMargin = AutoEdges.none,
    this.frame = EdgeInsets.zero,
    this.frameFraction = EdgeInsets.zero,
    this.marginFraction = EdgeInsets.zero,
    this.basisKeyword,
    this.minKeyword,
    this.maxKeyword,
    this.align,
    this.safe = false,
    this.clips = false,
    this.compressible = false,
    this.z = 0,
    this.ratio,
    this.shiftLeftFraction,
    this.shiftTopFraction,
    required super.child,
  });

  /// `flex-grow`: the share of the room left over this child takes.
  final double grow;

  /// `flex-shrink`: the weight of this child when there is not enough room.
  /// The room it gives up is `shrink × its base size`, normalised over the
  /// line -- so with the default of 1 everywhere a child twice as wide
  /// gives up twice as much.
  final double shrink;

  /// `flex-basis`: the size shrinking starts from, in pixels, or as a share
  /// of the line's own length ([basisFraction]). Neither says anything and
  /// the child's own content is the basis.
  ///
  /// EVERY LENGTH HERE IS A PAIR: pixels, a share of the line (`50%` is
  /// 0.5), or both, which is `calc(share + pixels)`. A share of a length
  /// the line does not have is no length at all -- the child's content
  /// stands in for it, or, as a bound, there is none -- except along a
  /// row whose length its content settled: that length is known once the
  /// line has it, and the shares are read against it then
  /// (css-sizing-3 5.2.1).
  final double? basis, basisFraction;

  /// A CEILING AND A FLOOR ON [basis], each a pair of pixels and a share of
  /// the line as [basis] is: `flex-basis: min(400px, 100%)` is the smaller
  /// of two lengths of the same line -- 400 wherever the line is longer
  /// than that, the line itself where it is not -- and which of the two
  /// binds is not known until the line's length is. `min()` is the basis
  /// and a [basisCap], `max()` the basis and a [basisFloor], and `clamp(lo,
  /// mid, hi)` the basis `mid` between a floor `lo` and a ceiling `hi`,
  /// where the floor wins (css-values-4 10.4). A bound that is a share of
  /// a length the line does not have makes the basis no length at all,
  /// as a share alone is: the child's content, or [basisKeyword].
  final double? basisCap, basisCapFraction, basisFloor, basisFloorFraction;

  /// `width`/`height` ALONG the line: the size this child asks for on its
  /// own. A basis is where flexing starts; this is what the child would be,
  /// and the line needs both.
  final double? mainSize, mainSizeFraction;

  /// `width`/`height` ACROSS the line, as a share of its depth where the
  /// line was given one. A child that states one is not stretched.
  final double? crossSize, crossSizeFraction;

  /// `min-width`/`max-width` along the line. `min: 0` gives up the
  /// automatic minimum -- the floor at the child's own min-content size --
  /// which is the only way to let the line crush it.
  final double? min, minFraction, max, maxFraction;

  /// A CEILING ON [min]: `min-width: min(100%, 72px)` is the smaller of
  /// two affine functions of the same room -- 72 wherever the room is
  /// wider than that and the room itself where it is not -- and which of
  /// the two binds is not known until the room is. Null leaves the floor
  /// on its own.
  final double? minCap, minCapFraction;

  /// `min-height`/`max-height` across the line.
  final double? crossMin, crossMinFraction, crossMax, crossMaxFraction;

  /// `margin`, which may be negative.
  final EdgeInsets margin;

  /// The margin edges that take the room left over instead of a length: an
  /// `auto` margin eats the free space before `justify-content` sees it,
  /// and one on each side of an axis centres the child in it.
  final AutoEdges autoMargin;

  /// The child's OWN padding and border. The line shrinks an item in
  /// proportion to its CONTENT box (§9.7) and never below its frame, so it
  /// has to be told how much of the child is frame.
  final EdgeInsets frame;

  /// The frame's PERCENTAGE part, as shares of the line's WIDTH: a
  /// percentage padding is a share of the containing block's width on
  /// every side, the top and the bottom included (CSS 2.1 8.4), and an
  /// item's containing block is the line's content box. The line has that
  /// width where it was handed one (a tight width); while it is working
  /// its own width out the share is cyclic and comes to nothing
  /// (css-sizing-3 5.2.1). The child pads itself by the same share; the
  /// line needs it to shrink the content box and floor the item at its
  /// frame, as it needs [frame].
  final EdgeInsets frameFraction;

  /// The part of [frameFraction] that is the item's MARGIN: a percentage
  /// margin the child holds inside itself, round the box the page draws
  /// (an `Inset` of the line's room). The line sees it as frame like the
  /// rest, but a [ratio] is of the box inside it (css-sizing-4 2.1): a
  /// `width: 35%; margin-top: 15.74%; aspect-ratio: 1` item down a column
  /// is as deep as it is wide, and the share on top of that.
  final EdgeInsets marginFraction;

  /// `flex-basis`, and the item's minimum and maximum along the line, as a
  /// SIZING KEYWORD ([FlexKeyword]). A keyword basis stands in for the
  /// item's own length along the line, which is left out of the question
  /// (css-flexbox-1 7.2.3): `min-content` and `max-content` are what the
  /// child measures at, `fit-content` its content in the line's length and
  /// `stretch` that whole length less the margins -- where the line was
  /// handed a length; where it was not, the two answer with the content,
  /// as `content` does. As a minimum or a maximum, `min-content` and
  /// `max-content` are the child's measurements and take the place of
  /// [min] and [max]; the other keywords bound nothing.
  ///
  /// WRITTEN BESIDE A SHARE ([basisFraction]), the keyword is the basis
  /// only where the share is of no length. css-flexbox-1 7.2.3 makes a
  /// percentage `flex-basis` against a container whose length is not
  /// definite `content` -- the item's own [mainSize] left out, where a
  /// share alone falls back to it -- and a length the line was handed
  /// makes it the share again: a wrapping column that the column above it
  /// first MEASURES and then lays out at the length it settled reads
  /// `flex-basis: 100%` as its content, and then as all of that length
  /// (`fixtures/flex-column-indefinite-main` case 2).
  final FlexKeyword? basisKeyword, minKeyword, maxKeyword;

  /// `position: relative` with a PERCENTAGE `left` and `top`: the child is
  /// drawn moved by that share of the line's width and height -- the flex
  /// container's content box, which is an item's containing block -- and
  /// the room it took on the line stays where it was (CSS 2.1 9.4.3). The
  /// width is always the line's own. A percentage `top` is of a height the
  /// line was HANDED (a tight height), and against one it was not -- a
  /// line as deep as its content -- it is `auto` and moves nothing
  /// (css-position-3 3.1).
  final double? shiftLeftFraction, shiftTopFraction;

  /// `align-self`: overrides the line's [FlexLine.crossAxisAlignment].
  final CrossAxisAlignment? align;

  /// `safe` in front of `align-self` ([align]): the alignment holds while
  /// the item fits its line, and an item deeper than the line sits at the
  /// START of the cross axis instead (css-align-3 4.4). It says nothing
  /// where [align] is null: the item then takes the line's alignment, and
  /// [FlexLine.safeCrossAxis] with it.
  final bool safe;

  /// Whether the child clips what overflows it. Such an item has no
  /// automatic minimum along the line (§4.5) and contributes its base size
  /// rather than its content.
  final bool clips;

  /// Whether the child is a picture -- a replaced box -- whose share of
  /// the line is OF NOTHING when the line is asked its least length: a
  /// percentage `width` or `max-width` on a replaced box resolves against
  /// zero for its min-content contribution (css-sizing-3 5.2.2), so the
  /// picture gives up all of its length to a row that shrinks the box it
  /// is in. A news site's footer picture is `width: 400px; max-width:
  /// 100%` in a flex `<a>`; Chrome shrinks the panel round it to 338 at
  /// 1024, and a floor of the 400 held it there.
  final bool compressible;

  /// `z-index`: who is drawn over whom. Lowest first, ties in document
  /// order, and it moves nothing -- an item's box is where the line put it
  /// whatever its order. `Tracks` reads the same key the same way.
  final int z;

  /// `aspect-ratio`: the child's width divided by its height. Where the
  /// line knows one of the two, the ratio says the other -- a TRANSFERRED
  /// size (css-sizing-4 4.1), which is what the child asks for along the
  /// line when it states no size of its own, and what it comes to across
  /// the line at the size the line gave it.
  final double? ratio;

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as FlexLineParentData;
    if (data.z != z) {
      data.z = z;
      renderObject.parent?.markNeedsPaint();
    }
    var changed = false;
    void set<T>(T have, T want, void Function(T) put) {
      if (have != want) {
        put(want);
        changed = true;
      }
    }

    set(data.grow, grow, (v) => data.grow = v);
    set(data.shrink, shrink, (v) => data.shrink = v);
    set(data.basis, basis, (v) => data.basis = v);
    set(data.basisFraction, basisFraction, (v) => data.basisFraction = v);
    set(data.basisCap, basisCap, (v) => data.basisCap = v);
    set(data.basisCapFraction, basisCapFraction, (v) => data.basisCapFraction = v);
    set(data.basisFloor, basisFloor, (v) => data.basisFloor = v);
    set(data.basisFloorFraction, basisFloorFraction, (v) => data.basisFloorFraction = v);
    set(data.mainSize, mainSize, (v) => data.mainSize = v);
    set(data.mainSizeFraction, mainSizeFraction, (v) => data.mainSizeFraction = v);
    set(data.crossSize, crossSize, (v) => data.crossSize = v);
    set(data.crossSizeFraction, crossSizeFraction, (v) => data.crossSizeFraction = v);
    set(data.min, min, (v) => data.min = v);
    set(data.minFraction, minFraction, (v) => data.minFraction = v);
    set(data.minCap, minCap, (v) => data.minCap = v);
    set(data.minCapFraction, minCapFraction, (v) => data.minCapFraction = v);
    set(data.max, max, (v) => data.max = v);
    set(data.maxFraction, maxFraction, (v) => data.maxFraction = v);
    set(data.crossMin, crossMin, (v) => data.crossMin = v);
    set(data.crossMinFraction, crossMinFraction, (v) => data.crossMinFraction = v);
    set(data.crossMax, crossMax, (v) => data.crossMax = v);
    set(data.crossMaxFraction, crossMaxFraction, (v) => data.crossMaxFraction = v);
    set(data.margin, margin, (v) => data.margin = v);
    set(data.autoMargin, autoMargin, (v) => data.autoMargin = v);
    set(data.frame, frame, (v) => data.frame = v);
    set(data.frameFraction, frameFraction, (v) => data.frameFraction = v);
    set(data.marginFraction, marginFraction, (v) => data.marginFraction = v);
    set(data.basisKeyword, basisKeyword, (v) => data.basisKeyword = v);
    set(data.minKeyword, minKeyword, (v) => data.minKeyword = v);
    set(data.maxKeyword, maxKeyword, (v) => data.maxKeyword = v);
    set(data.align, align, (v) => data.align = v);
    set(data.safe, safe, (v) => data.safe = v);
    set(data.clips, clips, (v) => data.clips = v);
    set(data.compressible, compressible, (v) => data.compressible = v);
    set(data.ratio, ratio, (v) => data.ratio = v);
    set(data.shiftLeftFraction, shiftLeftFraction, (v) => data.shiftLeftFraction = v);
    set(data.shiftTopFraction, shiftTopFraction, (v) => data.shiftTopFraction = v);
    if (changed) {
      final parent = renderObject.parent;
      if (parent is RenderObject) parent.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => FlexLine;
}

/// What a [FlexLine] knows about one of its children: [FlexCell]'s fields,
/// each under its CSS default.
class FlexLineParentData extends ContainerBoxParentData<RenderBox> {
  double grow = 0;
  double shrink = 1;
  double? basis, basisFraction;
  double? basisCap, basisCapFraction, basisFloor, basisFloorFraction;
  double? mainSize, mainSizeFraction;
  double? crossSize, crossSizeFraction;
  double? min, minFraction, max, maxFraction;
  double? minCap, minCapFraction;
  double? crossMin, crossMinFraction, crossMax, crossMaxFraction;
  EdgeInsets margin = EdgeInsets.zero;
  AutoEdges autoMargin = AutoEdges.none;
  EdgeInsets frame = EdgeInsets.zero;
  EdgeInsets frameFraction = EdgeInsets.zero;
  EdgeInsets marginFraction = EdgeInsets.zero;
  FlexKeyword? basisKeyword, minKeyword, maxKeyword;
  CrossAxisAlignment? align;
  bool safe = false;
  bool clips = false;
  bool compressible = false;
  int z = 0;
  double? ratio;
  double? shiftLeftFraction, shiftTopFraction;
}

/// One item of the line while it is being laid out: the numbers §9 walks
/// through, per child.
class _Item {
  _Item(this.child, this.data);

  final RenderBox child;
  final FlexLineParentData data;

  /// The size the child states along the line, where it states one
  /// (`width`), and across it (`height`); resolved against the line.
  double? statedMain, statedCross;

  /// Its minimum and maximum along the line and across it, resolved the
  /// same way.
  double? min, max, crossMin, crossMax;

  /// §9.2 step 3: the flex base size, and the same floored at the frame.
  double basis = 0, innerBasis = 0;

  /// §4.5: the size the line never shrinks this item below.
  double floor = 0;

  /// §9.2: the base size clamped by the floor and the maximum, and the same
  /// with the margins on.
  double hypoMain = 0, hypoOuterMain = 0;

  /// §9.4 step 7: the depth the item takes at its used main size.
  double hypoCross = 0;

  /// §9.7 / §9.4 step 11: the sizes the item is finally laid out at.
  double mainSize = 0, crossSize = 0;

  /// Where the item sits, from the line's main-start and cross-start edges.
  double offsetMain = 0, offsetCross = 0;

  /// Where the item's first line of text sits, from its own top.
  double baseline = 0;

  /// §9.7: the margins, once auto ones have taken their share.
  EdgeInsets margin = EdgeInsets.zero;

  /// The item's padding and border, its shares of the line's width
  /// resolved ([FlexCell.frameFraction]).
  EdgeInsets frame = EdgeInsets.zero;

  /// The part of [frame] outside the box a ratio is of: the item's
  /// percentage margin, resolved ([FlexCell.marginFraction]).
  EdgeInsets ratioOut = EdgeInsets.zero;

  double violation = 0;
  bool frozen = false;
}

/// How much room the line has along an axis: a length, or a question.
enum _Room {
  /// As much as the content wants (an unbounded slot, or a max-content
  /// question from above).
  maxContent,

  /// As little as the content can (a min-content question from above).
  minContent,

  /// A length in pixels.
  definite,
}

/// [FlexLine]'s layout: css-flexbox-1 §9 for a single line.
class RenderFlexLine extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, FlexLineParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, FlexLineParentData>,
        PaintOrder,
        AsksGuarded,
        PassesBaseline,
        KeptUnderHatch {
  RenderFlexLine({
    Axis direction = Axis.horizontal,
    bool reverse = false,
    double? maxExtent,
    MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.stretch,
    double spacing = 0,
    double? spacingFraction,
    bool wrap = false,
    double runSpacing = 0,
    double? runSpacingFraction,
    WrapAlignment? alignContent,
    bool reverseLines = false,
    bool balance = false,
    int lineCount = 1,
    TextDirection textDirection = TextDirection.ltr,
    bool safeMainAxis = false,
    bool safeCrossAxis = false,
    TextBaseline textBaseline = TextBaseline.alphabetic,
  }) : _direction = direction,
       _reverse = reverse,
       _maxExtent = maxExtent,
       _mainAxisAlignment = mainAxisAlignment,
       _crossAxisAlignment = crossAxisAlignment,
       _spacing = spacing,
       _spacingFraction = spacingFraction,
       _wrap = wrap,
       _runSpacing = runSpacing,
       _runSpacingFraction = runSpacingFraction,
       _alignContent = alignContent,
       _reverseLines = reverseLines,
       _balance = balance,
       _lineCount = lineCount,
       _textDirection = textDirection,
       _safeMainAxis = safeMainAxis,
       _safeCrossAxis = safeCrossAxis,
       _textBaseline = textBaseline;

  Axis _direction;
  Axis get direction => _direction;
  set direction(Axis value) {
    if (_direction == value) return;
    _direction = value;
    markNeedsLayout();
  }

  bool _reverse;
  bool get reverse => _reverse;
  set reverse(bool value) {
    if (_reverse == value) return;
    _reverse = value;
    markNeedsLayout();
  }

  double? _maxExtent;
  double? get maxExtent => _maxExtent;
  set maxExtent(double? value) {
    if (_maxExtent == value) return;
    _maxExtent = value;
    markNeedsLayout();
  }

  MainAxisAlignment _mainAxisAlignment;
  MainAxisAlignment get mainAxisAlignment => _mainAxisAlignment;
  set mainAxisAlignment(MainAxisAlignment value) {
    if (_mainAxisAlignment == value) return;
    _mainAxisAlignment = value;
    markNeedsLayout();
  }

  CrossAxisAlignment _crossAxisAlignment;
  CrossAxisAlignment get crossAxisAlignment => _crossAxisAlignment;
  set crossAxisAlignment(CrossAxisAlignment value) {
    if (_crossAxisAlignment == value) return;
    _crossAxisAlignment = value;
    markNeedsLayout();
  }

  double _spacing;
  double get spacing => _spacing;
  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  double? _spacingFraction;
  double? get spacingFraction => _spacingFraction;
  set spacingFraction(double? value) {
    if (_spacingFraction == value) return;
    _spacingFraction = value;
    markNeedsLayout();
  }

  double? _runSpacingFraction;
  double? get runSpacingFraction => _runSpacingFraction;
  set runSpacingFraction(double? value) {
    if (_runSpacingFraction == value) return;
    _runSpacingFraction = value;
    markNeedsLayout();
  }

  /// The gaps along the line and between its lines as this layout reads
  /// them: [spacing] and [runSpacing], plus their shares of the box's own
  /// length on each axis where the box was handed that length
  /// ([FlexLine.spacingFraction]). Set as each layout or measurement
  /// starts; nothing below it lays this box out again before it ends.
  double _gap = 0, _runGap = 0;

  bool _wrap;
  bool get wrap => _wrap;
  set wrap(bool value) {
    if (_wrap == value) return;
    _wrap = value;
    markNeedsLayout();
  }

  double _runSpacing;
  double get runSpacing => _runSpacing;
  set runSpacing(double value) {
    if (_runSpacing == value) return;
    _runSpacing = value;
    markNeedsLayout();
  }

  WrapAlignment? _alignContent;
  WrapAlignment? get alignContent => _alignContent;
  set alignContent(WrapAlignment? value) {
    if (_alignContent == value) return;
    _alignContent = value;
    markNeedsLayout();
  }

  bool _reverseLines;
  bool get reverseLines => _reverseLines;
  set reverseLines(bool value) {
    if (_reverseLines == value) return;
    _reverseLines = value;
    markNeedsLayout();
  }

  bool _balance;
  bool get balance => _balance;
  set balance(bool value) {
    if (_balance == value) return;
    _balance = value;
    markNeedsLayout();
  }

  int _lineCount;
  int get lineCount => _lineCount;
  set lineCount(int value) {
    if (_lineCount == value) return;
    _lineCount = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  bool _safeMainAxis;
  bool get safeMainAxis => _safeMainAxis;
  set safeMainAxis(bool value) {
    if (_safeMainAxis == value) return;
    _safeMainAxis = value;
    markNeedsLayout();
  }

  bool _safeCrossAxis;
  bool get safeCrossAxis => _safeCrossAxis;
  set safeCrossAxis(bool value) {
    if (_safeCrossAxis == value) return;
    _safeCrossAxis = value;
    markNeedsLayout();
  }

  TextBaseline _textBaseline;
  TextBaseline get textBaseline => _textBaseline;
  set textBaseline(TextBaseline value) {
    if (_textBaseline == value) return;
    _textBaseline = value;
    markNeedsLayout();
  }

  bool get _row => _direction == Axis.horizontal;

  // WHICH WAY EACH AXIS RUNS. The line is always walked from its left and
  // top edges; these say where CSS starts it.

  /// A row under `rtl`, whose main axis starts at its right edge. A
  /// column's main axis is the block one, which `direction` never turns.
  bool get _mainBack => _row && _textDirection == TextDirection.rtl;

  /// A column under `rtl`, whose cross axis starts at its right edge.
  bool get _crossBack => !_row && _textDirection == TextDirection.rtl;

  /// Whether the items run from the far end of the walk: `row-reverse` or
  /// a right-to-left row, and not both, which is left to right again.
  bool get _flipMain => _reverse != _mainBack;

  /// `wrap-reverse`, which only a box that wraps has.
  bool get _wrapReverse => _wrap && _reverseLines;

  /// Whether `flex-start` across the line is its far edge -- the lines
  /// stack from there and an item aligned to `start` sits there:
  /// `wrap-reverse` or a right-to-left column, and not both.
  bool get _flipCross => _wrapReverse != _crossBack;

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! FlexLineParentData) child.parentData = FlexLineParentData();
  }

  double _main(Size s) => _row ? s.width : s.height;
  double _cross(Size s) => _row ? s.height : s.width;
  Size _size(double main, double cross) => _row ? Size(main, cross) : Size(cross, main);
  double _mainSum(EdgeInsets e) => _row ? e.horizontal : e.vertical;
  double _crossSum(EdgeInsets e) => _row ? e.vertical : e.horizontal;
  double _mainStart(EdgeInsets e) => _row ? e.left : e.top;
  double _crossStart(EdgeInsets e) => _row ? e.top : e.left;
  bool _autoMainStart(AutoEdges a) => _row ? a.left : a.top;
  bool _autoMainEnd(AutoEdges a) => _row ? a.right : a.bottom;
  bool _autoCrossStart(AutoEdges a) => _row ? a.top : a.left;
  bool _autoCrossEnd(AutoEdges a) => _row ? a.bottom : a.right;

  // --- the layout ---------------------------------------------------------------

  /// The line, laid out. [place] hands each child its size and position;
  /// without it nothing is laid out for real and the answer is a
  /// measurement (a dry layout, an intrinsic size, a baseline).
  _Line _layOut(
    BoxConstraints constraints, {
    required bool place,
    _Room mainRoom = _Room.definite,
    _Room crossRoom = _Room.definite,
  }) {
    final items = <_Item>[];
    for (var child = firstChild; child != null;) {
      final data = child.parentData! as FlexLineParentData;
      items.add(_Item(child, data));
      child = data.nextSibling;
    }

    final tightMain = _row ? constraints.hasTightWidth : constraints.hasTightHeight;
    final tightCross = _row ? constraints.hasTightHeight : constraints.hasTightWidth;
    // A SHARE OF A LENGTH THE BOX WAS HANDED, and nothing of one it was
    // not ([FlexLine.spacingFraction]).
    _gap =
        _spacing +
        (_spacingFraction == null || !tightMain
            ? 0.0
            : _spacingFraction! * (_row ? constraints.maxWidth : constraints.maxHeight));
    _runGap =
        _runSpacing +
        (_runSpacingFraction == null || !tightCross
            ? 0.0
            : _runSpacingFraction! * (_row ? constraints.maxHeight : constraints.maxWidth));
    // The width the items' percentage frames are shares of: the box's own,
    // where it was handed one, and nothing while it is working it out
    // ([FlexCell.frameFraction]).
    final frameRoom = constraints.hasTightWidth ? constraints.maxWidth : 0.0;
    // THE BOX'S OWN CEILING ALONG THE LINE IS A CEILING ON THE ROOM.
    // `max-width` on a flex container caps the box, and the box is the
    // room its items are laid out in, so capping the constraint here caps
    // both at once: everything below reads `maxMain` and never the box.
    final maxMain = math.min(_main(Size(constraints.maxWidth, constraints.maxHeight)), _maxExtent ?? double.infinity);
    final maxCross = _cross(Size(constraints.maxWidth, constraints.maxHeight));
    final minMain = _main(Size(constraints.minWidth, constraints.minHeight));
    final minCross = _cross(Size(constraints.minWidth, constraints.minHeight));

    // A TIGHT LENGTH IS THE LINE'S OWN SIZE; a ceiling is its maximum and a
    // floor its minimum, which is not the same thing -- a line held to at
    // least 100 lays its items out in 100 and centres them there, where
    // constraining the finished box would centre them in their own size.
    final knownMain = tightMain ? maxMain : null;
    final knownCross = tightCross ? maxCross : null;
    // How much room the items are measured in. A question from above
    // (min-content, max-content) travels with [mainRoom].
    final room = knownMain != null
        ? _Room.definite
        : mainRoom != _Room.definite
        ? mainRoom
        : maxMain.isFinite
        ? _Room.definite
        : _Room.maxContent;
    final roomMain = knownMain ?? (room == _Room.definite ? maxMain : double.infinity);
    // The room ACROSS the line, which every measurement is taken in: one
    // line's share of it, where the box is balanced over a count of lines
    // ([FlexLine.lineCount]).
    final roomCross = _shared(knownCross ?? (maxCross.isFinite ? maxCross : null));

    final gaps = items.length <= 1 ? 0.0 : _gap * (items.length - 1);

    // A SHARE IS OF A LENGTH THE LINE HAS: its own, where it was given one
    // (css-flexbox-1 9.8). A depth it will only come to is no basis.
    for (final item in items) {
      _measureItem(
        item,
        roomMain: knownMain,
        shareCross: knownCross,
        roomCross: roomCross,
        room: room,
        crossRoom: crossRoom,
        frameRoom: frameRoom,
      );
    }

    // §9.3 step 4: the line's own length. Its content's, where it fits, and
    // the room there is where it does not -- never less than its items'
    // min-content sizes (fit-content, css-sizing-3 5.2.2).
    //
    // A BALANCED BOX'S CONTENT IS ITS LONGEST LINE ([FlexLine.balance]):
    // its max-content length is the longest of the lines its items make
    // balanced across [lineCount] of them with nothing to stop them, and a
    // column whose height nobody stated breaks into its lines first and is
    // as tall as the tallest. Where the length came from the lines, they
    // are the lines the box lays out ([counts]).
    List<int>? counts;
    double innerMain;
    if (knownMain != null) {
      innerMain = knownMain;
    } else if (room == _Room.definite && _row) {
      final maxContent = _balances && _lineCount > 1
          ? _longestLine(items, _Room.maxContent, roomCross, crossRoom)
          : _contributions(items, _Room.maxContent, roomCross, crossRoom) + gaps;
      if (maxContent <= roomMain) {
        innerMain = maxContent;
      } else {
        innerMain = math.max(_leastMain(items, roomCross, crossRoom, gaps), roomMain);
      }
    } else if (room == _Room.definite) {
      // A COLUMN IS AS TALL AS WHAT IT HOLDS, whatever height it is offered:
      // a block's automatic height is its content's, and a height nobody
      // stated is not a length to fill (CSS 2.1 10.6.3).
      if (_balances) {
        counts = _counts(items, maxMain.isFinite ? maxMain : double.infinity);
        innerMain = _longestLine(items, _Room.maxContent, roomCross, crossRoom, counts: counts);
      } else {
        innerMain = _contributions(items, _Room.maxContent, roomCross, crossRoom) + gaps;
      }
    } else if (room == _Room.maxContent && _balances) {
      counts = _counts(items, double.infinity);
      innerMain = _longestLine(items, room, roomCross, crossRoom, counts: counts);
    } else {
      innerMain = room == _Room.minContent
          ? _leastMain(items, roomCross, crossRoom, gaps)
          : _contributions(items, room, roomCross, crossRoom) + gaps;
    }
    innerMain = _clamped(innerMain, minMain, maxMain.isFinite ? maxMain : null);

    // A PERCENTAGE GAP ALONG A ROW IS OF THE ROW'S OWN WIDTH, which is
    // settled now: a row's width is always a length by the time its items
    // are laid out, whatever it took to find it, and the share it could
    // not be while the width was being worked out -- nothing, above --
    // it is from here on (css-align-3 8.3; taffy re-resolves the gap at
    // the same step). A height is a length only where it was handed one.
    // A question from above is still answered with nothing.
    if (_spacingFraction != null && _row && mainRoom == _Room.definite) {
      _gap = _spacing + _spacingFraction! * innerMain;
    }

    // A ROW WHOSE LENGTH ITS CONTENT SETTLED has that length now, and a
    // share along it was a question the items could not answer while it was
    // open: they contributed their content, which is what css-sizing-3
    // 5.2.1 asks of them, and now they are measured again with the shares
    // read against it. The line's own length is not measured again -- it is
    // what the shares are OF.
    if (knownMain == null && _row && items.any((i) => _sharesAlong(i.data))) {
      for (final item in items) {
        _measureItem(
          item,
          roomMain: innerMain,
          shareCross: knownCross,
          roomCross: roomCross,
          room: room,
          crossRoom: crossRoom,
          frameRoom: frameRoom,
        );
      }
    }

    // §9.3 step 5: an item that does not fit the room left starts another
    // line, where the line wraps. Every run flexes and aligns on its own,
    // and the box is as deep as all of them and the gaps between them. A
    // BALANCED box divides its items among its lines instead
    // ([FlexLine.balance]) -- the lines its length came from, where it came
    // from them.
    final runs = !_wrap
        ? <List<_Item>>[items]
        : _balance
        ? _split(items, counts ?? _counts(items, innerMain))
        : _runsOf(items, innerMain);
    final measured = [
      for (final run in runs)
        _measureRun(
          run,
          innerMain: innerMain,
          roomCross: roomCross,
          crossRoom: crossRoom,
          lineCross: _wrap ? null : knownCross,
        ),
    ];
    var natural = _runGap * (measured.length - 1);
    for (final m in measured) {
      natural += m.cross;
    }
    final crosses = [for (final m in measured) m.cross];
    final double boxCross;
    if (!_wrap) {
      // ONE LINE IS THE BOX: a box that does not wrap has a single line,
      // and a definite depth IS that line's (css-flexbox-1 9.4 step 8) --
      // as deep as it was told to be, or as deep as what it holds, held
      // between the floor and the ceiling.
      crosses[0] = knownCross ?? _clamped(natural, minCross, maxCross.isFinite ? maxCross : null);
      boxCross = crosses[0];
    } else {
      // A BOX THAT WRAPS IS MULTI-LINE WHATEVER IT CAME TO. `flex-wrap` is
      // what makes it one, not the number of lines: its lines are as deep
      // as their own items, the box does not hold them to its depth, and
      // `align-content` has its say over the one line as much as over five
      // (css-flexbox-1 8.4). taffy's flex_align_content_end is a column of
      // five 10-deep items in 100 -- one line, 50 wide, at the right end --
      // and flex_align_content_stretch_row_wrap is one line 150 deep in a
      // box of 100, which hangs out of it.
      boxCross = knownCross ?? _clamped(natural, minCross, maxCross.isFinite ? maxCross : null);
      // §9.6 step 15 at `align-content`'s default, `stretch`: the room left
      // over is shared out equally among the lines. Where there is none to
      // share, the lines are what they came to and the box overflows.
      final over = boxCross - natural;
      if (over > 0 && _alignContent == null) {
        for (var i = 0; i < crosses.length; i++) {
          crosses[i] += over / crosses.length;
        }
      }
    }

    final size = constraints.constrain(_size(knownMain ?? innerMain, boxCross));

    // 9.6 step 15 at any other `align-content`: the lines keep the depth
    // they came to and the room left over is put round them, the way
    // `justify-content` puts the room left along the line round its items.
    var used = _runGap * (crosses.length - 1);
    for (final c in crosses) {
      used += c;
    }
    final (lead, between) = _runGaps(boxCross - used, crosses.length);

    // A REVERSED LINE IS THE SAME LINE WITH ITS ITEMS THE OTHER WAY
    // ROUND, and every run is read backwards from here down: the line is
    // walked from its physical near edge either way. Each item still
    // carries the margins written on its own left and right -- CSS turns
    // the main axis round and moves no margin -- and the children still
    // PAINT in the order they were written (css-flexbox-1 5.4), because
    // only these lists turn round and never the child list itself.
    //
    // AND ITS BASELINE COMES FROM THE ITEM AT THAT NEAR EDGE, which is the
    // last one the page wrote. `fixtures/baseline-groups` row 3 is a
    // 90-deep `column-reverse` holding a 30 with text and an empty 20:
    // Chrome packs them at the bottom and answers the EMPTY one's bottom
    // edge, 60 down the box, and not the text's baseline 18 lower down.
    // taffy's `flex_flex_container_baseline_column_reverse` says the same.
    //
    // A RIGHT-TO-LEFT ROW IS WALKED THE SAME WAY, from its far end: its
    // first item is the rightmost ([textDirection]).
    final placed = _flipMain ? [for (final run in runs) run.reversed.toList()] : runs;
    // Where a relative shift moves an item's drawing, off the box's own
    // width and the height it was handed ([FlexCell.shiftLeftFraction]).
    final shiftRoom = Size(size.width, constraints.hasTightHeight ? size.height : 0);
    // THE LINES STACK FROM THE FAR SIDE under `wrap-reverse` or down a
    // right-to-left column ([_flipCross]), so the last one written is the
    // first from the top or the left; the room `align-content` leaves is
    // put round them as they stand on the page ([_runGaps]).
    var at = lead;
    for (var k = 0; k < runs.length; k++) {
      final i = _flipCross ? runs.length - 1 - k : k;
      _placeRun(
        placed[i],
        innerMain: innerMain,
        lineCross: crosses[i],
        maxBaseline: measured[i].baseline,
        crossOffset: at,
        place: place,
        shiftRoom: shiftRoom,
      );
      at += crosses[i] + _runGap + between;
    }
    // The box's first baseline is its first line's: the first on the page,
    // which under `wrap-reverse` is the last one written (css-flexbox-1
    // 8.5).
    return _Line(size, items, placed[_wrapReverse ? runs.length - 1 : 0]);
  }

  /// Where `align-content` puts the room [free] left over between and
  /// before [runs] lines: what comes before the first line ON THE PAGE --
  /// the top or left one -- and what comes between each pair. Room that
  /// is not there is never taken back -- `end` and `center` hang the lines
  /// out of the box the way CSS does (css-align-3 5.3).
  ///
  /// `start` and `end` are the FLEX ends of the axis, which turn round
  /// with `wrap-reverse` and down a right-to-left column ([_flipCross]).
  /// The keywords that spread the room fall back where there is none to
  /// spread or one line to spread it round: `spaceBetween` and `stretch`
  /// to a SAFE `start`, and `spaceAround` and `spaceEvenly` to a safe
  /// centre -- and a safe keyword with no room left is the start of the
  /// AXIS, which `wrap-reverse` does not turn round and `rtl` does: lines
  /// that overflow a right-to-left column hang out of its left edge.
  (double, double) _runGaps(double free, int runs) {
    if (runs <= 0) return (0.0, 0.0);
    var mode = _alignContent;
    var safe = false;
    if (runs <= 1 || free <= 0) {
      switch (mode) {
        case null || WrapAlignment.spaceBetween:
          mode = WrapAlignment.start;
          safe = true;
        case WrapAlignment.spaceAround || WrapAlignment.spaceEvenly:
          mode = WrapAlignment.center;
          safe = true;
        default:
          break;
      }
    }
    // How far the first line is from the edge the lines are walked from
    // in CSS -- the start of the axis, or its far end under `wrap-reverse`
    // -- and what goes between each pair.
    final double walk;
    var between = 0.0;
    if (free <= 0 && safe) {
      walk = 0;
    } else {
      final room = math.max(free, 0.0);
      switch (mode) {
        case null:
          walk = 0;
        case WrapAlignment.start:
          walk = _wrapReverse ? free : 0;
        case WrapAlignment.end:
          walk = _wrapReverse ? 0 : free;
        case WrapAlignment.center:
          walk = free / 2;
        case WrapAlignment.spaceBetween:
          walk = 0;
          between = room / (runs - 1);
        case WrapAlignment.spaceAround:
          walk = free >= 0 ? free / runs / 2 : free / 2;
          between = room / runs;
        case WrapAlignment.spaceEvenly:
          walk = free >= 0 ? free / (runs + 1) : free / 2;
          between = room / (runs + 1);
      }
    }
    // A right-to-left column is walked from its right edge: what is left
    // at its left is everything the walk and the gaps do not take.
    return (_crossBack ? free - walk - between * (runs - 1) : walk, between);
  }

  /// The least room the line can be laid out in: its items' min-content
  /// sizes with the gaps between them where they all stand on one line,
  /// and the WIDEST of them alone where the line wraps -- a line that
  /// wraps never has to hold two items side by side.
  double _leastMain(List<_Item> items, double? roomCross, _Room crossRoom, double gaps) => _wrap
      ? _contributions(items, _Room.minContent, roomCross, crossRoom, widest: true)
      : _contributions(items, _Room.minContent, roomCross, crossRoom) + gaps;

  /// §9.3 step 5: the items broken into lines. An item goes on the line
  /// being collected unless it would take the line past [innerMain] -- its
  /// HYPOTHETICAL main size counts, the size it asked for clamped by its
  /// own floor and cap, before any of the flexing that comes after -- and
  /// a line always holds at least one item, however long it is.
  ///
  /// IN BLINK'S LAYOUT UNITS: Blink sizes each item on its 1/64 px grid,
  /// a length truncated into one, and sums them there. Five `flex-basis:
  /// 20%` items in the news site's 928 px footer are 185.59375 each and fit; as
  /// doubles each is 185.60000000000002, five of them 928.0000000000001,
  /// and the fifth started a line of its own -- the news site's footer columns four
  /// to a line at 1024, 126 px longer than Chrome's
  /// (`fixtures/flex-wrap-fifths`).
  List<List<_Item>> _runsOf(List<_Item> items, double innerMain) {
    // A line of unbounded room holds everything: no unit is that long.
    int unit(double v) => v.isFinite ? (v * 64 + 1e-6).floor() : 1 << 52;
    final room = unit(innerMain);
    final gap = unit(_gap);
    final runs = <List<_Item>>[];
    var run = <_Item>[];
    var used = 0;
    for (final item in items) {
      final want = unit(item.hypoOuterMain);
      if (run.isNotEmpty && used + gap + want > room) {
        runs.add(run);
        run = <_Item>[];
        used = 0;
      }
      used += (run.isEmpty ? 0 : gap) + want;
      run.add(item);
    }
    if (run.isNotEmpty) runs.add(run);
    return runs.isEmpty ? [<_Item>[]] : runs;
  }

  /// Whether the items are balanced across the lines ([FlexLine.balance]),
  /// which only a box that wraps has.
  bool get _balances => _wrap && _balance;

  /// css-flexbox-2 6.1: the room across a box balanced over [lineCount]
  /// lines that one of them has -- [room] less the gaps between them,
  /// shared out -- and all of [room] where the gaps leave nothing to share,
  /// or the box does not balance ([FlexLine.lineCount]).
  double? _shared(double? room) {
    if (room == null || !_balances || _lineCount <= 1) return room;
    final left = room - (_lineCount - 1) * _runGap;
    return left > 0 ? left / _lineCount : room;
  }

  /// How many items go on each balanced line, no line of two or more
  /// longer than [limit] ([balancedLineItemCounts]): each item is its
  /// HYPOTHETICAL length, as it is for plain wrapping ([_runsOf]).
  List<int> _counts(List<_Item> items, double limit) => items.isEmpty
      ? const <int>[]
      : balancedLineItemCounts([for (final item in items) item.hypoOuterMain], limit, _gap, _lineCount);

  /// [items] cut into lines of [counts] items each.
  List<List<_Item>> _split(List<_Item> items, List<int> counts) {
    if (items.isEmpty) return [<_Item>[]];
    final runs = <List<_Item>>[];
    var start = 0;
    for (final n in counts) {
      runs.add(items.sublist(start, start + n));
      start += n;
    }
    return runs;
  }

  /// The longest line of a balanced box, each item its contribution to the
  /// box's own length ([_contribution]) and the gaps between them: on the
  /// lines [counts] says, or -- where it says none -- on the lines those
  /// contributions make balanced across [lineCount] lines with nothing to
  /// stop them.
  double _longestLine(List<_Item> items, _Room room, double? roomCross, _Room crossRoom, {List<int>? counts}) {
    if (items.isEmpty) return 0;
    final lengths = <double>[];
    for (final item in items) {
      final (basis, flexed) = _contribution(item, room, roomCross, crossRoom);
      lengths.add(basis + flexed);
    }
    var longest = 0.0, start = 0;
    for (final n in counts ?? balancedLineItemCounts(lengths, double.infinity, _gap, _lineCount)) {
      var line = 0.0;
      for (var i = start; i < start + n; i++) {
        line += lengths[i];
      }
      longest = math.max(longest, line + (n <= 1 ? 0.0 : _gap * (n - 1)));
      start += n;
    }
    return longest;
  }

  /// One line flexed and measured: §9.7 gives each item its length, §9.4
  /// step 7 its depth, and the line is as deep as its deepest item --
  /// measured from the items' baselines where they line up on one (§8.5).
  ({double cross, double baseline}) _measureRun(
    List<_Item> run, {
    required double innerMain,
    required double? roomCross,
    required _Room crossRoom,
    double? lineCross,
  }) {
    final gaps = run.length <= 1 ? 0.0 : _gap * (run.length - 1);
    _resolveFlexibleLengths(run, innerMain, gaps);
    for (final item in run) {
      // A STRETCHED ITEM ON THE ONE LINE OF A BOX HANDED ITS DEPTH IS AS
      // DEEP AS THAT LINE, whatever its content comes to (§9.4 steps 8 and
      // 11): the line is the box's depth ([_layOut]) and [_placeRun] hands
      // the item the line's, so nothing it would answer is read -- and it
      // is not asked. Down a column that was its least width
      // ([_across]), asked of every block on a page and through it of
      // everything they hold.
      if (lineCross != null && _stretches(item)) {
        item.hypoCross = _clamped(math.max(lineCross - _crossSum(item.data.margin), 0), item.crossMin, item.crossMax);
        continue;
      }
      _measureItemCross(item, roomCross: roomCross, crossRoom: crossRoom);
    }
    var baselines = 0;
    for (final item in run) {
      if (_onBaseline(item.data)) baselines++;
    }
    if (baselines > 1) {
      for (final item in run) {
        if (!_onBaseline(item.data)) continue;
        final text = _row
            ? dryBaselineOf(item.child, BoxConstraints.tight(Size(item.mainSize, item.hypoCross)), _textBaseline)
            : null;
        item.baseline = _synthesized(text, item.hypoCross, item.data) + _crossStart(item.data.margin);
      }
    }
    var maxBaseline = 0.0;
    for (final item in run) {
      maxBaseline = math.max(maxBaseline, item.baseline);
    }
    var cross = 0.0;
    for (final item in run) {
      final outer = item.hypoCross + _crossSum(item.data.margin);
      cross = math.max(cross, _onBaseline(item.data) ? maxBaseline - item.baseline + outer : outer);
    }
    return (cross: cross, baseline: maxBaseline);
  }

  /// §9.4 step 11 to §9.6 step 14: every item as deep as the line where it
  /// is stretched, the room left along the line to the auto margins and
  /// then to `justify-content`, the room across it to the cross-axis auto
  /// margins and then to `align-self` -- and the cursor walking the line,
  /// item by item, from its main-start edge. [crossOffset] is where this
  /// line starts across the box.
  void _placeRun(
    List<_Item> run, {
    required double innerMain,
    required double lineCross,
    required double maxBaseline,
    required double crossOffset,
    required bool place,
    Size shiftRoom = Size.zero,
  }) {
    final gaps = run.length <= 1 ? 0.0 : _gap * (run.length - 1);

    // §9.4 step 11: a stretched item is as deep as the line.
    for (final item in run) {
      item.crossSize = _stretches(item)
          ? _clamped(math.max(lineCross - _crossSum(item.data.margin), 0), item.crossMin, item.crossMax)
          : item.hypoCross;
    }

    // §9.5 step 12: the room left over goes to the auto margins, and what
    // they leave to `justify-content`.
    var used = gaps;
    for (final item in run) {
      used += item.mainSize + _mainSum(item.margin);
    }
    var free = innerMain - used;
    var autos = 0;
    for (final item in run) {
      if (_autoMainStart(item.data.autoMargin)) autos++;
      if (_autoMainEnd(item.data.autoMargin)) autos++;
    }
    if (free > 0 && autos > 0) {
      final share = free / autos;
      for (final item in run) {
        item.margin = _withMain(
          item.margin,
          start: _autoMainStart(item.data.autoMargin) ? share : null,
          end: _autoMainEnd(item.data.autoMargin) ? share : null,
        );
      }
      free = 0;
    }
    // ... AND `justify-content` NAMES THE ENDS OF THAT AXIS, not the
    // edges of the box: `start` on a reversed row is its right edge, and so
    // it is on a right-to-left one. With the items already the other way
    // round, that is the same packing read from the other end. The four
    // that spread the room are their own mirror and say the same thing
    // either way.
    final mode = _fallback(
      free,
      run.length,
      !_flipMain
          ? _mainAxisAlignment
          : switch (_mainAxisAlignment) {
              MainAxisAlignment.start => MainAxisAlignment.end,
              MainAxisAlignment.end => MainAxisAlignment.start,
              final other => other,
            },
    );
    for (var i = 0; i < run.length; i++) {
      run[i].offsetMain = _alignmentOffset(free, run.length, mode, i == 0);
    }

    // Under `wrap-reverse` the items on one baseline are packed against the
    // line's far edge: the one reaching furthest below its baseline touches
    // it.
    var maxBelow = 0.0;
    if (_wrapReverse && _row) {
      for (final item in run) {
        if (_onBaseline(item.data)) {
          maxBelow = math.max(maxBelow, item.crossSize + _crossSum(item.data.margin) - item.baseline);
        }
      }
    }

    // §9.6 steps 13 and 14: the cross-axis auto margins, then `align-self`.
    for (final item in run) {
      final freeCross = lineCross - item.crossSize - _crossSum(item.data.margin);
      final startAuto = _autoCrossStart(item.data.autoMargin), endAuto = _autoCrossEnd(item.data.autoMargin);
      if ((startAuto || endAuto) && freeCross < 0) {
        // Step 13's "otherwise": AN ITEM PAST ITS LINE STANDS AT THE START,
        // its auto margin there zero and the other taking up what it
        // passes the line by -- the writing mode's start, which is the
        // right of a right-to-left column. Shared between the two, an item
        // of 400 between auto margins down a column of 300 stood 50 out of
        // its left where Chrome starts it at the left and runs it 100 out
        // of the right (`fixtures/flex-column-stated-width-past-unread` p3).
        if (_crossBack) item.margin = _withCross(item.margin, start: _crossStart(item.margin) + freeCross);
      } else if (startAuto && endAuto) {
        item.margin = _withCross(item.margin, start: freeCross / 2, end: freeCross / 2);
      } else if (startAuto) {
        item.margin = _withCross(item.margin, start: freeCross);
      } else if (endAuto) {
        item.margin = _withCross(item.margin, end: freeCross);
      } else if (freeCross < 0 && (item.data.align != null ? item.data.safe : _safeCrossAxis)) {
        // A SAFE ALIGNMENT THAT WOULD PUSH THE ITEM OUT falls back to the
        // start of the axis -- not the flex start, which `wrap-reverse`
        // turns round, but the one `rtl` does (css-align-3 4.4).
        item.offsetCross = _crossBack ? freeCross : 0;
      } else {
        // `start` and `end` are the FLEX ends of the line, which turn round
        // with it ([_flipCross]), and a stretched item that cannot fill the
        // line is aligned as `start` is. Down a column a baseline is `start`
        // too -- the line's near edge under `rtl` only where the column
        // wraps, which is what Chrome draws.
        item.offsetCross = switch (_alignOf(item)) {
          CrossAxisAlignment.start || CrossAxisAlignment.stretch => _flipCross ? freeCross : 0,
          CrossAxisAlignment.end => _flipCross ? 0 : freeCross,
          CrossAxisAlignment.center => freeCross / 2,
          CrossAxisAlignment.baseline =>
            _row
                ? (_wrapReverse ? lineCross - maxBelow - item.baseline : maxBaseline - item.baseline)
                : (_wrapReverse != (_crossBack && !_wrap) ? freeCross : 0),
        };
      }
    }

    // The cursor walks the line, item by item, from its main-start edge.
    var cursor = 0.0;
    for (final item in run) {
      final main = cursor + item.offsetMain + _mainStart(item.margin);
      final cross = crossOffset + item.offsetCross + _crossStart(item.margin);
      item.offsetMain = main;
      item.offsetCross = cross;
      cursor = main + item.mainSize + (_row ? item.margin.right : item.margin.bottom);
      if (place) {
        item.child.layout(BoxConstraints.tight(_size(item.mainSize, item.crossSize)), parentUsesSize: true);
        item.data.offset =
            (_row ? Offset(main, cross) : Offset(cross, main)) +
            Offset(
              (item.data.shiftLeftFraction ?? 0) * shiftRoom.width,
              (item.data.shiftTopFraction ?? 0) * shiftRoom.height,
            );
      }
    }
  }

  /// §9.2 step 3 and §4.5: the item's base size, its floor and the base
  /// size clamped between the two, all along the line.
  void _measureItem(
    _Item item, {
    required double? roomMain,
    required double? shareCross,
    required double? roomCross,
    required _Room room,
    required _Room crossRoom,
    double frameRoom = 0,
  }) {
    final data = item.data;
    item.frame = data.frameFraction == EdgeInsets.zero ? data.frame : data.frame + data.frameFraction * frameRoom;
    item.ratioOut = data.marginFraction * frameRoom;
    final frameMain = _mainSum(item.frame);
    // An `auto` margin is not a length: it is nothing until step 12 hands it
    // the room left over.
    item.margin = EdgeInsets.fromLTRB(
      data.autoMargin.left ? 0 : data.margin.left,
      data.autoMargin.top ? 0 : data.margin.top,
      data.autoMargin.right ? 0 : data.margin.right,
      data.autoMargin.bottom ? 0 : data.margin.bottom,
    );
    // A PICTURE'S SHARE IS OF NOTHING WHERE THE LINE IS ASKED ITS LEAST
    // LENGTH ([FlexCell.compressible]) and has none of its own to be a
    // share of: its percentage size and cap come to zero, and the floor
    // under that cap with them.
    final shareMain = roomMain ?? (data.compressible && room == _Room.minContent ? 0.0 : null);
    // A SHARE THAT IS ALL MARGIN COMES TO NOTHING WHERE THE LINE HAS NO
    // LENGTH. A percentage margin the item holds inside itself
    // ([FlexCell.marginFraction]) is part of every size it states along the
    // line -- `width: 120px; margin-left: 5%` is a box of `calc(120px +
    // 5%)` -- and where the line is MEASURED rather than offered a length
    // (a float, an inline-block, a row whose base size is its content's)
    // the margin is cyclic and resolves against zero (css-sizing-3 5.2.1),
    // while the pixels are still the item's own: its contribution is 120,
    // where a share of nothing would have made the whole size `auto` and
    // the item its content. A share with any of the item's own in it is
    // still no length (`width: calc(50% + 5%)`), and so is a size of no
    // pixels at all (`width: 0%`). Along a row only: down a column the
    // margin's share is of the width, and no part of a height.
    final marginShare = _row ? _mainSum(data.marginFraction) : 0.0;
    double? along(double? px, double? fraction) =>
        shareMain == null && marginShare != 0 && px != null && fraction != null && (fraction - marginShare).abs() < 1e-9
        ? px
        : _resolve(px, fraction, shareMain);
    item.min = _floor(along(data.min, data.minFraction), along(data.minCap, data.minCapFraction));
    item.max = along(data.max, data.maxFraction);
    item.crossMin = _resolve(data.crossMin, data.crossMinFraction, shareCross);
    item.crossMax = _resolve(data.crossMax, data.crossMaxFraction, shareCross);
    item.statedMain = along(data.mainSize, data.mainSizeFraction);
    item.statedCross = _resolve(data.crossSize, data.crossSizeFraction, shareCross);
    // A FLOOR OR A CAP ACROSS THE LINE IS ONE ALONG IT TOO, through the
    // ratio (css-sizing-4 5.1): an empty `aspect-ratio: 2` item with
    // `min-height: 30px` is 60 wide, and the floor is where that 60 comes
    // from -- nothing else gave it a length. A transferred floor stands in
    // for an automatic one, which is what `auto` means once the other axis
    // has spoken for it.
    //
    // ONLY WHERE THE ITEM SAYS NOTHING ALONG THE LINE: a transfer runs
    // from the side that is settled towards the side that is not, and an
    // item that states its own length settles that side itself. Where it
    // does, the ratio says the depth and a cap across the line clamps the
    // DEPTH, giving nothing back along it -- a bookshop's covers are
    // 144 wide at 0.6445 with `max-height: 220px`, and Chrome draws them
    // 144 by 220, not 141.8 by 220.
    final saysMain =
        data.mainSize != null || data.mainSizeFraction != null || data.basis != null || data.basisFraction != null;
    final transfers = data.ratio != null && !saysMain;
    // A transferred floor is one floor MORE, not one instead: `min-width`
    // is still `auto` and still answers with the content, and the item is
    // held by whichever of the two is larger.
    final transferredFloor = transfers && item.crossMin != null ? _fromCross(item, item.crossMin!) : null;
    if (transfers && item.crossMax != null) {
      final t = _fromCross(item, item.crossMax!);
      item.max = item.max == null ? t : math.min(item.max!, t);
    }
    // A stretched item is measured AT the line's depth: a column inside it
    // lays its own content out in that, and has no size at all without it.
    //
    // AND AT THE DEPTH IT WILL HAVE, ITS OWN MAXIMUM ON (css-flexbox-1 9.4
    // step 11 and 9.2 step 3 both read the CLAMPED cross size). Measured at
    // the line's whole width, a section held to `crossMax` laid its text out
    // in more room than it gets: a docs site's intro section is a 1440-wide
    // line item with `max-width: 1280px`, and its paragraph came to one
    // 24px line fewer than the layout then gave it -- the line answered 374
    // where it drew 398, and every box under it moved.
    final frameCross = _crossSum(item.frame);
    double held(double v) => math.max(_clamped(v, item.crossMin, item.crossMax), frameCross);
    final crossKnown = item.statedCross != null
        ? held(item.statedCross!)
        : (_stretches(item) && roomCross != null ? held(math.max(roomCross - _crossSum(item.margin), 0)) : null);

    // A RATIO TURNS A DEPTH THE LINE KNOWS INTO A LENGTH ALONG IT: the
    // TRANSFERRED size (css-sizing-4 4.1, css-flexbox-1 9.2 step 3B). It
    // is what the child asks for where it asks for nothing itself, and it
    // comes before the content, which is only asked for where neither a
    // size nor a ratio says anything.
    final transferred = data.ratio == null || crossKnown == null ? null : _fromCross(item, crossKnown);

    // AND A STRETCH ACROSS THE LINE IS A DEPTH TO TRANSFER A FLOOR FROM.
    // A stretched item on a single line the box was GIVEN a depth for has
    // a DEFINITE cross size (css-flexbox-1 9.8), so the transferred size
    // suggestion -- which is the automatic minimum where the item states
    // no floor of its own (4.5) -- is that depth through the ratio. It is
    // what stops the shrink: a bare `aspect-ratio: 2` item on a line 100
    // wide and 100 deep is 200 wide and overflows, where the content
    // alone would let it give the 100 back. A floor the page WROTE takes
    // the automatic one's place and there is nothing to transfer
    // (`fixtures/flex-ratio-stretch`, h1 against h3). LIKE EVERY OTHER
    // READING OF 4.5 it is held down by the item's own cap along the line,
    // which is definite where it is written: a `max-width: 40px` item at a
    // ratio of 2 on a line 100 deep is 40 wide and 100 deep, not the 200
    // the depth transfers (taffy's flex_aspect_ratio_flex_row_stretch_-
    // fill_max_height).
    final stretchFloor =
        transfers && !_wrap && shareCross != null && data.min == null && data.minFraction == null && _stretches(item)
        ? math.min(
            _fromCross(item, held(math.max(shareCross - _crossSum(item.margin), 0))),
            item.max ?? double.infinity,
          )
        : null;

    // AND SO IS A DEPTH IT STATES. A box with a preferred ratio and a
    // definite size across is that size through the ratio as its
    // min-content length along the line, whatever it holds, and so no
    // shorter as its automatic minimum (4.5): the bookshop's cover
    // frames are `height: 100%; aspect-ratio: 1` down a line of 105.3 in a
    // card 38.7 wide, and Chrome keeps them 105.3 wide, hanging off both
    // sides -- an empty frame as much as one round its cover
    // (`fixtures/flex-hang-rigid` g1-g3). Not one that clips, nor one
    // that writes a floor of its own (g6: `min-width: 0` shrinks the
    // frame to its line); held down by its own cap along the line.
    final statedFloor =
        transfers &&
            item.statedCross != null &&
            transferred != null &&
            data.min == null &&
            data.minFraction == null &&
            data.minKeyword == null &&
            !data.clips
        ? math.min(transferred, item.max ?? double.infinity)
        : null;

    // A MINIMUM OR A MAXIMUM THAT IS A KEYWORD takes the place of any
    // length beside it (css-sizing-3 5.1). `min-content` and `max-content`
    // are the child's own measurements, taken at the depth the line holds
    // it to -- `max-width: min-content` holds the item at its longest word.
    // `fit-content` and `stretch` read the line's length less the margins,
    // as a keyword basis does: the content clamped into it, and all of it.
    // A product site's "Get started for free" is `width: 100%; max-width: 200px;
    // min-width: fit-content` with 24px of padding a side, and its one line
    // is past what the cap leaves it: the floor wins over the cap (10.4),
    // and Chrome draws it 200.6 wide on one line where the item stood 200
    // and broke onto two, the page under it 21.6px low. Where the line was
    // handed no length they bound nothing, and a minimum left to them is
    // the automatic one. `content` is a basis and nothing else, and the
    // length beside it stands.
    final stretchMain = roomMain == null ? null : math.max(roomMain - _mainSum(item.margin), 0.0);
    double? measured(FlexKeyword k) => switch (k) {
      FlexKeyword.minContent => _measureMain(item, _Room.minContent, crossKnown, roomCross, crossRoom),
      FlexKeyword.maxContent => _measureMain(item, _Room.maxContent, crossKnown, roomCross, crossRoom),
      FlexKeyword.fitContent when stretchMain != null => math.max(
        _measureMain(item, _Room.minContent, crossKnown, roomCross, crossRoom),
        math.min(_measureMain(item, _Room.maxContent, crossKnown, roomCross, crossRoom), stretchMain),
      ),
      FlexKeyword.stretch when stretchMain != null => stretchMain,
      _ => null,
    };
    if (data.minKeyword case final k? when k != FlexKeyword.content) item.min = measured(k);
    if (data.maxKeyword case final k? when k != FlexKeyword.content) item.max = measured(k);

    // A. a definite basis is the base size; a percentage one against a
    // length the line does not have is the child's content instead
    // (css-flexbox-1 7.2.3).
    //
    // A KEYWORD BASIS stands in for the item's own length along the line
    // and leaves it out of the question: `min-content` and `max-content`
    // are the child's measurements, and `fit-content` and `stretch` read
    // the line's length less the margins where the line was handed one --
    // the content clamped into it, and all of it -- and are `content`
    // where it was not. `content` is what the child holds, through its
    // ratio where the line holds its depth (9.2 step 3 B) and measured
    // where it does not.
    //
    // A KEYWORD BESIDE A SHARE is the basis where the share is of no
    // length, and the share is where it is of one ([FlexCell.basisKeyword]).
    final statedBasis = _bounded(
      _resolve(data.basis, data.basisFraction, roomMain),
      (data.basisFloor, data.basisFloorFraction),
      (data.basisCap, data.basisCapFraction),
      roomMain,
    );
    final keyword = statedBasis == null ? data.basisKeyword : null;
    final double? keyed = switch (keyword) {
      FlexKeyword.minContent => transferred ?? _measureMain(item, _Room.minContent, crossKnown, roomCross, crossRoom),
      FlexKeyword.maxContent => transferred ?? _measureMain(item, _Room.maxContent, crossKnown, roomCross, crossRoom),
      FlexKeyword.fitContent when stretchMain != null =>
        transferred ??
            math.max(
              _measureMain(item, _Room.minContent, crossKnown, roomCross, crossRoom),
              math.min(_measureMain(item, _Room.maxContent, crossKnown, roomCross, crossRoom), stretchMain),
            ),
      FlexKeyword.stretch when stretchMain != null => stretchMain,
      _ => null,
    };
    final contentBasis = keyword == null
        ? null
        : keyed ??
              transferred ??
              _measureMain(
                item,
                room == _Room.minContent ? _Room.minContent : _Room.maxContent,
                crossKnown,
                roomCross,
                crossRoom,
              );
    item.basis = math.max(
      contentBasis ??
          statedBasis ??
          item.statedMain ??
          transferred ??
          _measureMain(
            item,
            room == _Room.minContent ? _Room.minContent : _Room.maxContent,
            crossKnown,
            roomCross,
            crossRoom,
          ),
      frameMain,
    );
    item.innerBasis = item.basis - frameMain;

    // §4.5: the automatic minimum. A floor the item states wins; an item
    // that clips has none at all (css-overflow-3: a scroll container's
    // content does not size it); otherwise it is the item's min-content
    // size, no bigger than the size it asked for or its own maximum.
    item.floor = math.max(
      item.min ??
          (data.clips
              ? 0
              : math.max(
                  math.min(
                    math.min(
                      _measureMain(item, _Room.minContent, crossKnown, roomCross, crossRoom),
                      item.statedMain ?? transferred ?? double.infinity,
                    ),
                    item.max ?? double.infinity,
                  ),
                  frameMain,
                )),
      math.max(transferredFloor ?? 0, math.max(stretchFloor ?? 0, statedFloor ?? 0)),
    );
    item.hypoMain = _clamped(item.basis, math.max(item.floor, frameMain), item.max);
    item.hypoOuterMain = item.hypoMain + _mainSum(data.margin);
  }

  /// How long the child wants to be along the line: its max-content size,
  /// or its min-content size, measured at the depth the line will hold it
  /// to (or in the room the line has, where it holds it to nothing).
  double _measureMain(_Item item, _Room room, double? crossKnown, double? roomCross, _Room crossRoom) {
    if (_row) {
      final at = crossKnown ?? double.infinity;
      return guardedSize(
        item.child,
        () => room == _Room.minContent ? item.child.getMinIntrinsicWidth(at) : item.child.getMaxIntrinsicWidth(at),
      );
    }
    // DOWN A COLUMN THE MAIN AXIS IS THE BLOCK ONE, and a block's height is
    // the height it comes to at the width it has -- min-content and
    // max-content are the same question. The width is the one the line
    // holds it to, or the one it comes to across the line ([_across]),
    // HELD BY THE ITEM'S OWN FLOOR AND CAP there as its depth is
    // ([_measureItemCross]): the width it is measured at is the width it is
    // laid out at. A music store's footer links are a wrapping list, `max-width:
    // 80%` and centred by its margins, down a 328 column: measured at the
    // 328 its words came to, it was three lines deep, 120, and laid out at
    // its 262.4 it wrapped to four, 166 in Chrome, over the box under it.
    final width =
        crossKnown ??
        math.max(_clamped(_across(item, roomCross, crossRoom), item.crossMin, item.crossMax), _crossSum(item.frame));
    return guardedSize(item.child, () {
      final dry = item.child.getDryLayout(BoxConstraints.tightFor(width: width)).height;
      return dry.isFinite ? dry : item.child.getMaxIntrinsicHeight(width);
    });
  }

  /// The smallest the item's content comes to across the line: its
  /// min-content size in the axis the ratio decides, at the length the line
  /// gave it along the other one.
  double _minContentCross(_Item item) => guardedSize(
    item.child,
    () => _row ? item.child.getMinIntrinsicHeight(item.mainSize) : item.child.getMinIntrinsicWidth(item.mainSize),
  );

  /// The length along the line a depth of [cross] makes at the item's
  /// ratio, which is always the child's WIDTH over its HEIGHT, whichever
  /// way the line runs -- of the box inside its margin, which the line
  /// sees on both sides ([FlexCell.marginFraction]).
  double _fromCross(_Item item, double cross) {
    final ratio = item.data.ratio!, out = item.ratioOut;
    final inner = math.max(cross - _crossSum(out), 0.0);
    return (_row ? inner * ratio : inner / ratio) + _mainSum(out);
  }

  /// The depth a length of [main] along the line makes at the item's ratio.
  double _fromMain(_Item item, double main) {
    final ratio = item.data.ratio!, out = item.ratioOut;
    final inner = math.max(main - _mainSum(out), 0.0);
    return (_row ? inner / ratio : inner * ratio) + _crossSum(out);
  }

  /// Whether the item is stretched across the line: it asked for it, states
  /// no depth of its own, and neither cross margin is `auto`. A share of a
  /// depth the line was not given is no length, but it is not `auto`
  /// either: the item keeps its content's depth (css-flexbox-1 9.4 step 11
  /// stretches an `auto` cross size only).
  bool _stretches(_Item item) =>
      _alignOf(item) == CrossAxisAlignment.stretch &&
      item.data.crossSize == null &&
      item.data.crossSizeFraction == null &&
      !_autoCrossStart(item.data.autoMargin) &&
      !_autoCrossEnd(item.data.autoMargin);

  /// How wide an item comes out across a column, [height] tall. Asked the
  /// line's min- or max-content width, it is the item's own; otherwise it
  /// is FIT-CONTENT in the room the line has (css-sizing-3 5.2.2): its
  /// content's width where that fits, the room where it does not, and never
  /// under its longest word -- a sentence in a column 358 wide wraps in 358,
  /// where its max-content width would stand out of both sides.
  double _across(_Item item, double? roomCross, _Room crossRoom, {double height = double.infinity}) {
    final child = item.child;
    return guardedSize(child, () {
      if (crossRoom == _Room.minContent) return child.getMinIntrinsicWidth(height);
      if (crossRoom == _Room.maxContent || roomCross == null) return child.getMaxIntrinsicWidth(height);
      final room = math.max(roomCross - _crossSum(item.margin), 0.0);
      final dry = child.getDryLayout(
        height.isFinite
            ? BoxConstraints(maxWidth: room, minHeight: height, maxHeight: height)
            : BoxConstraints(maxWidth: room),
      );
      return math.max(child.getMinIntrinsicWidth(height), dry.width);
    });
  }

  /// §9.4 step 7: how deep the item is at the main size the line gave it.
  void _measureItemCross(_Item item, {required double? roomCross, required _Room crossRoom}) {
    final data = item.data;
    final frameCross = _crossSum(item.frame);
    final stated = item.statedCross;
    final double inner;
    if (stated != null) {
      inner = math.max(_clamped(stated, item.crossMin, item.crossMax), frameCross);
    } else if (data.ratio != null && !_row && crossRoom != _Room.definite && item.statedMain == null) {
      // BUT A COLUMN ASKED HOW WIDE IT IS ASKS ITS ITEMS' CONTENT. A ratio
      // turns a DEFINITE size into the other axis (css-sizing-4 2.1), and
      // a column's min- and max-content widths are its items' (css-flexbox-1
      // 9.9.3): an item of no stated height has no height to turn while its
      // width is being worked out -- the one the line gave it here is its
      // basis, which is not a size of its own -- so its width there is its
      // content's, as an item with no ratio's is. Cards that are `flex:
      // 1 1 0%; aspect-ratio: 1 / 1; overflow: hidden` down a column that is
      // `align-items: center` in its own, as wide as its widest card's
      // words: the ratio of a 64 the basis and the padding made said 64,
      // and the cards came out the width of their longest word (96 where
      // Chrome draws 346) and as deep, 900 short down the page.
      inner = math.max(_across(item, roomCross, crossRoom), frameCross);
    } else if (data.ratio != null) {
      // ACROSS THE LINE THE RATIO ANSWERS, AND ITS ANSWER IS CLAMPED.
      // A transferred size is clamped by the item's own floor and cap
      // across the line (css-sizing-4 4.1), and the length it was
      // transferred FROM is not asked again: the bookshop's book covers
      // are 144 wide at 0.6445, which is 223.4 deep, and a
      // `max-height: 220px` leaves them 144 by 220.
      //
      // AND CONTENT THAT DOES NOT FIT THE RATIO GROWS THE BOX. css-sizing-4
      // 4.3 gives a box with a preferred ratio an automatic minimum in the
      // ratio-dependent axis equal to its MIN-CONTENT size, so the ratio's
      // extent is where the box starts and not where it ends -- a floor.
      // A box that clips has no such minimum (css-overflow-3), and neither
      // has one that states a floor itself. The floor is "capped by its
      // maximum size", the one the item states across the line: a floor
      // it writes beats its cap (css-sizing-3 5.1), the one its content
      // hands it does not. The bookshop's covers are `max-height: 220px`
      // round a picture that would be 225 deep at their 144, and Chrome
      // keeps them 220 (`fixtures/flex-ratio-depth-share` c1).
      final wanted = _clamped(_fromMain(item, item.mainSize), item.crossMin, item.crossMax);
      final content = data.clips || item.crossMin != null ? 0.0 : _minContentCross(item);
      final floor = item.crossMax == null ? content : math.min(content, item.crossMax!);
      inner = math.max(math.max(wanted, floor), frameCross);
    } else if (_row) {
      // The depth of a box held to a width is a dry layout at that width.
      // A dry run that comes back unbounded is no answer -- a child that
      // stretches across an axis nothing has bounded is as deep as the
      // offer -- and the intrinsic is the same question of the content
      // alone.
      final dry = guardedSize(item.child, () {
        final dry = item.child.getDryLayout(BoxConstraints.tightFor(width: item.mainSize)).height;
        return dry.isFinite ? dry : item.child.getMaxIntrinsicHeight(item.mainSize);
      });
      inner = math.max(dry, frameCross);
    } else {
      inner = math.max(_across(item, roomCross, crossRoom, height: item.mainSize), frameCross);
    }
    // AND WHATEVER THE DEPTH CAME FROM, THE ITEM'S OWN FLOOR AND CAP HOLD
    // IT. §9.4 step 7 lays the item out as a block at the length the line
    // gave it, and a block's own `min-height` and `max-height` hold the
    // block whatever its content comes to -- the line does not have to
    // stretch the item, or the item state its depth, for them to count.
    // The bookshop's picture is `max-height: 100%` of a cover 220 deep,
    // round an image 225 deep at its 144, and Chrome draws it 220
    // (`fixtures/flex-ratio-depth-share` c1). A size the item states, or
    // its ratio transfers, is held already, and a child that holds itself
    // to the same numbers is held to them twice, which is once.
    item.hypoCross = math.max(_clamped(inner, item.crossMin, item.crossMax), frameCross);
  }

  /// css-flexbox-1 §9.7: the used main size of each item. Growing, the room
  /// left over is shared by `flex-grow`; shrinking, the overflow is shared
  /// by `shrink × the item's own content box`; either way an item that hits
  /// its floor or its cap freezes there and the rest share what is left.
  void _resolveFlexibleLengths(List<_Item> items, double innerMain, double gaps) {
    var hypoTotal = 0.0;
    for (final item in items) {
      hypoTotal += item.hypoOuterMain;
    }
    final growing = gaps + hypoTotal < innerMain;
    final shrinking = gaps + hypoTotal > innerMain;

    for (final item in items) {
      item.mainSize = item.hypoMain;
      item.frozen =
          (!growing && !shrinking) ||
          (item.data.grow == 0 && item.data.shrink == 0) ||
          (growing && item.basis > item.hypoMain) ||
          (shrinking && item.basis < item.hypoMain);
    }
    if (!growing && !shrinking) return;

    double usedSpace() {
      var sum = gaps;
      for (final item in items) {
        sum += (item.frozen ? item.mainSize : item.basis) + _mainSum(item.margin);
      }
      return sum;
    }

    final initialFree = innerMain - usedSpace();
    while (true) {
      if (items.every((item) => item.frozen)) break;
      final unfrozen = [
        for (final item in items)
          if (!item.frozen) item,
      ];
      var sumGrow = 0.0, sumShrink = 0.0;
      for (final item in unfrozen) {
        sumGrow += item.data.grow;
        sumShrink += item.data.shrink;
      }
      final remaining = innerMain - usedSpace();
      // A line whose flex factors add up to less than one shares only that
      // much of the room (§9.7 step 4b): that share of the INITIAL free
      // space, where the gaps are taken off already ([usedSpace]). Taken
      // off again, two `flex: .25 1 0` items 10 apart in 100 were 17.5 wide
      // where Chrome makes them 22.5 -- a quarter of the 90 between them
      // each.
      final double free;
      if (growing && sumGrow < 1) {
        free = math.min(initialFree * sumGrow, remaining);
      } else if (shrinking && sumShrink < 1) {
        free = math.max(initialFree * sumShrink, remaining);
      } else {
        free = remaining;
      }

      if (free.isFinite && free != 0) {
        if (growing && sumGrow > 0) {
          for (final item in unfrozen) {
            item.mainSize = item.basis + free * (item.data.grow / sumGrow);
          }
        } else if (shrinking && sumShrink > 0) {
          var scaled = 0.0;
          for (final item in unfrozen) {
            scaled += item.innerBasis * item.data.shrink;
          }
          if (scaled > 0) {
            for (final item in unfrozen) {
              item.mainSize = item.basis + free * (item.innerBasis * item.data.shrink / scaled);
            }
          }
        }
      }

      var violation = 0.0;
      for (final item in unfrozen) {
        final clamped = math.max(_clamped(item.mainSize, item.floor, item.max), 0.0);
        item.violation = clamped - item.mainSize;
        item.mainSize = clamped;
        violation += item.violation;
      }
      for (final item in unfrozen) {
        item.frozen = violation > 0
            ? item.violation > 0
            : violation < 0
            ? item.violation < 0
            : true;
      }
    }
  }

  /// css-flexbox-1 §9.9.1: what each item contributes to the line's own
  /// min- or max-content size -- its content contribution, plus its flex
  /// factor times the fraction that contribution needs. The spec scales the
  /// whole line by its largest fraction; neither Chrome nor Firefox do, so
  /// neither does this.
  double _contributions(List<_Item> items, _Room room, double? roomCross, _Room crossRoom, {bool widest = false}) {
    var total = 0.0;
    for (final item in items) {
      final (basis, flexed) = _contribution(item, room, roomCross, crossRoom);
      total = widest ? math.max(total, basis + flexed) : total + basis + flexed;
    }
    return total;
  }

  /// One item's part of [_contributions]: its base size, and what its flex
  /// factor adds to it or takes from it.
  (double, double) _contribution(_Item item, _Room room, double? roomCross, _Room crossRoom) {
    // DOWN A COLUMN AN ITEM CONTRIBUTES ITS HYPOTHETICAL LENGTH: its base
    // size held by its own floor and cap, and nothing the item states
    // beside them. A column whose height nobody stated is as tall as the
    // formatting context it sits in makes it (css-flexbox-1 9.3 step 4),
    // and Chrome lays a column's block out at the sum of its items'
    // HYPOTHETICAL outer main sizes and the gaps between them (Blink's
    // `FlexLayoutAlgorithm::MainAxisContentExtent`), not at 9.9.1's
    // contributions -- where a `height` beside a basis of the item's own
    // counted. A docs site's code sandboxes are each a column of
    // `max-height: 406px` round a body of `flex: 1; min-height: 0; height:
    // 60px`: a `0%` basis of a column with no height is the body's
    // content, which is nothing, and Chrome draws the column and its body
    // 0 deep, where counting the 60 made both 60 and put everything under
    // them 60 low (`fixtures/flex-wrap-runs-whole-frame` n2). A sports shop's
    // footer row, `flex: 1 0 0px` round a 21px line, is 21 in Chrome at a
    // `height: 40px` too: its floor, not its 40
    // (`fixtures/flex-column-basis-zero-floor` p5). NOT where the stated
    // height IS the basis (`height: 60px` alone is 60), nor where the
    // content holds the item: a block's automatic floor down a column is
    // its content's height (4.5), so `flex: 1 1 0px` round 30 of content
    // is 30, and only a floor the page writes lets it be less.
    if (!_row) return (item.basis, item.hypoOuterMain - item.basis);
    final data = item.data;
    final preferred = item.statedMain;
    // An item that cannot shrink is never counted below its base size,
    // and one that cannot grow never above it (css-flexbox-2 9.10.3);
    // the item's own minimum and maximum come after, so the floor
    // outlives the cap.
    final min = item.min, max = item.max;
    final basisMin = data.shrink == 0 ? _min(item.basis, max) : null;
    final basisMax = data.grow == 0 ? item.basis : null;
    final floor = math.max((min != null ? math.max(min, basisMin ?? min) : basisMin) ?? item.floor, item.floor);
    final cap = (max != null ? math.min(max, basisMax ?? max) : basisMax) ?? double.infinity;

    final double contribution;
    if (preferred != null && (cap <= floor || cap <= preferred)) {
      // The clamps settle it: nothing needs measuring.
      contribution = math.max(math.min(preferred, cap), floor) + _mainSum(data.margin);
    } else if (cap <= floor) {
      contribution = floor + _mainSum(data.margin);
    } else if (data.clips) {
      // A clipping item asks for its base size and measures nothing --
      // but a cap is a cap: the line never needs more room than the item
      // may take (a ratio can put a base size above one).
      contribution = _clamped(item.basis, min, max) + _mainSum(data.margin);
    } else {
      final crossKnown =
          item.statedCross ??
          (_stretches(item) && roomCross != null ? math.max(roomCross - _crossSum(item.margin), 0) : null);
      // A ratio answers here too: what a stretched item contributes to
      // the line's own length is the depth it will have, turned round
      // (css-sizing-4 4.1), and not its content -- an empty
      // `aspect-ratio: 2` item 100 deep is 200 long, where measuring it
      // makes it nothing at all.
      final transferred = data.ratio == null || crossKnown == null ? null : _fromCross(item, crossKnown);
      final inner = preferred != null
          ? math.max(preferred, _mainSum(item.frame))
          : transferred ?? _measureMain(item, room, crossKnown, roomCross, crossRoom);
      contribution = _clamped(inner + _mainSum(data.margin), min, max);
    }

    final diff = contribution - item.basis;
    final double fraction;
    if (diff > 0) {
      fraction = diff / math.max(1, data.grow);
    } else if (diff < 0) {
      final scaled = math.max(1, data.shrink) * item.innerBasis;
      fraction = scaled == 0 ? 0 : diff / scaled;
    } else {
      fraction = 0;
    }
    final double flexed;
    if (fraction > 0) {
      flexed = math.max(1, data.grow) * fraction;
    } else if (fraction < 0) {
      final scaled = math.max(1, data.shrink) * item.innerBasis;
      flexed = scaled == 0 ? 0 : scaled * fraction;
    } else {
      flexed = 0;
    }
    return (item.basis, flexed);
  }

  CrossAxisAlignment _alignOf(_Item item) => item.data.align ?? _crossAxisAlignment;

  /// Whether the item takes part in baseline alignment: it asked for it, and
  /// neither of its cross margins is `auto` (css-flexbox-1 §baseline
  /// participation).
  bool _onBaseline(FlexLineParentData data) =>
      (data.align ?? _crossAxisAlignment) == CrossAxisAlignment.baseline &&
      !_autoCrossStart(data.autoMargin) &&
      !_autoCrossEnd(data.autoMargin);

  /// Where an item's text sits from its own top, [depth] deep: its first
  /// line's baseline, or -- holding no text -- its bottom edge (css-flexbox-1
  /// §8.5 synthesizes one from the border box). An item that clips is a
  /// scroll container, whose baseline stays inside it (csswg-drafts#7660).
  double _synthesized(double? text, double depth, FlexLineParentData data) {
    final b = text ?? depth;
    return data.clips && _row ? b.clamp(0.0, depth) : b;
  }

  /// The item the line's own baseline comes from (css-flexbox-1 §8.5): in a
  /// row the first one lined up on a baseline, else the first; down a
  /// column, the first. Where the line wraps it is read from the FIRST RUN
  /// alone -- §8.5 takes the box's first baseline from its first flex line,
  /// so an `align-self: baseline` down on the second line is none of the
  /// box's business.
  T? _baselineItem<T>(Iterable<T> items, FlexLineParentData Function(T) data) {
    if (_row) {
      for (final item in items) {
        if (_onBaseline(data(item))) return item;
      }
    }
    return items.isEmpty ? null : items.first;
  }

  /// A length that is pixels, a share of [room], or both (`calc()`); a
  /// share of no room is no length.
  static double? _resolve(double? px, double? fraction, double? room) =>
      fraction == null ? px : (room == null ? null : (px ?? 0) + fraction * room);

  /// A basis [v] between a floor and a ceiling of its own, each pixels and
  /// a share of [room] ([FlexCell.basisCap]): the floor wins, as in
  /// `clamp()`. A bound that is a share of no room makes the basis none.
  static double? _bounded(double? v, (double?, double?) floor, (double?, double?) cap, double? room) {
    final lo = _resolve(floor.$1, floor.$2, room), hi = _resolve(cap.$1, cap.$2, room);
    if (v == null || floor.$2 != null && lo == null || cap.$2 != null && hi == null) return null;
    final capped = hi == null ? v : math.min(v, hi);
    return lo == null ? capped : math.max(lo, capped);
  }

  /// A floor under a ceiling of its own: `min-width: min(100%, 72px)`
  /// (`FlexCell.minCap`). A ceiling that is a share of a room the line
  /// does not have is no ceiling, and the floor stands as it is.
  static double? _floor(double? v, double? cap) => v == null || cap == null ? v : math.min(v, cap);

  /// Whether a row's items state a share of its width: a length along it
  /// ([_sharesAlong]), a percentage frame ([FlexCell.frameFraction]), or
  /// a gap between them ([FlexLine.spacingFraction]).
  bool get _sharesWidth {
    if (_spacingFraction != null) return true;
    for (var child = firstChild; child != null;) {
      final data = child.parentData! as FlexLineParentData;
      if (_sharesAlong(data) || data.frameFraction != EdgeInsets.zero) return true;
      child = data.nextSibling;
    }
    return false;
  }

  /// Whether the item states a share of the line's length, which a row
  /// whose length its content settles reads a second time.
  static bool _sharesAlong(FlexLineParentData data) =>
      data.basisFraction != null ||
      data.basisCapFraction != null ||
      data.basisFloorFraction != null ||
      data.mainSizeFraction != null ||
      data.minFraction != null ||
      data.minCapFraction != null ||
      data.maxFraction != null;

  /// [v] held between a floor and a ceiling THE FLOOR WINS: a minimum
  /// larger than the maximum is still the size (css-sizing-3 5.1), and an
  /// item whose longest word is wider than its `max-width` is that wide.
  static double _clamped(double v, double? min, double? max) {
    var out = v;
    if (max != null && out > max) out = max;
    if (min != null && out < min) out = min;
    return out;
  }

  static double _min(double a, double? b) => b == null ? a : math.min(a, b);

  EdgeInsets _withMain(EdgeInsets e, {double? start, double? end}) =>
      _row ? e.copyWith(left: start, right: end) : e.copyWith(top: start, bottom: end);

  EdgeInsets _withCross(EdgeInsets e, {double? start, double? end}) =>
      _row ? e.copyWith(top: start, bottom: end) : e.copyWith(left: start, right: end);

  /// css-align-3 5.3: a distribution keyword with one item, or with no room
  /// to distribute, falls back -- `space-between` to the flex start,
  /// `space-around` and `space-evenly` to a safe centre -- and a safe
  /// alignment with no room left ([safeMainAxis]) is the START OF THE AXIS:
  /// one item too tall for its column stays at the top rather than hanging
  /// out of both ends as `center` does. [mode] and the answer are in the
  /// terms the line is walked in, left to right or top to bottom; the flex
  /// start is its far end where the items run the other way ([_flipMain]),
  /// and the axis start only where the axis does ([_mainBack]).
  ///
  /// `space-between` PACKS AT THE FLEX START even where the line overflows:
  /// Chrome does not make that fallback safe, so a `row-reverse` line too
  /// long for its box stands on the right and runs out of the left
  /// (`fixtures/flex-reverse-hang` r6), where `space-around` runs out of
  /// the right (r4).
  MainAxisAlignment _fallback(double free, int count, MainAxisAlignment mode) {
    final axisStart = _mainBack ? MainAxisAlignment.end : MainAxisAlignment.start;
    if (free <= 0 && _safeMainAxis) return axisStart;
    if (count > 1 && free > 0) return mode;
    return switch (mode) {
      MainAxisAlignment.spaceBetween => _flipMain ? MainAxisAlignment.end : MainAxisAlignment.start,
      MainAxisAlignment.spaceAround || MainAxisAlignment.spaceEvenly => free > 0 ? MainAxisAlignment.center : axisStart,
      _ => mode,
    };
  }

  /// How far the item at [index] sits from where the one before it ended.
  /// The first item takes the packing offset; the rest take their share of
  /// what `space-*` spreads out, which is nothing where the line overflows.
  double _alignmentOffset(double free, int count, MainAxisAlignment mode, bool first) {
    final gap = _gap;
    if (first) {
      return switch (mode) {
        MainAxisAlignment.start => 0,
        MainAxisAlignment.end => free,
        MainAxisAlignment.center => free / 2,
        MainAxisAlignment.spaceBetween => 0,
        MainAxisAlignment.spaceAround => free >= 0 ? (free / count) / 2 : free / 2,
        MainAxisAlignment.spaceEvenly => free >= 0 ? free / (count + 1) : free / 2,
      };
    }
    final room = math.max(free, 0);
    return gap +
        switch (mode) {
          MainAxisAlignment.spaceBetween => room / (count - 1),
          MainAxisAlignment.spaceAround => room / count,
          MainAxisAlignment.spaceEvenly => room / (count + 1),
          _ => 0.0,
        };
  }

  // --- the RenderBox protocol ---------------------------------------------------

  /// The line as [performLayout] last placed it, which is where its
  /// baseline is read from.
  _Line? _placed;

  @override
  void performLayout() {
    final line = _layOut(constraints, place: true);
    _placed = line;
    size = line.size;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _layOut(constraints, place: false).size;

  @override
  double computeMinIntrinsicWidth(double height) => _intrinsic(height, _Room.minContent, Axis.horizontal);

  @override
  double computeMaxIntrinsicWidth(double height) => _intrinsic(height, _Room.maxContent, Axis.horizontal);

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsic(width, _Room.minContent, Axis.vertical);

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsic(width, _Room.maxContent, Axis.vertical);

  /// The line's own min- or max-content size along [axis], the other axis
  /// offered [extent]. ALONG the line that is §9.9.1's sum; ACROSS it, it is
  /// the line laid out in the room there is and asked how deep it came out
  /// -- the same box, measured.
  double _intrinsic(double extent, _Room room, Axis axis) {
    final along = (axis == Axis.horizontal) == _row;
    // The other axis's extent is room the items are measured in, not a size
    // the line is held to: `computeMaxIntrinsicWidth(height)` asks how wide
    // the line wants to be when it is OFFERED that height.
    //
    // EXCEPT A COLUMN ASKED ITS HEIGHT, which is its height AT that width
    // (`getMaxIntrinsicHeight(width)`): the width is the box's own, and
    // the shares of it its items state -- `max-width: 80%`, a percentage
    // frame -- are shares of a length the line has (css-flexbox-1 9.8), as
    // they are when it is laid out there. Left loose, they were shares of
    // nothing: the music store's footer, under an `IntrinsicHeight`, measured its
    // `max-width: 80%` link list at the column's whole 328, three lines
    // where the layout then drew four, and stood 46 short.
    //
    // AND A ROW WHOSE ITEMS STATE SHARES OF ITS WIDTH ([_sharesWidth]): the
    // width is the row's own for the same reason, and a `width: 100%` item
    // is all of it. Left loose, the row was its content's width, and the
    // share a share of that: a news front's grid of a 16/9 picture beside
    // its caption came to the caption's max-content width, where its `1fr`
    // picture column was nothing, and answered the caption's 171 where it
    // drew 362 -- and the `IntrinsicHeight` above it the next row's top 64
    // too high. A row of items that state no share stays loose: it is its
    // content's width wherever it is not handed one, and what it holds is
    // measured there.
    final constraints = axis == Axis.horizontal
        ? BoxConstraints(maxHeight: extent)
        : extent.isFinite && (!_row || _sharesWidth)
        ? BoxConstraints.tightFor(width: extent)
        : BoxConstraints(maxWidth: extent);
    // Across the line, the items are laid out along it in the room that
    // extent gives (a row asked its height at a width wraps in that width),
    // and it is ACROSS that the question is min- or max-content: a column's
    // min-content width is its widest item's longest word.
    final line = _layOut(
      constraints,
      place: false,
      mainRoom: along ? room : _Room.definite,
      crossRoom: along ? _Room.definite : room,
    );
    return along ? _main(line.size) : _cross(line.size);
  }

  /// The line's baseline is one item's ([_baselineItem]): where that item's
  /// text sits, or its bottom edge where it holds none -- so a line of
  /// boxes with no text still has one, as a flex container does. A line
  /// with no items has none. How deep the item is comes from the line as it
  /// was laid out: a child's own `size` is its parent's to read, and only
  /// while the parent lays it out -- not when the box laying the line out
  /// (a `Row`, a paragraph) asks where its baseline is.
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final item = _baselineItem(_placed?.first ?? const <_Item>[], (i) => i.data);
    if (item == null) return null;
    final depth = _row ? item.crossSize : item.mainSize;
    return item.data.offset.dy + _synthesized(item.child.getDistanceToActualBaseline(baseline), depth, item.data);
  }

  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
    final line = _layOut(constraints, place: false);
    final item = _baselineItem(line.first, (i) => i.data);
    if (item == null) return null;
    final text = dryBaselineOf(item.child, BoxConstraints.tight(_size(item.mainSize, item.crossSize)), baseline);
    final depth = _row ? item.crossSize : item.mainSize;
    return (_row ? item.offsetCross : item.offsetMain) + _synthesized(text, depth, item.data);
  }

  /// The children in paint order: by [FlexLineParentData.z], ties in
  /// document order. A line with no `z` anywhere paints the way it is
  /// written, which is what CSS asks for (css-flexbox-1 5.4).
  @override
  List<RenderBox> get paintOrder => _painted();

  List<RenderBox> _painted() {
    final kids = <(int, int, RenderBox)>[];
    var i = 0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      kids.add(((child.parentData! as FlexLineParentData).z, i++, child));
    }
    kids.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
    return [for (final k in kids) k.$3];
  }

  bool get _stacked {
    for (var child = firstChild; child != null; child = childAfter(child)) {
      if ((child.parentData! as FlexLineParentData).z != 0) return true;
    }
    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_stacked) return defaultPaint(context, offset);
    for (final child in _painted()) {
      context.paintChild(child, (child.parentData! as FlexLineParentData).offset + offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (!_stacked) return defaultHitTestChildren(result, position: position);
    for (final child in _painted().reversed) {
      final data = child.parentData! as FlexLineParentData;
      final hit = result.addWithPaintOffset(
        offset: data.offset,
        position: position,
        hitTest: (r, p) => child.hitTest(r, position: p),
      );
      if (hit) return true;
    }
    return false;
  }
}

/// The line as laid out: its size, and its items where they ended up.
class _Line {
  _Line(this.size, this.items, this.first);
  final Size size;
  final List<_Item> items;

  /// The items of the FIRST run, which is every item where the line does
  /// not wrap. The box's baseline is read from these alone.
  final List<_Item> first;
}
