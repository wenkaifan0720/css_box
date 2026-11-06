/// A picture tiled over the box.
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

/// `background-image: url(dots.svg); background-size: 8px 8px`: a picture
/// drawn at a TILE of its own size and REPEATED over the box
/// (css-backgrounds-3 3.4, 3.9) -- a grid of dots, a checker, a dotted rule
/// -- or, with [color], `mask-image` doing the same to a box painted in one
/// colour (css-masking-1 7.6, 7.7: a mask is laid out like a background,
/// and what shows is the colour as far as the tile's alpha says). No
/// Flutter widget repeats a picture it did not decode itself:
/// `DecorationImage` repeats an `ImageProvider`, and a vector is a widget.
///
/// The [child] -- the picture, an `SvgPicture` or an `Image` -- is laid out
/// at the tile's size and painted ONCE into an image at the device's pixel
/// ratio, which is what Chrome does with a tile (Blink records the picture
/// into the tile and Skia rasterises that record once, then repeats the
/// pixels); the image is then repeated as an [ImageShader] read pixel for
/// pixel (`FilterQuality.none`) -- or, for a tile that is not a whole
/// number of device pixels, rasterised at the next whole number up and
/// scaled back down bilinearly, as Chrome does (see [_sampling]). The
/// child is painted nowhere else, and is
/// not hit-tested: it is a picture, not content.
///
/// The image is drawn again whenever the child paints differently. A child
/// with LAYERS OF ITS OWN -- a [RepaintBoundary] round a picture that is
/// still loading or changes, an opacity layer -- repaints them without
/// telling its parent, so its layers are kept live in this box's own layer
/// and the tile is rasterised again from them whenever one of them changes
/// (in the frame it changes, as its repaint is composited).
///
/// The tile's size is [width] by [height] in logical px; null on an axis
/// is `auto` (css-backgrounds-3 3.9 and css-images-3 5.3): the other axis
/// through the picture's [ratio] (width over height) where it has one,
/// else the box's. Both null is the picture's ratio at the largest size
/// the box holds (`contain`), or the box itself where it has no ratio
/// either.
///
/// [x] and [y] place the first tile in the room the box has past it, as a
/// share, as `background-position` does, and [dx] and [dy] move it on by a
/// length; every copy moves with it, laid to either side
/// (css-backgrounds-3 3.6). The first tile starts at the box's corner
/// SNAPPED TO A CSS PIXEL (half up), and the tiles are cut to the box's
/// edges snapped the same way, as Blink snaps a box's paint rect.
///
/// [repeatX] and [repeatY] off lay the tile once along that axis
/// (`no-repeat`). [roundX] and [roundY] are `round` on that axis
/// (css-backgrounds-3 3.4): the tile is resized so that a whole number of
/// them -- as many as come nearest, at least one -- fits the box, and where
/// only one axis rounds and the other is `auto`, the other is scaled with
/// it to keep the tile's shape.
///
/// On a [spaceX] (or [spaceY]) axis the tile is `space`d (3.4): laid as
/// many whole times as the box holds, the first against the box's near
/// edge and the last against its far one, the room left over shared out
/// evenly between the copies -- in Blink's 1/64 px, the remainder dropped
/// -- and the position is not read; where the box holds fewer than two
/// copies the tile is laid once, where [x] and [dx] put it, as `no-repeat`
/// lays it ([repeatX] is not read on that axis either way). Chrome records
/// the tile and the room after it as ONE cell of the pattern and
/// rasterises that (`Image::DrawPattern`'s spacing), and so does this: the
/// picture drawn into the corner of a cell the gap bigger, the rest of the
/// cell clear.
///
/// A TILE A SHARE OF THE BOX: [widthFactor] (or [heightFactor]) is the
/// tile's side as that share of the box's, [width] (or [height]) added to
/// it -- `mask-size: 100%` is `widthFactor: 1` and the height through the
/// picture's [ratio] (css-backgrounds-3 3.9), which is the box's size to
/// say when it is laid out. An Indonesian news site's chevrons are a picture fitted to the
/// width of a link a share sizes, laid again down it.
///
/// A mask [color] is kept where the picture is; with [hole], where it is
/// NOT -- the picture `exclude`d from a layer that keeps the whole box,
/// one less the picture's alpha (css-masking-1 7.9, source-xor over an
/// opaque layer), and the whole box outside a tile laid once. With
/// [luminance] the picture masks by how light it is times how opaque
/// (css-masking-1 7.2): Blink's luma of its PREMULTIPLIED colour, `0.2126
/// R + 0.7152 G + 0.0722 B` turned into alpha -- the tile laid over black,
/// which makes each pixel opaque in its premultiplied colour, and its light
/// read as the alpha; round the picture there is none.
class PictureTile extends SingleChildRenderObjectWidget {
  const PictureTile({
    super.key,
    this.width,
    this.height,
    this.ratio,
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
    this.widthFactor,
    this.heightFactor,
    this.color,
    this.hole = false,
    this.luminance = false,
    required Widget super.child,
  });

