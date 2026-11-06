# css_box

Layout widgets for the CSS rules that Flutter's box protocol cannot state.

Flutter lays out in one pass: a parent hands its child constraints, and the
child answers with a size. Most layouts fit that. Many that browsers do every
day do not:

- a word too wide for its line that overflows whole instead of breaking;
- a box as wide as its content, up to the room it has;
- a row of items that each shrink by how wide they want to be;
- items on tracks that are shared across rows;
- floats with text running round them;
- a paragraph whose inline boxes are boxes.

Each widget here states one such CSS rule. Each is an ordinary `RenderBox`
underneath. It answers the intrinsic, dry-layout and baseline questions that
Flutter's own boxes ask, so it composes with `Row`, `Column`, `Table`,
`IntrinsicWidth` and the rest, and its children can be any widgets.

css_box is not a CSS renderer and does not parse stylesheets. You write the
widgets yourself, or a generator writes them for you.

## Getting started

```yaml
dependencies:
  css_box: ^0.1.0
```

```dart
import 'package:css_box/css_box.dart';
```

css_box depends only on Flutter. It is tested on Flutter 3.38.5 (Dart 3.10.4)
through 3.47.6 on the VM, and in Chrome for the painting that differs on the
web. `tool/test_range.sh` runs the suite and the analyzer on both ends of that
range.

### Three libraries

| Library | What it holds |
| --- | --- |
| `package:css_box/css_box.dart` | The widgets, decorations, clippers, enums and value classes. A page needs only this one. |
| `package:css_box/rendering.dart` | The render objects behind the widgets (`Render*`, `*ParentData`), and the dry-question protocols (`AsksGuarded`, `ChildDryBaseline`, `DryLastBaseline`, `OneBaseline`, `dryBaselineOf`, `dryLastBaselineOf`). Use it for code that composes at the render layer. |
| `package:css_box/bands.dart` | Width bands (`context.band`, `context.widthFrom`, `context.widthBelow`, `context.wrap`) for a page that changes at window widths, as a stylesheet's media queries do. |

### How the boxes measure

