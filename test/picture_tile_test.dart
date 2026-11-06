import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';

// A 4x4 tile lit in its top-left 2x2 square: an svg of viewBox 0 0 4 4
// holding a 2x2 rect, at `background-size: 4px 4px`.
class _Square extends CustomPainter {
  const _Square(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width / 2, size.height / 2), Paint()..color = color);

  @override
  bool shouldRepaint(_Square old) => old.color != color;
}

Widget _page(Widget tile, {double left = 0}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(devicePixelRatio: 1),
    child: RepaintBoundary(
      key: const Key('shot'),
      child: ColoredBox(
        color: const Color(0xFFFFFFFF),
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.only(left: left),
            child: SizedBox(width: 12, height: 8, child: tile),
          ),
        ),
      ),
    ),
  ),
);

Future<List<List<int>>> _green(WidgetTester tester, {int width = 16, int height = 8}) async {
  final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
  final data = await tester.runAsync(() async {
    final img = await ro.toImage();
    return (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  });
  final w = ro.size.width.round();
  return [
    for (var y = 0; y < height; y++) [for (var x = 0; x < width; x++) data!.getUint8((y * w + x) * 4 + 1)],
  ];
}

Future<List<List<int>>> _blue(WidgetTester tester, {int width = 16, int height = 8}) async {
  final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
  final data = await tester.runAsync(() async {
    final img = await ro.toImage();
    return (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  });
  final w = ro.size.width.round();
  return [
    for (var y = 0; y < height; y++) [for (var x = 0; x < width; x++) data!.getUint8((y * w + x) * 4 + 2)],
  ];
}

void main() {
  RenderPictureTile tile({double? width, double? height, double? ratio, bool roundX = false, bool roundY = false}) =>
      RenderPictureTile(
        width: width,
        height: height,
        ratio: ratio,
        roundX: roundX,
        roundY: roundY,
        devicePixelRatio: 1,
      );

  test("an `auto` axis is the other through the picture's ratio, and both `auto` is contain", () {
    expect(tile(width: 8, ratio: 2).tileOf(const Size(100, 50)), const Rect.fromLTWH(0, 0, 8, 4));
    expect(tile(height: 3, ratio: 4).tileOf(const Size(100, 50)), const Rect.fromLTWH(0, 0, 12, 3));
    // A SaaS landing page's 4:1 viewBox in a 1px rule is 4x1.
    expect(tile(ratio: 4).tileOf(const Size(340, 1)), const Rect.fromLTWH(0, 0, 4, 1));
    expect(tile(ratio: 0.25).tileOf(const Size(10, 100)), const Rect.fromLTWH(0, 0, 10, 40));
    // No ratio: the box's own size on the axis the tile leaves.
    expect(tile(width: 8).tileOf(const Size(100, 50)), const Rect.fromLTWH(0, 0, 8, 50));
  });

  test('round: a whole number of tiles, the other axis scaled with it where it is auto', () {
    // 340 / 5.02 is 67.7: 68 tiles of 5.
    final r = tile(width: 5.02, height: 1, roundX: true, roundY: true).tileOf(const Size(340, 1));
    expect(r.width, closeTo(5, 1e-9));
    expect(r.height, 1);
    // 100 / 8 is 12.5: 13 tiles of 100 / 13, in Blink's 1/64 px the
    // remainder dropped (492 / 64), and the auto height keeps the tile's
    // 2:1.
    final s = tile(width: 8, ratio: 2, roundX: true).tileOf(const Size(100, 50));
    expect(s.width, 492 / 64);
    expect(s.height, 246 / 64);
    // A stated height is left as it is.
    expect(tile(width: 8, height: 4, roundX: true).tileOf(const Size(100, 50)).height, 4);
  });

  test("a tile a share of the box: that share on its axis, the picture's ratio on the other in 1/64 px", () {
    RenderPictureTile share({double? widthFactor, double? heightFactor, double? ratio, double x = 0, double dy = 0}) =>
        RenderPictureTile(
          widthFactor: widthFactor,
          heightFactor: heightFactor,
          ratio: ratio,
          x: x,
          dy: dy,
          devicePixelRatio: 1,
        );
    // An Indonesian news site's chevron: a 6 by 10 picture at `mask-size: 100%` of a 24px
    // link is 24 by 40, `50% -3px` laying it 3px up.
    expect(
      share(widthFactor: 1, ratio: 0.6, x: 0.5, dy: -3).tileOf(const Size(24, 24)),
      const Rect.fromLTWH(0, -3, 24, 40),
    );
    // 10 / 3 is 3.333: 213 / 64 in layout units, the rest dropped.
    expect(share(widthFactor: 1, ratio: 3).tileOf(const Size(10, 50)).height, 213 / 64);
    expect(share(heightFactor: 0.5, ratio: 2).tileOf(const Size(100, 50)), const Rect.fromLTWH(0, 0, 50, 25));
  });

  testWidgets('a hole: the colour where the picture is not, and all of the box past a tile laid once', (tester) async {
    tester.view.physicalSize = const Size(16, 8);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _page(
        const PictureTile(
          width: 4,
          height: 4,
          repeatX: false,
          repeatY: false,
          color: Color(0xFF0000FF),
          hole: true,
          child: CustomPaint(painter: _Square(Color(0xFFFF0000))),
        ),
      ),
    );
    final g = await _green(tester);
    // Blue (green 0) over the 12 by 8 box but the tile's lit 2x2 corner,
    // where the page shows (255), as it does past the box.
    const cut = [255, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 255];
    const full = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 255];
    expect(g, [cut, cut, full, full, full, full, full, full]);
  });

  testWidgets('by luminance each copy masks by how light it is times how opaque', (tester) async {
    tester.view.physicalSize = const Size(16, 8);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<List<int>> row(Color square) async {
      await tester.pumpWidget(
        _page(
          PictureTile(
            width: 4,
            height: 4,
            color: const Color(0xFF0000FF),
            luminance: true,
            child: CustomPaint(painter: _Square(square)),
          ),
        ),
      );
      return (await _green(tester))[0].sublist(0, 6);
    }

    // White keeps the colour, black keeps nothing, and white half opaque
    // is 128 of light over black: the colour at 128 / 255 over the page.
    expect(await row(const Color(0xFFFFFFFF)), [0, 0, 255, 255, 0, 0]);
    expect(await row(const Color(0xFF000000)), [255, 255, 255, 255, 255, 255]);
    final half = await row(const Color(0x80FFFFFF));
    expect(half[0], closeTo(127, 1));
    expect(half.sublist(2), [255, 255, half[0], half[0]]);
  });

  testWidgets('the picture is drawn once into the tile and repeated over the box', (tester) async {
    tester.view.physicalSize = const Size(16, 8);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _page(const PictureTile(width: 4, height: 4, child: CustomPaint(painter: _Square(Color(0xFFFF0000))))),
    );
    final g = await _green(tester);
    // Lit (green 0) in the top-left 2x2 of every 4x4 tile; the page white
    // (255) elsewhere and past the box at x = 12.
    const lit = [0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255, 255, 255, 255, 255, 255];
    const dark = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255];
    expect(g, [lit, lit, dark, dark, lit, lit, dark, dark]);
  });

  // css-backgrounds-3 3.4: `space` lays as many whole copies as the box
  // holds, the first and the last against its edges, the room left over
  // shared between them in 1/64 px, and reads no position -- unless fewer
  // than two fit, when the one tile is laid where the position puts it.
  test('a spaced tile: whole copies edge to edge, the position not read', () {
    RenderPictureTile spaced(double w, {double x = 0, double dx = 0}) =>
        RenderPictureTile(width: w, height: 4, x: x, dx: dx, spaceX: true, devicePixelRatio: 1);
    // 7px icons in 389.76: 55 copies, 4.76 over 54 gaps -- 5/64 each.
    expect(spaced(7).spacingOf(const Size(389.76, 8)), (5 / 64, null));
    expect(spaced(7, dx: 3).tileOf(const Size(389.76, 8)), const Rect.fromLTWH(0, 0, 7, 4));
    // One copy fits: laid where the position puts it.
    expect(spaced(8, x: 0.5).tileOf(const Size(12, 8)), const Rect.fromLTWH(2, 0, 8, 4));
    expect(spaced(8, x: 0.5).spacingOf(const Size(12, 8)), (null, null));
  });

  testWidgets('a spaced tile is repeated with the room between the copies', (tester) async {
    tester.view.physicalSize = const Size(16, 8);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // 5px tiles in 12, lit in their top-left 2.5 by 2: two copies, at 0
    // and 7, the 2px between them clear, the position (dx: 3) not read.
    await tester.pumpWidget(
      _page(
        const PictureTile(
          width: 5,
          height: 4,
          dx: 3,
          spaceX: true,
          child: CustomPaint(painter: _Square(Color(0xFFFF0000))),
        ),
      ),
    );
    final g = await _green(tester);
    expect(g[0].sublist(0, 2), [0, 0]);
    expect(g[0][2], inInclusiveRange(120, 135));
    expect(g[0].sublist(3, 7), [255, 255, 255, 255]);
    expect(g[0].sublist(7, 9), [0, 0]);
    expect(g[0][9], inInclusiveRange(120, 135));
    expect(g[0].sublist(10), [255, 255, 255, 255, 255, 255]);
    // Down, 4px tiles in 8 are two copies that abut, the second from 4.
    expect(g[4].sublist(0, 2), [0, 0]);
    expect(g[2].sublist(0, 2), [255, 255]);
  });

  testWidgets('no-repeat along x lays one column of tiles, placed by a share and a length', (tester) async {
    tester.view.physicalSize = const Size(16, 8);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // `background-position: 50% 1px` in a 12px box: the tile at x = 4,
    // and down 1px -- every copy with it, one laid above.
    await tester.pumpWidget(
      _page(
        const PictureTile(
          width: 4,
          height: 4,
          x: 0.5,
          dy: 1,
          repeatX: false,
          child: CustomPaint(painter: _Square(Color(0xFFFF0000))),
        ),
      ),
    );
    final g = await _green(tester);
    const lit = [255, 255, 255, 255, 0, 0, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255];
    const dark = [255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255];
    expect(g, [dark, lit, lit, dark, dark, lit, lit, dark]);
  });

  testWidgets('a mask colour paints the tiles in it, as opaque as the picture', (tester) async {
    tester.view.physicalSize = const Size(16, 8);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _page(
        const PictureTile(
          width: 4,
          height: 4,
          color: Color(0xFF0000FF),
          child: CustomPaint(painter: _Square(Color(0xFFFF0000))),
        ),
      ),
    );
    final b = await _blue(tester);
    final g = await _green(tester);
    // Blue where the picture is: blue 255 and green 0; the page white.
    expect(b[0].sublist(0, 4), [255, 255, 255, 255]);
    expect(g[0].sublist(0, 4), [0, 0, 255, 255]);
  });

  testWidgets('the tiles start and stop at the CSS pixels nearest the box edges', (tester) async {
    tester.view.physicalSize = const Size(16, 8);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The box at x = 2.5, 12 wide: Chrome tiles from 3 and cuts at 15.
    await tester.pumpWidget(
      _page(const PictureTile(width: 4, height: 4, child: CustomPaint(painter: _Square(Color(0xFFFF0000)))), left: 2.5),
    );
    final g = await _green(tester);
    expect(g[0], [255, 255, 255, 0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255, 255, 255]);
  });

  testWidgets('a picture that changes is drawn into the tile again', (tester) async {
    tester.view.physicalSize = const Size(16, 8);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _page(const PictureTile(width: 4, height: 4, child: CustomPaint(painter: _Square(Color(0xFFFF0000))))),
    );
    await tester.pumpWidget(
      _page(const PictureTile(width: 4, height: 4, child: CustomPaint(painter: _Square(Color(0xFF00FF00))))),
    );
    final g = await _green(tester);
    // Green 255 where the square is now green, and the page's 255 round
    // it: read blue, 0 in the square and 255 on the page.
    final b = await _blue(tester);
    expect(g[0].sublist(0, 2), [255, 255]);
    expect(b[0].sublist(0, 6), [0, 0, 255, 255, 0, 0]);
  });
}
