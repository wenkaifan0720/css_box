/// A line box that lets a word too wide for it overflow, whole.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';
import 'indent.dart';

/// The room a paragraph's lines are broken in.
///
/// A line box is as wide as its containing block, and a word wider than
/// that OVERFLOWS it: `overflow-wrap` is `normal` until a page says
/// otherwise, and CSS breaks text between words, never inside one
/// (css-text-3 5.5). A Flutter paragraph does the opposite -- Skia breaks
/// an over-long word wherever it runs out of room -- so a 48px column
/// holding `Unbreakable word` comes out seven lines tall where a browser
/// draws two and lets the first word hang past the edge.
///
/// This lays its child out at the child's own min-content width whenever
/// the room is narrower than that, and still reports the ROOM as its size,
/// which is the pair of facts CSS states: the box keeps its width, the
/// text spills out of it.
///
/// IT SPILLS OUT OF THE LINE'S END EDGE (css-text-3 7.1: the contents of a
/// line too long for it are start-aligned, and what does not fit overflows
/// the end edge), which under `rtl` is the LEFT one. A paragraph widened
/// past the box sets its lines against its own right edge, so under `rtl`
/// that edge is put on the box's: the lines that fit end at the box's
/// right edge, where CSS sets them, and the long word hangs out of the
/// left. Only lines set against the start edge land where CSS puts them
/// -- `start`, `right`, and `justify`'s last line -- so only those move.
///
/// It also keeps the lines as tall as CSS makes them. A paragraph under a
/// forced strut has every line exactly the strut's height, and Skia rounds
/// that height to a whole pixel -- `line-height: 1.4` at 18px is a 25.2px
/// line box in a browser (25.1875, on its 1/64 grid) and a 25px one in
/// Flutter, so five lines of it come out most of a pixel short and every
/// box under them rides up. Given the [lineHeight] CSS uses -- or the
/// [height] it is a number of -- this counts the child's lines and reports
/// that many of them.
class LineBox extends SingleChildRenderObjectWidget {
  const LineBox({
    super.key,
    this.keepWords = true,
    this.anywhere = false,
    this.lineHeight,
    this.height,
    this.ascent,
    this.grown,
    super.child,
  }) : assert(!anywhere || !keepWords, 'a word that breaks anywhere is not kept whole'),
       assert(lineHeight == null || height == null, 'a line height is a length or a number, not both');

  /// Whether a word too wide for the line overflows whole (`overflow-wrap:
  /// normal`). Where a page lets words break (`break-word`, `anywhere`) or
  /// the text never wraps, the child is laid out in the room it is given.
  final bool keepWords;

  /// Whether the places a word may break count toward the least width
  /// (`overflow-wrap: anywhere`, and the legacy `word-break: break-word`):
  /// the line's min-content is then its widest grapheme, not its widest
  /// word ([RenderLineBox.anywhere]). Only where words are not kept whole.
  final bool anywhere;

  /// The height of every line, in logical pixels, where the child's lines
  /// are all its forced strut's; null leaves the child's height alone. It is
  /// held on Blink's 1/64 grid ([RenderLineBox.lineHeight]).
  final double? lineHeight;

  /// The height of every line as a share of the text's font size, as
  /// [TextStyle.height] states one: CSS's `line-height: 1.25`, where the
  /// line follows the size. The line is the size of the child's text (its
  /// root span's [TextStyle.fontSize]) times this, cut down onto Blink's
  /// 1/64 grid as Blink cuts it ([RenderLineBox.height]). Null where the
  /// line is a [lineHeight], or left alone.
  final double? height;

  /// How much of the line the strut keeps ABOVE the baseline, as Blink
  /// splits it. Null leaves Skia's own rounded split alone.
  final double? ascent;

  /// The line a run in one of the [GrownLine]'s `styles` stands on, where the
  /// strut alone sets every other line at [lineHeight] over [ascent]: the
  /// runs reach past the strut, and a line box is the larger reach of the
  /// strut's and the runs' over the baseline and under it (CSS 2.1 10.8) --
  /// on the lines those runs are on, and nowhere else.
  ///
  /// A sans headline that ends in a serif standfirst, at `line-height:
  /// 1.3` on a 16px block: the serif reaches a pixel further under the
  /// baseline than the strut, so the lines holding it are 21.8 and the
  /// lines of headline alone 20.8. Told 21.8 for every line, a news site's
  /// story cards each stood a pixel taller than Chrome draws them.
  ///
  /// A run is IN a style where it is set as the style says as far as a
  /// line's height goes -- face, size, weight, slant, variations and its
  /// own line height -- whatever its paint: a link's colour is not a line.
  /// Where the lines cannot be read one by one -- a box on a line, a child
  /// with a layer of its own, no line or every line holding such a run --
  /// every line is the grown one.
  final GrownLine? grown;

  @override
  RenderLineBox createRenderObject(BuildContext context) => RenderLineBox(
    keepWords: keepWords,
    anywhere: anywhere,
    lineHeight: lineHeight,
    height: height,
    ascent: ascent,
    grown: grown,
  );

  @override
  void updateRenderObject(BuildContext context, RenderLineBox renderObject) {
    renderObject
      ..keepWords = keepWords
      ..anywhere = anywhere
      ..lineHeight = lineHeight
      ..height = height
      ..ascent = ascent
      ..grown = grown;
  }
}

/// The line box of a line a run in one of `styles` stands on: `lineHeight`
/// tall, `ascent` of it over the baseline ([LineBox.grown]).
typedef GrownLine = ({List<TextStyle> styles, double lineHeight, double ascent});

/// A paragraph's lines read each at its own height ([RenderLineBox._grownRead]).
typedef _Lines = ({double height, double drop, double below, List<double> moves, List<double> tops});

/// The render object behind [LineBox].
class RenderLineBox extends RenderProxyBox with DryLastBaseline, PassesBaseline, KeptUnderHatch {
  RenderLineBox({
    bool keepWords = true,
    bool anywhere = false,
    double? lineHeight,
    double? height,
    double? ascent,
    GrownLine? grown,
    RenderBox? child,
  }) : _keepWords = keepWords,
       _anywhere = anywhere,
       _lineHeight = _onGrid(lineHeight),
       _height = height,
       _ascent = ascent,
       _grown = grown,
       super(child);

  bool get keepWords => _keepWords;
  bool _keepWords;
  set keepWords(bool v) {
    if (v == _keepWords) return;
    _keepWords = v;
    markNeedsLayout();
  }

  /// A LINE THAT MAY BREAK A WORD ANYWHERE IS AS NARROW AS ITS WIDEST
  /// GRAPHEME. `overflow-wrap: anywhere` breaks a word too long for its
  /// line between any two of its grapheme clusters, and -- unlike
  /// `break-word` -- the soft wrap opportunities it brings are considered
  /// in the min-content size (css-text-3 5.5; the legacy `word-break:
  /// break-word` is `anywhere` with `word-break: normal`, 5.2). Blink
  /// measures min-content by breaking at every one of them, each piece as
  /// the run shaped it (`NGLineBreaker`, `kMinContent`). A paragraph's own
  /// least is its widest WORD (Skia's `minIntrinsicWidth`), so a
  /// fit-content box round `Cookie Preferences` in a 60px column stood at
  /// `Preferences`, 91.5 wide and two lines, where Chrome makes it 60 and
  /// breaks the word into three (`fixtures/shrink-line-text` n2: a product
  /// site's footer links). Laid out at no width at all, Skia puts one cluster
  /// on each line, measured where the run shaped it ([_anywhereFloor]); a
  /// widget on the line at its own least, as the paragraph asks it
  /// (`RenderParagraph.computeMinIntrinsicWidth`). A line laid out in a room
  /// breaks its words where it runs out of room either way, as Skia does: only
  /// the least width moves. NEGATIVE: `break-word` (the paragraph's own least),
  /// a text that never wraps (its line).
  bool get anywhere => _anywhere;
  bool _anywhere;
  set anywhere(bool v) {
    if (v == _anywhere) return;
    _anywhere = v;
    markNeedsLayout();
  }

  /// [LineBox.lineHeight] ON BLINK'S 1/64 GRID. Blink lays lines out in
  /// LayoutUnits, and a line height that is a length -- `110%` and `1.1em`
  /// compute to one (css-inline-3 4.1) -- goes onto that grid ROUNDED
  /// (`LayoutUnit::FromFloatRound`): `110%` of 32px is 35.2, and every line
  /// of it 35.203125. A line height that is a number of pixels comes here
  /// on the grid already; one that follows the window is worked out at
  /// layout, and was used as the 35.2 it came to -- a bank's two-line
  /// pricing heading, `110%` of a fluid size, lost 0.00625px at every phone
  /// width, which put the footnotes at 360, on y = n + 0.5 in Chrome, under
  /// the half pixel, and Skia drew every line of them a whole pixel high
  /// (`fixtures/text-fluid-line-grid`). A NUMBER is not a length: Blink
  /// TRUNCATES a number's share onto the grid, and rounded here it could
  /// stand a 64th over Blink's line ([height]).
  double? get lineHeight => _lineHeight;
  double? _lineHeight;
  set lineHeight(double? v) {
    final g = _onGrid(v);
    if (g == _lineHeight) return;
    _lineHeight = g;
    markNeedsLayout();
  }

