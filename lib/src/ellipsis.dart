/// The ellipsis a clamped block ends on.
library;

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'balance.dart';
import 'dry.dart';
import 'inline_flow.dart' show TextWrapStyle;
import 'linebox.dart';
import 'pretty.dart';
import 'shrink.dart' show RenderShrinkWidth;

/// A paragraph cut off after its Nth line, with the ellipsis where that line
/// ENDS (`-webkit-line-clamp`, css-overflow-4 `block-ellipsis`).
///
/// Skia's `maxLines` with `TextOverflow.ellipsis` lays the last line out as
/// though everything after it were on it too, and cuts THAT off at the
/// room: a news site's two-line summaries ended `link between GLP-1 w…`. Chrome
/// keeps the lines where they broke and puts the ellipsis after the last
/// one -- `link between GLP-1…` -- taking characters off the end of it only
/// where the ellipsis does not fit beside them.
///
/// So the text is cut where the Nth line ends as the paragraph breaks it
/// unclamped, and the ellipsis goes on the end of what is left. Where that
/// no longer fits on the line, characters come off the end of it until it
/// does, as Chrome takes them: `Mockingbird…` is 100.4px in 14px
/// Montserrat and a 100px card shows `Mockingbir…`. (The paragraph stands
/// in a `LineBox`, which widens the room to the widest word, so Skia's own
/// ellipsis never saw the line as too wide.)
///
/// THE LINES AFTER THE CLAMP ARE LAID OUT AND PAINTED. The clamp ends the
/// block's own height at the Nth line and puts the ellipsis on it; what
/// follows is laid out below and hidden only by the block's `overflow:
/// hidden`, and where the block is taller than its lines -- a stretched
/// flex item, a stated height -- Chrome paints the next line in the room
/// (measured: `height: 100px` round a three-line clamp of 20px lines shows
/// the fourth). A portal's headlines are 72px items holding a three-line clamp,
/// and each shows the top of its fourth line under the ellipsis.
///
/// Only a paragraph of text: a line holding an inline box is Skia's.
class BlockEllipsis extends SingleChildRenderObjectWidget {
  const BlockEllipsis({super.key, this.textOverflow = false, this.textWrap = TextWrapStyle.auto, super.child});

  /// Whether a line too wide for the block is cut off with an ellipsis as
  /// well (`text-overflow: ellipsis` on a block that hides its overflow,
  /// css-overflow-4 3.2). CSS never breaks inside a word, so a word wider
  /// than the block hangs out of it, and this is what cuts it short:
  /// a bookstore's "The Thoroughbreds" is a two-line clamp 100px wide
  /// holding a 110px word, and drew `Thoroughbrec` where the browser draws
  /// `Thoroughbr…`.
  final bool textOverflow;

  /// How the lines the clamp KEEPS are broken (`text-wrap-style`,
  /// css-text-4 6.2): [TextWrapStyle.balance] or [TextWrapStyle.pretty]
  /// re-break them as [Balance] and [Pretty] do, and the ellipsis goes
  /// where the last of them ends, which is where it ends greedily.
  ///
  /// BLINK BREAKS A CLAMPED PARAGRAPH AS IF IT ENDED AT THE CLAMP. Its
  /// `ScoreLineBreaker` takes the greedy lines up to the paragraph's end
  /// or to the clamp, whichever comes first (`lines_until_clamp`), and
  /// re-breaks those alone; the bisecting fallback for balance does the
  /// same (`ParagraphLineBreaker::AttemptParagraphBalancing`). So a clamp
  /// the paragraph never reaches leaves it balanced or pretty whole, and
  /// one it does reach re-breaks the text of the lines kept over the same
  /// count -- balanced where there are at most six (Blink's
  /// `kMaxLinesForBalance`), greedy past that; pretty only where the
  /// clamp's line is one word under a third of the room, which a line the
  /// clamp cuts in the middle of the text seldom is. A paragraph with a
  /// forced break, or a word wider than the room, stays greedy.
  final TextWrapStyle textWrap;

  @override
  RenderBlockEllipsis createRenderObject(BuildContext context) =>
      RenderBlockEllipsis(textOverflow: textOverflow, textWrap: textWrap);

  @override
  void updateRenderObject(BuildContext context, RenderBlockEllipsis renderObject) {
    renderObject
      ..textOverflow = textOverflow
      ..textWrap = textWrap;
  }
}

/// The render object behind [BlockEllipsis].
class RenderBlockEllipsis extends RenderProxyBox with DryLastBaseline, AsksGuarded, KeptUnderHatch {
  RenderBlockEllipsis({bool textOverflow = false, TextWrapStyle textWrap = TextWrapStyle.auto, RenderBox? child})
    : _textOverflow = textOverflow,
      _textWrap = textWrap,
      super(child);

  /// See [BlockEllipsis.textOverflow].
  bool get textOverflow => _textOverflow;
  bool _textOverflow;
  set textOverflow(bool v) {
    if (v == _textOverflow) return;
    _textOverflow = v;
    _madeFor = null;
    markNeedsLayout();
  }

  /// See [BlockEllipsis.textWrap].
  TextWrapStyle get textWrap => _textWrap;
  TextWrapStyle _textWrap;
  set textWrap(TextWrapStyle v) {
    if (v == _textWrap) return;
    _textWrap = v;
    _madeFor = null;
    markNeedsLayout();
  }

  static const _ellipsis = '…';

  /// The paragraph under [child], past the line box around it.
  RenderParagraph? _paragraph() {
    var box = child;
    for (var i = 0; i < 4 && box != null; i++) {
      if (box is RenderParagraph) return box;
      if (box is! RenderProxyBox) return null;
      box = box.child;
    }
    return null;
  }

