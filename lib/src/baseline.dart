/// A baseline for a box that has none of its own.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';
import 'inline_flow.dart';
import 'linebox.dart';

/// A box whose baseline, where nothing inside it has one, is its bottom
/// edge.
///
/// A box that takes part in baseline alignment without a baseline of its
/// own has one synthesised from its border box, the alphabetic baseline
/// on the bottom edge (css-align-3 9.1). A flex container's baseline is
/// its first item's (css-flexbox-1 8.5), so an `inline-flex` icon button
/// stands on the line by the bottom of its ICON, not of the button: a
/// 20px icon centred in a 40px pill sits 30 above the baseline and 10
/// below it. A Flutter box with no text inside answers no baseline at all,
/// and the paragraph around it stands the whole pill on its bottom edge.
/// Wrapped around that first item, this answers for it.
class EdgeBaseline extends SingleChildRenderObjectWidget {
  const EdgeBaseline({super.key, this.only = false, super.child});

  /// Whether the edge is the ONLY answer: a box under layout containment
  /// has no baseline of its own at all (css-contain-2 2.2), so what is
  /// inside it is not asked. Without this the edge is a fallback, for a
  /// box that simply has nothing to give one.
  final bool only;

  @override
  RenderEdgeBaseline createRenderObject(BuildContext context) => RenderEdgeBaseline()..only = only;

  @override
  void updateRenderObject(BuildContext context, RenderEdgeBaseline renderObject) {
    renderObject.only = only;
  }
}

/// The render object behind [EdgeBaseline].
class RenderEdgeBaseline extends RenderProxyBox with DryLastBaseline, AsksGuarded, PassesBaseline, KeptUnderHatch {
  RenderEdgeBaseline([super.child]);

  bool _only = false;

  /// See [EdgeBaseline.only].
  set only(bool value) {
    if (_only == value) return;
    _only = value;
    markNeedsLayout();
  }

  @override
  bool get passes => !_only;

  @override
  bool get standsOnEdge => true;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final b = _only ? null : super.computeDistanceToActualBaseline(baseline);
    if (b != null) return b;
    // NOT `size`. An empty atomic inline stands on its BOTTOM MARGIN EDGE
    // (CSS 2.1 10.8.1), which is this box's height -- but a paragraph
    // measuring a placeholder asks for the baseline of every box under it,
    // and a box may only read its own `size` while ITS parent is the one
    // laying out. The dry answer is the same number and is always in
    // scope.
    return hasSize && (debugDoingThisLayout || debugDoingThisResize)
        ? size.height
        : guardedSize(this, () => getDryLayout(constraints)).height;
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) =>
      _dry(constraints, baseline, dryBaselineOf);

  /// An inline-block's baseline is its last line's, and a box with no line
  /// at all stands on its bottom edge either way (CSS 2.1 10.8.1) -- so
  /// the last-baseline question reaches the same answer through the same
  /// fallback.
  @override
  double? dryLastBaseline(BoxConstraints constraints, TextBaseline baseline) =>
      _dry(constraints, baseline, dryLastBaselineOf);

  /// AN EDGE AT NO DEPTH IS NO BASELINE. Asked under a height with no
  /// bound, a box that fills what it is handed (`height: double.infinity`)
  /// has its bottom edge at infinity -- and a flex line asks each item's
  /// baseline so, before it has a depth to hand, to sum the ascents and
  /// descents its intrinsic depth is (`RenderFlex`, css-flexbox-1 9.4 step
  /// 8): the line, the `IntrinsicHeight` round it and every box measuring
  /// them came out unbounded. Without a baseline the box stands at the
  /// line's start, which is where a box alone on a line stands either way
  /// (8.3); laid out in the depth the line comes to, it has its edge back.
  /// A recipe site's pages head with a `min-height: 280px` row aligned
  /// `baseline` round an empty block of `height: 100%`, and threw "A Stack
  /// requires bounded constraints" on every recipe route
  /// (`test/edge_baseline_unbounded_test.dart`). NEGATIVE: under a height
  /// with a bound, the edge answers as before.
  double? _dry(
    BoxConstraints constraints,
    TextBaseline baseline,
    double? Function(RenderBox, BoxConstraints, TextBaseline) of,
  ) {
    final child = this.child;
    if (child != null && !_only) {
      if (of(child, constraints, baseline) case final b?) return b;
    }
    final edge = child == null
        ? constraints.smallest.height
        : guardedSize(child, () => child.getDryLayout(constraints)).height;
    return edge.isFinite ? edge : null;
  }
}

