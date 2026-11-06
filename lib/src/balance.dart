/// The breaks a BALANCED paragraph is laid out on.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';
import 'linebox.dart';

/// A block whose lines are broken to be as EVEN as they can be
/// (`text-wrap: balance`, css-text-4 8.2).
///
/// A browser breaks a paragraph GREEDILY: each line takes as many words as
/// fit and the last one is whatever is over. A block asked to balance is
/// broken so that no line is much longer than another -- of every set of
/// breaks that takes the same number of lines, the one whose lines leave
/// the least room over, summed AS SQUARES ACROSS ALL THE LINES, THE LAST
/// ONE INCLUDED. (Leave the last line out of that sum and greedy always
/// wins, which is what the neighbouring `text-wrap: pretty` does; this
/// only claims `balance`.)
///
/// The set it lands on is USUALLY NOT A GREEDY ONE AT ANY WIDTH, which is
/// why this is a search over break points and not over widths. A
/// framework site's hero is the case: `The web framework` is 337.98 wide in a 358 box and
/// `for content-driven` is 325, so no room both fits the first line and
/// pushes `driven` off the second -- and Chrome still breaks it `The web
/// framework / for content- / driven websites`, because that is the even
/// set. The breaks are then stated as hard ones on the paragraph itself.
///
/// The line count never changes, so a balanced block is exactly as TALL as
/// the greedy one and nothing around it moves. Neither does the box:
/// balancing has no effect on intrinsic sizing (css-text-4 8.2), so a
/// `fit-content` heading is as wide as its GREEDY longest line and the
/// balanced lines sit inside it, which is what Chrome draws.
class Balance extends SingleChildRenderObjectWidget {
  const Balance({super.key, super.child});

  @override
  RenderBalance createRenderObject(BuildContext context) => RenderBalance();
}

/// The render object behind [Balance]: the paragraph under it is laid out
/// on the breaks [cuts] names, which [RenderPretty] answers differently.
class RenderBalance extends RenderProxyBox with DryLastBaseline, AsksGuarded, PassesBaseline, KeptUnderHatch {
  RenderBalance({RenderBox? child}) : super(child);

  /// Blink balances a paragraph of at most this many lines; a longer one is
  /// broken greedily, because the search costs a layout a line.
  static const int maxLines = 6;

  /// The most lines a paragraph may take and still be re-broken here.
  int get lineCap => maxLines;

  /// The paragraph under [child] (see [_chain]).
  RenderParagraph? _paragraph() => _chain()?.last as RenderParagraph?;

  /// The boxes from [child] down to the paragraph, the paragraph last:
  /// the emitter puts a line box between them, and a `Text` its own
  /// semantics and mouse region.
  ///
  /// EVERY BOX BETWEEN IS ONE THIS BOX CAN STAND IN FOR. A question asked
  /// at a width other than the one the paragraph was last broken for is
  /// answered by a copy of the chain holding the span a layout at that
  /// width would put there ([_measured]), so only a line box and the boxes
  /// that answer as their child does are passed through. Null -- the
  /// paragraph left greedy -- where there is no paragraph within reach or
  /// a box between could answer otherwise (a `ConstrainedBox`, an
  /// `IgnoreBaseline`): breaks it cannot be asked about would answer a
  /// height the layout does not keep.
  List<RenderBox>? _chain() {
    final out = <RenderBox>[];
    var box = child;
    for (var i = 0; i < 4 && box != null; i++) {
      out.add(box);
      if (box is RenderParagraph) return out;
      if (box is! RenderLineBox && !_passesThrough(box)) return null;
      box = (box as RenderProxyBox).child;
    }
    return null;
  }

  /// The proxies that answer every size and baseline as their child does.
  static bool _passesThrough(RenderBox box) =>
      box is RenderSemanticsAnnotations ||
      box is RenderExcludeSemantics ||
      box is RenderMergeSemantics ||
      box is RenderBlockSemantics ||
      box is RenderIndexedSemantics ||
      box is RenderSemanticsGestureHandler ||
      box is RenderMouseRegion ||
      box is RenderPointerListener ||
      box is RenderIgnorePointer ||
      box is RenderAbsorbPointer ||
      box is RenderRepaintBoundary ||
      box is RenderMetaData ||
      box is RenderOpacity ||
      box is RenderAnimatedOpacity;

