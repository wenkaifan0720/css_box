import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';

// A 4px-wide tile lit in its first pixel: `linear-gradient(90deg, #fff
// 1px, transparent 1px)` at `mask-size: 4px`, over a red box.
const _stripe = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00000000)],
  stops: [0, 0.25, 0.25],
);

Widget _page({double left = 0}) => Directionality(
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
            child: SizedBox(
              width: 16,
              height: 4,
              child: TileMask(
                gradient: _stripe,
                width: 4,
                child: const ColoredBox(color: Color(0xFFFF0000)),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  RenderTileMask mask({
    double? width,
    double? height,
    double dx = 0,
    double dy = 0,
    bool roundX = false,
    bool roundY = false,
  }) => RenderTileMask(
    gradient: _stripe,
    width: width,
    height: height,
    dx: dx,
    dy: dy,
    roundX: roundX,
    roundY: roundY,
    devicePixelRatio: 1,
  );

  test('a length moves the first tile, and every copy with it', () {
    expect(mask(width: 5, height: 5, dx: 2, dy: 3).tileOf(const Size(320, 100)), const Rect.fromLTWH(2, 3, 5, 5));
  });

  test('round: as many whole tiles as come nearest, resized to fit', () {
    // 16 / 5 is 3.2: three tiles of 16 / 3, in Blink's 1/64 px the
    // remainder dropped: 341 / 64.
    final r = mask(width: 5, height: 5, roundX: true, roundY: true).tileOf(const Size(16, 13));
    expect(r.width, 341 / 64);
    // 13 / 5 is 2.6: three tiles of 13 / 3, which is 277 / 64.
    expect(r.height, 277 / 64);
    // A tile that divides the box is left as it is.
    expect(mask(width: 5, height: 5, roundX: true).tileOf(const Size(320, 100)).width, 5);
    // A box smaller than half a tile still holds one, the box's size.
    expect(mask(width: 5, roundX: true).tileOf(const Size(2, 4)).width, 2);
  });

  test('a ratio alone is contained in the box', () {
    RenderTileMask contained() => RenderTileMask(gradient: _stripe, ratio: 16 / 88, devicePixelRatio: 1);
    // A SaaS landing page's progress line: a 16 by 88 picture in a box 16 wide.
    expect(contained().tileOf(const Size(16, 120)), const Rect.fromLTWH(0, 0, 16, 88));
    // A short box holds a smaller tile, 44 tall and 8 wide, two across.
    expect(contained().tileOf(const Size(16, 44)), const Rect.fromLTWH(0, 0, 8, 44));
  });

  testWidgets('the tile repeats over the box and keeps only where it is lit', (tester) async {
    tester.view.physicalSize = const Size(40, 10);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_page());
    // Red where the tile keeps it (255), the white page where it does not.
    // Green/blue channels tell red from white; the red channel is 255 in
    // both, so read green.
    final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
    final data = await tester.runAsync(() async {
      final img = await ro.toImage();
      return (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });
    List<int> green(int y) => [for (var x = 0; x < 20; x++) data!.getUint8((y * 40 + x) * 4 + 1)];
    // Columns 0, 4, 8, 12 are kept (green 0); the rest and past the box
    // are white (255).
    expect(green(1), [0, 255, 255, 255, 0, 255, 255, 255, 0, 255, 255, 255, 0, 255, 255, 255, 255, 255, 255, 255]);
  });

  testWidgets('the tile starts at the device pixel nearest the box corner', (tester) async {
    tester.view.physicalSize = const Size(40, 10);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The box at x = 2.5: Chrome tiles from 3, and so does this.
    await tester.pumpWidget(_page(left: 2.5));
    final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
    final data = await tester.runAsync(() async {
      final img = await ro.toImage();
      return (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });
    final green = [for (var x = 0; x < 12; x++) data!.getUint8((1 * 40 + x) * 4 + 1)];
    expect(green[3], 0);
    expect(green[7], 0);
    expect(green[4], 255);
    expect(green[2], isNot(0));
  });
}
