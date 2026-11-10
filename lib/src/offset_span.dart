/// A run of text painted off its place on the line: a relative offset.
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';

/// A run of text whose inline box is RELATIVELY POSITIONED (CSS 2.1 9.4.3,
/// `position: relative` with `top` or `left`): painted [offset] off the
/// place the line gives it, [dx] right and [dy] down, while the line keeps
/// that place. The offset is paint only -- the words round the box stay
/// where they are, and no line grows or shrinks for it -- so the span lays
/// out as the [TextSpan] it is, and an [OffsetSpans] round the paragraph
/// paints it moved. A `FloatText` paints the pieces on its lines moved
/// itself.
///
/// A footnote mark is the usual one: `sup { position: relative; top:
/// -0.5em; vertical-align: baseline }` keeps the line as tall as the text
/// round it and draws the mark half an em up --
/// `OffsetSpan(dy: -6, text: '1')` in 12px text. A `WidgetSpan` moved by a
/// `Transform` would move it too, but a placeholder is a paragraph of its
/// own, which takes the run out of the paragraph's text and is laid out
/// as a box: its own line height, rounded on its own.
class OffsetSpan extends TextSpan {
  const OffsetSpan({
    this.dx = 0,
    this.dy = 0,
    super.text,
    super.children,
    super.style,
    super.recognizer,
    super.mouseCursor,
    super.onEnter,
    super.onExit,
    super.semanticsLabel,
    super.locale,
    super.spellOut,
  });

  /// How far right the run is painted off its place (CSS `left`).
  final double dx;

  /// How far down the run is painted off its place (CSS `top`).
  final double dy;

  /// [dx] and [dy] together.
  Offset get offset => Offset(dx, dy);

  @override
  RenderComparison compareTo(InlineSpan other) {
    final result = super.compareTo(other);
    if (result == RenderComparison.layout || other is! OffsetSpan || other.offset == offset) return result;
    return result == RenderComparison.metadata || result == RenderComparison.identical ? RenderComparison.paint : result;
  }

  @override
  bool operator ==(Object other) => other is OffsetSpan && other.dx == dx && other.dy == dy && super == other;

  @override
  int get hashCode => Object.hash(super.hashCode, dx, dy);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('dx', dx, defaultValue: 0.0))
      ..add(DoubleProperty('dy', dy, defaultValue: 0.0));
  }
}

/// The paragraph the [OffsetSpan]s in it are painted off their places in.
///
/// Round a `Text.rich` -- and the boxes of one child each the line is set
/// in, a `LineBox` -- it finds the paragraph under it and paints it as it
/// is everywhere but where each [OffsetSpan] stands; then, for each, the
/// paragraph again moved by the span's offset, seen only through where the
/// span stood, moved with it. Each piece of a span is its box on its line:
/// across, its advance; down, the whole line. Layout, hit testing and the
/// paragraph's text are the child's own.
///
/// Where the paragraph cannot be painted twice -- a child with a layer of
/// its own, which a picture or a fade on a line may be -- or there is no
/// paragraph to find, the child is painted as it is.
class OffsetSpans extends SingleChildRenderObjectWidget {
  const OffsetSpans({super.key, super.child});

  @override
  RenderOffsetSpans createRenderObject(BuildContext context) => RenderOffsetSpans();
}

/// The render object behind [OffsetSpans].
class RenderOffsetSpans extends RenderProxyBox with ChildDryBaseline, KeptUnderHatch {
  RenderOffsetSpans({RenderBox? child}) : super(child);

  /// The paragraph: the child, or the one child of the boxes over it.
  RenderParagraph? get _paragraph {
    RenderObject? r = child;
    while (r != null && r is! RenderParagraph) {
      r = r is RenderObjectWithChildMixin<RenderBox> ? r.child : null;
    }
    return r is RenderParagraph ? r : null;
  }

  /// Each [OffsetSpan] of [p] with an offset, and its pieces, in the
  /// paragraph's own space.
  static List<(Offset, List<Rect>)> _pieces(RenderParagraph p) {
    final out = <(Offset, List<Rect>)>[];
    var at = 0;
    // Every span, in the order its code units are in the paragraph's text:
    // a placeholder is one.
    void walk(InlineSpan span) {
      final from = at;
      if (span is PlaceholderSpan) at += 1;
      if (span is TextSpan) {
        at += span.text?.length ?? 0;
        for (final c in span.children ?? const <InlineSpan>[]) {
          walk(c);
        }
      }
      if (span is OffsetSpan && span.offset != Offset.zero && at > from) {
        final boxes = p.getBoxesForSelection(
          TextSelection(baseOffset: from, extentOffset: at),
          boxHeightStyle: ui.BoxHeightStyle.max,
        );
        if (boxes.isNotEmpty) out.add((span.offset, [for (final b in boxes) b.toRect()]));
      }
    }

    walk(p.text);
    return out;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final p = _paragraph;
    final shift = p == null || !p.hasSize ? null : MatrixUtils.getAsTranslation(p.getTransformTo(this));
    final pieces = shift == null || needsCompositing ? const <(Offset, List<Rect>)>[] : _pieces(p!);
    if (pieces.isEmpty) {
      context.paintChild(child, offset);
      return;
    }
    paintMoved(context.canvas, offset + shift!, (offset & size).inflate(size.longestSide + 1e4), pieces, (by) {
      context.paintChild(child, offset + by);
    });
  }
}

/// Paints a paragraph with [paint] -- handed how far it is moved -- as it
/// is everywhere in [room] but where [pieces]' boxes stand, and then, for
/// each piece, again moved by its offset, seen only through its boxes moved
/// with it. The boxes are in the paragraph's own space, which starts at
/// [at] on the canvas. css_box's `FloatText` paints each of its lines so.
@internal
void paintMoved(
  Canvas canvas,
  Offset at,
  Rect room,
  List<(Offset, List<Rect>)> pieces,
  void Function(Offset by) paint,
) {
  // Everything but where the spans stand...
  final holes = Path();
  for (final (_, rects) in pieces) {
    for (final r in rects) {
      holes.addRect(r.shift(at));
    }
  }
  canvas
    ..save()
    ..clipPath(Path.combine(PathOperation.difference, Path()..addRect(room), holes));
  paint(Offset.zero);
  canvas.restore();
  // ...and each span where it is moved to.
  for (final (moved, rects) in pieces) {
    final seen = Path();
    for (final r in rects) {
      seen.addRect(r.shift(at + moved));
    }
    canvas
      ..save()
      ..clipPath(seen);
    paint(moved);
    canvas.restore();
  }
}