/// A box on the line by its MIDDLE: `vertical-align: middle`.
///
/// CSS 2.1 10.8.1 aligns the vertical midpoint of the box with the
/// baseline of the parent box plus half the x-height of the parent. As a
/// baseline of the box's own, that is half its height and [over] down from
/// its top, whatever is inside it -- which a paragraph standing its
/// placeholders on the baseline stands where `middle` puts it, for a box
/// whose height only layout knows. A Japanese news site's section link is an
/// `inline-block` at `middle` in a line beside a float
/// (`fixtures/float-widget-nested-align`).
class MiddleBaseline extends SingleChildRenderObjectWidget {
  const MiddleBaseline({super.key, required this.over, super.child});

  /// How far over the parent's baseline the box's middle stands: half the
  /// parent's x-height.
  final double over;

  @override
  RenderMiddleBaseline createRenderObject(BuildContext context) => RenderMiddleBaseline()..over = over;

  @override
  void updateRenderObject(BuildContext context, RenderMiddleBaseline renderObject) {
    renderObject.over = over;
  }
}

/// The render object behind [MiddleBaseline].
class RenderMiddleBaseline extends RenderProxyBox with DryLastBaseline, AsksGuarded, KeptUnderHatch {
  RenderMiddleBaseline([super.child]);

  double _over = 0;

  /// See [MiddleBaseline.over].
  set over(double value) {
    if (_over == value) return;
    _over = value;
    markNeedsLayout();
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    // The dry height, as [RenderEdgeBaseline] reads it: a paragraph
    // measuring a placeholder asks before this box's parent lays it out.
    final h = hasSize && (debugDoingThisLayout || debugDoingThisResize)
        ? size.height
        : guardedSize(this, () => getDryLayout(constraints)).height;
    return h / 2 + _over;
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) =>
      guardedSize(this, () => getDryLayout(constraints)).height / 2 + _over;

  @override
  double? dryLastBaseline(BoxConstraints constraints, TextBaseline baseline) =>
      computeDryBaseline(constraints, baseline);
}

/// A box on the line by its TOP: `vertical-align: text-top`.
///
/// CSS 2.1 10.8.1 aligns the top of the box with the top of the parent's
/// content area, the parent's ascent over the baseline. As a baseline of
/// the box's own, that is [at] down from its top whatever its height and
/// whatever is inside it -- which a paragraph standing its placeholders on
/// the baseline stands where `text-top` puts it, for a box whose height
/// only layout knows: an `inline-block` of words
/// (`fixtures/valign-text-top-words`, `fixtures/valign-text-bottom-words`
/// n5).
class TopBaseline extends SingleChildRenderObjectWidget {
  const TopBaseline({super.key, required this.at, super.child});

  /// How far over the parent's baseline the box's top stands: the parent's
  /// ascent.
  final double at;

  @override
  RenderTopBaseline createRenderObject(BuildContext context) => RenderTopBaseline()..at = at;

  @override
  void updateRenderObject(BuildContext context, RenderTopBaseline renderObject) {
    renderObject.at = at;
  }
}

/// The render object behind [TopBaseline].
class RenderTopBaseline extends RenderProxyBox with DryLastBaseline, AsksGuarded, KeptUnderHatch {
  RenderTopBaseline([super.child]);

  double _at = 0;

  /// See [TopBaseline.at].
  set at(double value) {
    if (_at == value) return;
    _at = value;
    markNeedsLayout();
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => _at;

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) => _at;

  @override
  double? dryLastBaseline(BoxConstraints constraints, TextBaseline baseline) => _at;
}

/// A box that stands on the baseline of its LAST line.
///
/// An inline-block's baseline is the baseline of the last line box in it
/// (CSS 2.1 10.8.1), and every Flutter box answers with its first: a
/// `Column` asks its first child, a paragraph its first line. Two stacked
/// 20px lines on a 25px line stood three pixels low, on the top one.
class LastBaseline extends SingleChildRenderObjectWidget {
  const LastBaseline({super.key, super.child});