  /// The span as the widget built it, before any break of ours.
  InlineSpan? _source;

  /// The span we last put on the paragraph: [_source], or one re-broken.
  InlineSpan? _installed;

  /// The re-broken span for each room the paragraph was asked about, keyed
  /// by the room and the width its lines are laid out at there ([_laidAt]);
  /// null where it stays greedy. Every entry is worked out of [_source] in
  /// [_config].
  final Map<(double, double), InlineSpan?> _byRoom = {};

  /// What the breaks were worked out under besides the room: the
  /// paragraph's text scaler, locale, strut, direction and the rest of what
  /// moves a break ([_configOf]).
  List<Object?>? _config;

  /// Reads the paragraph's span back: ours, the one a rebuild put back, or
  /// a new one, which throws the old breaks away.
  void _sync(RenderParagraph p) {
    final t = p.text;
    if (_installed != null && (identical(t, _installed) || t == _installed)) return;
    if (_source != null && (identical(t, _source) || t == _source)) return;
    _source = t;
    _installed = null;
    _byRoom.clear();
  }

  /// Everything of [p]'s besides its span and its room that moves where its
  /// lines break. A text scaler, a locale, a strut or a direction changed
  /// under a paragraph broken already re-breaks it: kept, the breaks made at
  /// a scale of 1 stood at 2, and a paragraph that is three lines when
  /// mounted at 2 stood four.
  static List<Object?> _configOf(RenderParagraph p) => [
    p.textScaler,
    p.locale,
    p.strutStyle,
    p.textDirection,
    p.textWidthBasis,
    p.textHeightBehavior,
    p.softWrap,
    p.maxLines,
    p.overflow,
  ];

  /// A paragraph of ONE run of plain text: a line with an inline box or a
  /// second style on it is not something a break can be moved through here.
  /// The one span in [s] that holds text, where there is exactly one and
  /// nothing else that paints: the text itself, or -- as the lowering's
  /// component templates write a heading, the text in a child span that
  /// carries the font -- a chain of spans down to it. A docs site's "Get
  /// professional support" heading was set greedily through one of those.
  /// The paragraph's text, span by span: every `TextSpan` that holds text,
  /// in the order it is drawn. A heading is usually one; a site's hero can be a
  /// bold product name and the rest of the sentence, and a break can fall in
  /// either. Null where a placeholder is among them, or a forced break
  /// where [breaks] is false.
  static List<TextSpan>? _leaves(InlineSpan? s, {bool breaks = false}) {
    final out = <TextSpan>[];
    bool walk(InlineSpan k) {
      if (k is! TextSpan) return false;
      final t = k.text;
      if (t != null && t.isNotEmpty) {
        if (!breaks && t.contains('\n')) return false;
        out.add(k);
      }
      for (final c in k.children ?? const <InlineSpan>[]) {
        if (!walk(c)) return false;
      }
      return true;
    }

    if (s == null || !walk(s)) return null;
    return out.isEmpty ? null : out;
  }

  /// Whether each paragraph a forced break ends is re-broken, or the first
  /// alone (see [_balance]).
  bool get everyParagraph => false;

  /// [s] with each leaf's text replaced by its entry in [texts], in the order
  /// of [_leaves]. By place, not by the span: a `const` span written twice in
  /// a paragraph is one object. Keyed by identity, a `<wbr>`'s zero-width
  /// space written twice took the second's line break at the first as well,
  /// and a paragraph of four lines stood five: `up-` / `to-` / `date PRDs.`
  /// where a dry run had said four, its grid row one line short.
  static InlineSpan _swap(InlineSpan s, Iterator<String> texts) {
    final t = s as TextSpan;
    final text = t.text != null && t.text!.isNotEmpty && texts.moveNext() ? texts.current : t.text;
    return TextSpan(
      text: text,
      children: t.children == null ? null : [for (final k in t.children!) _swap(k, texts)],
      style: t.style,
      recognizer: t.recognizer,
      mouseCursor: t.mouseCursor,
      onEnter: t.onEnter,
      onExit: t.onExit,
      semanticsLabel: t.semanticsLabel,
      locale: t.locale,
      spellOut: t.spellOut,
    );
  }

