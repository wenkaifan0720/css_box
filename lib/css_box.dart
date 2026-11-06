/// Layout widgets for the sizes Flutter's own cannot express.
///
/// Flutter's box protocol is one pass: a parent hands down constraints and
/// a child answers with a size. That is enough for most layouts and not
/// for many that browsers do routinely -- a word too wide for its line
/// that overflows whole, a box as wide as its content up to the room it
/// has, a row of items that shrink by how wide they want to be, items on
/// tracks shared across rows, floats with text running round them, a
/// paragraph whose inline boxes are boxes. Each widget here is one CSS
/// rule Flutter's own widgets cannot state, and each is an ordinary
/// `RenderBox` underneath: it answers the intrinsic, dry-layout and
/// baseline questions Flutter's own boxes ask, so it composes with them.
///
/// Nothing here is a CSS renderer and nothing here parses a stylesheet.
///
/// The render objects behind these widgets, and what a render object needs
/// to sit inside one or to host one, are `package:css_box/rendering.dart`.
library;

export 'src/align.dart' show AlignBox;
export 'src/balance.dart' show Balance;
export 'src/press_where_drawn.dart' show PressWhereDrawn;
export 'src/pretty.dart' show Pretty;
export 'src/blend.dart' show Blend, CanvasFiltered;
export 'src/clamp.dart' show ContentWidth, KeywordClamp;
export 'src/baseline.dart' show EdgeBaseline, LastBaseline, MiddleBaseline, TopBaseline;
export 'src/clip.dart' show ClipBox, InsetClip, RoundInsetClip;
export 'src/compressible.dart' show Compressible;
export 'src/content.dart' show FixedWidth, MinContentWidth;
export 'src/corner.dart' show CornerShapeBorder;
export 'src/dashed.dart' show DashedBorder;
export 'src/edges.dart' show AutoEdges;
export 'src/edge_span.dart' show edgeSpan, indentSpan;
export 'src/ellipsis.dart' show BlockEllipsis, ClampedBlock, LineClamp;
export 'src/extent.dart' show DocumentExtent, FixedLayer;
export 'src/filter.dart' show ColorMatrix;
export 'src/inset.dart' show Inset;
export 'src/layers.dart' show Layers;
export 'src/outline.dart' show OutlineRing;
export 'src/percent_corner.dart' show FractionalRadius, PaddingEdgeClip, PercentCornerBorder;
export 'src/linebox.dart' show GrownLine, LineBox;
export 'src/mitered.dart' show MiteredBorder;
export 'src/multi_column.dart' show MultiColumn;
export 'src/flex_line.dart' show FlexCell, FlexKeyword, FlexLine;
export 'src/float_flow.dart' show FloatClear, FloatFlow, FloatSide, FloatSlot, FloatText, FloatWidth;
export 'src/floor.dart' show FloorBox;
export 'src/fraction.dart'
    show FractionalConstraints, FractionalHeight, FractionalMinHeight, FractionalWidth, LooseHeight;
export 'src/gradient.dart'
    show
        GradientAngle,
        GradientBand,
        GradientOval,
        GradientStripe,
        LengthStopsGradient,
        LengthStopsRadialGradient,
        OvalExtent;
export 'src/gap_wrap.dart' show GapWrap;
export 'src/glyph_background.dart' show GlyphBackgroundSpan, GlyphBackgrounds;
export 'src/han.dart' show han;
export 'src/indent.dart' show IndentedText;
export 'src/inline_frame.dart' show InlineFrame;
export 'src/inline_frames.dart' show InlineFrameSpan, InlineFrames;
export 'src/inline_flow.dart'
    show
        InlineAtom,
        InlineBox,
        InlineBreak,
        InlineFlow,
        InlineFont,
        InlineMark,
        InlineNode,
        InlineText,
        OverflowWrap,
        TextWrapStyle,
        VerticalAlign,
        VerticalAlignKeyword,
        WhiteSpace,
        WordBreak;
export 'src/tile_mask.dart' show TileMask;
export 'src/picture_tile.dart' show PictureTile;
export 'src/mask_layers.dart' show MaskLayer, MaskLayers;
export 'src/ratio.dart' show RatioBox;
export 'src/scroll.dart' show ScrollBox;
export 'src/shadow.dart' show InnerShadow, OuterShadow;
export 'src/shape_clip.dart' show CircleClip, ClipPoint, EllipseClip, PolygonClip, RingClip;
export 'src/shrink.dart' show ShrinkWidth;
export 'src/spill.dart' show Spill;
export 'src/spot.dart' show SpotArea, SpotMark, SpotScope, SpotShift, SpotSpan, SpotText;
export 'src/pins.dart' show SectionPin;
export 'src/sticky.dart' show Sticky, StickyBlock, StickyPort;
export 'src/table.dart' show StickyRows, TableAlign, TableBand, TableBox, TableCaptions, TableShift, TableSlot;
export 'src/tracks.dart' show CellAlign, TrackCell, TrackContent, TrackFlow, TrackSize, Tracks;