  final double? width, height, ratio;

  /// The tile's side as a share of the box's, [width] or [height] added.
  final double? widthFactor, heightFactor;

  /// The mask [color] where the picture is not, rather than where it is.
  final bool hole;

  /// The picture read by its luminance, not its alpha.
  final bool luminance;
  final double x, y;
  final double dx, dy;
  final bool repeatX, repeatY;
  final bool roundX, roundY;

  /// `space` along that axis: as many whole copies as the box holds,
  /// spread from edge to edge.
  final bool spaceX, spaceY;

  /// The colour a mask lets through: the tiles are painted in it, each
  /// pixel as opaque as the picture is there. Null paints the picture.
  final Color? color;

  @override
  RenderPictureTile createRenderObject(BuildContext context) => RenderPictureTile(
    width: width,
    height: height,
    ratio: ratio,
    x: x,
    y: y,
    dx: dx,
    dy: dy,
    repeatX: repeatX,
    repeatY: repeatY,
    roundX: roundX,
    roundY: roundY,
    spaceX: spaceX,
    spaceY: spaceY,
    widthFactor: widthFactor,
    heightFactor: heightFactor,
    color: color,
    hole: hole,
    luminance: luminance,
    devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? View.of(context).devicePixelRatio,
  );

  @override
  void updateRenderObject(BuildContext context, RenderPictureTile renderObject) {
    renderObject
      ..width = width
      ..height = height
      ..ratio = ratio
      ..x = x
      ..y = y
      ..dx = dx
      ..dy = dy
      ..repeatX = repeatX
      ..repeatY = repeatY
      ..roundX = roundX
      ..roundY = roundY
      ..spaceX = spaceX
      ..spaceY = spaceY
      ..widthFactor = widthFactor
      ..heightFactor = heightFactor
      ..color = color
      ..hole = hole
      ..luminance = luminance
      ..devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? View.of(context).devicePixelRatio;
  }
}

/// The render object behind [PictureTile]: as big as it is let be, its
/// child laid out at the tile and painted into the tile's image.
class RenderPictureTile extends RenderProxyBox with ChildDryBaseline, KeptUnderHatch {
  RenderPictureTile({
    double? width,
    double? height,
    double? ratio,
    double x = 0,
    double y = 0,
    double dx = 0,
    double dy = 0,
    bool repeatX = true,
    bool repeatY = true,
    bool roundX = false,
    bool roundY = false,
    bool spaceX = false,
    bool spaceY = false,
    double? widthFactor,
    double? heightFactor,
    Color? color,
    bool hole = false,
    bool luminance = false,
    required double devicePixelRatio,
  }) : _width = width,
       _height = height,
       _ratio = ratio,
       _x = x,
       _y = y,
       _dx = dx,
       _dy = dy,
       _repeatX = repeatX,
       _repeatY = repeatY,
       _roundX = roundX,
       _roundY = roundY,
       _spaceX = spaceX,
       _spaceY = spaceY,
       _widthFactor = widthFactor,
       _heightFactor = heightFactor,
       _color = color,
       _hole = hole,
       _luminance = luminance,
       _dpr = devicePixelRatio;

