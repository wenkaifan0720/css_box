/// One CSS inline formatting context, laid out by Flutter alone.
///
/// Its balanced and pretty line breaking is Blink's, ported from Chromium,
/// whose BSD notice is in this package's NOTICES.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'balance.dart';
import 'dry.dart';
import 'han.dart';
import 'paint_order.dart';
import 'pretty.dart';

// ------------------------------------------------------------------ values

/// `white-space` (css-text-3 3): whether spaces collapse and lines wrap.
enum WhiteSpace {
  normal,
  nowrap,
  pre,
  preWrap,
  preLine,
  breakSpaces;

  /// Whether a line may break at a soft wrap opportunity in text of this.
  bool get wraps => this != nowrap && this != pre;
}

/// `word-break` (css-text-3 5.2).
enum WordBreak { normal, breakAll, keepAll, breakWord }

/// `overflow-wrap` (css-text-3 5.5).
enum OverflowWrap { normal, breakWord, anywhere }

/// The offsets in [s] its grapheme clusters end at, 0 first: the only
/// places text is cut. A character a reader sees as one -- an emoji of two
/// UTF-16 units, a letter and its accent, a family of emoji joined by ZWJs
/// -- is never split, by a break (css-text-3 5: no break within a cluster)
/// nor by `overflow-wrap` or an ellipsis, which keep a cluster wider than
/// the line whole.
List<int> _clusterEnds(String s) {
  final ends = <int>[0];
  for (final c in s.characters) {
    ends.add(ends.last + c.length);
  }
  return ends;
}

/// Whether [s] holds a cluster of more than one UTF-16 unit. Text all below
/// U+0300 and without a carriage return -- Latin letters, digits and
/// punctuation -- is cut anywhere, a cluster at each unit.
bool _clustered(String s) {
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c >= 0x300 || c == 0x0D) return true;
  }
  return false;
}

/// `text-wrap-style` (css-text-4 6.2): how the lines are chosen.
enum TextWrapStyle {
  /// Greedily: each line takes what fits.
  auto,

  /// Evenly: every line of a paragraph of up to six scored by the room it
  /// leaves.
  balance,

  /// Greedily, but for a last line of one short word: the last four lines
  /// re-broken.
  pretty,
}

/// The keywords of `vertical-align` (CSS 2.1 10.8.1).
enum VerticalAlignKeyword { baseline, middle, sub, superscript, textTop, textBottom, top, bottom, length }

/// `vertical-align`: where an inline box or an atomic inline stands on its
/// line (CSS 2.1 10.8.1). A length or a percentage is written as the
/// distance it raises the box, a percentage resolved against the box's
/// own line height.
@immutable
class VerticalAlign {
  const VerticalAlign._(this.keyword) : raise = 0;

  /// Raised [raise] pixels over the parent's baseline (negative: lowered).
  const VerticalAlign.length(this.raise) : keyword = VerticalAlignKeyword.length;

  final VerticalAlignKeyword keyword;

  /// How far a [VerticalAlignKeyword.length] raises the box.
  final double raise;

  static const baseline = VerticalAlign._(VerticalAlignKeyword.baseline);
  static const middle = VerticalAlign._(VerticalAlignKeyword.middle);
  static const sub = VerticalAlign._(VerticalAlignKeyword.sub);
  static const superscript = VerticalAlign._(VerticalAlignKeyword.superscript);
  static const textTop = VerticalAlign._(VerticalAlignKeyword.textTop);
  static const textBottom = VerticalAlign._(VerticalAlignKeyword.textBottom);
  static const top = VerticalAlign._(VerticalAlignKeyword.top);
  static const bottom = VerticalAlign._(VerticalAlignKeyword.bottom);

  /// `top` and `bottom` align to the LINE, not to the parent's baseline.
  bool get toLine => keyword == VerticalAlignKeyword.top || keyword == VerticalAlignKeyword.bottom;

  @override
  bool operator ==(Object other) => other is VerticalAlign && other.keyword == keyword && other.raise == raise;

  @override
  int get hashCode => Object.hash(keyword, raise);

  @override
  String toString() =>
      keyword == VerticalAlignKeyword.length ? 'VerticalAlign.length($raise)' : 'VerticalAlign.${keyword.name}';
}

/// A box's font as its line reads it (CSS 2.1 10.8.1): the CONTENT AREA its
/// glyphs stand in -- [ascent] over the baseline and [descent] under it, as
/// Blink rounds them when it loads the face -- and the [lineHeight] round
/// it, whose leading is split above and below. [size] is the font size
/// (`super` raises a box by a third of its parent's) and [xHeight] the
/// face's x-height (`middle` stands a box's midpoint half of it over the
/// parent's baseline), half an em where the face does not say.
@immutable
class InlineFont {
  const InlineFont({
    required this.size,
    required this.ascent,
    required this.descent,
    required this.lineHeight,
    double? xHeight,
  }) : _xHeight = xHeight;

  final double size, ascent, descent, lineHeight;
  final double? _xHeight;

  double get xHeight => _xHeight ?? size / 2;

  /// The box's own line: its ascent with half the leading added over the
  /// baseline, the rest under it. Blink halves the leading on its 1/64 px
  /// grid, floors the half to a whole pixel, and gives the remainder to the
  /// descent (`FontHeight::AddLeading`), so an odd half-leading sits BELOW
  /// the baseline.
  _Extent get _leaded {
    final half = ((lineHeight - ascent - descent) * 64).round() ~/ 2;
    final above = ascent + (half / 64).floorToDouble();
    return _Extent(above, lineHeight - above);
  }