  /// [LineBox.height]: A NUMBER'S LINE IS CUT DOWN ONTO BLINK'S GRID, NOT
  /// ROUNDED. Blink keeps `line-height: 1.25` as a percentage of the font
  /// size in a float, and lays the line out at the size -- rounded onto the
  /// 1/64 grid -- times it, over 100, each step in floats, the product cut
  /// down onto the grid (`LayoutUnit(float)` truncates;
  /// `ComputedStyle::ComputedLineHeightAsFixed`). Under a size that follows
  /// the window, `clamp(22px, 0.227vw + 21.274px, 24px)` at 390 is 22.159
  /// and `1.25` of it 27.699: 27.6875 in Blink, where rounded it was
  /// 27.703125, every line of a heading a 64th taller than Chrome's and the
  /// page under it lower by as much (`linebox_number_line_test`). The size
  /// is the child's own text's, as the line is the text's.
  double? get height => _height;
  double? _height;
  set height(double? v) {
    if (v == _height) return;
    _height = v;
    markNeedsLayout();
  }

  /// The line [height] makes of the child's text: null where the child is
  /// not a paragraph (there is no size to take a share of).
  double? get _numberLine {
    final n = _height, c = child;
    if (n == null || c is! RenderParagraph) return null;
    return _blinkNumberLine(n, c.text.style?.fontSize ?? kDefaultFontSize);
  }

  static final _f32 = Float32List(1);

  static double _float(double v) {
    _f32[0] = v;
    return _f32[0];
  }

  /// Blink's line for `line-height: [number]` at [size] px (see [height]).
  static double _blinkNumberLine(double number, double size) {
    final onGrid = (_float(size) * 64).roundToDouble() / 64;
    final percent = _float(number * 100);
    final line = _float(_float(onGrid * percent) / 100);
    return (line * 64).truncateToDouble() / 64;
  }

  /// Every line's height, as told: the [height]'s line where there is one,
  /// else the [lineHeight]. Null where neither is told.
  double? get line => _line;
  double? get _line => _height == null ? _lineHeight : _numberLine;

  /// The most two readings of one line can differ by where one is in
  /// doubles and the other in Skia's floats: a float's last bits at the
  /// heights a line comes to, far under anything a pixel shows.
  static const _floatNoise = 0.001;

  static double? _onGrid(double? v) => v == null || !v.isFinite ? v : (v * 64).roundToDouble() / 64;

  double? get ascent => _ascent;
  double? _ascent;
  set ascent(double? v) {
    if (v == _ascent) return;
    _ascent = v;
    markNeedsLayout();
  }

  /// See [LineBox.grown].
  GrownLine? get grown => _grown;
  GrownLine? _grown;
  set grown(GrownLine? v) {
    final g = _grown;
    if (v == null
        ? g == null
        : g != null && v.lineHeight == g.lineHeight && v.ascent == g.ascent && listEquals(v.styles, g.styles)) {
      return;
    }
    _grown = v;
    markNeedsLayout();
  }

  /// The line every line is told where the lines are not read one by one
  /// ([_grownRead]): the grown one where there is one, as the union of
  /// the strut and the runs reaching past it is on whichever line they
  /// are on.
  double? get _told => _grown == null ? _line : _onGrid(_grown!.lineHeight);
  double? get _toldAscent => _grown == null ? _ascent : _grown!.ascent;

  /// The box a child [height] tall with its first baseline at [baseline]
  /// stands in, and how far down in it the child sits.
  ///
  /// Skia lays every line out on whole pixels; CSS does not. A line box is
  /// the ASCENT it keeps above the baseline plus the DESCENT under it
  /// (CSS 2.1 10.8), each the larger of the strut's and what stands on the
  /// line, and Skia rounds the strut's pair before it adds them -- an
  /// 18.390625px line is drawn 18px tall and the 0.390625 comes off the
  /// ascent, which is why the same text sits 0.39px higher here than in a
  /// browser. Given the strut's own [ascent] the two halves go back
  /// together at the sizes CSS states them:
  ///
  ///  * A plain line: the baseline is the rounded ascent, so the box is the
  ///    unrounded one plus the strut's descent -- the whole line height.
  ///  * A line an atomic inline stretched from ABOVE (an empty badge, whose
  ///    baseline is its bottom margin edge): its ascent wins, and the
  ///    strut's fractional descent hangs under it.
  ///  * A line stretched from BELOW, or by a badge with a baseline of its
  ///    own inside it: the larger descent wins and the strut's ascent is
  ///    already covered, so nothing is put back.
  ///
  /// Whole lines are counted instead: a paragraph of [n] lines is n times
  /// the height CSS gives one, and only its FIRST baseline moves.
  (double, double) _box(double height, double? baseline) {
    final lh = _told;
    if (lh == null) return (height, 0);
    final skia = lh.roundToDouble();
    if (skia <= 0) return (height, 0);
    final a = _toldAscent;
    final drop = a == null || baseline == null || a <= baseline ? 0.0 : a - baseline;
    if (_plainLines(height, lh) case (final n, _)) {
      // Skia rounds the strut to the NEAREST pixel, so a plain line's
      // baseline is off by under half a pixel either way: a 25.2px line is
      // drawn 25 tall with its text 0.2 high, a 23.7px one 24 tall with its
      // text 0.3 LOW. Both are put back.
      //
      // A LINE DRAWN HIGH IS PUT BACK HOWEVER FAR. The ascent is the one
      // CSS gives the line, runs and all, and a run Skia sets shorter than
      // Blink does leaves the baseline where the strut alone put it: 14px
      // Helvetica has Apple's two extra pixels of ascent in Chrome and not
      // in Skia, and a portal's footer links sat a pixel high in their 20.5px
      // inline blocks -- which made every row round them 21
      // (`fixtures/inline-block-link-row`). Only a line drawn LOW is left
      // to Skia past half a pixel: that is a taller run this box is not
      // told of.
      final shift = a == null || baseline == null || a - baseline < -0.5 - _slack ? 0.0 : a - baseline;
      return (n * lh, shift);
    }
    // Past the first line there is no telling which of them the taller
    // thing is on, so a stretched line is only put back where it is the
    // only one.
    if (a == null || baseline == null || height >= 2 * skia) return (height, 0);
    final up = a > baseline ? a : baseline;
    final under = lh - a, left = height - baseline;
    return (up + (under > left ? under : left), drop);
  }

  /// How many lines a paragraph [height] tall is, and the whole pixels
  /// Skia drew each of them at, where every line is the strut's own of
  /// [lh]; null where they are not all the strut's.
  ///
  /// Skia rounds the strut's ascent and descent each on its own, so a line
  /// at a half pixel can come out the pixel BELOW as well: a 16.5px line
  /// of 11px text is drawn 16 tall, and read against 17 it was taken for
  /// a stretched line and handed back at 16 -- a news site's story cards, each
  /// half a pixel short in the stack.
  static (int, double)? _plainLines(double height, double lh) {
    final skia = lh.roundToDouble();
    if (skia <= 0) return null;
    var whole = skia;
    var n = (height / skia).round();
    if (!(n > 0 && (n * skia - height).abs() <= 0.01)) {
      for (final w in [lh.floorToDouble(), lh.ceilToDouble()]) {
        final k = w <= 0 ? 0 : (height / w).round();
        if (k > 0 && (k * w - height).abs() <= 0.01) {
          whole = w;
          n = k;
          break;
        }
      }
    }
    return n > 0 && (n * whole - height).abs() <= 0.01 ? (n, whole) : null;
  }

  /// The line box heights CSS gives a laid-out paragraph, read off the
  /// boxes Skia placed -- exact where [_box] can only guess.
  ///
  /// SKIA DRAWS EVERY LINE AT A WHOLE NUMBER OF PIXELS. It works the line
  /// out as CSS does -- the largest ascent anything on it asks for over
  /// the largest descent (CSS 2.1 10.8) -- and then rounds the sum, which
  /// takes the fraction off the ASCENT and leaves the descent where it
  /// was: a badge whose baseline sits 20.39px below its own top is drawn
  /// 0.39px ABOVE the top of its line, and the line comes out 28 where CSS
  /// makes it 28.39. Every wrapped line loses its own fraction again, and
  /// the height alone cannot say how much came off which line.
  ///
  /// The boxes still say. A `strut` box is placed against its line's own
  /// baseline and is the same height throughout, so the lines are what is
  /// left when they are gathered by it; the first line's `max` box, which
  /// is that line's ascent and descent around the same baseline, says
  /// where that baseline was drawn; and from there each ATOMIC INLINE's
  /// own box gives the two halves it asks of its line. A line Skia drew at
  /// the strut's own rounded height is a line nothing stretched, and CSS
  /// makes it [_lineHeight] whatever Skia's strut metrics say.
  ///
  /// Only a paragraph WITH a box on it needs this: a line of plain text is
  /// the strut's own height, which [_box] already has.
  ///
  /// The third number is how far below the baseline the paragraph ANSWERS
  /// Skia DRAWS its first line, and the fourth how far under the first
  /// baseline CSS puts the last (see [_read]).
  (double, double, double, double)? _exact(RenderBox child) {
    if (child is! RenderParagraph || child.childCount == 0) return null;
    return _read(
      child.text,
      (at, style) => child.getBoxesForSelection(at, boxHeightStyle: style),
      child.getDistanceToBaseline(TextBaseline.alphabetic, onlyReal: true),
      child.size.height,
    );
  }