  String? _plain(InlineSpan? s) {
    final ls = _leaves(s, breaks: true);
    if (ls == null) return null;
    final t = ls.map((l) => l.text!).join();
    return t.length < 2 ? null : t;
  }

  TextPainter _painter(RenderParagraph p, InlineSpan span) => TextPainter(
    text: span,
    textDirection: p.textDirection,
    textScaler: p.textScaler,
    strutStyle: p.strutStyle,
    locale: p.locale,
    textWidthBasis: p.textWidthBasis,
    textHeightBehavior: p.textHeightBehavior,
  );

  /// Where a line may end and where the next one starts: after a space,
  /// which the break eats, and after a hyphen, which stays on the line
  /// (`content-` / `driven`). The last pair closes the paragraph.
  static List<(int, int)> _opportunities(String t) {
    final out = <(int, int)>[];
    for (var i = 0; i < t.length - 1; i++) {
      final c = t.codeUnitAt(i);
      if (c == 0x20) {
        if (t.codeUnitAt(i + 1) != 0x20) out.add((i, i + 1));
      } else if ((c == 0x2D || c == 0x2013 || c == 0x2014) && i > 0 && t.codeUnitAt(i + 1) != 0x20) {
        out.add((i + 1, i + 1));
      }
    }
    out.add((t.length, t.length));
    return out;
  }

  /// The breaks the paragraph is re-broken on, or null to leave it greedy:
  /// the indices into [opp] where its lines end, LAST FIRST and closed
  /// with 0 (`[opp.length, ..., 0]`). A line from break `i` to break `j`
  /// runs from the character after the space `opp[i - 1]` eats (or 0) to
  /// the one `opp[j - 1]` names, and [x] is the caret offset of a
  /// character on the run laid out as one line, so its width is
  /// `x(end) - x(start)`. [room] is the line's width and [lines] the
  /// count the greedy break takes. [firstRoom] is the FIRST line's room
  /// where `text-indent` makes it another (css-text-3 8.1): each line is
  /// scored against its own room, so a hanging first line is balanced
  /// against the wider one (`fixtures/indent-hanging-balance`).
  List<int>? cuts(List<(int, int)> opp, double Function(int) x, double room, int lines, {double? firstRoom}) =>
      balancedCuts(opp, x, room, lines, firstRoom: firstRoom);

  /// [cuts] as [Balance] takes them, for a box that sets its own lines.
  static List<int>? balancedCuts(
    List<(int, int)> opp,
    double Function(int) x,
    double room,
    int lines, {
    double? firstRoom,
  }) {
    // f[k][j]: the least cost of covering the first j breaks in k lines,
    // and from[k][j] the break the last of those lines started after.
    const huge = double.infinity;
    final f = List.generate(lines + 1, (_) => List<double>.filled(opp.length + 1, huge));
    final from = List.generate(lines + 1, (_) => List<int>.filled(opp.length + 1, -1));
    f[0][0] = 0;
    for (var k = 1; k <= lines; k++) {
      for (var j = k; j <= opp.length; j++) {
        final end = opp[j - 1].$1;
        for (var i = k - 1; i < j; i++) {
          if (f[k - 1][i] == huge) continue;
          final start = i == 0 ? 0 : opp[i - 1].$2;
          final w = x(end) - x(start);
          // A line wider than the room is only allowed where it holds
          // one unbreakable stretch, which CSS lets hang out of the box.
          final r = k == 1 ? firstRoom ?? room : room;
          if (w > r && j - i > 1) continue;
          final over = r - w;
          // A LINE THAT ENDS AT A HYPHEN COSTS A LITTLE MORE than one that
          // ends at a space (Knuth-Plass's hyphen penalty). A phone-width
          // hero can be `framework optimized / for building fast, /
          // content-driven websites.` or `framework optimized for /
          // building fast, content- / driven websites.`, seven apart in
          // squared room out of twenty thousand, and Chrome sets the one
          // without the hyphen; a twentieth of the room, squared, settles
          // it and leaves `for content- / driven websites` (13,000 ahead)
          // where it was.
          final hyphen = j < opp.length && opp[j - 1].$1 == opp[j - 1].$2;
          final cost = f[k - 1][i] + over * over + (hyphen ? room * room / 400 : 0);
          if (cost < f[k][j]) {
            f[k][j] = cost;
            from[k][j] = i;
          }
        }
      }
    }
    if (f[lines][opp.length] == huge) return null;
    final cuts = <int>[];
    var j = opp.length;
    for (var k = lines; k > 0; k--) {
      cuts.add(j);
      j = from[k][j];
    }
    cuts.add(0);
    return cuts;
  }

