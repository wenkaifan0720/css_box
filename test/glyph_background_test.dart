import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _green = Color(0xFF00FF00);
const _red = Color(0xFFFF0000);
const _blue = Color(0xFF0000FF);
const _white = Color(0xFFFFFFFF);
const _ink = Color(0xFF000000);
const _clear = TextStyle(color: Color(0x00000000));

// A background of one colour.
const _solid = LinearGradient(colors: [_green, _green]);

// Red over the first half of the strip, blue over the second.
const _halves = LinearGradient(colors: [_red, _red, _blue, _blue], stops: [0, 0.5, 0.5, 1]);

// The test font sets every letter as a square one em across, 0.75 em above
// the baseline and 0.25 em below it: at 10px, a 10px square per letter, the
// line's baseline 7.5 down.
const _type = TextStyle(fontFamily: 'FlutterTest', fontSize: 10, height: 1, color: _ink);

Widget _page(InlineSpan text, {double width = 200, EdgeInsets pad = EdgeInsets.zero, StrutStyle? strut}) =>
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
              child: GlyphBackgrounds(
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
  tester.view.physicalSize = const Size(200, 40);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('the background shows inside the span\'s glyphs and nowhere else', (tester) async {
    await _view(tester);
    await tester.pumpWidget(
      _page(
        const TextSpan(
          children: [
            TextSpan(text: 'AA '),
            GlyphBackgroundSpan(background: _solid, text: 'XX', style: _clear),
            TextSpan(text: ' AA'),
          ],
        ),
      ),
    );
    final at = await _shot(tester);
    expect(at(35, 5), _green);
    expect(at(45, 5), _green);
    // The runs beside it in their own colour, and nothing under the line.
    expect(at(5, 5), _ink);
    expect(at(75, 5), _ink);
    expect(at(35, 15), _white);
  });

  testWidgets('a span holding only children, runs within runs, is found where its text is', (tester) async {
    // The shape the lowering prints: the span's text is all in its
    // children, and `visitChildren` passes over a span with no text.
    await _view(tester);
    await tester.pumpWidget(
      _page(
        const TextSpan(
          children: [
            TextSpan(text: 'AA '),
            GlyphBackgroundSpan(
              background: _solid,
              children: [
                TextSpan(text: 'X', style: _clear),
                TextSpan(
                  children: [TextSpan(text: 'X', style: _clear)],
                ),
              ],
            ),
            TextSpan(text: ' AA'),
          ],
        ),
      ),
    );
    final at = await _shot(tester);
    expect(at(35, 5), _green);
    expect(at(45, 5), _green);
    expect(at(5, 5), _ink);
    expect(at(75, 5), _ink);
  });

  testWidgets('the text is painted over it', (tester) async {
    await _view(tester);
    await tester.pumpWidget(
      _page(
        const TextSpan(
          children: [
            TextSpan(text: 'AA '),
            GlyphBackgroundSpan(
              background: _solid,
              text: 'XX',
              style: TextStyle(color: _red),
            ),
          ],
        ),
      ),
    );
    final at = await _shot(tester);
    expect(at(35, 5), _red);
  });

  testWidgets('a box broken over lines is one strip, each line showing its own stretch of it', (tester) async {
    await _view(tester);
    // `XX` on the first line and `XXXXXX` on the second: a strip of 20 and
    // 60 -- the space the first line ends in hangs past it -- red to 40.
    await tester.pumpWidget(
      _page(const GlyphBackgroundSpan(background: _halves, text: 'XX XXXXXX', style: _clear), width: 60),
    );
    final at = await _shot(tester);
    expect(at(15, 5), _red);
    expect(at(15, 15), _red, reason: 'the second line starts 20 into the strip');
    expect(at(25, 15), _blue);
    expect(at(55, 15), _blue);
  });

  // `background-size: 300%` on a product site's `Thinking...`: the tile is a share
  // of the strip, placed by `background-position`.
  testWidgets('a tile twice the strip across shows its first half, or at x 1 its second', (tester) async {
    await _view(tester);
    await tester.pumpWidget(
      _page(const GlyphBackgroundSpan(background: _halves, widthFactor: 2, text: 'XXXX', style: _clear)),
    );
    var at = await _shot(tester);
    expect(at(5, 5), _red);
    expect(at(35, 5), _red, reason: 'the tile is 80 across: red to 40');
    await tester.pumpWidget(
      _page(const GlyphBackgroundSpan(background: _halves, widthFactor: 2, x: 1, text: 'XXXX', style: _clear)),
    );
    at = await _shot(tester);
    expect(at(5, 5), _blue, reason: 'the tile runs from -40 to 40: blue from 0');
    expect(at(35, 5), _blue);
  });

  testWidgets('a tile twice the strip down shows its top half, or at y 1 its bottom one', (tester) async {
    await _view(tester);
    const down = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_red, _red, _blue, _blue],
      stops: [0, 0.5, 0.5, 1],
    );
    await tester.pumpWidget(
      _page(const GlyphBackgroundSpan(background: down, heightFactor: 2, text: 'XX', style: _clear)),
    );
    var at = await _shot(tester);
    expect(at(5, 1), _red);
    expect(at(5, 8), _red, reason: 'the tile is 20 down: red to 10');
    await tester.pumpWidget(
      _page(const GlyphBackgroundSpan(background: down, heightFactor: 2, y: 1, text: 'XX', style: _clear)),
    );
    at = await _shot(tester);
    expect(at(5, 1), _blue, reason: 'the tile runs from -10 to 10: blue from 0');
    expect(at(5, 8), _blue);
  });

  testWidgets('broken over lines, the tile is a share of the whole strip', (tester) async {
    await _view(tester);
    // A strip of 20 and 60 as above, the tile 160 across: red to 80, so
    // every piece is red.
    await tester.pumpWidget(
      _page(
        const GlyphBackgroundSpan(background: _halves, widthFactor: 2, text: 'XX XXXXXX', style: _clear),
        width: 60,
      ),
    );
    final at = await _shot(tester);
    expect(at(15, 5), _red);
    expect(at(25, 15), _red);
    expect(at(55, 15), _red);
  });

  testWidgets('the paragraph is where the boxes round it put it', (tester) async {
    await _view(tester);
    await tester.pumpWidget(
      _page(
        const TextSpan(
          children: [
            TextSpan(text: 'AA '),
            GlyphBackgroundSpan(background: _solid, text: 'XX', style: _clear),
          ],
        ),
        pad: const EdgeInsets.only(left: 7, top: 3),
      ),
    );
    final at = await _shot(tester);
    expect(at(20, 8), _ink);
    expect(at(40, 8), _green);
    expect(at(55, 8), _green);
    expect(at(40, 2), _white);
  });

  testWidgets('the piece is the content area: ascent over the baseline, descent under it', (tester) async {
    await _view(tester);
    // The baseline is 7.5 down: an area from 2.5 to 8.5, snapped to 3 and 9.
    await tester.pumpWidget(
      _page(
        const TextSpan(
          children: [
            TextSpan(text: 'AA '),
            GlyphBackgroundSpan(background: _solid, ascent: 5, descent: 1, text: 'XX', style: _clear),
          ],
        ),
      ),
    );
    final at = await _shot(tester);
    expect(at(35, 2), _white);
    expect(at(35, 3), _green);
    expect(at(35, 8), _green);
    expect(at(35, 9), _white);
  });

  testWidgets(
    'each piece is masked by its own glyphs: the line above keeps its stretch where it reaches into the line below',
    (tester) async {
      await _view(tester);
      // 6px lines of 10px letters: the first line's letters reach 4px into
      // the second line's content area. `XXXX` then `X X`: a strip of 40 and
      // 30, red to 35 -- the whole first line red, the whole second blue.
      await tester.pumpWidget(
        _page(
          const GlyphBackgroundSpan(background: _halves, ascent: 7.5, descent: 2.5, text: 'XXXX X X', style: _clear),
          width: 40,
          strut: const StrutStyle(fontFamily: 'FlutterTest', fontSize: 10, height: 0.6, forceStrutHeight: true),
        ),
      );
      final at = await _shot(tester);
      // Under the second line's space, inside its area, the first line's
      // letter is still the first line's red.
      expect(at(15, 5), _red);
      expect(at(5, 9), _blue);
    },
  );

  // `background-repeat`, a `calc()` size and a length position (3.4, 3.6,
  // 3.9): the tile laid again and again, a share with a length on it, and
  // a tile moved on by a length.
  testWidgets('a tile half the strip repeated shows twice; not repeated, once', (tester) async {
    await _view(tester);
    await tester.pumpWidget(
      _page(
        const GlyphBackgroundSpan(background: _halves, widthFactor: 0.5, repeatX: true, text: 'XXXX', style: _clear),
      ),
    );
    var at = await _shot(tester);
    // The tile is 20 across: red, blue, red, blue in tens.
    expect(
      [
        for (final x in [5, 15, 25, 35]) at(x, 5),
      ],
      [_red, _blue, _red, _blue],
    );
    await tester.pumpWidget(
      _page(const GlyphBackgroundSpan(background: _halves, widthFactor: 0.5, text: 'XXXX', style: _clear)),
    );
    at = await _shot(tester);
    expect(
      [
        for (final x in [5, 15, 25, 35]) at(x, 5),
      ],
      [_red, _blue, _white, _white],
    );
  });

  testWidgets('a tile of a share and a length, moved on by a length', (tester) async {
    await _view(tester);
    // A tile 0 x 40 + 20 = 20 across, moved 5 on and repeated: its copies
    // start at -15, 5, 25; red for their first ten.
    await tester.pumpWidget(
      _page(
        const GlyphBackgroundSpan(
          background: _halves,
          widthFactor: 0,
          width: 20,
          dx: 5,
          repeatX: true,
          text: 'XXXX',
          style: _clear,
        ),
      ),
    );
    final at = await _shot(tester);
    expect(
      [
        for (final x in [2, 7, 17, 27, 37]) at(x, 5),
      ],
      [_blue, _red, _blue, _red, _blue],
    );
  });

  testWidgets('the tile is sized and placed on the strip snapped to whole pixels', (tester) async {
    await _view(tester);
    // `XXX` from 0.6 to 30.6, snapped to 1 and 31 as Chrome snaps the
    // positioning area: a tile 15 across from 1, its copies meeting at 16.
    // Unsnapped they would meet at 15.6, and pixel 15 would be part red.
    await tester.pumpWidget(
      _page(
        const GlyphBackgroundSpan(background: _halves, widthFactor: 0.5, repeatX: true, text: 'XXX', style: _clear),
        pad: const EdgeInsets.only(left: 0.6),
      ),
    );
    final at = await _shot(tester);
    expect(at(15, 5), _blue);
    expect(at(16, 5), _red);
  });

  testWidgets('a tile that is no whole number of pixels is its raster read bilinearly, as Chrome reads it', (
    tester,
  ) async {
    await _view(tester);
    // A tile 7.5 across is drawn on 8 pixels, red on the first four and
    // blue on the rest, and scaled back down to 7.5. The first copy's blue
    // meets the second's red at 7.5, halfway across pixel 7: half of each.
    // Pixel 3's centre, 3.5, is texel 3.73 -- 0.77 of red texel 3 and
    // 0.23 of blue texel 4, where the gradient at 3.5 is red.
    await tester.pumpWidget(
      _page(
        const GlyphBackgroundSpan(background: _halves, widthFactor: 0.25, repeatX: true, text: 'XXX', style: _clear),
      ),
    );
    final at = await _shot(tester);
    int c(double v) => (v * 255).round();
    final seam = at(7, 5), inside = at(3, 5);
    expect(seam.a, 1.0);
    expect([c(seam.r), c(seam.b)], [closeTo(128, 3), closeTo(128, 3)]);
    expect([c(inside.r), c(inside.b)], [closeTo(196, 3), closeTo(60, 3)]);
    expect(at(8, 5), _red);
  });

  test('a round tile is the strip over the whole number of copies nearest to fitting it, in layout units', () {
    const round = GlyphBackgroundSpan(background: _halves, widthFactor: 0, width: 45, roundX: true, text: 'x');
    // 118 / 45 is 2.6: three copies of 118 / 3, cut down to a 64th.
    expect(round.tileOf(const Rect.fromLTWH(10, 0, 118, 20)), const Rect.fromLTWH(10, 0, 39.328125, 20));
    // 112 / 45 is 2.5 less a little: two copies of 56.
    expect(round.tileOf(const Rect.fromLTWH(0, 0, 112, 20)).width, 56);
    // A strip shorter than the tile holds one, the strip's own size.
    expect(round.tileOf(const Rect.fromLTWH(0, 0, 30, 20)).width, 30);
    // Not round down: the tile's own height.
    expect(round.tileOf(const Rect.fromLTWH(0, 0, 118, 20)).height, 20);
  });

  // `round` along one axis beside an `auto` size along the other (3.9,
  // the third step): the other is scaled with the rounded one.
  test('a round tile keeps its ratio where the other side is auto, in layout units', () {
    const across = GlyphBackgroundSpan(
      background: _halves,
      widthFactor: 0,
      width: 45,
      roundX: true,
      keepsRatio: true,
      text: 'x',
    );
    // 118 / 3 is 39.328125 across; 34 down times that, over 45, cut down
    // to a 64th after each step: 1337.15625, then 29.703125.
    expect(across.tileOf(const Rect.fromLTWH(0, 0, 118, 34)), const Rect.fromLTWH(0, 0, 39.328125, 29.703125));
    // Without it, the height the size says.
    const plain = GlyphBackgroundSpan(background: _halves, widthFactor: 0, width: 45, roundX: true, text: 'x');
    expect(plain.tileOf(const Rect.fromLTWH(0, 0, 118, 34)).height, 34);
    // Down: 50 over a tile of 22 is two copies of 25, and the width 40
    // with it, 1000 over 22 cut down to a 64th.
    const down = GlyphBackgroundSpan(
      background: _halves,
      heightFactor: 0,
      height: 22,
      widthFactor: 0,
      width: 40,
      roundY: true,
      keepsRatio: true,
      text: 'x',
    );
    expect(down.tileOf(const Rect.fromLTWH(0, 0, 118, 50)).size, const Size(45.453125, 25));
    // Round both ways, neither is scaled by the other.
    const both = GlyphBackgroundSpan(
      background: _halves,
      widthFactor: 0,
      width: 45,
      roundX: true,
      roundY: true,
      keepsRatio: true,
      text: 'x',
    );
    expect(both.tileOf(const Rect.fromLTWH(0, 0, 118, 34)).size, const Size(39.328125, 34));
  });

  testWidgets('a round tile is laid again and again', (tester) async {
    await _view(tester);
    // 40 across over a tile of 15: three copies of 13.328125, each red for
    // its first half and blue for its second.
    await tester.pumpWidget(
      _page(
        const GlyphBackgroundSpan(
          background: _halves,
          widthFactor: 0,
          width: 15,
          roundX: true,
          text: 'XXXX',
          style: _clear,
        ),
      ),
    );
    final at = await _shot(tester);
    expect(
      [
        for (final x in [2, 10, 16, 24, 29, 37]) at(x, 5),
      ],
      [_red, _blue, _red, _blue, _red, _blue],
    );
  });

  testWidgets('a changed background is painted again', (tester) async {
    await _view(tester);
    InlineSpan text(Color c) => TextSpan(
      children: [
        const TextSpan(text: 'AA '),
        GlyphBackgroundSpan(
          background: LinearGradient(colors: [c, c]),
          text: 'XX',
          style: _clear,
        ),
      ],
    );
    await tester.pumpWidget(_page(text(_green)));
    expect((await _shot(tester))(35, 5), _green);
    await tester.pumpWidget(_page(text(_blue)));
    expect((await _shot(tester))(35, 5), _blue);
  });

  // A border one sees, round each piece's padding box, over the background
  // the glyphs clip and not clipped by them (CSS 2.1 appendix E, step 7).
  testWidgets('the border is painted round the padding box, where the glyphs are not', (tester) async {
    await _view(tester);
    // The area is 30 to 50 across and 3 to 9 down; the border 2 round it.
    await tester.pumpWidget(
      _page(
        const TextSpan(
          children: [
            TextSpan(text: 'AA '),
            GlyphBackgroundSpan(
              background: _solid,
              ascent: 5,
              descent: 1,
              border: EdgeInsets.all(2),
              borderColor: _blue,
              text: 'XX',
              style: _clear,
            ),
          ],
        ),
      ),
    );
    final at = await _shot(tester);
    expect([at(29, 5), at(28, 5), at(51, 5), at(40, 1), at(40, 2), at(40, 9), at(40, 10)], List.filled(7, _blue));
    expect([at(27, 5), at(52, 5), at(40, 0), at(40, 11)], List.filled(4, _white));
    expect(at(40, 5), _green);
  });

  testWidgets('broken over lines, the left side is on the first piece and the right on the last', (tester) async {
    await _view(tester);
    // `XXX` then `XXX`, from 5: each piece 5 to 35 across, 3 to 9 and 13
    // to 19 down.
    await tester.pumpWidget(
      _page(
        const GlyphBackgroundSpan(
          background: _solid,
          ascent: 5,
          descent: 1,
          border: EdgeInsets.all(2),
          borderColor: _blue,
          text: 'XXX XXX',
          style: _clear,
        ),
        width: 45,
        pad: const EdgeInsets.only(left: 5),
      ),
    );
    final at = await _shot(tester);
    expect([at(4, 5), at(36, 15)], [_blue, _blue]);
    expect([at(36, 5), at(4, 15)], [_white, _white]);
    expect([at(20, 2), at(20, 12), at(20, 19)], [_blue, _blue, _blue]);
  });
}
