/// An inline box's background painted inside its glyphs.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';

/// A run of text whose inline box has its background CLIPPED TO ITS TEXT
/// (css-backgrounds-4 2.3, `background-clip: text`): [background] is laid
/// out over the box and shows only inside the glyphs the box holds, under
/// the text itself -- which a page writes `color: transparent` over so that
/// it shows. The span lays out and paints as the [TextSpan] it is; a
/// [GlyphBackgrounds] round the paragraph paints the background.
///
/// AN INLINE BOX BROKEN OVER LINES IS LAID OUT AS ONE BOX FIRST and then
/// cut into its pieces (css-break-3 5.4, `box-decoration-break: slice`):
/// the background is laid over a strip as long as all the pieces set end
/// to end, and each line shows its own stretch of it, so a gradient runs on
/// from where the line above left it.
///
/// Each piece is the box's content area on its line: across, from its
/// first glyph to its last (the spaces a line ends in hang past it,
/// css-text-3 4.1.3); down, [ascent] above the line's baseline and
/// [descent] under it -- the box's face's, as the browser rounds them.
/// Null takes the face's own from the text on the line.
///
/// The background is laid over a TILE the strip's size, or a share of it
/// ([widthFactor], [heightFactor]) and a length on it ([width], [height]),
/// placed by [x] and [y] and moved on by [dx] and [dy]. Along an axis it
/// is [repeatX] (or [repeatY]) on, copies of it are laid end to end from
/// it both ways (css-backgrounds-3 3.4); along one it is not, nothing is
/// painted past it (3.4, `no-repeat`). Along one it is [roundX] (or
/// [roundY]) on, the tile is first scaled so a whole number of copies
/// fill the strip, and laid again and again (`round`) -- and the other
/// axis with it where [keepsRatio] says.
///
/// The box's BORDER, where it has one to see, is [border] wide on each
/// side in [borderColor], solid: painted round each piece's padding box
/// over the background and under the text, as the browser paints an
/// inline box's border (CSS 2.1 appendix E, step 7) -- its paint the
/// glyphs do not clip. A box broken over lines has its left side on its
/// first piece and its right one on its last (css-break-3 5.4, `slice`).
/// Its room across is not the span's: the line holds it outside.
class GlyphBackgroundSpan extends TextSpan {
  const GlyphBackgroundSpan({
    required this.background,
    this.ascent,
    this.descent,
    this.widthFactor = 1,
    this.heightFactor = 1,
    this.width = 0,
    this.height = 0,
    this.x = 0,
    this.y = 0,
    this.dx = 0,
    this.dy = 0,
    this.repeatX = false,
    this.repeatY = false,
    this.roundX = false,
    this.roundY = false,
    this.keepsRatio = false,
    this.border = EdgeInsets.zero,
    this.borderColor = const Color(0x00000000),
    super.text,
    super.children,
    super.style,
    super.locale,
  });

  /// The box's background: one gradient over the strip of its pieces.
  final Gradient background;

  /// The content area above the baseline and below it.
  final double? ascent, descent;

  /// The tile the background is laid out over, as a SHARE of the strip
  /// (`background-size: 300%`, css-backgrounds-3 3.9). A tile at least
  /// the strip covers it, and no copy of it shows (3.4): a product site's
  /// `Thinking...` is a gradient three times its width, its first third
  /// showing.
  final double widthFactor, heightFactor;

  /// Lengths added to the tile's shares: `calc(200% + 10px)` is a factor
  /// of 2 and a [width] of 10; a tile of a length alone is a factor of 0.
  final double width, height;

  /// Where the tile sits, as the share of the room left over that goes
  /// before it -- `background-position`'s own measure (3.6), where `0%`
  /// is against one edge and `100%` the other; as in `GradientBand`.
  final double x, y;

  /// A length the tile is moved on by from where [x] and [y] put it.
  final double dx, dy;

  /// Whether the tile is laid again and again along each axis.
  final bool repeatX, repeatY;

  /// Whether the tile is scaled to fit the strip a whole number of times
  /// along each axis, and laid again and again along it (3.4, `round`).
  final bool roundX, roundY;