  @override
  RenderLastBaseline createRenderObject(BuildContext context) => RenderLastBaseline();
}

/// The render object behind [LastBaseline].
class RenderLastBaseline extends RenderProxyBox with AsksGuarded, PassesBaseline, KeptUnderHatch {
  RenderLastBaseline([super.child]);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final child = this.child;
    return child == null ? null : lastBaselineOf(child, baseline);
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) {
    final child = this.child;
    return child == null ? null : dryLastBaselineOf(child, constraints, baseline);
  }

  /// The lowest baseline of an in-flow line in [box], from its top: in a
  /// paragraph its last line's, and in a box of boxes the lowest of theirs.
  /// A positioned child is out of the flow and has no say.
  ///
  /// A paragraph keeps its lines to itself, so its last line is found by
  /// the caret at the end of its text, and stood on as the first line is:
  /// under a forced strut, which is how a line of lowered text is set,
  /// every line puts its baseline the same distance down.
  static double? lastBaselineOf(RenderBox box, TextBaseline baseline) {
    // AN IGNORED BASELINE IS NONE: what stands in an `IgnoreBaseline` has
    // no say in a baseline above it, here as in Flutter's own boxes. A news site's
    // strip links stand an svg icon in one, and the walk that went past it
    // asked the icon.
    if (box is RenderIgnoreBaseline) return null;
    // NOR HAS A BOX NOT LAID OUT YET: a subtree its own relayout boundary
    // lays out later in the frame -- the news site's icon, its picture just arrived
    // -- has no line to stand on, and asked one it throws (it has no
    // constraints).
    if (!box.hasSize) return null;
    // THE WALK READS BOXES IT IS NOT THE PARENT OF, and asks each the way a
    // parent does, through its cache: a box asked its baseline that is laid
    // out again lays out again what asked it, past a relayout boundary
    // ([RenderBox.markNeedsLayout]). Read around the cache, a line under a
    // boundary whose text changed was laid out after the block standing on
    // it, so the walk read it stale -- the news site's section frames at 360, a
    // paragraph asked before it was laid out.
    final first = box.getDistanceToActualBaseline(baseline);
    if (box is RenderEdgeBaseline) return first;
    // An inline formatting context knows its own last line.
    if (box is RenderInlineFlow) return box.lastBaseline;
    // A flex container gives one baseline, its first line's, and holds no
    // line box of its own for the walk below to find a lower one in.
    if (box is OneBaseline) return first;
    // A LINE BOX PAINTS ITS PARAGRAPH where CSS puts the baseline, not
    // where Skia rounded it to, and keeps that drop out of the parent data
    // the walk below reads: a web portal's 20.5px inline-block links answered 14 for
    // a line whose baseline is 15 -- 15 asked dry -- and the list rows
    // round them came out 21 (`fixtures/inline-block-link-row`).
    if (box is RenderLineBox) {
      // Lines read off the boxes on them: where CSS puts the last one.
      if (box.below case final below?) return first == null ? null : first + below;
      final child = box.child;
      final b = child == null ? null : lastBaselineOf(child, baseline);
      return b == null ? null : b + box.drop;
    }
    if (box is RenderParagraph) {
      if (first == null) return null;
      final end = TextPosition(offset: box.text.toPlainText(includeSemanticsLabels: false).length);
      final down =
          box.getOffsetForCaret(end, Rect.zero).dy - box.getOffsetForCaret(const TextPosition(offset: 0), Rect.zero).dy;
      return first + down;
    }
    double? lowest;
    var any = false;
    box.visitChildren((c) {
      if (c is! RenderBox) return;
      any = true;
      final data = c.parentData;
      if (data is StackParentData && data.isPositioned) return;
      final b = lastBaselineOf(c, baseline);
      if (b == null) return;
      final at = (data is BoxParentData ? data.offset.dy : 0.0) + b;
      if (lowest == null || at > lowest!) lowest = at;
    });
    return any ? lowest : first;
  }
}