  /// The span as the widget built it, before any cut of ours.
  InlineSpan? _source;

  /// The span we last put on the paragraph, and the room it was cut for.
  InlineSpan? _made;
  double? _madeFor;

  /// The clamp and the overflow the widget built the paragraph with, held
  /// while the paragraph shows a cut that lays the lines after the clamp
  /// out (see [_install]).
  int? _lines;
  TextOverflow? _overflow;

  /// The lines a [LineClamp] round the block leaves this paragraph, where
  /// one has counted its line boxes; null where none has, and the widget's
  /// own clamp holds. The clamp sets it from its layout.
  int? get budget => _budget;
  int? _budget;
  set budget(int? v) {
    if (v == _budget) return;
    _budget = v;
    if (_source != null) _apply();
    // The cut is made again; the one the paragraph shows stays OURS until
    // then, or the next read would take it for the widget's text.
    _madeFor = null;
    markNeedsLayout();
  }

  /// The clamp, the overflow and the wrapping the widget built the
  /// paragraph with.
  int? _ownLines;
  TextOverflow? _ownOverflow;
  bool _ownWrap = true;

  /// Whether the paragraph wraps: the widget's say, until a clamp above
  /// puts it past the cut.
  bool? _wrap;

  /// What the budget leaves the paragraph: the widget's own clamp where
  /// there is none; the budget's lines, ending on the ellipsis, where there
  /// is one; and PAST THE CLAMP -- a budget of nothing -- one unbroken
  /// line. Blink lays every paragraph after the one it cut out without
  /// breaking it, and paints it: a three-line paragraph after the clamp
  /// measures 24px in Chrome, and a `height: 220px` box round the clamp
  /// shows its first line, clipped at the box's edge.
  void _apply() {
    final b = _budget;
    _lines = b == null
        ? _ownLines
        : b == 0
        ? 1
        : b;
    _overflow = b == null
        ? _ownOverflow
        : b == 0
        ? TextOverflow.clip
        : TextOverflow.ellipsis;
    _wrap = b == null ? _ownWrap : b != 0;
  }

  /// How many lines the whole paragraph breaks into in the room this box
  /// was laid out in; null where there is no paragraph here to count.
  int? get lineCount {
    if (_paragraph() == null || !hasSize) return null;
    return _linesIn(constraints.maxWidth.isFinite ? constraints.maxWidth : size.width);
  }

  /// How many lines the whole paragraph breaks into in [room]: as wide as
  /// its widest word where that is wider, as the [LineBox] round it lays
  /// it out. Null where there is no paragraph here to count.
  int? _linesIn(double room) {
    final p = _paragraph();
    if (p == null) return null;
    _sync(p);
    final src = _source;
    if (src == null) return null;
    final painter = _painter(p, src)..layout();
    try {
      painter.layout(maxWidth: math.max(room, painter.minIntrinsicWidth));
      return painter.computeLineMetrics().length;
    } finally {
      painter.dispose();
    }
  }

  /// Whether a [LineClamp] round the block has counted its lines and told
  /// it its [budget]. Until one has, the block is asked its height as the
  /// clamp WILL cut it ([_heightAhead]).
  bool _told = false;

  /// The lines the [LineClamp] round this block will leave it in [room],
  /// worked out before the clamp has counted them: what the clamp's own
  /// walk hands it ([RenderLineClamp._budgetFor]). Null where no clamp is
  /// round it, or the clamp leaves the paragraph whole.
  int? _budgetAhead(double room) {
    for (var a = parent; a != null; a = a.parent) {
      if (a is RenderLineClamp) return a._budgetFor(this, room);
    }
    return null;
  }

  /// How tall the block is at [width] AS THE CLAMP ROUND IT WILL CUT IT,
  /// asked before the clamp has counted its lines ([_told]); null where the
  /// clamp has, where there is no clamp round it, or where the clamp
  /// leaves the paragraph whole, and the block answers as it always has.
  ///
  /// A CLAMPED BLOCK IS ITS KEPT LINES BEFORE ITS FIRST LAYOUT TOO. The
  /// clamp counts the lines and hands each paragraph its budget in its own
  /// layout, and a box that measures what it holds before laying it out --
  /// a grid sizing its rows, a flex line its items, an `IntrinsicHeight` --
  /// asked first. Each paragraph answered its whole text: a design blog's
  /// grid of two cards, each closing on a three-line clamp of six lines,
  /// sized its row three lines too tall and laid the cards out in it, and
  /// everything under the grid stood 76px low until something laid the
  /// page out again. So the paragraph asks the clamp what it will be
  /// handed, counting the paragraphs before it in the room it is asked
  /// in: its kept lines where the clamp cuts it, one unbroken line past
  /// the cut. What follows the box holding the cut is still asked its own
  /// height; the clamp's layout ends at that box.
  double? _heightAhead(double width) {
    if (_told || !width.isFinite) return null;
    if (_paragraph() == null) return null;
    final b = _budgetAhead(width);
    return b == null ? null : _heightAt(width, b);
  }

