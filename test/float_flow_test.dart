import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The test font sets every glyph one em wide: at 10px, 'aaaa bbbb cccc' is
// 140 wide, and twelve such words are 590.
const _words = 'aaaa bbbb cccc dddd eeee ffff gggg hhhh iiii jjjj kkkk llll';
const _style = TextStyle(fontFamily: 'FlutterTest', fontSize: 10, height: 1, color: Color(0xFF000000));

Rect _at(GlobalKey k) {
  final box = k.currentContext!.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

Future<void> _pump(WidgetTester t, Widget child, {double? width = 200}) {
  t.view.physicalSize = const Size(800, 600);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  return t.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: width == null ? child : SizedBox(width: width, child: child),
      ),
    ),
  );
}

RenderFloatText _text(WidgetTester tester, [int i = 0]) =>
    tester.renderObjectList<RenderFloatText>(find.byType(FloatText)).elementAt(i);

Size _flow(WidgetTester tester) => tester.renderObjectList<RenderBox>(find.byType(FloatFlow)).first.size;

/// Inter as `Fx`, and as `FxGap` with a line gap of half an em in `hhea`
/// and `OS/2` (Inter's own is none).
Future<void> _loadGapFaces() async {
  final plain = File('test/fonts/Inter.ttf').readAsBytesSync();
  await (FontLoader('Fx')..addFont(Future.value(ByteData.view(Uint8List.fromList(plain).buffer)))).load();
  final bytes = Uint8List.fromList(plain);
  final v = ByteData.view(bytes.buffer);
  for (var i = 0; i < v.getUint16(4); i++) {
    final rec = 12 + 16 * i;
    final tag = String.fromCharCodes(bytes.sublist(rec, rec + 4));
    final at = v.getUint32(rec + 8);
    if (tag == 'hhea') v.setInt16(at + 8, 1024);
    if (tag == 'OS/2') v.setInt16(at + 72, 1024);
  }
  await (FontLoader('FxGap')..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
}

void main() {
  group('blocks and floats', () {
    testWidgets('a float leaves the stack and the blocks after it run under it', (tester) async {
      final f = GlobalKey(), a = GlobalKey(), b = GlobalKey();
      await _pump(
        tester,
        FloatFlow(
          children: [
            FloatSlot(
              float: FloatSide.left,
              width: 60,
              height: 80,
              child: SizedBox(key: f),
            ),
            FloatSlot(height: 20, child: SizedBox(key: a)),
            FloatSlot(height: 20, child: SizedBox(key: b)),
          ],
        ),
      );
      expect(_at(f), const Rect.fromLTWH(0, 0, 60, 80));
      // A plain block keeps its width and its place: only its LINES shorten.
      expect(_at(a), const Rect.fromLTWH(0, 0, 200, 20));
      expect(_at(b), const Rect.fromLTWH(0, 20, 200, 20));
      // The root of the context holds its floats (CSS 2.1 10.6.7).
      expect(_flow(tester), const Size(200, 80));
    });

    testWidgets('a formatting context of its own narrows into the room beside a float', (tester) async {
      final f = GlobalKey(), a = GlobalKey();
      await _pump(
        tester,
        FloatFlow(
          children: [
            FloatSlot(
              float: FloatSide.left,
              width: 60,
              height: 80,
              child: SizedBox(key: f),
            ),
            FloatSlot(bfc: true, height: 20, child: SizedBox(key: a)),
          ],
        ),
      );
      expect(_at(a), const Rect.fromLTWH(60, 0, 140, 20));
    });

    testWidgets('a context of its own too wide for the room goes down past the float', (tester) async {
      final a = GlobalKey();
      await _pump(
        tester,
        FloatFlow(
          children: [
            FloatSlot(
              float: FloatSide.left,
              width: 150,
              height: 40,
              child: SizedBox(key: GlobalKey()),
            ),
            FloatSlot(bfc: true, width: 100, height: 20, child: SizedBox(key: a)),
          ],
        ),
      );
      expect(_at(a), const Rect.fromLTWH(0, 40, 100, 20));
    });

    testWidgets('the floats paint over the blocks of the flow, and a lifted block over the floats', (tester) async {
      // CSS 2.1 Appendix E: in-flow blocks' backgrounds (step 4), then the
      // floats (5), then the positioned boxes (8) -- whatever order the
      // document puts them in. A plain block under a float before it hid
      // the float (`fixtures/float-beside-bfc` b9).
      const block = Color(0xFF0000FF), float = Color(0xFF00FF00);
      final hits = <String>[];
      Widget flow({required bool lifted}) => FloatFlow(
        children: [
          FloatSlot(
            float: FloatSide.left,
            width: 60,
            height: 40,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => hits.add('float'),
              child: const ColoredBox(color: float),
            ),
          ),
          FloatSlot(
            height: 20,
            lifted: lifted,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => hits.add('block'),
              child: const ColoredBox(color: block),
            ),
          ),
        ],
      );
      await _pump(tester, flow(lifted: false));
      expect(
        tester.renderObject(find.byType(FloatFlow)),
        paints
          ..rect(color: block)
          ..rect(color: float),
      );
      await tester.tapAt(const Offset(10, 10));
      expect(hits, ['float']);
      hits.clear();
      await _pump(tester, flow(lifted: true));
      expect(
        tester.renderObject(find.byType(FloatFlow)),
        paints
          ..rect(color: float)
          ..rect(color: block),
      );
      await tester.tapAt(const Offset(10, 10));
      expect(hits, ['block']);
    });

    testWidgets("a block's own float paints over the blocks after it; NEGATIVE: one inside a layer of its own", (
      tester,
    ) async {
      // Step 5 of Appendix E is the stacking context's: the float of a
      // block in this context paints over the background of the next block
      // (`fixtures/float-held-by-its-line`: a 50px arrow in a 32px row).
      const first = Color(0xFF0000FF), next = Color(0xFFFF0000), float = Color(0xFF00FF00);
      Widget flow(Widget Function(Widget) frame, {bool lifted = false}) => FloatFlow(
        children: [
          FloatSlot(
            lifted: lifted,
            child: frame(
              ColoredBox(
                color: first,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: FloatFlow(
                    nested: true,
                    children: [
                      FloatSlot(
                        float: FloatSide.right,
                        width: 20,
                        height: 50,
                        child: const ColoredBox(color: float),
                      ),
                      const FloatSlot(height: 20, child: SizedBox()),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const FloatSlot(height: 40, child: ColoredBox(color: next)),
        ],
      );
      RenderObject root() => tester.renderObjectList(find.byType(FloatFlow)).first;
      await _pump(tester, flow((w) => w));
      expect(
        root(),
        paints
          ..rect(color: first)
          ..rect(color: next)
          ..rect(color: float),
      );
      // Under an opacity the float is the opacity's, painted inside it.
      await _pump(tester, flow((w) => Opacity(opacity: 1, child: w)));
      expect(
        root(),
        paints
          ..rect(color: first)
          ..rect(color: float)
          ..rect(color: next),
      );
      // Painted through again, where it was.
      await _pump(tester, flow((w) => w));
      expect(
        root(),
        paints
          ..rect(color: first)
          ..rect(color: next)
          ..rect(rect: const Rect.fromLTWH(178, 2, 20, 50), color: float),
      );
      // A lifted box -- `position: relative` -- paints after the flow's
      // blocks, as a context of its own, and its float with it
      // (`fixtures/float-pin-box`).
      await _pump(tester, flow((w) => w, lifted: true));
      expect(
        root(),
        paints
          ..rect(color: next)
          ..rect(color: first)
          ..rect(color: float),
      );
    });

    testWidgets('a max-content context of its own fits by its content, not by the room beside the float', (
      tester,
    ) async {
      // CSS 2.1 9.5 with 10.3.9: 'aaaa bbbb' is 90 wide whatever the room,
      // so it goes down past a float that leaves 50; 'aaaa' is 40 and
      // stands beside it.
      final a = GlobalKey(), b = GlobalKey();
      Widget flow(String words, GlobalKey k) => FloatFlow(
        children: [
          FloatSlot(
            float: FloatSide.left,
            width: 150,
            height: 40,
            child: SizedBox(key: GlobalKey()),
          ),
          FloatSlot(
            bfc: true,
            widthKeyword: FloatWidth.maxContent,
            child: Text(words, key: k, style: _style),
          ),
        ],
      );
      await _pump(tester, flow('aaaa bbbb', a));
      expect(_at(a), const Rect.fromLTWH(0, 40, 90, 10));
      await _pump(tester, flow('aaaa', b));
      expect(_at(b), const Rect.fromLTWH(150, 0, 40, 10));
    });

    testWidgets("a min-content floor holds a block at its content's width in a narrower room", (tester) async {
      // A `<fieldset>` is `min-width: min-content`: 'aaaaaaaa' is 80 wide
      // at the least, so in a 50px flow the block is 80, not 50; in a 200px
      // one the floor does not bind and the block is the room.
      final a = GlobalKey();
      Widget flow() => FloatFlow(
        children: [
          FloatSlot(
            bfc: true,
            minWidthKeyword: FloatWidth.minContent,
            child: SizedBox(
              key: a,
              child: const Text('aaaaaaaa bb', style: _style),
            ),
          ),
        ],
      );
      await _pump(tester, flow(), width: 50);
      expect(_at(a).width, 80);
      await _pump(tester, flow(), width: 200);
      expect(_at(a).width, 200);
    });

    testWidgets('a cleared box starts below the floats on the side it names', (tester) async {
      final f = GlobalKey(), a = GlobalKey(), b = GlobalKey();
      await _pump(
        tester,
        FloatFlow(
          children: [
            FloatSlot(
              float: FloatSide.right,
              width: 60,
              height: 80,
              child: SizedBox(key: f),
            ),
            FloatSlot(
              clear: FloatClear.left,
              height: 20,
              child: SizedBox(key: b),
            ),
            FloatSlot(
              clear: FloatClear.right,
              height: 20,
              child: SizedBox(key: a),
            ),
          ],
        ),
      );
      expect(_at(f), const Rect.fromLTWH(140, 0, 60, 80));
      // Nothing floats left: `clear: left` clears nothing.
      expect(_at(b), const Rect.fromLTWH(0, 0, 200, 20));
      // Its top margin, collapsed, would not be past the float: clearance
      // puts its border edge at the float's bottom (CSS 2.1 9.5.2).
      expect(_at(a), const Rect.fromLTWH(0, 80, 200, 20));
    });

    testWidgets('adjoining margins collapse into the one gap between two blocks', (tester) async {
      final a = GlobalKey(), b = GlobalKey();
      await _pump(
        tester,
        FloatFlow(
          children: [
            FloatSlot(
              float: FloatSide.left,
              width: 10,
              height: 10,
              child: SizedBox(key: GlobalKey()),
            ),
            FloatSlot(
              height: 20,
              margin: const EdgeInsets.only(bottom: 30),
              child: SizedBox(key: a),
            ),
            FloatSlot(
              height: 20,
              margin: const EdgeInsets.only(top: 10),
              child: SizedBox(key: b),
            ),
          ],
        ),
      );
      // 30 against 10 is one gap of 30, not two of 40 (CSS 2.1 8.3.1).
      expect(_at(a).top, 0);
      expect(_at(b).top, 50);
    });

    testWidgets('margins collapse through a block with nothing in it', (tester) async {
      final a = GlobalKey(), b = GlobalKey();
      await _pump(
        tester,
        FloatFlow(
          children: [
            FloatSlot(
              height: 20,
              margin: const EdgeInsets.only(bottom: 10),
              child: SizedBox(key: a),
            ),
            const FloatSlot(margin: EdgeInsets.only(top: 30, bottom: 5), child: SizedBox.shrink()),
            FloatSlot(
              height: 20,
              margin: const EdgeInsets.only(top: 15),
              child: SizedBox(key: b),
            ),
          ],
        ),
      );
      expect(_at(b).top, 50);
      expect(_flow(tester).height, 70);
    });

    testWidgets('a negative margin pulls the next block up', (tester) async {
      final b = GlobalKey();
      await _pump(
        tester,
        FloatFlow(
          children: [
            FloatSlot(
              height: 20,
              margin: const EdgeInsets.only(bottom: 10),
              child: SizedBox(key: GlobalKey()),
            ),
            FloatSlot(
              height: 20,
              margin: const EdgeInsets.only(top: -15),
              child: SizedBox(key: b),
            ),
          ],
        ),
      );
      // 10 and -15 collapse to -5.
      expect(_at(b).top, 15);
    });

    testWidgets('auto margins across centre a block', (tester) async {
      final a = GlobalKey(), b = GlobalKey();
      await _pump(
        tester,
        FloatFlow(
          children: [
            FloatSlot(width: 100, height: 10, autoLeft: true, autoRight: true, child: SizedBox(key: a)),
            FloatSlot(width: 100, height: 10, autoLeft: true, child: SizedBox(key: b)),
          ],
        ),
      );
      expect(_at(a), const Rect.fromLTWH(50, 0, 100, 10));
      expect(_at(b), const Rect.fromLTWH(100, 10, 100, 10));
    });

    testWidgets('a share of the container is a width and a margin the stack resolves', (tester) async {
      final a = GlobalKey(), b = GlobalKey();
      await _pump(
        tester,
        FloatFlow(
          children: [
            FloatSlot(
              float: FloatSide.left,
              widthFraction: 0.25,
              height: 20,
              child: SizedBox(key: a),
            ),
            FloatSlot(
              float: FloatSide.left,
              widthFraction: 0.25,
              height: 20,
              marginShare: const EdgeInsets.only(left: 0.1),
              child: SizedBox(key: b),
            ),
          ],
        ),
        width: 400,
      );
      expect(_at(a), const Rect.fromLTWH(0, 0, 100, 20));
      expect(_at(b), const Rect.fromLTWH(140, 0, 100, 20));
    });

    testWidgets('a clamp of a share and a length is their sum, of the content box where it says so', (tester) async {
      // An events site's cookie banner heading: `max-width: calc(100% - 75px);
      // padding-left: 15px` at content-box, 400 wide: 325 inside, 340 out.
      final a = GlobalKey(), b = GlobalKey();
      await _pump(
        tester,
        FloatFlow(
          children: [
            FloatSlot(
              float: FloatSide.left,
              width: 390,
              maxWidth: -75,
              maxWidthFraction: 1,
              contentBox: true,
              frame: const EdgeInsets.only(left: 15),
              height: 20,
              child: SizedBox(key: a),
            ),
            FloatSlot(
              float: FloatSide.left,
              minWidth: 20,
              minWidthFraction: 0.5,
              height: 20,
              child: SizedBox(key: b),
            ),
          ],
        ),
        width: 400,
      );
      expect(_at(a).width, 340);
      // `min-width: calc(50% + 20px)`: 220 of 400, under the first.
      expect(_at(b).width, 220);
    });

    testWidgets('a cap at the larger of two holds the float to whichever is wider in the box', (tester) async {
      // `float: left; max-width: max(50%, 200px)` round words wider than
      // both: 200 in a 300px box, half of a 600px one; of the content box,
      // the frame round it, where it says so.
      for (final (width, want) in const [(300.0, 200.0), (600.0, 300.0)]) {
        final a = GlobalKey(), b = GlobalKey();
        await _pump(
          tester,
          FloatFlow(
            children: [
              FloatSlot(
                float: FloatSide.left,
                maxWidthFraction: 0.5,
                maxWidthOther: 200,
                child: Text(_words, key: a, style: _style),
              ),
              FloatSlot(
                float: FloatSide.left,
                clear: FloatClear.both,
                maxWidthFraction: 0.5,
                maxWidthOther: 200,
                contentBox: true,
                frame: const EdgeInsets.only(left: 15),
                child: Padding(
                  padding: const EdgeInsets.only(left: 15),
                  child: Text(_words, key: b, style: _style),
                ),
              ),
            ],
          ),
          width: width,
        );
        expect(_at(a).width, want, reason: '$width');
        expect(_at(b).width, want, reason: '$width');
        expect(_at(b).left, 15, reason: '$width');
      }
      // A box of no width yet measures the float as if uncapped: the whole
      // cap is none (css-sizing-3 5.2.1) -- and laid out at the 290 that
      // comes to, the float is held to the larger arm of THAT, 200.
      final c = GlobalKey();
      await _pump(
        tester,
        IntrinsicWidth(
          child: FloatFlow(
            children: [
              FloatSlot(
                float: FloatSide.left,
                maxWidthFraction: 0.5,
                maxWidthOther: 200,
                child: Text('aaaa bbbb cccc dddd eeee ffff', key: c, style: _style),
              ),
            ],
          ),
        ),
        width: null,
      );
      expect(_flow(tester).width, 290);
      expect(_at(c).width, 200);
    });

    testWidgets('floats that do not fit beside each other go under', (tester) async {
      final a = GlobalKey(), b = GlobalKey(), c = GlobalKey();
      await _pump(
        tester,
        FloatFlow(
          children: [
            FloatSlot(
              float: FloatSide.left,
              width: 120,
              height: 30,
              child: SizedBox(key: a),
            ),
            FloatSlot(
              float: FloatSide.right,
              width: 60,
              height: 20,
              child: SizedBox(key: b),
            ),
            FloatSlot(
              float: FloatSide.left,
              width: 100,
              height: 10,
              child: SizedBox(key: c),
            ),
          ],
        ),
      );
      expect(_at(a), const Rect.fromLTWH(0, 0, 120, 30));
      expect(_at(b), const Rect.fromLTWH(140, 0, 60, 20));
      // 20 left beside the first two; beside the first alone, 80; under
      // both, the whole width at the first's bottom.
      expect(_at(c), const Rect.fromLTWH(0, 30, 100, 10));
      expect(_flow(tester), const Size(200, 40));
    });

    testWidgets('a float sized by its content is shrink-to-fit', (tester) async {
      final a = GlobalKey(), b = GlobalKey();
      await _pump(
        tester,
        FloatFlow(
          children: [
            FloatSlot(
              float: FloatSide.left,
              child: SizedBox(key: a, width: 70, height: 10),
            ),
            FloatSlot(
              float: FloatSide.right,
              child: Text('aaaa bbbb', key: b, style: _style),
            ),
          ],
        ),
      );
      expect(_at(a), const Rect.fromLTWH(0, 0, 70, 10));
      expect(_at(b), const Rect.fromLTWH(110, 0, 90, 10));
    });

    testWidgets('a flow that starts no context lets its floats hang out', (tester) async {
      await _pump(
        tester,
        FloatFlow(
          floatsOut: true,
          children: [
            FloatSlot(
              float: FloatSide.left,
              width: 50,
              height: 80,
              child: SizedBox(key: GlobalKey()),
            ),
            FloatSlot(height: 20, child: SizedBox(key: GlobalKey())),
          ],
        ),
      );
      expect(_flow(tester), const Size(200, 20));
    });

    testWidgets('a flow offered room is as wide as its content asks', (tester) async {
      final a = GlobalKey();
      await _pump(
        tester,
        FloatFlow(
          children: [
            FloatSlot(
              float: FloatSide.left,
              width: 50,
              height: 10,
              child: SizedBox(key: GlobalKey()),
            ),
            FloatSlot(child: SizedBox(key: a, width: 80, height: 10)),
          ],
        ),
        width: null,
      );
      // The block ends the floats' line: 80, not 50 + 80 (Blink's
      // `ComputeMinMaxSizes`).
      expect(_flow(tester), const Size(80, 10));
      expect(_at(a), const Rect.fromLTWH(0, 0, 80, 10));
    });

    testWidgets('its intrinsic widths are its content\'s', (tester) async {
      await _pump(
        tester,
        FloatFlow(
          children: [
            FloatSlot(
              float: FloatSide.left,
              width: 30,
              height: 10,
              child: SizedBox(key: GlobalKey()),
            ),
            FloatSlot(
              float: FloatSide.left,
              width: 40,
              height: 10,
              child: SizedBox(key: GlobalKey()),
            ),
            const FloatText(TextSpan(text: 'aaaa bbbb'), style: _style, lineHeight: 10),
          ],
        ),
        width: null,
      );
      final box = tester.renderObject<RenderBox>(find.byType(FloatFlow));
      // min-content: the widest of the floats and the widest word; max:
      // the floats side by side, and the paragraph's line on its own line.
      expect(box.getMinIntrinsicWidth(double.infinity), 40);
      expect(box.getMaxIntrinsicWidth(double.infinity), 90);
    });

    testWidgets('a hosted flow is as wide as the keyword the item names', (tester) async {
      final g = GlobalKey(), f = GlobalKey(), after = GlobalKey();
      await _pump(
        tester,
        FloatFlow(
          children: [
            FloatSlot(
              widthKeyword: FloatWidth.minContent,
              child: FloatFlow(
                key: g,
                nested: true,
                children: [
                  FloatSlot(
                    float: FloatSide.left,
                    width: 50,
                    height: 24,
                    child: SizedBox(key: f),
                  ),
                ],
              ),
            ),
            // AND ITS FLOAT IS THE OUTER CONTEXT'S: the nested flow holds no
            // float in and is not grown round one (CSS 2.1 9.4.1, 10.6.7), so
            // the box after it stands beside the float.
            FloatSlot(bfc: true, height: 10, child: SizedBox(key: after)),
          ],
        ),
      );
      expect(_at(g), const Rect.fromLTWH(0, 0, 50, 0));
      expect(_at(f), const Rect.fromLTWH(0, 0, 50, 24));
      expect(_at(after), const Rect.fromLTWH(50, 0, 150, 10));
    });

    testWidgets('a FloatFlow inside a FloatFlow is the same formatting context', (tester) async {
      final inner = GlobalKey(), after = GlobalKey();
      await _pump(
        tester,
        FloatFlow(
          children: [
            FloatSlot(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: FloatFlow(
                  nested: true,
                  children: [
                    const FloatSlot(
                      float: FloatSide.left,
                      width: 40,
                      height: 40,
                      child: SizedBox(width: 40, height: 40),
                    ),
                    FloatSlot(height: 20, child: SizedBox(key: inner, height: 20)),
                  ],
                ),
              ),
            ),
            FloatSlot(height: 20, child: SizedBox(key: after, height: 20)),
          ],
        ),
      );
      // The padded block is 40 tall -- its own 20 and the padding -- and the
      // float hangs out of it, to 50: the next block starts at 40.
      expect(_at(inner), const Rect.fromLTWH(10, 10, 180, 20));
      expect(_at(after), const Rect.fromLTWH(0, 40, 200, 20));
      expect(_flow(tester), const Size(200, 60));
    });

    testWidgets('a clearfix ends its block below the float it clears, the float the outer context\'s', (tester) async {
      // A byline header in a flow of floats: its avatar floats (the outer
      // context's float), and its `::after { display: table; clear: both }`
      // -- a context of its own, empty -- stands below the float, where the
      // header ends (`fixtures/clearfix-float-pulled-out` b1). Collapsed
      // through, the header ended at its 20 of words.
      final header = GlobalKey(), avatar = GlobalKey(), after = GlobalKey();
      const clear = FloatSlot(clear: FloatClear.both, bfc: true, child: SizedBox.shrink());
      await _pump(
        tester,
        FloatFlow(
          children: [
            FloatSlot(
              child: ColoredBox(
                key: header,
                color: const Color(0xFF0000FF),
                child: FloatFlow(
                  nested: true,
                  children: [
                    clear,
                    const FloatSlot(height: 20, child: SizedBox()),
                    FloatSlot(
                      float: FloatSide.left,
                      width: 80,
                      height: 80,
                      child: SizedBox(key: avatar),
                    ),
                    clear,
                  ],
                ),
              ),
            ),
            FloatSlot(height: 10, child: SizedBox(key: after, height: 10)),
          ],
        ),
      );
      expect(_at(avatar), const Rect.fromLTWH(0, 20, 80, 80));
      expect(_at(header), const Rect.fromLTWH(0, 0, 200, 100));
      expect(_at(after), const Rect.fromLTWH(0, 100, 200, 10));
    });

    testWidgets(
      'an empty context of its own keeps its margins apart; NEGATIVE: an empty block of the context collapses '
      'them through',
      (tester) async {
        // CSS 2.1 8.3.1: the top and bottom margins of an empty box adjoin
        // only where the box starts no context of its own. Empty in the
        // context, its 10 and 10 and the next box's 20 are one margin of 20;
        // a context of its own stands at its 10, and its 10 and the next 20
        // are 20 more.
        Future<Rect> next({required bool bfc}) async {
          final k = GlobalKey();
          await _pump(
            tester,
            FloatFlow(
              children: [
                const FloatSlot(height: 5, child: SizedBox()),
                FloatSlot(bfc: bfc, margin: const EdgeInsets.symmetric(vertical: 10), child: const SizedBox.shrink()),
                FloatSlot(
                  margin: const EdgeInsets.only(top: 20),
                  height: 10,
                  child: SizedBox(key: k, height: 10),
                ),
              ],
            ),
          );
          return _at(k);
        }

        expect(await next(bfc: true), const Rect.fromLTWH(0, 35, 200, 10));
        expect(await next(bfc: false), const Rect.fromLTWH(0, 25, 200, 10));
      },
    );

    testWidgets(
      'a flow behind the boxes placed under it in a stack is hosted through the stack; NEGATIVE: a context of '
      'its own',
      (tester) async {
        // A box of `position: relative` and a stated height, its labels
        // placed against it ahead of its flow in the tree: they paint under
        // the flow, so they come first in the stack. The flow is the stack's
        // content all the same, and of the context round it: its float hangs
        // out of the box, and the box after stands beside it.
        final f = GlobalKey(), inner = GlobalKey(), label = GlobalKey(), after = GlobalKey();
        Widget page({required bool own}) => FloatFlow(
          children: [
            FloatSlot(
              bfc: own,
              height: 30,
              child: SizedBox(
                height: 30,
                child: Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.passthrough,
                  children: [
                    Positioned(left: 0, bottom: 0, child: SizedBox(key: label, width: 10, height: 10)),
                    FloatFlow(
                      nested: !own,
                      children: [
                        FloatSlot(
                          float: FloatSide.left,
                          width: 40,
                          height: 60,
                          child: SizedBox(key: f),
                        ),
                        FloatSlot(height: 20, child: SizedBox(key: inner, height: 20)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            FloatSlot(bfc: true, height: 10, child: SizedBox(key: after)),
          ],
        );
        await _pump(tester, page(own: false));
        expect(tester.takeException(), isNull);
        expect(_at(f), const Rect.fromLTWH(0, 0, 40, 60));
        expect(_at(inner), const Rect.fromLTWH(0, 0, 200, 20));
        expect(_at(label), const Rect.fromLTWH(0, 20, 10, 10));
        expect(_at(after), const Rect.fromLTWH(40, 30, 160, 10));
        // NEGATIVE: a context of its own holds its float in, and the box
        // after runs the whole width under it.
        await _pump(tester, page(own: true));
        expect(tester.takeException(), isNull);
        expect(_at(f), const Rect.fromLTWH(0, 0, 40, 60));
        expect(_at(after), const Rect.fromLTWH(0, 30, 200, 10));
      },
    );

    testWidgets('a child whose top margin collapses through its parent\'s moves it', (tester) async {
      final outer = GlobalKey(), inner = GlobalKey();
      await _pump(
        tester,
        FloatFlow(
          children: [
            FloatSlot(height: 10, child: SizedBox(key: GlobalKey())),
            FloatSlot(
              margin: const EdgeInsets.only(top: 5),
              child: FloatFlow(
                key: outer,
                nested: true,
                children: [
                  FloatSlot(
                    height: 10,
                    margin: const EdgeInsets.only(top: 20),
                    child: SizedBox(key: inner),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      // 5 and 20 are one margin, outside the nested block (CSS 2.1 8.3.1).
      expect(_at(outer), const Rect.fromLTWH(0, 30, 200, 10));
      expect(_at(inner), const Rect.fromLTWH(0, 30, 200, 10));
    });

    testWidgets('a block whose top margin collapses through its parent\'s sets its lines beside the floats from the '
        'parent\'s top; NEGATIVE: one after a block of the parent\'s', (tester) async {
      // The margin goes above the parent (CSS 2.1 8.3.1), and the block's
      // border edge is the parent's content edge: its lines are set beside
      // the parent's floats from there. A bank's contact form
      // (`fixtures/fieldset-floats-contained` n1): a note of `margin-top:
      // 12px` after an empty block whose floats fill the first 34px broke
      // its line at 22, from 12 down, where Chrome breaks it at 34.
      Widget form({required bool after}) => FloatFlow(
        children: [
          FloatSlot(
            child: FloatFlow(
              key: const ValueKey('form'),
              nested: true,
              children: [
                if (after) FloatSlot(height: 1, child: SizedBox(key: GlobalKey())),
                FloatSlot(
                  float: FloatSide.left,
                  widthFraction: 1,
                  height: 26,
                  margin: const EdgeInsets.only(top: 8),
                  child: SizedBox(key: GlobalKey()),
                ),
                FloatSlot(
                  float: FloatSide.left,
                  width: 50,
                  height: 26,
                  child: SizedBox(key: GlobalKey()),
                ),
                const FloatSlot(
                  margin: EdgeInsets.only(top: 12),
                  child: FloatText(TextSpan(text: 'aaaa bbbb'), style: _style, lineHeight: 10),
                ),
              ],
            ),
          ),
        ],
      );
      await _pump(tester, form(after: false));
      // The floats stand 8..34 (the whole width) and 34..60 (50 of it) under
      // the parent's top, and a line of 10 there fits first beside the
      // second: 34 down, 50 in -- and the parent, the margin above it, 12
      // down in the flow.
      var t = _text(tester);
      expect(t.debugLines.map((l) => (l.x, l.y)), [(50.0, 34.0)]);
      expect(t.size.height, 44);
      expect(tester.getTopLeft(find.byKey(const ValueKey('form'))), const Offset(0, 12));
      // NEGATIVE: after a block of the parent's own, the margin is between
      // the two and the block's border edge 12 under the first's end, 13
      // down: the floats stand 9..35 and 35..61, and the line 22 under it.
      await _pump(tester, form(after: true));
      t = _text(tester);
      expect(t.debugLines.map((l) => (l.x, l.y)), [(50.0, 22.0)]);
      expect(tester.getTopLeft(find.byKey(const ValueKey('form'))), Offset.zero);
    });
  });

  group('paragraphs', () {
    testWidgets('on its own, a FloatText breaks its lines in its box', (tester) async {
      await _pump(tester, const FloatText(TextSpan(text: _words), style: _style, lineHeight: 10));
      final t = _text(tester);
      // 200 wide: 'aaaa bbbb cccc dddd' is 190, so three lines of four words.
      expect(t.size, const Size(200, 30));
      final lines = t.debugLines;
      expect(lines.map((l) => l.text), ['aaaa bbbb cccc dddd', 'eeee ffff gggg hhhh', 'iiii jjjj kkkk llll']);
      expect(lines.map((l) => l.x), [0, 0, 0]);
      expect(lines.map((l) => l.y), [0, 10, 20]);
    });

    testWidgets('in a FloatFlow, its lines shorten beside a float and run on under it', (tester) async {
      await _pump(
        tester,
        const FloatFlow(
          children: [
            FloatSlot(float: FloatSide.left, width: 50, height: 30, child: SizedBox(width: 50, height: 30)),
            FloatText(TextSpan(text: _words), style: _style, lineHeight: 10),
          ],
        ),
      );
      final t = _text(tester);
      final lines = t.debugLines;
      // 150 beside the float: three words a line for three lines, then the
      // whole width under it.
      expect(lines.map((l) => l.text), ['aaaa bbbb cccc', 'dddd eeee ffff', 'gggg hhhh iiii', 'jjjj kkkk llll']);
      expect(lines.map((l) => l.x), [50, 50, 50, 0]);
      expect(t.size, const Size(200, 40));
      expect(_flow(tester), const Size(200, 40));
    });

    testWidgets('a paragraph in a nested flow shortens beside the outer float', (tester) async {
      await _pump(
        tester,
        const FloatFlow(
          children: [
            FloatSlot(float: FloatSide.left, width: 50, height: 30, child: SizedBox(width: 50, height: 30)),
            FloatSlot(
              child: Padding(
                padding: EdgeInsets.all(10),
                child: FloatFlow(
                  nested: true,
                  children: [FloatText(TextSpan(text: _words), style: _style, lineHeight: 10)],
                ),
              ),
            ),
          ],
        ),
      );
      final lines = _text(tester).debugLines;
      // The paragraph starts 10 in and 10 down; the float reaches 50 across
      // and 30 down, so its first two lines start 40 into it and are 140
      // wide, and from the third, under the float, the room is its own 180.
      expect(lines.map((l) => l.text), ['aaaa bbbb cccc', 'dddd eeee ffff', 'gggg hhhh iiii', 'jjjj kkkk llll']);
      expect(lines.map((l) => l.x), [40, 40, 0, 0]);
    });

    testWidgets('a float met in the middle of a line stands on that line', (tester) async {
      const arrow = Key('arrow');
      await _pump(
        tester,
        const FloatFlow(
          children: [
            FloatText(TextSpan(text: 'aaaa bbbb cccc￼ dddd eeee'), style: _style, lineHeight: 10),
            FloatSlot(
              float: FloatSide.right,
              onLine: true,
              width: 50,
              height: 10,
              child: SizedBox(key: arrow, width: 50, height: 10),
            ),
          ],
        ),
      );
      final lines = _text(tester).debugLines;
      // Met after 140px of the first line, it fits beside it (CSS 2.1 9.5.1
      // rule 6): its top is the line's, at the right edge. The ten pixels
      // left beside it hold no more words.
      expect(lines.map((l) => l.text), ['aaaa bbbb cccc', 'dddd eeee']);
      expect(lines.map((l) => l.x), [0, 0]);
      expect(tester.getTopLeft(find.byKey(arrow)), const Offset(150, 0));
      expect(tester.getSize(find.byType(FloatText)), const Size(200, 20));
      expect(_flow(tester), const Size(200, 20));
    });

    testWidgets('a float met where its line has no room goes to the top of the next', (tester) async {
      const arrow = Key('arrow');
      await _pump(
        tester,
        const FloatFlow(
          children: [
            FloatText(TextSpan(text: 'aaaa bbbb cccc dddd￼ eeee'), style: _style, lineHeight: 10),
            FloatSlot(
              float: FloatSide.right,
              onLine: true,
              width: 50,
              height: 10,
              child: SizedBox(key: arrow, width: 50, height: 10),
            ),
          ],
        ),
      );
      final lines = _text(tester).debugLines;
      expect(lines.map((l) => l.text), ['aaaa bbbb cccc dddd', 'eeee']);
      expect(lines.map((l) => l.y), [0, 10]);
      expect(tester.getTopLeft(find.byKey(arrow)), const Offset(150, 10));
    });

    testWidgets('a line with no room for its first word moves down past the float', (tester) async {
      await _pump(
        tester,
        const FloatFlow(
          children: [
            FloatSlot(float: FloatSide.left, width: 180, height: 20, child: SizedBox(width: 180, height: 20)),
            FloatText(TextSpan(text: 'aaaa bbbb'), style: _style, lineHeight: 10),
          ],
        ),
      );
      final t = _text(tester);
      expect(t.debugLines.map((l) => (l.text, l.x, l.y)), [('aaaa bbbb', 0.0, 20.0)]);
      expect(t.size, const Size(200, 30));
    });

    testWidgets('a line is aligned in the room beside the float', (tester) async {
      await _pump(
        tester,
        const FloatFlow(
          children: [
            FloatSlot(float: FloatSide.left, width: 100, height: 10, child: SizedBox(width: 100, height: 10)),
            FloatText(
              TextSpan(text: 'aaaa'),
              style: _style,
              lineHeight: 10,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
      expect(_text(tester).debugLines.map((l) => l.x), [130]);
    });

    testWidgets(
      'a justified line is stretched to its room, beside a float too; NEGATIVE: the last line, one a forced break '
      'ends, one with no space between words, one holding a widget, and a paragraph set at its start',
      (tester) async {
        // 200 wide: `aaaa bbbb cccc dddd` is 190 and breaks softly, so it is
        // drawn 200 wide; `eeee ffff gggg` ends at a forced break, and
        // `llll mmmm` ends the paragraph: both keep their words' width.
        const text = 'aaaa bbbb cccc dddd eeee ffff gggg\nhhhh iiii jjjj kkkk llll mmmm';
        // Which columns of the first line are inked: the test font's glyphs
        // are filled em boxes.
        Future<List<bool>> firstLine(TextAlign align) async {
          await _pump(
            tester,
            RepaintBoundary(
              key: const Key('shot'),
              child: FloatText(
                const TextSpan(text: text),
                style: _style,
                lineHeight: 10,
                textAlign: align,
              ),
            ),
          );
          final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
          final data = (await tester.runAsync(() async {
            final img = await ro.toImage();
            return (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          }))!;
          final w = ro.size.width.round();
          return [for (var x = 0; x < w; x++) data.getUint8((5 * w + x) * 4 + 3) > 192];
        }

        var ink = await firstLine(TextAlign.justify);
        var t = _text(tester);
        expect(t.debugLines.map((l) => l.text), [
          'aaaa bbbb cccc dddd',
          'eeee ffff gggg',
          'hhhh iiii jjjj kkkk',
          'llll mmmm',
        ]);
        expect(t.debugDrawnWidths, [200, 140, 200, 90]);
        expect(t.debugLines.map((l) => l.x), [0, 0, 0, 0]);
        // `dddd` is drawn at the right edge, and the words after the break
        // are not drawn on the line.
        expect([ink[0], ink[195], ink[199]], [true, true, true]);
        ink = await firstLine(TextAlign.start);
        expect([ink[0], ink[189], ink[195], ink[199]], [true, true, false, false]);

        // Beside a float, in the room it leaves: 150 for the three lines
        // beside it; the last, under it, keeps its words' 140.
        await _pump(
          tester,
          const FloatFlow(
            children: [
              FloatSlot(float: FloatSide.left, width: 50, height: 30, child: SizedBox(width: 50, height: 30)),
              FloatText(
                TextSpan(text: _words),
                style: _style,
                lineHeight: 10,
                textAlign: TextAlign.justify,
              ),
            ],
          ),
        );
        t = _text(tester);
        expect(t.debugLines.map((l) => l.text), [
          'aaaa bbbb cccc',
          'dddd eeee ffff',
          'gggg hhhh iiii',
          'jjjj kkkk llll',
        ]);
        expect(t.debugDrawnWidths, [150, 150, 150, 140]);
        expect(t.debugLines.map((l) => l.x), [50, 50, 50, 0]);

        // NEGATIVE: set at its start, no line is stretched.
        await _pump(tester, const FloatText(TextSpan(text: text), style: _style, lineHeight: 10));
        expect(_text(tester).debugDrawnWidths, [190, 140, 190, 90]);

        // NEGATIVE: a line of one word has no space to stretch.
        await _pump(
          tester,
          const FloatText(
            TextSpan(text: 'aaaaaa bbbbbb'),
            style: _style,
            lineHeight: 10,
            textAlign: TextAlign.justify,
          ),
          width: 70,
        );
        expect(_text(tester).debugDrawnWidths, [60, 60]);

        // NEGATIVE: a line holding a widget is set at its start: 'aaaa ', the
        // box, ' bbbb cccc' is 170 and breaks softly before `dddd`.
        await _pump(
          tester,
          const FloatText(
            TextSpan(
              children: [
                TextSpan(text: 'aaaa '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.aboveBaseline,
                  baseline: TextBaseline.alphabetic,
                  child: SizedBox(width: 20, height: 10),
                ),
                TextSpan(text: ' bbbb cccc dddd eeee'),
              ],
            ),
            style: _style,
            lineHeight: 10,
            textAlign: TextAlign.justify,
          ),
        );
        t = _text(tester);
        expect(t.debugLines.map((l) => l.text), ['aaaa \uFFFC bbbb cccc', 'dddd eeee']);
        expect(t.debugDrawnWidths, [170, 90]);
      },
    );

    testWidgets('a newline is a forced break, and a line may end after a hyphen', (tester) async {
      await _pump(
        tester,
        const FloatText(TextSpan(text: 'aaaa\nbbbb-cccc dd'), style: _style, lineHeight: 10),
        width: 70,
      );
      final t = _text(tester);
      expect(t.debugLines.map((l) => l.text), ['aaaa', 'bbbb-', 'cccc dd']);
      expect(t.size, const Size(70, 30));
    });

    testWidgets('a paragraph is lineHeight a line and grows for a taller run', (tester) async {
      await _pump(
        tester,
        const FloatText(
          TextSpan(
            children: [
              TextSpan(text: 'aaaa '),
              TextSpan(text: 'BB', style: TextStyle(fontSize: 30, height: 1)),
            ],
          ),
          style: _style,
          lineHeight: 12,
        ),
      );
      final t = _text(tester);
      expect(t.size.height, greaterThan(29));
      await _pump(tester, const FloatText(TextSpan(text: 'aaaa'), style: _style, lineHeight: 12.5));
      expect(_text(tester).size, const Size(200, 12.5));
    });

    testWidgets('a line is drawn on the baseline Blink rounds to: Skia draws on the one it answers rounded', (
      tester,
    ) async {
      // At `line-height: 10` the test font's strut is 7 over the baseline;
      // Skia answers 7.5 and draws on 8. Set 0.5 up by what it answers,
      // the line came out on 8 at the top and at 0.25 (Blink: 7), a pixel
      // low (`fixtures/float-lines-normal`).
      for (final top in [0.0, 0.25]) {
        await _pump(
          tester,
          RepaintBoundary(
            key: const Key('shot'),
            child: SizedBox(
              height: 12,
              child: Padding(
                padding: EdgeInsets.only(top: top),
                child: const FloatText(TextSpan(text: 'EEEE'), style: _style, lineHeight: 10),
              ),
            ),
          ),
        );
        final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
        final data = (await tester.runAsync(() async {
          final img = await ro.toImage();
          return (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        }))!;
        final w = ro.size.width.round();
        bool inked(int y) => data.getUint8((y * w + 2) * 4 + 3) > 192;
        // The em box, 7.5 over the baseline and 2.5 under it, fills rows 0-8.
        expect([for (var y = 0; y < 11; y++) inked(y)], [for (var y = 0; y < 11; y++) y <= 8], reason: 'top $top');
      }
    });
  });

  group('widgets on the lines', () {
    // The test font's ascent is 7.5 and its descent 2.5, rounded to 8 and 3:
    // at `line-height: 10` the strut is 7 over the baseline and 3 under it.
    InlineSpan line(Widget w, {String before = 'aaaa ', String after = ' bbbb cccc dddd'}) => TextSpan(
      children: [
        TextSpan(text: before),
        WidgetSpan(alignment: PlaceholderAlignment.aboveBaseline, baseline: TextBaseline.alphabetic, child: w),
        TextSpan(text: after),
      ],
    );

    testWidgets('a widget on a line is a box of its own in the room beside the float', (tester) async {
      const w = Key('w');
      await _pump(
        tester,
        FloatFlow(
          children: [
            const FloatSlot(float: FloatSide.left, width: 60, height: 30, child: SizedBox(width: 60, height: 30)),
            FloatText(line(const SizedBox(key: w, width: 30, height: 20)), style: _style, lineHeight: 10),
          ],
        ),
      );
      final lines = _text(tester).debugLines;
      // 140 beside the float: 'aaaa ', the widget and ' bbbb' are 130.
      expect(lines.map((l) => l.text), ['aaaa \uFFFC bbbb', 'cccc dddd']);
      expect(lines.map((l) => l.x), [60, 60]);
      // The widget stands its bottom on the baseline, and the line box is
      // the 20 over it and the strut's 3 under.
      expect(lines.map((l) => l.y), [0, 23]);
      expect(tester.getRect(find.byKey(w)), const Rect.fromLTWH(110, 0, 30, 20));
    });

    testWidgets('a widget with no room beside the float moves its line down', (tester) async {
      const w = Key('w');
      await _pump(
        tester,
        FloatFlow(
          children: [
            const FloatSlot(float: FloatSide.left, width: 60, height: 20, child: SizedBox(width: 60, height: 20)),
            FloatText(
              line(const SizedBox(key: w, width: 150, height: 20), after: ''),
              style: _style,
              lineHeight: 10,
            ),
          ],
        ),
      );
      final lines = _text(tester).debugLines;
      expect(lines.map((l) => (l.text, l.x, l.y)), [('aaaa', 60.0, 0.0), ('\uFFFC', 0.0, 20.0)]);
      expect(tester.getRect(find.byKey(w)), const Rect.fromLTWH(0, 20, 150, 20));
    });

    testWidgets('a word and the widget after it part where the widget does not fit', (tester) async {
      const w = Key('w');
      await _pump(
        tester,
        FloatFlow(
          children: [
            const FloatSlot(float: FloatSide.left, width: 60, height: 30, child: SizedBox(width: 60, height: 30)),
            // 'aaaa bbbb ccc' is 130 of the 140 beside the float; the widget
            // after `ccc` is 20 more, and goes down alone (css-text-3 5.1).
            FloatText(
              line(
                const SizedBox(key: w, width: 20, height: 10),
                before: 'aaaa bbbb ccc',
                after: ' dd',
              ),
              style: _style,
              lineHeight: 10,
            ),
          ],
        ),
      );
      final lines = _text(tester).debugLines;
      expect(lines.map((l) => l.text), ['aaaa bbbb ccc', '\uFFFC dd']);
      expect(tester.getRect(find.byKey(w)), const Rect.fromLTWH(60, 10, 20, 10));
    });

    testWidgets('a widget on its baseline, and one a tap reaches', (tester) async {
      const w = Key('w');
      var taps = 0;
      await _pump(
        tester,
        FloatFlow(
          children: [
            const FloatSlot(float: FloatSide.right, width: 60, height: 30, child: SizedBox(width: 60, height: 30)),
            FloatText(
              TextSpan(
                children: [
                  const TextSpan(text: 'aaaa '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () => taps++,
                      // 16px of the test font: 12 over its baseline, 4 under.
                      child: const Text(
                        'x',
                        key: w,
                        style: TextStyle(fontFamily: 'FlutterTest', fontSize: 16, height: 1),
                      ),
                    ),
                  ),
                  const TextSpan(text: ' bbbb'),
                ],
              ),
              style: _style,
              lineHeight: 10,
            ),
          ],
        ),
      );
      final lines = _text(tester).debugLines;
      // 12 over the baseline and 4 under: the line is 12 over and 4 under.
      expect(lines.map((l) => (l.text, l.x, l.y, l.baseline)), [('aaaa \uFFFC bbbb', 0.0, 0.0, 12.0)]);
      expect(_text(tester).size, const Size(200, 16));
      expect(tester.getRect(find.byKey(w)), const Rect.fromLTWH(50, 0, 16, 16));
      await tester.tap(find.byKey(w));
      expect(taps, 1);
    });

    testWidgets('on its own, a FloatText sets its widgets on its lines', (tester) async {
      const w = Key('w');
      await _pump(
        tester,
        FloatText(line(const SizedBox(key: w, width: 30, height: 20)), style: _style, lineHeight: 10),
      );
      final t = _text(tester);
      expect(t.debugLines.map((l) => l.text), ['aaaa \uFFFC bbbb cccc', 'dddd']);
      expect(tester.getRect(find.byKey(w)), const Rect.fromLTWH(50, 0, 30, 20));
      expect(t.size, const Size(200, 33));
      // As wide as its words and the widget on one line at max-content.
      expect(t.getMaxIntrinsicWidth(double.infinity), 230);
      expect(t.getMinIntrinsicWidth(double.infinity), 40);
    });
  });
  group('a face with a line gap', () {
    setUpAll(_loadGapFaces);
    // Inter at 18px is 17.44 over its baseline and 4.34 under, and the
    // gap of half an em is 9. Blink rounds each: a `normal` line is 17 + 4
    // + 9 = 30, the strut floor(17 + 4.5) = 21 over the baseline and 9
    // under. Skia leads the ascent it answers by half the gap, 21.94,
    // which rounded is 22: the line was 31, its baseline 22.
    const gap = TextStyle(fontFamily: 'FxGap', fontSize: 18, color: Color(0xFF000000));
    const plain = TextStyle(fontFamily: 'Fx', fontSize: 18, color: Color(0xFF000000));

    testWidgets('a normal line is the bare ascent, the bare descent and the gap, each rounded', (tester) async {
      await _pump(tester, const FloatText(TextSpan(text: 'aaaa'), style: gap));
      expect(_text(tester).debugLines.map((l) => (l.y, l.baseline)), [(0.0, 21.0)]);
      expect(_text(tester).size.height, 30);
    });

    testWidgets("a widget alone on a line beside a float stands on the strut's baseline", (tester) async {
      // A Japanese news site's phone section heading: a link alone on the line beside a
      // floated title, as tall as the strut over the baseline.
      const w = Key('w');
      await _pump(
        tester,
        FloatFlow(
          children: [
            const FloatSlot(float: FloatSide.left, width: 60, height: 20, child: SizedBox(width: 60, height: 20)),
            const FloatText(
              TextSpan(
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.aboveBaseline,
                    baseline: TextBaseline.alphabetic,
                    child: SizedBox(key: w, width: 40, height: 21),
                  ),
                ],
              ),
              style: gap,
              textAlign: TextAlign.right,
            ),
          ],
        ),
      );
      expect(_text(tester).size.height, 30);
      expect(tester.getRect(find.byKey(w)), const Rect.fromLTWH(160, 0, 40, 21));
    });

    testWidgets('NEGATIVE: a face with no gap is its ascent and descent, as before', (tester) async {
      // 17.44 and 4.34, rounded: 17 over the baseline, 4 under.
      await _pump(tester, const FloatText(TextSpan(text: 'aaaa'), style: plain));
      expect(_text(tester).debugLines.map((l) => (l.y, l.baseline)), [(0.0, 17.0)]);
      expect(_text(tester).size.height, 21);
    });
  });

  group('under rtl', () {
    // A LINE STARTS AT ITS RIGHT (CSS 2.1 9.10). A sports news site's footer is an
    // `rtl` table round an inline-block and `Kontakt` beside a floated
    // link (`fixtures/float-rtl-empty-line` n5): the box at the right of
    // the room the float leaves, the word to its left.
    const box = Key('box');
    Widget footer(TextDirection d) => FloatFlow(
      children: [
        FloatText(
          const TextSpan(
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.aboveBaseline,
                baseline: TextBaseline.alphabetic,
                child: SizedBox(key: box, width: 30, height: 10),
              ),
              TextSpan(text: ' aaaa\uFFFC'),
            ],
          ),
          style: _style,
          lineHeight: 10,
          textDirection: d,
        ),
        const FloatSlot(
          float: FloatSide.left,
          onLine: true,
          width: 50,
          height: 10,
          child: SizedBox(width: 50, height: 10),
        ),
      ],
    );

    testWidgets('a line starts at the right of the room beside a float, the words in their bidi order', (tester) async {
      await _pump(tester, footer(TextDirection.rtl));
      // 150 beside the float; the line, box, space and word, is 80, and
      // stands at its right: the box first, from 170.
      expect(_text(tester).debugLines.map((l) => (l.x, l.width)), [(120.0, 80.0)]);
      expect(tester.getTopLeft(find.byKey(box)).dx, 170);
      // NEGATIVE: under `ltr`, at the left of the room.
      await _pump(tester, footer(TextDirection.ltr));
      expect(_text(tester).debugLines.map((l) => l.x), [50.0]);
      expect(tester.getTopLeft(find.byKey(box)).dx, 50);
    });

    testWidgets('a line wider than its room runs out of it to the left', (tester) async {
      // Box, space and `aaaa bbbb cccc`, 160, not wrapping in 100: the line
      // starts at the right edge, the box there, and the words run out of
      // the room to the left of it.
      await _pump(
        tester,
        const FloatText(
          TextSpan(
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.aboveBaseline,
                baseline: TextBaseline.alphabetic,
                child: SizedBox(key: box, width: 10, height: 10),
              ),
              TextSpan(text: ' aaaa bbbb cccc'),
            ],
          ),
          style: _style,
          lineHeight: 10,
          softWrap: false,
          textDirection: TextDirection.rtl,
        ),
        width: 100,
      );
      expect(_text(tester).debugLines.map((l) => l.x), [-60.0]);
      expect(tester.getTopLeft(find.byKey(box)).dx, 90);
    });

    testWidgets('a line is resolved as the whole paragraph is: a neutral at its end takes the direction of the letter '
        'after the break; NEGATIVE: at the end of the paragraph, the paragraph\'s', (tester) async {
      // `aaaa` and a box, then `bbbb` on the next line, in 60: the box is
      // between two Latin letters in the paragraph (UAX #9 N1), so it is
      // left to right after `aaaa`, at the line's right end -- set alone,
      // the line would end it on `rtl` and stand it left of the word.
      Widget line(String after) => FloatText(
        TextSpan(
          children: [
            const TextSpan(text: 'aaaa'),
            const WidgetSpan(
              alignment: PlaceholderAlignment.aboveBaseline,
              baseline: TextBaseline.alphabetic,
              child: SizedBox(key: box, width: 10, height: 10),
            ),
            TextSpan(text: after),
          ],
        ),
        style: _style,
        lineHeight: 10,
        textDirection: TextDirection.rtl,
      );
      await _pump(tester, line(' bbbb'), width: 60);
      expect(_text(tester).debugLines.map((l) => l.text), ['aaaa\uFFFC', 'bbbb']);
      expect(tester.getTopLeft(find.byKey(box)).dx, 50);
      // NEGATIVE: nothing after it, it takes the paragraph's `rtl` and
      // stands left of the word.
      await _pump(tester, line(''), width: 60);
      expect(tester.getTopLeft(find.byKey(box)).dx, 10);
    });
  });
}