  /// The span the re-broken lines make of [_source], or null where there
  /// is nothing to move.
  ///
  /// A FORCED BREAK ENDS A PARAGRAPH -- a `<br>`, or a segment break
  /// `pre-line` keeps (Blink's `LineInfo::IsEndParagraph`) -- and each is
  /// broken on its own: a balanced block re-breaks its FIRST paragraph
  /// alone, Blink balancing from the block's first line only
  /// (`initiate_balancing_`), a pretty one every paragraph ([everyParagraph]),
  /// each against the greedy count of its own lines. Read whole, the
  /// paragraphs of one block were one search over the breaks of all of
  /// them, which no set of breaks keeping the count moves -- so they were
  /// left greedy: `fixtures/inline-flow-pre-line-balance` p4, p5 (css_box's
  /// `InlineFlow` sets such a block so too).
  ///
  /// Worked out of the SOURCE, never of a span put on the paragraph before:
  /// a layout, a dry layout and an intrinsic height each ask it for their
  /// own room ([_breaksFor]), whose lines are laid out [at] ([_laidAt]).
  InlineSpan? _balance(RenderParagraph p, String text, double at) {
    final brk = <int, int>{};
    var from = 0;
    while (from <= text.length) {
      final nl = text.indexOf('\n', from);
      final to = nl < 0 ? text.length : nl;
      if (to - from >= 2) {
        final part = _paragraph1(p, text, from, to, at);
        if (part != null) brk.addAll(part);
      }
      if (nl < 0 || !everyParagraph) break;
      from = to + 1;
    }
    return brk.isEmpty ? null : _brokenAt(_source!, brk);
  }

  /// The span a layout in [room] puts on [p]: [_balance]'s, kept by room,
  /// or null where the paragraph stays greedy there.
  InlineSpan? _breaksFor(RenderParagraph p, double room) {
    final text = _plain(_source);
    if (text == null || !room.isFinite || room <= 0 || !p.softWrap) return null;
    if (p.maxLines != null || p.overflow == TextOverflow.ellipsis) return null;
    final config = _configOf(p);
    if (!listEquals(config, _config)) {
      _config = config;
      _byRoom.clear();
    }
    final at = _laidAt(room);
    final key = (room, at);
    if (_byRoom.containsKey(key)) return _byRoom[key];
    // A box asked at many widths keeps the last few: a layout's own and
    // the dry questions round it.
    if (_byRoom.length >= 8) _byRoom.clear();
    return _byRoom[key] = _balance(p, text, at);
  }

  /// The span [p] holds laid out in [room], a width with no bound being
  /// null: the source, re-broken where it is re-broken there. Null where
  /// there is no source to read.
  InlineSpan? _wanted(RenderParagraph p, double? room) => room == null ? _source : _breaksFor(p, room) ?? _source;