  double? _width;
  double? get width => _width;
  set width(double? v) {
    if (v == _width) return;
    _width = v;
    markNeedsLayout();
  }

  double? _height;
  double? get height => _height;
  set height(double? v) {
    if (v == _height) return;
    _height = v;
    markNeedsLayout();
  }

  double? _ratio;
  double? get ratio => _ratio;
  set ratio(double? v) {
    if (v == _ratio) return;
    _ratio = v;
    markNeedsLayout();
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

  bool _repeatX;
  bool get repeatX => _repeatX;
  set repeatX(bool v) {
    if (v == _repeatX) return;
    _repeatX = v;
    markNeedsPaint();
  }

  bool _repeatY;
  bool get repeatY => _repeatY;
  set repeatY(bool v) {
    if (v == _repeatY) return;
    _repeatY = v;
    markNeedsPaint();
  }

  bool _roundX;
  bool get roundX => _roundX;
  set roundX(bool v) {
    if (v == _roundX) return;
    _roundX = v;
    markNeedsLayout();
  }

  bool _roundY;
  bool get roundY => _roundY;
  set roundY(bool v) {
    if (v == _roundY) return;
    _roundY = v;
    markNeedsLayout();
  }

  bool _spaceX;
  bool get spaceX => _spaceX;
  set spaceX(bool v) {
    if (v == _spaceX) return;
    _spaceX = v;
    markNeedsPaint();
  }

  bool _spaceY;
  bool get spaceY => _spaceY;
  set spaceY(bool v) {
    if (v == _spaceY) return;
    _spaceY = v;
    markNeedsPaint();
  }

  double? _widthFactor;
  double? get widthFactor => _widthFactor;
  set widthFactor(double? v) {
    if (v == _widthFactor) return;
    _widthFactor = v;
    markNeedsLayout();
  }

  double? _heightFactor;
  double? get heightFactor => _heightFactor;
  set heightFactor(double? v) {
    if (v == _heightFactor) return;
    _heightFactor = v;
    markNeedsLayout();
  }

  Color? _color;
  Color? get color => _color;
  set color(Color? v) {
    if (v == _color) return;
    _color = v;
    markNeedsPaint();
  }

  bool _hole;
  bool get hole => _hole;
  set hole(bool v) {
    if (v == _hole) return;
    _hole = v;
    markNeedsPaint();
  }

  bool _luminance;
  bool get luminance => _luminance;
  set luminance(bool v) {
    if (v == _luminance) return;
    _luminance = v;
    markNeedsPaint();
  }

  double _dpr;
  double get devicePixelRatio => _dpr;
  set devicePixelRatio(double v) {
    if (v == _dpr) return;
    _dpr = v;
    markNeedsPaint();
  }

  /// The tile's image, and the cell and tile size and pixel ratio it was
  /// drawn at.
  ui.Image? _image;
  (Size, Size)? _imageOf;
  double? _imageAt;
  bool? _imageLuma;

  /// [image] read by its light: laid over black, each pixel opaque in its
  /// premultiplied colour, and that colour's luma made its alpha (see
  /// [PictureTile.luminance]). [image] is disposed.
  static ui.Image _luma(ui.Image image) {
    final w = image.width, h = image.height;
    final all = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
    ui.Image draw(void Function(Canvas) paint) {
      final r = ui.PictureRecorder();
      paint(Canvas(r));
      final picture = r.endRecording();
      try {
        return picture.toImageSync(w, h);
      } finally {
        picture.dispose();
      }
    }

    final opaque = draw(
      (c) => c
        ..drawRect(all, Paint()..color = const Color(0xFF000000))
        ..drawImage(image, Offset.zero, Paint()),
    );
    image.dispose();
    final out = draw(
      (c) => c.drawImage(
        opaque,
        Offset.zero,
        Paint()
          ..colorFilter = const ColorFilter.matrix(<double>[
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0.2126,
            0.7152,
            0.0722,
            0,
            0,
          ]),
      ),
    );
    opaque.dispose();
    return out;
  }

  /// Whether the child has painted differently since the image was drawn:
  /// a child that is not a repaint boundary marks its parent, and every
  /// change to this box marks it too. A repaint boundary inside the child
  /// marks nothing above it: a child that composites is kept in [_live].
  bool _stale = true;

  /// The layer a child that composites is painted into and the tile drawn
  /// from ([_TileLayer]), or null.
  final _live = LayerHandle<_TileLayer>();

  @override
  void markNeedsPaint() {
    _stale = true;
    super.markNeedsPaint();
  }

  @override
  void dispose() {
    _image?.dispose();
    _image = null;
    _live.layer = null;
    super.dispose();
  }

  Size _boxFor(BoxConstraints constraints) => Size(
    constraints.hasBoundedWidth ? constraints.maxWidth : constraints.minWidth,
    constraints.hasBoundedHeight ? constraints.maxHeight : constraints.minHeight,
  );

  // A background has no size of its own: the box it is laid in is its size.
  @override
  double computeMinIntrinsicWidth(double height) => 0;
  @override
  double computeMaxIntrinsicWidth(double height) => 0;
  @override
  double computeMinIntrinsicHeight(double width) => 0;
  @override
  double computeMaxIntrinsicHeight(double width) => 0;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => null;

  @override
  Size computeDryLayout(BoxConstraints constraints) => _boxFor(constraints);

  @override
  void performLayout() {
    size = _boxFor(constraints);
    final tile = tileOf(size);
    child?.layout(BoxConstraints.tight(tile.isEmpty ? Size.zero : tile.size));
  }

  /// The first tile in [box]: its size from [width], [height] and [ratio]
  /// -- or a share of the box's ([widthFactor], [heightFactor]) -- resized
  /// to a whole number of tiles on a `round` axis, placed by [x] and [y] in
  /// what the box leaves and moved on by [dx] and [dy].
  Rect tileOf(Size box) {
    var w = _widthFactor != null ? math.max(0.0, _widthFactor! * box.width + (_width ?? 0)) : _width;
    var h = _heightFactor != null ? math.max(0.0, _heightFactor! * box.height + (_height ?? 0)) : _height;
    final r = _ratio != null && _ratio! > 0 ? _ratio : null;
    if (w == null && h == null) {
      if (r != null && box.width > 0 && box.height > 0) {
        // `contain`: the picture's shape, as large as the box holds.
        if (box.width / box.height > r) {
          h = box.height;
          w = h * r;
        } else {
          w = box.width;
          h = w / r;
        }
      } else {
        w = box.width;
        h = box.height;
      }
    } else if (w == null) {
      w = r != null ? h! * r : box.width;
    } else {
      h ??= r != null ? w / r : box.height;
    }
    // A side a share gives and the ratio the other: Blink holds that other
    // in layout units, 1/64 px with the rest dropped.
    if (r != null && (_widthFactor != null) != (_heightFactor != null)) {
      double lu(double v) => (v * 64 + 1e-6).floorToDouble() / 64;
      if (_widthFactor != null && _height == null) h = lu(h!);
      if (_heightFactor != null && _width == null) w = lu(w);
    }
    var tw = w, th = h!;
    // In Blink's layout units, 1/64 px: the room over the count with the
    // remainder dropped (a LayoutUnit division truncates). 300px of 7px
    // tiles is 43 of 6.96875, not of 6.9767 -- a third of a pixel short by
    // the last one, which is where Chrome draws them.
    double rounded(double room, double tile) =>
        ((room * 64 + 1e-6) / math.max(1, (room / tile).round())).floorToDouble() / 64;
    if (_roundX && tw > 0 && box.width > 0) {
      final k = rounded(box.width, tw) / tw;
      tw *= k;
      if (!_roundY && _height == null && _heightFactor == null) th *= k;
    }
    if (_roundY && th > 0 && box.height > 0) {
      final k = rounded(box.height, th) / th;
      th *= k;
      if (!_roundX && _width == null && _widthFactor == null) tw *= k;
    }
    final (gx, gy) = _spacing(box, tw, th);
    return Rect.fromLTWH(
      gx != null ? 0 : (box.width - tw) * _x + _dx,
      gy != null ? 0 : (box.height - th) * _y + _dy,
      tw,
      th,
    );
  }

  /// The room between two copies along each `space` axis the box holds two
  /// copies or more on, as many whole copies as the room holds and the room
  /// left over over the gaps between them, in 1/64 px with the remainder
  /// dropped; null on any other axis.
  (double?, double?) spacingOf(Size box) {
    final t = tileOf(box);
    return _spacing(box, t.width, t.height);
  }

  (double?, double?) _spacing(Size box, double w, double h) {
    double? gap(bool on, double room, double tile) {
      if (!on || tile <= 0) return null;
      final n = (room / tile + 1e-9).floor();
      if (n < 2) return null;
      return ((room - n * tile) * 64 / (n - 1) + 1e-6).floorToDouble() / 64;
    }

    return (gap(_spaceX, box.width, w), gap(_spaceY, box.height, h));
  }

  /// The tile's image: [child] painted into it at the device's pixel
  /// ratio, redrawn only when the child or the tile has changed -- into
  /// the corner of a [cell] the room after it bigger on a `space` axis.
  ui.Image? _tile(RenderBox child, Size tile, Size cell) {
    if (!_stale && _image != null && _imageOf == (cell, tile) && _imageAt == _dpr && _imageLuma == _luminance) {
      return _image;
    }
    _image?.dispose();
    _image = null;
    final pw = _raster(cell.width * _dpr).clamp(1, 1 << 12), ph = _raster(cell.height * _dpr).clamp(1, 1 << 12);
    final root = LayerHandle<TransformLayer>(
      TransformLayer(transform: Matrix4.diagonal3Values(pw / cell.width, ph / cell.height, 1)),
    );
    final context = _TileContext(root.layer!, Offset.zero & cell);
    context.paintChild(child, Offset.zero);
    context.finish();
    final scene = root.layer!.buildScene(ui.SceneBuilder());
    try {
      _image = scene.toImageSync(pw, ph);
    } finally {
      scene.dispose();
      root.layer = null;
    }
    if (_luminance) _image = _luma(_image!);
    _imageOf = (cell, tile);
    _imageAt = _dpr;
    _imageLuma = _luminance;
    _stale = false;
    return _image;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => false;

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {}

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null || size.isEmpty) return;
    final tile = tileOf(size);
    if (tile.isEmpty) return;
    // A `space`d axis repeats the tile and the room after it: one cell of
    // the pattern is the two.
    final (gx, gy) = _spacing(size, tile.width, tile.height);
    final cell = Size(tile.width + (gx ?? 0), tile.height + (gy ?? 0));
    if (child.needsCompositing) {
      _paintLive(context, offset, child, tile, cell, (gx, gy));
      return;
    }
    _live.layer = null;
    final image = _tile(child, tile.size, cell);
    if (image == null) return;
    // The box's corner and far corner on the page, each snapped to the
    // nearest CSS pixel (half up) as Blink snaps the box's paint rect before
    // the device scale: the tiles start at the one and are cut at both.
    final corner = localToGlobal(Offset.zero);
    double snap(double v) => (v + 0.5).floorToDouble();
    final left = snap(corner.dx) - corner.dx, top = snap(corner.dy) - corner.dy;
    final right = snap(corner.dx + size.width) - corner.dx, bottom = snap(corner.dy + size.height) - corner.dy;
    if (right <= left || bottom <= top) return;
    final matrix = Matrix4.translationValues(offset.dx + left + tile.left, offset.dy + top + tile.top, 0)
      ..scaleByDouble(cell.width / image.width, cell.height / image.height, 1, 1);
    // A `space` axis repeats where it holds two copies, and lays the tile
    // once where it does not, whatever `repeat` says.
    final rx = _spaceX ? gx != null : _repeatX, ry = _spaceY ? gy != null : _repeatY;
    final paint = Paint()
      ..shader = ImageShader(
        image,
        rx ? TileMode.repeated : TileMode.decal,
        ry ? TileMode.repeated : TileMode.decal,
        matrix.storage,
        filterQuality: _sampling(image, cell, _dpr),
      );
    if (_color case final c?) paint.colorFilter = ColorFilter.mode(c, _hole ? BlendMode.srcOut : BlendMode.srcIn);
    context.canvas.drawRect(
      Rect.fromLTRB(offset.dx + left, offset.dy + top, offset.dx + right, offset.dy + bottom),
      paint,
    );
  }

