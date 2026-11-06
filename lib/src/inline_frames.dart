/// An inline box's background and border on every line it is on.
library;

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';

/// The text of an INLINE box that paints a frame -- a background, a border
/// -- round what it holds, where a line may break inside it: a `<code>`
/// chip of two words, a padded link, a ruled label in CJK.
///
/// CSS lays such a box out as text on the paragraph's lines (CSS 2.1 8.1,
/// 10.3.1, 10.6.1, 10.8.1): across, its margin, border and padding are room
/// before its first letter and after its last, which the span's own text
/// holds -- css_box's `edgeSpan`, at either end of [children]; down they
/// take no room, and the border and padding stand out over and under the
/// CONTENT AREA, the font's ascent above each line's baseline and its
/// descent below it ([ascent], [descent]).
///
/// BROKEN OVER LINES, the box is one fragment on each line (css-break-3
/// 5.4, `box-decoration-break: slice`): the first has the box's start
/// side, the last its end side, and the frame is painted as if the
/// fragments were set end to end and then cut apart -- a border is only on
/// the sides a fragment has, and a corner rounded only where the whole box
/// has it. An [InlineFrames] round the paragraph paints them.
///
/// The span lays out and paints its text as the [TextSpan] it is.
class InlineFrameSpan extends TextSpan {
  const InlineFrameSpan({
    required this.decoration,
    this.insets = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    required this.ascent,
    required this.descent,
    super.text,
    super.children,
    super.style,
    super.locale,
  });

  /// The background and the border, painted over each fragment's border
  /// box.
  final Decoration decoration;

  /// The border and the padding: how far the border box stands out from
  /// the content area over it and under it. The room they take across is
  /// the span's own text; only [EdgeInsets.top] and [EdgeInsets.bottom]
  /// are read.
  final EdgeInsets insets;

  /// The margin across, which the room at the span's ends holds too and
  /// which paints nothing: the first fragment's border box starts
  /// [EdgeInsets.left] after the span's first letter, and the last one's
  /// ends [EdgeInsets.right] before its last.
  final EdgeInsets margin;

  /// The content area: how far it reaches above a line's baseline and
  /// below it.
  final double ascent, descent;

  // Only the frame differs: the paragraph is painted again, not laid out
  // again.
  @override
  RenderComparison compareTo(InlineSpan other) {
    final result = super.compareTo(other);
    if (result == RenderComparison.paint || result == RenderComparison.layout) return result;
    final o = other as InlineFrameSpan;
    return o.decoration == decoration &&
            o.insets == insets &&
            o.margin == margin &&
            o.ascent == ascent &&
            o.descent == descent
        ? result
        : RenderComparison.paint;
  }

  @override
  bool operator ==(Object other) =>
      other is InlineFrameSpan &&
      super == other &&
      other.decoration == decoration &&
      other.insets == insets &&
      other.margin == margin &&
      other.ascent == ascent &&
      other.descent == descent;

  @override
  int get hashCode => Object.hash(super.hashCode, decoration, insets, margin, ascent, descent);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<Decoration>('decoration', decoration))
      ..add(DiagnosticsProperty<EdgeInsets>('insets', insets))
      ..add(DiagnosticsProperty<EdgeInsets>('margin', margin))
      ..add(DoubleProperty('ascent', ascent))
      ..add(DoubleProperty('descent', descent));
  }
}