  /// The room a layout under [c] breaks the lines in ([performLayout]);
  /// null where the width has no bound.
  double? _roomOf(BoxConstraints c) {
    if (!c.maxWidth.isFinite) return null;
    return c.hasTightWidth ? c.maxWidth : math.min(computeMaxIntrinsicWidth(double.infinity), c.maxWidth);
  }

  /// The box to ask a question about the paragraph laid out in [room]
  /// (null: a width with no bound): [child], where the paragraph holds the
  /// span a layout there puts on it, and otherwise a stand-in -- the chain
  /// down to the paragraph, copied ([_standIn]), holding that span.
  ///
  /// THE BREAKS ON THE PARAGRAPH ARE ITS LAST LAYOUT'S. Asked by the
  /// paragraph as it stands, a `Balance` laid out at 180 answered a dry
  /// layout at 700 with its three lines of 180 where the same words are one
  /// line at 700, and a track measured that way kept the old height after
  /// a resize.
  RenderBox _measured(double? room) {
    final child = this.child!;
    final chain = _chain();
    if (chain == null) return child;
    final p = chain.last as RenderParagraph;
    _sync(p);
    final want = _wanted(p, room);
    if (want == null || identical(p.text, want) || p.text == want) return child;
    return _standIn(chain, want);
  }

  /// The copy of the chain [_measured] asks, and what it was copied from.
  List<RenderBox>? _copy;
  List<Object?>? _copyOf;

  /// [chain] copied, unattached, its paragraph holding [text]: a line box
  /// as a line box set the same way, the paragraph as a paragraph set the
  /// same way, every box between as a plain proxy (each answers as its
  /// child does, [_passesThrough]). Copied again whenever anything it was
  /// copied from has changed, so nothing it measured before is kept.
  RenderBox _standIn(List<RenderBox> chain, InlineSpan text) {
    final of = <Object?>[text];
    for (final box in chain) {
      switch (box) {
        case RenderParagraph():
          of.addAll([box.textAlign, ..._configOf(box)]);
        case RenderLineBox():
          final g = box.grown;
          of.addAll([
            RenderLineBox,
            box.keepWords,
            box.anywhere,
            box.lineHeight,
            box.height,
            box.ascent,
            g?.lineHeight,
            g?.ascent,
            ...?g?.styles,
            g?.styles.length,
          ]);
        default:
          of.add(RenderProxyBox);
      }
    }
    final copy = _copy;
    if (copy != null && listEquals(of, _copyOf)) return copy.first;
    _dropCopy();
    RenderBox? below;
    final made = <RenderBox>[];
    for (final box in chain.reversed) {
      final RenderBox c = switch (box) {
        RenderParagraph() => RenderParagraph(
          text,
          textAlign: box.textAlign,
          textDirection: box.textDirection,
          softWrap: box.softWrap,
          overflow: box.overflow,
          textScaler: box.textScaler,
          maxLines: box.maxLines,
          locale: box.locale,
          strutStyle: box.strutStyle,
          textWidthBasis: box.textWidthBasis,
          textHeightBehavior: box.textHeightBehavior,
        ),
        RenderLineBox() => RenderLineBox(
          keepWords: box.keepWords,
          anywhere: box.anywhere,
          lineHeight: box.lineHeight,
          height: box.height,
          ascent: box.ascent,
          grown: box.grown,
          child: below,
        ),
        _ => RenderProxyBox(below),
      };
      made.insert(0, c);
      below = c;
    }
    _copy = made;
    _copyOf = of;
    return made.first;
  }

  void _dropCopy() {
    final copy = _copy;
    _copy = null;
    _copyOf = null;
    if (copy == null) return;
    for (final box in copy) {
      box.dispose();
    }
  }

  @override
  void dispose() {
    _dropCopy();
    super.dispose();
  }

