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