/// Paints the frame of every [InlineFrameSpan] in the paragraph under it,
/// one fragment on each line the span is on, in the order the browser
/// paints them: a line's inline boxes' backgrounds and borders before the
/// text on that line and after the lines above it (CSS 2.1 appendix E),
/// the frames in the order of their spans.
///
/// Where no frame reaches up to the text of a line above its own, that is
/// every frame UNDER the paragraph, which paints as it does: the text of
/// the lines below a frame is painted after it both ways. Where one does
/// -- a tag padded up over the line above it -- the paragraph is painted
/// LINE BY LINE: each line's frames, then that line's text, from a copy of
/// the paragraph laid out the same way in which only that line's code
/// units are painted. Text reaches as far as its runs' content areas
/// (`BoxHeightStyle.tight`).
///
/// The child is the paragraph, a [Text] or [RichText], under any boxes that
/// hold it alone and lay it out as they please (a [LineBox]); it lays out
/// and paints exactly as it would without this.
///
/// Each fragment is the span's code units on one line: across, from where
/// the first of them starts to where the last ends -- but white space that
/// ends the line, which is no part of it (css-text-3 4.1.3) -- less the
/// margin at the box's two ends; down, the content area round that line's
/// baseline and the border and padding round that. Its edges are snapped
/// to the nearest CSS pixel, half up, as Blink snaps a paint rect (see
/// [InlineFrame]).
///
/// A LINE'S BASELINE is read off its boxes, as no line's metrics can be
/// from outside the paragraph: the top of its strut box, plus how far the
/// strut stands over the baseline in a line of the strut alone, plus how
/// far the line's tallest run starts under the line's top -- the top being
/// the bottom of the line before (`BoxHeightStyle.max`). So the paragraph
/// has a strut ([RenderParagraph.strutStyle]), and every line has text on
/// it, or no frame is painted.
///
/// Painted line by line, the paragraph holds nothing but text: no
/// placeholder, which a copy could not lay out as the paragraph did.
/// Where it does, the frames are painted under it.
class InlineFrames extends SingleChildRenderObjectWidget {
  const InlineFrames({super.key, super.child});

  @override
  RenderInlineFrames createRenderObject(BuildContext context) => RenderInlineFrames();
}

/// One fragment of a span on its line: its border box, and the strip the
/// whole box's frame is laid over, both in the paragraph; and the line, by
/// the top of its strut box.
class _Fragment {
  _Fragment(this.span, this.box, this.line);
  final InlineFrameSpan span;
  Rect box;
  Rect strip = Rect.zero;
  final double line;
}

/// One line of the paragraph: its baseline, and how far down its text
/// reaches -- from the top to the bottom of its runs' content areas.
typedef _Line = ({double baseline, double inkTop, double inkBottom});

/// A copy of the paragraph for each of its lines, in which only that
/// line's text is painted.
class _Lines {
  _Lines(this.key, this.painters);
  final Object key;
  final List<TextPainter> painters;

  void dispose() {
    for (final t in painters) {
      t.dispose();
    }
  }
}

/// The render object behind [InlineFrames].
class RenderInlineFrames extends RenderProxyBox with ChildDryBaseline, KeptUnderHatch {
  RenderInlineFrames({RenderBox? child}) : super(child);

  /// The paragraph: the child, or the one child of the boxes over it.
  RenderParagraph? get _paragraph {
    RenderObject? r = child;
    while (r != null && r is! RenderParagraph) {
      r = r is RenderObjectWithChildMixin<RenderBox> ? r.child : null;
    }
    return r is RenderParagraph ? r : null;
  }

  /// How far the paragraph's strut stands over a line's baseline, less how
  /// far its tallest run starts under the line's top, and how tall the strut
  /// is: a line of the strut alone, laid out as the paragraph is.
  ///
  /// The line holds one character the paragraph's face draws: a zero-width
  /// space -- or, in a face that has none (a face of digits alone, which
  /// stands a line all the same: `fixtures/partial-face-line-box`), a
  /// digit, then a letter. Skia makes no box of a character nothing draws.
  static (double, double)? _strut(RenderParagraph p) {
    final strut = p.strutStyle;
    if (strut == null || strut.fontSize == 0) return null;
    for (final probe in const ['\u200B', '0', 'x']) {
      final line = TextPainter(
        text: TextSpan(text: probe, style: p.text.style),
        textDirection: p.textDirection,
        textScaler: p.textScaler,
        locale: p.locale,
        strutStyle: strut,
        textHeightBehavior: p.textHeightBehavior,
      )..layout();
      try {
        const all = TextSelection(baseOffset: 0, extentOffset: 1);
        final boxes = line.getBoxesForSelection(all, boxHeightStyle: ui.BoxHeightStyle.strut);
        final tallest = line.getBoxesForSelection(all, boxHeightStyle: ui.BoxHeightStyle.max);
        final lines = line.computeLineMetrics();
        if (boxes.isEmpty || tallest.isEmpty || lines.isEmpty) continue;
        return (lines.first.baseline - boxes.first.top - tallest.first.top, boxes.first.bottom - boxes.first.top);
      } finally {
        line.dispose();
      }
    }
    return null;
  }