  /// [paint] for a child that composites ([RenderObject.needsCompositing]):
  /// a repaint boundary inside it repaints its own layer and marks nothing
  /// above it, so the child is painted into a [_TileLayer] of this box's,
  /// in the tree and live, which draws the tiles and rasterises the child's
  /// layers again whenever any of them has changed. The child is painted
  /// into it again only where it marked this box ([_stale]); else the layer
  /// is kept, its child layers repainting themselves.
  void _paintLive(
    PaintingContext context,
    Offset offset,
    RenderBox child,
    Rect tile,
    Size cell,
    (double?, double?) spacing,
  ) {
    _image?.dispose();
    _image = null;
    final corner = localToGlobal(Offset.zero);
    double snap(double v) => (v + 0.5).floorToDouble();
    final left = snap(corner.dx) - corner.dx, top = snap(corner.dy) - corner.dy;
    final right = snap(corner.dx + size.width) - corner.dx, bottom = snap(corner.dy + size.height) - corner.dy;
    if (right <= left || bottom <= top) {
      _live.layer = null;
      return;
    }
    final pw = _raster(cell.width * _dpr).clamp(1, 1 << 12), ph = _raster(cell.height * _dpr).clamp(1, 1 << 12);
    final layer = _live.layer ??= _TileLayer();
    final fresh = layer.firstChild == null || layer.drawn?.cell != cell;
    layer.draw((
      cell: cell,
      pw: pw,
      ph: ph,
      luminance: _luminance,
      rect: Rect.fromLTRB(offset.dx + left, offset.dy + top, offset.dx + right, offset.dy + bottom),
      origin: Offset(offset.dx + left + tile.left, offset.dy + top + tile.top),
      rx: _spaceX ? spacing.$1 != null : _repeatX,
      ry: _spaceY ? spacing.$2 != null : _repeatY,
      quality: (pw - cell.width * _dpr).abs() < 1e-6 && (ph - cell.height * _dpr).abs() < 1e-6
          ? FilterQuality.none
          : FilterQuality.low,
      color: _color,
      hole: _hole,
    ));
    if (_stale || fresh) {
      context.pushLayer(
        layer,
        (c, _) => c.paintChild(child, Offset.zero),
        offset,
        childPaintBounds: Offset.zero & cell,
      );
    } else {
      context.addLayer(layer);
    }
    _stale = false;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('width', _width))
      ..add(DoubleProperty('height', _height))
      ..add(DoubleProperty('ratio', _ratio))
      ..add(DoubleProperty('x', _x, defaultValue: 0))
      ..add(DoubleProperty('y', _y, defaultValue: 0))
      ..add(DoubleProperty('dx', _dx, defaultValue: 0))
      ..add(DoubleProperty('dy', _dy, defaultValue: 0))
      ..add(FlagProperty('repeatX', value: _repeatX, ifFalse: 'no-repeat x'))
      ..add(FlagProperty('repeatY', value: _repeatY, ifFalse: 'no-repeat y'))
      ..add(FlagProperty('roundX', value: _roundX, ifTrue: 'roundX'))
      ..add(FlagProperty('roundY', value: _roundY, ifTrue: 'roundY'))
      ..add(FlagProperty('spaceX', value: _spaceX, ifTrue: 'spaceX'))
      ..add(FlagProperty('spaceY', value: _spaceY, ifTrue: 'spaceY'))
      ..add(DoubleProperty('widthFactor', _widthFactor, defaultValue: null))
      ..add(DoubleProperty('heightFactor', _heightFactor, defaultValue: null))
      ..add(ColorProperty('color', _color, defaultValue: null))
      ..add(FlagProperty('hole', value: _hole, ifTrue: 'hole'))
      ..add(FlagProperty('luminance', value: _luminance, ifTrue: 'luminance'));
  }
}