  /// How tall the block is at [width] where the clamp round it leaves it
  /// [b] lines, as its layout will make it ([_apply]) -- whether or not the
  /// clamp has told it a budget yet: one unbroken line past the cut; the
  /// kept lines where the clamp cuts it. Null where the paragraph answers
  /// for itself: it ends on the clamp's line or before, and its own clamp
  /// and wrapping draw the whole of it.
  ///
  /// THE BUDGET IS THE PARAGRAPH'S CLAMP. A paragraph the widget built at
  /// one line (`maxLines: 1`) whose text breaks into two, handed a budget
  /// of two, is laid out at two; asked before that, its own line answered.
  double? _heightAt(double width, int b) {
    final p = _paragraph();
    if (p == null || !width.isFinite) return null;
    _sync(p);
    if (_source == null) return null;
    if (b == 0) {
      // Past the cut: one unbroken line ([_apply]).
      final lb = _lineBox();
      if (lb != null) return lb.line!;
      final painter = _painter(p, _source!, maxLines: 1)..layout();
      try {
        return painter.height;
      } finally {
        painter.dispose();
      }
    }
    final n = _linesIn(width);
    if (n == null) return null;
    // A paragraph that ends on the clamp's line or before it is whole.
    if (n <= b && (_ownLines == null || _ownLines! >= n) && _ownWrap) return null;
    return _clampedHeight(p, width, b);
  }

  /// How tall the block is in [constraints] where the clamp round it keeps
  /// [kept] of its lines ([_heightAt]), the same before the clamp has told
  /// it and after: for the clamp's own height ([RenderLineClamp._cutHeight]).
  double _keptHeight(BoxConstraints constraints, int kept) {
    final h = _heightAt(constraints.maxWidth, kept) ?? child?.getDryLayout(constraints).height ?? 0.0;
    return constraints.constrainHeight(h);
  }

  /// Reads the paragraph's span back: ours, the one a rebuild put back, or
  /// a new one, which throws the old cut away.
  void _sync(RenderParagraph p) {
    final t = p.text;
    if (_made != null && t == _made) return;
    if (_source != null && t == _source) return;
    _source = t;
    _made = null;
    _madeFor = null;
    _ownLines = p.maxLines;
    _ownOverflow = p.overflow;
    _ownWrap = p.softWrap;
    _apply();
  }

  /// Whether the paragraph shows a cut of ours that keeps the lines after
  /// the clamp, so that its own height is not the block's.
  bool get _clamping {
    final p = _paragraph();
    return p != null && _lines != null && _made != null && p.text == _made;
  }

  /// Whether the paragraph is showing a cut made for another room than
  /// [room], so that the child cannot answer for it.
  bool _cutElsewhere(RenderParagraph? p, double room) =>
      p != null && _made != null && p.text == _made && _madeFor != room;

  TextPainter _painter(RenderParagraph p, InlineSpan span, {int? maxLines}) => TextPainter(
    text: span,
    textAlign: p.textAlign,
    textDirection: p.textDirection,
    textScaler: p.textScaler,
    maxLines: maxLines,
    ellipsis: maxLines == null ? null : _ellipsis,
    strutStyle: p.strutStyle,
    locale: p.locale,
    textWidthBasis: p.textWidthBasis,
    textHeightBehavior: p.textHeightBehavior,
  );

  /// Whether every span in [s] is text.
  static bool _plain(InlineSpan s) {
    var ok = true;
    s.visitChildren((span) {
      if (span is! TextSpan) ok = false;
      return ok;
    });
    return ok;
  }

  static TextSpan _copy(TextSpan s, {String? text, List<InlineSpan>? children, String? semanticsLabel}) => TextSpan(
    text: text,
    children: children,
    style: s.style,
    recognizer: s.recognizer,
    mouseCursor: s.mouseCursor,
    onEnter: s.onEnter,
    onExit: s.onExit,
    semanticsLabel: semanticsLabel,
    locale: s.locale,
    spellOut: s.spellOut,
  );

  /// [s] with only the characters from [from] to [to], or null where it
  /// holds none of them; [pos] counts the characters walked so far.
  static TextSpan? _slice(TextSpan s, int from, int to, List<int> pos) {
    var text = s.text;
    if (text != null) {
      final a = pos[0], b = a + text.length;
      pos[0] = b;
      final lo = from.clamp(a, b) - a, hi = to.clamp(a, b) - a;
      text = hi > lo ? text.substring(lo, hi) : null;
    }
    final kids = <InlineSpan>[
      for (final k in s.children ?? const <InlineSpan>[])
        if (_slice(k as TextSpan, from, to, pos) case final cut?) cut,
    ];
    if (text == null && kids.isEmpty) return null;
    return _copy(s, text: text, children: kids.isEmpty ? null : kids);
  }

  /// [s] with the characters from [start] to [end] taken out and the
  /// ellipsis where they were, after the last character kept and in its
  /// style; null where nothing is kept before it. [length] is the whole.
  /// With [breakAfter] the rest starts a line of its own under the
  /// ellipsis, as the lines after a clamp do.
  static TextSpan? _spliced(TextSpan s, int start, int end, int length, {bool breakAfter = false}) {
    final head = _slice(s, 0, start, [0]);
    if (head == null) return null;
    final ended = _ended(head);
    final tail = end < length ? _slice(s, end, length, [0]) : null;
    if (tail == null) return ended;
    return TextSpan(
      style: s.style,
      children: [
        ended,
        if (breakAfter) const TextSpan(text: '\n'),
        tail,
      ],
    );
  }

  /// [s] with the ellipsis after its last character, in that character's
  /// style.
  static TextSpan _ended(TextSpan s) {
    final kids = s.children;
    if (kids != null && kids.isNotEmpty) {
      return _copy(s, text: s.text, children: [...kids.take(kids.length - 1), _ended(kids.last as TextSpan)]);
    }
    return _copy(s, text: '${s.text ?? ''}$_ellipsis');
  }

  static bool _blank(int c) => c == 0x20 || c == 0x0A || c == 0x09 || c == 0x200B;

