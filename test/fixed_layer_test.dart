import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart' show RenderFixedLayer;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A box with a plain proxy where the layer stands: the layer as it was
/// before it held to the window.
class _Unheld extends SingleChildRenderObjectWidget {
  const _Unheld({super.child});

  @override
  RenderProxyBox createRenderObject(BuildContext context) => RenderProxyBox();
}

void main() {
  const window = Size(400, 600);
  const red = Color(0xFFFF0000);
  final bar = GlobalKey(), row = GlobalKey(), boundary = GlobalKey();

  // A page of 30 rows 40 tall, the fourteenth pressable, under a fixed bottom
  // bar 50 tall: the bar at the window's foot (550 to 600) covers the
  // fourteenth row at scroll 0.
  Widget page({
    ScrollController? controller,
    bool reverse = false,
    bool scrolls = true,
    bool unheld = false,
    bool boundaryInside = false,
    List<String>? pressed,
  }) {
    Widget layer(Widget child) => unheld ? _Unheld(child: child) : FixedLayer(child: child);
    Widget fixed = layer(
      SizedBox.fromSize(
        size: window,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                key: bar,
                behavior: HitTestBehavior.opaque,
                onTap: () => pressed?.add('bar'),
                child: const SizedBox(height: 50, child: ColoredBox(color: red)),
              ),
            ),
          ],
        ),
      ),
    );
    if (boundaryInside) fixed = RepaintBoundary(child: fixed);
    final document = DocumentExtent(
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.passthrough,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < 30; i++)
                i == 13
                    ? GestureDetector(
                        key: row,
                        behavior: HitTestBehavior.opaque,
                        onTap: () => pressed?.add('row'),
                        child: const SizedBox(height: 40, child: ColoredBox(color: Color(0xFF00FF00))),
                      )
                    : SizedBox(height: 40, child: ColoredBox(color: Color(0xFF000000 + i * 0x070707))),
            ],
          ),
          Positioned(left: 0, top: 0, child: fixed),
        ],
      ),
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: window),
        child: RepaintBoundary(
          key: boundary,
          child: scrolls
              ? SingleChildScrollView(controller: controller, reverse: reverse, child: document)
              : OverflowBox(alignment: Alignment.topLeft, minHeight: 0, maxHeight: double.infinity, child: document),
        ),
      ),
    );
  }

  Future<void> view(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = window;
    addTearDown(tester.view.reset);
  }

  Future<Uint8List> pixels(WidgetTester tester) async {
    final r = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return (await tester.runAsync(() async {
      final im = await r.toImage();
      final b = await im.toByteData(format: ui.ImageByteFormat.rawRgba);
      im.dispose();
      return b!.buffer.asUint8List();
    }))!;
  }

  bool redAt(Uint8List px, int x, int y) {
    final i = (y * window.width.toInt() + x) * 4;
    return px[i] == 0xFF && px[i + 1] == 0 && px[i + 2] == 0;
  }

  testWidgets('a fixed bottom bar stays at the window foot as the page scrolls, drawn and pressed there', (
    tester,
  ) async {
    await view(tester);
    final controller = ScrollController();
    final pressed = <String>[];
    await tester.pumpWidget(page(controller: controller, pressed: pressed));
    expect(tester.getRect(find.byKey(bar)), const Rect.fromLTRB(0, 550, 400, 600));
    // The fourteenth row (520 to 560) is under the bar at scroll 0.
    await tester.tapAt(const Offset(200, 555));
    expect(pressed, ['bar']);

    controller.jumpTo(300);
    await tester.pump();
    expect(tester.getRect(find.byKey(bar)), const Rect.fromLTRB(0, 550, 400, 600));
    expect(tester.getRect(find.byKey(row)), const Rect.fromLTRB(0, 220, 400, 260));
    // The row the scroll brought out from under the bar takes its press,
    // and the bar takes the press at the window's foot.
    pressed.clear();
    await tester.tapAt(const Offset(200, 255));
    await tester.tapAt(const Offset(200, 575));
    expect(pressed, ['row', 'bar']);
    final px = await pixels(tester);
    expect(redAt(px, 200, 575), isTrue);
    expect(redAt(px, 200, 255), isFalse);
  });

  testWidgets('the bar is held though a repaint boundary stands between the page and it', (tester) async {
    await view(tester);
    final controller = ScrollController();
    await tester.pumpWidget(page(controller: controller, boundaryInside: true));
    controller.jumpTo(300);
    await tester.pump();
    final px = await pixels(tester);
    expect(redAt(px, 200, 575), isTrue);
    expect(redAt(px, 200, 255), isFalse);
  });

  testWidgets('NEGATIVE: unscrolled, the layer paints exactly as an unheld one', (tester) async {
    await view(tester);
    await tester.pumpWidget(page(controller: ScrollController()));
    final held = await pixels(tester);
    await tester.pumpWidget(page(controller: ScrollController(), unheld: true));
    final unheld = await pixels(tester);
    expect(held, unheld);
  });

  testWidgets('NEGATIVE: a layer in no scroll, or in one that runs up, stays where it is laid out', (tester) async {
    await view(tester);
    await tester.pumpWidget(page(scrolls: false));
    expect(tester.getRect(find.byKey(bar)), const Rect.fromLTRB(0, 550, 400, 600));
    expect(tester.renderObject<RenderFixedLayer>(find.byType(FixedLayer)).shift, Offset.zero);

    final controller = ScrollController();
    await tester.pumpWidget(page(controller: controller, reverse: true));
    controller.jumpTo(100);
    await tester.pump();
    expect(tester.renderObject<RenderFixedLayer>(find.byType(FixedLayer)).shift, Offset.zero);
  });
}
