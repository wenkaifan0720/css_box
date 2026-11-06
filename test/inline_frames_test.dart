import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _green = Color(0xFF00FF00);
const _red = Color(0xFFFF0000);
const _blue = Color(0xFF0000FF);
const _white = Color(0xFFFFFFFF);

// The test font sets every letter as a square one em across, 0.75 em above
// the baseline and 0.25 em below it. Under a strut of 10px at `height: 2`
// every line is 20 tall with its baseline 15 down.
const _type = TextStyle(fontFamily: 'FlutterTest', fontSize: 10, height: 1, color: Color(0xFF000000));
const _strut = StrutStyle(fontFamily: 'FlutterTest', fontSize: 10, height: 2);

// A frame round the content area, 2.5 over it and 1.5 under it: on a line
// whose baseline is at 15, from 5 to 19.
InlineFrameSpan _frame(List<InlineSpan> children, Decoration decoration, {EdgeInsets margin = EdgeInsets.zero}) =>
    InlineFrameSpan(
      decoration: decoration,
      insets: const EdgeInsets.fromLTRB(4, 2.5, 4, 1.5),
      margin: margin,
      ascent: 7.5,
      descent: 2.5,
      children: children,
    );

Widget _page(InlineSpan text, {double width = 200, EdgeInsets pad = EdgeInsets.zero, StrutStyle? strut = _strut}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: const Key('shot'),
        child: ColoredBox(
          color: _white,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: InlineFrames(
                child: Padding(
                  padding: pad,
                  child: Text.rich(text, style: _type, strutStyle: strut),
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

Future<void> _view(WidgetTester tester) async {
  tester.view.physicalSize = const Size(200, 80);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const _sides = BoxDecoration(
  color: _green,
  border: Border(
    left: BorderSide(color: _red, width: 2),
    right: BorderSide(color: _blue, width: 2),
  ),
);

void main() {
  testWidgets('the frame is round the content area on its line, from the start edge to the end edge', (tester) async {
    await _view(tester);
    // `AA ` is 30 across; the edges are 4 each side of `BB`: 30 to 58.
    await tester.pumpWidget(
      _page(
        TextSpan(
          children: [
            const TextSpan(text: 'AA '),
            _frame([edgeSpan(4), const TextSpan(text: 'BB'), edgeSpan(4)], const BoxDecoration(color: _green)),
          ],
        ),
      ),
    );
    final at = await _shot(tester);
    expect(at(31, 10), _green);
    expect(at(56, 10), _green);
    expect(at(29, 10), _white);
    expect(at(58, 10), _white);
    // Over the glyphs (7.5 to 17.5) and past them, by the insets.
    expect(at(40, 4), _white);
    expect(at(40, 5), _green);
    expect(at(40, 18), _green);
    expect(at(40, 19), _white);
  });

  testWidgets('broken over two lines, each fragment has only the sides it has of the box', (tester) async {
    await _view(tester);
    // `BB ` ends the first line and `CC` starts the second: fragments 30 to
    // 54 and 0 to 24, the first with the red start side, the second with
    // the blue end side.
    await tester.pumpWidget(
      _page(
        TextSpan(
          children: [
            const TextSpan(text: 'AA '),
            _frame([edgeSpan(4), const TextSpan(text: 'BB CC'), edgeSpan(4)], _sides),
          ],
        ),
        width: 70,
      ),
    );
    final at = await _shot(tester);
    expect(at(31, 6), _red);
    expect(at(53, 6), _green, reason: 'no end side on the first line');
    expect(at(55, 6), _white, reason: 'the space the line ends in is not in it');
    expect(at(1, 26), _green, reason: 'no start side on the second line');
    expect(at(23, 26), _blue);
    expect(at(25, 26), _white);
    // The second line's baseline is 35: the fragment from 25 to 39.
    expect(at(10, 24), _white);
    expect(at(10, 25), _green);
    expect(at(10, 38), _green);
    expect(at(10, 39), _white);
  });

  testWidgets('white space in the span is on its line, where the line goes on after it', (tester) async {
    await _view(tester);
    // No room across, only over and under: the frame is ` BB `, 20 to 60,
    // its spaces with it, since `CC` follows on the line.
    await tester.pumpWidget(
      _page(
        const TextSpan(
          children: [
            TextSpan(text: 'AA'),
            InlineFrameSpan(
              decoration: BoxDecoration(color: _green),
              insets: EdgeInsets.only(top: 2.5, bottom: 1.5),
              ascent: 7.5,
              descent: 2.5,
              text: ' BB ',
            ),
            TextSpan(text: 'CC'),
          ],
        ),
      ),
    );
    final at = await _shot(tester);
    expect(at(19, 10), isNot(_green));
    expect(at(21, 10), _green);
    expect(at(58, 10), _green);
    expect(at(61, 10), isNot(_green));
  });

  testWidgets('the fragments are cut from one strip, the box set end to end', (tester) async {
    await _view(tester);
    // Two fragments 24 across: a strip of 48, red to 24 -- the first line's
    // fragment all red and the second's all blue.
    const halves = BoxDecoration(
      gradient: LinearGradient(colors: [_red, _red, _blue, _blue], stops: [0, 0.5, 0.5, 1]),
    );
    await tester.pumpWidget(
      _page(
        TextSpan(
          children: [
            const TextSpan(text: 'AA '),
            _frame([edgeSpan(4), const TextSpan(text: 'BB CC'), edgeSpan(4)], halves),
          ],
        ),
        width: 70,
      ),
    );
    final at = await _shot(tester);
    expect(at(31, 6), _red);
    expect(at(53, 6), _red);
    expect(at(1, 26), _blue);
    expect(at(23, 26), _blue);
  });

  testWidgets('the margin at the ends is room, not frame', (tester) async {
    await _view(tester);
    // 3 of the 7 before `BB` and 2 of the 6 after it are margin: 33 to 61.
    await tester.pumpWidget(
      _page(
        TextSpan(
          children: [
            const TextSpan(text: 'AA '),
            _frame(
              [edgeSpan(7), const TextSpan(text: 'BB'), edgeSpan(6)],
              const BoxDecoration(color: _green),
              margin: const EdgeInsets.only(left: 3, right: 2),
            ),
          ],
        ),
      ),
    );
    final at = await _shot(tester);
    expect(at(32, 10), _white);
    expect(at(33, 10), _green);
    expect(at(60, 10), _green);
    expect(at(61, 10), _white);
  });

  testWidgets("a line a taller run grows stands the fragment on that line's own baseline", (tester) async {
    await _view(tester);
    // A 30px `X` on the second line reaches 22.5 over the baseline where
    // the strut reaches 15: the line starts at 20, its baseline at 42.5,
    // and the fragment round `CC` is from 32.5 to 46.5, snapped to 33 and 47.
    await tester.pumpWidget(
      _page(
        TextSpan(
          children: [
            _frame([edgeSpan(4), const TextSpan(text: 'BB CC'), edgeSpan(4)], const BoxDecoration(color: _green)),
            const TextSpan(text: 'X', style: TextStyle(fontSize: 30)),
          ],
        ),
        width: 60,
      ),
    );
    final at = await _shot(tester);
    expect(at(1, 32), _white);
    expect(at(1, 33), _green);
    expect(at(22, 46), _green);
    expect(at(22, 47), _white);
  });

  testWidgets("a line Skia rounds down under its tallest run still has its frames", (tester) async {
    await _view(tester);
    // A 4px run at `height: 16.9`, its leading shared evenly, reaches 7.45
    // under the baseline where the strut reaches 5: the line is 22.45
    // tall, which Skia rounds to 22 -- its tallest run starts 0.45 over
    // the line's top, and the baseline is at 14.55. The frame round `BB` is
    // from 4.55 to 18.55, snapped to 5 and 19. (a SaaS landing page's `<code>` pills: 13px
    // runs at 32px in a 32px Inter strut.)
    await tester.pumpWidget(
      _page(
        TextSpan(
          children: [
            _frame([edgeSpan(4), const TextSpan(text: 'BB'), edgeSpan(4)], const BoxDecoration(color: _green)),
            const TextSpan(
              text: 'x',
              style: TextStyle(fontSize: 4, height: 16.9 / 4, leadingDistribution: TextLeadingDistribution.even),
            ),
          ],
        ),
      ),
    );
    final at = await _shot(tester);
    expect(at(1, 4), _white);
    expect(at(1, 5), _green);
    expect(at(1, 18), _green);
    expect(at(1, 19), _white);
  });

  testWidgets('the paragraph is where the boxes round it put it, and the edges are snapped on the page', (
    tester,
  ) async {
    await _view(tester);
    // 7.4 in and 3 down: the frame from 37.4 to 65.44, snapped to 37 and 65.
    await tester.pumpWidget(
      _page(
        TextSpan(
          children: [
            const TextSpan(text: 'AA '),
            _frame([edgeSpan(4), const TextSpan(text: 'BB'), edgeSpan(4)], const BoxDecoration(color: _green)),
          ],
        ),
        pad: const EdgeInsets.only(left: 7.4, top: 3),
      ),
    );
    final at = await _shot(tester);
    expect(at(36, 13), _white);
    expect(at(37, 13), _green);
    expect(at(64, 13), _green);
    expect(at(65, 13), _white);
    expect(at(50, 7), _white);
    expect(at(50, 8), _green);
  });

  // `AA BB ` fills the first line at 60 across and `CC` starts the second,
  // its baseline at 35: a frame round it padded 12.5 over the content area
  // is from 15 to 39 -- over the first line's glyphs, 7.5 to 17.5.
  InlineSpan reachingUp({List<InlineSpan> after = const []}) => TextSpan(
    children: [
      const TextSpan(text: 'AA BB '),
      const InlineFrameSpan(
        decoration: BoxDecoration(color: _green),
        insets: EdgeInsets.only(top: 12.5, bottom: 1.5),
        ascent: 7.5,
        descent: 2.5,
        text: 'CC',
      ),
      ...after,
    ],
  );

  testWidgets('a frame padded up over the line above is painted over that line\'s text, and under its own', (
    tester,
  ) async {
    await _view(tester);
    await tester.pumpWidget(_page(reachingUp(), width: 60));
    final at = await _shot(tester);
    expect(at(5, 16), _green, reason: 'the browser paints the first line before the second line\'s frame');
    expect(at(15, 16), _green);
    expect(at(5, 12), const Color(0xFF000000), reason: 'the first line\'s text, above the frame');
    expect(at(25, 16), _white, reason: 'the frame is only as wide as `CC`');
    expect(at(35, 12), const Color(0xFF000000), reason: 'the rest of the first line is painted');
    expect(at(5, 30), const Color(0xFF000000), reason: 'the frame is under its own line\'s text');
    expect(at(5, 38), _green);
  });

  testWidgets('a frame padded down over the line below is under that line\'s text', (tester) async {
    await _view(tester);
    // `AA` framed down to 29.5, snapped to 30, over `CC` from 27.5.
    await tester.pumpWidget(
      _page(
        const TextSpan(
          children: [
            InlineFrameSpan(
              decoration: BoxDecoration(color: _green),
              insets: EdgeInsets.only(top: 2.5, bottom: 12),
              ascent: 7.5,
              descent: 2.5,
              text: 'AA',
            ),
            TextSpan(text: ' BB CC'),
          ],
        ),
        width: 60,
      ),
    );
    final at = await _shot(tester);
    expect(at(5, 26), _green);
    expect(at(5, 29), const Color(0xFF000000));
    expect(at(5, 12), const Color(0xFF000000));
  });

  testWidgets('NEGATIVE: a paragraph with a placeholder is painted whole, over every frame', (tester) async {
    await _view(tester);
    await tester.pumpWidget(
      _page(reachingUp(after: const [WidgetSpan(child: SizedBox(width: 4, height: 4))]), width: 60),
    );
    final at = await _shot(tester);
    expect(at(5, 16), const Color(0xFF000000));
    expect(at(5, 38), _green);
  });

  testWidgets('painted line by line, a changed paragraph is copied again', (tester) async {
    await _view(tester);
    await tester.pumpWidget(_page(reachingUp(), width: 60));
    expect((await _shot(tester))(5, 16), _green);
    await tester.pumpWidget(
      _page(
        TextSpan(
          children: [
            const TextSpan(text: 'DD '),
            reachingUp(),
          ],
        ),
        width: 60,
      ),
    );
    // `DD AA ` is the first line now, `BB CC` the second and the frame is
    // round `CC`, 30 to 50: over `AA`, and `DD` in the clear.
    final at = await _shot(tester);
    expect(at(35, 16), _green);
    expect(at(5, 16), const Color(0xFF000000));
  });

  testWidgets('NEGATIVE: a paragraph with no strut has no baseline to read, and no frame is painted', (tester) async {
    await _view(tester);
    await tester.pumpWidget(
      _page(
        TextSpan(
          children: [
            const TextSpan(text: 'AA '),
            _frame([edgeSpan(4), const TextSpan(text: 'BB'), edgeSpan(4)], const BoxDecoration(color: _green)),
          ],
        ),
        strut: null,
      ),
    );
    final at = await _shot(tester);
    expect(at(31, 5), _white);
  });

  testWidgets('a changed decoration is painted again', (tester) async {
    await _view(tester);
    InlineSpan text(Color c) => TextSpan(
      children: [
        const TextSpan(text: 'AA '),
        _frame([edgeSpan(4), const TextSpan(text: 'BB'), edgeSpan(4)], BoxDecoration(color: c)),
      ],
    );
    await tester.pumpWidget(_page(text(_green)));
    expect((await _shot(tester))(31, 10), _green);
    await tester.pumpWidget(_page(text(_blue)));
    expect((await _shot(tester))(31, 10), _blue);
  });
}
