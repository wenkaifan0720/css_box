// The snippets of css_box's README, one function each, so that every one of
// them compiles and lays out: test/readme_test.dart checks that each Dart
// block of the README is in this file, and test/snippets_test.dart pumps
// every function here.
import 'package:css_box/bands.dart';
import 'package:css_box/css_box.dart';
import 'package:flutter/material.dart';

/// Every snippet, by the README section it illustrates.
final snippets = <String, Widget Function()>{
  'LineBox': lineBox,
  'Balance': balance,
  'Pretty': pretty,
  'IndentedText': indentedText,
  'BlockEllipsis': blockEllipsis,
  'LineClamp, ClampedBlock': lineClamp,
  'InlineFlow': inlineFlow,
  'InlineFrame': inlineFrame,
  'InlineFrames': inlineFrames,
  'GlyphBackgrounds': glyphBackgrounds,
  'LastBaseline': lastBaseline,
  'EdgeBaseline': edgeBaseline,
  'MiddleBaseline, TopBaseline': middleAndTopBaseline,
  'AlignBox': alignBox,
  'ShrinkWidth': shrinkWidth,
  'MinContentWidth': minContentWidth,
  'FixedWidth': fixedWidth,
  'KeywordClamp': keywordClamp,
  'Compressible': compressible,
  'FractionalWidth, FractionalConstraints': fractionalWidth,
  'FractionalHeight, FractionalMinHeight, LooseHeight': fractionalHeight,
  'RatioBox': ratioBox,
  'FloorBox': floorBox,
  'Inset': inset,
  'Spill': spill,
  'FlexLine, FlexCell': flexLine,
  'Tracks, TrackCell': tracks,
  'FloatFlow, FloatSlot, FloatText': floatFlow,
  'TableBox, TableSlot, TableBand, TableShift': tableBox,
  'TableCaptions': tableCaptions,
  'Layers': layers,
  'MultiColumn': multiColumn,
  'Sticky, StickyBlock, StickyPort': sticky,
  'SpotScope, SpotMark, SpotShift': spotMark,
  'SpotText': spotText,
  'SpotArea': spotArea,
  'ClipBox': clipBox,
  'ScrollBox': scrollBox,
  'DocumentExtent, FixedLayer': documentExtent,
  'PressWhereDrawn': pressWhereDrawn,
  'Blend': blend,
  'TileMask': tileMask,
  'MaskLayers': maskLayers,
  'PictureTile': pictureTile,
  'Shadows': shadows,
  'Borders and outlines': borders,
  'Gradients': gradients,
  'Clips': clips,
  'Width bands': widthBands,
};

Widget lineBox() =>
    const SizedBox(width: 48, child: LineBox(child: Text('Unbreakable word')));

Widget balance() =>
    const Balance(child: Text('The web framework for content-driven websites'));

Widget pretty() => const Pretty(
  child: Text(
    'A paragraph set so that its last line never holds one short word alone.',
  ),
);

Widget indentedText() => Padding(
  padding: const EdgeInsets.only(left: 30),
  child: IndentedText(
    '※1 A note that hangs its mark in the padding and wraps under its words.',
    indent: -30,
  ),
);

Widget blockEllipsis() => const BlockEllipsis(
  child: Text(
    'A summary cut after its second line, with the ellipsis where that line ends.',
    maxLines: 2,
  ),
);

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

Widget shrinkWidth() => const ShrinkWidth(
  child: DecoratedBox(
    decoration: BoxDecoration(color: Color(0xFFE2E8F0)),
    child: Text('as wide as its words, up to the room it has'),
  ),
);

Widget minContentWidth() => const MinContentWidth(
  child: DecoratedBox(
    decoration: BoxDecoration(color: Color(0xFFE2E8F0)),
    child: Text('as narrow as its longest word'),
  ),
);

Widget fixedWidth() => const IntrinsicHeight(
  child: FixedWidth(width: 100, child: Text('asked its height at 100 wide')),
);

Widget keywordClamp() => const KeywordClamp(
  floor: ContentWidth.min,
  ceiling: ContentWidth.max,
  child: Text('min-width: min-content; max-width: max-content'),
);

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

Widget fractionalWidth() => const FractionalConstraints(
  maxFactor: 1,
  maxOffset: -32,
  child: FractionalWidth(
    factor: 0.5,
    child: Text('half the room, and no wider than the room less 32'),
  ),
);

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

Widget ratioBox() => const SizedBox(
  width: 120,
  child: RatioBox(
    aspectRatio: 2,
    child: Text('aspect-ratio: 2, and never shorter than its content'),
  ),
);

Widget floorBox() => const FloorBox(
  floor: 120,
  margin: 16,
  child: Text('min-height: 120px over a 16px bottom margin'),
);

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

Widget tableCaptions() => TableCaptions(
  above: const [Text('Plans and prices, a caption wider than its table')],
  table: const TableBox(
    children: [
      TableSlot(row: 0, column: 0, child: TableShift(child: Text('Pro'))),
      TableSlot(row: 0, column: 1, child: TableShift(child: Text('12'))),
    ],
  ),
);

Widget layers() => const Layers(
  direction: Axis.vertical,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  z: [1, 0],
  children: [
    SizedBox(height: 40, child: ColoredBox(color: Color(0xFF1E293B))),
    SizedBox(height: 60, child: ColoredBox(color: Color(0xFFF8FAFC))),
  ],
);

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

Widget clipBox() => const SizedBox(
  width: 120,
  child: ClipBox(
    vertical: false,
    child: Text('cut across, and as tall as its lines', softWrap: false),
  ),
);

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

Widget tileMask() => const TileMask(
  gradient: RadialGradient(
    colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
    stops: [0.4, 0.4],
  ),
  width: 5,
  height: 5,
  child: SizedBox(height: 60, child: ColoredBox(color: Color(0xFF6366F1))),
);

Widget maskLayers() => const MaskLayers(
  layers: [
    MaskLayer(
      gradient: LinearGradient(colors: [Color(0xFF000000), Color(0x00000000)]),
    ),
  ],
  child: SizedBox(height: 60, child: ColoredBox(color: Color(0xFF0EA5E9))),
);

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
