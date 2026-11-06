/// A mask of several layers.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
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

/// One layer of a [MaskLayers]: a gradient laid over a TILE of [width] by
/// [height] -- null on an axis the tile fills, so a layer with neither is
/// laid over the box whole; with a [widthFraction] (or [heightFraction])
/// the tile is that share of the box and the length besides, which is
/// `mask-size: calc(100% - 100px) 100%` -- placed by [x] and [y] in the room the box has
/// past it (a share, as `mask-position` does) and moved on by [dx] and [dy],
/// repeated along the axes [repeatX] and [repeatY] say, and on a [roundX]
/// or [roundY] axis resized to a whole number of tiles (css-backgrounds-3
/// 3.4, 3.6, 3.9: a mask layer is laid out like a background).
///
/// On a [spaceX] (or [spaceY]) axis the tile is `space`d (3.4): laid as
/// many whole times as the box holds, the first against the box's near
/// edge and the last against its far one, the room left over shared out
/// evenly between the copies -- in Blink's 1/64 px, the remainder dropped
/// (`GetSpaceBetweenImageTiles`) -- and the position is not read. Where
/// the box holds fewer than two copies the tile is laid once, where [x]
/// and [dx] put it, as `no-repeat` lays it; [repeatX] is not read on that
/// axis either way. A travel site's scroll strips park the start fade of their
/// mask off the box; `space`d, it is laid all along the strip.
///
/// A layer in an INNER BOX is laid out in the box less [inset] and cut to
/// it -- `mask-origin` and `mask-clip` both the padding box (the border's
/// widths in) or the content box (the padding's as well), css-masking-1
/// 7.6, 7.7. It is COMPOSITED ONLY AS FAR AS THAT BOX: past it the layers
/// under it stand as they are, whatever its `mask-composite` -- Chrome,
/// measured, paints each layer into its clip box alone, so a fade in the
/// content box `intersect`ed with one across the border box leaves that
/// one over the padding and the border (`fixtures/mask-origin-clip-box`
/// p5). The tile's size, share and position are of that box.
///
/// A layer CUT TO ANOTHER BOX than the one it is laid out in -- `mask-origin:
/// content-box` under `mask-clip: border-box` -- is laid out in the box less
/// [inset] and cut to the box less [clip]: a tile laid off its box still
/// shows as far as the clip box reaches, and the copies of a repeated one go
/// on into it (css-backgrounds-3 3.7, 3.8). The travel site's strips padded 12px at
/// each end lay their fades in the content box, and the start fade's tail
/// shows in the padding before it.
///
/// A box it is cut to WITH ROUND CORNERS is given by the border box's own,
/// [corners]: each corner of the box it is cut to is the border edge's
/// less the frame on its two sides, and none where that is nothing
/// (css-backgrounds-3 5.3) -- after the border edge's are scaled back
/// together where two on a side pass it (5.5), which the box's size says
/// (`fixtures/mask-clip-round-inner`).
///
/// [composite] is how the layer meets the layers under it
/// (`mask-composite`, css-masking-1 7.9, the layer the source and what is
/// under it the destination): `add` is source-over ([BlendMode.srcOver]),
/// `subtract` source-out ([BlendMode.srcOut]), `intersect` source-in
/// ([BlendMode.srcIn]) and `exclude` xor ([BlendMode.xor]). The bottom
/// layer's has nothing to meet, and is drawn as it is.
@immutable
class MaskLayer {
  const MaskLayer({
    required this.gradient,
    this.width,
    this.height,
    this.widthFraction,
    this.heightFraction,
    this.x = 0,
    this.y = 0,
    this.dx = 0,
    this.dy = 0,
    this.repeatX = true,
    this.repeatY = true,
    this.roundX = false,
    this.roundY = false,
    this.spaceX = false,
    this.spaceY = false,
    this.inset = EdgeInsets.zero,
    this.clip,
    this.corners,
    this.composite = BlendMode.srcOver,
  });

  final Gradient gradient;
  final double? width, height;

  /// The share of the box the tile is on each axis, [width] or [height]
  /// added to it.
  final double? widthFraction, heightFraction;
  final double x, y, dx, dy;
  final bool repeatX, repeatY, roundX, roundY;

  /// `space` along that axis: as many whole copies as the box holds,
  /// spread from edge to edge.
  final bool spaceX, spaceY;

  /// How far in from the box's edges the box the layer is laid out in and
  /// cut to is.
  final EdgeInsets inset;