  /// Whether the ellipsis [check] laid out at [offset] sits on line [i] of
  /// [cm] and that line fits the [room] -- the ellipsis did not wrap and
  /// took nothing with it. [before] is how many lines the paragraph had
  /// where the cut keeps its tail on the line, so that the tail's reflow
  /// cannot hide a wrapped ellipsis.
  static bool _fits(TextPainter check, List<LineMetrics> cm, int offset, int i, double room, int? before) {
    if (cm.length <= i || cm[i].width > room + 0.01) return false;
    if (before != null && cm.length > before) return false;
    final y = check.getOffsetForCaret(TextPosition(offset: offset, affinity: TextAffinity.upstream), Rect.zero).dy;
    var line = -1;
    for (var j = 0; j < cm.length; j++) {
      if (cm[j].baseline - cm[j].ascent <= y + 0.5) line = j;
    }
    return line == i;
  }

  /// The span cut at the end of the paragraph's last line in [room], and
  /// on every line too wide for the room where [textOverflow] says so, its
  /// kept lines first re-broken as [textWrap] says ([_wrapped]); or null
  /// where nothing is cut or moved.
  InlineSpan? _clamped(RenderParagraph p, double room) {
    if (_madeFor == room) return _made;
    _madeFor = room;
    _made = null;
    final whole = _source;
    final lines = _lines;
    if (whole is! TextSpan || !p.softWrap || !room.isFinite || room <= 0 || !_plain(whole)) return null;
    final wrapped = _overflow == TextOverflow.clip && lines != null ? null : _wrapped(p, whole, room);
    final src = wrapped ?? whole;
    if (_overflow != TextOverflow.ellipsis || (lines == null ? !_textOverflow : lines < 1)) {
      return wrapped == null ? null : _made = _labelled(wrapped, whole);
    }
    final painter = _painter(p, src);
    try {
      // The lines as the paragraph breaks them unclamped: in the room, or
      // as wide as its widest word where that is wider, which is how the
      // `LineBox` round it lays the paragraph out and lets the word hang
      // out of the block. Without `text-overflow` a hanging word is left
      // hanging, and the lines are not these.
      painter.layout();
      final narrow = painter.minIntrinsicWidth;
      if (narrow > room + 0.01 && !_textOverflow) return null;
      painter.layout(maxWidth: math.max(room, narrow));
      var metrics = painter.computeLineMetrics();
      var made = src;
      final plain = src.toPlainText(includeSemanticsLabels: false);
      // Last line first, so that a cut leaves the lines before it where
      // they are. The clamped line loses what comes after it; a line too
      // wide for the room -- one word, since a line that could break would
      // have -- loses its end. Either ends on the ellipsis, and characters
      // come off before it until the ellipsis fits the room.
      final shown = lines == null ? metrics.length : math.min(lines, metrics.length);
      for (var i = shown - 1; i >= 0; i--) {
        final m = metrics[i];
        final clamp = lines != null && i == lines - 1 && metrics.length > lines;
        final range = painter.getLineBoundary(
          painter.getPositionForOffset(Offset(m.left + math.min(m.width, room) / 2, m.baseline)),
        );
        final start = range.start.clamp(0, plain.length);
        var end = range.end.clamp(start, plain.length);
        // Where the next line's text starts: what a clamp keeps, below.
        var next = end;
        while (next < plain.length && _blank(plain.codeUnitAt(next))) {
          next++;
        }
        while (end > start && _blank(plain.codeUnitAt(end - 1))) {
          end--;
        }
        if (!clamp) {
          if (!_textOverflow || m.width <= room + 0.01) continue;
          if (RegExp(r'\s').hasMatch(plain.substring(start, end))) continue;
        }
        final length = made.toPlainText(includeSemanticsLabels: false).length;
        // The clamp line loses only what was on it after the cut: the lines
        // after it go on below, on lines of their own.
        final drop = clamp ? next : end;
        for (; end > start; end--) {
          if (_blank(plain.codeUnitAt(end - 1))) continue;
          final candidate = _spliced(made, end, drop, length, breakAfter: clamp);
          if (candidate == null) break;
          final check = _painter(p, candidate);
          try {
            check.layout();
            check.layout(maxWidth: math.max(room, check.minIntrinsicWidth));
            final cm = check.computeLineMetrics();
            if (_fits(check, cm, end + 1, i, room, clamp ? null : metrics.length)) {
              made = candidate;
              metrics = cm;
              break;
            }
          } finally {
            check.dispose();
          }
        }
      }
      if (identical(made, whole)) return null;
      return _made = _labelled(made, whole);
    } finally {
      painter.dispose();
    }
  }

  /// [made] read to a screen reader as the [whole] text -- where the span
  /// holds text of its own to carry the label; a label on a span of only
  /// children is one Flutter will not take.
  static TextSpan _labelled(TextSpan made, TextSpan whole) => made.text == null
      ? made
      : _copy(
          made,
          text: made.text,
          children: made.children,
          semanticsLabel: whole.semanticsLabel ?? whole.toPlainText(includeSemanticsLabels: false),
        );

