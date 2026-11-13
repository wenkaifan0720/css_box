/// A box that clips, and asks for no room on the axes it clips.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';
import 'scroll.dart';

/// [ClipRect], plus the half of clipping that changes layout.
///
/// A stock clip forwards its child's intrinsic sizes untouched, so every
/// parent that sizes itself to what its children need -- a [Row], an
/// [IntrinsicWidth], a grid track -- makes room for content that was
/// going to be cut off anyway. A strip of eight cards inside a 358-wide
/// scroller ends up 1594 wide, and the page around it goes with it.
///
/// A browser does not do that: the smallest a scroll container has to be
/// is nothing, because what does not fit is scrolled to rather than shown
/// (css-grid-1 6.6, css-flexbox-1 4.5 -- the automatic minimum size of a
/// scroll container is zero). Its LARGEST is still its content's, so a
/// track with room to spare still grows to fit; it is only the floor that
/// moves.
///
/// `clip-path: inset(...)`, for a [ClipRect]: what is left of the border
/// box once each side is cut in by a length and a share of the box on that
/// axis (css-masking-1 5.1). A NEGATIVE inset reaches OUT past the box, and
/// the clip is then wider than the box it is on -- which is a page's way of
/// painting past its own edge: a pricing page's rows hold a `::before` at
/// `inset: 0; clip-path: inset(0 -1440px)` whose box-shadow is offset and
/// spread 1440px to the left, and the dark bar runs from the row to the
/// edge of the page.
class InsetClip extends CustomClipper<Rect> {
  const InsetClip({this.px = EdgeInsets.zero, this.share = EdgeInsets.zero});

  /// The cut on each side, in logical pixels.
  final EdgeInsets px;

  /// The cut on each side as a share of the box's own width (left, right)
  /// or height (top, bottom).
  final EdgeInsets share;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
    px.left + share.left * size.width,
    px.top + share.top * size.height,
    size.width - px.right - share.right * size.width,
    size.height - px.bottom - share.bottom * size.height,
  );

  @override
  bool shouldReclip(InsetClip old) => old.px != px || old.share != share;
}

/// `clip-path: inset(... round ...)`, for a [ClipRRect]: the rectangle
/// left of the border box once each side is cut in by a length ([px]) and
/// a share of the box on that axis ([share]) -- never less than nothing
/// -- with the corners of [borderRadius] (css-shapes-1 3.1.1, the
/// `border-radius` shorthand's), scaled back together where two pass the
/// side they share, against the rectangle itself (css-backgrounds-3 5.5,
/// Blink's `ConstrainRadii`). `inset(10% round 8px)` on a 300x100 box is
/// the 240x80 rectangle 30 in and 10 down, 8px round each corner.
///
/// A CORNER THAT IS A SHARE is of the BOX, not of the rectangle the cuts
/// leave: [borderRadiusShare] holds each corner's radii as shares, the one
/// across of the box's width and the one down of its height, added to
/// [borderRadius] -- Blink resolves the radii against the reference box
/// (`BasicShapeInset::GetPath`). `inset(10% round 10%)` on a 300x100 box
/// is the 240x80 rectangle with corners 30 across and 10 down.
class RoundInsetClip extends CustomClipper<RRect> {
  const RoundInsetClip({
    this.px = EdgeInsets.zero,
    this.share = EdgeInsets.zero,
    this.borderRadius = BorderRadius.zero,
    this.borderRadiusShare = BorderRadius.zero,
  });

  /// The cut on each side, in logical pixels.
  final EdgeInsets px;

  /// The cut on each side as a share of the box's own width (left, right)
  /// or height (top, bottom).
  final EdgeInsets share;

  /// The corners of the rectangle the cuts leave.
  final BorderRadius borderRadius;

  /// The corners' radii as shares of the box: `x` of its width, `y` of its
  /// height.
  final BorderRadius borderRadiusShare;

  @override
  RRect getClip(Size size) {
    final left = px.left + share.left * size.width, top = px.top + share.top * size.height;
    final right = size.width - px.right - share.right * size.width;
    final bottom = size.height - px.bottom - share.bottom * size.height;
    final rect = Rect.fromLTRB(left, top, right < left ? left : right, bottom < top ? top : bottom);
    if (borderRadiusShare == BorderRadius.zero) return borderRadius.toRRect(rect).scaleRadii();
    Radius at(Radius r, Radius f) {
      final x = r.x + f.x * size.width, y = r.y + f.y * size.height;
      return x <= 0 || y <= 0 ? Radius.zero : Radius.elliptical(x, y);
    }

    return RRect.fromRectAndCorners(
      rect,
      topLeft: at(borderRadius.topLeft, borderRadiusShare.topLeft),
      topRight: at(borderRadius.topRight, borderRadiusShare.topRight),
      bottomRight: at(borderRadius.bottomRight, borderRadiusShare.bottomRight),
      bottomLeft: at(borderRadius.bottomLeft, borderRadiusShare.bottomLeft),
    ).scaleRadii();
  }

  @override
  bool shouldReclip(RoundInsetClip old) =>
      old.px != px ||
      old.share != share ||
      old.borderRadius != borderRadius ||
      old.borderRadiusShare != borderRadiusShare;
}

/// The two axes are separate because CSS's rule is: a box that clips only
/// across still asks for the height its content needs.
class ClipBox extends StatelessWidget {
  const ClipBox({
    super.key,
    this.horizontal = true,
    this.vertical = true,
    this.floors = true,
    this.borderRadius,
    this.scrollsHorizontally = false,
    this.scrollsVertically = false,
    this.takesPointer = true,
    this.child,
  });

  /// Whether the clip -- and so the zero floor -- applies on each axis.
  final bool horizontal, vertical;

