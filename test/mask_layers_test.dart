import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

// A 4px-wide tile lit in its first pixel: `linear-gradient(90deg, #000
// 1px, transparent 1px)` at `mask-size: 4px`.
const _stripe = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
  stops: [0, 0.25, 0.25],
);

// A layer half opaque everywhere.
const _half = LinearGradient(colors: [Color(0x80000000), Color(0x80000000)]);

Widget _page(List<MaskLayer> layers, {double left = 0}) => Directionality(
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
              child: MaskLayers(
                layers: layers,
                child: const ColoredBox(color: Color(0xFFFF0000)),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<List<int>> _greenRow(WidgetTester tester, int y) async {
  final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
  final data = await tester.runAsync(() async {
    final img = await ro.toImage();
    return (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  });
  return [for (var x = 0; x < 20; x++) data!.getUint8((y * 40 + x) * 4 + 1)];
}

void main() {
  test('a layer is laid out as a background: its tile, placed and rounded', () {
    const l = MaskLayer(gradient: _stripe, width: 5, height: 5, dx: 2, dy: 3);
    expect(l.tileOf(const Size(320, 100)), const Rect.fromLTWH(2, 3, 5, 5));
    const whole = MaskLayer(gradient: _half);
    expect(whole.tileOf(const Size(320, 100)), const Rect.fromLTWH(0, 0, 320, 100));
    const round = MaskLayer(gradient: _stripe, width: 5, roundX: true);
    // Three tiles of 16 / 3, in Blink's 1/64 px the remainder dropped.
    expect(round.tileOf(const Size(16, 4)).width, 341 / 64);
  });

  test('a tile that is a share of the box and a length', () {
    // A travel site's strip: `mask-size: calc(100% - 100px) 100%` at the corner,
    // and a 100px fade at the far edge (`mask-position: 100% 0`).
    const solid = MaskLayer(gradient: _half, width: -100, widthFraction: 1, repeatX: false);
    expect(solid.tileOf(const Size(320, 40)), const Rect.fromLTWH(0, 0, 220, 40));
    const fade = MaskLayer(gradient: _stripe, width: 100, x: 1, repeatX: false);
    expect(fade.tileOf(const Size(320, 40)), const Rect.fromLTWH(220, 0, 100, 40));
    // Never under nothing: a box narrower than the length.
    expect(solid.tileOf(const Size(60, 40)).width, 0);
    const half = MaskLayer(gradient: _half, heightFraction: 0.5, height: 4);
    expect(half.tileOf(const Size(320, 40)), const Rect.fromLTWH(0, 0, 320, 24));
  });

  testWidgets('each layer is over the ones after it: the stripe over a half-opaque layer', (tester) async {
    tester.view.physicalSize = const Size(40, 10);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_page(const [MaskLayer(gradient: _stripe, width: 4), MaskLayer(gradient: _half)]));
    final g = await _greenRow(tester, 1);
    // Red where the stripe is lit (green 0); half red over the white page
    // where only the second layer is (green about 127); the page past the
    // box (255).
    for (var x = 0; x < 16; x++) {
      if (x % 4 == 0) {
        expect(g[x], 0, reason: 'x = $x');
      } else {
        expect(g[x], inInclusiveRange(125, 130), reason: 'x = $x');
      }
    }
    expect(g.sublist(16), [255, 255, 255, 255]);
  });

  testWidgets('a layer laid once along x masks nothing past its one tile', (tester) async {
    tester.view.physicalSize = const Size(40, 10);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _page(const [
        MaskLayer(gradient: _stripe, width: 4, repeatX: false),
        MaskLayer(gradient: _stripe, width: 4, dx: 2),
      ]),
    );
    final g = await _greenRow(tester, 1);
    // The first layer's one tile lights x = 0; the second, moved on by 2,
    // lights 2, 6, 10 and 14.
    expect(g.sublist(0, 16), [0, 255, 0, 255, 255, 255, 0, 255, 255, 255, 0, 255, 255, 255, 0, 255]);
  });

  // css-masking-1 7.9: each layer meets the ones under it by its
  // `mask-composite` -- `intersect` source-in, `subtract` source-out,
  // `exclude` xor. The stripe lights the first quarter of its tile: 4px
  // tiles light 0 and 4, an 8px tile 0 and 1. Added, all three; kept
  // where both are lit (0); where the one under is not (4); where one is
  // and not the other (1 and 4).
  testWidgets('a layer meets the ones under it by its composite', (tester) async {
    tester.view.physicalSize = const Size(40, 10);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<List<int>> row(BlendMode mode) async {
      await tester.pumpWidget(
        _page([MaskLayer(gradient: _stripe, width: 4, composite: mode), const MaskLayer(gradient: _stripe, width: 8)]),
      );
      return (await _greenRow(tester, 1)).sublist(0, 8);
    }

    expect(await row(BlendMode.srcOver), [0, 0, 255, 255, 0, 255, 255, 255]);
    expect(await row(BlendMode.srcIn), [0, 255, 255, 255, 255, 255, 255, 255]);
    expect(await row(BlendMode.srcOut), [255, 255, 255, 255, 0, 255, 255, 255]);
    expect(await row(BlendMode.xor), [255, 0, 255, 255, 0, 255, 255, 255]);
    // The bottom layer's own composite has nothing to meet.
    await tester.pumpWidget(_page(const [MaskLayer(gradient: _half, composite: BlendMode.srcIn)]));
    expect((await _greenRow(tester, 1)).sublist(0, 4), everyElement(inInclusiveRange(125, 130)));
    // A layer of no tile, intersected, leaves nothing.
    await tester.pumpWidget(
      _page(const [MaskLayer(gradient: _stripe, width: 0, composite: BlendMode.srcIn), MaskLayer(gradient: _half)]),
    );
    expect((await _greenRow(tester, 1)).sublist(0, 8), List.filled(8, 255));
  });

  // css-backgrounds-3 3.4: `space` lays as many whole copies as the box
  // holds, the first and the last against its edges, the room left over
  // shared between them in 1/64 px, and reads no position -- unless fewer
  // than two fit, when the one tile is laid where the position puts it.
  test('a spaced tile: whole copies edge to edge, the position not read', () {
    // The travel site's start fade: 100px at -100px, `space`d along a 1408px
    // strip -- 14 copies, 8px shared over 13 gaps (39/64 each).
    const fade = MaskLayer(gradient: _stripe, width: 100, dx: -100, repeatX: false, spaceX: true);
    expect(fade.tileOf(const Size(1408, 40)), const Rect.fromLTWH(0, 0, 100, 40));
    expect(fade.spacingOf(const Size(1408, 40)), (39 / 64, null));
    // A share: a 45% tile holds twice whatever the box.
    const share = MaskLayer(
      gradient: _half,
      widthFraction: 0.45,
      heightFraction: 0.45,
      x: 0.5,
      y: 0.5,
      spaceX: true,
      spaceY: true,
    );
    expect(share.tileOf(const Size(200, 120)), const Rect.fromLTWH(0, 0, 90, 54));
    expect(share.spacingOf(const Size(200, 120)), (20.0, 12.0));
    // One copy fits: laid where the position puts it.
    const once = MaskLayer(gradient: _stripe, width: 100, x: 0.5, spaceX: true);
    expect(once.tileOf(const Size(150, 40)), const Rect.fromLTWH(25, 0, 100, 40));
    expect(once.spacingOf(const Size(150, 40)), (null, null));
  });

  testWidgets('a spaced tile is repeated with the room between the copies', (tester) async {
    tester.view.physicalSize = const Size(40, 10);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const solid = LinearGradient(colors: [Color(0xFF000000), Color(0xFF000000)]);
    // 6px tiles in 16: two copies, at 0 and 10, the 4px between them clear;
    // the position (dx: 3) not read.
    await tester.pumpWidget(_page(const [MaskLayer(gradient: solid, width: 6, dx: 3, repeatX: false, spaceX: true)]));
    expect((await _greenRow(tester, 1)).sublist(0, 16), [0, 0, 0, 0, 0, 0, 255, 255, 255, 255, 0, 0, 0, 0, 0, 0]);
    // 10px tiles in 16: one copy, laid once where dx puts it.
    await tester.pumpWidget(_page(const [MaskLayer(gradient: solid, width: 10, dx: 3, repeatX: false, spaceX: true)]));
    expect((await _greenRow(tester, 1)).sublist(0, 16), [255, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255]);
  });

  // css-masking-1 7.6, 7.7: a layer whose `mask-origin` and `mask-clip`
  // are an inner box is laid out in it and cut to it, and is transparent
  // past it.
  testWidgets('a layer in an inner box is laid out in it and composites nothing past it', (tester) async {
    tester.view.physicalSize = const Size(40, 10);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const solid = LinearGradient(colors: [Color(0xFF000000), Color(0xFF000000)]);
    const inner = EdgeInsets.symmetric(horizontal: 4);
    bool half(int v) => v >= 125 && v <= 130;
    // A half-opaque layer added over an opaque one 4px in: all of the
    // inner box, half of the rest.
    await tester.pumpWidget(_page(const [MaskLayer(gradient: _half), MaskLayer(gradient: solid, inset: inner)]));
    var g = (await _greenRow(tester, 1)).sublist(0, 16);
    expect(g.sublist(4, 12), List.filled(8, 0));
    expect([...g.sublist(0, 4), ...g.sublist(12)].every(half), isTrue, reason: '$g');
    // Intersected, the inner layer composites only inside its box: past it
    // the layer under it stands as it is (Chrome, measured:
    // fixtures/mask-origin-clip-box p5), half all along.
    await tester.pumpWidget(
      _page(const [MaskLayer(gradient: solid, inset: inner, composite: BlendMode.srcIn), MaskLayer(gradient: _half)]),
    );
    g = (await _greenRow(tester, 1)).sublist(0, 16);
    expect(g.every(half), isTrue, reason: '$g');
    // And subtracted from an opaque layer: nothing inside its box, all of
    // the layer under it past it.
    await tester.pumpWidget(
      _page(const [MaskLayer(gradient: _half, inset: inner, composite: BlendMode.srcOut), MaskLayer(gradient: solid)]),
    );
    g = (await _greenRow(tester, 1)).sublist(0, 16);
    expect(g.sublist(4, 12), List.filled(8, 255));
    expect([...g.sublist(0, 4), ...g.sublist(12)], List.filled(8, 0));
    // A tile is laid from the inner box's corner: the 4px stripe lit at
    // 2, 6, 10 and 14, and nothing before 2.
    await tester.pumpWidget(_page(const [MaskLayer(gradient: _stripe, width: 4, inset: EdgeInsets.only(left: 2))]));
    expect((await _greenRow(tester, 1)).sublist(0, 16), [
      255,
      255,
      0,
      255,
      255,
      255,
      0,
      255,
      255,
      255,
      0,
      255,
      255,
      255,
      0,
      255,
    ]);
  });

  // css-backgrounds-3 3.7, 3.8: a layer laid out in one box and cut to
  // another -- `mask-origin: content-box` under `mask-clip: border-box` --
  // is placed in the first and shows as far as the second reaches.
  // The travel site's strips padded 12px at each end (fixtures/mask-layers-share m5).
  testWidgets('a layer laid out in an inner box and cut to the border box shows past the inner box', (tester) async {
    tester.view.physicalSize = const Size(40, 10);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const solid = LinearGradient(colors: [Color(0xFF000000), Color(0xFF000000)]);
    // A 4px tile laid once 3px before a box 4px in: 1 to 5 of the border
    // box, all of it shown when cut to the border box ...
    await tester.pumpWidget(
      _page(const [
        MaskLayer(
          gradient: solid,
          width: 4,
          dx: -3,
          repeatX: false,
          inset: EdgeInsets.only(left: 4),
          clip: EdgeInsets.zero,
        ),
      ]),
    );
    expect((await _greenRow(tester, 1)).sublist(0, 8), [255, 0, 0, 0, 0, 255, 255, 255]);
    // ... and only from 4 on when cut to the box it is laid out in.
    await tester.pumpWidget(
      _page(const [MaskLayer(gradient: solid, width: 4, dx: -3, repeatX: false, inset: EdgeInsets.only(left: 4))]),
    );
    expect((await _greenRow(tester, 1)).sublist(0, 8), [255, 255, 255, 255, 0, 255, 255, 255]);
    // A repeated tile goes on into the border box: the stripe laid from 2
    // lights 2, 6, 10 and 14 -- and cut to the content box 12 in from the
    // right, not 14.
    await tester.pumpWidget(
      _page(const [
        MaskLayer(gradient: _stripe, width: 4, inset: EdgeInsets.only(left: 2), clip: EdgeInsets.only(right: 4)),
      ]),
    );
    expect((await _greenRow(tester, 1)).sublist(0, 16), [
      255,
      255,
      0,
      255,
      255,
      255,
      0,
      255,
      255,
      255,
      0,
      255,
      255,
      255,
      255,
      255,
    ]);
  });

  // css-backgrounds-3 5.3, 5.5: a box the layer is cut to inside ROUND
  // corners has the border edge's corners less the frame on their two
  // sides -- after the border edge's are scaled back together to fit the
  // box (fixtures/mask-origin-clip-box n7, mask-clip-round-inner).
  test("the box a layer is cut to has the border edge's corners less the frame, scaled back first", () {
    const solid = LinearGradient(colors: [Color(0xFF000000), Color(0xFF000000)]);
    // 60px corners on a box 100 wide: scaled back by 100/120 to 50, then
    // the right side's 20px frame off the two on the right.
    const l = MaskLayer(
      gradient: solid,
      inset: EdgeInsets.only(right: 20),
      corners: BorderRadius.all(Radius.circular(60)),
    );
    final r = l.cutOf(const Rect.fromLTRB(0, 0, 80, 200), const Size(100, 200));
    expect((r.tlRadiusX, r.tlRadiusY), (50, 50));
    expect((r.trRadiusX, r.trRadiusY), (30, 50));
    expect((r.brRadiusX, r.blRadiusX), (30, 50));
    // A corner no rounder than the frame beside it is square.
    const m = MaskLayer(gradient: solid, inset: EdgeInsets.all(12), corners: BorderRadius.all(Radius.circular(12)));
    expect(m.cutOf(const Rect.fromLTRB(12, 12, 88, 188), const Size(100, 200)).isRect, isTrue);
    // NEGATIVE: no corners, a rect.
    const n = MaskLayer(gradient: solid, inset: EdgeInsets.all(12));
    expect(n.cutOf(const Rect.fromLTRB(12, 12, 88, 188), const Size(100, 200)).isRect, isTrue);
  });

  testWidgets('a layer cut to a box with round corners masks out past them', (tester) async {
    tester.view.physicalSize = const Size(40, 30);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const solid = LinearGradient(colors: [Color(0xFF000000), Color(0xFF000000)]);
    Future<int> green(MaskLayer l, int x, int y) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(devicePixelRatio: 1),
            child: RepaintBoundary(
              key: const Key('shot'),
              child: ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 40,
                    height: 30,
                    child: MaskLayers(
                      layers: [l],
                      child: const ColoredBox(color: Color(0xFFFF0000)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
      final data = await tester.runAsync(() async {
        final img = await ro.toImage();
        return (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      });
      return data!.getUint8((y * 40 + x) * 4 + 1);
    }

    // 15px corners round a 5px frame: the box it is cut to is 5..35 by
    // 5..25 with corners of 10, and its corner pixel is past the curve.
    const round = MaskLayer(gradient: solid, inset: EdgeInsets.all(5), corners: BorderRadius.all(Radius.circular(15)));
    expect(await green(round, 6, 6), 255, reason: 'past the corner: masked out, the white under it');
    expect(await green(round, 15, 15), 0, reason: 'inside: the red box');
    expect(await green(round, 6, 15), 0, reason: 'along the side, inside');
    expect(await green(round, 2, 15), 255, reason: 'in the frame: outside the box it is cut to');
    // NEGATIVE: with no corners the box is square, its corner pixel kept.
    expect(await green(const MaskLayer(gradient: solid, inset: EdgeInsets.all(5)), 6, 6), 0);
  });

  testWidgets('the layers start at the CSS pixel nearest the box corner', (tester) async {
    tester.view.physicalSize = const Size(40, 10);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The box at x = 2.5: the tiles from 3, not 2.5 -- from 2.5 the 1px
    // stripes would light half of 3 and half of 4. The 4px layer lights 3
    // and 7; the 8px one under it, lit in its first quarter, 3 and 4.
    await tester.pumpWidget(
      _page(const [MaskLayer(gradient: _stripe, width: 4), MaskLayer(gradient: _stripe, width: 8)], left: 2.5),
    );
    final g = await _greenRow(tester, 1);
    expect([g[3], g[4], g[5], g[6], g[7], g[8]], [0, 0, 255, 255, 0, 255]);
  });
}