  /// This font with its text scaled by [scaler]: the size as [scaler]
  /// scales it, and the content area, the line height and the x-height by
  /// the same factor, so the strut grows with the glyphs it holds. Itself
  /// where nothing scales.
  InlineFont _scaledBy(TextScaler scaler) {
    if (scaler == TextScaler.noScaling || size <= 0) return this;
    final k = scaler.scale(size) / size;
    if (k == 1) return this;
    return InlineFont(
      size: size * k,
      ascent: ascent * k,
      descent: descent * k,
      lineHeight: lineHeight * k,
      xHeight: _xHeight == null ? null : _xHeight * k,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is InlineFont &&
      other.size == size &&
      other.ascent == ascent &&
      other.descent == descent &&
      other.lineHeight == lineHeight &&
      other._xHeight == _xHeight;

  @override
  int get hashCode => Object.hash(size, ascent, descent, lineHeight, _xHeight);
}

// ------------------------------------------------------------------ nodes

/// What an [InlineFlow] holds: text, inline boxes round more of it, atomic
/// inlines, and forced breaks, in document order.
@immutable
sealed class InlineNode {
  const InlineNode();
}

/// A run of text: one text node. Its white space is processed by the
/// `white-space` of the box it is in (css-text-3 4); its [style] is merged
/// over that box's.
class InlineText extends InlineNode {
  const InlineText(this.text, {this.style});

  final String text;
  final TextStyle? style;
}

/// A forced line break (`<br>`).
class InlineBreak extends InlineNode {
  const InlineBreak();
}

/// An inline box (CSS 2.1 9.2.2): what it holds is laid out on the lines of
/// the flow, and it is one FRAGMENT on each line it is on (css-break-3 5.4,
/// `box-decoration-break: slice`).
///
/// Across, its [margin], border and [padding] take room before its first
/// letter and after its last (10.3.1); down they take none, and the border
/// and padding stand out over and under its [font]'s content area on each
/// line (10.6.1). The [decoration] is painted over every fragment's border
/// box, cut from the strip the fragments make set end to end: a border is
/// only on the sides a fragment has.
///
/// [verticalAlign] moves the box off its parent's baseline (10.8.1).
/// [font] is the box's own: its content area, and the line height its
/// text stands in; null is its parent's.
class InlineBox extends InlineNode {
  const InlineBox({
    this.key,
    this.style,
    this.font,
    this.verticalAlign = VerticalAlign.baseline,
    this.whiteSpace,
    this.wordBreak,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.decoration,
    this.opacity = 1,
    this.blendMode = BlendMode.srcOver,
    this.offset = Offset.zero,
    this.offsetShare = 0,
    this.placed,
    this.children = const [],
  });

  /// Names the box to whoever reads its rectangle back
  /// ([RenderInlineFlow.boxRects]).
  final Key? key;
  final TextStyle? style;
  final InlineFont? font;
  final VerticalAlign verticalAlign;

  /// This box's `white-space` and `word-break`, where they are not its
  /// parent's.
  final WhiteSpace? whiteSpace;
  final WordBreak? wordBreak;

  /// The padding inside the border. The border's widths are the
  /// [decoration]'s ([Decoration.padding]).
  final EdgeInsets padding;

  /// Only the left and right margins: an inline box's vertical margins take
  /// no room (CSS 2.1 10.6.1).
  final EdgeInsets margin;
  final Decoration? decoration;

  /// `opacity`, a GROUP opacity (css-color-4 2.2): the box's frames, its
  /// text and everything inside it are laid down as one picture, which is
  /// painted at this alpha. The box is a stacking context (CSS 2.1
  /// appendix E, z-index 0), so the picture is painted after every piece
  /// of the flow that is in none, in tree order; at 0 nothing of it is.
  final double opacity;

  /// `mix-blend-mode` (compositing-1 5.1): the box and everything in it,
  /// laid down as one picture as a faded box is and at its [opacity], are
  /// blended into what the page painted under them in this mode -- one
  /// `saveLayer` restored in it (compositing-1 3.3: the opacity first,
  /// then the blend). A blended box is a stacking context and paints
  /// where a faded one does. Nothing inside it may push a compositing
  /// layer of its own, which no `saveLayer` holds: a box faded inside it
  /// is a `saveLayer` too, and an atomic inline in it must paint on the
  /// canvas (no `Opacity`, no `ShaderMask`, ...).
  final BlendMode blendMode;

  /// `position: relative` (CSS 2.1 9.4.3): the box and everything in it
  /// are painted [offset] from where the lines put them, which keep the
  /// room it took there -- nothing else on a line moves. A moved box is a
  /// positioned one (appendix E, step 8): painted after every piece of the
  /// flow that is in no such group, in tree order with the faded boxes --
  /// but, unlike them, it lays down no layer of its own. Its rectangle
  /// ([RenderInlineFlow.boxRects]) moves with it, as a browser reports it.
  final Offset offset;

  /// A SHARE of the flow's width the box is moved across, on top of
  /// [offset]: `left: 10%` is 0.1, `right: 10%` -0.1. A `relative` box's
  /// containing block is the content box of the block container its lines
  /// are in (CSS 2.1 10.1), and a percentage `left` or `right` is of its
  /// width (9.3.2): the width the flow is laid out at. A moved box as
  /// [offset] makes one, painted where one is.
  final double offsetShare;

  /// What is placed against the box: a positioned box (`position:
  /// relative`) is the CONTAINING BLOCK of the `absolute` boxes inside it
  /// (CSS 2.1 10.1), which is its padding box -- over every line it is on,
  /// from the start of its first piece to the end of its last, down from
  /// the first's top to the last's bottom, and no narrower than nothing
  /// where the last ends before the first starts (Chrome, measured). This
  /// is laid out exactly that rectangle, a `Stack` of `Positioned` boxes as
  /// a rule, and moves with the box ([offset]). It is out of the flow: it
  /// takes no room on any line, and paints among the positioned boxes
  /// (appendix E, step 8) after all the box holds -- the box, placing
  /// something, painted among them too, as one moved is.
  final Widget? placed;
  final List<InlineNode> children;
}

/// An atomic inline (an inline-block, a picture): the [child] is one
/// unbreakable box on the line (CSS 2.1 9.2.2), laid out in the room the
/// flow's line has and standing on the baseline by its own.
///
/// Its baseline is the child's ([RenderBox.getDistanceToActualBaseline])
/// where [ownBaseline]; otherwise -- and where the child has none -- its
/// bottom MARGIN edge (10.8.1). [margin] is round the child: all four
/// sides are part of what stands on the line.
class InlineAtom extends InlineNode {
  const InlineAtom({
    required this.child,
    this.verticalAlign = VerticalAlign.baseline,
    this.margin = EdgeInsets.zero,
    this.ownBaseline = true,
    this.opacity = 1,
  });

  final Widget child;
  final VerticalAlign verticalAlign;
  final EdgeInsets margin;
  final bool ownBaseline;

  /// The atom's own `opacity` (css-color-4 2.2), painted by the flow: a
  /// layer of its own at that alpha, as an `Opacity` round the [child]
  /// would be -- but inside a box of the flow that is one `saveLayer`
  /// ([InlineBox.blendMode], and every faded box inside such a box), a
  /// `saveLayer` too, restored at that alpha: a layer an `Opacity` pushed
  /// there is no part of the group, and is laid down over it after it is
  /// blended. Measured in Chrome (fixtures/mix-blend-plus-lighter n2: a
  /// faded inline-block in a padded box added over a colour).
  final double opacity;
}

/// A box taken OUT of the flow where it stood on a line (CSS 2.1 9.3.1):
/// the POINT it came out at, which is its static position across, at the
/// line's top down (10.3.7, 10.6.4) -- the place no one but the lines
/// knows. [child], a `SpotMark` as a rule, is laid out at no size there,
/// and a `SpotShift` moves the box to it.
///
/// It takes no room, and is no soft wrap opportunity (css-text-3 5.1: an
/// out-of-flow box introduces none): a break before it is taken after it,
/// so a point that ends a line stays on that line, at the end of its words
/// -- the spaces before it hang (4.1.3), and spaces on its two sides are
/// one. Chrome's `top: 0` box after `messages are ` in a span the line
/// breaks after is at the end of `are`, where the span's first piece ends
/// too (`fixtures/inline-flow-placed` n1). It is no content: a line of
/// nothing but points is no line (CSS 2.1 9.4.2), and a point in a flow of
/// nothing is where the line would have started.
class InlineMark extends InlineNode {
  const InlineMark({required this.child});

  final Widget child;
}

// ------------------------------------------------------------------ widget

/// A block's lines: one CSS inline formatting context (CSS 2.1 9.4.2, 10.8;
/// css-text-3), laid out and painted by this render object alone.
///
/// A [Text] is one paragraph broken by Skia, standing every run on one
/// baseline under one strut, and a placeholder is one unbreakable piece. It
/// cannot say what a browser does with an inline box a line breaks INSIDE:
/// `vertical-align` moving each of the box's pieces by what is on ITS line,
/// the box's background and border drawn round each piece, text that
/// white-space keeps or a word break that differs from run to run. This
/// lays the content out the way CSS does:
///
///  * the content is flattened into words, spaces, box edges and atomic
///    inlines; white space is collapsed or kept by each run's
///    `white-space` (css-text-3 4.1);
///  * lines are broken at soft wrap opportunities -- spaces, after a
///    hyphen, between ideographs, never before a closing glyph nor after an
///    opening one -- measuring each run on a line whole, as the browser
///    shapes it (css-text-3 5);
///  * each line's height and baseline are settled by `vertical-align`
///    (10.8): the [font] is the strut, every inline box aligned by what it
///    holds on that line;
///  * each line is placed by `text-align` and [textIndent], its items in
///    visual order (UAX #9: over whole items left to right; right to left,
///    over the paragraph's characters, a word split where their levels
///    part, and each inline box's start edge on its right);
///  * each inline box is one fragment on each line it is on;
///  * with [ellipsis], a line too wide for the flow ends on an ellipsis;
///  * with [textWrap], the lines are re-broken to balance, or for a last
///    line of one short word.
///
/// Painted in CSS's order (appendix E): line by line, each inline box's
/// frame before what it holds on that line; a faded box
/// ([InlineBox.opacity]), a stacking context, after all of that, as one
/// picture at its alpha, and a moved one ([InlineBox.offset]) there too.
///
/// The text scales for the reader as a [Text]'s does ([textScaler]), its
/// struts and fonts with it -- and only the text: an [InlineAtom] is laid
/// out at its own size, unlike a [RichText]'s [WidgetSpan].
class InlineFlow extends StatelessWidget {
  const InlineFlow({
    super.key,
    required this.font,
    this.style,
    this.textAlign = TextAlign.start,
    this.textIndent = 0,
    this.tabSize = 8,
    this.whiteSpace = WhiteSpace.normal,
    this.wordBreak = WordBreak.normal,
    this.overflowWrap = OverflowWrap.normal,
    this.textDirection,
    this.ellipsis = false,
    this.ellipsisText = '\u2026',
    this.textWrap = TextWrapStyle.auto,
    this.textScaler,
    this.children = const [],
  });

  /// The block's font: the strut every line stands on.
  final InlineFont font;

  /// Merged over the ambient [DefaultTextStyle]; the runs' own styles are
  /// merged over it.
  final TextStyle? style;
  final TextAlign textAlign;

  /// `text-indent`, on the first line.
  final double textIndent;

  /// `tab-size`, in spaces of [style]: a kept tab stops at the next
  /// multiple of it from the line's start.
  final double tabSize;
  final WhiteSpace whiteSpace;
  final WordBreak wordBreak;
  final OverflowWrap overflowWrap;

  /// The paragraph's direction; null is the ambient [Directionality].
  final TextDirection? textDirection;

  /// `text-overflow: ellipsis` on a block that hides its overflow
  /// (css-overflow-3 3.2): each line too wide for the flow ends on `…`.
  ///
  /// As Blink truncates a line (`LineTruncator`), measured in Chrome 151:
  /// only what is PAINTED changes, and every box keeps the place and size
  /// the line gave it. From the line's end, each piece of text and each
  /// atomic inline past the room is hidden; the text across it is cut at
  /// the last character that leaves room for the ellipsis -- a space
  /// counts like any other -- and an atomic inline across it is hidden
  /// whole. The ellipsis stands right after what is kept (not after the
  /// end padding of the box it was in), on the line's baseline, in the
  /// flow's own [style] -- not a raised box's size, a bold box's weight, a
  /// red box's colour, nor a faded box's alpha -- and undecorated, the
  /// flow's own underline too, but with its text shadow. A box's frame
  /// is painted whole, under the ellipsis. The first piece on the line
  /// keeps a character, or an atomic inline itself, however narrow the
  /// flow. In tracked text the ellipsis asks for its own advance alone,
  /// not the letter-spacing after it, and stands after the spacing of the
  /// last character kept -- its own box's, whatever the block's. Left to
  /// right only.
  final bool ellipsis;

  /// What the [ellipsis] is written as: `…`, or three full stops where the
  /// block's primary face has no `…` -- Blink asks that face alone
  /// (`NGLineTruncator`), and sets the full stops in whatever face draws
  /// them.
  final String ellipsisText;

  /// `text-wrap-style` (css-text-4 6.2), as Blink's `ScoreLineBreaker`
  /// sets it: [TextWrapStyle.balance] re-breaks a paragraph of up to six
  /// lines, and [TextWrapStyle.pretty] the last four lines of one whose
  /// last line is a single word under a third of the room, each for the
  /// least room left over, squared (see `_rebroken`). The widths scored
  /// are the flow's own -- its runs measured whole, the frames and atomic
  /// inlines on the line -- save that a line does not count the box edges
  /// after its last word. Only the breaks move: the flow has the greedy
  /// number of lines, and its min- and max-content widths are the greedy
  /// ones. A forced break ends a paragraph, each scored on its own --
  /// balanced lines in the first alone, as Blink balances. A flow with a
  /// tab, and a paragraph with a line wider than the flow, is broken
  /// greedily.
  final TextWrapStyle textWrap;

  /// How the flow's TEXT is scaled for the reader (`MediaQuery`'s text
  /// scale, an accessibility setting); null is the ambient
  /// [MediaQuery.textScalerOf], as a [Text]'s is. [TextScaler.noScaling]
  /// keeps every length as written, as a layout of fixed pixel metrics
  /// needs.
  ///
  /// The glyphs of every run, the [font]'s strut and each [InlineBox.font]
  /// -- size, content area, line height, x-height -- scale together, so
  /// the lines grow with what they hold. ONLY TEXT SCALES: an
  /// [InlineAtom] is laid out at its own size, and the text inside it
  /// scales once, by its own `Text` -- as CSS text zoom scales each font
  /// once and no box -- where a [RichText] scales a [WidgetSpan]'s box as a
  /// whole, and the text in it a second time. Nor do an [InlineBox]'s
  /// padding, border and margin, the [textIndent] or the [ellipsisText]'s
  /// box scale: only the text in them.
  final TextScaler? textScaler;
  final List<InlineNode> children;

  static final _atoms = Expando<List<Widget>>();

  @override
  Widget build(BuildContext context) => _InlineFlowLayout(
    flow: this,
    style: DefaultTextStyle.of(context).style.merge(style),
    direction: textDirection ?? Directionality.maybeOf(context) ?? TextDirection.ltr,
    textScaler: textScaler ?? MediaQuery.textScalerOf(context),
    children: _atoms[this] ??= [
      for (final a in _atomsOf(children)) a.child,
      for (final b in _placedOf(children)) b.placed!,
    ],
  );
}

/// The boxes with something placed against them, in tree order: after the
/// atomic inlines, their [InlineBox.placed] are the flow's children.
List<InlineBox> _placedOf(List<InlineNode> nodes) {
  final out = <InlineBox>[];
  void walk(List<InlineNode> ns) {
    for (final n in ns) {
      if (n is! InlineBox) continue;
      if (n.placed != null) out.add(n);
      walk(n.children);
    }
  }

  walk(nodes);
  return out;
}

/// The atomic inlines, and the points of [InlineMark]s as atoms of no
/// size, in tree order: each one's child is a child of the flow.
List<InlineAtom> _atomsOf(List<InlineNode> nodes) {
  final out = <InlineAtom>[];
  void walk(List<InlineNode> ns) {
    for (final n in ns) {
      switch (n) {
        case InlineAtom():
          out.add(n);
        case InlineMark():
          out.add(InlineAtom(child: n.child, ownBaseline: false));
        case InlineBox():
          walk(n.children);
        case InlineText() || InlineBreak():
          break;
      }
    }
  }

  walk(nodes);
  return out;
}

class _InlineFlowLayout extends MultiChildRenderObjectWidget {
  const _InlineFlowLayout({
    required this.flow,
    required this.style,
    required this.direction,
    required this.textScaler,
    super.children,
  });

  final InlineFlow flow;
  final TextStyle style;
  final TextDirection direction;
  final TextScaler textScaler;

  @override
  RenderInlineFlow createRenderObject(BuildContext context) => RenderInlineFlow(
    content: flow.children,
    font: flow.font,
    style: style,
    textAlign: flow.textAlign,
    textIndent: flow.textIndent,
    tabSize: flow.tabSize,
    whiteSpace: flow.whiteSpace,
    wordBreak: flow.wordBreak,
    overflowWrap: flow.overflowWrap,
    textDirection: direction,
    ellipsis: flow.ellipsis,
    ellipsisText: flow.ellipsisText,
    textWrap: flow.textWrap,
    textScaler: textScaler,
  );

  @override
  void updateRenderObject(BuildContext context, RenderInlineFlow renderObject) {
    renderObject
      ..content = flow.children
      ..font = flow.font
      ..style = style
      ..textAlign = flow.textAlign
      ..textIndent = flow.textIndent
      ..tabSize = flow.tabSize
      ..whiteSpace = flow.whiteSpace
      ..wordBreak = flow.wordBreak
      ..overflowWrap = flow.overflowWrap
      ..textDirection = direction
      ..ellipsis = flow.ellipsis
      ..ellipsisText = flow.ellipsisText
      ..textWrap = flow.textWrap
      ..textScaler = textScaler;
  }
}

// ------------------------------------------------------------------ items

/// A box's ascent and descent about its baseline.
class _Extent {
  const _Extent(this.above, this.below);
  final double above, below;
}

/// An inline box of the flow, or the flow's root (index 0): what its items
/// read off it.
class _Box {
  _Box(this.index, this.parent, this.node, this.font, this.style, this.whiteSpace, this.wordBreak);

  final int index;
  final _Box? parent;

  /// Null for the root.
  final InlineBox? node;
  final InlineFont font;
  final TextStyle style;
  final WhiteSpace whiteSpace;
  final WordBreak wordBreak;
  VerticalAlign get align => node?.verticalAlign ?? VerticalAlign.baseline;

  /// How far this box and all in it are painted from where the lines put
  /// them: its own [InlineBox.offset] and every box's round it, with the
  /// [InlineBox.offsetShare]s of the flow's [width].
  Offset get shift {
    final n = node;
    if (n == null) return Offset.zero;
    final own = n.offsetShare == 0 ? n.offset : n.offset + Offset(n.offsetShare * _root.width, 0);
    return parent!.shift + own;
  }

  _Box get _root => parent?._root ?? this;

  /// The root's: the width the flow was last laid out at, what a share of
  /// [InlineBox.offsetShare] is of.
  double width = 0;

  /// Margin, border and padding at the box's start and end, and the
  /// border and padding over and under its content area.
  EdgeInsets frame = EdgeInsets.zero;
  EdgeInsets margin = EdgeInsets.zero;
}

/// [mark] is an [InlineMark]'s point: an atom of no size and no content
/// (see [_Flattener._walk]).
enum _Kind { word, space, open, close, atomic, br, mark }

class _Item {
  _Item(
    this.kind,
    this.width,
    this.box, {
    this.run = -1,
    this.atom = -1,
    this.style,
    this.text = '',
    this.breakAfter = false,
    this.collapsible = false,
    this.kern = 0,
    this.level = 0,
  });

  final _Kind kind;
  final double width;

  /// The inline box this item is IN (word, space, br, atomic), or the one it
  /// opens or closes (open, close).
  final _Box box;

  /// The text run a word or space came out of: runs are measured whole on
  /// a line and never across two.
  final int run;

  /// The atomic inline's index among the flow's atoms.
  final int atom;
  final TextStyle? style;
  final String text;

  /// A soft wrap opportunity after this item.
  final bool breakAfter;

  /// A collapsible space: it hangs at the end of a line.
  final bool collapsible;

  /// What kerning against the next item's first character takes off this
  /// item's last glyph: the browser shapes a text node once and breaks the
  /// shaped run.
  final double kern;

  /// Its bidi level in a right-to-left flow, resolved over the paragraph
  /// (see [_Flattener._levels]): even left to right, odd right to left.
  /// 0 in a left-to-right one, whose lines order whole items (see
  /// [_visualOrder]).
  final int level;

  _Item copy({double? width, double? kern, bool? breakAfter, int? run, int? level}) => _Item(
    kind,
    width ?? this.width,
    box,
    run: run ?? this.run,
    atom: atom,
    style: style,
    text: text,
    breakAfter: breakAfter ?? this.breakAfter,
    collapsible: collapsible,
    kern: kern ?? this.kern,
    level: level ?? this.level,
  );
}

/// The widths the flow's text is measured with: Flutter's own shaping, in
/// the style each run is drawn in.
///
/// KEPT FOR TWO GENERATIONS OF THE CONTENT, NOT FOR ITS WHOLE HISTORY. A
/// width is kept in the generation that last asked for it; a new one
/// starts where the content is flattened again ([turn]), and where one
/// grows past [_most]. A width the last generation measured and this one
/// asks for again is moved into this one; one it does not ask for is
/// dropped with the generation after. So the lines broken again at another
/// width ask nothing new of what they asked before (no turn), and the same
/// words given again -- the widget rebuilt round a list of its own --
/// shape nothing again; but text and styles the flow no longer holds are
/// let go, however long it lives and however often its content changes.
/// The widths are the same whichever generation holds them.
class _Measure {
  Map<TextStyle, Map<String, double>> _now = {}, _before = {};
  int _held = 0;

  /// The widths a generation holds before it starts another.
  static const _most = 4096;

  /// How many texts were shaped, and how many widths are held.
  int shaped = 0;
  int get held => _held + _before.values.fold(0, (n, m) => n + m.length);

  /// Starts a generation: what this one measured is kept for one more.
  void turn() {
    _before = _now;
    _now = {};
    _held = 0;
  }

  /// The word-separator characters in [text] (css-text-3 8.2).
  static int _separators(String text) {
    var n = 0;
    for (final r in text.runes) {
      if (r == 0x20 || r == 0xA0 || r == 0x1361 || r == 0x10100 || r == 0x10101 || r == 0x1039F || r == 0x1091F) n++;
    }
    return n;
  }

  double width(String text, TextStyle style) {
    if (text.isEmpty) return 0;
    if (_now[style]?[text] case final w?) return w;
    final w = _before[style]?.remove(text) ?? _shape(text, style);
    if (_held >= _most) turn();
    (_now[style] ??= {})[text] = w;
    _held++;
    return w;
  }

  double _shape(String text, TextStyle style) {
    shaped++;
    // `word-spacing` goes on every word separator (css-text-3 8.2); Skia
    // leaves it off one that ENDS its text, so it is counted here.
    final ws = style.wordSpacing ?? 0;
    final tp = TextPainter(
      text: han(text, style: ws == 0 ? style : style.copyWith(wordSpacing: 0)),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width + ws * _separators(text);
    tp.dispose();
    return w;
  }
}

/// [style] with its font size scaled by [scaler]; itself where nothing
/// scales.
TextStyle _scaled(TextStyle style, TextScaler scaler) =>
    scaler == TextScaler.noScaling ? style : style.copyWith(fontSize: scaler.scale(style.fontSize ?? kDefaultFontSize));

/// [own] merged over [parent], a style scaled by [scaler] already: a size
/// [own] states is scaled as it comes in, and one it inherits is the
/// parent's, scaled once.
TextStyle _scaledUnder(TextStyle parent, TextStyle? own, TextScaler scaler) {
  if (own == null || scaler == TextScaler.noScaling) return parent.merge(own);
  if (!own.inherit) return _scaled(own, scaler);
  final size = own.fontSize;
  return parent.merge(size == null ? own : own.copyWith(fontSize: scaler.scale(size)));
}

/// The content flattened into items: everything that does not depend on
/// the width the lines are broken in.
class _Flat {
  _Flat(this.items, this.boxes, this.atoms, this.hasContent);
  final List<_Item> items;
  final List<_Box> boxes;
  final List<InlineAtom> atoms;

  /// Whether anything but collapsible white space and empty inline boxes is
  /// in the flow (else it makes no line box, CSS 2.1 9.4.2).
  final bool hasContent;
}

class _Flattener {
  _Flattener(this.m, this.root, {this.rtl = false, this.scaler = TextScaler.noScaling});

  final _Measure m;
  final _Box root;

  /// What the text is scaled by: every box's style and font is scaled as
  /// it is read ([_scaledUnder], [InlineFont._scaledBy]); [root]'s is
  /// scaled already.
  final TextScaler scaler;

  /// Whether the paragraph runs right to left: its items are given their
  /// levels ([_levels]), and each box's start edge is its RIGHT one.
  final bool rtl;
  final List<_Item> items = [];
  final List<_Box> boxes = [];
  final List<InlineAtom> atoms = [];
  var _run = 0;

  /// Whether anything a collapsible space could follow is on the line yet;
  /// a space before the first of it collapses to nothing.
  bool _sawContent = false;

  _Flat run(List<InlineNode> content) {
    boxes.add(root);
    _walk(content, root);
    if (rtl) _levels();
    _kernRuns();
    _breakBetweenAtomics();
    final has = items.any(
      (i) =>
          i.kind == _Kind.word ||
          i.kind == _Kind.atomic ||
          i.kind == _Kind.br ||
          (i.kind == _Kind.space && !i.collapsible),
    );
    return _Flat(items, boxes, atoms, has);
  }

  void _walk(List<InlineNode> nodes, _Box box) {
    for (final n in nodes) {
      switch (n) {
        case InlineText():
          _text(n, box);
        case InlineBreak():
          items.add(_Item(_Kind.br, 0, box, style: box.style));
          _sawContent = false;
        case InlineAtom():
          atoms.add(n);
          items.add(_Item(_Kind.atomic, 0, box, atom: atoms.length - 1));
          _sawContent = true;
        case InlineMark():
          // The break opportunity before the point is taken after it: the
          // point stays on the line it follows (see [InlineMark]).
          atoms.add(InlineAtom(child: n.child, ownBaseline: false));
          final before = items.isEmpty ? null : items.last;
          if (before != null && before.breakAfter) items[items.length - 1] = before.copy(breakAfter: false);
          items.add(_Item(_Kind.mark, 0, box, atom: atoms.length - 1, breakAfter: before?.breakAfter ?? false));
        case InlineBox():
          final b = _Box(
            boxes.length,
            box,
            n,
            n.font?._scaledBy(scaler) ?? box.font,
            _scaledUnder(box.style, n.style, scaler),
            n.whiteSpace ?? box.whiteSpace,
            n.wordBreak ?? box.wordBreak,
          );
          b.frame = n.padding + (n.decoration?.padding.resolve(TextDirection.ltr) ?? EdgeInsets.zero);
          b.margin = EdgeInsets.only(left: n.margin.left, right: n.margin.right);
          boxes.add(b);
          // AN INLINE BOX'S EDGES TAKE ROOM ON ITS LINE: its margin, border
          // and padding on the side it opens are on the line before its
          // first word, and on the side it closes after its last (CSS 2.1
          // 10.3.1, css-inline-3 3). The side it opens is its START: the
          // right one under `rtl` (css-writing-modes-4 2.4.2).
          final start = rtl ? b.frame.right + b.margin.right : b.margin.left + b.frame.left;
          final end = rtl ? b.margin.left + b.frame.left : b.frame.right + b.margin.right;
          items.add(_Item(_Kind.open, start, b));
          _walk(n.children, b);
          items.add(_Item(_Kind.close, end, b));
      }
    }
  }

  void _text(InlineText n, _Box box) {
    final st = _scaledUnder(box.style, n.style, scaler);
    final run = _run++;
    final text = n.text;
    if (text.isEmpty) return;
    // U+2028 and U+2029 force a break in every white-space mode (css-text-3
    // 4.1 mandatory breaks).
    if (text.contains(' ') || text.contains(' ')) {
      final parts = text.split(RegExp('[  ]'));
      for (var i = 0; i < parts.length; i++) {
        if (i > 0) {
          items.add(_Item(_Kind.br, 0, box, style: st));
          _sawContent = false;
        }
        if (parts[i].isNotEmpty) _textRun(parts[i], st, box, run);
      }
      return;
    }
    _textRun(text, st, box, run);
  }

  static final RegExp _wsRun = RegExp(r'[ \t\n\r\f]+');

  void _textRun(String text, TextStyle st, _Box box, int run) {
    final ws = box.whiteSpace;
    if (ws == WhiteSpace.pre || ws == WhiteSpace.preWrap || ws == WhiteSpace.breakSpaces) {
      // Spaces are content; newlines force breaks; pre wraps only if pre-wrap.
      final lines = text.split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (i > 0) {
          items.add(_Item(_Kind.br, 0, box, style: st));
          _sawContent = false;
        }
        _preservedRun(lines[i], st, box, run, wraps: ws != WhiteSpace.pre);
      }
      return;
    }
    // css-text-3 4.1.1: a tab or a newline becomes a space and a RUN of them
    // collapses to one, which disappears at the start of the block.
    final segments = ws == WhiteSpace.preLine ? text.split('\n') : [text];
    for (var si = 0; si < segments.length; si++) {
      if (si > 0) {
        items.add(_Item(_Kind.br, 0, box, style: st));
        _sawContent = false;
      }
      final parts = segments[si].replaceAll(_wsRun, ' ').split(' ');
      for (var i = 0; i < parts.length; i++) {
        if (i > 0) _addSpace(st, box, run);
        _word(parts[i], st, box, run);
      }
    }
  }

  /// A collapsible space, dropped where collapsing leaves nothing: at the
  /// start of the block's content and after another collapsible space
  /// (css-text-3 4.1.1). Whether a line may break at it is the RUN's own
  /// white space (CSS 2.1 16.6): a space inside a `nowrap` run is no soft
  /// wrap opportunity.
  ///
  /// A SPACE COLLAPSES ACROSS A BOX'S EDGES: one after another collapsible
  /// space is dropped "even one outside the boundary of the inline
  /// containing that space" (4.1.1), whatever the frame between them. In
  /// `Quiet <span> <b></b> </span> harbour` the span's spaces and the one
  /// before `harbour` are gone and the span is a point after `Quiet `;
  /// read only up to the edge, each was a space of its own and the span
  /// 4.5px wide (fixtures/relative-inline-empty n1).
  void _addSpace(TextStyle st, _Box box, int run) {
    if (!_sawContent) return;
    for (var i = items.length - 1; i >= 0; i--) {
      final k = items[i].kind;
      // A point is no content either: spaces on its two sides are one.
      if (k == _Kind.open || k == _Kind.close || k == _Kind.mark) continue;
      if (k == _Kind.space && items[i].collapsible) return;
      break;
    }
    items.add(
      _Item(
        _Kind.space,
        m.width(' ', st),
        box,
        run: run,
        style: st,
        text: ' ',
        breakAfter: box.whiteSpace.wraps,
        collapsible: true,
      ),
    );
  }

  static final _letterOrNumber = RegExp(r'[\p{L}\p{N}]', unicode: true);

  /// A word with its own break opportunities: U+200B, after a hyphen,
  /// between CJK ideographs -- never before a closing glyph nor after an
  /// opening one (UAX #14 LB13, LB21), and under `keep-all` never between
  /// two letters or numbers (css-text-3 5.2).
  void _word(String w, TextStyle st, _Box box, int run) {
    if (w.isEmpty) return;
    final segs = <String>[];
    final buf = StringBuffer();
    final runes = w.runes.toList();
    final keepAll = box.wordBreak == WordBreak.keepAll;
    // `break-all` breaks between any two letters (css-text-3 5.2) -- the
    // first word on a line too -- but not before a closing mark nor after
    // an opening one (UAX #14 LB13, LB14). Measured in Chrome 151: `abcdefg
    // hi` in a box three glyphs wide is `abc`, `def`, `g h`, `i`.
    final breakAll = box.wordBreak == WordBreak.breakAll;
    // No break falls inside a grapheme cluster ([_clusterEnds]): not
    // between a letter and its accent, an emoji and its modifier, nor the
    // people of a family joined by ZWJs.
    final ends = _clustered(w) ? _clusterEnds(w).toSet() : null;
    var at = 0;
    for (var i = 0; i < runes.length; i++) {
      final r = runes[i];
      at += r > 0xFFFF ? 2 : 1;
      if (r == 0x200B) {
        segs.add(buf.toString());
        buf.clear();
        segs.add('​');
        continue;
      }
      buf.writeCharCode(r);
      final next = i + 1 < runes.length ? runes[i + 1] : null;
      final isCjk = _isCjk(r);
      final kept =
          keepAll &&
          next != null &&
          _letterOrNumber.hasMatch(String.fromCharCode(r)) &&
          _letterOrNumber.hasMatch(String.fromCharCode(next));
      final between = ends == null || ends.contains(at);
      if (between &&
          ((r == 0x2D && next != null && next != 0x2D && i > 0) ||
              (next != null && _asciiBreak(r, next)) ||
              (breakAll && next != null && !_noBreakAfter(r) && !_noBreakBefore(next)) ||
              (isCjk && next != null && !kept && !_noBreakAfter(r) && !_noBreakBefore(next)) ||
              (next != null && _isCjk(next) && !isCjk && !kept && !_noBreakAfter(r)))) {
        segs.add(buf.toString());
        buf.clear();
      }
    }
    if (buf.isNotEmpty) segs.add(buf.toString());
    // A `nowrap` run offers none of these either (CSS 2.1 16.6).
    final breaks = box.whiteSpace.wraps;
    for (var i = 0; i < segs.length; i++) {
      final s = segs[i];
      if (s == '​') {
        items.add(_Item(_Kind.space, 0, box, run: run, style: st, breakAfter: breaks));
        _sawContent = true;
        continue;
      }
      final last = i == segs.length - 1;
      items.add(_Item(_Kind.word, m.width(s, st), box, run: run, style: st, text: s, breakAfter: !last && breaks));
      _sawContent = true;
    }
  }

  /// Kept white space (`pre`, `pre-wrap`, `break-spaces`): every space and
  /// tab keeps its width and is a break opportunity where lines wrap.
  ///
  /// A WORD BETWEEN THEM BREAKS WHERE A COLLAPSED ONE WOULD ([_word]) where
  /// lines wrap: `pre-wrap` keeps the spaces, not the words whole (css-text-3
  /// 3). A docs site's `pre-wrap` paragraphs break `src={user.imageUrl}` after
  /// `src=` in Chrome 151 (fixtures/inline-flow-ascii-break p1).
  void _preservedRun(String s, TextStyle st, _Box box, int run, {required bool wraps}) {
    final buf = StringBuffer();
    void flush() {
      if (buf.isEmpty) return;
      final t = buf.toString();
      buf.clear();
      if (wraps) {
        _word(t, st, box, run);
        return;
      }
      items.add(_Item(_Kind.word, m.width(t, st), box, run: run, style: st, text: t));
      _sawContent = true;
    }

    for (final r in s.runes) {
      if (r == 0x20 || r == 0x09) {
        flush();
        final t = String.fromCharCode(r);
        items.add(_Item(_Kind.space, m.width(t, st), box, run: run, style: st, text: t, breakAfter: wraps));
        _sawContent = true;
      } else {
        buf.writeCharCode(r);
      }
    }
    flush();
  }

  /// THE LEVEL OF EVERY ITEM OF A RIGHT-TO-LEFT FLOW (UAX #9), resolved over
  /// the PARAGRAPH and not line by line: a neutral takes the direction of
  /// the strong characters round it wherever the lines break (N1), and one
  /// at the paragraph's end the paragraph's own (N2). The full stop of
  /// `layouts.` ending an `rtl` paragraph is right to left, and Chrome sets
  /// it at the far LEFT of its line, where the word before it is left to
  /// right (fixtures/inline-frame-pieces n3).
  ///
  /// Each character is L, R, a European digit (EN) or neutral ([_charClass]):
  /// one separator between two digits is a digit (W4), and so is a run of
  /// terminators against one (W5); a digit after L is L (W7). White space,
  /// punctuation, an atomic inline (U+FFFC, css-writing-modes-4 2.4.2) and
  /// a box's edge are neutral -- an edge is no character, and takes the
  /// level of the neutrals it stands among. A forced break ends the
  /// paragraph (a segment break is B). The levels (I1, I2): R 1, L and EN
  /// 2, over the paragraph's 1.
  ///
  /// A WORD WHOSE CHARACTERS COME TO TWO LEVELS IS TWO ITEMS, with no break
  /// between them: Blink segments its text at every change of level
  /// (`NGInlineItem`) and shapes each segment on its own, so no kerning
  /// spans the change -- each segment past a change is a run of its own
  /// ([_kernRuns], and a line's runs are measured whole).
  void _levels() {
    final cls = <int>[], at = <int>[];
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      if ((it.kind == _Kind.word || it.kind == _Kind.space) && it.text.isNotEmpty) {
        for (final r in it.text.runes) {
          cls.add(_charClass(r));
          at.add(i);
        }
      } else {
        cls.add(it.kind == _Kind.br ? _paragraphEnd : _neutral);
        at.add(i);
      }
    }
    final lv = _resolveLevels(cls, 1);
    final out = <_Item>[];
    var c = 0;
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      var n = 0;
      while (c + n < at.length && at[c + n] == i) {
        n++;
      }
      if (it.kind != _Kind.word || lv.sublist(c, c + n).every((v) => v == lv[c])) {
        out.add(it.copy(level: lv[c]));
        c += n;
        continue;
      }
      final runes = it.text.runes.toList();
      var from = 0;
      for (var k = 1; k <= n; k++) {
        if (k < n && lv[c + k] == lv[c + from]) continue;
        final seg = String.fromCharCodes(runes.sublist(from, k));
        out.add(
          _Item(
            _Kind.word,
            m.width(seg, it.style!),
            it.box,
            run: it.run,
            style: it.style,
            text: seg,
            breakAfter: k == n && it.breakAfter,
            level: lv[c + from],
          ),
        );
        from = k;
      }
      c += n;
    }
    // A run apart at every change of level.
    var was = -1, level = -1, now = -1;
    for (var i = 0; i < out.length; i++) {
      final it = out[i];
      if (it.kind != _Kind.word && it.kind != _Kind.space) continue;
      if (it.run != was) {
        (was, level, now) = (it.run, it.level, it.run);
      } else if (it.level != level) {
        (level, now) = (it.level, _run++);
      }
      if (now != it.run) out[i] = it.copy(run: now);
    }
    items
      ..clear()
      ..addAll(out);
  }