  /// Whether the box reports the zero floor as its minimum intrinsic size.
  ///
  /// The floor is a MINIMUM, not a min-content size: a scroll container's
  /// min-content width is still its content's, and a `min-content` track
  /// sizes itself to that (css-grid-1 12.5). A grid item (`TrackCell`) that
  /// states `minWidth: 0` has the floor applied where CSS applies it, so
  /// the box under it reports its content.
  final bool floors;

  /// Rounded corners, as [ClipRRect] takes them. Null clips a rectangle.
  final BorderRadiusGeometry? borderRadius;

  /// Whether what runs out of the box on each axis is scrolled to: an
  /// `overflow-x` or `overflow-y` of `auto` or `scroll` (css-overflow-3
  /// 3.1), where `hidden` and `clip` only cut. The content is laid out as
  /// the clip lays it out either way, so at rest the picture is the same
  /// ([ScrollBox]).
  final bool scrollsHorizontally, scrollsVertically;

  /// Whether a box that scrolls takes a pointer where nothing in it does
  /// ([ScrollBox.takesPointer]).
  final bool takesPointer;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final child = this.child;
    return _ClipBox(
      horizontal: horizontal,
      vertical: vertical,
      floors: floors,
      borderRadius: borderRadius,
      child: child != null && (scrollsHorizontally || scrollsVertically)
          ? ScrollBox(
              horizontal: scrollsHorizontally,
              vertical: scrollsVertically,
              takesPointer: takesPointer,
              child: child,
            )
          : child,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('horizontal', value: horizontal, ifTrue: 'clips across'));
    properties.add(FlagProperty('vertical', value: vertical, ifTrue: 'clips down'));
    properties.add(FlagProperty('floors', value: floors, ifFalse: 'reports its content'));
    properties.add(DiagnosticsProperty<BorderRadiusGeometry?>('borderRadius', borderRadius, defaultValue: null));
    properties.add(FlagProperty('scrollsHorizontally', value: scrollsHorizontally, ifTrue: 'scrolls across'));
    properties.add(FlagProperty('scrollsVertically', value: scrollsVertically, ifTrue: 'scrolls down'));
    properties.add(FlagProperty('takesPointer', value: takesPointer, ifFalse: 'takes no pointer of its own'));
  }
}

/// The clip of a [ClipBox], round its content or the [ScrollBox] it
/// scrolls in.
class _ClipBox extends SingleChildRenderObjectWidget {
  const _ClipBox({
    required this.horizontal,
    required this.vertical,
    required this.floors,
    required this.borderRadius,
    super.child,
  });

  final bool horizontal, vertical, floors;
  final BorderRadiusGeometry? borderRadius;

  @override
  RenderClipBox createRenderObject(BuildContext context) => RenderClipBox(
    horizontal: horizontal,
    vertical: vertical,
    floors: floors,
    borderRadius: borderRadius ?? BorderRadius.zero,
    clipBehavior: borderRadius == null ? Clip.hardEdge : Clip.antiAlias,
  );

  @override
  void updateRenderObject(BuildContext context, RenderClipBox renderObject) {
    renderObject
      ..horizontal = horizontal
      ..vertical = vertical
      ..floors = floors
      ..borderRadius = borderRadius ?? BorderRadius.zero
      ..clipBehavior = borderRadius == null ? Clip.hardEdge : Clip.antiAlias;
  }
}

/// The render object behind [ClipBox].
class RenderClipBox extends RenderClipRRect with DryLastBaseline, KeptUnderHatch {
  RenderClipBox({
    bool horizontal = true,
    bool vertical = true,
    bool floors = true,
    super.borderRadius,
    super.clipBehavior,
    super.child,
  }) : _horizontal = horizontal,
       _vertical = vertical,
       _floors = floors;

  bool get horizontal => _horizontal;
  bool _horizontal;
  set horizontal(bool value) {
    if (_horizontal == value) return;
    _horizontal = value;
    markNeedsLayout();
  }

  bool get vertical => _vertical;
  bool _vertical;
  set vertical(bool value) {
    if (_vertical == value) return;
    _vertical = value;
    markNeedsLayout();
  }

  bool get floors => _floors;
  bool _floors;
  set floors(bool value) {
    if (_floors == value) return;
    _floors = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      horizontal && floors ? 0.0 : guardedSize(child, () => super.computeMinIntrinsicWidth(height));

  @override
  double computeMinIntrinsicHeight(double width) =>
      vertical && floors ? 0.0 : guardedSize(child, () => super.computeMinIntrinsicHeight(width));

  // A scroll container's baseline is its content's, held inside its own
  // box (csswg-drafts#7660): text scrolled out of view does not drag the
  // line the box sits on down after it. The height is kept from layout:
  // the line asking is an ancestor, which may not read this box's size,
  // and a relayout clears the cached baseline and tells the line anyway.
  double _height = 0;

  @override
  void performLayout() {
    super.performLayout();
    _height = size.height;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final b = super.computeDistanceToActualBaseline(baseline);
    return b == null || !vertical ? b : b.clamp(0.0, _height);
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) {
    final c = child;
    final b = c == null ? null : guardedWhereProxiesAssert(c, () => super.computeDryBaseline(constraints, baseline));
    return b == null || !vertical ? b : b.clamp(0.0, guardedSize(this, () => getDryLayout(constraints)).height);
  }

  @override
  double? dryLastBaseline(BoxConstraints constraints, TextBaseline baseline) {
    final c = child;
    final b = c == null ? null : dryLastBaselineOf(c, constraints, baseline);
    return b == null || !vertical ? b : b.clamp(0.0, guardedSize(this, () => getDryLayout(constraints)).height);
  }
}
