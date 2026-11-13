import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';

/// A `min-height` OVER A BOTTOM MARGIN THAT MAY LEAVE THE BOX.
///
/// A last child's bottom margin collapses through the end of a box of
/// `auto` height with no bottom padding or border (CSS 2.1 8.3.1), and a
/// `min-height` decides whether it does: where the content reaches the
/// floor the box is as tall as its content and the margin goes on below
/// it; where the floor binds the box is the floor, and Chrome drops the
/// margin (`fixtures/min-height-end-margin`). The flow around this box
/// prints [margin] after it either way, so where the floor binds this
/// widget stands [margin] shorter than the box it draws.
///
/// The box itself is the child, laid out at its content height or, where
/// that falls short, at [floor] -- so whatever measures the child reads the
/// box the page draws.
class FloorBox extends SingleChildRenderObjectWidget {
  const FloorBox({super.key, required this.floor, required this.margin, super.child});

  /// The box's `min-height`, on its border box.
  final double floor;

  /// The bottom margin its last child hands out past it.
  final double margin;

  @override
  RenderFloorBox createRenderObject(BuildContext context) => RenderFloorBox(floor: floor, margin: margin);

  @override
  void updateRenderObject(BuildContext context, RenderFloorBox renderObject) {
    renderObject
      ..floor = floor
      ..margin = margin;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('floor', floor))
      ..add(DoubleProperty('margin', margin));
  }
}

/// The render object behind [FloorBox].
class RenderFloorBox extends RenderProxyBox with ChildDryBaseline, KeptUnderHatch {
  RenderFloorBox({required double floor, required double margin, RenderBox? child})
    : _floor = floor,
      _margin = margin,
      super(child);

  double get floor => _floor;
  double _floor;
  set floor(double v) {
    if (v == _floor) return;
    _floor = v;
    markNeedsLayout();
  }

  double get margin => _margin;
  double _margin;
  set margin(double v) {
    if (v == _margin) return;
    _margin = v;
    markNeedsLayout();
  }

  /// What the flow is told for a box whose content is [content] tall.
  double _told(double content) => content >= _floor ? content : math.max(0.0, _floor - _margin);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _told(guardedSize(child, () => super.computeMinIntrinsicHeight(width)));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _told(guardedSize(child, () => super.computeMaxIntrinsicHeight(width)));

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final c = child;
    if (c == null) return constraints.constrain(Size.zero);
    final got = guardedSize(c, () => c.getDryLayout(constraints.copyWith(minHeight: 0)));
    return constraints.constrain(Size(got.width, _told(got.height)));
  }

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.constrain(Size.zero);
      return;
    }
    final open = constraints.copyWith(minHeight: 0);
    c.layout(open, parentUsesSize: true);
    final content = c.size.height;
    if (content < _floor) {
      c.layout(open.copyWith(minHeight: math.min(_floor, open.maxHeight)), parentUsesSize: true);
    }
    size = constraints.constrain(Size(c.size.width, _told(content)));
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final c = child;
    if (c == null) return false;
    if (!(Offset.zero & c.size).contains(position)) return false;
    if (hitTestChildren(result, position: position) || hitTestSelf(position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}
