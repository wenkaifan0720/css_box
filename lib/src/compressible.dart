import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';

/// A REPLACED BOX SIZED BY A SHARE OF ITS CONTAINER, asked how wide it
/// wants to be.
///
/// css-sizing-3 5.2.1: a percentage in a replaced box's `width` or
/// `max-width` resolves against ZERO for its min-content contribution and
/// as `auto` for its max-content one. So the picture asks a `1fr` track or
/// a shrinking flex item for nothing, and a float or a max-content track
/// for its natural width -- whatever the picture itself says.
/// `RenderImage` says nothing until it has decoded and its own width after,
/// and a layout that asks it is a different layout on each side of that:
/// a news site's `width: 100%` card pictures (304 wide, in 171px `1fr` tracks)
/// laid the grid out two to a row in the gate, which never decodes a
/// picture, and one to a row in the render, which does.
///
/// [natural] is the width the box has with its percentage treated as
/// `auto`: the picture's own, or its stated height down the picture's
/// ratio. The box's laid-out size is its child's under the constraints it
/// is handed; only the intrinsic answers are the box's own.
class Compressible extends SingleChildRenderObjectWidget {
  const Compressible({super.key, required this.natural, this.naturalHeight, super.child});

  /// The max-content width: see the class.
  final double natural;

  /// The picture's own height, where the layout is to ask for one: down
  /// the picture's ratio at a width it is given, its own at none. A ratio
  /// box (`RenderAspectRatio`) asked its width at no height asks its
  /// child's height first, and a picture that answers nothing made the
  /// column round a `width: 100%` picture 0 wide where Chrome has 604.
  final double? naturalHeight;

  @override
  RenderCompressible createRenderObject(BuildContext context) =>
      RenderCompressible(natural: natural, naturalHeight: naturalHeight);

  @override
  void updateRenderObject(BuildContext context, RenderCompressible renderObject) => renderObject
    ..natural = natural
    ..naturalHeight = naturalHeight;
}

/// The render object for [Compressible].
class RenderCompressible extends RenderProxyBox with ChildDryBaseline, KeptUnderHatch {
  RenderCompressible({required double natural, double? naturalHeight, RenderBox? child})
    : _natural = natural,
      _naturalHeight = naturalHeight,
      super(child);

  double? get naturalHeight => _naturalHeight;
  double? _naturalHeight;
  set naturalHeight(double? value) {
    if (_naturalHeight == value) return;
    _naturalHeight = value;
    markNeedsLayout();
  }

  double get natural => _natural;
  double _natural;
  set natural(double value) {
    if (_natural == value) return;
    _natural = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0.0;

  @override
  double computeMaxIntrinsicWidth(double height) => _natural;

  /// See [Compressible.naturalHeight].
  double? _height(double width) {
    final h = _naturalHeight;
    if (h == null) return null;
    return width.isFinite && _natural > 0 ? width * h / _natural : h;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _height(width) ?? guardedSize(child, () => super.computeMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _height(width) ?? guardedSize(child, () => super.computeMaxIntrinsicHeight(width));
}
