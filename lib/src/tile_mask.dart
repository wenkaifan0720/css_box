/// A mask tiled from a small gradient.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';

/// A tile's side in device pixels as Chrome rasterises it: the next whole
/// pixel up, at least one (cc's `PaintShader::CreateScaledPaintRecord`
/// rounds the scaled tile out and draws the tile scaled to fill it).
int _raster(double v) => math.max(1, (v - 1e-6).ceil());

/// Whether the tile's raster is read pixel for pixel: the tile is a whole
/// number of device pixels. A tile that is not -- `round` resizes one to
/// the box, 322 / 64 = 5.03 -- is its rounded-up raster scaled back down
/// to the tile, and Chrome samples that BILINEARLY (Blink draws a tiled
/// picture or gradient with low filter quality).
FilterQuality _sampling(ui.Image image, Size tile, double dpr) =>
    (image.width - tile.width * dpr).abs() < 1e-6 && (image.height - tile.height * dpr).abs() < 1e-6
    ? FilterQuality.none
    : FilterQuality.low;

/// `mask-image: radial-gradient(#fff .5px, transparent .5px); mask-size:
/// 5px 5px`: a tile of gradient laid over the box and REPEATED
/// (css-masking-1 7.6, 7.7 -- a mask is laid out like a background, in
/// the border box, from its corner, repeated by default), so the box shows
/// through a screen of dots. A framework site's hero and its cards are drawn
/// this way. A [ShaderMask] takes one shader over the whole box, and no
/// gradient shader repeats on a grid.
///
/// This is the same layer as a [ShaderMask] with the tile as its shader:
/// the tile's gradient is rasterised ONCE at the device's pixel ratio,
/// which is what Chrome does with it (the gradient sampled at device pixel
/// centres), and repeated as an [ImageShader] read pixel for pixel
/// (`FilterQuality.none`, so no texel is blended with its neighbour) --
/// or, for a tile that is not a whole number of device pixels, rasterised
/// at the next whole number up and scaled back down bilinearly, as Chrome
/// does (see [_sampling]). The
/// tile starts at the box's corner SNAPPED TO A CSS PIXEL (half up), as
/// Blink snaps the box's paint rect before the device scale: a box at
/// 30.5px tiles from 31, not from 30.5 -- read from 30.5 the texels would
/// fall on pixel edges, and every dot would be a neighbour off; and at a
/// ratio of 2 a box at 46.5px tiles from 47 (94 device pixels), where the
/// nearest device pixel, 93, put every dot one off Chrome's. `dstIn`: what
/// the box painted is kept as far as the tile's alpha says.
///
/// [width] and [height] are the tile's size in logical px; null on an axis
/// the tile fills (a stripe repeated across the box is a tile as tall as
/// the box). [x] and [y] place the first tile in the room the box has
/// past it, as a share, as `mask-position` does, and [dx] and [dy] move it
/// on by a length (`mask-position: 2px 2px`): every copy moves with the
/// first, the tiles laid to either side of it (css-backgrounds-3 3.6).
///
/// [ratio] is a tile with a ratio and no size of its own: a picture of
/// only a `viewBox` (css-images-3 5.2.1), which `mask-size: auto` sizes as
/// `contain` -- as large as the box holds on both axes (css-backgrounds-3
/// 3.9) -- and only the box's size, known when it is laid out, says how
/// large that is. A pricing page's progress line is a 16 by 88 picture in a box
/// as tall as the list beside it.
///
/// [roundX] and [roundY] are `mask-repeat: round` on that axis
/// (css-backgrounds-3 3.4): the tile is resized so that a whole number of
/// them fits the box -- as many as come nearest, and at least one -- which
/// only the box's own size, known when it is laid out, can say.
class TileMask extends SingleChildRenderObjectWidget {
  const TileMask({
    super.key,
    required this.gradient,
    this.width,
    this.height,
    this.x = 0,
    this.y = 0,
    this.dx = 0,
    this.dy = 0,
    this.roundX = false,
    this.roundY = false,
    this.ratio,
    required Widget super.child,
  }) : assert(ratio == null || width == null && height == null);