  /// [_exact] asked BEFORE layout -- an intrinsic height, a dry layout, a
  /// dry baseline: the paragraph laid out again on a painter of its own,
  /// every box on it at its dry size, and the boxes read off that.
  ///
  /// A DRY ANSWER IS THE ONE LAYOUT WILL GIVE. Read off Skia's rounded
  /// height alone it cannot be: a 20.5px line Skia draws 21 tall is 21
  /// asked dry and 20.5 laid out, and a wrapping flex row sizes its line
  /// from the dry one and stretches every item on it to that --
  /// inline-block-link-row's 13px list came out 21 where Chrome's is 20.5.
  (double, double, double, double)? _dryExact(BoxConstraints constraints) {
    final child = this.child;
    if (_told == null || _toldAscent == null || child is! RenderParagraph || child.childCount == 0) return null;
    return onDryPainter<(double, double, double, double)?>(
      child,
      constraints,
      (painter) => _read(
        child.text,
        (at, style) => painter.getBoxesForSelection(at, boxHeightStyle: style),
        painter.computeDistanceToActualBaseline(TextBaseline.alphabetic),
        constraints.constrainHeight(painter.height),
      ),
    );
  }

  /// The line box heights and the drop of the first baseline, read off a
  /// laid-out paragraph's [boxes], its [first] baseline and its [height];
  /// and how far below [first] Skia drew that baseline.
  ///
  /// THE BASELINE A PARAGRAPH ANSWERS IS NOT THE ONE IT DRAWS ON: it
  /// answers the ascent its line asked for, and draws on the one the
  /// rounding left it (see below). The box's own baseline is the drawn one
  /// dropped by the drop -- where CSS puts it -- and a box that stands on
  /// ITS baseline in a line of its own was stood the rounding's fraction
  /// off it: `27<sup>th</sup>` glued in a placeholder is a 28.33px line on
  /// a 22.33 baseline Skia draws at 22, and answered 22.66 to the line
  /// round it, which came out 28.66.
  (double, double, double, double)? _read(
    InlineSpan text,
    List<TextBox> Function(TextSelection at, ui.BoxHeightStyle style) boxes,
    double? first,
    double height,
  ) {
    final lh = _told, a = _toldAscent;
    if (lh == null || a == null) return null;
    final plain = text.toPlainText(includeSemanticsLabels: false);
    final all = TextSelection(baseOffset: 0, extentOffset: plain.length);
    final struts = boxes(all, ui.BoxHeightStyle.strut);
    final tallest = boxes(all, ui.BoxHeightStyle.max);
    if (struts.isEmpty || tallest.isEmpty) return null;
    final strutTop = <double>[];
    final deep = struts.first.bottom - struts.first.top;
    for (final b in struts) {
      if ((b.bottom - b.top - deep).abs() > 0.01) return null;
      if (strutTop.isEmpty || (b.top - strutTop.last).abs() > 0.01) strutTop.add(b.top);
    }
    // WHERE THE FIRST LINE'S BASELINE WAS DRAWN. The paragraph answers the
    // ascent its line asked for, unrounded; its `max` box hangs that much
    // above the baseline the rounding left it on.
    if (first == null) return null;
    final drawn = tallest.first.top + first;
    final rise = drawn - strutTop.first;
    final n = strutTop.length;
    final up = List<double>.filled(n, a);
    final down = List<double>.filled(n, lh - a);
    // The height Skia drew each line at: the lines tile, each from the top
    // of the tallest box on it to the top of the next.
    //
    // NOT FROM ONE STRUT TO THE NEXT. A strut box hangs from its own line's
    // baseline, and a box that raises the baseline of a line under the
    // first moves that line's strut down by more than the line above it:
    // a browser maker's `CHOOSE A LANGUAGE` put its 44px select on a second
    // line, the struts came 55 apart, the 55px line was read as a plain 32, and
    // the list came out 64 where it is 87.
    final lineTop = List<double?>.filled(n, null);
    if (tallest.length == struts.length) {
      for (var k = 0; k < struts.length; k++) {
        final j = strutTop.indexWhere((t) => (t - struts[k].top).abs() <= 0.01);
        final top = tallest[k].top;
        if (j >= 0 && (lineTop[j] == null || top < lineTop[j]!)) lineTop[j] = top;
      }
    }
    final tops = lineTop.every((t) => t != null)
        ? [for (final t in lineTop) t!]
        : [for (final t in strutTop) t - strutTop.first];
    // WHERE EACH LINE'S BASELINE WAS DRAWN. A strut box hangs its strut's
    // ascent over its line's baseline -- less the fraction Skia's rounding
    // of THAT line's height put on the ascent, which is the `max` box's top
    // below where the line starts. The first line's baseline is known, and
    // gives the strut's ascent; a line under it has a fraction of its own.
    // Read as the first line's, `Trains leaving` over a `middle` `Oslo
    // every hour` -- a 25.625px second line drawn 26, 0.375 on its ascent
    // where the first line had none -- stood `Oslo` 0.375 higher on it than
    // it is, read it 0.375 deeper, and the line came out 26
    // (`fixtures/vertical-align-margin`).
    final lineEnd = List<double?>.filled(n, null);
    if (tallest.length == struts.length) {
      for (var k = 0; k < struts.length; k++) {
        final j = strutTop.indexWhere((t) => (t - struts[k].top).abs() <= 0.01);
        final bottom = tallest[k].bottom;
        if (j >= 0 && (lineEnd[j] == null || bottom > lineEnd[j]!)) lineEnd[j] = bottom;
      }
    }
    final List<double>? from;
    if (lineTop.every((t) => t != null) && lineEnd.every((b) => b != null)) {
      // Where Skia starts each line: under the one before, at that line's
      // `max` box height rounded.
      from = [0.0];
      for (var j = 1; j < n; j++) {
        from.add(from[j - 1] + (lineEnd[j - 1]! - lineTop[j - 1]!).roundToDouble());
      }
    } else {
      from = null;
    }
    double baseOf(int j) =>
        from == null ? strutTop[j] + rise : strutTop[j] + first - strutTop.first + (lineTop[j]! - from[j]);
    final drew = [for (var i = 0; i < n; i++) i < n - 1 ? tops[i + 1] - tops[i] : height - tops[i]];
    final plainLine = lh.roundToDouble();
    for (var i = 0; i < plain.length; i++) {
      if (plain.codeUnitAt(i) != 0xFFFC) continue;
      final at = boxes(TextSelection(baseOffset: i, extentOffset: i + 1), ui.BoxHeightStyle.tight);
      if (at.isEmpty) continue;
      final t = at.first.top, h = at.first.bottom - at.first.top;
      if (h <= 0) continue;
      // The line it stands on is the one whose baseline it holds: every
      // alignment a placeholder can take keeps the box across one.
      var line = 0, near = double.infinity;
      for (var j = 0; j < n; j++) {
        final base = baseOf(j);
        final off = base < t ? t - base : (base > t + h ? base - t - h : 0.0);
        if (off < near) {
          near = off;
          line = j;
        }
      }
      // A line Skia drew at the strut's own height is one this box did not
      // stretch, and the strut's CSS halves are the line.
      if ((drew[line] - plainLine).abs() < 0.01) continue;
      final base = baseOf(line);
      if (base - t > up[line]) up[line] = base - t;
      if (t + h - base > down[line]) down[line] = t + h - base;
    }
    var high = 0.0;
    for (var i = 0; i < n; i++) {
      high += up[i] + down[i];
    }
    // WHERE CSS PUTS THE LAST BASELINE: under the first by each line's
    // descent and the next one's ascent, as read here -- not where Skia
    // drew it, at its lines' heights rounded (see [RenderLineBox.below]).
    var below = 0.0;
    for (var i = 1; i < n; i++) {
      below += down[i - 1] + up[i];
    }
    // A LINE HOLDING NOTHING BUT A BOX OF NO SIZE IS STILL A LINE. An atomic
    // inline is in-flow content, so the line it stands on alone is a line
    // box as tall as its strut (CSS 2.1 9.4.2, 10.8), and Skia draws it --
    // but gives a 0x0 placeholder no box at all, so no strut box above
    // gathers that line. A docs site's headings end in a 0x0 `inline-block` link;
    // where `Conditional rendering` and its space fill the 292px line the
    // link wraps, Chrome's heading is 80 tall and this one answered 40, and
    // every box under two such headings rode up 80px at 360. Only the boxes
    // that END the paragraph are read so, and only a line Skia drew at the
    // strut's own height: anything else is left as it was.
    if (from != null && n > 0) {
      var end = plain.length;
      while (end > 0 &&
          plain.codeUnitAt(end - 1) == 0xFFFC &&
          boxes(TextSelection(baseOffset: end - 1, extentOffset: end), ui.BoxHeightStyle.tight).isEmpty) {
        end--;
      }
      if (end < plain.length) {
        final past = height - (from[n - 1] + (lineEnd[n - 1]! - lineTop[n - 1]!).roundToDouble());
        if ((past - plainLine).abs() < 0.5) {
          high += lh;
          below += down[n - 1] + a;
        }
      }
    }
    // Rounded to the nearest pixel, a line can be drawn LOWER than CSS
    // puts it too -- by under half a pixel, where the sum's fraction was a
    // half or more. Anything further down is a taller run of text the
    // boxes here do not see, and is left where Skia put it.
    final drop = up[0] - drawn;
    // A line with no text on it but the zero width space that holds a box
    // up has no taller run to leave alone: the space is set in the block's
    // own font, whose natural ascent Skia lets past the strut, and it
    // pushed a pricing page's 36px price box 1.16px down its 35.84px line.
    final boxesOnly = plain.codeUnits.every((c) => c == 0x200B || c == 0xFFFC);
    return (high, drop >= -0.5 - _slack || boxesOnly ? drop : 0.0, drawn - first, below);
  }