Every box answers `getMinIntrinsicWidth`, `getMaxIntrinsicWidth`, the two
intrinsic heights, `getDryLayout` and `getDryBaseline` from its children, and
asks its children the same questions. Some Flutter boxes answer a dry
baseline only by asserting in a debug build: `Align` on Flutter 3.38, and on
3.41 through 3.47 a proxy over a box that has no baseline
([flutter#189711](https://github.com/flutter/flutter/issues/189711)). css_box
asks a question under Flutter's own `debugCheckingIntrinsics` guard only where
it can reach one of those boxes. Everywhere else it asks as a release build
asks, so the answers there are a release build's too. Release builds never use
the guard.

## Widgets

Each section names the CSS rule, says what Flutter cannot say about it, and
shows the widget in a short snippet. The snippets are the functions in
`example/lib/snippets.dart`, which the example's
tests compile and pump. The example app shows all of them in a gallery.

- [Lines and words](#lines-and-words): `LineBox`, `Balance`, `Pretty`,
  `IndentedText`, `BlockEllipsis`, `LineClamp`, `ClampedBlock`
- [Inline formatting](#inline-formatting): `InlineFlow`, `InlineFrame`,
  `InlineFrames`, `GlyphBackgrounds`
- [Baselines](#baselines): `LastBaseline`, `EdgeBaseline`, `MiddleBaseline`,
  `TopBaseline`, `AlignBox`
- [Sizing](#sizing): `ShrinkWidth`, `MinContentWidth`, `FixedWidth`,
  `KeywordClamp`, `Compressible`, `FractionalWidth`, `FractionalConstraints`,
  `FractionalHeight`, `FractionalMinHeight`, `LooseHeight`, `RatioBox`,
  `FloorBox`, `Inset`, `Spill`
- [Flex, grid, floats and tables](#flex-grid-floats-and-tables): `FlexLine`,
  `FlexCell`, `Tracks`, `TrackCell`, `FloatFlow`, `FloatSlot`, `FloatText`,
  `TableBox`, `TableSlot`, `TableBand`, `TableShift`, `TableCaptions`,
  `Layers`, `MultiColumn`
- [Positioning, scrolling and clipping](#positioning-scrolling-and-clipping):
  `Sticky`, `StickyBlock`, `StickyPort`, `SpotScope`, `SpotMark`, `SpotShift`,
  `SpotText`, `SpotArea`, `ClipBox`, `ScrollBox`, `DocumentExtent`,
  `FixedLayer`
- [Painting](#painting): `Blend`, `TileMask`, `MaskLayers`, `PictureTile`,
  and the decorations and clippers
- [Interaction](#interaction): `PressWhereDrawn`
- [Width bands](#width-bands): `bands.dart`

## Lines and words

### LineBox

**CSS:** css-text-3 §5.5 (`overflow-wrap: normal`) and §7.1. A word wider than
its line overflows the line's end edge. It is never broken inside.

**Flutter:** a paragraph laid out narrower than its longest word breaks that
word wherever it runs out of room. A 48px column that holds `Unbreakable word`
breaks the first word into pieces, where a browser draws two lines and lets
the first word hang past the edge. No constraint can say "report this width,
but lay the text out wider".

**Widget:** `LineBox` lays its paragraph out at the paragraph's min-content
width whenever the room is narrower, and still reports the room as its size.
It also keeps lines as tall as CSS makes them under a forced strut, on
Blink's 1/64px grid (`lineHeight`, `ascent`).

```dart
Widget lineBox() =>
    const SizedBox(width: 48, child: LineBox(child: Text('Unbreakable word')));
```

### Balance

**CSS:** css-text-4 `text-wrap-style: balance`. The lines are broken so that
none is much longer than another, and the line count stays the same.

**Flutter:** a paragraph is broken greedily, and the set of breaks that a
browser chooses is usually not a greedy one at any width. So no width you give
a `Text` reproduces it.

**Widget:** `Balance` searches the paragraph's break points, not widths, for
the set whose lines leave the least room over, summed as squares. The line
count never changes, so the block is exactly as tall as the greedy one.

```dart
Widget balance() =>
    const Balance(child: Text('The web framework for content-driven websites'));
```

### Pretty

**CSS:** css-text-4 `text-wrap-style: pretty`. The last line does not hold one
short word alone.

**Flutter:** a paragraph has no way to look back at its last lines.

**Widget:** `Pretty` re-breaks the last four lines as Blink does. This happens
when the last line holds one word narrower than a third of the room.

```dart
Widget pretty() => const Pretty(
  child: Text(
    'A paragraph set so that its last line never holds one short word alone.',
  ),
);
```

### IndentedText

**CSS:** css-text-3 §8.1 `text-indent`. The first line starts the indent in
from the start edge. A negative indent hangs the first line out of the edge.
A percentage is a share of the block's own width.

**Flutter:** a paragraph has one width for every line.

**Widget:** `IndentedText` sets the first line in its own room and the rest
under it, each broken where a browser breaks it. `share` is the percentage.

```dart
Widget indentedText() => Padding(
  padding: const EdgeInsets.only(left: 30),
  child: IndentedText(
    '※1 A note that hangs its mark in the padding and wraps under its words.',
    indent: -30,
  ),
);
```

### BlockEllipsis, LineClamp, ClampedBlock

**CSS:** css-overflow-4 `line-clamp` and `block-ellipsis`
(`-webkit-line-clamp`). The block is cut after its Nth line box. The ellipsis
goes where that line ends, wherever in the block's paragraphs the line falls.

**Flutter:** `maxLines` with `TextOverflow.ellipsis` lays the last line out as
if everything after it were on it, and cuts that off. So a summary ends
`link between GLP-1 w…` where Chrome ends it `link between GLP-1…`. And
`maxLines` counts the lines of one paragraph, not of a block.

**Widget:** `BlockEllipsis` cuts a paragraph where its `maxLines`th line ends
and puts the ellipsis there. `LineClamp` counts the line boxes through every
paragraph under it. Each `ClampedBlock` ends at the cut it holds.

```dart
Widget blockEllipsis() => const BlockEllipsis(
  child: Text(
    'A summary cut after its second line, with the ellipsis where that line ends.',
    maxLines: 2,
  ),
);
```

```dart
Widget lineClamp() => const LineClamp(
  lines: 3,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ClampedBlock(
        child: BlockEllipsis(child: Text('What is general fiction?')),
      ),
      ClampedBlock(
        child: BlockEllipsis(
          child: Text(
            'Stories of people and places that never were, told as if they had been.',
          ),
        ),
      ),
    ],
  ),
);
```

## Inline formatting

### InlineFlow

**CSS:** CSS 2.1 §9.4.2 and §10.8, css-text-3. This is one inline formatting
context:

- `white-space`, `word-break` and `overflow-wrap`, set per run;
- inline boxes that are one fragment on each line, framed round each fragment;
- `vertical-align` for each fragment, measured by what is on its line;
- `text-align`, `text-indent`, bidi reordering, and balanced and pretty
  wrapping.

**Flutter:** a `Text` stands every run on one baseline under one strut. A
`WidgetSpan` is one unbreakable piece. Nothing frames an inline box that a
line breaks inside, or moves each of its pieces off the baseline.

**Widget:** `InlineFlow` lays out `InlineText`, `InlineBox`, `InlineAtom`,
`InlineBreak` and `InlineMark` nodes the way a browser lays out a block's
lines. `InlineFont` is the box's font, as a line reads it.

```dart
Widget inlineFlow() => const InlineFlow(
  font: InlineFont(size: 14, ascent: 13, descent: 3, lineHeight: 20),
  children: [
    InlineText('Pick from the list '),
    InlineBox(
      padding: EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: Color(0xFFFFF3B0)),
      children: [InlineText('or type a name of your own')],
    ),
    InlineText(' and press '),
    InlineAtom(child: SizedBox.square(dimension: 14)),
  ],
);
```

### InlineFrame

**CSS:** CSS 2.1 §10.6.1 and §10.8.1. An inline box's padding and border take
room across, but no room down. They stand out over and under the font's
content area, and do not move the line.

**Flutter:** a `WidgetSpan` with padding is as tall as its padding, and the
line grows to fit it.

**Widget:** `InlineFrame` frames content that no line breaks: a chip, a badge,
a padded label. Its `margin` and `insets` take room across and none down, and
it paints its `decoration` round the content area that `ascent` and `descent`
give, out over the lines above and below.

```dart
Widget inlineFrame() => const Text.rich(
  TextSpan(
    children: [
      TextSpan(text: 'Tagged '),
      WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: InlineFrame(
          decoration: BoxDecoration(color: Color(0xFFE0E7FF)),
          insets: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          ascent: 11,
          descent: 3,
          child: Text('chip'),
        ),
      ),
    ],
  ),
);
```

### InlineFrames

**CSS:** css-break-3 §5.4, `box-decoration-break: slice`. An inline box that
a line breaks inside is one fragment on each line. It is painted as if the
fragments were set end to end and then cut apart.

**Flutter:** a `TextSpan` has a background colour, not a box. It has no
padding, border or radius, and nothing marks where one line's piece ends.

**Widget:** `InlineFrames` paints the frame of every `InlineFrameSpan` in the
paragraph under it, one fragment on each line, in the order a browser paints
them.

```dart
Widget inlineFrames() => const InlineFrames(
  child: Text.rich(
    TextSpan(
      children: [
        TextSpan(text: 'Status '),
        InlineFrameSpan(
          decoration: BoxDecoration(color: Color(0xFFFFE4E6)),
          insets: EdgeInsets.symmetric(horizontal: 4),
          ascent: 11,
          descent: 3,
          children: [TextSpan(text: 'pending review')],
        ),
        TextSpan(text: ' since Monday'),
      ],
    ),
  ),
);
```

### GlyphBackgrounds

**CSS:** css-backgrounds-4 §2.3, `background-clip: text`. An inline box's
background shows only inside its glyphs. A box broken over lines is laid out
as one strip (css-break-3 §5.4), so a gradient runs on from line to line.

**Flutter:** a `ShaderMask` covers a whole widget, not the pieces of a span
on each line.

**Widget:** `GlyphBackgrounds` paints each `GlyphBackgroundSpan`'s
background inside that span's own glyphs, under the text.

```dart
Widget glyphBackgrounds() => const GlyphBackgrounds(
  child: Text.rich(
    GlyphBackgroundSpan(
      background: LinearGradient(
        colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
      ),
      text: 'Gradient words',
      style: TextStyle(color: Color(0x00000000)),
    ),
  ),
);
```

## Baselines

### LastBaseline

**CSS:** CSS 2.1 §10.8.1. An inline-block's baseline is the baseline of its
last line box.

**Flutter:** every box answers with its first baseline. A `Column` asks its
first child, and a paragraph answers with its first line.

**Widget:** `LastBaseline` answers the baseline of the last line inside it,
laid out and dry.

```dart
Widget lastBaseline() => const Row(
  crossAxisAlignment: CrossAxisAlignment.baseline,
  textBaseline: TextBaseline.alphabetic,
  children: [
    Text('Total '),
    LastBaseline(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text('12 items'), Text('USD 48.00')],
      ),
    ),
  ],
);
```

### EdgeBaseline

**CSS:** css-align-3 §9.1. A box with no baseline of its own takes part in
baseline alignment by its bottom edge.

**Flutter:** a box with no text in it answers no baseline at all.

**Widget:** `EdgeBaseline` answers its child's baseline where the child has
one, and its bottom edge where it has none (or always, with `only`).

```dart
Widget edgeBaseline() => const Row(
  crossAxisAlignment: CrossAxisAlignment.baseline,
  textBaseline: TextBaseline.alphabetic,
  children: [
    Text('Share '),
    EdgeBaseline(
      child: SizedBox.square(
        dimension: 40,
        child: ColoredBox(color: Color(0xFF94A3B8)),
      ),
    ),
  ],
);
```

### MiddleBaseline, TopBaseline

**CSS:** CSS 2.1 §10.8.1, `vertical-align: middle` and `text-top`.

**Flutter:** `PlaceholderAlignment.middle` and `.top` place a box by the text
of the line it is on. CSS places it by the parent's baseline: its middle half
the parent's x-height over it, or its top at the parent's ascent.

**Widget:** `MiddleBaseline` answers a baseline at half its height and `over`
down. `TopBaseline` answers one at `at` down. A paragraph that stands its
placeholders on the baseline then puts the box where CSS puts it, whatever
its height.

```dart
Widget middleAndTopBaseline() => const Text.rich(
  TextSpan(
    children: [
      TextSpan(text: 'middle '),
      WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: MiddleBaseline(
          over: 4,
          child: SizedBox.square(
            dimension: 24,
            child: ColoredBox(color: Color(0xFF0EA5E9)),
          ),
        ),
      ),
      TextSpan(text: ' and text-top '),
      WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: TopBaseline(
          at: 11,
          child: SizedBox.square(
            dimension: 24,
            child: ColoredBox(color: Color(0xFFF97316)),
          ),
        ),
      ),
    ],
  ),
);
```

### AlignBox

**CSS:** css-align-3 §4.4 (`safe` alignment). It also gives an aligned box a
baseline.

**Flutter:** on Flutter 3.38 `Align` reports no dry baseline, and asking it
for one asserts in a debug build, which takes down every paragraph or flex
line that asks.

**Widget:** `AlignBox` is `Align` with a baseline, plus an `overflow` that lets
the child run past the box and `safeX` / `safeY` alignment.

```dart
Widget alignBox() => const Row(
  crossAxisAlignment: CrossAxisAlignment.baseline,
  textBaseline: TextBaseline.alphabetic,
  children: [
    Text('Label '),
    Expanded(
      child: AlignBox(
        alignment: Alignment.centerLeft,
        heightFactor: 2,
        child: Text('stands on the line'),
      ),
    ),
  ],
);
```

## Sizing

### ShrinkWidth

**CSS:** CSS 2.1 §10.3.5, shrink-to-fit:
`min(max(min-content, room), max-content)`. This is the width of a float, an
inline-block, or an item that a line does not stretch.

**Flutter:** a stretching `Column` takes all the room, and `IntrinsicWidth`
takes the content's width whatever the room is. Nothing narrows to the room
and stops at the content.

**Widget:** `ShrinkWidth` narrows when the room is tight and stops at its
content's width when the room is wide. It passes both intrinsic widths up
unchanged, so a line can still shrink it.

```dart
Widget shrinkWidth() => const ShrinkWidth(
  child: DecoratedBox(
    decoration: BoxDecoration(color: Color(0xFFE2E8F0)),
    child: Text('as wide as its words, up to the room it has'),
  ),
);
```

### MinContentWidth

**CSS:** css-sizing-3 §5.1, `width: min-content`.

**Flutter:** `IntrinsicWidth` is `max-content`, and `ShrinkWidth` is
`fit-content`. Nothing gives the third keyword.

**Widget:** `MinContentWidth` is as narrow as its longest unbreakable piece.

```dart
Widget minContentWidth() => const MinContentWidth(
  child: DecoratedBox(
    decoration: BoxDecoration(color: Color(0xFFE2E8F0)),
    child: Text('as narrow as its longest word'),
  ),
);
```

### FixedWidth

**CSS:** CSS 2.1 §10.2. A box with a stated width answers questions about its
height at that width.

**Flutter:** `SizedBox(width: 100)` passes the question's own width to its
child when asked for its intrinsic height. So a 100px column of text, asked
at 300, answers with one line.

**Widget:** `FixedWidth` asks its child at its own width.

```dart
Widget fixedWidth() => const IntrinsicHeight(
  child: FixedWidth(width: 100, child: Text('asked its height at 100 wide')),
);
```

### KeywordClamp

**CSS:** css-sizing-3 §5.1. `min-width` and `max-width` can be stated as
`min-content`, `max-content` or `fit-content`.

**Flutter:** `ConstrainedBox` takes numbers, and a keyword is not a number
until the child is measured.

**Widget:** `KeywordClamp` measures the child and applies the bound
(`ContentWidth.min`, `.max` or `.fit`) to the constraints it lays the child
out under.

```dart
Widget keywordClamp() => const KeywordClamp(
  floor: ContentWidth.min,
  ceiling: ContentWidth.max,
  child: Text('min-width: min-content; max-width: max-content'),
);
```

### Compressible

**CSS:** css-sizing-3 §5.2.1. In a replaced box (a picture) that is sized by a
percentage, the percentage resolves against zero for the box's min-content
contribution.

**Flutter:** an `Image` reports nothing until it has decoded, and its own
width after that. So a layout that asks it is a different layout before the
decode and after.

**Widget:** `Compressible` answers 0 for its min-content width and `natural`
for its max-content width, whatever the picture says.

```dart
Widget compressible() => const Row(
  children: [
    Expanded(
      child: Compressible(
        natural: 304,
        child: SizedBox(
          height: 80,
          child: ColoredBox(color: Color(0xFFCBD5E1)),
        ),
      ),
    ),
    Text('beside it'),
  ],
);
```

### FractionalWidth, FractionalConstraints

**CSS:** CSS 2.1 §10.2 and §10.4. A percentage width against a containing
block with no definite width resolves as `auto`. A percentage `min-width` or
`max-width`, with a `calc()` offset, resolves at layout.

**Flutter:** `FractionallySizedBox` measured at an unbounded width hands its
child a tight width of `infinity * factor`. `ConstrainedBox` takes only
numbers.

**Widget:** `FractionalWidth` gives its child a share of the room, and
`auto` where there is no room to take a share of. `FractionalConstraints`
puts a floor and a cap on the width, each a share plus an offset.

```dart
Widget fractionalWidth() => const FractionalConstraints(
  maxFactor: 1,
  maxOffset: -32,
  child: FractionalWidth(
    factor: 0.5,
    child: Text('half the room, and no wider than the room less 32'),
  ),
);
```

### FractionalHeight, FractionalMinHeight, LooseHeight

**CSS:** CSS 2.1 §10.5 and §10.7. A percentage `height` or `min-height` is a
share of an offered height, and `auto` where none is offered.

**Flutter:** the same infinite share as with the width. Also, a flex line
hands a stretched item a tight height that reaches its content.

**Widget:** `FractionalHeight` and `FractionalMinHeight` take their share of
the height they are offered. `LooseHeight` passes on the room it was given
without the obligation to fill it.

```dart
Widget fractionalHeight() => const SizedBox(
  height: 120,
  child: Row(
    children: [
      Expanded(
        child: FractionalHeight(
          factor: 0.5,
          child: ColoredBox(color: Color(0xFFBFDBFE)),
        ),
      ),
      Expanded(
        child: FractionalMinHeight(
          factor: 0.25,
          child: ColoredBox(
            color: Color(0xFFBBF7D0),
            child: Text('at least a quarter'),
          ),
        ),
      ),
      Expanded(
        child: LooseHeight(
          child: ColoredBox(
            color: Color(0xFFFDE68A),
            child: Text('as tall as its text'),
          ),
        ),
      ),
    ],
  ),
);
```

### RatioBox

**CSS:** css-sizing-4 §4.3. A box with a preferred aspect ratio is never
shorter than its min-content height on the axis that the ratio sets.

**Flutter:** `AspectRatio` is only the first half. A card at `aspect-ratio: 2`
that holds a 100px child comes out 60 tall where CSS makes it 100, and the
card spills into the row below.

**Widget:** `RatioBox` is as tall as its ratio says, and no shorter than its
content. It answers the same height to the flex line or grid track that asks.

```dart
Widget ratioBox() => const SizedBox(
  width: 120,
  child: RatioBox(
    aspectRatio: 2,
    child: Text('aspect-ratio: 2, and never shorter than its content'),
  ),
);
```

### FloorBox

**CSS:** CSS 2.1 §8.3.1 and §10.7. A last child's bottom margin collapses
through the end of a box of `auto` height, unless the box's `min-height`
binds.

**Flutter:** margins never collapse.

**Widget:** `FloorBox` is the box at its content height or at `floor`,
whichever is taller. Where the floor binds, it stands `margin` shorter, so the
flow's margin after it lands where Chrome puts it.

```dart
Widget floorBox() => const FloorBox(
  floor: 120,
  margin: 16,
  child: Text('min-height: 120px over a 16px bottom margin'),
);
```

### Inset

**CSS:** CSS 2.1 §8.3, negative margins. A box that takes less room than its
content makes what follows it overlap it.

**Flutter:** `Padding` asserts that its insets are not negative. `Transform`
moves paint and not the box, and `Align`'s factors are multiplicative.

**Widget:** `Inset` is `Padding` that allows negative insets. The child is
laid out with more room than the box, and the box reports less.

```dart
Widget inset() => const Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    SizedBox(height: 60, child: ColoredBox(color: Color(0xFF1E293B))),
    Inset(
      insets: EdgeInsets.only(top: -24, left: 16, right: 16),
      child: SizedBox(height: 80, child: ColoredBox(color: Color(0xFFFDE68A))),
    ),
  ],
);
```

### Spill

**CSS:** CSS 2.1 §11.1.1, `overflow: visible`. The box is the size the room
says, and its content is the size the content says, painted past the edge.

**Flutter:** a child is never given more room than its parent has. A `Column`
under content taller than the window paints a striped overflow band.

**Widget:** `Spill` gives its child no ceiling on `axis`, reports the size the
room gives it, and paints the child wherever that leaves it.

```dart
Widget spill() => const SizedBox(
  height: 60,
  child: Spill(
    axis: Axis.vertical,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 100, child: ColoredBox(color: Color(0xFFFECACA))),
      ],
    ),
  ),
);
```

## Flex, grid, floats and tables

### FlexLine, FlexCell

**CSS:** css-flexbox-1 §9. Each item shrinks by `flex-shrink` times its base
size (§9.7). Each item stops shrinking at its min-content size, its automatic
minimum (§4.5). Margins can be `auto`, items can wrap, and `align-content`
places the lines.

**Flutter:** `Flexible` shares out what is left over, by factors written
before anything is measured. It has no floor, so it crushes the longest word.

**Widget:** `FlexLine` lays out its `FlexCell`s as a CSS flex line does,
through Flutter's own intrinsic and dry-layout questions.

```dart
Widget flexLine() => const FlexLine(
  spacing: 12,
  children: [
    FlexCell(child: Text('a headline that gives up room grudgingly')),
    FlexCell(
      shrink: 3,
      child: Text('a caption that gives up three times as much'),
    ),
    FlexCell(shrink: 0, child: Icon(Icons.chevron_right)),
  ],
);
```

### Tracks, TrackCell

**CSS:** css-grid-1. Placement follows §8.5, including `dense`, and track
sizing follows §11 (fixed, `fr`, `minmax()`, `min-content`, `max-content`,
`fit-content()`, `repeat()`). It covers spans, gaps, and content and item
alignment.

**Flutter:** nothing sizes a track from items in other rows. `Table` has no
spans and no `fr` columns, and `GridView` scrolls and makes every cell alike.

**Widget:** `Tracks` is a grid. A child in a `TrackCell` says where it goes
and what box it asks for. Any other child is placed in flow order, `dense` or
not.

```dart
Widget tracks() => const Tracks(
  columns: [TrackSize.auto, TrackSize.flex(1), TrackSize.fixed(64)],
  spacing: 16,
  runSpacing: 8,
  children: [
    TrackCell(columnSpan: 3, child: Text('A header across all three tracks')),
    Text('Name'),
    Text('A column as wide as the widest item in it'),
    Text('64px'),
    Text('A longer name'),
    Text('shares what is left'),
    Text('64px'),
  ],
);
```

### FloatFlow, FloatSlot, FloatText

**CSS:** CSS 2.1 §9.5 (floats), §9.5.2 (`clear`), §9.4.1 (block formatting
contexts) and §8.3.1 (collapsing margins).

**Flutter:** a `Column` cannot take a child out of the stack. It adds margins
that CSS collapses, and nothing in it shortens the lines of a paragraph beside
a float.

**Widget:** `FloatFlow` is a block formatting context. A `FloatSlot` floats a
child left or right, clears it, or makes it a context of its own. A
`FloatText` paragraph is set a line at a time in the room each line has beside
the floats.

```dart
Widget floatFlow() => const FloatFlow(
  children: [
    FloatSlot(
      float: FloatSide.left,
      width: 80,
      height: 60,
      margin: EdgeInsets.only(right: 8),
      child: ColoredBox(color: Color(0xFFBAE6FD)),
    ),
    FloatText(
      TextSpan(
        text:
            'The lines of this paragraph shorten beside the float, '
            'and run the full width again below it.',
      ),
    ),
  ],
);
```

### TableBox, TableSlot, TableBand, TableShift

**CSS:** CSS 2.1 §17. It covers the automatic and fixed table layouts
(§17.5.2), cells that span rows and columns, `border-spacing`, and the
backgrounds of rows, row groups and columns. Cell content is aligned at the
top, middle, bottom or on the row's shared baseline (§17.5.3).

**Flutter:** `Table` has no spans. Its rows cannot align cells on a shared
baseline while the cells still fill the row.

**Widget:** `TableBox` is the grid. A `TableSlot` is a cell that fills its
slot, and its `TableShift` is the content that the row's alignment moves. A
`TableBand` is a row's or a column's background.

```dart
Widget tableBox() => const TableBox(
  spacing: Size(8, 4),
  children: [
    TableBand(row: 0, rows: 1, child: ColoredBox(color: Color(0xFFF1F5F9))),
    TableSlot(row: 0, column: 0, child: TableShift(child: Text('Plan'))),
    TableSlot(
      row: 0,
      column: 1,
      child: TableShift(child: Text('Price a month')),
    ),
    TableSlot(row: 1, column: 0, child: TableShift(child: Text('Pro'))),
    TableSlot(
      row: 1,
      column: 1,
      align: TableAlign.middle,
      child: TableShift(child: Text('12')),
    ),
  ],
);
```

### TableCaptions

**CSS:** CSS 2.1 §17.4 and css-tables-3. Captions go above or below the table
box, and the wrapper is as wide as the widest caption's min-content width.

**Widget:** `TableCaptions` is the table wrapper box.

```dart
Widget tableCaptions() => TableCaptions(
  above: const [Text('Plans and prices, a caption wider than its table')],
  table: const TableBox(
    children: [
      TableSlot(row: 0, column: 0, child: TableShift(child: Text('Pro'))),
      TableSlot(row: 0, column: 1, child: TableShift(child: Text('12'))),
    ],
  ),
);
```

### Layers

**CSS:** CSS 2.1 Appendix E. A `z-index` paints a box over the siblings after
it, including what it paints past its own edge.

**Flutter:** a `Column` paints in document order.

**Widget:** `Layers` is a `Flex` that paints, and hit-tests, its children by
`z`.

```dart
Widget layers() => const Layers(
  direction: Axis.vertical,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  z: [1, 0],
  children: [
    SizedBox(height: 40, child: ColoredBox(color: Color(0xFF1E293B))),
    SizedBox(height: 60, child: ColoredBox(color: Color(0xFFF8FAFC))),
  ],
);
```

### MultiColumn

**CSS:** css-multicol-1. `column-count` and `column-width` cut a block's flow
into columns side by side, balanced: as short as they can be with the flow
in them. A piece the browser never cuts (css-break-3 §4.4) -- a line box, a
replaced box, a scroll container -- stands whole in one column; a break
leaves `orphans` and `widows` lines of a paragraph on either side where it
can, and a margin at a break is truncated.

**Flutter:** a `Column` is one column, and no widget measures its children
before it chooses where to cut them.

**Widget:** `MultiColumn` lays each child out at the column's width, kept
whole, and balances the columns the way Blink does: a first guess of the
flow's height over the count, grown by the least shortage until the pieces
fit. `MultiColumn.lines` is a flow whose children are the lines of one
paragraph.

```dart
Widget multiColumn() => const MultiColumn(
  count: 2,
  gap: 8,
  spaces: [0, 12, 12],
  children: [
    SizedBox(height: 80, child: ColoredBox(color: Color(0xFF1E293B))),
    SizedBox(height: 40, child: ColoredBox(color: Color(0xFF64748B))),
    SizedBox(height: 40, child: ColoredBox(color: Color(0xFFCBD5E1))),
  ],
);
```

## Positioning, scrolling and clipping

### Sticky, StickyBlock, StickyPort

**CSS:** css-position-3 §3.4, `position: sticky`. The box is laid out in flow
and drawn shifted to stay inside its scrollport's edges, moved in by its
insets, and never out of its containing block.

**Flutter:** sliver headers are slivers, not boxes in a column.

**Widget:** a `Sticky` box is held to the nearest `StickyPort` or viewport,
and capped by the nearest `StickyBlock`. It is hit where it is drawn.

```dart
Widget sticky() => SizedBox(
  height: 160,
  child: SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final section in ['A', 'B', 'C'])
          StickyBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Sticky(top: 0, child: Text('Section $section')),
                const SizedBox(height: 160),
              ],
            ),
          ),
      ],
    ),
  ),
);
```

### SpotScope, SpotMark, SpotShift

**CSS:** CSS 2.1 §10.3.7 and §10.6.4, the static position. An absolutely
positioned box with an `auto` inset is placed where the flow would have put
it.

**Flutter:** a `Positioned` child of a `Stack` knows nothing about where the
flow left off.

**Widget:** a `SpotMark` is a box of no size in the flow. A `SpotShift` inside
a `Positioned` moves its child to where the mark ended up, on the axes that
the insets leave to the flow. `SpotScope` holds the marks of one containing
block.

```dart
Widget spotMark() => const SpotScope(
  child: Stack(
    clipBehavior: Clip.none,
    fit: StackFit.passthrough,
    children: [
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('The flow before the box'),
          SpotMark(id: 0),
          Text('and the flow after it'),
        ],
      ),
      Positioned(left: 0, top: 0, child: SpotShift(id: 0, child: Text('*'))),
    ],
  ),
);
```

### SpotText

**CSS:** the static position of a box that was taken out of a line between two
letters that no line breaks between (CSS 2.1 §9.3).

**Flutter:** a placeholder breaks the line before and after it.

**Widget:** a `SpotSpan` in a paragraph holds no text, so it breaks nothing.
The `SpotText` round the paragraph reads the point off the paragraph's own
layout.

```dart
Widget spotText() => const SpotScope(
  child: Stack(
    clipBehavior: Clip.none,
    fit: StackFit.passthrough,
    children: [
      SpotText(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'ab'),
              SpotSpan(id: 0),
              TextSpan(text: 'cd'),
            ],
          ),
        ),
      ),
      Positioned(left: 0, top: 0, child: SpotShift(id: 0, child: Text('^'))),
    ],
  ),
);
```

### SpotArea

**CSS:** css-flexbox-1 §4.1. An out-of-flow child of a flex container is
placed in the container's content box, as if it were the only item.

**Widget:** `SpotArea` marks that rectangle, and the `SpotShift` reads both its
corner and its size.

```dart
Widget spotArea() => const SpotScope(
  child: Stack(
    clipBehavior: Clip.none,
    fit: StackFit.passthrough,
    children: [
      Padding(
        padding: EdgeInsets.all(16),
        child: SpotArea(id: 1, child: SizedBox(height: 60)),
      ),
      Positioned(
        left: 0,
        top: 0,
        right: 0,
        bottom: 0,
        child: SpotShift(
          id: 1,
          across: true,
          child: Text('where the area starts'),
        ),
      ),
    ],
  ),
);
```

### ClipBox

**CSS:** css-overflow-3 §3. `overflow-x` and `overflow-y` clip each axis on
its own, and a box that clips has an automatic minimum size of zero
(css-grid-1 §6.6, css-flexbox-1 §4.5).

**Flutter:** a clip passes its child's intrinsic sizes up unchanged. A strip
of cards in a 358px scroller then sizes the page round it at 1594px.

**Widget:** `ClipBox` clips on the axes you name and reports a zero floor
there. With `scrollsHorizontally` or `scrollsVertically`, it scrolls what it
cuts.

```dart
Widget clipBox() => const SizedBox(
  width: 120,
  child: ClipBox(
    vertical: false,
    child: Text('cut across, and as tall as its lines', softWrap: false),
  ),
);
```

### ScrollBox

**CSS:** css-overflow-3 §3.1, `overflow: auto | scroll`. A scroll container's
content is laid out at the box's size, and the box scrolls over the furthest
edge anything inside it reaches.

**Flutter:** a scrollable lays its content out unbounded on its axis and
scrolls over the child's size, not over what hangs out of it.

**Widget:** `ScrollBox` is what `ClipBox` builds when it scrolls.

```dart
Widget scrollBox() => SizedBox(
  height: 100,
  child: ScrollBox(
    vertical: true,
    child: Spill(
      axis: Axis.vertical,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [for (var i = 0; i < 12; i++) Text('Row $i')],
      ),
    ),
  ),
);
```

### DocumentExtent, FixedLayer

**CSS:** css-overflow-3 §2.2 and css-position-3 §3.3. A document scrolls over
every box in it, not over the root's box alone. A `position: fixed` layer
never scrolls.

**Flutter:** `SingleChildScrollView` scrolls over its child's size.

**Widget:** `DocumentExtent` is as tall as the furthest bottom edge of
anything laid out inside it. `FixedLayer` marks a layer that it does not look
inside.

```dart
Widget documentExtent() => const SizedBox(
  height: 120,
  child: SingleChildScrollView(
    child: DocumentExtent(
      child: SizedBox(
        height: 60,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          maxHeight: 300,
          child: ColoredBox(color: Color(0xFFE0F2FE)),
        ),
      ),
    ),
  ),
);
```

## Painting

### Blend

**CSS:** compositing-1 §5.1, `mix-blend-mode`, with the box's opacity in the
same group (§3.3).

**Flutter:** no layer blends a box into what is already painted.

**Widget:** `Blend` paints its child in a layer restored with `mode` and
`opacity`.

```dart
Widget blend() => const Stack(
  children: [
    SizedBox(
      width: 120,
      height: 60,
      child: ColoredBox(color: Color(0xFF38BDF8)),
    ),
    Positioned(
      left: 40,
      top: 20,
      child: Blend(
        mode: BlendMode.multiply,
        child: SizedBox(
          width: 80,
          height: 40,
          child: ColoredBox(color: Color(0xFFF59E0B)),
        ),
      ),
    ),
  ],
);
```

### TileMask

**CSS:** css-masking-1 §7.6 and §7.7. A `mask-image` is laid out as a
background is: a tile, repeated.

**Flutter:** a `ShaderMask` takes one shader over the whole box, and no
gradient shader repeats on a grid.

**Widget:** `TileMask` rasterises the tile once, as Chrome does, and repeats
it pixel for pixel.

```dart
Widget tileMask() => const TileMask(
  gradient: RadialGradient(
    colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
    stops: [0.4, 0.4],
  ),
  width: 5,
  height: 5,
  child: SizedBox(height: 60, child: ColoredBox(color: Color(0xFF6366F1))),
);
```

### MaskLayers

**CSS:** css-masking-1 §7.9. A mask of several layers, each laid out as a
background and composited with `mask-composite`.

**Widget:** `MaskLayers` draws its `MaskLayer`s into one picture and keeps
the box through it.

```dart
Widget maskLayers() => const MaskLayers(
  layers: [
    MaskLayer(
      gradient: LinearGradient(colors: [Color(0xFF000000), Color(0x00000000)]),
    ),
  ],
  child: SizedBox(height: 60, child: ColoredBox(color: Color(0xFF0EA5E9))),
);
```

### PictureTile

**CSS:** css-backgrounds-3 §3.4 and §3.9. A `background-image` is drawn at a
tile size and repeated, `round`, or `space`. With a colour, it is a
`mask-image`.

**Flutter:** `DecorationImage` repeats an `ImageProvider`, and a vector
picture is a widget.

**Widget:** `PictureTile` paints its child once into a tile and repeats the
tile over the box.

```dart
Widget pictureTile() => const SizedBox(
  height: 60,
  child: PictureTile(
    width: 8,
    height: 8,
    child: Center(
      child: SizedBox.square(
        dimension: 2,
        child: ColoredBox(color: Color(0xFF64748B)),
      ),
    ),
  ),
);
```

### Decorations and clippers

These are not widgets. They are the decorations, borders, gradient
transforms, clippers and values that Flutter's own widgets take.

| Class | CSS | What Flutter's own cannot say |
| --- | --- | --- |
| `OuterShadow` | css-backgrounds-3 §7.1.1 | A `box-shadow` cut out of the box, so a box with no background is not in its own shade. |
| `InnerShadow` | css-backgrounds-3 §7.1.1 | An `inset` shadow inside the padding edge. |
| `DashedBorder` | css-backgrounds-3 §4.2 | `dashed` and `dotted` sides, laid out as Blink lays them out. |
| `MiteredBorder` | css-backgrounds-3 §5.5 | Rounded corners between sides of different colours or widths. |
| `CornerShapeBorder` | css-borders-4 §3.7 | `corner-shape: superellipse()`, `bevel`, `scoop` and `notch`. |
| `PercentCornerBorder`, `FractionalRadius`, `PaddingEdgeClip` | css-backgrounds-3 §5.1 and §5.2 | `border-radius` as percentages, and the padding edge inside them. |
| `OutlineRing` | css-ui-4 §4 | An `outline` with `outline-offset`, outside the border edge. |
| `GradientAngle`, `GradientStripe`, `GradientOval` | css-images-3 §3 | Gradient angles and `repeating-*` gradients at any box size, and `radial-gradient()` shapes. |
| `LengthStopsGradient`, `LengthStopsRadialGradient` | css-images-3 §3.5.1 | Stops in px, such as `black 160px`. |
| `GradientBand` | css-backgrounds-3 §3.7 and §3.9 | A background layer that is a band. |
| `ColorMatrix` | filter-effects-1 §13.1 | `grayscale()`, `sepia()`, `contrast()` and the others, chained. |
| `InsetClip`, `RoundInsetClip` | css-masking-1 §5.1, css-shapes-1 §3.1.1 | `clip-path: inset()`, including negative insets and share corners. |
| `CircleClip`, `EllipseClip`, `PolygonClip`, `ClipPoint` | css-shapes-1 §3.1 | `circle()`, `ellipse()` and `polygon()`, in px plus shares of the box. |
| `RingClip` | css-masking-1 §7.9 | The ring between two box edges. |

```dart
Widget shadows() => const Row(
  children: [
    DecoratedBox(
      decoration: OuterShadow(
        shadows: [
          BoxShadow(
            color: Color(0x40000000),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: SizedBox(width: 120, height: 60),
    ),
    SizedBox(width: 24),
    DecoratedBox(
      decoration: InnerShadow(
        shadows: [BoxShadow(color: Color(0xFF2563EB), offset: Offset(0, -2))],
      ),
      child: SizedBox(
        width: 120,
        height: 40,
        child: Center(child: Text('Tab')),
      ),
    ),
  ],
);
```

```dart
Widget borders() => const Row(
  children: [
    DecoratedBox(
      decoration: BoxDecoration(
        border: DashedBorder.fromBorderSide(
          BorderSide(color: Color(0xFF475569)),
        ),
      ),
      child: SizedBox(width: 80, height: 40),
    ),
    SizedBox(width: 16),
    DecoratedBox(
      decoration: ShapeDecoration(
        color: Color(0xFFF472B6),
        shape: CornerShapeBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
          curvature: 2,
        ),
      ),
      child: SizedBox.square(dimension: 60),
    ),
    SizedBox(width: 16),
    DecoratedBox(
      decoration: OutlineRing(
        color: Color(0xFF2563EB),
        width: 1,
        offset: 4,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: SizedBox(width: 80, height: 40),
    ),
  ],
);
```

```dart
Widget gradients() => const Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
          transform: GradientAngle(135),
        ),
      ),
      child: SizedBox(height: 40),
    ),
    DecoratedBox(
      decoration: BoxDecoration(
        gradient: LengthStopsGradient(
          colors: [
            Color(0x00000000),
            Color(0xFF000000),
            Color(0xFF000000),
            Color(0x00000000),
          ],
          stops: [0, 0, 1, 1],
          lengths: [0, 40, -40, 0],
        ),
      ),
      child: SizedBox(height: 20),
    ),
  ],
);
```

```dart
Widget clips() => Row(
  children: [
    ClipPath(
      clipper: const CircleClip(radiusShare: 0.5),
      child: Container(width: 60, height: 60, color: const Color(0xFF10B981)),
    ),
    const SizedBox(width: 16),
    ClipPath(
      clipper: const PolygonClip([
        ClipPoint(),
        ClipPoint(yShare: 1),
        ClipPoint(xShare: 1),
      ]),
      child: Container(width: 60, height: 60, color: const Color(0xFFF43F5E)),
    ),
    const SizedBox(width: 16),
    ClipRRect(
      clipper: const RoundInsetClip(
        share: EdgeInsets.all(0.1),
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Container(width: 60, height: 60, color: const Color(0xFF8B5CF6)),
    ),
  ],
);
```

The outer shadow's cut is the same on every renderer. On the web, every
shadow is cut by an even-odd path, because `Path.combine` did not cut the hole
there. `test/shadow_cut_parity_test.dart` reads the same pixels on the VM and
in Chrome.

## Interaction

### PressWhereDrawn

**CSS:** CSS 2.1 Appendix E. A press lands on the box painted last at the
point.

**Flutter:** a box hit-tests only inside itself. So a control that hangs out
of the box round it (a bar at the foot of a box of no height, a dialog moved
to the middle of the window) is not pressed, and the press lands on what is
drawn under it.

**Widget:** `PressWhereDrawn` goes round a screen. A press then also asks
each control in the screen (a gesture detector, a text field, a link in a
paragraph) whether it is drawn at the point and not cut there by a clip. Of
those, the control painted last takes the press.

```dart
Widget pressWhereDrawn() => PressWhereDrawn(
  child: SizedBox(
    height: 0,
    child: OverflowBox(
      alignment: Alignment.topLeft,
      maxHeight: 40,
      child: GestureDetector(
        onTap: () => debugPrint('pressed where it is drawn'),
        child: const SizedBox(
          width: 160,
          height: 40,
          child: ColoredBox(color: Color(0xFF22C55E)),
        ),
      ),
    ),
  ),
);
```

## Width bands

**CSS:** mediaqueries-4 `min-width`. A page is a different page on each side
of a breakpoint.

`package:css_box/bands.dart` picks a value by the window's width: a band is
keyed by its least width, as `(min-width: 768px)` is.

```dart
Widget widthBands() => Builder(
  builder: (context) => Padding(
    padding: context.band({
      0: const EdgeInsets.all(12),
      768: const EdgeInsets.all(24),
    }),
    child: context.widthFrom(768)
        ? const Text('a row of links')
        : const Text('a menu button'),
  ),
);
```

## Testing and benchmarks

- `flutter test` runs the suite (synthetic tests, with numbers checked
  against Chrome where the comments say so).
- `tool/test_range.sh` runs the suite, the analyzer, the example's tests and
  the web parity tests on each end of the supported Flutter range.
- `benchmark/` holds large pages of `Tracks`, `InlineFlow` and `FloatFlow`,
  timed beside the stock widgets' pages of the same content. See
  `benchmark/README.md`.

## License

css_box is under the BSD 3-Clause license (`LICENSE`). `Tracks` and
`FloatFlow` port Taffy's grid, block and float layout (MIT), and `InlineFlow`
ports Blink's balanced and pretty line breakers (Chromium, BSD 3-Clause).
`NOTICES` holds those notices. Flutter collects `NOTICES` into an app's
license page. The test fonts (`test/fonts`) are under the SIL Open Font
License 1.1.
