import 'dart:io';
import 'dart:typed_data';

import 'package:css_box/css_box.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// A FLOW LAID OUT AT ITS OWN MAX-CONTENT WIDTH IS ONE LINE. Its lines fit
// as Blink's `LineBreaker` counts them: every text item it has closed at
// its float width rounded UP to 1/64 px. A max-content width summed from
// the float widths is short of that by up to 1/64 an item, and the flow
// broke at its own width -- a docs site's figure captions, `Initially, each
// <code>MyButton</code>'s <code>count</code> state is <code>0</code>`, two
// lines of an item that shrank to them, where Chrome's one line is 307.875
// (fixtures/flex-shrink-inline-flow-caption p1; the float sum 307.827).
const _body = InlineFont(size: 15, ascent: 15, descent: 4, lineHeight: 18.75, xHeight: 8.1884765625);
const _code = InlineFont(size: 13.5, ascent: 13, descent: 3, lineHeight: 16.875, xHeight: 7.3828125);

void main() {
  setUpAll(() async {
    final bytes = Uint8List.fromList(await File('${Directory.current.path}/test/fonts/Inter.ttf').readAsBytes());
    await (FontLoader('Fx')..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  });

  InlineFlow caption(double pad, WhiteSpace ws) {
    InlineNode code(String t) => InlineBox(
      font: _code,
      padding: EdgeInsets.all(pad),
      children: [InlineText(t, style: const TextStyle(fontFamily: 'Fx', fontSize: 13.5))],
    );
    return InlineFlow(
      font: _body,
      style: const TextStyle(fontFamily: 'Fx', fontSize: 15, color: Color(0xFF000000)),
      textAlign: TextAlign.center,
      whiteSpace: ws,
      children: [
        InlineText('Initially, each '),
        code('MyButton'),
        InlineText('’s '),
        code('count'),
        InlineText(' state is '),
        code('0'),
      ],
    );
  }

  Future<RenderBox> lay(WidgetTester tester, Widget flow, double? width) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: width == null ? IntrinsicWidth(child: flow) : SizedBox(width: width, child: flow),
        ),
      ),
    );
    return tester.renderObject<RenderBox>(find.byType(InlineFlow));
  }

  for (final ws in [WhiteSpace.normal, WhiteSpace.preWrap]) {
    for (final pad in [4.0, 0.0]) {
      testWidgets('a flow at its own max-content width is one line: $ws, code padded $pad', (tester) async {
        final flow = caption(pad, ws);
        final shrunk = await lay(tester, flow, null);
        final max = shrunk.getMaxIntrinsicWidth(double.infinity);
        expect(max * 64, (max * 64).roundToDouble(), reason: 'on the 1/64 grid: $max');
        expect(shrunk.size.height, 18.75, reason: 'IntrinsicWidth: $max');
        expect((await lay(tester, flow, max)).size.height, 18.75, reason: 'at $max');
      });
    }
  }

  testWidgets('NEGATIVE: a flow short of its max-content width by a pixel breaks', (tester) async {
    final flow = caption(4, WhiteSpace.normal);
    final max = (await lay(tester, flow, null)).getMaxIntrinsicWidth(double.infinity);
    expect((await lay(tester, flow, max - 1)).size.height, 37.5);
  });

  testWidgets('NEGATIVE: a flow at a width past its max-content is laid out at that width, one line', (tester) async {
    final flow = caption(4, WhiteSpace.normal);
    final max = (await lay(tester, flow, null)).getMaxIntrinsicWidth(double.infinity);
    final wide = await lay(tester, flow, max + 40);
    expect(wide.size, Size(max + 40, 18.75));
  });

  testWidgets('the min-content width is on the grid too, and laid out at it keeps its lines', (tester) async {
    final flow = caption(4, WhiteSpace.normal);
    final r = await lay(tester, flow, null);
    final min = r.getMinIntrinsicWidth(double.infinity);
    expect(min * 64, (min * 64).roundToDouble(), reason: '$min');
    final at = (await lay(tester, flow, min)).size.height;
    expect(at, (await lay(tester, flow, min + 0.25)).size.height, reason: 'at $min: the lines of a quarter pixel more');
  });
}