  static double _key(double top) => (top * 1000).roundToDouble() / 1000;

  /// Every line, by the top of its strut box; null where a line has no
  /// text on it to read.
  static Map<double, _Line>? _lines(RenderParagraph p, String plain) {
    final strut = _strut(p);
    if (strut == null) return null;
    final (rise, height) = strut;
    // Each line's strut top, the top and bottom of its tallest run, and
    // of its runs' content areas.
    final lines = <double, (double, double)>{};
    final ink = <double, (double, double)>{};
    var i = 0;
    while (i < plain.length) {
      while (i < plain.length && plain.codeUnitAt(i) == 0xFFFC) {
        i++;
      }
      var j = i;
      while (j < plain.length && plain.codeUnitAt(j) != 0xFFFC) {
        j++;
      }
      if (j > i) {
        final range = TextSelection(baseOffset: i, extentOffset: j);
        final struts = p.getBoxesForSelection(range, boxHeightStyle: ui.BoxHeightStyle.strut);
        final tallest = p.getBoxesForSelection(range, boxHeightStyle: ui.BoxHeightStyle.max);
        final tight = p.getBoxesForSelection(range);
        if (struts.length != tallest.length || struts.length != tight.length) return null;
        (double, double) union((double, double)? had, TextBox t) =>
            had == null ? (t.top, t.bottom) : (t.top < had.$1 ? t.top : had.$1, t.bottom > had.$2 ? t.bottom : had.$2);
        for (var k = 0; k < struts.length; k++) {
          final key = _key(struts[k].top);
          lines[key] = union(lines[key], tallest[k]);
          ink[key] = union(ink[key], tight[k]);
        }
      }
      i = j;
    }
    final out = <double, _Line>{};
    var top = 0.0;
    for (final key in lines.keys.toList()..sort()) {
      final (maxTop, maxBottom) = lines[key]!;
      final under = maxTop - top;
      // A line with no text on it is between: its height is at least the
      // strut's, which no run starts under a line's top by. Skia rounds a
      // line's height to the pixel, so its tallest run may start up to half
      // a pixel over the line's top.
      if (under < -0.5 || under >= height - 0.01) return null;
      final (inkTop, inkBottom) = ink[key]!;
      out[key] = (baseline: key + rise + under, inkTop: inkTop, inkBottom: inkBottom);
      top = maxBottom;
    }
    return out;
  }

  static bool _blank(int unit) => unit == 0x20 || unit == 0x0A || unit == 0x09 || unit == 0x0D;

  /// The top of the strut box of the line the code unit at [i] is on.
  static double? _lineOf(RenderParagraph p, int i) {
    final boxes = p.getBoxesForSelection(
      TextSelection(baseOffset: i, extentOffset: i + 1),
      boxHeightStyle: ui.BoxHeightStyle.strut,
    );
    return boxes.isEmpty ? null : _key(boxes.first.top);
  }