  /// Give every text item the kern it loses by being measured on its own:
  /// two items kern only when the browser shapes them together -- adjacent
  /// text of one run.
  void _kernRuns() {
    for (var i = 0; i + 1 < items.length; i++) {
      final a = items[i], b = items[i + 1];
      if ((a.kind != _Kind.word && a.kind != _Kind.space) || a.text.isEmpty) continue;
      if ((b.kind != _Kind.word && b.kind != _Kind.space) || b.text.isEmpty) continue;
      if (a.run != b.run) continue;
      final st = a.style!;
      // Its first code point: half an emoji is no string to measure.
      final c = String.fromCharCode(b.text.runes.first);
      final k = m.width(a.text + c, st) - m.width(a.text, st) - m.width(c, st);
      if (k != 0) items[i] = a.copy(kern: k);
    }
  }

  /// A BREAK BETWEEN TWO ATOMIC INLINES THAT TOUCH: Blink breaks a line
  /// between two pictures with nothing between them, where the white space
  /// of the box the two are IN wraps.
  void _breakBetweenAtomics() {
    for (var i = 0; i < items.length; i++) {
      final a = items[i];
      if (a.kind != _Kind.atomic || a.breakAfter) continue;
      if (!a.box.whiteSpace.wraps) continue;
      var j = i + 1;
      while (j < items.length &&
          (items[j].kind == _Kind.open || items[j].kind == _Kind.close || items[j].kind == _Kind.mark)) {
        j++;
      }
      if (j < items.length && items[j].kind == _Kind.atomic) items[i] = a.copy(breakAfter: true);
    }
  }

  /// Closing brackets, commas, full stops and the other glyphs a line may
  /// not begin with (UAX #14 CL, CP, EX, IS, NS).
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

  /// BLINK BREAKS BETWEEN TWO PRINTABLE ASCII GLYPHS BY ITS OWN TABLE, not
  /// UAX #14 (`LineBreakData::FillAscii`, Chromium's
  /// `character_property_data_generator.cc`, Firefox 3.6's matrix): BEFORE
  /// AN OPENING `(` `<` `[` `{` after anything but `$ ' ( / < @ [ ^ _ \` {`,
  /// a digit or a letter, and AFTER A `?` before anything but
  /// `! " ' ) , . / : ; ? ] }`. (UAX #14 LB30 keeps `=` and `{` together.)
  /// the docs site's `<code>src={user.imageUrl}</code>` breaks after `src=` in
  /// Chrome 151, and one line more under it held it whole
  /// (fixtures/inline-flow-ascii-break p1). The hyphen's rule is above.
  static bool _asciiBreak(int last, int next) {
    if (last < 0x21 || last > 0x7E || next < 0x21 || next > 0x7E) return false;
    if (next == 0x28 || next == 0x3C || next == 0x5B || next == 0x7B) {
      return !(last == 0x24 ||
          last == 0x27 ||
          last == 0x28 ||
          last == 0x2F ||
          (last >= 0x30 && last <= 0x39) ||
          last == 0x3C ||
          last == 0x40 ||
          (last >= 0x41 && last <= 0x5A) ||
          last == 0x5B ||
          (last >= 0x5E && last <= 0x60) ||
          (last >= 0x61 && last <= 0x7A) ||
          last == 0x7B);
    }
    if (last == 0x3F) return !'!"\'),./:;?]}'.codeUnits.contains(next);
    return false;
  }

  /// Opening brackets and quotes a line may not end with (UAX #14 OP).
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

  static bool _isCjk(int r) =>
      (r >= 0x4E00 && r <= 0x9FFF) ||
      (r >= 0x3400 && r <= 0x4DBF) ||
      (r >= 0x3040 && r <= 0x30FF) ||
      (r >= 0xAC00 && r <= 0xD7AF) ||
      (r >= 0xF900 && r <= 0xFAFF) ||
      (r >= 0xFF00 && r <= 0xFFEF);
}

// ------------------------------------------------------------------ lines

class _Placed {
  _Placed(this.item);
  final _Item item;
  double x = 0;

  /// Baseline shift relative to the line's baseline (positive = up).
  double shift = 0;
  double above = 0;
  double below = 0;
  bool lineRelative = false;
  bool alignTop = false;
}

class _Line {
  final List<_Placed> placed = [];
  double avail = double.infinity;
  double y = 0;

  /// Inline boxes opened on an earlier line and still open when this one
  /// starts (outermost first): they continue here as a new fragment.
  final List<_Box> carried = [];
  final Map<_Box, double> carriedShift = {};
  double width = 0;

  /// The trailing run of text measured whole: Chrome shapes a line's text as
  /// one run, and summing its words loses the kerning between them.
  double runBase = 0;
  String runText = '';
  int run = -1;

  /// The line as Blink's `LineBreaker` counts it to FIT (its `position_`),
  /// not where anything is painted: every text item it has closed -- at a
  /// tag, a zero-width one too, where the shaping run above goes on -- at
  /// its `SnappedWidth()`, its float width rounded UP to 1/64 px. [fitBase]
  /// is that sum up to [fitMark], a place in [width].
  double fitBase = 0;
  double fitMark = 0;
  double above = 0;
  double below = 0;
  double get height => above + below;
  bool endsWithForcedBreak = false;

  /// What of [width] the line's content takes for alignment and for the
  /// flow's intrinsic widths: less the kept spaces that HANG at its end
  /// (css-text-3 4.1.3) -- all of them where a soft wrap ends the line,
  /// and past the edge only where a forced break or the paragraph's end
  /// does. Measured in Chrome 151 under `text-align: right`: `abc  ` then
  /// a soft wrap stands as `abc` would, `abc   ` at the paragraph's end
  /// with its spaces where they fit.
  double content = 0;

  /// [content] as the line FITS it ([fitBase]): every text item at its
  /// float width rounded up to 1/64 px, as Blink sums a line's items in
  /// LayoutUnits. The flow's intrinsic widths are these, so a flow laid out
  /// at its own max-content width fits it on the lines it measured
  /// (fixtures/flex-shrink-inline-flow-caption p1: 307.875, the float
  /// widths 307.827).
  double fit = 0;
}

/// An atomic inline as a pass measured it: its margin box's width, its
/// border box's size, and its baseline from its border box's top (null: it
/// stands on its bottom margin edge).
class _AtomFact {
  const _AtomFact(this.size, this.baseline);
  final Size size;
  final double? baseline;
}

/// Breaks chosen beforehand (see `RenderInlineFlow._rebroken`): a line
/// ends after each item of [after], and in each of [spans] -- item ranges,
/// both ends included, each a paragraph -- every item fits where it is.
/// Outside them the lines are the greedy ones.
class _Cuts {
  const _Cuts(this.after, this.spans);
  final Set<int> after;
  final List<(int, int)> spans;

  /// Whether the breaks round item [i] are chosen.
  bool at(int i) => spans.any((s) => s.$1 <= i && i <= s.$2);
}

