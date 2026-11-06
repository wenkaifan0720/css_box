/// A paragraph whose first line starts somewhere else than the rest.
library;

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'balance.dart';
import 'dry.dart';
import 'pretty.dart';

/// `text-indent` (css-text-3 8.1) as a box of text: the FIRST line starts
/// [indent] in from the start edge -- or, where [indent] is negative, that
/// far OUT of it -- and every line after it starts at the edge. A hanging
/// indent is the negative one written beside a padding of the same size:
/// `padding-left: 30px; text-indent: -30px` puts a note's `※1` in the
/// padding and wraps its lines under the words, and a Japanese car listing's footnotes
/// are fifteen of these.
///
/// A Flutter paragraph has one width for every line, so the block is two:
/// the first line, set on its own in a room [indent] narrower than the box
/// (wider, for a hanging one) and painted [indent] along; and the words
/// after it, set as a paragraph of their own in the box's width under it.
/// The first line breaks where a browser breaks it -- greedily, in its own
/// room -- and the rest breaks where the browser breaks the rest, in the
/// box's. The lines are as tall as the strut and the style make them, as
/// a [Text]'s are, and the first line's baseline is the block's.
///
/// A PERCENTAGE is a [share] of the box's own width (8.1: "refers to the
/// block container's own inline-axis inner size"), which only the layout
/// knows: `text-indent: 15%` is a [share] of 0.15, on top of [indent]. The
/// widths the box is asked for before it has one -- its min-content and
/// max-content -- take it as nothing, as a percentage of a size not yet
/// known is (css-sizing-3 5.2.1).
///
/// THE START EDGE IS THE DIRECTION'S. Under `rtl` the first line's room is
/// cut from (or, hanging, grown past) the RIGHT edge: the line is set in
/// the same narrower or wider room and placed from the left, so a hanging
/// line reaches out past the right side, into `padding-right`.
///
/// A JUSTIFIED first line is spread to its room like any line that is not
/// a paragraph's last (7.3), and Skia spreads every line of a paragraph but
/// its last, so the first line is set with the line after it and drawn
/// alone.
///
/// A FORCED BREAK -- a line feed `white-space: pre` keeps -- ends the first
/// line wherever it stands, and the rest starts right after it, spaces and
/// all; with [softWrap] false no other break is taken, and no line wraps.
///
/// The text is one string, or one [TextSpan] tree of strings in styles
/// (a [han]-trimmed run is one). Where it wraps, its spaces are already
/// collapsed (`white-space: normal`): a soft break eats the space it lands
/// on, and the rest starts on the next word. A positive indent that does
/// not wrap is the same as an [edgeSpan] in front of a [Text]; the negative
/// one has no span, since a placeholder cannot be less than nothing wide. A
/// [WidgetSpan] has no place here: the rest is cut from the span tree by
/// code unit, and a placeholder holds no code unit to cut at.
///
/// A READER IS TOLD the words with each span's [TextSpan.semanticsLabel]
/// in that span's place, as [Text] tells them. The rest of what a [Text]
/// tells of its spans is not told: a span's spell-out, locale and
/// [TextSpan.recognizer] actions.
///
/// The rest is resolved for direction on its own (UAX #9), which is the
/// whole paragraph's resolution wherever it starts on a letter or nothing
/// before it is set against the paragraph's direction. Where it starts on
/// a neutral or a number after a letter of the other direction -- a Latin
/// word in an `rtl` block, a Hebrew one in an `ltr` block -- a mark of that
/// letter's class in front of it (U+200E, U+200F, U+061C) resolves it as
/// the whole paragraph does. An explicit embedding, an isolate, or an
/// Arabic-Indic digit before the cut is not carried over; the lowering
/// writes none of them here.
class IndentedText extends LeafRenderObjectWidget {
  IndentedText(
    String text, {
    super.key,
    this.indent = 0,
    this.share = 0,
    this.style,
    this.strutStyle,
    this.textAlign = TextAlign.start,
    this.softWrap = true,
    this.balance = false,
    this.pretty = false,
  }) : text = TextSpan(text: text);

  const IndentedText.rich(
    this.text, {
    super.key,
    this.indent = 0,
    this.share = 0,
    this.style,
    this.strutStyle,
    this.textAlign = TextAlign.start,
    this.softWrap = true,
    this.balance = false,
    this.pretty = false,
  });

  /// The words, as a [Text.rich] takes them; [style] is set under them.
  final TextSpan text;

  /// How far in from the start edge the first line begins, in pixels;
  /// negative is out.
  final double indent;

