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