  /// How far in from the box's edges the box the layer is cut to is, where
  /// that is not [inset].
  final EdgeInsets? clip;

  /// The BORDER box's corners, where the box the layer is cut to has round
  /// ones: each of those is one of these, scaled back with the others to
  /// fit the box (css-backgrounds-3 5.5), less the frame on its two sides
  /// -- [clip], or [inset] -- and none where that is nothing (5.3).
  final BorderRadius? corners;

  /// The box the layer is cut to, [cut] in a box of [size]: square, or
  /// round at the corners [corners] leaves it (see there).
  RRect cutOf(Rect cut, Size size) {
    final r = corners;
    if (r == null) return RRect.fromRectAndRadius(cut, Radius.zero);
    // The border edge's corners, scaled back together by the least share
    // any side has room for (css-backgrounds-3 5.5).
    var f = 1.0;
    void fit(double side, double a, double b) {
      if (a + b > side && a + b > 0) f = math.min(f, side / (a + b));
    }

    fit(size.width, r.topLeft.x, r.topRight.x);
    fit(size.width, r.bottomLeft.x, r.bottomRight.x);
    fit(size.height, r.topLeft.y, r.bottomLeft.y);
    fit(size.height, r.topRight.y, r.bottomRight.y);
    final e = clip ?? inset;
    Radius less(Radius c, double x, double y) =>
        Radius.elliptical(math.max(0.0, c.x * f - x), math.max(0.0, c.y * f - y));
    return RRect.fromRectAndCorners(
      cut,
      topLeft: less(r.topLeft, e.left, e.top),
      topRight: less(r.topRight, e.right, e.top),
      bottomRight: less(r.bottomRight, e.right, e.bottom),
      bottomLeft: less(r.bottomLeft, e.left, e.bottom),
    );
  }

  /// How the layer meets the layers under it.
  final BlendMode composite;

  /// The first tile in [box]: the tile's own size on the axes it states,
  /// the box's on the ones it fills -- resized to a whole number of tiles
  /// on a `round` axis -- placed by [x] and [y] in what is left and moved
  /// on by [dx] and [dy], or against the box's near edge on a `space` axis
  /// that holds two copies or more (see [spacingOf]).
  Rect tileOf(Size box) {
    final (w, h) = _size(box);
    final (gx, gy) = _spacing(box, w, h);
    return Rect.fromLTWH(gx != null ? 0 : (box.width - w) * x + dx, gy != null ? 0 : (box.height - h) * y + dy, w, h);
  }

  /// The room between two copies along each `space` axis the box holds
  /// two copies or more on; null on any other axis.
  (double?, double?) spacingOf(Size box) {
    final (w, h) = _size(box);
    return _spacing(box, w, h);
  }

  (double, double) _size(Size box) {
    var w = widthFraction != null ? math.max(0.0, widthFraction! * box.width + (width ?? 0)) : width ?? box.width;
    var h = heightFraction != null ? math.max(0.0, heightFraction! * box.height + (height ?? 0)) : height ?? box.height;
    // In Blink's layout units, 1/64 px: the room over the count with the
    // remainder dropped (a LayoutUnit division truncates). 300px of 7px
    // tiles is 43 of 6.96875, not of 6.9767 -- a third of a pixel short by
    // the last one, which is where Chrome draws them.
    double rounded(double room, double tile) =>
        ((room * 64 + 1e-6) / math.max(1, (room / tile).round())).floorToDouble() / 64;
    if (roundX && width != null && w > 0 && box.width > 0) w = rounded(box.width, w);
    if (roundY && height != null && h > 0 && box.height > 0) h = rounded(box.height, h);
    return (w, h);
  }

  (double?, double?) _spacing(Size box, double w, double h) {
    // As many whole copies as the room holds, and the room left over over
    // the gaps between them, in 1/64 px with the remainder dropped; none
    // where fewer than two fit.
    double? gap(bool on, double room, double tile) {
      if (!on || tile <= 0) return null;
      final n = (room / tile + 1e-9).floor();
      if (n < 2) return null;
      return ((room - n * tile) * 64 / (n - 1) + 1e-6).floorToDouble() / 64;
    }

    return (gap(spaceX, box.width, w), gap(spaceY, box.height, h));
  }

