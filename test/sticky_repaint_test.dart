// A STICKY BOX IS DRAWN AGAIN AS ITS SCROLL MOVES, under a layer cached
// between it and the view. Its shift is worked out where it is painted,
// and a scroll repaints its view: the view draws again whatever it holds,
// but a RepaintBoundary inside -- a developer's own, or a ListView's round
// each child -- hands back the picture it kept, moved whole, and the box in
// it stays where it was last drawn: it scrolls away with the page. Each
// sticky box now hears every scroll round it (`Sticky`, `RenderSticky
// .scrolls`), as a fixed layer hears its document's.
//
// NEGATIVE: a box taken out of the tree hears no more of the scroll it was
// in, which goes on scrolling.
import 'dart:ui' as ui;

import 'package:css_box/css_box.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _bar = Color(0xFFE53935);

/// The window's pixels, read through a boundary round the whole scene
/// (above every scroll in it).
Future<ui.Color> _pixel(WidgetTester tester, Offset at) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('window')));
  final bytes = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final width = image.width;
    image.dispose();
    final i = (at.dy.toInt() * width + at.dx.toInt()) * 4;
    return data!.buffer.asUint8List().sublist(i, i + 4);
  }))!;
  return ui.Color.fromARGB(bytes[3], bytes[0], bytes[1], bytes[2]);
}

Widget _window(Widget child) => RepaintBoundary(
  key: const ValueKey('window'),
  child: Directionality(textDirection: TextDirection.ltr, child: child),
);

/// A block 1000 tall with a 40px bar held to the top of its view.
Widget _block() => StickyBlock(
  child: SizedBox(
    height: 1000,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        Sticky(
          top: 0,
          child: SizedBox(height: 40, child: ColoredBox(color: _bar)),
        ),
      ],
    ),
  ),
);

ScrollPosition _position(WidgetTester tester, Axis axis) => tester
    .stateList<ScrollableState>(find.byType(Scrollable))
    .firstWhere((s) => axisDirectionToAxis(s.axisDirection) == axis)
    .position;

void main() {
  Future<void> view(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(200, 300)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('under a RepaintBoundary of its own page, the bar stays at the top of the window', (tester) async {
    await view(tester);
    await tester.pumpWidget(
      _window(
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 100),
              RepaintBoundary(child: _block()),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
    expect(await _pixel(tester, const Offset(10, 120)), _bar, reason: 'at rest, where it is laid out');
    _position(tester, Axis.vertical).jumpTo(300);
    await tester.pump();
    // Laid out 200 above the window now, drawn held at its top.
    expect(await _pixel(tester, const Offset(10, 20)), _bar);
    expect(tester.getTopLeft(find.byType(ColoredBox)).dy, 0);
  });

  testWidgets("in a ListView's child (a boundary round each), the bar stays at the top of the window", (tester) async {
    await view(tester);
    await tester.pumpWidget(
      _window(ListView(children: [const SizedBox(height: 100), _block(), const SizedBox(height: 2000)])),
    );
    _position(tester, Axis.vertical).jumpTo(300);
    await tester.pump();
    expect(await _pixel(tester, const Offset(10, 20)), _bar);
  });

  testWidgets('in a box that scrolls both ways, the bar is held across the outer of its two scrolls', (tester) async {
    await view(tester);
    await tester.pumpWidget(
      _window(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: 100,
            child: ClipBox(
              scrollsVertically: true,
              scrollsHorizontally: true,
              child: Spill(
                child: RepaintBoundary(
                  child: StickyBlock(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Sticky(
                          top: 0,
                          child: SizedBox(width: 200, height: 20, child: ColoredBox(color: _bar)),
                        ),
                        SizedBox(width: 200, height: 300),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // The vertical scroll is the outer one: the horizontal is the bar's own.
    _position(tester, Axis.vertical).jumpTo(150);
    await tester.pump();
    expect(await _pixel(tester, const Offset(10, 10)), _bar);
  });

  testWidgets('NEGATIVE: a bar taken out of the page hears no more of its scroll', (tester) async {
    await view(tester);
    Widget page(bool bar) => _window(
      SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 100),
            RepaintBoundary(child: bar ? _block() : const SizedBox(height: 1000)),
            const SizedBox(height: 2000),
          ],
        ),
      ),
    );
    await tester.pumpWidget(page(true));
    final sticky = tester.renderObject(find.byType(Sticky));
    await tester.pumpWidget(page(false));
    expect(sticky.attached, isFalse);
    _position(tester, Axis.vertical).jumpTo(300);
    await tester.pump();
    // A box disposed and still listening asserts as it is marked to paint.
    expect(tester.takeException(), isNull);
  });
}
