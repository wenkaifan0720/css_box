import 'dart:io';
import 'dart:typed_data';

import 'package:css_box/css_box.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// BLINK BREAKS BETWEEN TWO PRINTABLE ASCII GLYPHS BY ITS OWN TABLE
// (`LineBreakData::FillAscii`): before an opening `(` `<` `[` `{` after
// anything but `$ ' ( / < @ [ ^ _ \` {`, a digit or a letter, and after a
// `?` before anything but `! " ' ) , . / : ; ? ] }`. A docs site's
// `<code>src={user.imageUrl}</code>` breaks after `src=` in Chrome 151
// (fixtures/inline-flow-ascii-break). A word with a break in it has a
// min-content width under its max-content one; a word without, the same.
const _font = InlineFont(size: 15, ascent: 15, descent: 4, lineHeight: 18.75, xHeight: 8.1884765625);
const _style = TextStyle(fontFamily: 'Fx', fontSize: 15, color: Color(0xFF000000));

void main() {
  setUpAll(() async {
    final bytes = Uint8List.fromList(await File('${Directory.current.path}/test/fonts/Inter.ttf').readAsBytes());
    await (FontLoader('Fx')..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  });

  Future<RenderBox> lay(
    WidgetTester tester,
    String word, {
    double? width,
    bool boxed = true,
    WhiteSpace ws = WhiteSpace.preWrap,
  }) async {
    final flow = InlineFlow(
      font: _font,
      style: _style,
      whiteSpace: ws,
      children: [
        if (boxed)
          InlineBox(font: _font, padding: const EdgeInsets.all(4), children: [InlineText(word)])
        else
          InlineText(word),
      ],
    );
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

  const breaks = {
    'src={user.imageUrl}': 'after `=`, before `{`',
    'value=(computed)': 'after `=`, before `(`',
    'f()(x)': 'after `)`, before `(`',
    'a+[b]': 'after `+`, before `[`',
    'page?query': 'after `?`',
  };
  for (final MapEntry(key: word, value: where) in breaks.entries) {
    for (final ws in [WhiteSpace.preWrap, WhiteSpace.normal]) {
      for (final boxed in [true, false]) {
        testWidgets('`$word` breaks $where: $ws${boxed ? ', in a box' : ''}', (tester) async {
          final r = await lay(tester, word, boxed: boxed, ws: ws);
          final min = r.getMinIntrinsicWidth(double.infinity), max = r.getMaxIntrinsicWidth(double.infinity);
          expect(min, lessThan(max - 4), reason: '$min $max');
          expect((await lay(tester, word, width: min, boxed: boxed, ws: ws)).size.height, 37.5);
        });
      }
    }
  }

  testWidgets('a `pre-wrap` word breaks after its hyphen as a collapsed one does', (tester) async {
    final r = await lay(tester, 'well-known', boxed: false);
    expect(r.getMinIntrinsicWidth(double.infinity), lessThan(r.getMaxIntrinsicWidth(double.infinity) - 4));
  });

  testWidgets('NEGATIVE: a `pre` word breaks nowhere', (tester) async {
    for (final word in [...breaks.keys, 'well-known']) {
      final r = await lay(tester, word, boxed: false, ws: WhiteSpace.pre);
      expect(r.getMinIntrinsicWidth(double.infinity), r.getMaxIntrinsicWidth(double.infinity), reason: word);
    }
  });

  const whole = {
    'src{user.imageUrl}': 'a letter before `{`',
    r'$(document.body)': r'a `$` before `(`',
    'isReady?).then': 'a `?` before `)`',
    'Array<T>': 'a letter before `<`',
    'x2(y)': 'a digit before `(`',
    'why?"no"': 'a `?` before `"`',
  };
  for (final MapEntry(key: word, value: why) in whole.entries) {
    testWidgets('NEGATIVE: `$word` stays whole: $why', (tester) async {
      for (final ws in [WhiteSpace.preWrap, WhiteSpace.normal]) {
        final r = await lay(tester, word, ws: ws);
        expect(r.getMinIntrinsicWidth(double.infinity), r.getMaxIntrinsicWidth(double.infinity), reason: '$ws');
      }
    });
  }

  testWidgets('NEGATIVE: a `nowrap` flow breaks nowhere', (tester) async {
    final flow = InlineFlow(
      font: _font,
      style: _style,
      whiteSpace: WhiteSpace.nowrap,
      children: [InlineText('src={user.imageUrl}')],
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: IntrinsicWidth(child: flow),
        ),
      ),
    );
    final r = tester.renderObject<RenderBox>(find.byType(InlineFlow));
    expect(r.getMinIntrinsicWidth(double.infinity), r.getMaxIntrinsicWidth(double.infinity));
  });
}