/// Break [items] into lines [maxWidth] wide (null: never), the first
/// [indent] shorter (css-text-3 5, 6; CSS 2.1 16.1).
List<_Line> _break(
  List<_Item> items,
  double? maxWidth, {
  required _Measure m,
  required bool wraps,
  required bool breakAnywhere,
  required double indent,
  required double tabWidth,
  required double tabMinimum,
  required bool hasContent,
  required void Function(_Line) settle,
  _Cuts? cuts,
}) {
  final lines = <_Line>[];
  var line = _Line();
  var firstLine = true;
  var y = 0.0;
  final width = maxWidth ?? double.infinity;
  bool hasContentOn() => line.placed.any(
    (p) =>
        p.item.kind == _Kind.word || p.item.kind == _Kind.atomic || (p.item.kind == _Kind.space && !p.item.collapsible),
  );
  var lastBreak = -1;

  // A TAB STOPS AT THE NEXT MULTIPLE OF `tab-size` SPACES from the line's
  // start edge, the indent inside it; one that would come within half a
  // space of a stop goes on to the next (css-text-3 4.2; Blink's
  // `Font::TabWidth`). Measured in Chrome 151: `abc` then a tab at 16px
  // is 80 wide, and one after eight glyphs a whole 128.
  double tabAt(_Line line) {
    if (tabWidth <= 0) return 0;
    final at = line.width + (firstLine ? indent : 0);
    var d = tabWidth - at % tabWidth;
    if (d < tabMinimum) d += tabWidth;
    return d;
  }

  void add(_Line line, _Placed p) {
    var it = p.item;
    if (it.kind == _Kind.space && it.text == '\t') {
      it = it.copy(width: tabAt(line));
      p = _Placed(it);
    }
    line.placed.add(p);
    final text = (it.kind == _Kind.word || it.kind == _Kind.space) && it.text != '\t';
    if (!(text && line.run >= 0 && line.run == it.run) && line.width > line.fitMark) {
      line.fitBase += _ceil64(line.width - line.fitMark);
      line.fitMark = line.width;
    }
    if (it.kind == _Kind.space && it.text == '\t') {
      line.width += it.width;
      line.fitBase += it.width;
      line.fitMark = line.width;
      line.run = -1;
      line.runText = '';
      line.runBase = line.width;
    } else if (it.kind == _Kind.word || it.kind == _Kind.space) {
      if (line.run >= 0 && line.run == it.run) {
        line.runText += it.text;
      } else {
        line.runBase = line.width;
        line.run = it.run;
        line.runText = it.text;
      }
      line.width = line.runBase + m.width(line.runText, it.style!) + it.kern;
    } else if ((it.kind != _Kind.open && it.kind != _Kind.close) || it.width != 0) {
      line.width += it.width;
      line.fitBase += it.width;
      line.fitMark = line.width;
      line.run = -1;
      line.runText = '';
      line.runBase = line.width;
    }
  }

  // THE WIDTH A LINE FITS BY, and with [it] after it: Blink sums its
  // items in LayoutUnits, a text item it has closed at its float width
  // rounded up to 1/64 px and the one it is breaking at its float width
  // (against a room on the 1/64 grid, the same as rounding it up too).
  // Chrome 151 keeps `vo` + `yx` + a 13px end edge off a 200px line that
  // the float widths fit to 1/64 (probe_pw/items.py: `kg vo` is
  // 41.015625 wide there, its float width rounded up).
  double fitWidth(_Line line) => line.fitBase + (line.width - line.fitMark);
  double fitWith(_Line line, _Item it) {
    if ((it.kind == _Kind.word || it.kind == _Kind.space) && it.text != '\t' && line.run >= 0 && line.run == it.run) {
      return line.fitBase + (line.runBase + m.width(line.runText + it.text, it.style!) + it.kern - line.fitMark);
    }
    final closed = line.width > line.fitMark ? line.fitBase + _ceil64(line.width - line.fitMark) : line.fitBase;
    if (it.kind == _Kind.space && it.text == '\t') return closed + tabAt(line);
    return closed + it.width;
  }

  void recompute(_Line line) {
    final ps = List<_Placed>.of(line.placed);
    line.placed.clear();
    line.width = 0;
    line.runBase = 0;
    line.runText = '';
    line.run = -1;
    line.fitBase = 0;
    line.fitMark = 0;
    for (final p in ps) {
      add(line, p);
    }
  }

  double avail() => width - (firstLine ? indent : 0);

  // WHAT FITS IS WHAT FITS THE ROOM AND ONE LAYOUTUNIT MORE: Blink's
  // `LineBreaker` fits a line to `AvailableWidthToFit()`, its available
  // width `AddEpsilon()`-ed, 1/64 px. Chrome 151 sets ` mqzgmvz q   j`
  // in Inter on a line of 110px whose last glyph ends at 110.016
  // (probe_pw/ties.py: three of sweep5's 300 paragraphs, each 1/64 over).
  // Min-content widths (a zero [width]) keep every break.
  final slack = width > 0 ? 1 / 64 : 1e-6;

  void flush({bool forced = false, bool last = false}) {
    // Collapsible spaces that end a line hang: they are dropped from it,
    // before a forced break too (css-text-3 4.1.3 phase II) -- and before
    // a point, which then stands at the end of the words: Chrome's static
    // position after `messages are ` at a line's end is the end of `are`,
    // where the relative span's piece ends (`fixtures/inline-flow-placed`
    // n1).
    var dropped = false;
    for (var i = line.placed.length - 1; i >= 0; i--) {
      final p = line.placed[i];
      if (p.item.kind == _Kind.space && p.item.collapsible) {
        line.placed.removeAt(i);
        dropped = true;
      } else if (p.item.kind == _Kind.close ||
          p.item.kind == _Kind.open ||
          p.item.kind == _Kind.br ||
          p.item.kind == _Kind.mark) {
        continue;
      } else {
        break;
      }
    }
    if (dropped) recompute(line);
    line.endsWithForcedBreak = forced;
    var hung = 0.0;
    for (var i = line.placed.length - 1; i >= 0; i--) {
      final it = line.placed[i].item;
      if (it.kind == _Kind.close || it.kind == _Kind.open || it.kind == _Kind.br || it.kind == _Kind.mark) continue;
      if (it.kind != _Kind.space || it.box.whiteSpace != WhiteSpace.preWrap) break;
      hung += it.width;
    }
    final kept = line.width - hung;
    line.content = forced || last ? kept + math.min(hung, math.max(0.0, avail() - kept)) : kept;
    final closed = line.width > line.fitMark ? line.fitBase + _ceil64(line.width - line.fitMark) : line.fitBase;
    line.fit = math.max(line.content, closed - (line.width - line.content));
    final open = <_Box>[...line.carried];
    for (final p in line.placed) {
      if (p.item.kind == _Kind.open) open.add(p.item.box);
      if (p.item.kind == _Kind.close && open.isNotEmpty) open.removeLast();
    }
    settle(line);
    line.avail = width;
    line.y = y;
    y += line.height;
    lines.add(line);
    line = _Line()..carried.addAll(open);
    firstLine = false;
    lastBreak = -1;
  }

  /// Take the line's last word down: everything after the last break
  /// opportunity moves to the next line. False where there is none, or
  /// nothing but box edges after it.
  bool rewind() {
    if (lastBreak < 0) return false;
    final carry = line.placed.sublist(lastBreak + 1);
    if (!carry.any(
      (p) =>
          p.item.kind == _Kind.word ||
          p.item.kind == _Kind.atomic ||
          (p.item.kind == _Kind.space && !p.item.collapsible),
    )) {
      return false;
    }
    line.placed.removeRange(lastBreak + 1, line.placed.length);
    recompute(line);
    flush();
    for (final p in carry) {
      if (p.item.kind == _Kind.space && p.item.collapsible && !hasContentOn()) continue;
      add(line, _Placed(p.item));
    }
    return true;
  }

  // The UTF-16 length of the longest start of [s] that fits [room], cut
  // between grapheme clusters only ([_clusterEnds]).
  int fitChars(String s, TextStyle st, double room) {
    final ends = _clustered(s) ? _clusterEnds(s) : null;
    var lo = 0, hi = ends == null ? s.length : ends.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (m.width(s.substring(0, ends?[mid] ?? mid), st) <= room + slack) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return ends?[lo] ?? lo;
  }

  // A BOX'S LAST WORD THAT FITS BUT FOR THE BOX'S END EDGE is broken where
  // `overflow-wrap` lets it, at its own width less a pixel: Blink's
  // `HandleOverflow` breaks it in the room before it, but never at its end
  // ("the text fits but its right margin does not"), and the edge goes
  // down with what is left. Chrome 151 sets `ddfcdah` closing a box with
  // 25px of end edge, 117px wide, as `ddfcda` / `h` -- not `ddfcd` / `ah`
  // (probe_bal/endedge.py).
  void splitBefore() {
    var k = line.placed.length - 1;
    while (k >= 0 && line.placed[k].item.kind == _Kind.close) {
      k--;
    }
    if (k < 0) return;
    final word = line.placed[k].item;
    if (word.kind != _Kind.word || !word.box.whiteSpace.wraps || word.text.length < 2) return;
    final tail = line.placed.sublist(k + 1);
    line.placed.removeRange(k, line.placed.length);
    recompute(line);
    final take = fitChars(word.text, word.style!, math.min(avail() - line.width, word.width - 1));
    if (take == 0 || take >= word.text.length) {
      add(line, _Placed(word));
      for (final p in tail) {
        add(line, _Placed(p.item));
      }
      return;
    }
    final head = word.text.substring(0, take), rest = word.text.substring(take);
    add(
      line,
      _Placed(
        _Item(
          _Kind.word,
          m.width(head, word.style!),
          word.box,
          run: word.run,
          style: word.style,
          text: head,
          breakAfter: true,
          level: word.level,
        ),
      ),
    );
    flush();
    add(
      line,
      _Placed(
        _Item(
          _Kind.word,
          m.width(rest, word.style!),
          word.box,
          run: word.run,
          style: word.style,
          text: rest,
          breakAfter: word.breakAfter,
          kern: word.kern,
          level: word.level,
        ),
      ),
    );
    for (final p in tail) {
      add(line, _Placed(p.item));
    }
  }

  for (var i = 0; i < items.length; i++) {
    final it = items[i];
    if (it.kind == _Kind.br) {
      // A forced break measures the line it ends.
      if (wraps && !(cuts?.at(i) ?? false) && fitWidth(line) > avail() + slack) rewind();
      line.placed.add(_Placed(it));
      flush(forced: true);
      continue;
    }
    if (it.kind == _Kind.space &&
        it.collapsible &&
        line.placed.every(
          (p) => p.item.kind == _Kind.open || p.item.kind == _Kind.close || p.item.kind == _Kind.mark,
        )) {
      continue; // a collapsible space that starts a line
    }
    if (it.kind == _Kind.open || it.kind == _Kind.close) {
      // AN INLINE BOX'S END EDGE GOES DOWN WITH ITS LAST WORD; ITS START
      // EDGE HANGS (measured in Chrome): only the end edge asks for room.
      if (it.kind == _Kind.close &&
          it.width != 0 &&
          wraps &&
          !(cuts?.at(i) ?? false) &&
          fitWith(line, it) > avail() + slack) {
        if (!rewind() && breakAnywhere && width > 0) splitBefore();
      }
      add(line, _Placed(it));
      if (cuts != null && cuts.after.contains(i)) flush();
      continue;
    }
    final w = it.width;
    // A collapsible space hangs at the end of its line: it never forces a
    // break (css-text-3 4.1.3).
    // So does a KEPT one under `pre-wrap` (4.1.3): `ab c  d  e f` in a box
    // seven glyphs and a half wide is `ab c  d  ` and `e f` in Chrome 151,
    // the two spaces past the edge. Under `break-spaces` none hangs.
    final hangs = it.kind == _Kind.space && (it.collapsible || it.box.whiteSpace == WhiteSpace.preWrap);
    // On breaks chosen beforehand ([cuts]) every item fits where it is.
    final cutting = cuts?.at(i) ?? false;
    // A point takes no room, and stays on the line it follows.
    var fits =
        cutting ||
        !wraps ||
        hangs ||
        it.kind == _Kind.mark ||
        fitWith(line, it) <= avail() + slack ||
        line.placed.every(
          (p) =>
              p.item.kind == _Kind.open ||
              p.item.kind == _Kind.close ||
              (p.item.width == 0 && p.item.kind != _Kind.word && p.item.kind != _Kind.atomic),
        );
    // A WORD TOO WIDE FOR A LINE IT STARTS is broken where `overflow-wrap`
    // lets it (css-text-3 5.5): Chrome 151 sets an 18-letter word in a
    // `break-word` box 104px wide as three lines of six. Not for the
    // min-content width (a zero [width]), which `break-word` leaves to
    // whole words.
    if (fits &&
        !cutting &&
        width > 0 &&
        it.kind == _Kind.word &&
        wraps &&
        breakAnywhere &&
        it.box.whiteSpace.wraps &&
        fitWith(line, it) > avail() + slack) {
      fits = false;
    }
    // A closing glyph that ends the line gives up its blank half where that
    // is what fits it (`text-spacing-trim: normal`, css-text-4 8.3).
    var halved = false;
    if (!fits &&
        it.kind == _Kind.word &&
        it.text.isNotEmpty &&
        hanCloses(it.text.runes.last) &&
        fitWith(line, it) - (it.style!.fontSize ?? 14) / 2 <= avail() + slack) {
      fits = true;
      halved = true;
    }
    if (!fits) {
      if (lastBreak >= 0) {
        final carry = line.placed.sublist(lastBreak + 1);
        line.placed.removeRange(lastBreak + 1, line.placed.length);
        recompute(line);
        flush();
        for (final p in carry) {
          // Only the spaces that START the new line collapse away.
          if (p.item.kind == _Kind.space && p.item.collapsible && !hasContentOn()) continue;
          add(line, _Placed(p.item));
        }
      } else if (it.kind == _Kind.word &&
          breakAnywhere &&
          it.box.whiteSpace.wraps &&
          line.placed.any((p) => p.item.kind == _Kind.word || p.item.kind == _Kind.atomic)) {
        flush();
      }
      // The item alone still does not fit: break inside it if allowed --
      // never in text that does not wrap, which `overflow-wrap` leaves
      // whole (css-text-3 5.5: it applies where text wraps; Chrome 151
      // keeps a `nowrap` span too wide for a `break-word` line whole,
      // overflowing). The room is the line's, a framed box's start edge on
      // it counted: Chrome 151 breaks `acace` in a box padded 11px a side,
      // 90px wide, as `acac` / `e`.
      if (it.kind == _Kind.word &&
          wraps &&
          breakAnywhere &&
          it.box.whiteSpace.wraps &&
          (width > 0 ? fitWith(line, it) : w) > avail() + slack) {
        var rest = it.text;
        while (rest.isNotEmpty) {
          final room = avail() - line.width;
          var take = fitChars(rest, it.style!, room);
          if (take == 0) {
            if (line.placed.any((p) => p.item.kind == _Kind.word || p.item.kind == _Kind.atomic)) {
              flush();
              continue;
            }
            // A cluster wider than the line is set whole, overflowing.
            take = rest.characters.first.length;
          }
          final piece = rest.substring(0, take);
          rest = rest.substring(take);
          add(
            line,
            _Placed(
              _Item(
                _Kind.word,
                m.width(piece, it.style!),
                it.box,
                run: it.run,
                style: it.style,
                text: piece,
                breakAfter: rest.isNotEmpty,
                level: it.level,
              ),
            ),
          );
          if (rest.isNotEmpty) flush();
        }
        lastBreak = it.breakAfter ? line.placed.length - 1 : -1;
        continue;
      }
    }
    add(line, _Placed(halved ? it.copy(kern: it.kern - (it.style!.fontSize ?? 14) / 2) : it));
    if (it.breakAfter) lastBreak = line.placed.length - 1;
    if (cuts != null && cuts.after.contains(i)) flush();
  }
  if (line.placed.isNotEmpty || (lines.isEmpty && hasContent)) flush(last: true);
  return lines;
}

// ------------------------------------------------------------------ vertical

/// An atomic inline's margin box about its own baseline: the child's
/// baseline, or its bottom margin edge (CSS 2.1 10.8.1).
_Extent _atomExtent(InlineAtom a, _AtomFact f) {
  final h = f.size.height + a.margin.vertical;
  final base = a.ownBaseline && f.baseline != null ? a.margin.top + f.baseline! : h;
  return _Extent(base, h - base);
}

/// The baseline shift `vertical-align` gives a box relative to its parent's
/// baseline; null for the line-relative `top` and `bottom`. [height] and
/// [baseline] are the box's extent where it is measured as one (an atomic,
/// or an inline box united with what it holds).
double? _shiftFor(VerticalAlign va, InlineFont own, InlineFont parent, double? height, double? baseline) {
  switch (va.keyword) {
    case VerticalAlignKeyword.baseline:
      return 0;
    case VerticalAlignKeyword.top:
    case VerticalAlignKeyword.bottom:
      return null;
    case VerticalAlignKeyword.middle:
      // The box's midpoint half the parent's x-height over the parent's
      // baseline, the half rounded to Blink's 1/64 px.
      final half = (parent.xHeight / 2 * 64).roundToDouble() / 64;
      if (height != null) return half + height / 2 - baseline!;
      final ext = own._leaded;
      return half - (ext.above - ext.below) / 2;
    case VerticalAlignKeyword.textTop:
      if (height != null) return parent.ascent - baseline!;
      return parent.ascent - own._leaded.above;
    case VerticalAlignKeyword.textBottom:
      if (height != null) return -(parent.descent - (height - baseline!));
      return -(parent.descent - own._leaded.below);
    case VerticalAlignKeyword.sub:
      // Down a fifth of the PARENT's font size and one pixel more, up a
      // third of it and one more, each share cut to Blink's 1/64 px grid
      // (`InlineBoxState`'s baseline shift). A 12px line's subscript drops
      // 3.390625.
      return -(_floor64(parent.size / 5) + 1);
    case VerticalAlignKeyword.superscript:
      return _floor64(parent.size / 3) + 1;
    case VerticalAlignKeyword.length:
      return va.raise;
  }
}

double _floor64(double v) => (v * 64).floorToDouble() / 64;

/// [v] up to Blink's 1/64 px grid, past float noise under it.
double _ceil64(double v) => (v * 64 - 1e-6).ceilToDouble() / 64;

/// THE BOX `vertical-align` READS IS THE BOX WITH ITS CONTENT IN IT: Blink
/// unites every metric on the line inside an inline box into that box
/// before it aligns the box (`InlineBoxState::metrics.Unite`). A `top` or
/// `bottom` box aligns to the line and unites into nothing.
Map<_Box, _Extent> _unitedExtents(_Line line, _Box root, List<InlineAtom> atoms, List<_AtomFact> facts) {
  bool aligned(_Box b) => b.align.keyword != VerticalAlignKeyword.baseline;
  if (!line.carried.any(aligned) && !line.placed.any((p) => p.item.kind == _Kind.open && aligned(p.item.box))) {
    return const {};
  }
  final out = <_Box, _Extent>{};
  final frames = <(_Box, _Extent)>[(root, root.font._leaded)];
  void unite(_Extent e, double shift) {
    final (b, cur) = frames.last;
    frames[frames.length - 1] = (
      b,
      _Extent(math.max(cur.above, e.above + shift), math.max(cur.below, e.below - shift)),
    );
  }

  void close() {
    if (frames.length < 2) return;
    final (b, u) = frames.removeLast();
    out[b] = u;
    final s = _shiftFor(b.align, b.font, frames.last.$1.font, u.above + u.below, u.above);
    if (s != null) unite(u, s);
  }

  for (final b in line.carried) {
    frames.add((b, b.font._leaded));
  }
  for (final p in line.placed) {
    final it = p.item;
    switch (it.kind) {
      case _Kind.open:
        frames.add((it.box, it.box.font._leaded));
      case _Kind.close:
        close();
      case _Kind.mark:
        break;
      case _Kind.word:
      case _Kind.space:
      case _Kind.br:
        unite(it.box.font._leaded, 0);
      case _Kind.atomic:
        final a = atoms[it.atom];
        final e = _atomExtent(a, facts[it.atom]);
        final s = _shiftFor(a.verticalAlign, it.box.font, frames.last.$1.font, e.above + e.below, e.above);
        if (s != null) unite(e, s);
    }
  }
  while (frames.length > 1) {
    close();
  }
  return out;
}

/// Settle one line on its baseline (CSS 2.1 10.8): each inline box and
/// atomic gets its shift, the line box is the extent of the strut and of
/// everything aligned, and `top`/`bottom` boxes are placed after.
void _settle(_Line line, _Box root, List<InlineAtom> atoms, List<_AtomFact> facts) {
  // A line box of nothing but empty inline boxes is no line box (9.4.2),
  // nor one of nothing but the points out-of-flow boxes left on it.
  if (!line.placed.any((p) => p.item.kind != _Kind.open && p.item.kind != _Kind.close && p.item.kind != _Kind.mark)) {
    line.above = 0;
    line.below = 0;
    return;
  }
  final strut = root.font._leaded;
  var above = strut.above;
  var below = strut.below;
  final shiftStack = <double>[0];
  final boxStack = <_Box>[root];
  // The `top` or `bottom` box each level is inside: what is in one is set
  // on the box's own baseline and moved with it once the line's height is
  // known (CSS 2.1 10.8.1) -- on every line the box is on, the ones it is
  // carried onto too. Measured in Chrome 151: a `top` span of 10px/14px
  // words broken over two 20px lines stands its words 2px under each
  // line's top, and a `bottom` one 2px over each line's bottom.
  final inside = <_LineRelative?>[null];
  final relative = <_LineRelative>[];
  final united = _unitedExtents(line, root, atoms, facts);
  double? shiftOfBox(_Box b, _Box parent) {
    final u = united[b];
    if (u == null) return _shiftFor(b.align, b.font, parent.font, null, null);
    return _shiftFor(b.align, b.font, parent.font, u.above + u.below, u.above);
  }

  // What is on the line: the line box grows round it where it stands on
  // the baseline; inside a `top` or `bottom` box it is that box's, whose
  // united extent (see [_unitedExtents]) is what the line makes room for.
  void grow(_Placed? p, double a, double b) {
    final lr = inside.last;
    if (lr == null) {
      above = math.max(above, a);
      below = math.max(below, b);
    } else if (p != null) {
      lr.members.add(p);
    }
  }

  _LineRelative enter(_Box b, {_Placed? open}) {
    final u = united[b] ?? b.font._leaded;
    final lr = _LineRelative(
      u.above,
      u.below,
      b.align.keyword == VerticalAlignKeyword.top,
      open: open,
      carried: open == null ? b : null,
    );
    relative.add(lr);
    inside.add(lr);
    shiftStack.add(0);
    return lr;
  }

  for (final b in line.carried) {
    final s = shiftOfBox(b, boxStack.last);
    boxStack.add(b);
    if (s == null) {
      enter(b);
      line.carriedShift[b] = 0;
      continue;
    }
    shiftStack.add(shiftStack.last + s);
    line.carriedShift[b] = shiftStack.last;
    inside.last?.carriedMembers.add(b);
    inside.add(inside.last);
    final ext = b.font._leaded;
    grow(null, ext.above + shiftStack.last, ext.below - shiftStack.last);
  }
  for (final p in line.placed) {
    final it = p.item;
    switch (it.kind) {
      case _Kind.open:
        final b = it.box;
        final s = shiftOfBox(b, boxStack.last);
        boxStack.add(b);
        final ext = b.font._leaded;
        p.above = ext.above;
        p.below = ext.below;
        if (s == null) {
          p.lineRelative = true;
          p.alignTop = b.align.keyword == VerticalAlignKeyword.top;
          p.shift = 0;
          enter(b, open: p);
        } else {
          shiftStack.add(shiftStack.last + s);
          p.shift = shiftStack.last;
          grow(p, p.above + p.shift, p.below - p.shift);
          inside.add(inside.last);
        }
      case _Kind.close:
        if (shiftStack.length > 1) {
          shiftStack.removeLast();
          boxStack.removeLast();
          inside.removeLast();
        }
        p.shift = shiftStack.last;
        inside.last?.members.add(p);
      case _Kind.word:
      case _Kind.space:
        final ext = it.box.font._leaded;
        p.shift = shiftStack.last;
        p.above = ext.above;
        p.below = ext.below;
        grow(p, p.above + p.shift, p.below - p.shift);
      case _Kind.atomic:
        final a = atoms[it.atom];
        final ext = _atomExtent(a, facts[it.atom]);
        final h = ext.above + ext.below;
        final s = _shiftFor(a.verticalAlign, it.box.font, boxStack.last.font, h, ext.above);
        if (s == null) {
          p.lineRelative = true;
          p.alignTop = a.verticalAlign.keyword == VerticalAlignKeyword.top;
          p.above = h;
          p.below = 0;
          relative.add(_LineRelative(h, 0, p.alignTop, open: p));
        } else {
          p.shift = shiftStack.last + s;
          p.above = ext.above;
          p.below = h - ext.above;
          grow(p, p.above + p.shift, p.below - p.shift);
        }
      case _Kind.br:
        final ext = it.box.font._leaded;
        grow(null, ext.above + shiftStack.last, ext.below - shiftStack.last);
      // A point takes no part in the line's height.
      case _Kind.mark:
        break;
    }
  }
  // Line-relative boxes: the line grows to fit them (10.8.1).
  for (final lr in relative) {
    final h = lr.above + lr.below;
    if (h > above + below) {
      if (lr.top) {
        below = h - above;
      } else {
        above = h - below;
      }
    }
  }
  line.above = above;
  line.below = below;
  for (final lr in relative) {
    final shift = lr.top ? above - lr.above : lr.below - below;
    lr.open?.shift = shift;
    if (lr.carried case final b?) line.carriedShift[b] = shift;
    for (final p in lr.members) {
      p.shift += shift;
    }
    for (final b in lr.carriedMembers) {
      line.carriedShift[b] = line.carriedShift[b]! + shift;
    }
  }
}