  /// Every span's fragments, line by line, in the paragraph's terms, and
  /// the paragraph's lines.
  static (List<_Fragment>, Map<double, _Line>) _cut(RenderParagraph p) {
    const none = (<_Fragment>[], <double, _Line>{});
    final spans = <(InlineFrameSpan, int, int)>[];
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
      if (span is InlineFrameSpan) spans.add((span, from, at));
    }

    walk(p.text);
    if (spans.isEmpty) return none;
    final plain = p.text.toPlainText(includeSemanticsLabels: false);
    final baselines = _lines(p, plain);
    if (baselines == null) return none;
    final out = <_Fragment>[];
    for (final (span, s, e) in spans) {
      // Each line's code units of the span, by the top of the line's strut
      // box -- but white space that ENDS a line, which is not on it
      // (css-text-3 4.1.3): white space is, where more of the paragraph
      // than white space follows it on its line.
      final lines = <double, (double, double)>{};
      var i = s;
      while (i < e) {
        final blank = _blank(plain.codeUnitAt(i));
        var j = i;
        while (j < e && _blank(plain.codeUnitAt(j)) == blank) {
          j++;
        }
        var on = !blank;
        if (blank) {
          var k = j;
          while (k < plain.length && _blank(plain.codeUnitAt(k))) {
            k++;
          }
          on = k < plain.length && _lineOf(p, i) == _lineOf(p, k);
        }
        if (on) {
          for (final b in p.getBoxesForSelection(
            TextSelection(baseOffset: i, extentOffset: j),
            boxHeightStyle: ui.BoxHeightStyle.strut,
          )) {
            final key = _key(b.top);
            final had = lines[key];
            lines[key] = had == null
                ? (b.left, b.right)
                : (b.left < had.$1 ? b.left : had.$1, b.right > had.$2 ? b.right : had.$2);
          }
        }
        i = j;
      }
      final tops = lines.keys.toList()..sort();
      for (final (k, top) in tops.indexed) {
        final (left, right) = lines[top]!;
        final baseline = baselines[top]?.baseline;
        if (baseline == null) return none;
        final box = Rect.fromLTRB(
          k == 0 ? left + span.margin.left : left,
          baseline - span.ascent - span.insets.top,
          k == tops.length - 1 ? right - span.margin.right : right,
          baseline + span.descent + span.insets.bottom,
        );
        if (box.width > 0) out.add(_Fragment(span, box, top));
      }
    }
    return (out, baselines);
  }

  /// Whether a frame reaches the text of a line ABOVE its own, which the
  /// browser paints before it. The text of a line below is painted after
  /// the frame both ways.
  static bool _reachesUp(List<_Fragment> fragments, Map<double, _Line> lines) {
    for (final f in fragments) {
      for (final MapEntry(key: top, value: l) in lines.entries) {
        if (top < f.line && f.box.top < l.inkBottom && f.box.bottom > l.inkTop) return true;
      }
    }
    return false;
  }

  /// [root] with only the code units from [from] to [to] painted: the rest
  /// lay out as they are and paint nothing -- no glyphs, no background, no
  /// shadow, no decoration. Null where it holds a placeholder or a span
  /// that paints itself.
  static InlineSpan? _showing(InlineSpan root, int from, int to) {
    final hidden = TextStyle(
      foreground: Paint()..color = const Color(0x00000000),
      background: Paint()..color = const Color(0x00000000),
      decoration: TextDecoration.none,
      shadows: const [],
    );
    var at = 0;
    var plain = true;
    InlineSpan walk(InlineSpan span) {
      if (span is! TextSpan || span.runtimeType != TextSpan && span is! InlineFrameSpan) {
        plain = false;
        return span;
      }
      final text = span.text ?? '';
      final start = at;
      at += text.length;
      final a = from.clamp(start, at), b = to.clamp(start, at);
      return TextSpan(
        style: span.style,
        locale: span.locale,
        spellOut: span.spellOut,
        children: [
          if (a > start) TextSpan(text: text.substring(0, a - start), style: hidden),
          if (b > a) TextSpan(text: text.substring(a - start, b - start)),
          if (at > b) TextSpan(text: text.substring(b - start), style: hidden),
          for (final c in span.children ?? const <InlineSpan>[]) walk(c),
        ],
      );
    }

    final out = walk(root);
    return plain ? out : null;
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

  _Lines? _laid;

  /// A copy of [p] for each of its lines, top to bottom, only that line's
  /// text painted; null where it cannot be copied so, or its lines are not
  /// [count].
  List<TextPainter>? _copies(RenderParagraph p, int count) {
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
    if (_laid case final l? when l.key == key) return l.painters.length == count ? l.painters : null;
    _laid?.dispose();
    _laid = null;
    final plain = p.text.toPlainText(includeSemanticsLabels: false);
    // Each line's code units, from where it starts to where the next one
    // does: its white space and the break that ends it are its own.
    final whole = _copy(p, p.text);
    final ranges = <(int, int)>[];
    try {
      var start = 0;
      while (start < plain.length) {
        final end = whole.getLineBoundary(TextPosition(offset: start)).end;
        if (end <= start) return null;
        ranges.add((start, end));
        start = end;
      }
    } finally {
      whole.dispose();
    }
    final painters = <TextPainter>[];
    for (final (from, to) in ranges) {
      final shown = _showing(p.text, from, to);
      if (shown == null) {
        for (final t in painters) {
          t.dispose();
        }
        return null;
      }
      painters.add(_copy(p, shown));
    }
    _laid = _Lines(key, painters);
    return painters.length == count ? painters : null;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final p = _paragraph;
    if (p != null && p.hasSize) {
      final (fragments, lines) = _cut(p);
      final shift = MatrixUtils.getAsTranslation(p.getTransformTo(this));
      if (fragments.isNotEmpty && shift != null) {
        final canvas = context.canvas;
        final at = offset + shift;
        // Where the paragraph is on the page, which the edges are snapped on.
        final page = localToGlobal(shift);
        double snap(double v) => (v + 0.5).floorToDouble();
        for (final f in fragments) {
          final g = f.box.shift(page);
          f.box = Rect.fromLTRB(snap(g.left), snap(g.top), snap(g.right), snap(g.bottom)).shift(-page);
        }
        // The strip each fragment is cut from: the box's fragments set end
        // to end, from where this one's predecessors would start.
        final spans = Map<InlineFrameSpan, List<_Fragment>>.identity();
        for (final f in fragments) {
          (spans[f.span] ??= []).add(f);
        }
        for (final group in spans.values) {
          final length = group.fold(0.0, (t, f) => t + f.box.width);
          var before = 0.0;
          for (final f in group) {
            f.strip = Rect.fromLTWH(f.box.left - before, f.box.top, length, f.box.height);
            before += f.box.width;
          }
        }
        void frame(_Fragment f) {
          if (f.box.isEmpty) return;
          final painter = f.span.decoration.createBoxPainter();
          final strip = f.strip.shift(at);
          canvas
            ..save()
            ..clipRect(f.box.shift(at));
          painter.paint(canvas, strip.topLeft, ImageConfiguration(size: strip.size, textDirection: p.textDirection));
          canvas.restore();
          painter.dispose();
        }

        final tops = lines.keys.toList()..sort();
        final copies = p.firstChild == null && _reachesUp(fragments, lines) ? _copies(p, tops.length) : null;
        if (copies != null) {
          // Line by line: its frames, then its text. The paragraph's own
          // text is all in the copies.
          for (final (i, top) in tops.indexed) {
            for (final f in fragments) {
              if (f.line == top) frame(f);
            }
            copies[i].paint(canvas, at);
          }
          return;
        }
        fragments.forEach(frame);
      }
    }
    context.paintChild(child, offset);
  }

  @override
  void dispose() {
    _laid?.dispose();
    _laid = null;
    super.dispose();
  }
}