  final Gradient gradient;
  final double? width, height;

  /// Width over height of a tile `contain`ed in the box.
  final double? ratio;
  final double x, y;
  final double dx, dy;
  final bool roundX, roundY;

  @override
  RenderTileMask createRenderObject(BuildContext context) => RenderTileMask(
    gradient: gradient,
    width: width,
    height: height,
    x: x,
    y: y,
    dx: dx,
    dy: dy,
    roundX: roundX,
    roundY: roundY,
    ratio: ratio,
    devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? View.of(context).devicePixelRatio,
    textDirection: Directionality.maybeOf(context),
  );

  @override
  void updateRenderObject(BuildContext context, RenderTileMask renderObject) {
    renderObject
      ..gradient = gradient
      ..width = width
      ..height = height
      ..x = x
      ..y = y
      ..dx = dx
      ..dy = dy
      ..roundX = roundX
      ..roundY = roundY
      ..ratio = ratio
      ..devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? View.of(context).devicePixelRatio
      ..textDirection = Directionality.maybeOf(context);
  }
}

/// The render object behind [TileMask]: a [RenderShaderMask] whose shader
/// is the tile, made when the box is painted.
class RenderTileMask extends RenderProxyBox with ChildDryBaseline, KeptUnderHatch {
  RenderTileMask({
    required Gradient gradient,
    double? width,
    double? height,
    double x = 0,
    double y = 0,
    double dx = 0,
    double dy = 0,
    bool roundX = false,
    bool roundY = false,
    double? ratio,
    required double devicePixelRatio,
    TextDirection? textDirection,
  }) : _gradient = gradient,
       _ratio = ratio,
       _width = width,
       _height = height,
       _x = x,
       _y = y,
       _dx = dx,
       _dy = dy,
       _roundX = roundX,
       _roundY = roundY,
       _dpr = devicePixelRatio,
       _textDirection = textDirection;

  Gradient _gradient;
  Gradient get gradient => _gradient;
  set gradient(Gradient v) {
    if (v == _gradient) return;
    _gradient = v;
    _drop();
  }

  double? _width;
  double? get width => _width;
  set width(double? v) {
    if (v == _width) return;
    _width = v;
    _drop();
  }

  double? _height;
  double? get height => _height;
  set height(double? v) {
    if (v == _height) return;
    _height = v;
    _drop();
  }

  double _x;
  double get x => _x;
  set x(double v) {
    if (v == _x) return;
    _x = v;
    markNeedsPaint();
  }

  double _y;
  double get y => _y;
  set y(double v) {
    if (v == _y) return;
    _y = v;
    markNeedsPaint();
  }

  double _dx;
  double get dx => _dx;
  set dx(double v) {
    if (v == _dx) return;
    _dx = v;
    markNeedsPaint();
  }

  double _dy;
  double get dy => _dy;
  set dy(double v) {
    if (v == _dy) return;
    _dy = v;
    markNeedsPaint();
  }

  bool _roundX;
  bool get roundX => _roundX;
  set roundX(bool v) {
    if (v == _roundX) return;
    _roundX = v;
    markNeedsPaint();
  }

  bool _roundY;
  bool get roundY => _roundY;
  set roundY(bool v) {
    if (v == _roundY) return;
    _roundY = v;
    markNeedsPaint();
  }

  double? _ratio;
  double? get ratio => _ratio;
  set ratio(double? v) {
    if (v == _ratio) return;
    _ratio = v;
    markNeedsPaint();
  }

  double _dpr;
  double get devicePixelRatio => _dpr;
  set devicePixelRatio(double v) {
    if (v == _dpr) return;
    _dpr = v;
    _drop();
  }

  TextDirection? _textDirection;
  TextDirection? get textDirection => _textDirection;
  set textDirection(TextDirection? v) {
    if (v == _textDirection) return;
    _textDirection = v;
    _drop();
  }

  /// The tile's picture, kept while nothing it was made from changes.
  ui.Image? _image;
  Size? _imageOf;

