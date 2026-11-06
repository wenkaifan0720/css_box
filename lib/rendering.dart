/// The render objects behind css_box's widgets, and what a render object
/// needs to sit inside one of them or to host one.
///
/// A page needs none of this: its widgets are `package:css_box/css_box.dart`.
/// This library is for code that composes at the render layer -- a
/// `RenderBox` of its own that holds css_box's boxes, or a test that reads
/// what they laid out -- and is imported beside that one.
///
/// THE DRY QUESTIONS. Every box here answers Flutter's dry layout and dry
/// baseline questions, and asks them of what it holds through
/// [dryBaselineOf] and [dryLastBaselineOf]: a box that answers no dry
/// baseline but by asserting -- an `Align` on Flutter 3.38, a proxy over
/// a box with no baseline from 3.41 to 3.47 -- is asked under Flutter's
/// own `debugCheckingIntrinsics` hatch, and only where the question can
/// reach one. A box of your own that does the same mixes in
/// [AsksGuarded]; one that can say where its last line's baseline is
/// without being laid out mixes in [DryLastBaseline]; a proxy that answers
/// its child's dry baseline, and none where the child has none, mixes in
/// [ChildDryBaseline]; a container that has one baseline whichever is asked
/// mixes in [OneBaseline]. A box that states its own width rather than
/// measuring it mixes in [StatedWidth], and a keyword clamp asks past it.
library;

export 'src/align.dart' show RenderAlignBox;
export 'src/balance.dart' show RenderBalance;
export 'src/baseline.dart' show RenderEdgeBaseline, RenderLastBaseline, RenderMiddleBaseline, RenderTopBaseline;
export 'src/blend.dart' show RenderBlend, RenderCanvasFiltered;
export 'src/clamp.dart' show RenderKeywordClamp, StatedWidth, contentIntrinsicWidth;
export 'src/clip.dart' show RenderClipBox;
export 'src/compressible.dart' show RenderCompressible;
export 'src/content.dart' show RenderFixedWidth, RenderMinContentWidth;
export 'src/dry.dart'
    show AsksGuarded, ChildDryBaseline, DryLastBaseline, OneBaseline, dryBaselineOf, dryLastBaselineOf;
export 'src/ellipsis.dart' show RenderBlockEllipsis, RenderClampedBlock, RenderLineClamp;
export 'src/extent.dart' show RenderDocumentExtent, RenderFixedLayer, furthestEdge;
export 'src/flex_line.dart' show FlexLineParentData, RenderFlexLine;
export 'src/float_flow.dart' show FloatFlowParentData, RenderFloatFlow, RenderFloatText;
export 'src/floor.dart' show RenderFloorBox;
export 'src/fraction.dart'
    show
        RenderFractionalConstraints,
        RenderFractionalHeight,
        RenderFractionalMinHeight,
        RenderFractionalWidth,
        RenderLooseHeight;
export 'src/gap_wrap.dart' show RenderGapWrap;
export 'src/glyph_background.dart' show RenderGlyphBackgrounds;
export 'src/indent.dart' show RenderIndentedText;
export 'src/inline_flow.dart' show InlineFlowParentData, RenderInlineFlow;
export 'src/inline_frame.dart' show RenderInlineFrame;
export 'src/inline_frames.dart' show RenderInlineFrames;
export 'src/inset.dart' show RenderInset, RoomHost;
export 'src/layers.dart' show RenderLayers;
export 'src/linebox.dart' show RenderLineBox;
export 'src/mask_layers.dart' show RenderMaskLayers;
export 'src/multi_column.dart' show MultiColumnParentData, RenderMultiColumn;
export 'src/picture_tile.dart' show RenderPictureTile;
export 'src/press_where_drawn.dart' show RenderPressWhereDrawn;
export 'src/pretty.dart' show RenderPretty;
export 'src/ratio.dart' show RenderRatioBox;
export 'src/scroll.dart' show RenderScrollPort;
export 'src/shrink.dart' show RenderShrinkWidth;
export 'src/spill.dart' show RenderSpill;
export 'src/pins.dart' show RenderSectionPin;
export 'src/spot.dart' show Overhangs, RenderSpotArea, RenderSpotMark, RenderSpotShift, RenderSpotText;
export 'src/sticky.dart'
    show HearsScrolls, HoldsSticky, RenderSticky, RenderStickyBlock, RenderStickyPort, scrollsRound, stickyPortOf;
export 'src/table.dart'
    show
        RenderTableBand,
        RenderTableBox,
        RenderTableCaptions,
        RenderTableShift,
        RenderTableSlot,
        TableBoxParentData,
        TableCaptionsParentData;
export 'src/tile_mask.dart' show RenderTileMask;
export 'src/tracks.dart' show RenderTracks, TrackCellParentData;
