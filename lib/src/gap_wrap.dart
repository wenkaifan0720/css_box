/// A wrap whose length along its runs counts its gaps.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';

/// [Wrap], ASKED ITS LENGTH ALONG ITS RUNS, COUNTING ITS [spacing].
///
/// A wrapping flex container's max-content main size is its items'
/// max-content contributions end to end on one line with the gaps between
/// them in it (css-flexbox-1 9.9.1; css-align-3 8.1: a gap is the space
/// between adjacent items on a line). `RenderWrap.computeMaxIntrinsicWidth`
/// adds up its children and leaves its own `spacing` out, so a gapped
/// [Wrap] answers `spacing * (children - 1)` too little, and laid out at
/// what it answered -- under an [IntrinsicWidth], or in anything else that
/// shrinks to fit it -- breaks its last item onto a run of its own. This
/// one answers the length it lays out on one run at.
///
/// Laid out exactly as the [Wrap] it extends. Everything else it is asked
/// is a [Wrap]'s answer: its least length along its runs is its widest
/// item's (9.9.1: a multi-line container's min-content main size is its
/// largest min-content contribution), and across its runs it lays itself
/// out dry, its spacing in.
class GapWrap extends Wrap {
  const GapWrap({
    super.key,
    super.direction,
    super.alignment,
    super.spacing,
    super.runAlignment,
    super.runSpacing,
    super.crossAxisAlignment,
    super.textDirection,
    super.verticalDirection,
    super.clipBehavior,
    super.children,
  });

  @override
  RenderGapWrap createRenderObject(BuildContext context) => RenderGapWrap(
    direction: direction,
    alignment: alignment,
    spacing: spacing,
    runAlignment: runAlignment,
    runSpacing: runSpacing,
    crossAxisAlignment: crossAxisAlignment,
    textDirection: textDirection ?? Directionality.maybeOf(context),
    verticalDirection: verticalDirection,
    clipBehavior: clipBehavior,
  );
}

/// The render object behind [GapWrap].
class RenderGapWrap extends RenderWrap {
  RenderGapWrap({
    super.children,
    super.direction,
    super.alignment,
    super.spacing,
    super.runAlignment,
    super.runSpacing,
    super.crossAxisAlignment,
    super.textDirection,
    super.verticalDirection,
    super.clipBehavior,
  });

  /// The gaps between its children on one run.
  double get _gaps => childCount < 2 ? 0 : spacing * (childCount - 1);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      guardedSize(this, () => super.computeMaxIntrinsicWidth(height)) + (direction == Axis.horizontal ? _gaps : 0);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      guardedSize(this, () => super.computeMaxIntrinsicHeight(width)) + (direction == Axis.vertical ? _gaps : 0);
}
