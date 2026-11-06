/// A column or a row whose children paint in an order of their own.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';
import 'paint_order.dart';

/// [Flex], painting its children by [z] rather than in the order it lays
/// them out.
///
/// A `z-index` on a box in a block's flow paints it over the siblings after
/// it (CSS 2.1 Appendix E, step 9 over steps 4 and 8), and what it paints
/// may run past its own edge onto them: a news site's sticky header is 141px tall
/// with the 2px rule under its nav hanging below that, over the white page
/// the next box starts with. A [Column] paints in document order, so the
/// page painted over the rule. Laid out exactly as the [Flex] it extends;
/// only paint and hit testing read [z].
class Layers extends Flex {
  const Layers({
    super.key,
    required super.direction,
    required this.z,
    super.mainAxisAlignment,
    super.mainAxisSize,
    super.crossAxisAlignment,
    super.textDirection,
    super.verticalDirection,
    super.textBaseline,
    super.clipBehavior,
    super.spacing,
    super.children,
  });

  /// Each child's paint order: lowest first, ties in document order.
  final List<int> z;

  @override
  RenderLayers createRenderObject(BuildContext context) => RenderLayers(
    z: z,
    direction: direction,
    mainAxisAlignment: mainAxisAlignment,
    mainAxisSize: mainAxisSize,
    crossAxisAlignment: crossAxisAlignment,
    textDirection: getEffectiveTextDirection(context),
    verticalDirection: verticalDirection,
    textBaseline: textBaseline,
    clipBehavior: clipBehavior,
    spacing: spacing,
  );

  @override
  void updateRenderObject(BuildContext context, RenderLayers renderObject) {
    super.updateRenderObject(context, renderObject);
    renderObject.z = z;
  }
}

class RenderLayers extends RenderFlex with PaintOrder, KeptUnderHatch {
  RenderLayers({
    required List<int> z,
    super.direction,
    super.mainAxisAlignment,
    super.mainAxisSize,
    super.crossAxisAlignment,
    super.textDirection,
    super.verticalDirection,
    super.textBaseline,
    super.clipBehavior,
    super.spacing,
  }) : _z = z;

  List<int> _z;
  List<int> get z => _z;
  set z(List<int> value) {
    if (listEquals(_z, value)) return;
    _z = value;
    markNeedsPaint();
  }

  /// The children in paint order. `List.sort` is not stable, so the index
  /// breaks ties.
  @override
  List<RenderBox> get paintOrder => _painted();

  List<RenderBox> _painted() {
    final kids = <(int, int, RenderBox)>[];
    var i = 0;
    for (var child = firstChild; child != null; i++) {
      kids.add((i < _z.length ? _z[i] : 0, i, child));
      child = childAfter(child);
    }
    kids.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
    return [for (final k in kids) k.$3];
  }

  @override
  void defaultPaint(PaintingContext context, Offset offset) {
    for (final child in _painted()) {
      context.paintChild(child, (child.parentData! as FlexParentData).offset + offset);
    }
  }

  @override
  bool defaultHitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in _painted().reversed) {
      final hit = result.addWithPaintOffset(
        offset: (child.parentData! as FlexParentData).offset,
        position: position,
        hitTest: (r, p) => child.hitTest(r, position: p),
      );
      if (hit) return true;
    }
    return false;
  }
}
