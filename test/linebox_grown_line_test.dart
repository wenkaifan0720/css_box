import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The test font sets every letter as a square one em across, 0.75em over
// the baseline. The block is 16px on 20.8px lines: the strut is 12 over 4,
// led to 14 over 6.8 as Blink floors the half above. A run of 8px on 24px
// lines is 6 over 2, led to 14 over 10: as high as the strut over the
// baseline and 3.2 deeper under it, so a line holding one is 14 over 10,
// 24 tall, and a line without one the strut's 20.8 -- 20.796875 on Blink's
// 1/64 grid.
const _black = Color(0xFF000000);
const _white = Color(0xFFFFFFFF);
const _w = 40;
const _lh = 20.8;
const _grid = 20.796875;
final _strut = StrutStyle(
  fontFamily: 'FlutterTest',
  fontSize: 16,
  height: _lh / 16,
  leadingDistribution: ui.TextLeadingDistribution.even,
);
const _block = TextStyle(fontFamily: 'FlutterTest', fontSize: 16, height: _lh / 16, color: _black);
// The deep run, and the same run in another colour: a line's height does
// not read its paint.
const _deep = TextStyle(fontSize: 8, height: 3, leadingDistribution: ui.TextLeadingDistribution.even);
const _deepRed = TextStyle(
  fontSize: 8,
  height: 3,
  leadingDistribution: ui.TextLeadingDistribution.even,
  color: Color(0xFFFF0000),
);
// A run of 16px on 24px lines: 16 over 8, past the strut both ways.
const _high = TextStyle(fontSize: 16, height: 1.5, leadingDistribution: ui.TextLeadingDistribution.even);

Widget _box(List<InlineSpan> spans, {GrownLine? grown, double lh = _lh, double ascent = 14}) => Directionality(
  textDirection: TextDirection.ltr,
  child: RepaintBoundary(
    key: const Key('shot'),
    child: ColoredBox(
      color: _white,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: _w.toDouble(),
          child: LineBox(
            lineHeight: lh,
            ascent: ascent,
            grown: grown,
            child: Text.rich(
              TextSpan(children: spans),
              style: _block,
              strutStyle: _strut,
            ),
          ),
        ),
      ),
    ),
  ),
);

// Four lines, the second and the fourth holding the deep run.
List<InlineSpan> _mixed([TextStyle deep = _deep]) => [
  const TextSpan(text: 'A\n'),
  TextSpan(text: 'B', style: deep),
  const TextSpan(text: '\nC\n'),
  TextSpan(text: 'D', style: deep),
];

