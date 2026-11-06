/// An inline box's background and border round what it holds on its line.
library;

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';

/// The frame an INLINE box paints round its content, where the content is
/// one piece no line breaks -- a word, or an atomic inline -- so the whole
/// box is on one line: a `<span>` chip, a padded label, a bordered badge
/// round an icon.
///
/// CSS lays such a box out ACROSS and DOWN differently (CSS 2.1 8.1,
/// 10.3.1, 10.6.1, 10.8.1):
///
/// - Across, its margin, border and padding are room before its first
///   letter and after its last: [margin] outside, [insets] (border and
///   padding) inside it, each side on its own.
/// - Down, they take no room at all: the line is as tall as the
///   `line-height`s on it say, and the padding and border stand out over
///   and under the CONTENT AREA -- the font's ascent above the baseline
///   and its descent below it, [ascent] and [descent] -- over whatever is
///   above and below.
/// - The [decoration] -- the background and the border -- fills the
///   border box that makes (css-backgrounds-3 3.7, `border-box`).
///
/// The child is the content as a line of its own, the width it takes on
/// the line; this box is that and the room across, exactly as tall as the
/// child, and answers the child's baseline -- so a `WidgetSpan` standing
/// it on the baseline puts the content where the line puts the box's text,
/// and the paragraph's own line height is whatever the child's is.
class InlineFrame extends SingleChildRenderObjectWidget {
  const InlineFrame({
    super.key,
    required this.decoration,
    this.insets = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    required this.ascent,
    required this.descent,
    super.child,
  });

  /// The background and the border, painted over the border box.
  final Decoration decoration;

  /// The border and the padding: room across, and how far the border box
  /// stands out from the content area down.
  final EdgeInsets insets;

  /// The margin across; room outside the border box that paints nothing.
  /// Only its left and right are read.
  final EdgeInsets margin;

  /// The content area: how far it reaches above the child's baseline and
  /// below it.
  final double ascent, descent;

  @override
  RenderInlineFrame createRenderObject(BuildContext context) => RenderInlineFrame(
    decoration: decoration,
    insets: insets,
    margin: margin,
    ascent: ascent,
    descent: descent,
    textDirection: Directionality.maybeOf(context),
  );

  @override
  void updateRenderObject(BuildContext context, RenderInlineFrame renderObject) => renderObject
    ..decoration = decoration
    ..insets = insets
    ..margin = margin
    ..ascent = ascent
    ..descent = descent
    ..textDirection = Directionality.maybeOf(context);
}

/// The render object behind [InlineFrame].
class RenderInlineFrame extends RenderShiftedBox with AsksGuarded, KeptUnderHatch {
  RenderInlineFrame({
    required Decoration decoration,
    EdgeInsets insets = EdgeInsets.zero,
    EdgeInsets margin = EdgeInsets.zero,
    required double ascent,
    required double descent,
    TextDirection? textDirection,
    RenderBox? child,
  }) : _decoration = decoration,
       _insets = insets,
       _margin = margin,
       _ascent = ascent,
       _descent = descent,
       _textDirection = textDirection,
       super(child);

  Decoration _decoration;
  Decoration get decoration => _decoration;
  set decoration(Decoration v) {
    if (v == _decoration) return;
    _painter?.dispose();
    _painter = null;
    _decoration = v;
    markNeedsPaint();
  }

  EdgeInsets _insets;
  EdgeInsets get insets => _insets;
  set insets(EdgeInsets v) {
    if (v == _insets) return;
    _insets = v;
    markNeedsLayout();
  }

  EdgeInsets _margin;
  EdgeInsets get margin => _margin;
  set margin(EdgeInsets v) {
    if (v == _margin) return;
    _margin = v;
    markNeedsLayout();
  }

  double _ascent;
  double get ascent => _ascent;
  set ascent(double v) {
    if (v == _ascent) return;
    _ascent = v;
    markNeedsPaint();
  }

  double _descent;
  double get descent => _descent;
  set descent(double v) {
    if (v == _descent) return;
    _descent = v;
    markNeedsPaint();
  }

  TextDirection? _textDirection;
  TextDirection? get textDirection => _textDirection;
  set textDirection(TextDirection? v) {
    if (v == _textDirection) return;
    _textDirection = v;
    markNeedsPaint();
  }

  BoxPainter? _painter;

  /// Where the child's baseline was at the last layout, from the top.
  double _baseline = 0;

  double get _across => _insets.left + _insets.right + _margin.left + _margin.right;

  /// The content never wraps: its one piece is as wide as it is.
  static const BoxConstraints _loose = BoxConstraints();

  @override
  double computeMinIntrinsicWidth(double height) =>
      guardedSize(child, () => child?.getMaxIntrinsicWidth(double.infinity) ?? 0) + _across;

  @override
  double computeMaxIntrinsicWidth(double height) => computeMinIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      guardedSize(child, () => child?.getMinIntrinsicHeight(double.infinity) ?? 0);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      guardedSize(child, () => child?.getMaxIntrinsicHeight(double.infinity) ?? 0);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final s = guardedSize(child, () => child?.getDryLayout(_loose) ?? Size.zero);
    return constraints.constrain(Size(s.width + _across, s.height));
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) {
    final child = this.child;
    return child == null ? null : dryBaselineOf(child, _loose, baseline);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => child?.getDistanceToActualBaseline(baseline);

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size(_across, 0));
      _baseline = 0;
      return;
    }
    child.layout(_loose, parentUsesSize: true);
    (child.parentData! as BoxParentData).offset = Offset(_margin.left + _insets.left, 0);
    _baseline = child.getDistanceToBaseline(TextBaseline.alphabetic) ?? child.size.height;
    size = constraints.constrain(Size(child.size.width + _across, child.size.height));
  }

  /// The border box: the content's width and the insets across, the
  /// content area and the insets down, round the baseline.
  Rect get _borderBox {
    final w = (child?.size.width ?? 0) + _insets.left + _insets.right;
    return Rect.fromLTRB(
      _margin.left,
      _baseline - _ascent - _insets.top,
      _margin.left + math.max(0.0, w),
      _baseline + _descent + _insets.bottom,
    );
  }

  /// The border box SNAPPED TO WHOLE CSS PIXELS where it lands on the
  /// page, back in this box's own terms. Blink paints a box's background
  /// and border over its paint rect snapped that way (`ToPixelSnappedRect`:
  /// each edge to the nearest pixel, half up) and scales to the device
  /// after; an inline box stands wherever the words before it end, a
  /// fraction across, and drawn where it lay its edges were a column of
  /// blended pixels where Chrome's are solid.
  Rect get _snappedBox {
    final corner = localToGlobal(Offset.zero);
    final box = _borderBox.shift(corner);
    double snap(double v) => (v + 0.5).floorToDouble();
    return Rect.fromLTRB(snap(box.left), snap(box.top), snap(box.right), snap(box.bottom)).shift(-corner);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final box = _snappedBox.shift(offset);
    _painter ??= _decoration.createBoxPainter(markNeedsPaint);
    _painter!.paint(context.canvas, box.topLeft, ImageConfiguration(size: box.size, textDirection: _textDirection));
    super.paint(context, offset);
  }

  @override
  void detach() {
    _painter?.dispose();
    _painter = null;
    super.detach();
  }

  @override
  void dispose() {
    _painter?.dispose();
    _painter = null;
    super.dispose();
  }
}