  /// The width the line box under [child] lays the lines out at, handed
  /// [room].
  ///
  /// THE GREEDY COUNT IS THE ONE AT THAT WIDTH. A line box keeps a word
  /// whole, so a room under the longest run (`ingest&nbsp;events` in a narrow
  /// cell) lays the paragraph out at that run. Counted at the room itself,
  /// Skia broke the run inside and took a line more; the set of that many
  /// lines went in (`per / 1K / ingest events`, where Chrome and the greedy
  /// paragraph take `per 1K / ingest events`), taller than the dry layout
  /// that [computeDryLayout] reads off the paragraph as it stands, and a
  /// track measured before the set went in stood a line short.
  double _laidAt(double room) {
    var box = child;
    for (var i = 0; i < 4 && box != null; i++) {
      if (box is RenderLineBox) return box.linesWidth(room);
      if (box is! RenderProxyBox) break;
      box = box.child;
    }
    return room;
  }

  /// The breaks of the paragraph of [text] from [from] to [to] (no forced
  /// break in it), as [_brokenAt] takes them: where each line but the last
  /// ends, to where the next starts; null to leave it greedy.
  Map<int, int>? _paragraph1(RenderParagraph p, String text, int from, int to, double room) {
    // The paragraph alone, in its styles: every other character gone.
    final whole = from == 0 && to == text.length;
    final span = whole ? _source! : _slice(_source!, from, to);
    final painter = _painter(p, span);
    try {
      // How many lines the greedy break takes: the balanced set takes the
      // same number, which is what keeps the block's height where it was.
      painter.layout(maxWidth: room);
      final lines = painter.computeLineMetrics().length;
      if (lines < 2 || lines > lineCap) return null;
      // Every prefix's width, off ONE laid-out line: a line from a to b is
      // as wide as the text up to b less the text up to a. The room for
      // that line is the run's own greatest width and NOT `infinity`,
      // which Skia lays out to a caret offset of NaN.
      painter.layout(maxWidth: painter.maxIntrinsicWidth.ceilToDouble() + 1);
      final opp = _opportunities(text.substring(from, to));
      if (opp.length < lines) return null;
      final at = <int, double>{};
      double x(int i) => at.putIfAbsent(i, () => painter.getOffsetForCaret(TextPosition(offset: i), Rect.zero).dx);
      final cuts = this.cuts(opp, x, room, lines);
      if (cuts == null) return null;
      return {for (var t = cuts.length - 1; t > 1; t--) from + opp[cuts[t - 1] - 1].$1: from + opp[cuts[t - 1] - 1].$2};
    } finally {
      painter.dispose();
    }
  }

  /// [source] with only its characters from [from] to [to] (by the offsets
  /// of its text, leaf by leaf), every style kept.
  static InlineSpan _slice(InlineSpan source, int from, int to) {
    final texts = <String>[];
    var a = 0;
    for (final leaf in _leaves(source, breaks: true)!) {
      final b = a + leaf.text!.length;
      final s = from.clamp(a, b), e = to.clamp(a, b);
      texts.add(leaf.text!.substring(s - a, e - a));
      a = b;
    }
    return _swap(source, texts.iterator);
  }

  /// Where a line of [text] may end and the next one start (see
  /// [cuts]).
  static List<(int, int)> opportunities(String text) => _opportunities(text);

  /// [source] broken on [cuts] of [opp] as [cuts] returns them: a line feed
  /// where each line but the last ends, the space the break eats dropped,
  /// every style kept. [source] is text alone, as [cuts] was asked about
  /// it.
  static TextSpan brokenOn(InlineSpan source, List<(int, int)> opp, List<int> cuts) {
    // A line ends before the character a cut names, and the space a cut
    // eats is dropped.
    return _brokenAt(source, {
      for (var t = cuts.length - 1; t > 1; t--) opp[cuts[t - 1] - 1].$1: opp[cuts[t - 1] - 1].$2,
    });
  }