Future<(Uint8List, int)> _shot(WidgetTester tester) async {
  final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
  return (await tester.runAsync(() async {
    final img = await ro.toImage();
    return ((await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List(), img.height);
  }))!;
}

/// The first pixel row of each glyph square down the column at [x].
List<int> _inkTops(Uint8List px, int h, {int x = 2}) {
  final out = <int>[];
  var inside = false;
  for (var y = 0; y < h; y++) {
    final ink = 1 - px[(y * _w + x) * 4] / 255;
    if (ink > 0.5 && !inside) out.add(y);
    inside = ink > 0.5;
  }
  return out;
}

Future<void> _pump(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(_w * 1.0, 200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(w);
}

/// [read] asked outside layout, as a test may.
T _asked<T>(T Function() read) {
  final was = RenderObject.debugCheckingIntrinsics;
  RenderObject.debugCheckingIntrinsics = true;
  try {
    return read();
  } finally {
    RenderObject.debugCheckingIntrinsics = was;
  }
}

RenderLineBox _line(WidgetTester tester) => tester.renderObject<RenderLineBox>(find.byType(LineBox));

void main() {
  const grown = (styles: [_deep], lineHeight: 24.0, ascent: 14.0);

  testWidgets('the lines holding the deep run are its line, the rest the strut\'s', (tester) async {
    await _pump(tester, _box(_mixed(), grown: grown));
    final box = _line(tester);
    // 20.796875 + 24 + 20.796875 + 24, where every line told 24 is 96.
    expect(box.size.height, closeTo(2 * _grid + 48, 1e-6));
    expect(_asked(() => box.getDistanceToBaseline(TextBaseline.alphabetic)), closeTo(14, 1e-3));
    // The last baseline: 14 over the fourth line, which starts 65.59375 down.
    expect(box.below, closeTo(2 * _grid + 24 + 14 - 14, 1e-6));
    // Asked before layout, the same lines.
    final room = BoxConstraints(maxWidth: _w.toDouble());
    expect(box.getDryLayout(room).height, closeTo(box.size.height, 1e-6));
    expect(box.getMinIntrinsicHeight(_w.toDouble()), closeTo(box.size.height, 1e-6));
    expect(_asked(() => box.getDryBaseline(room, TextBaseline.alphabetic)), closeTo(14, 1e-3));
    // Each square where its line puts it: 14 - 12, then the 8px squares
    // 6 over their baselines at 34.8 and 79.6, the 16px one 12 over 58.8.
    final (px, h) = await _shot(tester);
    final tops = _inkTops(px, h);
    expect(tops.length, 4);
    for (final (i, want) in [2.0, 28.8, 46.8, 73.6].indexed) {
      expect((tops[i] - want).abs(), lessThanOrEqualTo(1), reason: 'line $i at ${tops[i]}, want $want ($tops)');
    }
  });

  testWidgets('a run that reaches past the strut over the baseline moves the baseline of its line', (tester) async {
    await _pump(
      tester,
      _box(
        const [TextSpan(text: 'A', style: _high), TextSpan(text: '\nB')],
        grown: (styles: const [_high], lineHeight: 24.0, ascent: 16.0),
      ),
    );
    final box = _line(tester);
    expect(box.size.height, closeTo(24 + _grid, 1e-6));
    expect(_asked(() => box.getDistanceToBaseline(TextBaseline.alphabetic)), closeTo(16, 1e-3));
    // The second baseline: 14 into the line that starts at 24.
    expect(box.below, closeTo(24 + 14 - 16, 1e-6));
  });

  testWidgets('a run in the style with other paint is in it', (tester) async {
    await _pump(tester, _box(_mixed(_deepRed), grown: grown));
    expect(_line(tester).size.height, closeTo(2 * _grid + 48, 1e-6));
  });

  testWidgets('a point is on the line painted under it', (tester) async {
    await _pump(tester, _box(_mixed(), grown: grown));
    final box = _line(tester);
    final para = tester.renderObject<RenderParagraph>(find.byType(RichText));
    // The middle of the third line as CSS stacks it, under 20.8 and 24: on
    // the `C`, which Skia drew 45 down, not 44.8.
    const at = Offset(4, _grid + 24 + _grid / 2);
    final result = BoxHitTestResult();
    expect(box.hitTest(result, position: at), isTrue);
    final entry = result.path.firstWhere((e) => e.target == para);
    expect(para.getPositionForOffset(MatrixUtils.transformPoint(entry.transform!, at)).offset, 4);
  });

  group('NEGATIVE: every line the one told', () {
    Future<(double, double?, List<int>)> read(WidgetTester tester, Widget w) async {
      await _pump(tester, w);
      final box = _line(tester);
      final (px, h) = await _shot(tester);
      return (box.size.height, _asked(() => box.getDistanceToBaseline(TextBaseline.alphabetic)), _inkTops(px, h));
    }

    testWidgets('where every line holds the run, every line is grown', (tester) async {
      final spans = [const TextSpan(text: 'A', style: _deep), const TextSpan(text: '\nB', style: _deep)];
      final grownBox = await read(tester, _box(spans, grown: grown));
      final told = await read(tester, _box(spans, lh: 24, ascent: 14));
      expect([grownBox.$1, grownBox.$2, ...grownBox.$3], [told.$1, told.$2, ...told.$3]);
    });

    testWidgets('where no line holds the run, every line is grown', (tester) async {
      const spans = [TextSpan(text: 'A\nB')];
      final grownBox = await read(tester, _box(spans, grown: grown));
      final told = await read(tester, _box(spans, lh: 24, ascent: 14));
      expect([grownBox.$1, grownBox.$2, ...grownBox.$3], [told.$1, told.$2, ...told.$3]);
    });

    testWidgets('a paragraph with a box on it is read off its boxes, every line grown', (tester) async {
      final spans = [const WidgetSpan(child: SizedBox(width: 4, height: 4)), ..._mixed()];
      final grownBox = await read(tester, _box(spans, grown: grown));
      final told = await read(tester, _box(spans, lh: 24, ascent: 14));
      expect([grownBox.$1, grownBox.$2, ...grownBox.$3], [told.$1, told.$2, ...told.$3]);
    });
  });
}