  void _drop() {
    _image?.dispose();
    _image = null;
    _imageOf = null;
    markNeedsPaint();
  }

  @override
  void dispose() {
    _image?.dispose();
    _image = null;
    super.dispose();
  }

  @override
  ShaderMaskLayer? get layer => super.layer as ShaderMaskLayer?;

  @override
  bool get alwaysNeedsCompositing => child != null;

  /// The first tile in the box: the tile's own size on the axes it states,
  /// the box's on the ones it fills -- resized to a whole number of tiles on
  /// a `round` axis -- placed by [x] and [y] in what is left and moved on
  /// by [dx] and [dy].
  Rect tileOf(Size box) {
    var w = _width ?? box.width, h = _height ?? box.height;
    if (_ratio case final r? when r > 0) {
      w = math.min(box.width, box.height * r);
      h = w / r;
    }
    // In Blink's layout units, 1/64 px: the room over the count with the
    // remainder dropped (a LayoutUnit division truncates). 300px of 7px
    // tiles is 43 of 6.96875, not of 6.9767 -- a third of a pixel short by
    // the last one, which is where Chrome draws them.
    double rounded(double room, double tile) =>
        ((room * 64 + 1e-6) / math.max(1, (room / tile).round())).floorToDouble() / 64;
    if (_roundX && _width != null && w > 0 && box.width > 0) w = rounded(box.width, w);
    if (_roundY && _height != null && h > 0 && box.height > 0) h = rounded(box.height, h);
    return Rect.fromLTWH((box.width - w) * _x + _dx, (box.height - h) * _y + _dy, w, h);
  }

  /// The tile at [size], drawn once at the device's pixel ratio.
  ui.Image _tile(Size size) {
    if (_image != null && _imageOf == size) return _image!;
    _image?.dispose();
    final pw = _raster(size.width * _dpr).clamp(1, 1 << 14), ph = _raster(size.height * _dpr).clamp(1, 1 << 14);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pw / size.width, ph / size.height);
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = _gradient.createShader(rect, textDirection: _textDirection));
    final picture = recorder.endRecording();
    _image = picture.toImageSync(pw, ph);
    picture.dispose();
    _imageOf = size;
    return _image!;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      return;
    }
    assert(needsCompositing);
    final tile = tileOf(size);
    if (tile.isEmpty) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    // Where the box's corner lands on the page, and how far the nearest
    // CSS pixel is from it: the tile starts there. Blink snaps a box's
    // paint rect to whole CSS pixels (`ToPixelSnappedRect`, half up) and
    // scales to the device after, so at a device pixel ratio of 2 a box at
    // 46.5px paints from 94 device pixels, not 93: snapped to the device
    // instead, every dot of a mask at that corner was one device pixel
    // off the browser's.
    final corner = localToGlobal(Offset.zero);
    final snap = Offset((corner.dx + 0.5).floorToDouble() - corner.dx, (corner.dy + 0.5).floorToDouble() - corner.dy);
    final image = _tile(tile.size);
    final matrix = Matrix4.translationValues(tile.left + snap.dx, tile.top + snap.dy, 0)
      ..scaleByDouble(tile.width / image.width, tile.height / image.height, 1, 1);
    layer ??= ShaderMaskLayer();
    layer!
      ..shader = ImageShader(
        image,
        TileMode.repeated,
        TileMode.repeated,
        matrix.storage,
        filterQuality: _sampling(image, tile.size, _dpr),
      )
      ..maskRect = offset & size
      ..blendMode = BlendMode.dstIn;
    context.pushLayer(layer!, super.paint, offset);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<Gradient>('gradient', _gradient))
      ..add(DoubleProperty('width', _width))
      ..add(DoubleProperty('height', _height))
      ..add(DoubleProperty('dx', _dx, defaultValue: 0))
      ..add(DoubleProperty('dy', _dy, defaultValue: 0))
      ..add(FlagProperty('roundX', value: _roundX, ifTrue: 'roundX'))
      ..add(FlagProperty('roundY', value: _roundY, ifTrue: 'roundY'));
  }
}