  @override
  bool operator ==(Object other) =>
      other is MaskLayer &&
      other.gradient == gradient &&
      other.width == width &&
      other.height == height &&
      other.widthFraction == widthFraction &&
      other.heightFraction == heightFraction &&
      other.x == x &&
      other.y == y &&
      other.dx == dx &&
      other.dy == dy &&
      other.repeatX == repeatX &&
      other.repeatY == repeatY &&
      other.roundX == roundX &&
      other.roundY == roundY &&
      other.spaceX == spaceX &&
      other.spaceY == spaceY &&
      other.inset == inset &&
      other.clip == clip &&
      other.corners == corners &&
      other.composite == composite;

  @override
  int get hashCode => Object.hash(
    gradient,
    width,
    height,
    widthFraction,
    heightFraction,
    x,
    y,
    dx,
    dy,
    repeatX,
    repeatY,
    roundX,
    roundY,
    spaceX,
    spaceY,
    inset,
    clip,
    corners,
    composite,
  );
}

/// `mask-image: radial-gradient(...), linear-gradient(...)`: a mask of
/// SEVERAL LAYERS, each laid out over the box as a background is
/// (css-masking-1 7.6, 7.7: in the border box, from its corner) and the
/// layers composited -- each onto the ones after it by its
/// [MaskLayer.composite], the last one at the bottom (css-masking-1 7.9,
/// `mask-composite: add` is source-over) -- and the box kept as far as the
/// result's alpha says. A dot screen over a fade is a framework site's shape:
/// the dots stay where the fade has gone; two fades in one tile laid again and
/// again, `intersect`ed, keep the product in every copy. [ShaderMask] takes one
/// shader, and no one shader is two layers laid out on two grids.
///
/// The layers are drawn into ONE picture of the box at the device's pixel
/// ratio -- a tiled layer's gradient rasterised once into its tile and
/// repeated from where the tile stands, read pixel for pixel, as
/// [TileMask] does with one -- and the box is kept through it (`dstIn`).
/// The picture starts at the box's corner SNAPPED TO A CSS PIXEL (half up)
/// and ends at its far corner snapped the same way, as Blink snaps the
/// box's paint rect: outside it the mask is transparent black
/// (css-masking-1 7.1).
///
/// [layers] are in the order the page lists them: the first one on top.
class MaskLayers extends SingleChildRenderObjectWidget {
  const MaskLayers({super.key, required this.layers, required Widget super.child});

  final List<MaskLayer> layers;

  @override
  RenderMaskLayers createRenderObject(BuildContext context) => RenderMaskLayers(
    layers: layers,
    devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? View.of(context).devicePixelRatio,
    textDirection: Directionality.maybeOf(context),
  );

  @override
  void updateRenderObject(BuildContext context, RenderMaskLayers renderObject) {
    renderObject
      ..layers = layers
      ..devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? View.of(context).devicePixelRatio
      ..textDirection = Directionality.maybeOf(context);
  }
}

/// The render object behind [MaskLayers]: a [ShaderMaskLayer] whose shader
/// is the layers' picture, drawn when the box is painted.
class RenderMaskLayers extends RenderProxyBox with ChildDryBaseline, KeptUnderHatch {
  RenderMaskLayers({required List<MaskLayer> layers, required double devicePixelRatio, TextDirection? textDirection})
    : _layers = layers,
      _dpr = devicePixelRatio,
      _textDirection = textDirection;

