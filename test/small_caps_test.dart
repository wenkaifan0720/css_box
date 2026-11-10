import 'dart:io';
import 'dart:typed_data';

import 'package:css_box/css_box.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// SMALL CAPITALS A FACE DOES NOT HAVE ARE MADE UP (css-fonts-4 6.4): Inter
// has no `smcp`, so a browser draws `font-variant: small-caps` text with
// each letter that uppercasing changes as its capital at 0.7 of the size,
// rounded to the pixel, and the rest as written; under `all-small-caps`
// the whole run small (fixtures/small-caps-synthesis).
void main() {
  setUpAll(() async {
    final bytes = Uint8List.fromList(await File('test/fonts/Inter.ttf').readAsBytes());
    await (FontLoader('Fx')..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  });

  const style = TextStyle(fontFamily: 'Fx', fontSize: 16, height: 1.5, leadingDistribution: TextLeadingDistribution.even);

  test('the letters uppercasing changes are capitals at the small size, the rest as written', () {
    const span = SmallCapsSpan(text: 'Hello World, 2026', size: 11, style: style);
    expect(span.runs, [('H', false), ('ELLO', true), (' W', false), ('ORLD', true), (', 2026', false)]);
  });

  test('under `all`, the whole run is small capitals', () {
    expect(const SmallCapsSpan(text: 'NASA and Nato, 2026', size: 11, all: true).runs, [('NASA AND NATO, 2026', true)]);
  });

  test('a letter whose capital is longer is written as it is: the text keeps its length', () {
    expect(const SmallCapsSpan(text: 'straße', size: 11).runs, [('STRA', true), ('ß', false), ('E', true)]);
  });

  test('NEGATIVE: a text with nothing to shrink is one run as written', () {
    expect(const SmallCapsSpan(text: '2026 / 10', size: 11).runs, [('2026 / 10', false)]);
  });

  Future<RenderParagraph> laid(WidgetTester tester, InlineSpan span) async {
    final key = GlobalKey();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: Text.rich(span, key: key, style: style)),
    ));
    return tester.renderObject<RenderParagraph>(find.byKey(key));
  }

  testWidgets('it lays out as the capitals written at the small size, on the line of the text round it', (tester) async {
    final made = await laid(tester, const SmallCapsSpan(text: 'oct 31, 2026', size: 11));
    final madeSize = made.size;
    // The paragraph's text is the page's: the capitals are only drawn.
    expect(made.text.toPlainText(), 'oct 31, 2026');
    final written = await laid(
      tester,
      const TextSpan(children: [TextSpan(text: 'OCT', style: TextStyle(fontSize: 11)), TextSpan(text: ' 31, 2026')]),
    );
    expect(madeSize, written.size);
    // The 11px capitals at the paragraph's 1.5 are a 16.5px line inside its
    // 24px one: the line is the paragraph's.
    final plain = await laid(tester, const TextSpan(text: '31, 2026'));
    expect(madeSize.height, plain.size.height);
  });

  test('a new size lays out again', () {
    const a = SmallCapsSpan(text: 'oct', size: 11);
    expect(a.compareTo(const SmallCapsSpan(text: 'oct', size: 12)), RenderComparison.layout);
    expect(a.compareTo(const SmallCapsSpan(text: 'oct', size: 11)), RenderComparison.identical);
    expect(a.compareTo(const SmallCapsSpan(text: 'oct', size: 11, all: true)), RenderComparison.layout);
  });
}