/// A `top` or `bottom` box on one line, or an atomic inline aligned so:
/// its extent above and below its own baseline, which edge of the line box
/// it stands on, and what is inside it -- set on its baseline, and moved
/// with it once the line's height is known.
class _LineRelative {
  _LineRelative(this.above, this.below, this.top, {this.open, this.carried});
  final double above, below;
  final bool top;

  /// Its open (or the atomic inline itself) on this line.
  final _Placed? open;

  /// Or the box it carried onto this line.
  final _Box? carried;
  final List<_Placed> members = [];
  final List<_Box> carriedMembers = [];
}

// ------------------------------------------------------------------ bidi

/// A left-to-right line's items in VISUAL order: UAX #9 over whole items,
/// a word L or R by its first strong character, a number EN; everything
/// else neutral. A right-to-left flow's lines are ordered by [_rtlLine].
List<_Placed> _visualOrder(List<_Placed> placed) {
  if (placed.length < 2) return placed;
  const base = 0;
  final cls = [for (final p in placed) _bidiClass(p.item)];
  if (!cls.contains(1)) return placed;
  var lastStrong = base;
  for (var i = 0; i < cls.length; i++) {
    if (cls[i] == 2 && lastStrong == 0) cls[i] = 0;
    if (cls[i] == 0 || cls[i] == 1) lastStrong = cls[i];
  }
  final dirs = [for (final c in cls) c == 2 ? 1 : c];
  var i = 0;
  while (i < dirs.length) {
    if (dirs[i] != -1) {
      i++;
      continue;
    }
    var j = i;
    while (j < dirs.length && dirs[j] == -1) {
      j++;
    }
    final before = i == 0 ? base : dirs[i - 1];
    final after = j == dirs.length ? base : dirs[j];
    final d = before == after ? before : base;
    for (var k = i; k < j; k++) {
      dirs[k] = d;
    }
    i = j;
  }
  final lv = [for (var k = 0; k < cls.length; k++) cls[k] == 2 ? 2 : (dirs[k] == 1 ? 1 : 0)];
  var top = 0;
  for (final v in lv) {
    if (v > top) top = v;
  }
  final out = List<_Placed>.of(placed);
  for (var level = top; level >= 1; level--) {
    var s = 0;
    while (s < out.length) {
      if (lv[s] < level) {
        s++;
        continue;
      }
      var e = s;
      while (e < out.length && lv[e] >= level) {
        e++;
      }
      for (var a = s, b = e - 1; a < b; a++, b--) {
        final t = out[a];
        out[a] = out[b];
        out[b] = t;
        final tl = lv[a];
        lv[a] = lv[b];
        lv[b] = tl;
      }
      s = e;
    }
  }
  return out;
}

/// A character's bidi class, as [_Flattener._levels] reads it (UAX #9
/// table 4): L, R (and AL), EN, ES, CS, ET, or neutral -- the rest.
int _charClass(int c) {
  if (_strongR(c)) return _r;
  if (_strongL(c)) return _l;
  if ((c >= 0x30 && c <= 0x39) || (c >= 0xFF10 && c <= 0xFF19)) return _en;
  if (c == 0x2B || c == 0x2D) return _es;
  if (c == 0x2C || c == 0x2E || c == 0x2F || c == 0x3A || c == 0xA0) return _cs;
  if (c == 0x23 ||
      c == 0x24 ||
      c == 0x25 ||
      c == 0xB0 ||
      (c >= 0xA2 && c <= 0xA5) ||
      c == 0x2030 ||
      c == 0x2031 ||
      (c >= 0x20A0 && c <= 0x20CF)) {
    return _et;
  }
  return _neutral;
}

const _l = 0, _r = 1, _en = 2, _es = 3, _cs = 4, _et = 5, _neutral = -1, _paragraphEnd = -2;

/// The levels of a run of characters of the classes [_charClass] gives --
/// [_paragraphEnd] where a paragraph ends -- under paragraph level [base]
/// (UAX #9 W4, W5, W6, W7, N1, N2, I1, I2; a paragraph's end is at its
/// level).
List<int> _resolveLevels(List<int> cls, int base) {
  final t = List<int>.of(cls);
  // W4: one separator between two digits is a digit.
  for (var i = 1; i + 1 < t.length; i++) {
    if ((t[i] == _es || t[i] == _cs) && t[i - 1] == _en && t[i + 1] == _en) t[i] = _en;
  }
  // W5: terminators against a digit are digits.
  for (var i = 0; i < t.length; i++) {
    if (t[i] != _et) continue;
    var j = i;
    while (j < t.length && t[j] == _et) {
      j++;
    }
    if ((i > 0 && t[i - 1] == _en) || (j < t.length && t[j] == _en)) {
      for (var k = i; k < j; k++) {
        t[k] = _en;
      }
    }
    i = j - 1;
  }
  // W6: the separators and terminators left are neutral. W7: a digit
  // after L is L.
  var strong = base;
  for (var i = 0; i < t.length; i++) {
    if (t[i] == _es || t[i] == _cs || t[i] == _et) t[i] = _neutral;
    if (t[i] == _paragraphEnd) {
      strong = base;
    } else if (t[i] == _l || t[i] == _r) {
      strong = t[i];
    } else if (t[i] == _en && strong == _l) {
      t[i] = _l;
    }
  }
  // N1, N2: neutrals between two of one direction take it -- a digit
  // counts as R -- and the paragraph's otherwise.
  int side(int k) => k < 0 || k >= t.length || t[k] == _paragraphEnd ? base : (t[k] == _en ? _r : t[k]);
  for (var i = 0; i < t.length;) {
    if (t[i] != _neutral) {
      i++;
      continue;
    }
    var j = i;
    while (j < t.length && t[j] == _neutral) {
      j++;
    }
    final d = side(i - 1) == side(j) ? side(j) : base;
    for (var k = i; k < j; k++) {
      t[k] = d;
    }
    i = j;
  }
  return [
    for (final v in t)
      v == _paragraphEnd
          ? base
          : base.isEven
          ? (v == _l
                ? base
                : v == _r
                ? base + 1
                : base + 2)
          : (v == _r ? base : base + 1),
  ];
}

/// A line of a right-to-left flow in visual order: each item at the level
/// the paragraph gave it ([_Flattener._levels]); the white space ending
/// the line, and any before a tab, at the paragraph's (UAX #9 L1); then,
/// from the highest level down to 1, every run at that level or above
/// reversed (L2).
List<_Placed> _reordered(List<_Placed> placed) {
  const base = 1;
  final lv = [for (final p in placed) p.item.level];
  bool white(_Item it) =>
      it.kind == _Kind.space || it.kind == _Kind.open || it.kind == _Kind.close || it.kind == _Kind.br;
  for (var i = placed.length - 1; i >= 0 && white(placed[i].item); i--) {
    lv[i] = base;
  }
  for (var i = 0; i < placed.length; i++) {
    if (placed[i].item.text != '\t') continue;
    for (var k = i; k >= 0 && white(placed[k].item); k--) {
      lv[k] = base;
    }
  }
  final top = lv.fold(base, math.max);
  final out = List<_Placed>.of(placed);
  for (var level = top; level >= 1; level--) {
    for (var s = 0; s < out.length;) {
      if (lv[s] < level) {
        s++;
        continue;
      }
      var e = s;
      while (e < out.length && lv[e] >= level) {
        e++;
      }
      for (var a = s, b = e - 1; a < b; a++, b--) {
        final t = out[a];
        out[a] = out[b];
        out[b] = t;
        final tl = lv[a];
        lv[a] = lv[b];
        lv[b] = tl;
      }
      s = e;
    }
  }
  return out;
}

/// An inline box's left or right edge on a line of a right-to-left flow
/// (see [_rtlLine]).
class _Edge {
  const _Edge(this.box, {required this.left});
  final _Box box;
  final bool left;
}

/// A LINE OF A RIGHT-TO-LEFT FLOW as it is set, left to right: its items in
/// visual order ([_reordered]), and each inline box on it standing round
/// what it holds there -- its left edge before the first of it, its right
/// edge after the last -- outer boxes round inner ones. The box's START is
/// its right side (css-writing-modes-4 2.4.2): its right margin, border
/// and padding are on the line it opens on, its left ones on the line it
/// closes on, and a line it runs on over has neither (css-break-3 5.4).
/// inline-frame-pieces n3's `<code>` over two lines of an `rtl` paragraph
/// is padded on its RIGHT on the first and its LEFT on the second, where
/// Chrome rounds them.
///
/// A box that holds nothing on the line stands where the first of its
/// edges does in visual order. One the order parts -- what it holds on the
/// line not side by side -- is one fragment over all of it here, where
/// Blink sets one for each part.
List<Object> _rtlLine(_Line l) {
  final vis = _reordered(l.placed);
  bool edge(_Item it) => it.kind == _Kind.open || it.kind == _Kind.close;
  Iterable<_Box> chain(_Box b) sync* {
    for (_Box? x = b; x != null && x.node != null; x = x.parent) {
      yield x;
    }
  }

  final holding = <_Box>{};
  for (final p in vis) {
    if (!edge(p.item)) holding.addAll(chain(p.item.box));
  }
  // What the boxes stand round: every item but the edges, and the first
  // edge of a box that holds nothing here.
  final anchors = <_Placed>[];
  final empty = <_Box>{};
  for (final p in vis) {
    final it = p.item;
    if (!edge(it) || (!holding.contains(it.box) && empty.add(it.box))) anchors.add(p);
  }
  final first = <_Box, int>{}, last = <_Box, int>{};
  for (var i = 0; i < anchors.length; i++) {
    for (final b in chain(anchors[i].item.box)) {
      first.putIfAbsent(b, () => i);
      last[b] = i;
    }
  }
  int depth(_Box b) => chain(b).length;
  final out = <Object>[];
  for (var i = 0; i < anchors.length; i++) {
    final opening = [
      for (final e in first.entries)
        if (e.value == i) e.key,
    ]..sort((a, b) => depth(a).compareTo(depth(b)));
    final closing = [
      for (final e in last.entries)
        if (e.value == i) e.key,
    ]..sort((a, b) => depth(b).compareTo(depth(a)));
    out.addAll([for (final b in opening) _Edge(b, left: true)]);
    if (!edge(anchors[i].item)) out.add(anchors[i]);
    out.addAll([for (final b in closing) _Edge(b, left: false)]);
  }
  return out;
}

int _bidiClass(_Item it) {
  if (it.kind != _Kind.word || it.text.isEmpty) return -1;
  var digits = false;
  for (final c in it.text.runes) {
    if (_strongR(c)) return 1;
    if (_strongL(c)) return 0;
    if (c >= 0x30 && c <= 0x39) digits = true;
  }
  return digits ? 2 : -1;
}

bool _strongR(int c) =>
    (c >= 0x0590 && c <= 0x08FF) ||
    (c >= 0xFB1D && c <= 0xFDFF) ||
    (c >= 0xFE70 && c <= 0xFEFF) ||
    (c >= 0x10800 && c <= 0x10FFF) ||
    (c >= 0x1E800 && c <= 0x1EFFF);

bool _strongL(int c) =>
    (c >= 0x41 && c <= 0x5A) ||
    (c >= 0x61 && c <= 0x7A) ||
    c == 0xAA ||
    c == 0xB5 ||
    c == 0xBA ||
    (c >= 0xC0 && c <= 0x2B8 && c != 0xD7 && c != 0xF7) ||
    (c >= 0x370 && c <= 0x58F && c != 0x37E && c != 0x387) ||
    (c >= 0x0900 && c <= 0x1FFF) ||
    (c >= 0x2C00 && c <= 0x2DFF) ||
    (c >= 0x3040 && c <= 0xD7FF) ||
    (c >= 0xF900 && c <= 0xFAFF) ||
    (c >= 0xFF21 && c <= 0xFF3A) ||
    (c >= 0xFF41 && c <= 0xFF5A) ||
    (c >= 0xFF66 && c <= 0xFFDC) ||
    (c >= 0x10000 && c <= 0x107FF) ||
    (c >= 0x20000 && c <= 0x3FFFF);

// ------------------------------------------------------------------ placed

/// A run of one text node on one line, drawn as one shaped piece.
class _Piece {
  _Piece(this.text, this.x, this.baseline, this.width, this.style, this.run, {this.reversed = false});
  String text;
  final double x, baseline;
  double width;
  final TextStyle style;
  final int run;

  /// At an odd bidi level: shaped and painted right to left, its neutrals
  /// mirrored, as Blink shapes a right-to-left segment. Measured as set
  /// left to right, which is its width but for the kerning of its pairs
  /// reversed.
  final bool reversed;

  /// Hidden by an ellipsis (see [InlineFlow.ellipsis]): not painted.
  bool hidden = false;
}

/// One inline box's fragment on one line: its border box.
class _Fragment {
  _Fragment(this.box, this.rect, this.line);
  final _Box box;
  final Rect rect;
  final int line;
}

/// What a line paints, in CSS order (appendix E): the frame of each inline
/// box it is on where the box starts on it, each piece of text and each
/// atomic inline, in tree order.
sealed class _Op {
  _Op(this.box);

  /// The inline box the op paints for: a frame's own box, the box a piece
  /// of text or an atomic inline is in. Its faded ancestors say which
  /// group the op is painted in.
  final _Box box;
}

class _FrameOp extends _Op {
  _FrameOp(this.fragment, super.box);
  final int fragment;
}

class _TextOp extends _Op {
  _TextOp(this.piece, super.box);
  final int piece;
}

class _AtomOp extends _Op {
  _AtomOp(this.atom, super.box);
  final int atom;
}

/// A laid-out flow: its lines, and everything placed on them.
class _Laid {
  _Laid(
    this.width,
    this.height,
    this.baselines,
    this.pieces,
    this.fragments,
    this.atomAt,
    this.ops, {
    this.hidden = const {},
  });
  final double width, height;

  /// The atomic inlines an ellipsis hides: laid out where they stand, and
  /// not painted.
  final Set<int> hidden;

  /// Each line's baseline, from the flow's top.
  final List<double> baselines;
  final List<_Piece> pieces;
  final List<_Fragment> fragments;
  final List<Offset?> atomAt;
  final List<_Op> ops;
}

/// The ops of a [_Laid] a box paints as one group ([RenderInlineFlow._paintGroups]):
/// the root's, or a faded, blended or moved box's, or one with something
/// placed against it. [ops] are the ones no such box inside it holds, by
/// their index, in order; [inner] are the groups of the boxes inside it, in
/// tree order.
class _PaintGroup {
  _PaintGroup(this.box, this.ops, this.inner);

  /// Null for the root.
  final _Box? box;
  final List<int> ops;
  final List<_PaintGroup> inner;
}

// ------------------------------------------------------------------ render

/// Where an atomic inline of an [InlineFlow] stands.
class InlineFlowParentData extends ContainerBoxParentData<RenderBox> {
  bool shown = false;

  /// How far the moved boxes round the atomic inline move it
  /// ([InlineBox.offset]), past [offset], where its line put it.
  Offset shift = Offset.zero;
}

enum _Pass { layout, dry, minContent, maxContent }