  /// EACH LINE AT ITS OWN HEIGHT where [grown] says which lines a taller
  /// run stands on: the lines holding a run in one of its styles are its
  /// line, every other the strut's ([LineBox.grown]). Skia's lines are read
  /// off the [boxes] it placed -- each line's `max` boxes span it top to
  /// bottom, and its `strut` boxes hang the strut's ascent over its
  /// baseline, the same on every line -- and its [first] baseline; each
  /// line is moved from where Skia drew its baseline to where CSS stacks
  /// it, under the lines above at their heights.
  ///
  /// The paragraph's height, how far its first baseline moves, how far
  /// under the first CSS puts the last, and how much further than the
  /// first each line moves, with the tops of Skia's lines. Null where the
  /// lines cannot be read so (see [LineBox.grown]), and where every line
  /// or none holds such a run: those are the grown line or the strut's on
  /// every line, as told.
  _Lines? _grownRead(
    InlineSpan text,
    List<TextBox> Function(TextSelection at, ui.BoxHeightStyle style) boxes,
    double? first,
  ) {
    final g = _grown, lh = _line, a = _ascent;
    if (g == null || lh == null || a == null || first == null) return null;
    final plain = text.toPlainText(includeSemanticsLabels: false);
    // A line with nothing on it -- between two breaks, before the first,
    // after the last -- has no box to read it by.
    if (plain.isEmpty ||
        plain.contains('\uFFFC') ||
        plain.contains('\n\n') ||
        plain.startsWith('\n') ||
        plain.endsWith('\n')) {
      return null;
    }
    final all = TextSelection(baseOffset: 0, extentOffset: plain.length);
    final lines = <(double, double)>[];
    for (final b in boxes(all, ui.BoxHeightStyle.max)) {
      final i = lines.indexWhere((l) => (l.$1 - b.top).abs() <= 0.01);
      if (i < 0) {
        lines.add((b.top, b.bottom));
      } else if (b.bottom > lines[i].$2) {
        lines[i] = (lines[i].$1, b.bottom);
      }
    }
    lines.sort((x, y) => x.$1.compareTo(y.$1));
    final n = lines.length;
    if (n < 2) return null;
    int lineOf(TextBox b) {
      final mid = (b.top + b.bottom) / 2;
      return lines.indexWhere((l) => mid >= l.$1 && mid < l.$2);
    }

    final strutTop = List<double?>.filled(n, null);
    for (final b in boxes(all, ui.BoxHeightStyle.strut)) {
      final k = lineOf(b);
      if (k < 0) return null;
      if (strutTop[k] == null) {
        strutTop[k] = b.top;
      } else if ((strutTop[k]! - b.top).abs() > 0.01) {
        return null;
      }
    }
    if (strutTop.contains(null)) return null;
    final on = List<bool>.filled(n, false);
    for (final (start, end) in _runsIn(text, g.styles)) {
      for (final b in boxes(TextSelection(baseOffset: start, extentOffset: end), ui.BoxHeightStyle.max)) {
        if (b.right - b.left <= 0) continue;
        final k = lineOf(b);
        if (k < 0) return null;
        on[k] = true;
      }
    }
    if (!on.contains(true) || !on.contains(false)) return null;
    final tall = _onGrid(g.lineHeight)!;
    final moves = <double>[];
    var top = 0.0;
    for (var k = 0; k < n; k++) {
      moves.add(top + (on[k] ? g.ascent : a) - (first + strutTop[k]! - strutTop[0]!));
      top += on[k] ? tall : lh;
    }
    final last = top - (on[n - 1] ? tall - g.ascent : lh - a);
    return (
      height: top,
      drop: moves[0],
      below: last - (on[0] ? g.ascent : a),
      moves: [for (final m in moves) m - moves[0]],
      // Where one line's cut ends and the next one's begins: halfway
      // between the bottom of the one's `max` box and the top of the
      // next's, which Skia's rounding can put either side of it.
      tops: [for (var k = 0; k < n; k++) k == 0 ? lines[0].$1 : (lines[k - 1].$2 + lines[k].$1) / 2],
    );
  }

  /// Where in [text] the runs set in one of [styles] are, as offsets into
  /// its plain text: each run's style is the styles of the spans round it
  /// laid over one another, and each of [styles] is laid over the
  /// paragraph's own, as a span's would be.
  static List<(int, int)> _runsIn(InlineSpan text, List<TextStyle> styles) {
    final root = const TextStyle().merge(text.style);
    final wanted = [for (final s in styles) root.merge(s)];
    final runs = <(int, int)>[];
    var at = 0;
    void walk(InlineSpan span, TextStyle round) {
      final style = round.merge(span.style);
      if (span is PlaceholderSpan) {
        at += 1;
      } else if (span is TextSpan) {
        final t = span.text;
        if (t != null && t.isNotEmpty) {
          if (wanted.any((w) => _sameLine(style, w))) runs.add((at, at + t.length));
          at += t.length;
        }
        for (final c in span.children ?? const <InlineSpan>[]) {
          walk(c, style);
        }
      }
    }

    walk(text, const TextStyle());
    return runs;
  }

  /// Whether [a] and [b] set a run's line alike: the face, its size, weight,
  /// slant and variations, and the run's own line height and its split.
  static bool _sameLine(TextStyle a, TextStyle b) =>
      a.fontFamily == b.fontFamily &&
      a.fontSize == b.fontSize &&
      a.fontWeight == b.fontWeight &&
      a.fontStyle == b.fontStyle &&
      a.height == b.height &&
      a.leadingDistribution == b.leadingDistribution &&
      listEquals(a.fontVariations, b.fontVariations);

  /// [_grownRead] of the laid-out [child], where it is painted all on its
  /// own canvas -- each line is painted on its own -- and holds no box.
  _Lines? _laidGrown(RenderBox child) {
    if (_grown == null || child is! RenderParagraph || child.childCount > 0 || child.isRepaintBoundary) return null;
    return _grownRead(
      child.text,
      (at, style) => child.getBoxesForSelection(at, boxHeightStyle: style),
      child.getDistanceToBaseline(TextBaseline.alphabetic, onlyReal: true),
    );
  }

  /// [_laidGrown] asked BEFORE layout, on a painter of its own, as
  /// [_dryExact] is.
  _Lines? _dryGrown(BoxConstraints constraints) {
    final child = this.child;
    if (_grown == null || child is! RenderParagraph || child.childCount > 0 || child.isRepaintBoundary) return null;
    return onDryPainter<_Lines?>(
      child,
      constraints,
      (painter) => _grownRead(
        child.text,
        (at, style) => painter.getBoxesForSelection(at, boxHeightStyle: style),
        painter.computeDistanceToActualBaseline(TextBaseline.alphabetic),
      ),
    );
  }

  /// How far a half pixel may miss: Skia answers a baseline in float32,
  /// and inline-flex-item-baseline's line drawn 0.5 low came back
  /// 0.5000134 low and was left there.
  static const _slack = 1e-3;

