/// The order a box paints its children in.
library;

import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/rendering.dart';

/// A box that paints its children in an order of its own -- by `z-index`,
/// lowest first, ties in document order (CSS 2.1 appendix E) -- and not
/// in the order it holds them: a page's sticky bar, held first and painted
/// over the content that scrolls under it.
@internal
mixin PaintOrder on RenderBox {
  /// Its children, the one painted first first.
  List<RenderBox> get paintOrder;
}

/// [box]'s children in the order it paints them: its own where it keeps one
/// ([PaintOrder]), else the order it holds them in, as a stack and a flex
/// paint theirs -- but a view and a group of slivers, which paint theirs
/// last to first, so a pinned header, the first, is drawn over what the
/// slivers after it hang under it ([RenderViewport] from its last down to
/// its centre, after those before the centre).
@internal
List<RenderObject> childrenInPaintOrder(RenderObject box) {
  if (box is PaintOrder) return box.paintOrder;
  final held = <RenderObject>[];
  box.visitChildren(held.add);
  if (box is RenderViewport) {
    final centre = held.indexOf(box.center as RenderObject? ?? box);
    if (centre < 0) return held.reversed.toList();
    return [...held.take(centre), ...held.skip(centre).toList().reversed];
  }
  if (box is RenderShrinkWrappingViewport || box is RenderSliverMainAxisGroup) return held.reversed.toList();
  return held;
}
