import 'dart:ui' show ImageFilter;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';

/// A box drawn into what is behind it with a `mix-blend-mode`.
///
/// CSS blends the element AND EVERYTHING INSIDE IT with its backdrop as one
/// picture (compositing-1 5.1), which is a layer: the box is drawn on its
/// own and then composited with the blend mode. That is exactly what
/// `saveLayer` with a blended `Paint` does, and there is no layer type in
/// Flutter that says it -- `ColorFilterLayer` filters, `ShaderMaskLayer`
/// masks, and neither blends a box into what is already there.
///
/// THE BOX'S OWN OPACITY GOES IN THE SAME LAYER. CSS applies `opacity` to
/// the group first and then blends the group (compositing-1 3.3), which is
/// the alpha of the `Paint` the layer is restored with. An `Opacity` child
/// cannot say it: it pushes a compositing layer of its own, and a layer is
/// no part of the canvas `saveLayer` round it -- the box came out mixed
/// half-and-half with the backdrop where it should have been added.
class Blend extends SingleChildRenderObjectWidget {
  const Blend({super.key, required this.mode, this.opacity = 1, super.child});

  final BlendMode mode;

  /// The box's own `opacity`, applied to it before it is blended.
  final double opacity;

  @override
  RenderBlend createRenderObject(BuildContext context) => RenderBlend(mode, opacity);

  @override
  void updateRenderObject(BuildContext context, RenderBlend renderObject) => renderObject
    ..mode = mode
    ..opacity = opacity;
}

class RenderBlend extends RenderProxyBox with ChildDryBaseline, KeptUnderHatch {
  RenderBlend(this._mode, [this._opacity = 1]);

  BlendMode _mode;
  BlendMode get mode => _mode;
  set mode(BlendMode v) {
    if (_mode == v) return;
    _mode = v;
    markNeedsPaint();
  }

  double _opacity;
  double get opacity => _opacity;
  set opacity(double v) {
    if (_opacity == v) return;
    _opacity = v;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || _opacity <= 0) return;
    context.canvas.saveLayer(
      offset & size,
      Paint()
        ..blendMode = _mode
        ..color = Color.fromRGBO(0, 0, 0, _opacity.clamp(0.0, 1.0)),
    );
    super.paint(context, offset);
    context.canvas.restore();
  }
}

/// An [ImageFiltered] that filters on the canvas it is painted on.
///
/// `ImageFiltered` pushes a layer of its own (`ImageFilterLayer`), and a
/// layer is no part of the canvas a [Blend] round it saves: the filtered
/// box came out drawn over what is behind it in the normal way, its blend
/// and its opacity lost, where CSS blends the group the filter is in
/// (compositing-1 5.1, filter-effects-1 2). A `saveLayer` with the filter
/// on its `Paint` is the same picture filtered the same way, and it is in
/// the [Blend]'s.
///
/// Where something in it pushes a layer of its own the canvas cannot hold
/// that either, and the box filters in a layer as `ImageFiltered` does.
class CanvasFiltered extends SingleChildRenderObjectWidget {
  const CanvasFiltered({super.key, required this.imageFilter, super.child});

  /// The filter: a blur, a colour matrix (a [ColorFilter] is one), or a
  /// composition of them.
  final ImageFilter imageFilter;

  @override
  RenderCanvasFiltered createRenderObject(BuildContext context) => RenderCanvasFiltered(imageFilter);

  @override
  void updateRenderObject(BuildContext context, RenderCanvasFiltered renderObject) =>
      renderObject.imageFilter = imageFilter;
}

class RenderCanvasFiltered extends RenderProxyBox with ChildDryBaseline, KeptUnderHatch {
  RenderCanvasFiltered(this._imageFilter);

  ImageFilter _imageFilter;
  ImageFilter get imageFilter => _imageFilter;
  set imageFilter(ImageFilter v) {
    if (_imageFilter == v) return;
    _imageFilter = v;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) {
      layer = null;
      return;
    }
    if (child.needsCompositing) {
      final l = layer is ImageFilterLayer ? layer! as ImageFilterLayer : ImageFilterLayer();
      l.imageFilter = _imageFilter;
      layer = l;
      context.pushLayer(l, super.paint, offset);
      return;
    }
    layer = null;
    context.canvas.saveLayer(null, Paint()..imageFilter = _imageFilter);
    super.paint(context, offset);
    context.canvas.restore();
  }
}