  /// [src] with a forced break where each line the clamp keeps ends, as
  /// [textWrap] breaks them in [room]; null where they stay greedy (see
  /// [BlockEllipsis.textWrap]). The lines kept are the greedy count, at
  /// most the clamp's, and the last of them ends where it ends greedily:
  /// balanced or pretty lines are re-broken over the text up to there, so
  /// no line can take a word past it, and the cut goes where it went.
  TextSpan? _wrapped(RenderParagraph p, TextSpan src, double room) {
    if (_textWrap == TextWrapStyle.auto) return null;
    final text = src.toPlainText(includeSemanticsLabels: false);
    if (text.length < 2 || text.contains('\n')) return null;
    final painter = _painter(p, src);
    try {
      painter.layout();
      // A word wider than the room keeps the paragraph greedy (Blink's
      // `disable_score_line_break_`).
      if (painter.minIntrinsicWidth > room + 0.01) return null;
      painter.layout(maxWidth: room);
      final metrics = painter.computeLineMetrics();
      final kept = _lines == null ? metrics.length : math.min(_lines!, metrics.length);
      if (kept < 2 || (_textWrap == TextWrapStyle.balance && kept > RenderBalance.maxLines)) return null;
      // Where each greedy line ends, its blanks off.
      int endOf(int i) {
        final m = metrics[i];
        var end = painter
            .getLineBoundary(painter.getPositionForOffset(Offset(m.left + math.min(m.width, room) / 2, m.baseline)))
            .end
            .clamp(0, text.length);
        while (end > 0 && _blank(text.codeUnitAt(end - 1))) {
          end--;
        }
        return end;
      }

      final greedy = [for (var i = 0; i < kept; i++) endOf(i)];
      final opp = RenderBalance.opportunities(text.substring(0, greedy.last));
      if (opp.length < kept) return null;
      // Every prefix's width, off one laid-out line (see `RenderBalance`).
      painter.layout(maxWidth: painter.maxIntrinsicWidth.ceilToDouble() + 1);
      final at = <int, double>{};
      double x(int i) => at.putIfAbsent(i, () => painter.getOffsetForCaret(TextPosition(offset: i), Rect.zero).dx);
      final cuts = _textWrap == TextWrapStyle.balance
          ? RenderBalance.balancedCuts(opp, x, room, kept)
          : RenderPretty.prettyCuts(opp, x, room, kept);
      if (cuts == null) return null;
      // Nothing moved: the greedy lines stand.
      var same = true;
      for (var t = cuts.length - 1, i = 0; t > 1; t--, i++) {
        if (opp[cuts[t - 1] - 1].$1 != greedy[i]) same = false;
      }
      return same ? null : RenderBalance.brokenOn(src, opp, cuts);
    } finally {
      painter.dispose();
    }
  }

  /// Puts the cut on the paragraph. A clamp's cut keeps the lines after
  /// the clamp, which Skia lays out only without `maxLines` and paints only
  /// without its own ellipsis; the block's height is taken at the clamp in
  /// [performLayout]. The widget's own clamp and overflow go back on with
  /// the whole text.
  void _install(double room) {
    final p = _paragraph();
    if (p == null) return;
    _sync(p);
    final want = _clamped(p, room) ?? _source;
    if (want == null) return;
    final tailed = identical(want, _made) && _lines != null;
    final lines = tailed ? null : _lines;
    final overflow = tailed ? TextOverflow.clip : _overflow;
    final wrap = _wrap ?? p.softWrap;
    if (p.text != want || p.maxLines != lines || (overflow != null && p.overflow != overflow) || p.softWrap != wrap) {
      invokeLayoutCallback((Constraints _) {
        p.text = want;
        p.maxLines = lines;
        if (overflow != null) p.overflow = overflow;
        p.softWrap = wrap;
      });
    }
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    if (constraints.maxWidth.isFinite) _install(constraints.maxWidth);
    child.layout(_fit(constraints), parentUsesSize: true);
    var s = child.size;
    // THE BLOCK ENDS AT THE CLAMP; the lines under it are painted where
    // they fall and are the block's overflow.
    if (_clamping) s = Size(s.width, math.min(s.height, _clampedHeight(_paragraph()!, constraints.maxWidth)));
    size = constraints.constrain(s);
  }

  /// RE-BROKEN LINES THAT WRAP ARE AS WIDE AS THEIR ROOM, as the greedy
  /// ones are: handed a loose width, a paragraph of forced breaks stood at
  /// its longest line (see `RenderBalance`).
  BoxConstraints _fit(BoxConstraints c) {
    final p = _paragraph();
    if (_textWrap == TextWrapStyle.auto || p == null || _made == null || p.text != _made) return c;
    if (c.hasTightWidth || !c.maxWidth.isFinite || _whole(p, max: true) <= c.maxWidth) return c;
    return c.tighten(width: c.maxWidth);
  }

  // A CUT PARAGRAPH MEASURES AS THE WHOLE ONE: the clamp is laid out, and
  // says nothing about how wide the text wants to be.
  double _whole(RenderParagraph p, {required bool max}) {
    final painter = _painter(p, _source!)..layout();
    try {
      return max ? painter.maxIntrinsicWidth : painter.minIntrinsicWidth;
    } finally {
      painter.dispose();
    }
  }

  /// The [LineBox] the paragraph sits in, where there is one.
  RenderLineBox? _lineBox() {
    var box = child;
    for (var i = 0; i < 4 && box != null; i++) {
      if (box is RenderLineBox) return box.line == null ? null : box;
      if (box is! RenderProxyBox) return null;
      box = box.child;
    }
    return null;
  }

  /// How tall the block is at [width] with the clamp on: its lines, each
  /// the CSS `line-height` where a [LineBox] under the clamp says one --
  /// Skia rounds a line to whole pixels, and three lines of 18.4 measured
  /// 54 where the LineBox round them stands 55.2, as Chrome does (a news site's
  /// headlines were 1.2px short) -- else the paragraph's own height.
  double _clampedHeight(RenderParagraph p, double width, [int? lines]) {
    final lb = _lineBox();
    if (lb == null) return _tall(p, width, lines);
    final painter = _painter(p, _source!, maxLines: lines ?? _lines)..layout(maxWidth: width);
    try {
      return painter.computeLineMetrics().length * lb.line!;
    } finally {
      painter.dispose();
    }
  }

