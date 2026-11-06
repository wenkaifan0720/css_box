import 'dart:io';
import 'dart:typed_data';

import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// BLINK ON macOS LIFTS THE ASCENT OF HELVETICA by 15% of its rounded ascent
// and descent (`FontMetrics::AscentDescentWithHacks`), and it asks the face
// it drew, not the name the page gave it. Helvetica at 16px rounds to 12
// over 4 and is lifted 2: in a 22.4px line the strut stands floor(14 + 2.2)
// = 16 over the baseline, where the face read alone stands floor(12 + 3.2)
// = 15. A page's `sans-serif` that Chrome drew in Helvetica ships under the
// generic's own name, which says nothing of the face: `FloatText` is told
// the strut's ascent.
const _helvetica = '/System/Library/Fonts/Helvetica.ttc';
final _skip = File(_helvetica).existsSync() ? null : 'needs the system Helvetica';

Future<void> _load(String family) async {
  final bytes = File(_helvetica).readAsBytesSync();
  await (FontLoader(family)..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)))).load();
}

Future<void> _pump(WidgetTester t, Widget child) {
  t.view.physicalSize = const Size(800, 600);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  return t.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 120, child: child),
      ),
    ),
  );
}

RenderFloatText _text(WidgetTester tester) => tester.renderObject<RenderFloatText>(find.byType(FloatText));

List<(double, double)> _lines(WidgetTester tester) => [for (final l in _text(tester).debugLines) (l.y, l.baseline)];

const _generic = TextStyle(fontFamily: 'sansserif', fontSize: 16, color: Color(0xFF000000));
const _named = TextStyle(fontFamily: 'Helvetica', fontSize: 16, color: Color(0xFF000000));
const _two = 'aaaa bbbb cccc dddd eeee ffff';

void main() {
  setUpAll(() async {
    // The other way round: Inter, under a name Blink would lift and under
    // one it would not.
    final inter = File('test/fonts/Inter.ttf').readAsBytesSync();
    for (final family in const ['Times', 'Plainface']) {
      await (FontLoader(family)..addFont(Future.value(ByteData.view(Uint8List.fromList(inter).buffer)))).load();
    }
    if (_skip != null) return;
    await _load('sansserif');
    await _load('Helvetica');
  });

  testWidgets('a face shipped under a lifted name it is not, told its own ascent, stands unlifted', (tester) async {
    const plain = TextStyle(fontFamily: 'Plainface', fontSize: 16, color: Color(0xFF000000));
    const named = TextStyle(fontFamily: 'Times', fontSize: 16, color: Color(0xFF000000));
    await _pump(tester, const FloatText(TextSpan(text: _two), style: plain, lineHeight: 22.4));
    final own = _lines(tester);
    // Read off the name alone, the stand-in is lifted, and stands lower.
    await _pump(tester, const FloatText(TextSpan(text: _two), style: named, lineHeight: 22.4));
    expect(_lines(tester).first.$2, greaterThan(own.first.$2));
    await _pump(
      tester,
      FloatText(
        const TextSpan(text: _two),
        style: named,
        lineHeight: 22.4,
        ascent: own.first.$2,
      ),
    );
    expect(_lines(tester), own);
  });

  testWidgets('told the strut ascent, a generically named Helvetica stands as the named one does', (tester) async {
    await _pump(tester, const FloatText(TextSpan(text: _two), style: _named, lineHeight: 22.4));
    final named = _lines(tester);
    expect(named.first, (0.0, 16.0));
    await _pump(tester, const FloatText(TextSpan(text: _two), style: _generic, lineHeight: 22.4, ascent: 16));
    expect(_lines(tester), named);
    // 22.4 is 22.40625 on Blink's 1/64 grid.
    expect(_text(tester).size.height, _text(tester).debugLines.length * 22.40625);
  }, skip: _skip != null);

  testWidgets('NEGATIVE: untold, the generic name reads the face alone, a pixel high', (tester) async {
    await _pump(tester, const FloatText(TextSpan(text: _two), style: _generic, lineHeight: 22.4));
    expect(_lines(tester).first, (0.0, 15.0));
  }, skip: _skip != null);

  testWidgets("a run in the block's family stands on the lifted face, and the line is no taller", (tester) async {
    // A bold run is the same face to Blink, lifted as the strut is: the line
    // stays 22.4 (22.40625 on the 1/64 grid). Unlifted, the run would reach 15 over and 7.4 under, and
    // with the strut's 16 over the line would be 23.4.
    await _pump(
      tester,
      const FloatText(
        TextSpan(
          children: [
            TextSpan(text: 'aaaa '),
            TextSpan(
              text: 'bbbb',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: ' cccc dddd eeee ffff'),
          ],
        ),
        style: _generic,
        lineHeight: 22.4,
        ascent: 16,
      ),
    );
    final lines = _lines(tester);
    expect(lines.length, greaterThan(1));
    for (var i = 0; i < lines.length; i++) {
      expect(lines[i].$1, closeTo(i * 22.40625, 1e-6));
      expect(lines[i].$2, closeTo(i * 22.40625 + 16, 1e-6));
    }
  }, skip: _skip != null);

  testWidgets('NEGATIVE: an ascent the name already gives changes nothing', (tester) async {
    await _pump(tester, const FloatText(TextSpan(text: _two), style: _named, lineHeight: 22.4));
    final untold = _lines(tester);
    await _pump(tester, const FloatText(TextSpan(text: _two), style: _named, lineHeight: 22.4, ascent: 16));
    expect(_lines(tester), untold);
  }, skip: _skip != null);
}