  /// The narrowest the text can be drawn without breaking a word: the
  /// widest stretch between two places a line may break (css-text-3 5).
  ///
  /// Skia's own answer misses one of those places. It breaks a line at a
  /// U+200B ZERO WIDTH SPACE, as CSS does -- it is what `<wbr>` is -- but
  /// measures the words either side of one as a single word, so a 95px
  /// column holding `Hamburger<zwsp>fontsiv` was widened to the whole run
  /// and drew it on one line. Broken at each one instead, the text's
  /// min-content is its longest piece.
  ///
  /// It misses the places between two ideographs too (UAX #14 LB31): it
  /// measures a run of Han as one word, the way ICU's word breaker reads
  /// Chinese it has no dictionary for, so a 100px box of
  /// `刊登廣告，關於我們` was widened to the whole run and drew it on one
  /// line. Broken there as well ([_ideographicBreak]), the floor is the
  /// longest piece Chrome keeps whole.
  ///
  /// A paragraph that never wraps -- `white-space: nowrap` or `pre` -- has
  /// no such places: its least width is its longest line (css-text-3 3),
  /// where Skia answers as though it wrapped.
  ///
  /// AND AN ATOMIC INLINE ON SUCH A LINE IS THERE AT ITS OWN LEAST WIDTH:
  /// the min-content of a box is the width its content takes with every
  /// box in it at ITS min-content contribution (css-sizing-3 5.1), which a
  /// line that never breaks lays end to end -- where Skia's longest line
  /// is every box at its greatest. A market tracker's `Prediction Markets`
  /// line, its words then an inline-block of `white-space: normal` holding
  /// two more, in a fit-content box its room is narrower than: the box
  /// stood 67.6, the block's words side by side, where Chrome narrows it
  /// to 53.6, the line's word and the block's longest (`fixtures/
  /// shrink-spill-room` n3). Only the least width: the room the line is
  /// laid out in stays its whole length ([_lineFloor]). An inline-block
  /// that resets no `white-space` never wraps either, and is there at its
  /// whole length ([_atomLeast]).
  double _floor() {
    final child = this.child;
    if (child == null) return 0.0;
    if (child is RenderParagraph && !child.softWrap) {
      if (!_holds(child.text)) return child.getMaxIntrinsicWidth(double.infinity);
      final painter =
          TextPainter(
              text: child.text,
              textDirection: child.textDirection,
              textScaler: child.textScaler,
              strutStyle: child.strutStyle,
              locale: child.locale,
              textWidthBasis: child.textWidthBasis,
              textHeightBehavior: child.textHeightBehavior,
            )
            // Only the widths count on one line; a baseline alignment is what
            // the spans of a lowered line carry (see [_textFloor]).
            ..setPlaceholderDimensions([
              for (var box = child.firstChild; box != null; box = child.childAfter(box))
                PlaceholderDimensions(
                  size: Size(_atomLeast(box), 0),
                  alignment: ui.PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  baselineOffset: 0,
                ),
            ])
            ..layout();
      final least = painter.maxIntrinsicWidth;
      painter.dispose();
      return least;
    }
    if (_anywhere && child is RenderParagraph) return _anywhereFloor(child);
    if (child is! RenderParagraph || !_breaksAtZwsp(child.text)) {
      return child.getMinIntrinsicWidth(double.infinity);
    }
    if (!identical(child.text, _floorOf) || child.textScaler != _floorScaler) {
      TextPainter painter(InlineSpan text) => TextPainter(
        text: text,
        textDirection: child.textDirection,
        textScaler: child.textScaler,
        strutStyle: child.strutStyle,
        locale: child.locale,
        textWidthBasis: child.textWidthBasis,
        textHeightBehavior: child.textHeightBehavior,
      )..layout();
      final broken = painter(_atZwsp(child.text));
      var floor = broken.minIntrinsicWidth;
      broken.dispose();
      // Skia kerns ACROSS a zero width space -- `v<zwsp>H` is as wide as
      // `vH` -- so the word before one takes more room on its line than it
      // measures alone, and at its own width breaks in two. Measured where
      // it stands, in the text laid out on one line:
      final whole = painter(child.text);
      final plain = child.text.toPlainText(includeSemanticsLabels: false);
      var start = 0;
      for (var i = 0; i < plain.length; i++) {
        final c = plain.codeUnitAt(i);
        if (c == 0x20 || c == 0x0A) start = i + 1;
        if (c != 0x200B) continue;
        final boxes = whole.getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: i + 1));
        if (boxes.isNotEmpty) {
          floor = math.max(
            floor,
            boxes.map((b) => b.right).reduce(math.max) - boxes.map((b) => b.left).reduce(math.min),
          );
        }
        start = i + 1;
      }
      whole.dispose();
      _floorValue = floor;
      _floorOf = child.text;
      _floorScaler = child.textScaler;
    }
    return _floorValue;
  }

  /// [_floor] where a word breaks [anywhere]: the widest line the paragraph
  /// [child] comes to laid out at no width -- one grapheme cluster, or one
  /// widget at its own least, a line.
  double _anywhereFloor(RenderParagraph child) {
    final painter =
        TextPainter(
            text: child.text,
            textDirection: child.textDirection,
            textScaler: child.textScaler,
            strutStyle: child.strutStyle,
            locale: child.locale,
            textWidthBasis: child.textWidthBasis,
            textHeightBehavior: child.textHeightBehavior,
          )
          ..setPlaceholderDimensions([
            for (var box = child.firstChild; box != null; box = child.childAfter(box))
              PlaceholderDimensions(
                size: Size(box.getMinIntrinsicWidth(double.infinity), 0),
                alignment: ui.PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                baselineOffset: 0,
              ),
          ])
          ..layout(maxWidth: 0);
    final floor = painter.computeLineMetrics().fold(0.0, (w, line) => math.max(w, line.width));
    painter.dispose();
    return floor;
  }

  /// The least width of the atomic inline [box] on a line that never
  /// breaks: its own min-content (css-sizing-3 5.1) -- and where all it
  /// holds is a paragraph that never wraps, its greatest, where Skia
  /// answers that paragraph's least as though it wrapped, as for the line's
  /// own words above. Through boxes of one child (the scale a `WidgetSpan`
  /// is wrapped in, a key's, a colour's, a padding, a clamp), nothing in it
  /// may break, so nothing in it is narrower than at its greatest. The
  /// inline-block of `fixtures/inline-block-alone-measured` n2 inherits its
  /// line's `nowrap`: `Hot stocks` is one piece, and the line's least width
  /// its greatest. NEGATIVE: a block whose words wrap (`white-space:
  /// normal`, a `LineBox` that wraps), at its longest word; a box of
  /// several children, at its own least.
  static double _atomLeast(RenderBox box) {
    RenderObject? inner = box;
    while (inner is RenderObjectWithChildMixin<RenderBox>) {
      inner = inner.child;
    }
    if (inner is RenderParagraph && !inner.softWrap) return box.getMaxIntrinsicWidth(double.infinity);
    return box.getMinIntrinsicWidth(double.infinity);
  }

  InlineSpan? _floorOf;
  TextScaler? _floorScaler;
  double _floorValue = 0;

  /// The narrowest room the line may be laid out in: the width below
  /// which Skia would break a WORD.
  ///
  /// AN ATOMIC INLINE IS NOT A WORD. A line box is as wide as its
  /// containing block, and an inline-block, an image or a button wider
  /// than that HANGS OUT of it (CSS 2.1 9.4.2, 10.3.2) -- the line does not
  /// grow to hold it. Only text is kept whole here, and only because Skia
  /// breaks text in a place CSS does not. Counted as a word, a news site's
  /// `display: inline-block; width: 100%` wrapper widened its line to the
  /// 452 its content wants and then took 100% OF THAT in a 390px phone,
  /// and all but 7 of the page's 1,183 boxes moved
  /// (`fixtures/inline-block-content-overflows`).
  ///
  /// This is NOT the box's min-content width, which an atomic inline is
  /// part of like anything else on the line: `width: min-content` around a
  /// row of icons is as wide as the icons (`computeMinIntrinsicWidth`
  /// answers [_floor]).
  ///
  /// [room] is the width the line is laid out in, which a line that never
  /// wraps counts its atomic inlines against ([_hungLength]).
  double _lineFloor([double room = double.infinity]) {
    final child = this.child;
    if (child is RenderParagraph && child.softWrap && _holds(child.text)) return _textFloor(child);
    // A line that never wraps is laid out at its whole length, and hangs
    // out of a box narrower than that.
    if (child is RenderParagraph && !child.softWrap) return _hungLength(child, room);
    return _floor();
  }

  /// The whole length of [child], a line that never wraps, laid out in
  /// [room]: its words end to end, and each atomic inline at the width it
  /// has THERE.
  ///
  /// THE LINE NOT WRAPPING DOES NOT WIDEN ITS BLOCK. An inline-block of
  /// `width: auto` is shrink-to-fit against its containing block --
  /// min(max(min-content, available), max-content), the available width
  /// the block's, not what is left of the line (CSS 2.1 10.3.9, 10.3.5) --
  /// so one that wraps its own words again (`white-space: normal` on a
  /// `nowrap` line) is no wider than the block where its words are longer
  /// than that. Counted at its greatest, the line was laid out that long
  /// and the block handed it all: a store's answer cards are `inline-grid`
  /// boxes on the `nowrap` line of a carousel slide, and each came out as
  /// wide as its answer on one line -- 1423 in a 330 slide: its words ran
  /// out of the card under its clip, the longest answer's card stood at
  /// its floor, and the carousel and the page under it were 10.7px short
  /// (`linebox_nowrap_atom_room_test`). Only the
  /// atoms: words that never wrap are their whole length whatever the room.
  /// Where the line is longer than its room all the same, the atoms are
  /// handed that length as before.
  double _hungLength(RenderParagraph child, double room) {
    if (!room.isFinite || !_holds(child.text)) return child.getMaxIntrinsicWidth(double.infinity);
    final painter =
        TextPainter(
            text: child.text,
            textDirection: child.textDirection,
            textScaler: child.textScaler,
            strutStyle: child.strutStyle,
            locale: child.locale,
            textWidthBasis: child.textWidthBasis,
            textHeightBehavior: child.textHeightBehavior,
          )
          ..setPlaceholderDimensions([
            for (var box = child.firstChild; box != null; box = child.childAfter(box))
              PlaceholderDimensions(
                size: Size(math.min(math.max(_atomLeast(box), room), box.getMaxIntrinsicWidth(double.infinity)), 0),
                alignment: ui.PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                baselineOffset: 0,
              ),
          ])
          ..layout();
    final whole = painter.maxIntrinsicWidth;
    painter.dispose();
    return whole;
  }

  /// The min-content width of [child]'s TEXT, with every atomic inline in
  /// it taken as nothing.
  double _textFloor(RenderParagraph child) {
    if (identical(child.text, _textFloorOf) && child.textScaler == _textFloorScaler) return _textFloorValue;
    var n = 0;
    child.text.visitChildren((span) {
      if (span is PlaceholderSpan) n++;
      return true;
    });
    final painter =
        TextPainter(
            // Every atomic inline is nothing here, so what breaks the text is
            // what breaks it with none: a zero width space, an ideograph.
            text: _breaksAnywhere(child.text) ? _atZwsp(child.text) : child.text,
            textDirection: child.textDirection,
            textScaler: child.textScaler,
            strutStyle: child.strutStyle,
            locale: child.locale,
            textWidthBasis: child.textWidthBasis,
            textHeightBehavior: child.textHeightBehavior,
          )
          // A baseline alignment is what the spans of a lowered line carry,
          // and `addPlaceholder` asserts one is given for it.
          ..setPlaceholderDimensions(
            List.filled(
              n,
              const PlaceholderDimensions(
                size: Size.zero,
                alignment: ui.PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                baselineOffset: 0,
              ),
            ),
          )
          ..layout();
    _textFloorValue = painter.minIntrinsicWidth;
    painter.dispose();
    _textFloorOf = child.text;
    _textFloorScaler = child.textScaler;
    return _textFloorValue;
  }

  InlineSpan? _textFloorOf;
  TextScaler? _textFloorScaler;
  double _textFloorValue = 0;

  /// Whether [text] holds an atomic inline.
  static bool _holds(InlineSpan text) {
    var any = false;
    text.visitChildren((span) {
      if (span is PlaceholderSpan) any = true;
      return !any;
    });
    return any;
  }

  static bool _breaksAtZwsp(InlineSpan text) {
    var zwsp = false, placeholder = false;
    text.visitChildren((span) {
      if (span is PlaceholderSpan) placeholder = true;
      if (span is TextSpan && (span.text?.contains('\u200B') ?? false)) zwsp = true;
      return !placeholder;
    });
    return (zwsp || _breaksIdeographs(text.toPlainText(includeSemanticsLabels: false))) && !placeholder;
  }

  /// [text], with a hard break at every zero width space and at every
  /// place a line breaks beside an ideograph ([_ideographicBreak]),
  /// across the spans as well as inside them.
  static InlineSpan _atZwsp(InlineSpan text) {
    int? last;
    InlineSpan broken(InlineSpan span) {
      if (span is! TextSpan) {
        last = null;
        return span;
      }
      String? out;
      if (span.text case final t?) {
        final b = StringBuffer();
        for (final r in t.runes) {
          if (r == 0x200B) {
            b.write('\n');
            last = null;
            continue;
          }
          if (last != null && _ideographicBreak(last!, r)) b.write('\n');
          b.writeCharCode(r);
          last = r;
        }
        out = b.toString();
      }
      return TextSpan(text: out, style: span.style, locale: span.locale, children: span.children?.map(broken).toList());
    }

    return broken(text);
  }

  /// Whether a line may break between [a] and [b] for an ideograph beside
  /// them: after one, unless [b] may not start a line or [a] may not end
  /// one; before one, after a letter or a digit. What the engine breaks at
  /// (`compute/inline.dart`), which is Chrome's under `word-break:
  /// normal`. A word joiner (U+2060) on either side holds the two
  /// together, and a space is Skia's own break already.
  static bool _ideographicBreak(int a, int b) {
    if (a == 0x2060 || b == 0x2060 || a == 0x20 || b == 0x20 || a == 0x0A || b == 0x0A) return false;
    if (_cjk(a)) return !_noBreakAfter(a) && !_noBreakBefore(b);
    return _cjk(b) && !_noBreakAfter(a);
  }

  /// Whether [text] holds a zero width space or a place
  /// [_ideographicBreak] breaks at, atomic inlines or not.
  static bool _breaksAnywhere(InlineSpan text) {
    final plain = text.toPlainText(includeSemanticsLabels: false);
    return plain.contains('\u200B') || _breaksIdeographs(plain);
  }

  /// Whether [text] holds a place [_ideographicBreak] breaks at.
  static bool _breaksIdeographs(String text) {
    int? last;
    for (final r in text.runes) {
      if (last != null && _ideographicBreak(last, r)) return true;
      last = r;
    }
    return false;
  }

  static bool _cjk(int r) =>
      (r >= 0x4E00 && r <= 0x9FFF) ||
      (r >= 0x3400 && r <= 0x4DBF) ||
      (r >= 0x3040 && r <= 0x30FF) ||
      (r >= 0xAC00 && r <= 0xD7AF) ||
      (r >= 0xF900 && r <= 0xFAFF) ||
      (r >= 0xFF00 && r <= 0xFFEF);

  /// Closing brackets, commas, full stops, the small kana and the other
  /// glyphs a line may not begin with (UAX #14 CL, CP, EX, IS, NS).
  static bool _noBreakBefore(int r) =>
      r == 0x29 ||
      r == 0x5D ||
      r == 0x7D ||
      r == 0x2C ||
      r == 0x2E ||
      r == 0x21 ||
      r == 0x3F ||
      r == 0x3A ||
      r == 0x3B ||
      r == 0x25 ||
      r == 0x3001 ||
      r == 0x3002 ||
      r == 0x3005 ||
      r == 0x3009 ||
      r == 0x300B ||
      r == 0x300D ||
      r == 0x300F ||
      r == 0x3011 ||
      r == 0x3015 ||
      r == 0x3017 ||
      r == 0x3019 ||
      r == 0x301B ||
      r == 0x301C ||
      r == 0x301E ||
      r == 0x301F ||
      r == 0x3041 ||
      r == 0x3043 ||
      r == 0x3045 ||
      r == 0x3047 ||
      r == 0x3049 ||
      r == 0x3063 ||
      r == 0x3083 ||
      r == 0x3085 ||
      r == 0x3087 ||
      r == 0x308E ||
      r == 0x3095 ||
      r == 0x3096 ||
      r == 0x309B ||
      r == 0x309C ||
      r == 0x309D ||
      r == 0x309E ||
      r == 0x30A1 ||
      r == 0x30A3 ||
      r == 0x30A5 ||
      r == 0x30A7 ||
      r == 0x30A9 ||
      r == 0x30C3 ||
      r == 0x30E3 ||
      r == 0x30E5 ||
      r == 0x30E7 ||
      r == 0x30EE ||
      r == 0x30F5 ||
      r == 0x30F6 ||
      r == 0x30FB ||
      r == 0x30FC ||
      r == 0x30FD ||
      r == 0x30FE ||
      r == 0xFF01 ||
      r == 0xFF05 ||
      r == 0xFF09 ||
      r == 0xFF0C ||
      r == 0xFF0E ||
      r == 0xFF1A ||
      r == 0xFF1B ||
      r == 0xFF1F ||
      r == 0xFF3D ||
      r == 0xFF5D ||
      r == 0xFF60 ||
      r == 0xFF61 ||
      r == 0xFF63 ||
      r == 0xFF64 ||
      r == 0xFF65 ||
      (r >= 0xFF67 && r <= 0xFF70) ||
      r == 0xFF9E ||
      r == 0xFF9F;

  /// Opening brackets, which a line may not end with (UAX #14 OP).
  static bool _noBreakAfter(int r) =>
      r == 0x28 ||
      r == 0x5B ||
      r == 0x7B ||
      r == 0x3008 ||
      r == 0x300A ||
      r == 0x300C ||
      r == 0x300E ||
      r == 0x3010 ||
      r == 0x3014 ||
      r == 0x3016 ||
      r == 0x3018 ||
      r == 0x301A ||
      r == 0x301D ||
      r == 0xFF08 ||
      r == 0xFF3B ||
      r == 0xFF5B ||
      r == 0xFF5F ||
      r == 0xFF62;

  /// [ask], a question about the paragraph this box holds, asked through
  /// the hatch where Flutter's proxies assert ([guardedWhereProxiesAssert]).
  /// Every size and baseline this box works out of its child is asked so --
  /// the room its lines break in, which it asks in layout too -- since a
  /// paragraph asked a size asks a baseline of each box standing on its
  /// baseline, and from Flutter 3.41 to 3.47 one with none asserts there.
  /// On every other Flutter it is asked as it always was, so a debug build
  /// sets the line as a release build does.
  T _asked<T>(T Function() ask) {
    final child = this.child;
    return child == null ? ask() : guardedWhereProxiesAssert(child, ask);
  }

  /// [ask], a dry question about the paragraph, asked AFTER the child is
  /// laid out: in a debug build under Flutter's `debugCheckingIntrinsics`
  /// hatch, as [_asked] asks it where it must. A box's dry baseline and its
  /// laid-out one share one cache, and Flutter asserts the one it kept is
  /// the dry one; a box that answers another baseline laid out than dry --
  /// one on its last line answers its first dry -- threw there once its
  /// line was laid out. Under the hatch nothing is kept, so the layout is
  /// the one a release build makes, where the question reads what the
  /// layout kept.
  T _askedLaidOut<T>(T Function() ask) {
    var debug = false;
    assert(() {
      debug = true;
      return true;
    }());
    if (!debug || RenderObject.debugCheckingIntrinsics) return _asked(ask);
    return underHatch(ask);
  }

  @override
  double computeMinIntrinsicWidth(double height) => _asked(_floor);

  @override
  double computeMaxIntrinsicWidth(double height) => _asked(() => super.computeMaxIntrinsicWidth(height));

  /// [constraints], widened to that floor where they fall below it.
  ///
  /// THE LINES ARE AS TALL AS THEY ARE, whatever the box: a box too short
  /// for its lines lets them overflow it (css-overflow-3 3, `visible`), and
  /// a paragraph handed the box's height clips what does not fit -- a 12px
  /// inline-block's `x` on a 20px line came out cut in half. The child is
  /// asked for its own height and this box keeps the one it is given.
  BoxConstraints _room(BoxConstraints constraints) {
    final free = BoxConstraints(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);
    if (child == null || !_keepWords || _anywhere || !constraints.hasBoundedWidth) return free;
    final floor = _lineFloor(constraints.maxWidth);
    if (!floor.isFinite || floor <= constraints.maxWidth) return free;
    return BoxConstraints(minWidth: constraints.hasTightWidth ? floor : constraints.minWidth, maxWidth: floor);
  }

  /// The width the lines are counted at, asked a height at [width]: the one
  /// they are laid out at ([_room]). NOT the box's min-content: an atomic
  /// inline wider than the line hangs out of it ([_lineFloor]), and the
  /// lines under it are as many as at the width the line has. Counted at
  /// the inline's own least width, a book cover `max-width: 100%` of its
  /// 300px picture, in a 100px card, answered 468 for the 164 it is laid
  /// out at, and a bookstore's carousel, its row measured by an
  /// `IntrinsicHeight`, stood 275px deeper than its cards.
  double _width(double width) => _keepWords && !_anywhere ? math.max(width, _lineFloor(width)) : width;

  /// [_width], for a box above that sets the lines' breaks.
  double linesWidth(double width) => _asked(() => _width(width));

  /// The line box CSS gives a line holding nothing but atomic inlines, as
  /// its height and its baseline, for the questions asked BEFORE layout --
  /// an intrinsic height, a dry layout -- where [_exact] cannot read the
  /// boxes Skia placed: the strut's two halves against each box's own
  /// ascent and descent (CSS 2.1 10.8). Skia rounds the line it draws, and
  /// a pricing page's 35.84px price line answered 37 to the grid row round the
  /// plan cards, which made every card 1.44px taller than what was in it.
  ///
  /// A box held to the TOP or the BOTTOM of the line stands on neither
  /// half: the line is at least that box tall (CSS 2.1 10.8), and where the
  /// box is what makes it so, the baseline is Skia's to say and is left
  /// null. A news site's `line-height: 0` artwork blocks hold a 146px picture
  /// at the bottom of a strut that reaches nothing below its baseline, and
  /// asked dry the line answered Skia's 147 to the box round it.
  ///
  /// A FORCED STRUT IS THE LINE, whatever stands on it: Skia sets a line
  /// on a strut with `forceStrutHeight` at the strut's ascent and descent
  /// and lets a box that reaches past them hang out, so the line is laid
  /// out [lineHeight] tall on [ascent]. Asked before layout it is the same
  /// line. A box's own halves are Skia's, unrounded, where Blink rounds a
  /// font's ascent and descent and floors the half-leading: an icon glyph
  /// at `vertical-align: -4px` on a 32px line reached 0.73px over the
  /// strut's ascent, and every row of a feature table measured by an
  /// `IntrinsicHeight` stood that much taller than its 32px line.
  ///
  /// BUT ONLY WHERE NOTHING ON IT REACHES PAST THE STRUT. A box that does
  /// is laid out where Skia placed it, and the line is read off the boxes
  /// ([_exact]), which hold it to the strut where Skia drew the strut's
  /// own line and to the boxes where it did not -- a line of a fractional
  /// height is one Skia rounds, and reads as one it did not. Asked before
  /// layout it is the same reading on a dry paragraph ([_dryExact]). A
  /// pricing page's gradient label is a box on a 25.59375px forced line
  /// whose own text a larger text scale raises: laid out it came to 31,
  /// asked it answered the strut's 25.6, and the column the label stood
  /// in, measured by its line, overflowed by 5.4
  /// (`test/linebox_forced_strut_reach_test.dart`).
  ///
  /// Null where the line has text on it, does not fit on one line, or
  /// centres a box on it.
  (double, double?)? _boxesOnly(double width) {
    final lh = _told, a = _toldAscent;
    final child = this.child;
    if (lh == null || a == null || child is! RenderParagraph || child.childCount == 0) return null;
    final plain = child.text.toPlainText(includeSemanticsLabels: false);
    if (!plain.codeUnits.every((c) => c == 0x200B || c == 0xFFFC)) return null;
    final spans = <PlaceholderSpan>[];
    child.text.visitChildren((span) {
      if (span is PlaceholderSpan) spans.add(span);
      return true;
    });
    final room = BoxConstraints(maxWidth: width);
    var up = a, down = lh - a, across = 0.0, edged = 0.0;
    var box = child.firstChild;
    for (final span in spans) {
      if (box == null) return null;
      final size = box.getDryLayout(room);
      across += size.width;
      switch (span.alignment) {
        case ui.PlaceholderAlignment.baseline:
          final b = box.getDryBaseline(room, span.baseline ?? TextBaseline.alphabetic);
          if (b == null) return null;
          up = math.max(up, b);
          down = math.max(down, size.height - b);
        case ui.PlaceholderAlignment.aboveBaseline:
          up = math.max(up, size.height);
        case ui.PlaceholderAlignment.belowBaseline:
          down = math.max(down, size.height);
        case ui.PlaceholderAlignment.top || ui.PlaceholderAlignment.bottom:
          edged = math.max(edged, size.height);
        default:
          return null;
      }
      box = child.childAfter(box);
    }
    if (box != null || across > width + 0.01) return null;
    if (child.strutStyle?.forceStrutHeight ?? false) {
      final reaches = up > a + _floatNoise || down > lh - a + _floatNoise || edged > lh + _floatNoise;
      return reaches ? null : (lh, a);
    }
    return edged > up + down ? (edged, null) : (up + down, up);
  }

  // An intrinsic height is asked for without a line to stand on, so only
  // the whole lines of one are counted.
  @override
  double computeMinIntrinsicHeight(double width) => _asked(
    () =>
        _boxesOnly(_width(width))?.$1 ??
        _dryExact(BoxConstraints(maxWidth: _width(width)))?.$1 ??
        _dryGrown(BoxConstraints(maxWidth: _width(width)))?.height ??
        _box(child?.getMinIntrinsicHeight(_width(width)) ?? 0.0, null).$1,
  );

  @override
  double computeMaxIntrinsicHeight(double width) => _asked(
    () =>
        _boxesOnly(_width(width))?.$1 ??
        _dryExact(BoxConstraints(maxWidth: _width(width)))?.$1 ??
        _dryGrown(BoxConstraints(maxWidth: _width(width)))?.height ??
        _box(child?.getMaxIntrinsicHeight(_width(width)) ?? 0.0, null).$1,
  );

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => _asked(() => _dryLayout(constraints));

  Size _dryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    final room = _room(constraints);
    final s = child.getDryLayout(room);
    // A child that comes back unbounded -- a stock `Row` stretching it
    // across an axis nothing bounded, asked dry by a host that measures
    // its items with no bound across -- has no lines to count. The answer
    // is as unbounded as the offer, and the host that asked reads an
    // unbounded answer as none and asks the intrinsic instead.
    if (!s.height.isFinite) return constraints.constrain(s);
    final high =
        _boxesOnly(room.maxWidth)?.$1 ??
        _dryExact(room)?.$1 ??
        _dryGrown(room)?.height ??
        _box(s.height, dryBaselineOf(child, room, TextBaseline.alphabetic)).$1;
    return constraints.constrain(Size(s.width, high));
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) =>
      _asked(() => _dryBaseline(constraints, baseline));

  double? _dryBaseline(BoxConstraints constraints, TextBaseline baseline) {
    final child = this.child;
    if (child == null) return null;
    final room = _room(constraints);
    if (baseline == TextBaseline.alphabetic) {
      if (_boxesOnly(room.maxWidth) case (_, final up?)) return up;
    }
    final b = dryBaselineOf(child, room, baseline);
    if (b == null) return null;
    final h = child.getDryLayout(room).height;
    if (!h.isFinite) return b;
    final exact = _dryExact(room);
    if (exact == null) {
      if (_dryGrown(room) case final grown?) return b + grown.drop;
    }
    return b + (exact == null ? _box(h, b).$2 : exact.$2 + exact.$3);
  }

  /// The LINE the box is put back on is the FIRST one -- [_box] drops the
  /// content so that line's baseline lands where CSS puts it, and every
  /// line under it comes down by the same amount.
  @override
  double? dryLastBaseline(BoxConstraints constraints, TextBaseline baseline) =>
      _asked(() => _dryLastBaseline(constraints, baseline));

  double? _dryLastBaseline(BoxConstraints constraints, TextBaseline baseline) {
    final child = this.child;
    if (child == null) return null;
    final room = _room(constraints);
    final last = dryLastBaselineOf(child, room, baseline);
    if (last == null) return null;
    final first = dryBaselineOf(child, room, baseline);
    final h = child.getDryLayout(room).height;
    if (!h.isFinite) return last;
    // Lines read off the boxes on them: the first baseline put back, as
    // [computeDryBaseline] puts it, and the lines CSS stacks under it.
    final exact = _dryExact(room);
    if (exact != null && first != null) return first + exact.$2 + exact.$3 + exact.$4;
    if (exact == null && first != null) {
      if (_dryGrown(room) case final grown?) return first + grown.drop + grown.below;
    }
    return last + (exact?.$2 ?? _box(h, first).$2);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final b = super.computeDistanceToActualBaseline(baseline);
    return b == null ? null : b + _drawn + _offset;
  }

  /// How far down the child's first baseline is put back, as CSS puts it;
  /// see [_box]. What the box ANSWERS -- its baselines, and [drop] for a
  /// walk to its last one -- reads this; [paint] puts the child [_painted].
  double _offset = 0;

  /// A MOVE OF LESS THAN HALF A 64TH IS NOT PAINTED. Blink sets a baseline
  /// on its 1/64 grid (`LayoutUnit`), so a baseline Skia drew within half
  /// a unit of the ascent CSS gives it is ON that ascent already: what is
  /// left is float32 noise -- a strut written at `fontSize: 22.291` puts
  /// a news site's 24px Post Grotesk headline at 21.00012 where Blink's line
  /// says 21 -- and painting the paragraph moved by it moves nothing but
  /// where the glyphs are rounded to. At a half pixel that is the whole
  /// pixel: the headline's line starts at y = 1080.5 at 1440, Chrome draws
  /// its baseline at 1101.5 and rounds it down the page, and the paragraph
  /// painted 0.00012 up composed (in float32) a hair short of the half and
  /// was drawn a pixel HIGH, where the same paragraph unmoved in a
  /// `SizedBox` of the line height is drawn where Chrome draws it.
  ///
  /// THE PAINT ALONE. The baseline the box answers stays the exact one, and
  /// so does [drop]: a row that stands its items on their baselines makes
  /// itself the highest ascent over the deepest descent of them (CSS 2.1
  /// 10.8; `RenderFlex` under `CrossAxisAlignment.baseline`), so one item
  /// answering Skia's 13.99998 beside another's exact 14 made a pricing
  /// page's rows 0.0000229 taller than their 19.890625 line, and the card
  /// column a box asked its height of (`IntrinsicHeight`, which reads the
  /// line) overflowed by it at every width from 768 up. NEGATIVE: a
  /// baseline a 64th or more off the ascent (Skia's rounded strut, 0.39 at
  /// 18.390625; Apple's two pixels of Helvetica ascent) is painted put
  /// back, however little.
  double get _painted => _offset.abs() < 1 / 128 ? 0.0 : _offset;

  /// How far below the baseline the child answers it draws its first line
  /// (see [_read]).
  double _drawn = 0;

  /// How far under its first baseline the box has its LAST, where its
  /// lines were read off the boxes on them ([_read]); null where they were
  /// not, and a walk to the last baseline adds [drop] to the child's own.
  ///
  /// NOT THE PARAGRAPH'S LAST LINE PUT BACK BY THE DROP. Skia stacks the
  /// lines at their heights rounded, and draws the first a fraction under
  /// the baseline it answers ([_drawn]): a news site's bylines are one
  /// 17.59375px line, 14 over its baseline, holding a box, and Skia draws
  /// that line 18 -- in `fixtures/linebox-told-placeholder-rounded` p1 the
  /// paragraph answers 14.05, draws 14.40 and is dropped 0.40, and the
  /// walk stood the byline on 13.6, the card's 24px line on 19.6 over 6:
  /// 25.6 where Chrome's is 26, its story cards 25.65 each and 9px
  /// down a phone page. A byline of two such lines came right by luck, its
  /// second line drawn 18 under the first where CSS has 17.59; one of
  /// three came out 0.4 low.
  double? get below => _below;
  double? _below;

  /// How far down CSS puts the paragraph from where it was laid out -- what
  /// a walk to its LAST baseline adds, which no parent data records. It is
  /// painted there too, but for a move too small to paint ([_painted]).
  double get drop => _offset;

  /// How far across [paint] puts the child: nothing, but where an `rtl`
  /// paragraph set against its start edge was widened past the box, which
  /// puts its right edge on the box's (see [LineBox]).
  double _across = 0;

  static double _acrossFor(RenderBox child, double width) {
    if (child.size.width <= width) return 0;
    final (TextDirection? direction, TextAlign? align) = switch (child) {
      RenderParagraph() => (child.textDirection, child.textAlign),
      RenderIndentedText() => (child.textDirection, child.textAlign),
      _ => (null, null),
    };
    if (direction != TextDirection.rtl) return 0;
    return switch (align) {
      TextAlign.start || TextAlign.right || TextAlign.justify => width - child.size.width,
      _ => 0,
    };
  }

  /// EVERY LINE AT THE PITCH CSS GIVES IT. Blink stacks a paragraph's
  /// lines at their line height on its 1/64 grid (`LayoutUnit`), and Skia
  /// at that height rounded to a whole pixel: a paragraph of 16px text on
  /// `line-height: 1.444` lines is 23.09375 a line in a browser and 23 in
  /// a `Text`, so where [_box] puts the first line and the paragraph's
  /// height back, the lines between still climb 0.09375px each --
  /// a course site's 37-line biography ended 3.4px high, and a video
  /// site's 28.4375px lines, drawn 28, put the 22nd 9.2px high (census:
  /// 1,560 lines half a pixel or more off on 32 sites of the test sets).
  ///
  /// NO STOCK ROUTE STACKS A FRACTIONAL LINE. SkParagraph rounds each
  /// line's height (`InternalLineMetrics::height`, descent - ascent +
  /// leading, to the nearest pixel) and starts the next line there, under
  /// a forced strut, a strut not forced, and a `TextStyle.height` with
  /// either leading distribution alike: 23.4, 23.09375, 28.4375 and 16.5
  /// stack at 23, 23, 28 and 17 in Inter and the test font, every one of
  /// the four ways. So the lines are moved where they are painted.
  ///
  /// Where every line is the strut's own ([_plainLines]), line k of the
  /// [_lines] is painted on its own, cut to the band Skia drew it in and
  /// moved down by k times what Skia's line came short ([_pitch]): the
  /// first band reaches up and the last down past the box, for glyphs that
  /// hang out of it. Only a paragraph painted all on its own canvas is cut
  /// up so: a box on a line ([_exact]'s lines) or a layer of its own would
  /// be painted once per line.
  ///
  /// THE PAINT ALONE, as [_painted]: the baselines the box answers, its
  /// hit testing and its height stay Skia's lines put back as before.
  /// NEGATIVE: a line height of whole pixels, one line, a paragraph with a
  /// box on it -- each painted once, where it was.
  int _lines = 0;
  double _whole = 0;
  double _pitch = 0;

  /// Where the lines are each their own height ([_grownRead]): how much
  /// further than the first each line is moved, and the top of each as
  /// Skia drew it, which cuts the paragraph into the lines painted. Its
  /// hit testing follows: a point is on the line painted under it.
  List<double>? _moves;
  List<double>? _tops;

  void _readLines(RenderBox child, bool exact) {
    _lines = 0;
    _whole = 0;
    _pitch = 0;
    final lh = _told;
    if (lh == null || exact || child.isRepaintBoundary) return;
    var kids = 0;
    child.visitChildren((_) => kids++);
    if (kids > 0) return;
    if (_plainLines(child.size.height, lh) case (final n, final whole) when n > 1 && whole != lh) {
      _lines = n;
      _whole = whole;
      _pitch = lh - whole;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final at = offset + Offset(_across, _painted);
    if (_moves case final moves? when !needsCompositing) {
      final tops = _tops!;
      final reach = child.size.width + child.size.height + 1e4;
      for (var k = 0; k < moves.length; k++) {
        final band = Rect.fromLTRB(
          -reach,
          k == 0 ? -reach : tops[k],
          child.size.width + reach,
          k == moves.length - 1 ? child.size.height + reach : tops[k + 1],
        );
        context.pushClipRect(false, at + Offset(0, moves[k]), band, (c, o) => c.paintChild(child, o));
      }
      return;
    }
    if (_lines < 2 || needsCompositing) {
      context.paintChild(child, at);
      return;
    }
    // Wide enough for anything the paragraph paints past its box.
    final reach = child.size.width + child.size.height + 1e4;
    for (var k = 0; k < _lines; k++) {
      final band = Rect.fromLTRB(
        -reach,
        k == 0 ? -reach : k * _whole,
        child.size.width + reach,
        k == _lines - 1 ? child.size.height + reach : (k + 1) * _whole,
      );
      context.pushClipRect(false, at + Offset(0, k * _pitch), band, (c, o) => c.paintChild(child, o));
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    var line = 0.0;
    if (_moves case final moves?) {
      final y = position.dy - _painted;
      for (var k = moves.length - 1; k > 0; k--) {
        if (y - moves[k] >= _tops![k]) {
          line = moves[k];
          break;
        }
      }
    }
    return result.addWithPaintOffset(
      offset: Offset(_across, _painted + line),
      position: position,
      hitTest: (r, p) => child.hitTest(r, position: p),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(_across, _painted, 0.0, 1.0);
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      _offset = 0;
      _drawn = 0;
      _below = null;
      _across = 0;
      _lines = 0;
      _moves = null;
      _tops = null;
      return;
    }
    final room = _asked(() => _room(constraints));
    child.layout(room, parentUsesSize: true);
    final exact = _exact(child);
    final grown = exact == null ? _laidGrown(child) : null;
    final (read, drop) = exact != null
        ? (exact.$1, exact.$2)
        : grown != null
        ? (grown.height, grown.drop)
        : _box(child.size.height, child.getDistanceToBaseline(TextBaseline.alphabetic, onlyReal: true));
    // A LINE OF NOTHING BUT BOXES IS ONE NUMBER, ASKED OR LAID OUT. Before
    // layout its height is worked out as CSS sizes it ([_boxesOnly]), in
    // doubles; laid out it is read off the boxes Skia placed, in floats --
    // the same line a millionth of a pixel apart. A box that measures what
    // it holds before laying it out hands it the asked height, and a stock
    // `Column` of five buttons, each an inline-block alone on its line, was
    // handed 0.0000048 less than it came to: its debug overflow hatch
    // covered the bottom tenth of a page. Where the two differ by that
    // float's part of a pixel and no more, the line is the asked one.
    final asked = _askedLaidOut(() => _boxesOnly(room.maxWidth))?.$1;
    final tall = asked != null && (asked - read).abs() <= _floatNoise ? asked : read;
    _offset = drop;
    _drawn = exact?.$3 ?? 0;
    _below = exact?.$4 ?? grown?.below;
    size = constraints.constrain(Size(child.size.width, tall));
    _across = _acrossFor(child, size.width);
    _moves = grown?.moves;
    _tops = grown?.tops;
    _readLines(child, exact != null || grown != null);
  }
}