/// A painting context of the tile's own, over a layer no page shows: the
/// child is painted into it and the layer drawn into the tile's image.
class _TileContext extends PaintingContext {
  _TileContext(super.containerLayer, super.estimatedBounds);

  void finish() => stopRecordingIfNeeded();
}

/// How a [_TileLayer] draws its tiles: its child layers rasterised into a
/// [cell] of [pw] by [ph] pixels (read by their light where [luminance]),
/// repeated from [origin] on each axis that repeats ([rx], [ry]) over
/// [rect], read with [quality], and painted in [color] where a mask.
typedef _TileDraw = ({
  Size cell,
  int pw,
  int ph,
  bool luminance,
  Rect rect,
  Offset origin,
  bool rx,
  bool ry,
  FilterQuality quality,
  Color? color,
  bool hole,
});

/// The layer of a [RenderPictureTile] whose child composites: the child's
/// layers are its children, kept in the tree so a repaint boundary inside
/// the child repaints into them, but never added to the scene where they
/// stand -- the layer adds its tiles instead, from an image of them drawn
/// as [RenderPictureTile._tile] draws one. Retained rendering adds it again
/// only where it or a layer under it changed, which is when the image is
/// drawn again. Nothing in it is hit or found: the tiles are a picture.
class _TileLayer extends ContainerLayer {
  _TileDraw? drawn;
  ui.Picture? _picture;

