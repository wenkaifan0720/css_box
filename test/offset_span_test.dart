import 'dart:ui' as ui;

import 'package:css_box/css_box.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _white = Color(0xFFFFFFFF);
const _ink = Color(0xFF000000);

// The test font sets every letter as a square one em across, 0.75 em above
// the baseline and 0.25 em below it: at 10px, a 10px square per letter.
const _type = TextStyle(fontFamily: 'FlutterTest', fontSize: 10, height: 1, color: _ink);

// The paragraph 10px down and 10px in from the page's edges, so that a
// span moved off it is still on the page.
Widget _page(InlineSpan text, {double width = 200}) => Directionality(
  textDirection: TextDirection.ltr,
  child: RepaintBoundary(
    key: const Key('shot'),
    child: ColoredBox(
      color: _white,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: OffsetSpans(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text.rich(text, style: _type),
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<Color Function(int, int)> _shot(WidgetTester tester) async {
  final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
  final data = (await tester.runAsync(() async {
    final img = await ro.toImage();
    return (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  }))!;
  final w = ro.size.width.round();
  return (int x, int y) {
    final i = (y * w + x) * 4;
    return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
  };
}

// CSS 2.1 9.4.3: a relatively positioned inline box is painted off the
// place the line gives it, and the line keeps the place. `ab`, then `X`
// moved 3 right and 4 down, then `cd`: the X's square is drawn from
// (33, 14) where the line sets it at (30, 10), nothing is drawn where it
// stood, and `c` is where the line puts it.
void main() {
  testWidgets('a span is painted off its place by its offset, and nothing is left where it stood', (tester) async {
    await tester.pumpWidget(
      _page(
        const TextSpan(children: [TextSpan(text: 'ab'), OffsetSpan(text: 'X', dx: 3, dy: 4), TextSpan(text: 'cd')]),
      ),
    );
    final px = await _shot(tester);
    expect(px(15, 15), _ink, reason: 'b where the line sets it');
    expect(px(45, 15), _ink, reason: 'c where the line sets it');
    expect(px(31, 12), _white, reason: 'the X is not where the line set it');
    expect(px(35, 22), _ink, reason: 'the X moved 3 right and 4 down');
    expect(px(35, 9), _white, reason: 'nothing above the moved X');
  });

  testWidgets('the paragraph lays out as it does without the offset', (tester) async {
    await tester.pumpWidget(
      _page(const TextSpan(children: [TextSpan(text: 'ab '), OffsetSpan(text: 'Xy', dy: -5), TextSpan(text: ' cd')]), width: 70),
    );
    final moved = tester.getSize(find.byType(Text));
    await tester.pumpWidget(
      _page(const TextSpan(children: [TextSpan(text: 'ab '), TextSpan(text: 'Xy'), TextSpan(text: ' cd')]), width: 70),
    );
    expect(moved, tester.getSize(find.byType(Text)));
  });

  testWidgets('a span broken over two lines moves each piece on its line', (tester) async {
    // 50 across holds `ab XY` (5 squares) and then `ZW` on the next line.
    await tester.pumpWidget(
      _page(const TextSpan(children: [TextSpan(text: 'ab '), OffsetSpan(text: 'XY ZW', dy: -4)]), width: 70),
    );
    final px = await _shot(tester);
    expect(px(45, 18), _white, reason: 'the bottom of the first piece moved up');
    expect(px(45, 8), _ink, reason: 'the first piece 4 up');
    expect(px(15, 28), _white, reason: 'the bottom of the second piece moved up');
    expect(px(15, 24), _ink, reason: 'the second piece 4 up, on its own line');
    expect(px(15, 12), _ink, reason: 'a where the line sets it');
  });

  // A FloatText sets each line as a paragraph of its own, and paints the
  // piece of a span on it moved, as OffsetSpans does a paragraph's: the
  // lines beside a float are no paragraph to find.
  Widget floatPage(InlineSpan text, {double width = 200}) => Directionality(
    textDirection: TextDirection.ltr,
    child: RepaintBoundary(
      key: const Key('shot'),
      child: ColoredBox(
        color: _white,
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(width: width, child: FloatText(text, style: _type, lineHeight: 10)),
          ),
        ),
      ),
    ),
  );

  testWidgets('a FloatText paints a span off its place on each line it is on', (tester) async {
    // 50 across holds `ab XY` and then `ZW cd`: the span `XY ZW` 4 up and 2
    // right on both lines, `ab` and `cd` where the lines set them.
    await tester.pumpWidget(
      floatPage(const TextSpan(children: [TextSpan(text: 'ab '), OffsetSpan(text: 'XY ZW', dx: 2, dy: -4), TextSpan(text: ' cd')]), width: 50),
    );
    final px = await _shot(tester);
    expect(px(15, 15), _ink, reason: 'a where the first line sets it');
    expect(px(41, 18), _white, reason: 'the bottom of X moved up');
    expect(px(45, 8), _ink, reason: 'X 4 up');
    expect(px(41, 12), _white, reason: 'nothing at the left edge of X: moved 2 right');
    expect(px(15, 28), _white, reason: 'the bottom of Z moved up');
    expect(px(15, 24), _ink, reason: 'Z 4 up, on its own line');
    expect(px(45, 25), _ink, reason: 'c where the second line sets it');
  });

  testWidgets('NEGATIVE: a FloatText with a span at no offset paints as with a TextSpan', (tester) async {
    await tester.pumpWidget(
      floatPage(const TextSpan(children: [TextSpan(text: 'ab '), OffsetSpan(text: 'XY ZW'), TextSpan(text: ' cd')]), width: 50),
    );
    final a = await _shot(tester);
    await tester.pumpWidget(
      floatPage(const TextSpan(children: [TextSpan(text: 'ab '), TextSpan(text: 'XY ZW'), TextSpan(text: ' cd')]), width: 50),
    );
    final b = await _shot(tester);
    for (var y = 0; y < 40; y++) {
      for (var x = 0; x < 70; x++) {
        expect(a(x, y), b(x, y), reason: '($x, $y)');
      }
    }
  });

  testWidgets('NEGATIVE: a span at no offset is painted as a TextSpan is', (tester) async {
    await tester.pumpWidget(
      _page(const TextSpan(children: [TextSpan(text: 'ab'), OffsetSpan(text: 'X'), TextSpan(text: 'cd')])),
    );
    final a = await _shot(tester);
    await tester.pumpWidget(_page(const TextSpan(children: [TextSpan(text: 'ab'), TextSpan(text: 'X'), TextSpan(text: 'cd')])));
    final b = await _shot(tester);
    for (var y = 0; y < 30; y++) {
      for (var x = 0; x < 80; x++) {
        expect(a(x, y), b(x, y), reason: '($x, $y)');
      }
    }
  });

  test('a new offset repaints and lays out nothing', () {
    const a = OffsetSpan(text: 'X', dy: -4);
    expect(a.compareTo(const OffsetSpan(text: 'X', dy: -6)), RenderComparison.paint);
    expect(a.compareTo(const OffsetSpan(text: 'X', dy: -4)), RenderComparison.identical);
    expect(a.compareTo(const TextSpan(text: 'X')), RenderComparison.layout);
  });
}