  /// How tall the clamped paragraph is at [width], where the paragraph
  /// holds a cut made for another room.
  double _tall(RenderParagraph p, double width, [int? lines]) {
    final painter = _painter(p, _source!, maxLines: lines ?? _lines)..layout(maxWidth: width);
    try {
      return painter.height;
    } finally {
      painter.dispose();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final p = _paragraph();
    return p != null && _made != null && p.text == _made
        ? _whole(p, max: false)
        : super.computeMinIntrinsicWidth(height);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final p = _paragraph();
    return p != null && _made != null && p.text == _made
        ? _whole(p, max: true)
        : super.computeMaxIntrinsicWidth(height);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (_heightAhead(width) case final h?) return h;
    final p = _paragraph();
    return _cutElsewhere(p, width) || _clamping ? _clampedHeight(p!, width) : super.computeMinIntrinsicHeight(width);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (_heightAhead(width) case final h?) return h;
    final p = _paragraph();
    return _cutElsewhere(p, width) || _clamping ? _clampedHeight(p!, width) : super.computeMaxIntrinsicHeight(width);
  }

  // THE CUT KEEPS THE LINE COUNT, so the child answers for itself at the
  // room it was cut for; at another, the whole text is clamped there.
  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    if (_heightAhead(constraints.maxWidth) case final h?) {
      return constraints.constrain(Size(child.getDryLayout(constraints).width, h));
    }
    final p = _paragraph();
    if (!(_cutElsewhere(p, constraints.maxWidth) || _clamping) || !constraints.maxWidth.isFinite) {
      return constraints.constrain(child.getDryLayout(constraints));
    }
    final painter = _painter(p!, _source!, maxLines: _lines)
      ..layout(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);
    try {
      final lb = _lineBox();
      final h = lb == null ? painter.height : painter.computeLineMetrics().length * lb.line!;
      return constraints.constrain(Size(painter.width, h));
    } finally {
      painter.dispose();
    }
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) =>
      child == null ? null : dryBaselineOf(child!, constraints, baseline);

  @override
  double? dryLastBaseline(BoxConstraints constraints, TextBaseline baseline) {
    if (child == null) return null;
    // The clamp line's baseline is the block's last, not the last line
    // painted under it.
    if (_clamping && constraints.maxWidth.isFinite) {
      final painter = _painter(_paragraph()!, _source!, maxLines: _lines)..layout(maxWidth: constraints.maxWidth);
      try {
        final lm = painter.computeLineMetrics();
        if (lm.isNotEmpty) return lm.last.baseline;
      } finally {
        painter.dispose();
      }
    }
    return dryLastBaselineOf(child!, constraints, baseline);
  }
}

/// A block cut off after its Nth LINE BOX, wherever inside it that line
/// falls: `-webkit-line-clamp` over block children (css-overflow-4
/// `line-clamp`). Blink counts the line boxes through every paragraph
/// inside the block, in order, and at the Nth: the paragraph holding it
/// is cut there, with the ellipsis on the line, and closes on its own
/// padding and border, as does every block round it; the block ends at
/// that border-box bottom (read off Chrome: `fixtures/line-clamp`). What
/// follows is laid out where the flow puts it, below, each paragraph on
/// ONE UNBROKEN LINE (Blink stops breaking past the clamp: the third
/// paragraph of `fixtures/line-clamp`'s b5 measures 24px, not its three
/// lines), and is the block's overflow, which its `overflow: hidden`
/// hides. A bookstore's "What is
/// General Fiction?" is a heading and a paragraph under a three-line
/// clamp: the heading's one line, two of the paragraph's, and the ellipsis
/// at the end of the second.
///
/// Every paragraph under the clamp stands in a [BlockEllipsis] (the
/// lowering writes one round each), which is handed its budget of lines
/// -- the ellipsis and the cut are that widget's -- and every block-level
/// box in a [ClampedBlock], which is told when it holds the cut.
class LineClamp extends SingleChildRenderObjectWidget {
  const LineClamp({super.key, required this.lines, super.child});

  /// The line boxes the block keeps.
  final int lines;

  @override
  RenderLineClamp createRenderObject(BuildContext context) => RenderLineClamp(lines);

  @override
  void updateRenderObject(BuildContext context, RenderLineClamp renderObject) => renderObject.lines = lines;
}

/// The render object behind [LineClamp].
class RenderLineClamp extends RenderProxyBox with ChildDryBaseline, KeptUnderHatch {
  RenderLineClamp(this._lines, [RenderBox? child]) : super(child);