  /// Whether, where one axis is [roundX] (or [roundY]) and the other is
  /// not, that other -- sized `auto` -- is scaled with the rounded one, to
  /// the ratio the tile had (3.9, the third step): a tile 45 across and
  /// the strip's 34 down, rounded to 39.328125 across, is 29.703125 down.
  final bool keepsRatio;

  /// The widths of the box's border on each side, and its one colour.
  final EdgeInsets border;
  final Color borderColor;

  /// The tile over a [strip] of the box's pieces set end to end.
  ///
  /// A `round` axis is the strip over the whole number of tiles nearest
  /// to fitting it, one at the least (3.9) -- in Blink's layout units, 64
  /// to the pixel, each division cut down to one: a 45px tile over a strip
  /// 118 across is three of 39.328125. The axis [keepsRatio] scales is
  /// the rounded one times the tile's own side on it, over the tile's own
  /// on the rounded one, each step cut down to a unit as Blink's are
  /// (`BackgroundImageGeometry`: multiplied, then divided).
  Rect tileOf(Rect strip) {
    var w = strip.width * widthFactor + width, h = strip.height * heightFactor + height;
    double units(double v) => (v * 64).floorToDouble() / 64;
    double rounded(double area, double tile) {
      if (area <= 0 || tile <= 0) return tile;
      final n = math.max(1, (units(area / tile) + 0.5).floor());
      return units(area / n);
    }

    if (roundX && strip.width > 0 && w > 0) {
      final r = rounded(strip.width, w);
      if (keepsRatio && !roundY) h = units(units(h * r) / w);
      w = r;
    }
    if (roundY && strip.height > 0 && h > 0) {
      final r = rounded(strip.height, h);
      if (keepsRatio && !roundX) w = units(units(w * r) / h);
      h = r;
    }
    return Rect.fromLTWH(strip.left + (strip.width - w) * x + dx, strip.top + (strip.height - h) * y + dy, w, h);
  }

  bool get _laidX => repeatX || roundX;
  bool get _laidY => repeatY || roundY;

  // Only the background differs: the paragraph is painted again, not laid
  // out again (and the widget round it with it).
  @override
  RenderComparison compareTo(InlineSpan other) {
    final result = super.compareTo(other);
    if (result == RenderComparison.paint || result == RenderComparison.layout) return result;
    final o = other as GlyphBackgroundSpan;
    return o.background == background &&
            o.ascent == ascent &&
            o.descent == descent &&
            o.widthFactor == widthFactor &&
            o.heightFactor == heightFactor &&
            o.width == width &&
            o.height == height &&
            o.x == x &&
            o.y == y &&
            o.dx == dx &&
            o.dy == dy &&
            o.repeatX == repeatX &&
            o.repeatY == repeatY &&
            o.roundX == roundX &&
            o.roundY == roundY &&
            o.keepsRatio == keepsRatio &&
            o.border == border &&
            o.borderColor == borderColor
        ? result
        : RenderComparison.paint;
  }

  @override
  bool operator ==(Object other) =>
      other is GlyphBackgroundSpan &&
      super == other &&
      other.background == background &&
      other.ascent == ascent &&
      other.descent == descent &&
      other.widthFactor == widthFactor &&
      other.heightFactor == heightFactor &&
      other.width == width &&
      other.height == height &&
      other.x == x &&
      other.y == y &&
      other.dx == dx &&
      other.dy == dy &&
      other.repeatX == repeatX &&
      other.repeatY == repeatY &&
      other.roundX == roundX &&
      other.roundY == roundY &&
      other.keepsRatio == keepsRatio &&
      other.border == border &&
      other.borderColor == borderColor;