  /// Draw the tiles as [d] says, from the next frame on.
  void draw(_TileDraw d) {
    if (d == drawn) return;
    drawn = d;
    markNeedsAddToScene();
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    final d = drawn!;
    final inner = ui.SceneBuilder()
      ..pushTransform(Matrix4.diagonal3Values(d.pw / d.cell.width, d.ph / d.cell.height, 1).storage);
    addChildrenToScene(inner);
    inner.pop();
    final scene = inner.build();
    ui.Image image;
    try {
      image = scene.toImageSync(d.pw, d.ph);
    } finally {
      scene.dispose();
    }
    if (d.luminance) image = RenderPictureTile._luma(image);
    final matrix = Matrix4.translationValues(d.origin.dx, d.origin.dy, 0)
      ..scaleByDouble(d.cell.width / image.width, d.cell.height / image.height, 1, 1);
    final paint = Paint()
      ..shader = ImageShader(
        image,
        d.rx ? TileMode.repeated : TileMode.decal,
        d.ry ? TileMode.repeated : TileMode.decal,
        matrix.storage,
        filterQuality: d.quality,
      );
    if (d.color case final c?) paint.colorFilter = ColorFilter.mode(c, d.hole ? BlendMode.srcOut : BlendMode.srcIn);
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(d.rect, paint);
    _picture?.dispose();
    _picture = recorder.endRecording();
    image.dispose();
    final layer = builder.pushOffset(0, 0, oldLayer: engineLayer as ui.OffsetEngineLayer?);
    builder.addPicture(Offset.zero, _picture!);
    builder.pop();
    engineLayer = layer;
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, {required bool onlyFirst}) =>
      false;

  @override
  void dispose() {
    _picture?.dispose();
    _picture = null;
    super.dispose();
  }
}