  int _lines;
  int get lines => _lines;
  set lines(int v) {
    if (v == _lines) return;
    _lines = v;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    c.layout(constraints, parentUsesSize: true);
    // The Nth line, counted through the paragraphs as they broke whole,
    // and what that makes of every box: the paragraph holding the line
    // and the boxes round it are cut, the boxes after them are nothing.
    // A clamp inside counts its own lines and is one box to this one.
    // Sizes of boxes inside are read here, which only a layout callback
    // may do; the boxes told to change lay out again below.
    RenderBlockEllipsis? cut;
    RenderBox? outermost;
    var changed = false;
    invokeLayoutCallback((Constraints _) {
      var before = 0;
      final budgets = <RenderBlockEllipsis, int?>{};
      final boxes = <RenderClampedBlock, bool>{};
      final order = <RenderObject>[];
      void walk(RenderObject r) {
        if (r is RenderLineClamp) return;
        if (r is RenderClampedBlock) order.add(r);
        if (r is RenderBlockEllipsis) {
          order.add(r);
          // Past the cut, a budget of nothing: one unbroken line.
          int? budget = cut == null ? null : 0;
          if (cut == null) {
            final n = r.lineCount;
            if (n != null) {
              if (before + n >= _lines) {
                cut = r;
                budget = _lines - before;
              }
              before += n;
            }
          }
          budgets[r] = budget;
          return;
        }
        r.visitChildren(walk);
      }

      walk(c);
      final above = <RenderObject>{};
      if (cut case final p?) {
        for (RenderObject? a = p.parent; a != null && !identical(a, this); a = a.parent) {
          if (a is RenderClampedBlock) {
            above.add(a);
            outermost = a;
          }
        }
        outermost ??= p;
      }
      for (final r in order) {
        if (r is RenderClampedBlock) boxes[r] = above.contains(r);
      }
      for (final e in budgets.entries) {
        e.key._told = true;
        if (e.key.budget != e.value) {
          e.key.budget = e.value;
          changed = true;
        }
      }
      for (final e in boxes.entries) {
        if (e.key._cut != e.value) {
          e.key
            .._cut = e.value
            ..markNeedsLayout();
          changed = true;
        }
      }
    });
    if (changed) c.layout(constraints, parentUsesSize: true);
    var h = c.size.height;
    if (outermost case final box?) {
      invokeLayoutCallback((Constraints _) {
        h = math.min(h, box.localToGlobal(Offset.zero, ancestor: this).dy + box.size.height);
      });
    }
    size = constraints.constrain(Size(c.size.width, h));
  }

  /// The budget this clamp's layout will hand [asker], worked out before
  /// the layout counts: the walk [performLayout] makes, with every
  /// paragraph before [asker] broken in [room], the room [asker] is asked
  /// in. Null where the clamp leaves it whole.
  int? _budgetFor(RenderBlockEllipsis asker, double room) {
    final c = child;
    if (c == null) return null;
    var before = 0;
    var cut = false;
    var found = false;
    int? budget;
    void walk(RenderObject r) {
      if (found || r is RenderLineClamp) return;
      if (r is RenderBlockEllipsis) {
        final n = r._linesIn(room);
        if (identical(r, asker)) {
          found = true;
          budget = cut
              ? 0
              : n != null && before + n >= _lines
              ? _lines - before
              : null;
          return;
        }
        if (n != null) {
          if (before + n >= _lines) cut = true;
          before += n;
        }
        return;
      }
      r.visitChildren(walk);
    }

    walk(c);
    return budget;
  }