/// The render object behind [InlineFlow].
class RenderInlineFlow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, InlineFlowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, InlineFlowParentData>,
        DryLastBaseline,
        AsksGuarded,
        KeptUnderHatch,
        PaintOrder {
  RenderInlineFlow({
    required List<InlineNode> content,
    required InlineFont font,
    required TextStyle style,
    TextAlign textAlign = TextAlign.start,
    double textIndent = 0,
    double tabSize = 8,
    WhiteSpace whiteSpace = WhiteSpace.normal,
    WordBreak wordBreak = WordBreak.normal,
    OverflowWrap overflowWrap = OverflowWrap.normal,
    TextDirection textDirection = TextDirection.ltr,
    bool ellipsis = false,
    String ellipsisText = '\u2026',
    TextWrapStyle textWrap = TextWrapStyle.auto,
    TextScaler textScaler = TextScaler.noScaling,
  }) : _textScaler = textScaler,
       _content = content,
       _font = font,
       _style = style,
       _textAlign = textAlign,
       _textIndent = textIndent,
       _tabSize = tabSize,
       _whiteSpace = whiteSpace,
       _wordBreak = wordBreak,
       _overflowWrap = overflowWrap,
       _textDirection = textDirection,
       _ellipsis = ellipsis,
       _ellipsisText = ellipsisText,
       _textWrap = textWrap;

  List<InlineNode> _content;
  set content(List<InlineNode> v) {
    if (identical(v, _content)) return;
    _content = v;
    _changed();
    markNeedsCompositingBitsUpdate();
  }

  InlineFont _font;
  set font(InlineFont v) {
    if (v == _font) return;
    _font = v;
    _changed();
  }

  TextStyle _style;
  set style(TextStyle v) {
    if (v == _style) return;
    _style = v;
    _measure = _Measure();
    _changed();
  }

  TextAlign _textAlign;
  set textAlign(TextAlign v) {
    if (v == _textAlign) return;
    _textAlign = v;
    markNeedsLayout();
  }

  double _textIndent;
  set textIndent(double v) {
    if (v == _textIndent) return;
    _textIndent = v;
    markNeedsLayout();
  }

  double _tabSize;
  set tabSize(double v) {
    if (v == _tabSize) return;
    _tabSize = v;
    markNeedsLayout();
  }

  WhiteSpace _whiteSpace;
  set whiteSpace(WhiteSpace v) {
    if (v == _whiteSpace) return;
    _whiteSpace = v;
    _changed();
  }

  WordBreak _wordBreak;
  set wordBreak(WordBreak v) {
    if (v == _wordBreak) return;
    _wordBreak = v;
    _changed();
  }

  OverflowWrap _overflowWrap;
  set overflowWrap(OverflowWrap v) {
    if (v == _overflowWrap) return;
    _overflowWrap = v;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection v) {
    if (v == _textDirection) return;
    _textDirection = v;
    // The items' levels and the sides their edges open on are the
    // direction's ([_Flattener.rtl]).
    _changed();
  }

  /// See [InlineFlow.ellipsis].
  bool _ellipsis;
  set ellipsis(bool v) {
    if (v == _ellipsis) return;
    _ellipsis = v;
    markNeedsLayout();
  }

  /// See [InlineFlow.ellipsisText].
  String _ellipsisText;
  set ellipsisText(String v) {
    if (v == _ellipsisText) return;
    _ellipsisText = v;
    markNeedsLayout();
  }

  /// See [InlineFlow.textWrap].
  TextWrapStyle _textWrap;
  set textWrap(TextWrapStyle v) {
    if (v == _textWrap) return;
    _textWrap = v;
    markNeedsLayout();
  }

  /// See [InlineFlow.textScaler].
  TextScaler get textScaler => _textScaler;
  TextScaler _textScaler;
  set textScaler(TextScaler v) {
    if (v == _textScaler) return;
    _textScaler = v;
    _measure = _Measure();
    _changed();
  }

  _Measure _measure = _Measure();
  _Flat? _flatCache;
  _Laid? _laid;
  List<TextPainter>? _painters;

  void _changed() {
    _flatCache = null;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  /// The content flattened, once for each content: a content flattened
  /// again starts a generation of the widths it is measured in ([_Measure]).
  _Flat get _flat => _flatCache ??= _Flattener(
    _measure..turn(),
    _Box(0, null, null, _font._scaledBy(_textScaler), _scaled(_style, _textScaler), _whiteSpace, _wordBreak),
    rtl: _textDirection == TextDirection.rtl,
    scaler: _textScaler,
  ).run(_content);

  /// How many texts this flow has shaped to measure them, and how many of
  /// their widths it holds now (see [_Measure]): what a test reads to know
  /// that what it measured before is let go, and that a width asked again
  /// is not shaped again.
  @visibleForTesting
  ({int shaped, int held}) get debugMeasured => (shaped: _measure.shaped, held: _measure.held);

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! InlineFlowParentData) child.parentData = InlineFlowParentData();
  }

  List<RenderBox> get _children {
    final out = <RenderBox>[];
    var c = firstChild;
    while (c != null) {
      out.add(c);
      c = childAfter(c);
    }
    return out;
  }

  /// Every atomic inline as [pass] asks it, in the room [room] (the flow's
  /// content width, null: unbounded).
  List<_AtomFact> _atoms(_Pass pass, double? room) {
    final flat = _flat;
    final kids = _children;
    final out = <_AtomFact>[];
    for (var i = 0; i < flat.atoms.length; i++) {
      final a = flat.atoms[i];
      final kid = i < kids.length ? kids[i] : null;
      if (kid == null) {
        out.add(const _AtomFact(Size.zero, null));
        continue;
      }
      final max = room == null ? double.infinity : math.max(0.0, room - a.margin.horizontal);
      final c = BoxConstraints(maxWidth: max);
      switch (pass) {
        case _Pass.layout:
          kid.layout(c, parentUsesSize: true);
          out.add(
            _AtomFact(
              kid.size,
              a.ownBaseline ? kid.getDistanceToBaseline(TextBaseline.alphabetic, onlyReal: true) : null,
            ),
          );
        case _Pass.dry:
          out.add(
            _AtomFact(
              guardedSize(kid, () => kid.getDryLayout(c)),
              a.ownBaseline ? dryBaselineOf(kid, c, TextBaseline.alphabetic) : null,
            ),
          );
        case _Pass.minContent:
          out.add(_AtomFact(Size(guardedSize(kid, () => kid.getMinIntrinsicWidth(double.infinity)), 0), null));
        case _Pass.maxContent:
          out.add(_AtomFact(Size(guardedSize(kid, () => kid.getMaxIntrinsicWidth(double.infinity)), 0), null));
      }
    }
    return out;
  }

  bool get _breakAnywhere =>
      _overflowWrap == OverflowWrap.anywhere ||
      _overflowWrap == OverflowWrap.breakWord ||
      _wordBreak == WordBreak.breakWord;

  List<_Line> _lines(_Pass pass, double? width, List<_AtomFact> facts) {
    final flat = _flat;
    final root = flat.boxes.first;
    final items = [
      for (final it in flat.items)
        it.kind == _Kind.atomic
            ? it.copy(width: facts[it.atom].size.width + flat.atoms[it.atom].margin.horizontal)
            : it,
    ];
    final maxW = pass == _Pass.minContent ? 0.0 : (pass == _Pass.maxContent ? null : width);
    List<_Line> breakOn(_Cuts? cuts, [double? at]) => _break(
      items,
      at ?? maxW,
      m: _measure,
      wraps: flat.boxes.any((b) => b.whiteSpace.wraps),
      breakAnywhere: _breakAnywhere,
      indent: _textIndent,
      tabWidth: _tabSize * _measure.width(' ', root.style),
      tabMinimum: _measure.width(' ', root.style.copyWith(letterSpacing: 0, wordSpacing: 0)) / 2,
      hasContent: flat.hasContent,
      settle: (l) => _settle(l, root, flat.atoms, facts),
      cuts: cuts,
    );
    final greedy = breakOn(null);
    // Balancing and pretty lines move the breaks of a laid-out flow, never
    // its intrinsic widths (css-text-4 6.2).
    if (_textWrap == TextWrapStyle.auto || maxW == null || (pass != _Pass.layout && pass != _Pass.dry)) return greedy;
    final cuts = _rebroken(items, maxW, greedy, root.style, (at) => breakOn(null, at));
    if (cuts == null) return greedy;
    final lines = breakOn(cuts);
    return lines.length == greedy.length ? lines : greedy;
  }

  /// The items after which the lines break under [_textWrap], or null for
  /// the [greedy] ones: Blink's `ScoreLineBreaker`, ported as it is
  /// (Chromium's `score_line_breaker.cc`, `line_break_candidate.cc`).
  ///
  /// Each break opportunity is a candidate with two positions on the flow
  /// set as ONE line: where a line ending there ends -- after its last
  /// word or atomic inline, before the spaces and the box edges between
  /// that and the break, which "don't change pos_if_break" -- and where the
  /// next line starts, past the break's spaces and the end edges after
  /// them. A line from candidate `s` to `e` scores `(room - width)²` in
  /// float arithmetic, room taking a LayoutUnit epsilon, every line adds
  /// `4 × width × font-size`, a break before the paragraph's last word
  /// 10000 (typographic orphans), and a line wider than its room 1e12.
  /// `balance` scores every line of a paragraph of up to six;
  /// `pretty` only a last line of one word under a third of the room, and
  /// re-breaks the last four lines, the last scoring nothing. Where the
  /// score finds no breaks into the greedy count of lines (fewer than three
  /// break opportunities, or none that keep the count), pretty lines stay
  /// greedy and balanced ones are bisected ([_bisected]). A tab, a line
  /// wider than the flow or a word broken to fit it leaves the greedy lines
  /// of its paragraph as they are.
  ///
  /// A FORCED BREAK ENDS A PARAGRAPH, each scored on its own (Blink's
  /// `LineInfo::IsEndParagraph`): pretty lines in each, balanced ones in the
  /// first alone -- Blink balances from the block's first line only
  /// (`initiate_balancing_`), and never bisects a block with a forced break
  /// (`DidAppendForcedBreak`).
  _Cuts? _rebroken(
    List<_Item> items,
    double width,
    List<_Line> greedy,
    TextStyle rootStyle,
    List<_Line> Function(double) greedyAt,
  ) {
    final n = greedy.length;
    if (n < 2) return null;
    if (items.any((it) => it.kind == _Kind.space && it.text == '\t')) return null;
    // An overflow disables both (Blink's `disable_score_line_break_` and
    // `disable_bisect_line_break_`), and so does a word broken because it
    // overflowed (`RetryAfterOverflow`): a line holding a piece of one.
    final own = Set<_Item>.identity()..addAll(items);
    final forced = items.any((it) => it.kind == _Kind.br);
    if (!forced) {
      if (_textWrap == TextWrapStyle.balance && n > RenderBalance.maxLines) return null;
      if (_overflows(greedy, width, own)) return null;
      final scored = _scored(items, width, greedy, rootStyle.fontSize ?? 14);
      if (scored != null) return _Cuts(scored, [(0, items.length - 1)]);
      if (_textWrap != TextWrapStyle.balance) return null;
      final bisected = _bisected(items, width, greedy, rootStyle, greedyAt, own);
      return bisected == null ? null : _Cuts(bisected, [(0, items.length - 1)]);
    }
    // The paragraphs: the greedy lines up to each that ends on a forced
    // break, and their items up to and with that break.
    final after = <int>{};
    final spans = <(int, int)>[];
    var first = 0, from = 0;
    for (var k = 0; k < n; k++) {
      final end = greedy[k].placed.isNotEmpty && greedy[k].placed.last.item.kind == _Kind.br;
      if (!end && k < n - 1) continue;
      final to = end ? items.indexOf(greedy[k].placed.last.item) : items.length - 1;
      if (to < 0) return null;
      final lines = greedy.sublist(first, k + 1);
      final opens = first == 0;
      first = k + 1;
      final start = from;
      from = to + 1;
      if (lines.length < 2 || _overflows(lines, width, own, first: opens ? 0 : 1)) continue;
      if (_textWrap == TextWrapStyle.balance && (!opens || lines.length > RenderBalance.maxLines)) continue;
      // The paragraph's items, less the forced break that ends it.
      final scored = _scored(
        items,
        width,
        lines,
        rootStyle.fontSize ?? 14,
        start: start,
        end: end ? to : null,
        opens: opens,
      );
      if (scored == null) continue;
      after.addAll(scored);
      spans.add((start, to));
    }
    return spans.isEmpty ? null : _Cuts(after, spans);
  }

  /// Whether a line of [lines] overflows [width], or holds a piece of a
  /// word broken to fit -- an item not among [own]. [first] is the index
  /// of the first of [lines] in the flow (the first line is indented).
  bool _overflows(List<_Line> lines, double width, Set<_Item> own, {int first = 0}) {
    for (final (i, l) in lines.indexed) {
      if (l.content > width - (first + i == 0 ? _textIndent : 0) + 1 / 64) return true;
      if (l.placed.any((p) => !own.contains(p.item))) return true;
    }
    return false;
  }

  /// Whether the break after item [i] is one Blink's `ScoreLineBreaker`
  /// never sees: a space that STARTS a text run, more of the run after
  /// it on the same greedy line, where the text before is in a box that
  /// does not wrap. Blink's `LineBreaker::AppendCandidates` takes such
  /// leading spaces as a break by `auto_wrap_` before it sets the run's
  /// own style -- the previous run's -- so `<span style="white-space:
  /// nowrap">a b</span> c d` offers the score no break before `c`; where
  /// the greedy line ENDS at the space, `AppendLine` marks the break and
  /// it stands. Found in Chrome 151: `Vtiw krgv vs` nowrap, then ` dnwuiw
  /// Vk A nATp`, balanced in 173px, is the greedy two lines; with the
  /// greedy break at such a space the score keeps it. [placed] is every
  /// item the greedy lines hold: a space none holds hung at a line's end.
  /// [ends] is what each greedy line but the last ends on: a KEPT space
  /// (`pre-wrap`) hangs there still held, and its break stands too --
  /// Chrome 151 balances `h <span style="white-space: nowrap">abe e
  /// gebeg</span> haf   hb  ca` in 209px from the greedy break after the
  /// span (probe_bal/sweep7.py c195, and c27, c77, c191).
  static bool _leadsAfterNowrap(List<_Item> items, int i, Set<_Item> placed, Set<_Item> ends) {
    final it = items[i];
    if (it.kind != _Kind.space || i + 1 >= items.length || items[i + 1].run != it.run) return false;
    if (!placed.contains(it) || ends.contains(it)) return false;
    // The style is the last run's that set one: a run of spaces alone
    // returns before it does, so the text before is the last WORD's.
    // Kept spaces (`pre-wrap`) that lead the run are one break with the
    // first, the last as much as the first (a candidate stands after the
    // last alone): Chrome 151 keeps `ghfdc ceech` (nowrap) `  cbeha`
    // whole where pretty lines would move `cbeha` (probe_bal/sweep5.py c45).
    for (var j = i - 1; j >= 0; j--) {
      final p = items[j];
      if (p.kind == _Kind.space && p.run == it.run) {
        if (p.collapsible) return false; // not the run's first
        continue;
      }
      // A forced break is the block's, which wraps: the kept space that
      // starts the line after `<br>` breaks, whatever came before it
      // (sweep5 c214: `fefgb behfgh ae` nowrap, `<br>`, ` ba e   hg`).
      if (p.kind == _Kind.br) return false;
      if (p.kind != _Kind.word) continue;
      if (p.run == it.run) return false;
      return !p.box.whiteSpace.wraps;
    }
    return false;
  }

  /// Balanced lines where [_scored] finds none: Blink's
  /// `ParagraphLineBreaker::AttemptParagraphBalancing`, ported as it is.
  /// The narrowest width, bisected to a pixel in LayoutUnits from four
  /// fifths of the greedy lines' mean up to the flow's, at which the greedy
  /// break takes no more lines and none overflows; the lines are broken
  /// there and aligned in the flow's own width. A paragraph estimated at
  /// more than twelve lines of spaces is left greedy.
  Set<int>? _bisected(
    List<_Item> items,
    double width,
    List<_Line> greedy,
    TextStyle rootStyle,
    List<_Line> Function(double) greedyAt,
    Set<_Item> own,
  ) {
    final n = greedy.length;
    int lu(double v) => (v * 64).round();
    final space = _measure.width(' ', rootStyle);
    if (space > 0) {
      var chars = 0;
      for (final it in items) {
        chars += it.kind == _Kind.word || it.kind == _Kind.space ? it.text.length : (it.kind == _Kind.atomic ? 1 : 0);
      }
      final perLine = (lu(width) / 64 / space).floor();
      if (perLine <= 0) return null;
      if ((chars + perLine - 1) ~/ perLine > RenderBalance.maxLines * 2) return null;
    }
    var sum = 0;
    for (final l in greedy) {
      sum += lu(l.content);
    }
    final avg = sum ~/ n;
    var lower = (avg * 0.8).round();
    var upper = lu(width);
    while (lower + 64 < upper) {
      final middle = (upper + lower) ~/ 2;
      final lines = greedyAt(middle / 64);
      if (lines.length <= n && !_overflows(lines, middle / 64, own)) {
        upper = middle;
      } else {
        lower = middle;
      }
    }
    final lines = greedyAt(upper / 64);
    if (lines.length != n) return null;
    final cuts = <int>{};
    for (final l in lines.take(n - 1)) {
      final i = items.indexOf(l.placed.last.item);
      if (i < 0) return null;
      cuts.add(i);
    }
    return cuts;
  }

  /// The breaks Blink's `ScoreLineBreaker` chooses (see [_rebroken]) in
  /// the paragraph set on [greedy]: [items] from [start] up to [end], the
  /// forced break that ends it and is left out (null: the flow's end);
  /// [opens] where it is the flow's first, whose first line is indented.
  Set<int>? _scored(
    List<_Item> items,
    double width,
    List<_Line> greedy,
    double fontSize, {
    int start = 0,
    int? end,
    bool opens = true,
  }) {
    final n = greedy.length;
    final stop = end ?? items.length;
    // x[i]: where item i starts, the items before it set as one line.
    final x = List<double>.filled(items.length + 1, 0);
    var w = 0.0, runBase = 0.0, runText = '';
    var run = -1;
    var started = false;
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      x[i] = w;
      if (!started && it.kind == _Kind.space && it.collapsible) continue;
      if (it.kind != _Kind.open && it.kind != _Kind.close) started = true;
      if (it.kind == _Kind.word || it.kind == _Kind.space) {
        if (run >= 0 && run == it.run) {
          runText += it.text;
        } else {
          runBase = w;
          run = it.run;
          runText = it.text;
        }
        w = runBase + _measure.width(runText, it.style!) + it.kern;
      } else if ((it.kind != _Kind.open && it.kind != _Kind.close) || it.width != 0) {
        w += it.width;
        run = -1;
        runText = '';
        runBase = w;
      }
    }
    x[items.length] = w;
    bool opaque(_Item it) =>
        it.kind == _Kind.open || it.kind == _Kind.close || it.kind == _Kind.space || it.kind == _Kind.mark;
    double ifBreak(int i) {
      var e = i;
      while (e >= 0 && opaque(items[e])) {
        e--;
      }
      return x[e + 1];
    }

    double noBreak(int i) {
      var k = i + 1;
      while (k < items.length && items[k].kind == _Kind.close) {
        k++;
      }
      return x[k];
    }

    // The window: the whole paragraph to balance, the last four lines to
    // make pretty -- where its last line is one short word.
    var from = start, lines = n;
    if (_textWrap == TextWrapStyle.pretty) {
      final last = greedy.last;
      final lastRoom = width - (n == 1 && opens ? _textIndent : 0);
      final placed = last.placed;
      // A break opportunity inside the line: after an item before its last
      // word or atomic inline -- not the spaces or the forced break after it.
      final lastContent = placed.lastIndexWhere((p) => p.item.kind == _Kind.word || p.item.kind == _Kind.atomic);
      var breaksInside = false;
      for (var j = 0; j < lastContent && !breaksInside; j++) {
        breaksInside = placed[j].item.breakAfter;
      }
      // An atomic inline last before a forced break breaks after itself
      // (Blink's `CanBreakInside` sees the break's result after it): Chrome
      // 151 leaves `ahhabfh hda d` / `#` / `<br>` as it is, pretty, where it
      // re-breaks the same paragraph ending on a word, or ending the block
      // (probe_bal/brvar2.py).
      if (end != null && lastContent >= 0 && placed[lastContent].item.kind == _Kind.atomic) breaksInside = true;
      // A THIRD OF THE ROOM IN LAYOUTUNITS, the division cut down to 1/64
      // px, against the line's width rounded up to them: Chrome 151 leaves
      // `gpepf` (44.65625) last in 134px (a third 44.65625, not 44.667)
      // as it is (probe_bal/sweep6.py Inter 94, c110).
      if (!(_ceil64(last.content) < (lastRoom * 64 / 3).floorToDouble() / 64) || breaksInside) return null;
      lines = math.min(RenderPretty.tail, n);
    }
    if (lines < n || !opens) {
      // The window starts where its first line does, past end edges (and
      // the spaces a line drops at its start).
      from = items.indexOf(greedy[n - lines].placed.first.item);
      if (from < 0) return null;
      while (from < stop && items[from].kind == _Kind.close) {
        from++;
      }
    }
    // Candidates: the window's start, each break opportunity in it with a
    // word or atomic inline after it, its end.
    var lastContent = stop - 1;
    while (lastContent > from && items[lastContent].kind != _Kind.word && items[lastContent].kind != _Kind.atomic) {
      lastContent--;
    }
    final at = <int>[-1];
    final nb = <double>[x[from]], ib = <double>[x[from]];
    final placed = Set<_Item>.identity()
      ..addAll([
        for (final l in greedy)
          for (final p in l.placed) p.item,
      ]);
    final ends = Set<_Item>.identity();
    for (final l in greedy.take(greedy.length - 1)) {
      final last = l.placed.lastWhere(
        (p) => p.item.kind != _Kind.open && p.item.kind != _Kind.close && p.item.kind != _Kind.mark,
        orElse: () => _Placed(items[from]),
      );
      ends.add(last.item);
    }
    for (var i = from; i < lastContent; i++) {
      if (!items[i].breakAfter || _leadsAfterNowrap(items, i, placed, ends)) continue;
      // A run of kept spaces breaks after its last, across box edges too
      // (UAX #14 LB7: no break before a space): each is an item that may
      // break after it, where the greedy lines hang the run whole.
      if (items[i].kind == _Kind.space) {
        var k = i + 1;
        while (k < items.length &&
            (items[k].kind == _Kind.open || items[k].kind == _Kind.close || items[k].kind == _Kind.mark)) {
          k++;
        }
        if (k < items.length && items[k].kind == _Kind.space) continue;
      }
      at.add(i);
      ib.add(ifBreak(i));
      nb.add(noBreak(i));
    }
    at.add(stop - 1);
    // KEPT SPACES BEFORE A FORCED BREAK, IN THE LAST WORD'S TEXT, are the
    // last line's: they hang only where they do not fit (css-text-3
    // 4.1.3), and Chrome 151 scores the line with them -- it leaves
    // `pre-wrap` paragraphs ending `dbhfahe <br>` greedy that it balances
    // as css_box did without the space (probe_pw/brspace.py: sweep5 c7,
    // c8, c76). Spaces that are a text of their own, after a tag
    // (`<span>ahahf</span> <br>`), change nothing (c81, c135, c190, c283).
    var last = ifBreak(stop - 1);
    if (end != null) {
      var k = stop - 1;
      while (k >= start &&
          (items[k].kind == _Kind.open || items[k].kind == _Kind.close || items[k].kind == _Kind.mark)) {
        k--;
      }
      var j = k;
      while (j >= start && items[j].kind == _Kind.space && !items[j].collapsible) {
        j--;
      }
      if (j < k && j >= start && items[j].kind == _Kind.word) {
        last = x[k + 1];
        // As far as they fit the greedy last line: past its room they hang
        // (sweep5 c154: `ebhgd   ` 128px in 127 leaves `#` where it is;
        // c5: `WdfvT ` 3.5px past the room balances the lines above it).
        final first = items.indexOf(greedy.last.placed.first.item);
        final room = width - (n == 1 && opens ? _textIndent : 0);
        if (first >= 0) last = math.min(last, x[first] + room);
      }
    }
    ib.add(last);
    nb.add(x[stop]);
    final c = at.length;
    if (c < 5) return null; // three break opportunities at least
    final penalty = List<double>.filled(c, 0);
    penalty[c - 2] = 10000; // the break before the last word
    final f = Float32List(1);
    double fl(double v) => (f..[0] = v)[0];
    final justified = _textAlign == TextAlign.justify;
    final linePenalty = justified ? 0.0 : fl(fl(fl(width * fontSize) * 2) * 2);
    final balanced = _textWrap == TextWrapStyle.balance;
    double availToFit(int line) {
      var a = width - (line == 0 && opens && from == start ? _textIndent : 0);
      a = (a * 64).floorToDouble() / 64; // LayoutUnit
      return fl(math.max(0.0, a) + 1 / 64);
    }

    final score = <double>[0], prev = <int>[0], lineOf = <int>[0];
    var active = 0;
    for (var end = 1; end < c; end++) {
      final isLast = end == c - 1;
      var best = double.maxFinite;
      var bestPrev = 0;
      var lastLine = lineOf[active];
      var avail = availToFit(lastLine);
      var startEdge = fl(fl(ib[end]) - avail);
      var bestHope = 0.0;
      for (var start = active; start < end; start++) {
        final li = lineOf[start];
        if (li != lastLine) {
          lastLine = li;
          final na = availToFit(li);
          if (na != avail) {
            avail = na;
            startEdge = fl(fl(ib[end]) - avail);
            bestHope = 0;
          }
        }
        if (fl(score[start] + bestHope) >= best) continue;
        final delta = fl(fl(nb[start]) - startEdge);
        var widthScore = 0.0, additional = 0.0;
        if ((isLast || !justified) && delta < 0) {
          widthScore = 1e12;
        } else if (isLast && !balanced) {
          additional = fl(4 * penalty[start]);
        } else if (delta < 0) {
          widthScore = 1e12;
        } else {
          widthScore = fl(delta * delta);
        }
        if (delta < 0) {
          active = start + 1;
        } else {
          bestHope = widthScore;
        }
        final sc = fl(fl(score[start] + widthScore) + additional);
        if (sc <= best) {
          best = sc;
          bestPrev = start;
        }
      }
      score.add(fl(fl(best + penalty[end]) + linePenalty));
      prev.add(bestPrev);
      lineOf.add(lineOf[bestPrev] + 1);
    }
    final cuts = <int>{};
    var count = 0;
    for (var i = c - 1; i > 0; i = prev[i]) {
      count++;
      if (i < c - 1) cuts.add(at[i]);
    }
    if (count != lines) return null;
    // The lines before the window keep their greedy breaks.
    for (var k = 0; k < n - lines; k++) {
      final i = items.indexOf(greedy[k].placed.last.item);
      if (i < 0) return null;
      cuts.add(i);
    }
    return cuts;
  }

  double _widest(List<_Line> lines, {bool fit = false}) {
    var w = 0.0;
    for (var i = 0; i < lines.length; i++) {
      w = math.max(w, (fit ? lines[i].fit : lines[i].content) + (i == 0 ? _textIndent : 0));
    }
    return w;
  }

  /// Lay the flow out [width] wide (null: at its max-content width).
  _Laid _lay(_Pass pass, double? width) {
    final flat = _flat;
    if (!flat.hasContent) {
      // Its points are laid out all the same (see [performLayout]).
      _atoms(pass, width);
      return _Laid(0, 0, const [], const [], const [], List.filled(flat.atoms.length, null), const []);
    }
    final facts = _atoms(pass, width);
    final lines = _lines(pass, width, facts);
    final contentW = width ?? _widest(lines);
    final rtl = _textDirection == TextDirection.rtl;
    final pieces = <_Piece>[];
    final fragments = <_Fragment>[];
    final atomAt = List<Offset?>.filled(flat.atoms.length, null);
    final ops = <_Op>[];
    final baselines = <double>[];
    final hidden = <int>{};
    for (var li = 0; li < lines.length; li++) {
      final l = lines[li];
      final ind = li == 0 ? _textIndent : 0.0;
      final free = (l.avail.isFinite ? l.avail : contentW) - l.content - ind;
      final justify = _textAlign == TextAlign.justify && !l.endsWithForcedBreak && li < lines.length - 1 && free > 0;
      final nSpaces = justify
          ? l.placed.where((p) => p.item.kind == _Kind.space && p.item.width > 0 && p.item.text != '\t').length
          : 0;
      final extraPerSpace = nSpaces > 0 ? free / nSpaces : 0.0;
      // Under `rtl` a line starts at its RIGHT edge: `start` aligns right,
      // the indent comes off the right, and a line too long for its box
      // overflows the LEFT (css-text-3 7.1).
      var x =
          (rtl ? 0.0 : ind) +
          (free < 0
              ? (rtl ? free : 0.0)
              : switch (_textAlign) {
                  TextAlign.center => free / 2,
                  TextAlign.right => free,
                  TextAlign.end => rtl ? 0.0 : free,
                  TextAlign.left => 0.0,
                  _ => rtl && !justify ? free : 0.0,
                });
      // Kept spaces that hang past the line's end hang off its LEFT under
      // `rtl`, where they stand in visual order ([_reordered]).
      if (rtl) x -= math.max(0.0, l.width - l.content);
      final baselineY = l.y + l.above;
      baselines.add(baselineY);
      // The shift each box stands at on this line: its open's, or the one
      // it carried in.
      double shiftOf(_Box b) {
        for (final p in l.placed) {
          if (p.item.kind == _Kind.open && identical(p.item.box, b)) return p.shift;
        }
        return l.carriedShift[b] ?? 0.0;
      }

      // Where each box's fragment starts on this line, and which fragment
      // each open box on it is. A right-to-left line sets each box's left
      // edge where it stands ([_rtlLine]).
      final openX = <_Box, double>{};
      if (!rtl) {
        for (final b in l.carried) {
          openX[b] = x;
        }
      }
      final fragmentOf = <_Box, int>{};
      final lineOps = <(int, _Op)>[];
      final firstPiece = pieces.length;
      final lineAtoms = <(double, double, int)>[];
      final order = <_Placed, int>{};
      for (var i = 0; i < l.placed.length; i++) {
        order[l.placed[i]] = i;
      }
      void addFragment(_Box b, double x0, double x1, int at) {
        final shift = shiftOf(b);
        final f = b.font;
        final rect = Rect.fromLTRB(
          x0,
          baselineY - shift - f.ascent - b.frame.top,
          x1,
          baselineY - shift + f.descent + b.frame.bottom,
        );
        fragments.add(_Fragment(b, rect, li));
        fragmentOf[b] = fragments.length - 1;
        lineOps.add((at, _FrameOp(fragments.length - 1, b)));
      }

      // A word, a space or an atomic inline, set at [x] and past it.
      void set(_Placed p) {
        final it = p.item;
        p.x = x;
        switch (it.kind) {
          case _Kind.word:
          case _Kind.space:
            final tab = it.text == '\t';
            final w = it.width + (it.kind == _Kind.space && it.width > 0 && !tab ? extraPerSpace : 0);
            // A tab is room to its stop, and no glyph.
            if (it.text.isNotEmpty && !tab) {
              // One piece per run on one line: a renderer that shaped each
              // word on its own would lose the kerning between them.
              final bl = baselineY - p.shift;
              final last = pieces.isEmpty ? null : pieces.last;
              // A justified line's spaces are wider than their glyphs, so
              // its words are drawn one by one.
              if (last != null &&
                  extraPerSpace == 0 &&
                  last.run == it.run &&
                  last.baseline == bl &&
                  (last.x + last.width - x).abs() < 0.01 &&
                  lineOps.isNotEmpty &&
                  lineOps.last.$2 is _TextOp &&
                  (lineOps.last.$2 as _TextOp).piece == pieces.length - 1) {
                // A run at an odd level is set right to left: what stands
                // after it on the line came before it in the text.
                last.text = it.level.isOdd ? it.text + last.text : last.text + it.text;
                last.width = x + w - last.x;
              } else {
                pieces.add(_Piece(it.text, x, bl, w, it.style!, it.run, reversed: it.level.isOdd));
                lineOps.add((order[p]!, _TextOp(pieces.length - 1, it.box)));
              }
            }
            x += w;
          case _Kind.atomic:
            final a = flat.atoms[it.atom];
            final top = baselineY - p.shift - p.above + a.margin.top;
            atomAt[it.atom] = Offset(x + a.margin.left, top);
            lineOps.add((order[p]!, _AtomOp(it.atom, it.box)));
            lineAtoms.add((x, x + it.width, it.atom));
            x += it.width;
          // A point at the line's top, where it came out: nothing painted.
          case _Kind.mark:
            atomAt[it.atom] = Offset(x, l.y);
          case _Kind.br:
          case _Kind.open:
          case _Kind.close:
            break;
        }
      }

      // The frame paints where the box STARTS on this line, in tree order:
      // at its open, or before everything for a carried box.
      int paintsAt(_Box b) {
        final opener = l.placed.indexWhere((q) => q.item.kind == _Kind.open && identical(q.item.box, b));
        return opener < 0 ? l.carried.indexOf(b) - l.carried.length : opener;
      }

      // A right-to-left line: its boxes' edges where [_rtlLine] stands
      // them, the right one with the box's start side where it opens on
      // the line, the left one with its end side where it closes.
      if (rtl) {
        for (final t in _rtlLine(l)) {
          if (t is! _Edge) {
            set(t as _Placed);
            continue;
          }
          final b = t.box;
          bool has(_Kind k) => l.placed.any((q) => q.item.kind == k && identical(q.item.box, b));
          if (t.left) {
            final ends = has(_Kind.close);
            if (ends) x += b.margin.left;
            openX[b] = x;
            if (ends) x += b.frame.left;
          } else {
            final starts = has(_Kind.open);
            if (starts) x += b.frame.right;
            addFragment(b, openX.remove(b)!, x, paintsAt(b));
            if (starts) x += b.margin.right;
          }
        }
      } else {
        for (final p in _visualOrder(l.placed)) {
          final it = p.item;
          switch (it.kind) {
            case _Kind.open:
            case _Kind.close:
              p.x = x;
              // The edge met first on the line is the box's LEFT edge and
              // carries its left margin, border and padding.
              final b = it.box;
              if (!openX.containsKey(b)) {
                x += b.margin.left;
                openX[b] = x;
                x += b.frame.left;
              } else {
                x += b.frame.right;
                addFragment(b, openX.remove(b)!, x, paintsAt(b));
                x += b.margin.right;
              }
            default:
              set(p);
          }
        }
      }
      // Boxes still open at the line's end get a fragment to it.
      for (final e in openX.entries) {
        final b = e.key;
        addFragment(b, e.value, x, paintsAt(b));
      }
      if (pass == _Pass.layout && _ellipsis && !rtl && l.avail.isFinite && ind + l.content > l.avail + 0.01) {
        _ellipsize(l, pieces, firstPiece, lineAtoms, lineOps, hidden, baselineY);
      }
      // Tree order: carried boxes first (outermost first), then by where
      // each thing is among the line's items.
      lineOps.sort((a, b) => a.$1.compareTo(b.$1));
      ops.addAll(lineOps.map((e) => e.$2));
    }
    final last = lines.isEmpty ? null : lines.last;
    final height = last == null ? 0.0 : last.y + last.height;
    return _Laid(contentW, height, baselines, pieces, fragments, atomAt, ops, hidden: hidden);
  }

  /// LINE [l] ENDS ON AN ELLIPSIS (see [InlineFlow.ellipsis]), as Blink's
  /// `LineTruncator` ends it: the line's leaves -- its pieces of text from
  /// [firstPiece] on, its atomic inlines [atoms] -- walked from its end.
  /// A leaf that starts past the room is hidden; one that ends where the
  /// ellipsis still fits after it takes the ellipsis; one across that
  /// point is cut where it still fits, if it is text, and hidden where it
  /// is not or nothing of it fits. The first leaf is never hidden: it
  /// keeps a character, or itself. What is hidden drops out of [ops]
  /// ([hidden], for an atomic inline) and the ellipsis is the line's last
  /// op, in the flow's own style, on the line's baseline.
  void _ellipsize(
    _Line l,
    List<_Piece> pieces,
    int firstPiece,
    List<(double, double, int)> atoms,
    List<(int, _Op)> ops,
    Set<int> hidden,
    double baseline,
  ) {
    final style = _flat.boxes.first.style.copyWith(decoration: TextDecoration.none);
    // The room the ellipsis asks for is its advance without the spacing
    // after it: Chrome 151 keeps `abcde…` in 101px of Ahem tracked 1px (5 x
    // 17 + 16) and `abcd…` in 88px tracked 2px (4 x 18 + 16), and draws the
    // ellipsis after the fifth letter's spacing (probe_ell/tracked.py).
    final ellipsisWidth = _measure.width(_ellipsisText, style.copyWith(letterSpacing: 0));
    final leaves = <({double x0, double x1, int piece, int atom})>[
      for (var i = firstPiece; i < pieces.length; i++)
        (x0: pieces[i].x, x1: pieces[i].x + pieces[i].width, piece: i, atom: -1),
      for (final a in atoms) (x0: a.$1, x1: a.$2, piece: -1, atom: a.$3),
    ]..sort((a, b) => a.x0.compareTo(b.x0));
    void hide(({double x0, double x1, int piece, int atom}) leaf) {
      if (leaf.piece >= 0) {
        pieces[leaf.piece].hidden = true;
      } else {
        hidden.add(leaf.atom);
      }
    }

    double? at;
    for (var i = leaves.length - 1; i >= 0; i--) {
      final leaf = leaves[i];
      final first = i == 0;
      if (l.avail - leaf.x0 <= 0) {
        if (!first) hide(leaf);
        continue;
      }
      final space = l.avail - leaf.x0 - ellipsisWidth;
      if (space >= leaf.x1 - leaf.x0) {
        at = leaf.x1;
        break;
      }
      if (space <= 0 && !first) {
        hide(leaf);
        continue;
      }
      if (leaf.piece < 0) {
        if (first) {
          at = leaf.x1;
          break;
        }
        hide(leaf);
        continue;
      }
      // The text is cut between two characters, where its own shaping puts
      // the one after the last kept -- the kerning with it included, as a
      // cut of the shaped run keeps it. In tracked text each character
      // kept brings the spacing after it, as Blink's does, and no more:
      // Skia's carets in tracked text stand half a spacing past the
      // boundary, so the run is shaped untracked for them and the spacing
      // added (`abcde…` in 101px of Ahem tracked 1px, not `abcd…`).
      final p = pieces[leaf.piece];
      final spacing = p.style.letterSpacing ?? 0;
      final tp = TextPainter(
        text: han(p.text, style: spacing == 0 ? p.style : p.style.copyWith(letterSpacing: 0)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      try {
        final steps = <int, int>{0: 0};
        double caret(int k) => tp.getOffsetForCaret(TextPosition(offset: k), Rect.zero).dx + steps[k]! * spacing;
        // Cut between grapheme clusters only ([_clusterEnds]).
        final ends = _clusterEnds(p.text);
        var keep = 0;
        for (var n = 1; n < ends.length; n++) {
          final k = ends[n];
          steps[k] = n;
          if (caret(k) > space) break;
          keep = k;
        }
        if (keep == 0 || keep == p.text.length) {
          if (!first) {
            hide(leaf);
            continue;
          }
          if (keep == 0) {
            keep = ends.length > 1 ? ends[1] : p.text.length;
            steps[keep] ??= 1;
          }
        }
        final w = caret(keep);
        p
          ..text = p.text.substring(0, keep)
          ..width = w;
        at = p.x + w;
      } finally {
        tp.dispose();
      }
      break;
    }
    ops.removeWhere(
      (e) => switch (e.$2) {
        _TextOp(:final piece) => pieces[piece].hidden,
        _AtomOp(:final atom) => hidden.contains(atom),
        _ => false,
      },
    );
    if (at == null) return;
    pieces.add(_Piece(_ellipsisText, at, baseline, ellipsisWidth, style, -1));
    ops.add((l.placed.length, _TextOp(pieces.length - 1, _flat.boxes.first)));
  }

  // -- intrinsics

  @override
  double computeMinIntrinsicWidth(double height) {
    if (!_flat.hasContent) return 0;
    return _widest(_lines(_Pass.minContent, null, _atoms(_Pass.minContent, null)), fit: true);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (!_flat.hasContent) return 0;
    return _widest(_lines(_Pass.maxContent, null, _atoms(_Pass.maxContent, null)), fit: true);
  }

  @override
  double computeMinIntrinsicHeight(double width) => _lay(_Pass.dry, width.isFinite ? width : null).height;

  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final w = constraints.hasBoundedWidth ? constraints.maxWidth : null;
    final laid = _lay(_Pass.dry, w);
    return constraints.constrain(Size(w ?? laid.width, laid.height));
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) {
    final laid = _lay(_Pass.dry, constraints.hasBoundedWidth ? constraints.maxWidth : null);
    return laid.baselines.isEmpty ? null : laid.baselines.first;
  }

  @override
  double? dryLastBaseline(BoxConstraints constraints, TextBaseline baseline) {
    final laid = _lay(_Pass.dry, constraints.hasBoundedWidth ? constraints.maxWidth : null);
    return laid.baselines.isEmpty ? null : laid.baselines.last;
  }

  /// Each line's baseline, from the flow's top, as last laid out.
  List<double> get lineBaselines => List.unmodifiable(_laid?.baselines ?? const <double>[]);

  /// [box]'s fragments, one per line it is on, as last laid out: each its
  /// border box in the flow's coordinates, where it is painted (moved by
  /// [InlineBox.offset]).
  List<Rect> fragmentsOf(InlineBox box) => [
    for (final f in _laid?.fragments ?? const <_Fragment>[])
      if (identical(f.box.node, box)) f.rect.shift(f.box.shift),
  ];

  /// The rectangle of every inline box that has a [InlineBox.key]: the union
  /// of its fragments, which is what a browser reports for an inline element
  /// (`getBoundingClientRect`), in the flow's coordinates.
  Map<Key, Rect> get boxRects {
    final out = <Key, Rect>{};
    for (final f in _laid?.fragments ?? const <_Fragment>[]) {
      final k = f.box.node?.key;
      if (k == null) continue;
      final had = out[k];
      final r = f.rect.shift(f.box.shift);
      out[k] = had == null ? r : had.expandToInclude(r);
    }
    return out;
  }

  /// The text as it was set: each run of one text node on one line, from
  /// the left of its advance, on its baseline -- what an ellipsis hides
  /// left out, and the ellipsis in. `reversed`: a run at an odd bidi level,
  /// its text in logical order and painted right to left.
  @visibleForTesting
  List<({String text, double x, double baseline, double width, TextStyle style, bool reversed})> get pieces => [
    for (final p in _laid?.pieces ?? const <_Piece>[])
      if (!p.hidden) (text: p.text, x: p.x, baseline: p.baseline, width: p.width, style: p.style, reversed: p.reversed),
  ];

  /// The baseline of the flow's last line, from its top.
  double? get lastBaseline {
    final b = _laid?.baselines;
    return b == null || b.isEmpty ? null : b.last;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final b = _laid?.baselines;
    return b == null || b.isEmpty ? null : b.first;
  }

  // -- layout

  @override
  void performLayout() {
    final w = constraints.hasBoundedWidth ? constraints.maxWidth : null;
    final laid = _lay(_Pass.layout, w);
    _laid = laid;
    _disposePainters();
    size = constraints.constrain(Size(w ?? laid.width, laid.height));
    // The containing block of every relative box in the flow (see
    // [InlineBox.offsetShare]), before any shift is read.
    _flat.boxes.first.width = size.width;
    final shifts = <int, Offset>{
      for (final op in laid.ops)
        if (op case _AtomOp(:final atom, :final box)) atom: box.shift,
    };
    // A POINT ON NO LINE -- a flow of nothing is no line (CSS 2.1 9.4.2)
    // -- is where the line would have started, at the flow's top, as what
    // is placed against a box on no line is (below).
    final points = {
      for (final it in _flat.items)
        if (it.kind == _Kind.mark) it.atom,
    };
    var kid = firstChild;
    var i = 0;
    while (kid != null && i < laid.atomAt.length) {
      final data = kid.parentData! as InlineFlowParentData;
      final at = laid.atomAt[i];
      data
        ..offset = at ?? (points.contains(i) ? Offset(_lineStart, 0) : Offset.zero)
        ..shift = shifts[i] ?? Offset.zero
        ..shown = at != null && !laid.hidden.contains(i);
      kid = childAfter(kid);
      i++;
    }
    // WHAT IS PLACED AGAINST A BOX is laid out its containing block, the
    // padding box from its first piece's start to its last one's end. A
    // box on no line -- a flow of nothing, which is no line (CSS 2.1
    // 9.4.2) -- is a point where the line would have started, as
    // `text-align` puts it, at the flow's top; what is placed against it
    // is painted after all else, faded as the boxes round it fade.
    _placedKids = {};
    _orphans = [];
    for (final node in _placedOf(_content)) {
      if (kid == null) break;
      final data = kid.parentData! as InlineFlowParentData;
      final frags = [
        for (final f in laid.fragments)
          if (identical(f.box.node, node)) f,
      ];
      final Rect cb;
      final Offset shift;
      if (frags.isNotEmpty) {
        final border = node.decoration?.padding.resolve(TextDirection.ltr) ?? EdgeInsets.zero;
        final first = frags.first.rect, last = frags.last.rect;
        final left = first.left + border.left;
        cb = Rect.fromLTRB(
          left,
          first.top + border.top,
          math.max(left, last.right - border.right),
          math.max(first.top + border.top, last.bottom - border.bottom),
        );
        shift = frags.first.box.shift;
        _placedKids![frags.first.box] = kid;
      } else {
        cb = Rect.fromLTWH(_lineStart, 0, 0, 0);
        final (moved, alpha) = _around(node);
        shift = moved;
        if (alpha > 0) _orphans!.add((kid, alpha));
      }
      kid.layout(BoxConstraints.tight(cb.size));
      data
        ..offset = cb.topLeft
        ..shift = shift
        ..shown = true;
      kid = childAfter(kid);
    }
    while (kid != null) {
      (kid.parentData! as InlineFlowParentData).shown = false;
      kid = childAfter(kid);
    }
  }

  /// Where a line of nothing would start across this box, as `text-align`
  /// puts it.
  double get _lineStart {
    final rtl = _textDirection == TextDirection.rtl;
    return switch (_textAlign) {
      TextAlign.center => size.width / 2,
      TextAlign.right => size.width,
      TextAlign.left => 0.0,
      TextAlign.end => rtl ? 0.0 : size.width,
      _ => rtl ? size.width : 0.0,
    };
  }

  /// The child placed against each box, as last laid out
  /// ([InlineBox.placed]).
  Map<_Box, RenderBox>? _placedKids;

  /// What is placed against the boxes on no line, each with the opacity of
  /// the boxes round it and its own.
  List<(RenderBox, double)>? _orphans;

  /// How far [node] is moved, its own offset and those of the boxes round
  /// it, and the opacity they all come to.
  (Offset, double) _around(InlineBox node) {
    (Offset, double)? walk(List<InlineNode> ns, Offset at, double alpha) {
      for (final n in ns) {
        if (n is! InlineBox) continue;
        final here = (at + n.offset + Offset(n.offsetShare * size.width, 0), alpha * n.opacity);
        if (identical(n, node)) return here;
        if (walk(n.children, here.$1, here.$2) case final found?) return found;
      }
      return null;
    }

    return walk(_content, Offset.zero, 1) ?? (Offset.zero, 1);
  }

  // -- paint

  void _disposePainters() {
    for (final p in _painters ?? const <TextPainter>[]) {
      p.dispose();
    }
    _painters = null;
  }

  List<TextPainter> _paintersFor(_Laid laid) => _painters ??= [
    for (final p in laid.pieces)
      TextPainter(
        text: han(_painted(p), style: p.style),
        textDirection: p.reversed ? TextDirection.rtl : TextDirection.ltr,
        maxLines: 1,
      )..layout(),
  ];

  /// A piece's text as it is painted. A DECORATED PIECE THAT ENDS IN A
  /// SPACE ends on a word joiner too: Skia decorates no white space that
  /// ends its paragraph, and each piece is a paragraph of its own, where
  /// Blink underlines the space before an inline box (`Notes ` then a
  /// chip). The joiner draws nothing and takes no room.
  static String _painted(_Piece p) =>
      (p.style.decoration ?? TextDecoration.none) != TextDecoration.none && p.text.endsWith(' ')
      ? '${p.text}\u2060'
      : p.text;

  @override
  void paint(PaintingContext context, Offset offset) {
    final laid = _laid;
    if (laid == null) return;
    final painters = _paintersFor(laid);
    final kids = _children;
    // Each fragment snapped to the page's pixels, half up, as Blink snaps a
    // paint rect; and the strip each is cut from -- the box's fragments set
    // end to end.
    final page = localToGlobal(Offset.zero);
    double snap(double v) => (v + 0.5).floorToDouble();
    final boxes = <Rect>[];
    for (final f in laid.fragments) {
      final g = f.rect.shift(page + f.box.shift);
      boxes.add(Rect.fromLTRB(snap(g.left), snap(g.top), snap(g.right), snap(g.bottom)).shift(-page));
    }
    final strips = List<Rect>.filled(boxes.length, Rect.zero);
    final byBox = <_Box, List<int>>{};
    for (var i = 0; i < laid.fragments.length; i++) {
      (byBox[laid.fragments[i].box] ??= []).add(i);
    }
    final rtl = _textDirection == TextDirection.rtl;
    for (final idx in byBox.values) {
      final length = idx.fold(0.0, (t, i) => t + boxes[i].width);
      var before = 0.0;
      for (final i in idx) {
        final b = boxes[i];
        strips[i] = rtl
            ? Rect.fromLTWH(b.right + before - length, b.top, length, b.height)
            : Rect.fromLTWH(b.left - before, b.top, length, b.height);
        before += b.width;
      }
    }
    final atomNodes = _atomsOf(_content);
    void paintOp(PaintingContext context, Offset offset, _Op op, {bool flat = false}) {
      switch (op) {
        case _FrameOp(:final fragment):
          final f = laid.fragments[fragment];
          final d = f.box.node?.decoration;
          final box = boxes[fragment];
          if (d == null || box.isEmpty) return;
          final canvas = context.canvas;
          final painter = d.createBoxPainter(markNeedsPaint);
          final strip = strips[fragment].shift(offset);
          // A BOX OF ONE FRAGMENT is its own strip, and is painted as a
          // block's decoration is, uncut: an outer shadow falls outside
          // the border box (css-backgrounds-3 7.1.1). Only a fragment of
          // several is its slice of the strip (css-break-3 5.4).
          final whole = byBox[f.box]!.length == 1;
          if (!whole) {
            canvas
              ..save()
              ..clipRect(box.shift(offset));
          }
          painter.paint(canvas, strip.topLeft, ImageConfiguration(size: strip.size, textDirection: _textDirection));
          if (!whole) canvas.restore();
          painter.dispose();
        case _TextOp(:final piece):
          final p = laid.pieces[piece];
          if (p.text.trim().isEmpty && (p.style.decoration ?? TextDecoration.none) == TextDecoration.none) return;
          final tp = painters[piece];
          // SKIA ROUNDS THE PARAGRAPH'S BASELINE, then the glyphs' device
          // row: a painter with its baseline 15.5 below its top (Inter at
          // 16px) draws its glyphs 16 below, and put 4.5 down to stand on a
          // baseline at 20 they came out on 21 -- every flow's text a pixel
          // under Chrome's, which stands the glyphs on the rounded
          // baseline. Measured in the harness: Arial at 13px (11.98) drawn
          // from 0.5 down stands on 13, not 12.
          final b = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic).roundToDouble();
          tp.paint(context.canvas, offset + op.box.shift + Offset(p.x, p.baseline - b));
        case _AtomOp(:final atom):
          if (atom < kids.length) {
            final kid = kids[atom];
            final data = kid.parentData! as InlineFlowParentData;
            if (!data.shown) return;
            final opacity = atom < atomNodes.length ? atomNodes[atom].opacity : 1.0;
            final at = offset + data.offset + data.shift;
            if (opacity >= 1) {
              context.paintChild(kid, at);
              return;
            }
            final alpha = Color.getAlphaFromOpacity(opacity);
            if (alpha == 0) return;
            if (flat) {
              context.canvas.saveLayer(null, Paint()..color = Color.fromARGB(alpha, 0, 0, 0));
              context.paintChild(kid, at);
              context.canvas.restore();
            } else {
              context.pushOpacity(offset, alpha, (c, o) => c.paintChild(kid, o + data.offset + data.shift));
            }
          }
      }
    }

    // A FADED OR MOVED BOX IS A GROUP painted after the rest (appendix E,
    // step 8): the ops of no such box first, in order; then each group, in
    // tree order -- the ops of its own, then the groups inside it, the same
    // way. A faded box is one picture at its alpha; a moved one is no
    // layer, only later. A BLENDED box is one `saveLayer`, restored in its
    // mode at its alpha, and every faded box inside it is one too ([flat]):
    // a layer pushed inside a `saveLayer` is no part of it.
    void group(PaintingContext context, Offset offset, _PaintGroup g, {bool flat = false}) {
      for (final i in g.ops) {
        paintOp(context, offset, laid.ops[i], flat: flat);
      }
      for (final inner in g.inner) {
        final b = inner.box!;
        final opacity = b.node!.opacity, mode = b.node!.blendMode;
        if (opacity >= 1 && mode == BlendMode.srcOver) {
          group(context, offset, inner, flat: flat);
          continue;
        }
        final alpha = Color.getAlphaFromOpacity(opacity);
        if (alpha == 0) continue;
        if (flat || mode != BlendMode.srcOver) {
          final canvas = context.canvas;
          canvas.saveLayer(
            null,
            Paint()
              ..color = Color.fromARGB(alpha, 0, 0, 0)
              ..blendMode = mode,
          );
          group(context, offset, inner, flat: true);
          canvas.restore();
          continue;
        }
        context.pushOpacity(offset, alpha, (c, o) => group(c, o, inner));
      }
      // What is placed against the box, after all it holds.
      final kid = g.box == null ? null : _placedKids?[g.box];
      if (kid != null) {
        final data = kid.parentData! as InlineFlowParentData;
        if (data.shown) context.paintChild(kid, offset + data.offset + data.shift);
      }
    }

    group(context, offset, _groupsOf(laid));
    for (final (kid, opacity) in _orphans ?? const <(RenderBox, double)>[]) {
      final data = kid.parentData! as InlineFlowParentData;
      final at = offset + data.offset + data.shift;
      if (opacity >= 1) {
        context.paintChild(kid, at);
      } else {
        context.pushOpacity(
          offset,
          Color.getAlphaFromOpacity(opacity),
          (c, o) => c.paintChild(kid, o + data.offset + data.shift),
        );
      }
    }
  }

  /// The groups [paint] paints [laid]'s ops in (see there): the ops of no
  /// faded, blended or moved box, in order, then each such box's group, in
  /// tree order, the same way inside it.
  static _PaintGroup _paintGroups(_Laid laid) {
    final chains = [for (final op in laid.ops) _groupChain(op.box)];
    _PaintGroup build(_Box? of, int depth, Iterable<int> ops) {
      final own = <int>[];
      final inner = <_Box, List<int>>{};
      for (final i in ops) {
        final chain = chains[i];
        if (chain.length == depth) {
          own.add(i);
        } else {
          (inner[chain[depth]] ??= []).add(i);
        }
      }
      final boxes = inner.keys.toList()..sort((a, b) => a.index.compareTo(b.index));
      return _PaintGroup(of, own, [for (final b in boxes) build(b, depth + 1, inner[b]!)]);
    }

    return build(null, 0, [for (var i = 0; i < laid.ops.length; i++) i]);
  }

  /// [_paintGroups] of the layout [laid], kept with it: a layout's boxes and
  /// ops are what a new layout, and nothing else, changes.
  (_Laid, _PaintGroup)? _groupsKept;
  _PaintGroup _groupsOf(_Laid laid) {
    if (_groupsKept case (final at, final groups) when identical(at, laid)) return groups;
    final groups = _paintGroups(laid);
    _groupsKept = (laid, groups);
    return groups;
  }

  /// The children in the order [paint] paints them, the first painted
  /// first: the atomic inlines and what is placed against the boxes in
  /// their groups' order ([_paintGroups]) -- a moved or faded box's after
  /// the rest, one faded to nothing where it would stand -- then what is
  /// placed against the boxes on no line. A child painted nowhere (hidden,
  /// or on no line) comes before them all, in the order the flow holds it.
  /// [hitTestChildren] asks them from the last: the one drawn on top takes
  /// the press.
  @override
  List<RenderBox> get paintOrder {
    final kids = _children;
    final laid = _laid;
    final painted = <RenderBox>[];
    if (laid != null) {
      void walk(_PaintGroup g) {
        for (final i in g.ops) {
          if (laid.ops[i] case _AtomOp(:final atom) when atom < kids.length) painted.add(kids[atom]);
        }
        g.inner.forEach(walk);
        final kid = g.box == null ? null : _placedKids?[g.box];
        if (kid != null) painted.add(kid);
      }

      walk(_groupsOf(laid));
      for (final (kid, _) in _orphans ?? const <(RenderBox, double)>[]) {
        painted.add(kid);
      }
    }
    final seen = painted.toSet();
    return [
      for (final k in kids)
        if (!seen.contains(k)) k,
      ...painted,
    ];
  }

  /// The faded, blended and moved boxes [b] is in, and those with something
  /// placed against them, [b] too, outermost first.
  static List<_Box> _groupChain(_Box b) {
    final out = <_Box>[];
    for (_Box? x = b; x != null; x = x.parent) {
      final n = x.node;
      if (n != null &&
          (n.opacity < 1 ||
              n.blendMode != BlendMode.srcOver ||
              n.offset != Offset.zero ||
              n.offsetShare != 0 ||
              n.placed != null)) {
        out.add(x);
      }
    }
    return out.reversed.toList();
  }

  /// A group at an alpha between none and all is a layer of its own.
  @override
  bool get alwaysNeedsCompositing => _fades(_content);

  static bool _fades(List<InlineNode> nodes) {
    for (final n in nodes) {
      if (n is InlineBox && ((n.opacity > 0 && n.opacity < 1) || _fades(n.children))) return true;
      if (n is InlineAtom && n.opacity > 0 && n.opacity < 1) return true;
    }
    return false;
  }

  /// The child painted on top takes the press: [paintOrder] asked from its
  /// last, a box moved over the one after it hit first, as it is drawn.
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final order = paintOrder;
    for (var i = order.length - 1; i >= 0; i--) {
      final kid = order[i];
      final data = kid.parentData! as InlineFlowParentData;
      if (!data.shown) continue;
      final hit = result.addWithPaintOffset(
        offset: data.offset + data.shift,
        position: position,
        hitTest: (r, transformed) => kid.hitTest(r, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final data = child.parentData! as InlineFlowParentData;
    final at = data.offset + data.shift;
    transform.translateByDouble(at.dx, at.dy, 0, 1);
  }

  String get _plainText {
    final b = StringBuffer();
    void walk(List<InlineNode> ns) {
      for (final n in ns) {
        switch (n) {
          case InlineText():
            b.write(n.text);
          case InlineBreak():
            b.write('\n');
          case InlineBox():
            walk(n.children);
          case InlineAtom() || InlineMark():
            break;
        }
      }
    }

    walk(_content);
    return b.toString().replaceAll(RegExp(r'[ \t\n\r\f]+'), ' ').trim();
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    final text = _plainText;
    if (text.isNotEmpty) {
      config
        ..label = text
        ..textDirection = _textDirection;
    }
  }

  @override
  void dispose() {
    _disposePainters();
    super.dispose();
  }
}