  List<MaskLayer> _layers;
  List<MaskLayer> get layers => _layers;
  set layers(List<MaskLayer> v) {
    if (listEquals(v, _layers)) return;
    _layers = v;
    _drop();
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

  /// The mask's picture, and the box it was drawn for: its size and where
  /// its corner fell inside a CSS pixel.
  ui.Image? _image;
  (Size, Offset)? _imageOf;

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

  /// The layers over [box] -- [snapped] its paint rect, in the box's own
  /// coordinates -- drawn at the device's pixel ratio.
  ui.Image _mask(Rect snapped) {
    final key = (size, snapped.topLeft);
    if (_image != null && _imageOf == key) return _image!;
    _image?.dispose();
    final pw = (snapped.width * _dpr).round().clamp(1, 1 << 14), ph = (snapped.height * _dpr).round().clamp(1, 1 << 14);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pw / snapped.width, ph / snapped.height);
    // The box's corner in the picture: the tiles are laid from the snapped
    // corner, which is the picture's own.
    final area = Offset.zero & snapped.size;
    final tiles = <ui.Image>[];
    for (final l in _layers.reversed) {
      // Each layer over the ones under it, by its `mask-composite`; the
      // bottom one onto nothing.
      final mode = identical(l, _layers.last) ? BlendMode.srcOver : l.composite;
      // The box the layer is laid out in: the border box, or one inside it
      // ([MaskLayer.inset]) from the snapped corner in -- and the one it is
      // cut to, the same box unless [MaskLayer.clip] names another.
      final inner = l.inset.deflateRect(area);
      final box = l.inset.deflateSize(size);
      final cut = l.clip == null ? inner : l.clip!.deflateRect(area);
      final tile = inner.isEmpty || cut.isEmpty ? Rect.zero : l.tileOf(box).shift(inner.topLeft);
      // A `space`d axis repeats the tile and the room after it: one cell
      // of the pattern is the two, the gradient over the tile alone.
      final (gx, gy) = inner.isEmpty ? (null, null) : l.spacingOf(box);
      final cell = Size(tile.width + (gx ?? 0), tile.height + (gy ?? 0));
      if (tile.isEmpty) {
        // A layer of no tile is transparent all over the box it is cut to:
        // kept only where it is, it leaves nothing there -- and a box of
        // nothing to cut to composites nowhere.
        if (!cut.isEmpty && (mode == BlendMode.srcIn || mode == BlendMode.srcOut)) {
          if (l.corners == null) {
            canvas.drawRect(cut, Paint()..blendMode = BlendMode.clear);
          } else {
            canvas.drawRRect(l.cutOf(cut, size), Paint()..blendMode = BlendMode.clear);
          }
        }
        continue;
      }
      final tw = _raster(cell.width * _dpr).clamp(1, 1 << 14), th = _raster(cell.height * _dpr).clamp(1, 1 << 14);
      final r = ui.PictureRecorder();
      final c = Canvas(r);
      c.scale(tw / cell.width, th / cell.height);
      final rect = Offset.zero & tile.size;
      c.drawRect(rect, Paint()..shader = l.gradient.createShader(rect, textDirection: _textDirection));
      final picture = r.endRecording();
      final image = picture.toImageSync(tw, th);
      picture.dispose();
      tiles.add(image);
      final matrix = Matrix4.translationValues(tile.left, tile.top, 0)
        ..scaleByDouble(cell.width / tw, cell.height / th, 1, 1);
      // A `space` axis repeats where it holds two copies, and lays the
      // tile once where it does not, whatever `repeat` says.
      final rx = l.spaceX ? gx != null : l.repeatX, ry = l.spaceY ? gy != null : l.repeatY;
      final paint = Paint()
        ..blendMode = mode
        ..shader = ImageShader(
          image,
          rx ? TileMode.repeated : TileMode.decal,
          ry ? TileMode.repeated : TileMode.decal,
          matrix.storage,
          filterQuality: _sampling(image, cell, _dpr),
        );
      if (l.corners == null) {
        canvas.drawRect(cut, paint);
      } else {
        canvas.drawRRect(l.cutOf(cut, size), paint);
      }
      // Past the box it is cut to the layer composites nothing: the layers
      // under it stand there as they are, whatever the operator.
    }
    final picture = recorder.endRecording();
    _image = picture.toImageSync(pw, ph);
    picture.dispose();
    for (final t in tiles) {
      t.dispose();
    }
    _imageOf = key;
    return _image!;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      return;
    }
    assert(needsCompositing);
    if (_layers.isEmpty || size.isEmpty) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    // Where the box's corners land on the page, snapped to the nearest CSS
    // pixel as Blink snaps the box's paint rect.
    final corner = localToGlobal(Offset.zero);
    double snap(double v) => (v + 0.5).floorToDouble();
    final snapped = Rect.fromLTRB(
      snap(corner.dx) - corner.dx,
      snap(corner.dy) - corner.dy,
      snap(corner.dx + size.width) - corner.dx,
      snap(corner.dy + size.height) - corner.dy,
    );
    if (snapped.isEmpty) {
      layer = null;
      return;
    }
    final image = _mask(snapped);
    final matrix = Matrix4.translationValues(snapped.left, snapped.top, 0)
      ..scaleByDouble(snapped.width / image.width, snapped.height / image.height, 1, 1);
    layer ??= ShaderMaskLayer();
    layer!
      ..shader = ImageShader(image, TileMode.decal, TileMode.decal, matrix.storage, filterQuality: FilterQuality.none)
      ..maskRect = offset & size
      ..blendMode = BlendMode.dstIn;
    context.pushLayer(layer!, super.paint, offset);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<MaskLayer>('layers', _layers));
  }
}