  /// [source] broken where [brk] says: a line feed before each character
  /// it names, and the characters up to the one it maps that to dropped.
  static TextSpan _brokenAt(InlineSpan source, Map<int, int> brk) {
    final leaves = _leaves(source, breaks: true)!;
    final text = leaves.map((l) => l.text!).join();
    // Each leaf's share of the broken text.
    final texts = <String>[];
    var a = 0;
    for (final leaf in leaves) {
      final b = a + leaf.text!.length;
      final sb = StringBuffer();
      for (var i = a; i < b; i++) {
        final st = brk[i];
        if (st != null) {
          sb.write('\n');
          if (st > i) continue;
        }
        sb.writeCharCode(text.codeUnitAt(i));
      }
      texts.add(sb.toString());
      a = b;
    }
    return _swap(source, texts.iterator) as TextSpan;
  }

  /// The paragraph's own greatest width, which is the GREEDY one: balancing
  /// says nothing about intrinsic sizing (css-text-4 8.2).
  @override
  double computeMaxIntrinsicWidth(double height) {
    final p = _paragraph();
    if (p == null) return guardedSize(child, () => super.computeMaxIntrinsicWidth(height));
    _sync(p);
    if (_plain(_source) == null) return guardedSize(child, () => super.computeMaxIntrinsicWidth(height));
    final painter = _painter(p, _source!);
    try {
      painter.layout(maxWidth: double.infinity);
      return painter.maxIntrinsicWidth;
    } finally {
      painter.dispose();
    }
  }

  /// Puts on the paragraph the span a layout in [room] lays out: the
  /// source, re-broken there, or -- where the width has no bound (null) --
  /// the source as it is, every break of ours taken back off.
  void _install(double? room) {
    final p = _paragraph();
    if (p == null) return;
    _sync(p);
    final want = _wanted(p, room);
    if (want == null) return;
    if (!identical(p.text, want) && p.text != want) {
      invokeLayoutCallback((Constraints _) {
        p.text = want;
      });
    }
    _installed = want;
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    _install(_roomOf(constraints));
    child.layout(_fit(constraints), parentUsesSize: true);
    size = constraints.constrain(child.size);
  }

  /// A BALANCED PARAGRAPH THAT WRAPS IS AS WIDE AS ITS ROOM, as the greedy
  /// one is (`TextWidthBasis.parent`): balancing moves the breaks, not the
  /// box, which is its fit-content wherever it is not handed a width
  /// (css-sizing-3 5.2). Handed a loose width, the re-broken paragraph
  /// stood at its longest balanced line: text-wrap-balance's centred
  /// heading of 336 stood 231 wide, 52px right of where it is. Measured
  /// to its fit instead (`IntrinsicWidth`), it answered its whole line as
  /// its least width, and a phone-width hero, under a box that shrinks to
  /// fit, stood one line of 829 in 358.
  BoxConstraints _fit(BoxConstraints c) =>
      c.hasTightWidth || !c.maxWidth.isFinite || computeMaxIntrinsicWidth(double.infinity) <= c.maxWidth
      ? c
      : c.tighten(width: c.maxWidth);

  // EVERY QUESTION ASKED BEFORE A LAYOUT IS ANSWERED FOR THE SPAN THAT
  // LAYOUT PUTS ON THE PARAGRAPH ([_measured]): the source, broken for the
  // room the question asks about, under the paragraph's text scaler, strut
  // and locale as they are now.
  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    if (child == null) return constraints.smallest;
    final box = _measured(_roomOf(constraints));
    return constraints.constrain(guardedSize(box, () => box.getDryLayout(_fit(constraints))));
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) =>
      child == null ? null : dryBaselineOf(_measured(_roomOf(constraints)), constraints, baseline);

  @override
  double? dryLastBaseline(BoxConstraints constraints, TextBaseline baseline) =>
      child == null ? null : dryLastBaselineOf(_measured(_roomOf(constraints)), constraints, baseline);

  /// An intrinsic height is the height laid out at [width], so it is asked
  /// of the span broken for that width.
  @override
  double computeMinIntrinsicHeight(double width) {
    if (child == null) return 0.0;
    return _measured(width.isFinite ? width : null).getMinIntrinsicHeight(width);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (child == null) return 0.0;
    return _measured(width.isFinite ? width : null).getMaxIntrinsicHeight(width);
  }
}