  /// How far in the first line begins as a part of the box's own width --
  /// 0.15 for `text-indent: 15%` -- on top of [indent].
  final double share;

  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign textAlign;

  /// False for `white-space: nowrap` and `pre`: no line wraps, however
  /// long.
  final bool softWrap;

  /// Whether the lines are re-broken to balance (`text-wrap: balance`,
  /// css-text-4 8.2), each against its own room -- the first against the
  /// one the indent leaves it -- as [Balance] re-breaks a paragraph.
  final bool balance;

  /// Whether a last line left holding one short word takes another down
  /// with it (`text-wrap: pretty`), as [Pretty] re-breaks a paragraph --
  /// the first line, where the four lines re-broken reach it, against its
  /// own room.
  final bool pretty;

  @override
  RenderIndentedText createRenderObject(BuildContext context) {
    final defaults = DefaultTextStyle.of(context);
    return RenderIndentedText(
      text: text,
      style: style == null || style!.inherit ? defaults.style.merge(style) : style!,
      indent: indent,
      share: share,
      strutStyle: strutStyle,
      textAlign: textAlign,
      softWrap: softWrap,
      balance: balance,
      pretty: pretty,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      textHeightBehavior: DefaultTextHeightBehavior.maybeOf(context),
      locale: Localizations.maybeLocaleOf(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderIndentedText renderObject) {
    final defaults = DefaultTextStyle.of(context);
    renderObject
      ..text = text
      ..style = style == null || style!.inherit ? defaults.style.merge(style) : style!
      ..indent = indent
      ..share = share
      ..strutStyle = strutStyle
      ..textAlign = textAlign
      ..softWrap = softWrap
      ..balance = balance
      ..pretty = pretty
      ..textDirection = Directionality.of(context)
      ..textScaler = MediaQuery.textScalerOf(context)
      ..textHeightBehavior = DefaultTextHeightBehavior.maybeOf(context)
      ..locale = Localizations.maybeLocaleOf(context);
  }
}

/// The two halves of an [IndentedText] as one layout set them.
typedef _Laid = ({
  /// The first line, alone: its height, its baseline and where it ends.
  TextPainter first,

  /// The first line as it is drawn where that is not [first]: set with the
  /// line after it, so a justified line is spread (see [IndentedText]).
  TextPainter? shown,

  /// The words after the first line, in the box's width.
  TextPainter? rest,
  String restText,

  /// How far in the first line starts: [RenderIndentedText.indent] and the
  /// share of the width.
  double at,
});

/// Release [l]'s painters: a layout's, once another replaces it or the box
/// is disposed, and a measurement's, once it is read. No two layouts share
/// a painter.
void _release(_Laid? l) {
  l?.first.dispose();
  l?.shown?.dispose();
  l?.rest?.dispose();
}

/// The render object behind [IndentedText].
class RenderIndentedText extends RenderBox with AsksGuarded, KeptUnderHatch {
  RenderIndentedText({
    required TextSpan text,
    required TextStyle style,
    double indent = 0,
    double share = 0,
    StrutStyle? strutStyle,
    TextAlign textAlign = TextAlign.start,
    bool softWrap = true,
    bool balance = false,
    bool pretty = false,
    required TextDirection textDirection,
    TextScaler textScaler = TextScaler.noScaling,
    TextHeightBehavior? textHeightBehavior,
    Locale? locale,
  }) : _text = text,
       _style = style,
       _indent = indent,
       _share = share,
       _strutStyle = strutStyle,
       _textAlign = textAlign,
       _softWrap = softWrap,
       _balance = balance,
       _pretty = pretty,
       _textDirection = textDirection,
       _textScaler = textScaler,
       _textHeightBehavior = textHeightBehavior,
       _locale = locale;

  TextSpan _text;
  TextSpan get text => _text;
  set text(TextSpan v) {
    if (v == _text) return;
    _text = v;
    _plain = null;
    _spoken = null;
    _dirty();
    markNeedsSemanticsUpdate();
  }

  /// The span's words end to end, which the cut is found in.
  String? _plain;
  String get _words => _plain ??= _text.toPlainText(includeSemanticsLabels: false);

  /// What a reader is told: the words, each span's [TextSpan.semanticsLabel]
  /// in that span's place.
  String? _spoken;

  TextStyle _style;
  TextStyle get style => _style;
  set style(TextStyle v) {
    if (v == _style) return;
    _style = v;
    _dirty();
  }

  double _indent;
  double get indent => _indent;
  set indent(double v) {
    if (v == _indent) return;
    _indent = v;
    _dirty();
  }

  double _share;
  double get share => _share;
  set share(double v) {
    if (v == _share) return;
    _share = v;
    _dirty();
  }

  StrutStyle? _strutStyle;
  StrutStyle? get strutStyle => _strutStyle;
  set strutStyle(StrutStyle? v) {
    if (v == _strutStyle) return;
    _strutStyle = v;
    _dirty();
  }

  TextAlign _textAlign;
  TextAlign get textAlign => _textAlign;
  set textAlign(TextAlign v) {
    if (v == _textAlign) return;
    _textAlign = v;
    _dirty();
  }

  bool _softWrap;
  bool get softWrap => _softWrap;
  set softWrap(bool v) {
    if (v == _softWrap) return;
    _softWrap = v;
    _dirty();
  }

  bool _balance;
  bool get balance => _balance;
  set balance(bool v) {
    if (v == _balance) return;
    _balance = v;
    markNeedsLayout();
  }

  bool _pretty;
  bool get pretty => _pretty;
  set pretty(bool v) {
    if (v == _pretty) return;
    _pretty = v;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection v) {
    if (v == _textDirection) return;
    _textDirection = v;
    _dirty();
  }

  TextScaler _textScaler;
  TextScaler get textScaler => _textScaler;
  set textScaler(TextScaler v) {
    if (v == _textScaler) return;
    _textScaler = v;
    _dirty();
  }

  TextHeightBehavior? _textHeightBehavior;
  TextHeightBehavior? get textHeightBehavior => _textHeightBehavior;
  set textHeightBehavior(TextHeightBehavior? v) {
    if (v == _textHeightBehavior) return;
    _textHeightBehavior = v;
    _dirty();
  }

  Locale? _locale;
  Locale? get locale => _locale;
  set locale(Locale? v) {
    if (v == _locale) return;
    _locale = v;
    _dirty();
  }

  void _dirty() {
    _whole?.dispose();
    _whole = null;
    _extent = null;
    _least = null;
    markNeedsLayout();
  }

  TextPainter _painter(TextSpan words, {int? maxLines}) => TextPainter(
    text: TextSpan(style: _style, children: [words]),
    textDirection: _textDirection,
    textAlign: _textAlign,
    textScaler: _textScaler,
    strutStyle: _strutStyle,
    textHeightBehavior: _textHeightBehavior,
    locale: _locale,
    maxLines: maxLines,
  );

  /// [painter] laid out in a room [room] wide, its lines placed in that
  /// room by [textAlign] as a [Text] places its lines in its box: the room
  /// is the least width as well as the most, or a short line set to the
  /// right or the centre would be placed in its own width. Where no line
  /// wraps the room is only the least.
  TextPainter _lay(TextPainter painter, double room) =>
      painter..layout(minWidth: room, maxWidth: _softWrap ? room : double.infinity);

  /// The whole text on one line: the intrinsic widths.
  TextPainter? _whole;
  TextPainter get _measured => _whole ??= _painter(_text)..layout();

  /// [span] from code unit [from] on, its styles kept: the rest of the
  /// text, cut where the first line ended. A span wholly before the cut is
  /// dropped, one across it keeps its tail.
  static TextSpan _tail(TextSpan span, int from) {
    final own = span.text ?? '';
    final text = from >= own.length ? null : (from <= 0 ? own : own.substring(from));
    var left = from - own.length;
    final kids = <InlineSpan>[];
    for (final k in span.children ?? const <InlineSpan>[]) {
      final n = k.toPlainText(includeSemanticsLabels: false).length;
      if (left >= n) {
        left -= n;
        continue;
      }
      assert(k is TextSpan, 'a WidgetSpan cannot be cut');
      kids.add(left > 0 ? _tail(k as TextSpan, left) : k);
      left = 0;
    }
    return TextSpan(text: text, style: span.style, children: kids.isEmpty ? null : kids);
  }

  /// [span] up to code unit [to], its styles kept: what [_tail] leaves.
  static TextSpan _head(TextSpan span, int to) {
    final own = span.text ?? '';
    final text = to <= 0 || own.isEmpty ? null : (to >= own.length ? own : own.substring(0, to));
    var left = to - own.length;
    final kids = <InlineSpan>[];
    for (final k in span.children ?? const <InlineSpan>[]) {
      if (left <= 0) break;
      final n = k.toPlainText(includeSemanticsLabels: false).length;
      assert(k is TextSpan, 'a WidgetSpan cannot be cut');
      kids.add(left >= n ? k : _head(k as TextSpan, left));
      left -= n;
    }
    return TextSpan(text: text, style: span.style, children: kids.isEmpty ? null : kids);
  }

  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);

  /// The class UAX #9 gives the LETTER [c]: `L`, `R` or `AL` (an Arabic,
  /// Syriac or Thaana one); null for anything that is not a letter.
  static String? _strong(int c) {
    if (!_letter.hasMatch(String.fromCharCode(c))) return null;
    if ((c >= 0x0600 && c <= 0x07BF) ||
        (c >= 0x0860 && c <= 0x08FF) ||
        (c >= 0xFB50 && c <= 0xFDFF) ||
        (c >= 0xFE70 && c <= 0xFEFF) ||
        (c >= 0x1EE00 && c <= 0x1EEFF)) {
      return 'AL';
    }
    if ((c >= 0x0590 && c <= 0x05FF) ||
        (c >= 0x07C0 && c <= 0x085F) ||
        (c >= 0xFB1D && c <= 0xFB4F) ||
        (c >= 0x10800 && c <= 0x10FFF) ||
        (c >= 0x1E800 && c <= 0x1EDFF)) {
      return 'R';
    }
    return 'L';
  }

  /// The mark that resolves the rest as the whole paragraph resolves it
  /// (see [IndentedText]), or null where none is needed: the rest starts
  /// on a letter, or the last letter before the cut is of the paragraph's
  /// own direction. The neutrals and numbers the rest starts on take their
  /// direction from that letter (UAX #9 W2, W7, N1), which the rest, set
  /// alone, would take from the paragraph instead.
  String? _mark(String words, int cut) {
    final after = words.substring(cut).runes;
    if (after.isEmpty || _strong(after.first) != null) return null;
    final before = words.substring(0, cut).runes.toList();
    String? last;
    for (var i = before.length - 1; i >= 0 && last == null; i--) {
      last = _strong(before[i]);
    }
    if (last == null || last == (_textDirection == TextDirection.rtl ? 'R' : 'L')) return null;
    return switch (last) {
      'L' => '\u200E',
      'R' => '\u200F',
      _ => '\u061C',
    };
  }

  /// The first line and the rest, laid out for a box [width] wide: broken
  /// greedily, or re-broken to [balance] or [pretty] where it asks.
  _Laid _lines(double width) {
    final greedy = _linesOf(_text, _words, width);
    if (!_balance && !_pretty) return greedy;
    final rebroken = _rebroken(greedy, width);
    if (rebroken == null) return greedy;
    _release(greedy);
    return rebroken;
  }

  /// [greedy]'s lines re-broken as [Balance] or [Pretty] breaks a
  /// paragraph (css-text-4 8.2) -- the same count -- with the first line
  /// scored against its OWN room, the one the indent leaves it
  /// (`fixtures/indent-hanging-balance`, `fixtures/indent-hanging-pretty`:
  /// Chrome sets a product site's hanging quotes so, and not against the box's
  /// width). Null where it stays greedy: a balanced block past
  /// [RenderBalance.maxLines] lines, a justified or unwrapped block, one
  /// that is not left to right, and text with a forced break or anything
  /// but text in it.
  _Laid? _rebroken(_Laid greedy, double width) {
    if (!_softWrap || _textAlign == TextAlign.justify || _textDirection != TextDirection.ltr) return null;
    final lines = greedy.first.computeLineMetrics().length + (greedy.rest?.computeLineMetrics().length ?? 0);
    if (lines < 2 || _balance && lines > RenderBalance.maxLines) return null;
    final words = _words;
    if (words.contains('\n')) return null;
    final opp = RenderBalance.opportunities(words);
    if (opp.length < lines) return null;
    // Every prefix's width, off ONE laid-out line (see [RenderBalance]).
    final painter = _painter(_text)..layout();
    try {
      painter.layout(maxWidth: painter.maxIntrinsicWidth.ceilToDouble() + 1);
      final at = <int, double>{};
      double x(int i) => at.putIfAbsent(i, () => painter.getOffsetForCaret(TextPosition(offset: i), Rect.zero).dx);
      final firstRoom = math.max(0.0, width - greedy.at);
      final cuts = _balance
          ? RenderBalance.balancedCuts(opp, x, width, lines, firstRoom: firstRoom)
          : RenderPretty.prettyCuts(opp, x, width, lines, firstRoom: firstRoom);
      if (cuts == null) return null;
      final broken = RenderBalance.brokenOn(_text, opp, cuts);
      return _linesOf(broken, broken.toPlainText(includeSemanticsLabels: false), width);
    } finally {
      painter.dispose();
    }
  }

  /// [text] -- whose words are [words] -- as a first line and the rest in
  /// a box [width] wide.
  _Laid _linesOf(TextSpan text, String words, double width) {
    final at = _indent + _share * width;
    final room = math.max(0.0, width - at);
    final first = _lay(_painter(text, maxLines: 1), room);
    // Where the first line ends: the break Skia took in its room. A forced
    // break ends it with its line feed, and the rest starts right after
    // that; a soft break sits on collapsed spaces, which no line starts
    // with.
    var end = first.getLineBoundary(const TextPosition(offset: 0)).end;
    if (end <= 0 && words.isNotEmpty) end = math.min(words.length, 1);
    final fed = end > 0 && end <= words.length && words.codeUnitAt(end - 1) == 0x0A;
    if (!fed && end < words.length && words.codeUnitAt(end) == 0x0A) {
      end++;
    } else if (!fed) {
      if (!_softWrap) end = words.length;
      while (end < words.length && words.codeUnitAt(end) == 0x20) {
        end++;
      }
    }
    if (end >= words.length) return (first: first, shown: null, rest: null, restText: '', at: at);
    final forced = words.codeUnitAt(end - 1) == 0x0A;
    final restText = words.substring(end);
    var tail = _tail(text, end);
    if (_mark(words, end) case final mark?) {
      tail = TextSpan(
        children: [
          TextSpan(text: mark),
          tail,
        ],
      );
    }
    final rest = _lay(_painter(tail), width);
    final shown = _textAlign == TextAlign.justify && !forced ? _lay(_painter(text, maxLines: 2), room) : null;
    return (first: first, shown: shown, rest: rest, restText: restText, at: at);
  }

  /// The words after the first line, as the last layout broke them; empty
  /// where one line held them all.
  @visibleForTesting
  String get restText => _laid?.restText ?? '';

  /// The span the rest was set from: the text's tail, styles kept.
  @visibleForTesting
  InlineSpan? get restSpan => _laid?.rest?.text;

  /// How wide the first line is drawn: its whole room where it is
  /// justified.
  @visibleForTesting
  double? get firstLineWidth {
    final lines = _laid;
    if (lines == null) return null;
    final metrics = (lines.shown ?? lines.first).computeLineMetrics();
    return metrics.isEmpty ? null : metrics.first.width;
  }

  _Laid? _laid;

  /// The text's max-content width: every line as long as nothing but a
  /// forced break makes it, the first one [indent] along.
  double? _extent;
  double get _maxContent => _extent ??= _measureExtent();

  double _measureExtent() {
    final words = _words;
    final cut = words.indexOf('\n');
    if (cut < 0) return math.max(0.0, _measured.maxIntrinsicWidth + _indent);
    final head = _painter(_head(_text, cut)), tail = _painter(_tail(_text, cut + 1));
    try {
      head.layout();
      tail.layout();
      return math.max(0.0, math.max(head.maxIntrinsicWidth + _indent, tail.maxIntrinsicWidth));
    } finally {
      head.dispose();
      tail.dispose();
    }
  }

  /// The box's width under [constraints]: as a [Text]'s, its own greatest
  /// width held between the bounds -- the whole text on one line, which
  /// starts [indent] along.
  double _widthFor(BoxConstraints constraints) {
    if (constraints.hasTightWidth) return constraints.maxWidth;
    return _maxContent.clamp(constraints.minWidth, constraints.maxWidth);
  }

  Size _sizeFor(BoxConstraints constraints) {
    final width = _widthFor(constraints);
    final lines = _lines(width);
    try {
      return constraints.constrain(Size(width, lines.first.height + (lines.rest?.height ?? 0)));
    } finally {
      _release(lines);
    }
  }

  /// The text's min-content width: every line as short as a break lets it
  /// be (css-text-3 5), the first one [indent] along -- the least room the
  /// first piece fits in beside the indent, and every piece after it alone.
  double? _least;
  double get _minContent => _least ??= _measureLeast();

  double _measureLeast() {
    final words = _words;
    var end = _firstPieceEnd();
    // The rest starts on the next piece: a soft break sits on collapsed
    // spaces, which no line starts with.
    while (end < words.length && words.codeUnitAt(end) == 0x20) {
      end++;
    }
    if (end >= words.length) return math.max(0.0, _measured.minIntrinsicWidth + _indent);
    final head = _painter(_head(_text, end)), tail = _painter(_tail(_text, end));
    try {
      head.layout();
      tail.layout();
      return math.max(0.0, math.max(head.minIntrinsicWidth + _indent, tail.minIntrinsicWidth));
    } finally {
      head.dispose();
      tail.dispose();
    }
  }

  /// Where the text's first piece ends: the first place a line may break
  /// (css-text-3 5.1), as Skia's breaker finds it. Set in the width of its
  /// own widest piece, a text's first line holds its first piece and
  /// whatever else fits beside it; that line, set alone in ITS widest
  /// piece, holds fewer; a line that fits in its widest piece is one piece.
  int _firstPieceEnd() {
    var end = _words.length;
    var words = _text;
    // Each round the line loses a piece at least.
    for (var round = 0; round < 64; round++) {
      final painter = _painter(words);
      final int line;
      try {
        painter.layout();
        // Skia measures a word a hair narrower than it sets it; half a pixel
        // is less than any piece but a blank one.
        painter.layout(maxWidth: painter.minIntrinsicWidth + 0.5);
        line = painter.getLineBoundary(const TextPosition(offset: 0)).end;
      } finally {
        painter.dispose();
      }
      if (line <= 0 || line >= end) return end;
      end = line;
      words = _head(_text, end);
    }
    return end;
  }

  /// A text that does not wrap is as narrow as its longest line (css-text-3
  /// 3); one that wraps, as its longest piece, with the first line's piece
  /// [indent] in -- a hanging indent takes its width off the first piece
  /// alone, and a positive one adds to it alone.
  @override
  double computeMinIntrinsicWidth(double height) => _softWrap ? _minContent : _maxContent;

  @override
  double computeMaxIntrinsicWidth(double height) => _maxContent;

  /// AT NO WIDTH -- a `Column` measuring its own width asks each child's
  /// height at `double.infinity` -- the text is its whole length on one
  /// line, as a [Text]'s is: held to an infinite width, the share of the
  /// indent (`0 * infinity`) and the room it leaves came to NaN, which the
  /// painter refuses. The product site's 1280 page threw on its first frame.
  @override
  double computeMinIntrinsicHeight(double width) =>
      _sizeFor(width.isFinite ? BoxConstraints.tightFor(width: width) : const BoxConstraints()).height;

  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sizeFor(constraints);

  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
    final lines = _lines(_widthFor(constraints));
    try {
      return lines.first.computeDistanceToActualBaseline(baseline);
    } finally {
      _release(lines);
    }
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      _laid?.first.computeDistanceToActualBaseline(baseline);

  @override
  void performLayout() {
    final width = _widthFor(constraints);
    final lines = _lines(width);
    _release(_laid);
    _laid = lines;
    final height = lines.first.height + (lines.rest?.height ?? 0);
    size = constraints.constrain(Size(width, height));
  }

  @override
  void dispose() {
    _release(_laid);
    _laid = null;
    _whole?.dispose();
    _whole = null;
    super.dispose();
  }

  /// Far enough that a clip this far out clips nothing.
  static const double _far = 1e9;

  @override
  void paint(PaintingContext context, Offset offset) {
    final lines = _laid;
    if (lines == null) return;
    final canvas = context.canvas;
    // The first line's room starts [at] along from the left; under `rtl`
    // it is cut from the right, and starts at the left itself.
    final origin = offset + Offset(_textDirection == TextDirection.rtl ? 0 : lines.at, 0);
    if (lines.shown case final shown?) {
      canvas
        ..save()
        ..clipRect(Rect.fromLTRB(-_far, -_far, _far, offset.dy + lines.first.height));
      shown.paint(canvas, origin);
      canvas.restore();
    } else {
      lines.first.paint(canvas, origin);
    }
    lines.rest?.paint(canvas, offset + Offset(0, lines.first.height));
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..label = _spoken ??= _text.toPlainText()
      ..textDirection = _textDirection;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('text', _words))
      ..add(DoubleProperty('indent', _indent))
      ..add(DoubleProperty('share', _share, defaultValue: 0.0))
      ..add(EnumProperty<TextAlign>('textAlign', _textAlign))
      ..add(FlagProperty('softWrap', value: _softWrap, ifFalse: 'no wrapping'))
      ..add(FlagProperty('balance', value: _balance, ifTrue: 'balanced'))
      ..add(FlagProperty('pretty', value: _pretty, ifTrue: 'pretty'));
  }
}
