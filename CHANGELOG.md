## 0.1.3

- A face that loads after text was laid out lays the text out again in the
  face, without the widget being mounted again, in `InlineFlow`,
  `FloatText` and `IndentedText`: an app that loads its fonts as it runs
  (`google_fonts`, a font fetched or read from a file, `FontLoader`) drew
  them in the fallback face's widths until the page was built anew, and a
  float that held one kept the fallback's width beside the floats around
  it. Each now relayouts when the system fonts change, as `RenderParagraph`
  does, and drops what it measured in the fallback (word widths, a
  paragraph measured whole, a style's extents). A face loaded before the
  first frame (an app's bundled fonts, which Flutter registers before
  `main`) changes nothing.
  Not fixed here, a Flutter gap (3.38 and 3.47): a `Text` whose width a box
  asks before laying it out -- a float, a flex item sized by its content,
  `IntrinsicWidth` -- keeps the fallback's width after the face loads,
  because `RenderParagraph.systemFontsDidChange` lays out its text again
  but not the painter its intrinsic widths and dry layout read.
- An intrinsic height is no less than the height the box lays out at, at
  the width it lays out at, under a parent that hands it no height
  (`test/intrinsic_height_asked_test.dart`, over every box that answers
  one). Three answered short, and an `IntrinsicHeight` or a row measured by
  its items handed the short answer back and overflowed:
  - `LineBox` round a line of nothing but atomic inlines on a forced strut
    answered the strut's line whatever stood on it, while laid out on a
    line of a fractional height it reads the line off the boxes Skia
    placed, which comes to more where a box reaches past the strut: an
    inline-block whose own text a larger text scale raises came to 31 on a
    25.59375px line and answered 25.6. Where a box reaches past the strut
    the line is now read the same way before layout, off a dry paragraph;
    where nothing does, it is the strut's line, as before.
  - `FixedWidth` asked in less room than its width answered at its own
    width, where it lays its child out at the room: its words came out on
    fewer lines than it drew them on. It is asked at the width it lays its
    child out at; in room as wide as it or wider, as before.
  - `ShrinkWidth` with a `roomFactor`, offered no height, asked its child
    how wide it is laid out with no bound on either axis, which a box of a
    ratio cannot be: `RenderAspectRatio` asserted in a debug build, and in
    release took the whole room. It lays the child out in the width it is
    offered instead: a child that takes all of it, as a ratio with no
    height to transfer does, is as wide as its content (css-sizing-4 5.1),
    what the intrinsic question answers; one short of it is the wider of
    the two, so words that wrap there keep their unwrapped width and a
    turned box (`RotatedBox`) under a height cap is as wide as the columns
    it sets at the cap, which the intrinsic question cannot see
    (`RenderConstrainedBox` asks what it holds at the height it is asked,
    not the one it caps). Offered a height, as before.
- `FloatSlot.frameShare` (new, optional): a padding written as a share of
  the containing block's width (CSS 2.1 8.4), which the `FloatFlow`'s pass
  resolves against the width it lays the child out in and adds to the
  child's `frame` -- the one width a float, laid out at a width of its own,
  is never handed. A share of a width still being worked out comes to
  nothing (css-sizing-3 5.2.1), as a `marginShare` does. For a child with
  nothing inside to place: a ratio spacer, an empty `float: left; width:
  1px; padding-bottom: 56.25%` held in by a clear after it, now holds its
  flow open at 16:9 of the flow's width at every width. Every existing call
  is unchanged.
- Every size and baseline a box of css_box's asks of what it holds before
  layout (intrinsic widths and heights, dry layout, dry baseline) is asked
  under Flutter's `debugCheckingIntrinsics` hatch where it may reach a box
  that answers nothing dry, on every Flutter: a `LayoutBuilder`, whatever
  it is asked, and a box with no dry baseline of its own (a picture, a
  flow, a rotated box, a scroll view, a viewport; on 3.38 an `Align` and an
  `AnimatedSize` too) asked a baseline. Such a box answers what a release
  build answers (no size, no baseline) where it threw in a debug build:
  a `LineBox` holding a stack on its baseline with a `LayoutBuilder` placed
  over it threw at its first layout on 3.38, and nothing under it was
  drawn. Release builds are unchanged, and so is every question that
  reaches no such box.

## 0.1.2

- A `BlockEllipsis` under a `LineClamp` that has been laid out answers a
  height asked before the clamp lays out again (intrinsic heights, dry
  layout) as the clamp will cut it, once the room it is asked in is not the
  one the clamp counted its lines in, or once anything under the clamp has
  changed (a text, a text scale, a style). It answered the budget the
  clamp's last layout told it: a title built at one line that a clamp of two
  let break into two lines once the text scale went from 1.3 to 2.0 answered
  its one line, and a grid of such cards sized its rows one line short and
  overflowed them until the page was laid out anew. Laid out and asked in
  the same room with nothing changed, a block answers as before.
  `RenderLineClamp.markNeedsLayout` only clears a flag.
- `LineBox` round a line of nothing but atomic inlines on a forced strut
  (`StrutStyle.forceStrutHeight`) answers the strut's line height and
  ascent when asked before layout (intrinsic heights, dry layout, dry
  baseline), as it is laid out: Skia sets the line at the strut whatever
  stands on it. It worked the line out of each box's own ascent and
  descent, which are Skia's unrounded ones where Blink rounds them, and a
  glyph at `vertical-align: -4px` on a 32px line answered 32.73 to an
  `IntrinsicHeight` round it. A strut that is a minimum is unchanged.
- New `OffsetSpan` and `OffsetSpans`: a run of text painted off its place
  on the line by `dx` and `dy`, as a relatively positioned inline box is
  (CSS 2.1 9.4.3, `position: relative` with `top`/`left`). The span lays
  out as the `TextSpan` it is, so the line keeps the place and no line
  grows; `OffsetSpans` round the paragraph paints it moved, each piece on
  its own line, and `FloatText` paints the pieces on its lines moved
  itself. A footnote mark at `top: -0.5em` on the baseline is drawn half
  an em up with the words round it where they were.
- New `SmallCapsSpan`: a `TextSpan` for `font-variant: small-caps` (and
  `petite-caps`, `all-small-caps`, `all-petite-caps`) in a face with no
  small capitals of its own. Each letter that changes when uppercased is
  drawn as its capital at `size`, the rest at the text's size; under `all`
  the whole run is small capitals (css-fonts-4 6.4, as a browser makes
  them up). Its `text` stays the string written, and reads back so:
  `SmallCapsSpan(text: 'oct 31, 2026', size: 11)` draws `OCT` at 11 and
  ` 31, 2026` at the paragraph's size.

## 0.1.1

- A vertical `FlexLine` handed no width of its own (fit-content) reads its
  items' `FlexCell.crossSizeFraction` against the width it comes to, where
  it read them as no size at all. The share counts as the item's content
  while the width is worked out (css-sizing-3 5.2.1), then the line is laid
  out again at that width: a `width: 90%` item of a 351-wide column is
  315.9 wide, and a column narrower than the room is its widest item's
  width, the share 90% of that. A line given its width is unchanged.
- `RatioBox` at an indefinite width is as wide as its content's max-content
  width, and as tall as that width gives through the ratio (css-sizing-3
  5.1), where it answered 0 tall. A `Column` measuring how wide the box
  wants to be asks it how tall it is with no width, then how wide at that
  height, so a picture at `width: 100%` with an `aspect-ratio` in a
  shrink-to-fit parent (`ShrinkWidth`, `IntrinsicWidth`) came out 0x0.
  Asked how wide at the height it comes to by itself, which states no height
  (css-sizing-4 5.2), it now answers its content's widths, not the ratio's:
  a percentage-width picture keeps no min-content (css-sizing-3 5.2.2), and
  its parent shrinks to the room instead of overflowing it. A height the
  box is given is still read through the ratio.
- `FractionalConstraints` asks its child how tall it is at the width the
  child is laid out at in the room, where it asked at the whole room. A
  picture of a stated width under `max-width: 100%` in a wider room stays
  its own width (CSS 2.1 10.4), but a `SizedBox` hands the width it is asked
  at on to the `AspectRatio` inside, so the picture answered the room's
  height: under an `IntrinsicHeight` it stood taller than it is. A child
  that fills its room (an `AspectRatio` of no width) is still asked at the
  room, and so is one that answers no width.
- `FloatText` sets a long paragraph in work that grows with its length when
  it is right to left, holds right-to-left letters or bidi controls, or has a
  letter or word spacing. Each of its lines was set from all the rest of the
  paragraph, so 4 times the words took 16 times the work. A paragraph set
  right to left, or holding right-to-left letters, is now read off a cut a
  little past the line, where a letter after the line settles the bidi levels
  (UAX #9). A spaced paragraph, or one with an embedding or an isolate, is
  laid out once at the line's width, and the lines after it are read off
  that layout until the width changes. Its lines break where they did.

## 0.1.0

First published version.

- Widgets for the CSS rules that Flutter's box protocol cannot state, each
  an ordinary `RenderBox` that answers Flutter's intrinsic, dry-layout and
  baseline questions:
  - lines and words: `LineBox` (and `LineBox.grown`, CSS 2.1 10.8),
    `Balance`, `Pretty`, `IndentedText`, `BlockEllipsis` (with
    `text-wrap: balance`/`pretty` under a clamp), `LineClamp`,
    `ClampedBlock`;
  - inline formatting: `InlineFlow`, `InlineFrame`, `InlineFrames`,
    `GlyphBackgrounds`;
  - baselines: `LastBaseline`, `EdgeBaseline`, `MiddleBaseline`,
    `TopBaseline`, `AlignBox`;
  - sizing: `ShrinkWidth`, `MinContentWidth`, `FixedWidth`, `KeywordClamp`,
    `Compressible`, `FractionalWidth`, `FractionalConstraints`,
    `FractionalHeight`, `FractionalMinHeight`, `LooseHeight`, `RatioBox`,
    `FloorBox`, `Inset`, `Spill`;
  - flex, grid, floats, tables and columns: `FlexLine`, `GapWrap`, `Tracks`,
    `FloatFlow`, `TableBox`, `TableCaptions`, `Layers`, `MultiColumn`
    (balanced columns with `orphans` and `widows`, css-multicol-1);
  - positioning, scrolling and clipping: `Sticky`, `SpotScope`, `SpotMark`,
    `SpotShift`, `SpotText`, `SpotArea`, `ClipBox`, `ScrollBox`,
    `DocumentExtent`;
  - painting: `Blend`, `TileMask`, `MaskLayers`, `PictureTile`, and the
    decorations and clippers (`OuterShadow`, `InnerShadow`, `DashedBorder`,
    `CornerShapeBorder`, `OutlineRing`, the gradient transforms, the
    `clip-path` shapes and others);
  - interaction: `PressWhereDrawn`.
- Text scaling: `FloatText` and `InlineFlow` scale their text by a
  `textScaler`, the ambient `MediaQuery.textScalerOf` where none is given,
  as `Text` does: the glyphs, the strut and every inline box's
  `InlineFont` together. Only text scales: an `InlineAtom`, or a
  `WidgetSpan` on a `FloatText`'s line, is laid out at its own size and
  the text in it scales once, by its own `Text` -- unlike `RichText`, which
  scales a `WidgetSpan`'s box as a whole and the text in it again.
  `TextScaler.noScaling` keeps a layout of fixed pixel metrics as written.
- Three libraries: `css_box.dart` (what a page uses), `rendering.dart` (the
  render objects and the dry-question protocols) and `bands.dart` (width
  bands), each showing its names by name; the helpers the package's own
  files share are `@internal` and in none of them.
- Tested on Flutter 3.38.5 (Dart 3.10.4) through 3.47.6, with
  `tool/test_range.sh`. The shadow cut is also tested in Chrome.
- An example app that shows every snippet of the README, and benchmarks for
  `Tracks`, `InlineFlow` and `FloatFlow` on large pages, and of how
  `FloatText` and `InlineFlow` scale with their content: a line of a
  `FloatText` is set from the words up to a cut not far past it, and an
  `InlineFlow` keeps the widths it measured for its last two contents,
  not all it ever held.