  // A CLAMP IS ASKED ITS HEIGHT AS IT LAYS ITSELF OUT, AND THE SAME AFTER
  // ITS LAYOUT AS BEFORE. Its layout ends it at the box holding the cut;
  // asked dry, it passed the question to what it holds, which answers the
  // whole -- what follows the cut too -- and its layout tells the blocks
  // inside their budgets, so that an unchanged clamp asked again answered
  // otherwise: a profile card's two-line clamp laid out 46 tall
  // and then answered 72, and the grid round the cards, measuring again
  // after a frame, grew them 212 -> 248. So the clamp answers from a walk
  // that changes nothing: the line the clamp falls on, counted as its
  // layout counts it ([_cutIn]), and how far down the boxes above that
  // line end ([_endIn]).

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final c = child;
    if (c == null) return constraints.smallest;
    final whole = c.getDryLayout(constraints);
    final cut = _cutHeight(constraints);
    return constraints.constrain(cut == null ? whole : Size(whole.width, math.min(whole.height, cut)));
  }

  @override
  double computeMinIntrinsicHeight(double width) => _cutIntrinsic(width, super.computeMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) => _cutIntrinsic(width, super.computeMaxIntrinsicHeight(width));

  double _cutIntrinsic(double width, double whole) {
    final cut = width.isFinite ? _cutHeight(BoxConstraints.tightFor(width: width)) : null;
    return cut == null ? whole : math.min(whole, cut);
  }

  /// The paragraph the clamp's layout cuts in [room] and the lines it keeps
  /// of it: [performLayout]'s walk, every paragraph broken in [room] as
  /// [_budgetFor] breaks them. Null where the clamp cuts nothing.
  (RenderBlockEllipsis, int)? _cutIn(double room) {
    final c = child;
    if (c == null) return null;
    var before = 0;
    (RenderBlockEllipsis, int)? cut;
    void walk(RenderObject r) {
      if (cut != null || r is RenderLineClamp) return;
      if (r is RenderBlockEllipsis) {
        final n = r._linesIn(room);
        if (n != null) {
          if (before + n >= _lines) cut = (r, _lines - before);
          before += n;
        }
        return;
      }
      r.visitChildren(walk);
    }

    walk(c);
    return cut;
  }

  /// How far down the child, in [constraints], the outermost box holding
  /// the cut ends -- where [performLayout] ends the clamp. Null where the
  /// clamp cuts nothing, or a box between it and the cut is one this walk
  /// cannot measure through; the clamp then answers what it holds.
  double? _cutHeight(BoxConstraints constraints) {
    final c = child;
    if (c == null || !constraints.maxWidth.isFinite) return null;
    final cut = _cutIn(constraints.maxWidth);
    if (cut == null) return null;
    final path = <RenderBox>[];
    for (RenderObject? a = cut.$1; a != null && !identical(a, this); a = a.parent) {
      if (a is! RenderBox) return null;
      path.add(a);
    }
    if (path.isEmpty || !identical(path.last, c)) return null;
    return _endIn(path.reversed.toList(), 0, constraints, cut.$2);
  }

  /// Where the cut ends in `path[i]`, dry in [constraints]: down to the cut
  /// paragraph keeping [kept] lines ([RenderBlockEllipsis._keptHeight]),
  /// each [RenderClampedBlock] on the way ending at the cut inside it plus
  /// its own bottom, as their layouts end them. Through a column, the
  /// boxes above; through padding, its top; through boxes that hand their
  /// child what they are handed, nothing. Null at any other box.
  double? _endIn(List<RenderBox> path, int i, BoxConstraints constraints, int kept) {
    final box = path[i];
    if (i == path.length - 1) return box is RenderBlockEllipsis ? box._keptHeight(constraints, kept) : null;
    if (!constraints.maxWidth.isFinite) return null;
    final next = path[i + 1];
    double? below(BoxConstraints c, [double top = 0]) => switch (_endIn(path, i + 1, c, kept)) {
      final end? => top + end,
      null => null,
    };
    switch (box) {
      case RenderClampedBlock():
        final end = below(constraints);
        return end == null ? null : math.min(box.getDryLayout(constraints).height, end + box.bottom);
      case RenderFlex()
          when box.direction == Axis.vertical &&
              box.verticalDirection == VerticalDirection.down &&
              // The children stand from the top: packed there, or with no
              // room left over to place them in.
              (box.mainAxisAlignment == MainAxisAlignment.start ||
                  (box.mainAxisSize == MainAxisSize.min && constraints.minHeight == 0)):
        final inner = box.crossAxisAlignment == CrossAxisAlignment.stretch
            ? BoxConstraints.tightFor(width: constraints.maxWidth)
            : BoxConstraints(maxWidth: constraints.maxWidth);
        var y = 0.0;
        for (var k = box.firstChild; k != null; k = box.childAfter(k)) {
          if (identical(k, next)) return below(inner, y);
          if (((k.parentData! as FlexParentData).flex ?? 0) > 0) return null;
          y += k.getDryLayout(inner).height + box.spacing;
        }
        return null;
      case RenderPadding():
        final pad = box.padding.resolve(box.textDirection);
        return below(constraints.deflate(pad), pad.top);
      case RenderConstrainedOverflowBox():
        final inner = BoxConstraints(
          minWidth: box.minWidth ?? constraints.minWidth,
          maxWidth: box.maxWidth ?? constraints.maxWidth,
          minHeight: box.minHeight ?? constraints.minHeight,
          maxHeight: box.maxHeight ?? constraints.maxHeight,
        );
        final y = box.alignment.resolve(box.textDirection).y;
        if (y == -1) return below(inner);
        final room = box.getDryLayout(constraints).height - next.getDryLayout(inner).height;
        return below(inner, room * (y + 1) / 2);
      case RenderConstrainedBox():
        return below(box.additionalConstraints.enforce(constraints));
      case RenderShrinkWidth():
        return below(box.childConstraints(constraints));
      case RenderClipRect() ||
          RenderClipRRect() ||
          RenderClipPath() ||
          RenderClipOval() ||
          RenderDecoratedBox() ||
          RenderSemanticsAnnotations() ||
          // A mouse region, a pointer listener, a gesture's semantics: a
          // `Press` round a link.
          RenderProxyBoxWithHitTestBehavior() ||
          RenderRepaintBoundary() ||
          RenderOpacity() ||
          RenderIgnorePointer() ||
          RenderAbsorbPointer() ||
          RenderMetaData() ||
          RenderExcludeSemantics() ||
          RenderMergeSemantics() ||
          RenderBlockSemantics() ||
          RenderCustomPaint() ||
          RenderTransform() ||
          RenderFractionalTranslation() ||
          RenderPhysicalModel() ||
          RenderPhysicalShape():
        return below(constraints);
    }
    return null;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = child;
    if (c != null) context.paintChild(c, offset);
  }
}

/// A block-level box under a [LineClamp]: the clamp tells it when it
/// holds the line the block is cut at, and it then ends at the cut inside
/// it plus its own [bottom], the padding and border it closes on.
class ClampedBlock extends SingleChildRenderObjectWidget {
  const ClampedBlock({super.key, this.bottom = 0, super.child});

  /// The box's bottom padding and border.
  final double bottom;

  @override
  RenderClampedBlock createRenderObject(BuildContext context) => RenderClampedBlock(bottom);

  @override
  void updateRenderObject(BuildContext context, RenderClampedBlock renderObject) => renderObject.bottom = bottom;
}

/// The render object behind [ClampedBlock].
class RenderClampedBlock extends RenderProxyBox with ChildDryBaseline, KeptUnderHatch {
  RenderClampedBlock(this._bottom, [RenderBox? child]) : super(child);

  double _bottom;
  double get bottom => _bottom;
  set bottom(double v) {
    if (v == _bottom) return;
    _bottom = v;
    markNeedsLayout();
  }

  bool _cut = false;

  /// Where the content cut inside this box ends, in its own coordinates:
  /// the bottom of the next box down that holds the cut, or of the cut
  /// paragraph itself.
  double? _cutEnd() {
    double? end;
    bool walk(RenderObject r) {
      if (r is RenderLineClamp) return false;
      if (r is RenderBox &&
          ((r is RenderClampedBlock && r._cut) || (r is RenderBlockEllipsis && (r.budget ?? 0) > 0))) {
        end = r.localToGlobal(Offset.zero, ancestor: this).dy + r.size.height;
        return true;
      }
      var found = false;
      r.visitChildren((k) {
        if (!found) found = walk(k);
      });
      return found;
    }

    final c = child;
    if (c != null) walk(c);
    return end;
  }

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    c.layout(constraints, parentUsesSize: true);
    var h = c.size.height;
    if (_cut) {
      double? end;
      invokeLayoutCallback((Constraints _) => end = _cutEnd());
      if (end case final e?) h = math.min(h, e + _bottom);
    }
    size = constraints.constrain(Size(c.size.width, h));
  }
}