  @override
  int get hashCode => Object.hash(
    super.hashCode,
    background,
    ascent,
    descent,
    widthFactor,
    heightFactor,
    width,
    height,
    x,
    y,
    dx,
    dy,
    repeatX,
    repeatY,
    roundX,
    roundY,
    keepsRatio,
    border,
    borderColor,
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<Gradient>('background', background))
      ..add(DoubleProperty('ascent', ascent, defaultValue: null))
      ..add(DoubleProperty('descent', descent, defaultValue: null))
      ..add(DoubleProperty('widthFactor', widthFactor, defaultValue: 1.0))
      ..add(DoubleProperty('heightFactor', heightFactor, defaultValue: 1.0))
      ..add(DoubleProperty('width', width, defaultValue: 0.0))
      ..add(DoubleProperty('height', height, defaultValue: 0.0))
      ..add(DoubleProperty('x', x, defaultValue: 0.0))
      ..add(DoubleProperty('y', y, defaultValue: 0.0))
      ..add(DoubleProperty('dx', dx, defaultValue: 0.0))
      ..add(DoubleProperty('dy', dy, defaultValue: 0.0))
      ..add(FlagProperty('repeatX', value: repeatX, ifTrue: 'repeatX'))
      ..add(FlagProperty('repeatY', value: repeatY, ifTrue: 'repeatY'))
      ..add(FlagProperty('roundX', value: roundX, ifTrue: 'roundX'))
      ..add(FlagProperty('roundY', value: roundY, ifTrue: 'roundY'))
      ..add(FlagProperty('keepsRatio', value: keepsRatio, ifTrue: 'keepsRatio'))
      ..add(DiagnosticsProperty<EdgeInsets>('border', border, defaultValue: EdgeInsets.zero))
      ..add(ColorProperty('borderColor', borderColor, defaultValue: const Color(0x00000000)));
  }
}

/// Paints the background of every [GlyphBackgroundSpan] in the paragraph
/// under it inside that span's own glyphs, under the text -- where the
/// browser paints an inline box's background, before the text on its
/// line (css-backgrounds-4 2.3).
///
/// The child is the paragraph, a [Text] or [RichText], under any boxes that
/// hold it alone and lay it out as they please (a [LineBox]); it lays out
/// and paints exactly as it would without this. For each piece of each
/// span, on its line, the background is laid over the piece's place in the
/// span's strip, cut to the piece's content area -- its edges snapped to
/// the nearest CSS pixel, half up, as Blink snaps a paint rect -- and kept
/// only inside THAT PIECE'S glyphs: a copy of the paragraph laid out the
/// same way, in which those glyphs alone are opaque. So the text of the
/// line above or below, which a tight line height lets into the piece, is
/// not painted with it, as the browser masks each piece with its own text.
///
/// The paragraph is set left to right and holds no placeholders: a copy
/// could not lay out a `WidgetSpan` as the paragraph did.
class GlyphBackgrounds extends SingleChildRenderObjectWidget {
  const GlyphBackgrounds({super.key, super.child});

  @override
  RenderGlyphBackgrounds createRenderObject(BuildContext context) => RenderGlyphBackgrounds(
    devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? View.of(context).devicePixelRatio,
  );

  @override
  void updateRenderObject(BuildContext context, RenderGlyphBackgrounds renderObject) {
    renderObject.devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? View.of(context).devicePixelRatio;
  }
}

/// One piece of a span on its line: the content area, the strip of the
/// span's pieces set end to end as it lies on this line (both in the
/// paragraph), and the mask.
class _Piece {
  _Piece(this.span, this.area, this.strip, this.mask, {required this.first, required this.last});
  final GlyphBackgroundSpan span;
  final Rect area, strip;
  final TextPainter mask;

  /// Whether the piece is the span's first, and its last.
  final bool first, last;

  /// The tile drawn once, for a tile that repeats, and the size and pixel
  /// ratio it was drawn at.
  ui.Image? image;
  (Size, double)? imageOf;
}

/// The render object behind [GlyphBackgrounds].
class RenderGlyphBackgrounds extends RenderProxyBox with ChildDryBaseline, KeptUnderHatch {
  RenderGlyphBackgrounds({RenderBox? child, double devicePixelRatio = 1}) : _dpr = devicePixelRatio, super(child);

  double _dpr;
  double get devicePixelRatio => _dpr;
  set devicePixelRatio(double v) {
    if (v == _dpr) return;
    _dpr = v;
    markNeedsPaint();
  }

  /// The tile [span] repeats, [size] across, drawn ONCE as Chrome draws a
  /// tile it repeats: on the next whole number of device pixels up, at
  /// least one, the gradient sampled at their centres (cc's
  /// `PaintShader::CreateScaledPaintRecord`, as `TileMask` draws its own).
  ui.Image _tileOf(_Piece piece, Size size) {
    final key = (size, _dpr);
    if (piece.image != null && piece.imageOf == key) return piece.image!;
    piece.image?.dispose();
    int raster(double v) => math.max(1, (v - 1e-6).ceil()).clamp(1, 1 << 14);
    final pw = raster(size.width * _dpr), ph = raster(size.height * _dpr);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pw / size.width, ph / size.height);
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = piece.span.background.createShader(rect));
    final picture = recorder.endRecording();
    piece.image = picture.toImageSync(pw, ph);
    picture.dispose();
    piece.imageOf = key;
    return piece.image!;
  }

  /// What [_pieces] were cut for: the paragraph's text and everything it
  /// is laid out with.
  Object? _cutFor;
  List<_Piece> _pieces = const [];

  /// The paragraph: the child, or the one child of the boxes over it.
  RenderParagraph? get _paragraph {
    RenderObject? r = child;
    while (r != null && r is! RenderParagraph) {
      r = r is RenderObjectWithChildMixin<RenderBox> ? r.child : null;
    }
    return r is RenderParagraph ? r : null;
  }

  static final _lit = TextStyle(foreground: Paint()..color = const Color(0xFF000000));
  static final _dark = TextStyle(foreground: Paint()..color = const Color(0x00000000));

  /// [style] painting nothing of its own: no glyphs (its runs say whether
  /// theirs are painted), no background, no shadow, no decoration. Only
  /// paint changes, so the text lays out as it did.
  static TextStyle _bare(TextStyle? style) => (style ?? const TextStyle()).copyWith(
    foreground: _dark.foreground,
    background: _dark.foreground,
    shadows: const [],
    decoration: TextDecoration.none,
  );

  /// [span] with only the glyphs of code units [a] to [b] opaque.
  static InlineSpan _only(InlineSpan span, int a, int b) {
    var at = 0;
    InlineSpan walk(InlineSpan span) {
      if (span is! TextSpan) return span;
      final kids = <InlineSpan>[];
      final t = span.text;
      if (t != null && t.isNotEmpty) {
        final from = at, to = at + t.length;
        at = to;
        final cuts = <int>{from, a.clamp(from, to), b.clamp(from, to), to}.toList()..sort();
        for (var i = 0; i + 1 < cuts.length; i++) {
          kids.add(
            TextSpan(
              text: t.substring(cuts[i] - from, cuts[i + 1] - from),
              style: cuts[i] >= a && cuts[i + 1] <= b ? _lit : _dark,
            ),
          );
        }
      }
      for (final c in span.children ?? const <InlineSpan>[]) {
        kids.add(walk(c));
      }
      return TextSpan(style: _bare(span.style), locale: span.locale, children: kids);
    }

    return walk(span);
  }

  /// A painter of [text] laid out as [p] lays out its own.
  static TextPainter _copy(RenderParagraph p, InlineSpan text) =>
      TextPainter(
        text: text,
        textAlign: p.textAlign,
        textDirection: p.textDirection,
        textScaler: p.textScaler,
        maxLines: p.maxLines,
        ellipsis: p.overflow == TextOverflow.ellipsis ? '\u2026' : null,
        locale: p.locale,
        strutStyle: p.strutStyle,
        textWidthBasis: p.textWidthBasis,
        textHeightBehavior: p.textHeightBehavior,
      )..layout(
        minWidth: p.constraints.minWidth,
        maxWidth: p.softWrap || p.overflow == TextOverflow.ellipsis ? p.constraints.maxWidth : double.infinity,
      );

  void _drop() {
    for (final piece in _pieces) {
      piece.mask.dispose();
      piece.image?.dispose();
    }
    _pieces = const [];
    _cutFor = null;
  }

  /// Every span's pieces, line by line.
  List<_Piece> _cut(RenderParagraph p) {
    final spans = <(GlyphBackgroundSpan, int, int)>[];
    var at = 0;
    // Every span, in the order its code units are in the paragraph's text
    // (`visitChildren` passes over a span with no text of its own, which
    // a span holding only children is).
    void walk(InlineSpan span) {
      final from = at;
      if (span is PlaceholderSpan) at += 1;
      if (span is TextSpan) {
        at += span.text?.length ?? 0;
        for (final c in span.children ?? const <InlineSpan>[]) {
          walk(c);
        }
      }
      if (span is GlyphBackgroundSpan) spans.add((span, from, at));
    }

    walk(p.text);
    if (spans.isEmpty) return const [];
    final plain = p.text.toPlainText(includeSemanticsLabels: false);
    final out = <_Piece>[];
    for (final (span, s, e) in spans) {
      if (e <= s) continue;
      final whole = _copy(p, _only(p.text, s, e));
      final cut = <(int, int, Rect)>[];
      for (final line in whole.computeLineMetrics()) {
        final range = whole.getLineBoundary(whole.getPositionForOffset(Offset(line.left, line.baseline)));
        final a = range.start < s ? s : range.start;
        var b = range.end > e ? e : range.end;
        // The spaces a line ends in hang past it, and a forced break is no
        // glyph: the piece ends at the line's last glyph.
        if (b == range.end) {
          while (b > a && (plain.codeUnitAt(b - 1) == 0x20 || plain.codeUnitAt(b - 1) == 0x0A)) {
            b--;
          }
        }
        if (b <= a) continue;
        final boxes = whole.getBoxesForSelection(
          TextSelection(baseOffset: a, extentOffset: b),
          boxHeightStyle: ui.BoxHeightStyle.tight,
        );
        if (boxes.isEmpty) continue;
        var r = boxes.first.toRect();
        for (final x in boxes.skip(1)) {
          r = r.expandToInclude(x.toRect());
        }
        final up = span.ascent, down = span.descent;
        if (up != null && down != null) r = Rect.fromLTRB(r.left, line.baseline - up, r.right, line.baseline + down);
        cut.add((a, b, r));
      }
      final length = cut.fold(0.0, (t, c) => t + c.$3.width);
      var before = 0.0;
      for (final (i, (a, b, r)) in cut.indexed) {
        final strip = Rect.fromLTWH(r.left - before, r.top, length, r.height);
        before += r.width;
        out.add(
          _Piece(
            span,
            r,
            strip,
            cut.length == 1 ? whole : _copy(p, _only(p.text, a, b)),
            first: i == 0,
            last: i == cut.length - 1,
          ),
        );
      }
      if (cut.length != 1) whole.dispose();
    }
    return out;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final p = _paragraph;
    if (p != null && p.hasSize && p.firstChild == null) {
      final key = (
        p.text,
        p.constraints,
        p.textAlign,
        p.textDirection,
        p.textScaler,
        p.maxLines,
        p.overflow,
        p.softWrap,
        p.locale,
        p.strutStyle,
        p.textWidthBasis,
        p.textHeightBehavior,
      );
      if (key != _cutFor) {
        _drop();
        _pieces = _cut(p);
        _cutFor = key;
      }
      final shift = MatrixUtils.getAsTranslation(p.getTransformTo(this));
      if (_pieces.isNotEmpty && shift != null) {
        final canvas = context.canvas;
        final at = offset + shift;
        // Where the paragraph is on the page, which the edges are snapped on.
        final page = localToGlobal(shift);
        double snap(double v) => (v + 0.5).floorToDouble();
        Rect snapped(Rect r) => Rect.fromLTRB(snap(r.left), snap(r.top), snap(r.right), snap(r.bottom));
        for (final piece in _pieces) {
          final cut = snapped(piece.area.shift(page)).shift(at - page);
          if (cut.isEmpty) continue;
          canvas
            ..save()
            ..clipRect(cut)
            ..saveLayer(cut, Paint());
          // THE TILE IS SIZED AND PLACED ON THE SNAPPED STRIP: Blink snaps
          // the background positioning area to whole pixels, each edge half
          // up on the page, before it sizes the tile on it and puts it
          // (BackgroundImageGeometry's snapped positioning area), and does
          // not snap the tile. Chrome, a 50% tile repeated over a box from
          // x 111.27 to 229.5: the area is 111 to 230, the tile 59.5, and
          // its copies meet at 170.5; a tile moved `10px` on a box from
          // 98.47 starts at 108 exactly. On a box broken over lines each
          // line's strip is snapped as it lies on that line.
          final span = piece.span;
          final tile = span.tileOf(snapped(piece.strip.shift(page))).shift(at - page);
          const e = 1e-6;
          if (tile.left <= cut.left + e &&
              tile.top <= cut.top + e &&
              tile.right >= cut.right - e &&
              tile.bottom >= cut.bottom - e) {
            // A tile that covers the piece is one gradient over all of it,
            // as the browser draws a single tile.
            canvas.drawRect(cut, Paint()..shader = span.background.createShader(tile));
          } else if (!span._laidX && !span._laidY) {
            // A tile laid once short of the piece is the gradient over the
            // tile, and nothing past it (3.4, `no-repeat`).
            final r = tile.intersect(cut);
            if (!r.isEmpty) canvas.drawRect(r, Paint()..shader = span.background.createShader(tile));
          } else if (!tile.isEmpty) {
            // A TILE THAT REPEATS is Chrome's pattern of it: the tile drawn
            // once on whole device pixels and laid again and again from
            // where it is put, read pixel for pixel where the tile is a
            // whole number of them and BILINEARLY where it is not -- the
            // raster scaled back down to the tile. Chrome, a 10-stripe
            // gradient over a tile 59.5 across from 111: the pixel from 116
            // to 117 is 0.953 of the first stripe, where the stripes meet
            // at 116.95 -- the raster's texels read, not the gradient at
            // the pixel's centre -- and the pixel at a seam at 170.5 half
            // of each copy. Along an axis it is not repeated on, it stops
            // at the tile (3.4).
            final image = _tileOf(piece, tile.size);
            final whole =
                (image.width - tile.width * _dpr).abs() < 1e-6 && (image.height - tile.height * _dpr).abs() < 1e-6;
            final matrix = Matrix4.translationValues(tile.left, tile.top, 0)
              ..scaleByDouble(tile.width / image.width, tile.height / image.height, 1, 1);
            final r = Rect.fromLTRB(
              span._laidX ? cut.left : math.max(cut.left, tile.left),
              span._laidY ? cut.top : math.max(cut.top, tile.top),
              span._laidX ? cut.right : math.min(cut.right, tile.right),
              span._laidY ? cut.bottom : math.min(cut.bottom, tile.bottom),
            );
            if (!r.isEmpty) {
              canvas.drawRect(
                r,
                Paint()
                  ..shader = ImageShader(
                    image,
                    TileMode.repeated,
                    TileMode.repeated,
                    matrix.storage,
                    filterQuality: whole ? FilterQuality.none : FilterQuality.low,
                  ),
              );
            }
          }
          canvas.saveLayer(cut, Paint()..blendMode = BlendMode.dstIn);
          piece.mask.paint(canvas, at);
          canvas
            ..restore()
            ..restore()
            ..restore();
          // THE BORDER round the padding box, snapped as the area is: the
          // ring between the two rects, one fill, as Blink fills a border
          // of one colour -- no seam where two sides meet.
          final b = span.border;
          if (b != EdgeInsets.zero && span.borderColor.a != 0) {
            final l = piece.first ? b.left : 0.0, r = piece.last ? b.right : 0.0;
            final ring = snapped(
              Rect.fromLTRB(
                piece.area.left - l,
                piece.area.top - b.top,
                piece.area.right + r,
                piece.area.bottom + b.bottom,
              ).shift(page),
            ).shift(at - page);
            final hole = Rect.fromLTRB(ring.left + l, ring.top + b.top, ring.right - r, ring.bottom - b.bottom);
            final ink = Paint()..color = span.borderColor;
            if (hole.width > 0 && hole.height > 0) {
              canvas.drawDRRect(
                RRect.fromRectAndRadius(ring, Radius.zero),
                RRect.fromRectAndRadius(hole, Radius.zero),
                ink,
              );
            } else {
              canvas.drawRect(ring, ink);
            }
          }
        }
      }
    }
    context.paintChild(child, offset);
  }

  @override
  void dispose() {
    _drop();
    super.dispose();
  }
}
