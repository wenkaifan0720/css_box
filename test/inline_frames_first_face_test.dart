import 'dart:io';
import 'dart:typed_data';

import 'package:css_box/css_box.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// A PARAGRAPH WHOSE FIRST FACE DRAWS NONE OF ITS WORDS. `Digits` is Open
// Sans cut to its ten digits (test/fonts); every glyph of
// the words is the fallback's. Its lines stand on Digits all the same --
// the first available font (fixtures/partial-face-line-box) -- and the
// frames on them are painted: the strut is measured on a digit, where a
// zero-width space is nothing Digits draws and Skia makes no box of it.
const _red = Color(0xFFFF0000);

void main() {
  setUpAll(() async {
    Future<void> load(String family, String file) async {
      final bytes = Uint8List.fromList(await File('${Directory.current.path}/test/fonts/$file').readAsBytes());
      await (FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
    }

    await load('Digits', 'OpenSansDigits.ttf');
    await load('Fx', 'Inter.ttf');
  });

  Widget page(String family) => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 300,
        child: InlineFrames(
          child: Text.rich(
            const TextSpan(
              children: [
                TextSpan(text: 'Status '),
                InlineFrameSpan(
                  decoration: BoxDecoration(color: _red),
                  insets: EdgeInsets.only(top: 2, bottom: 2),
                  ascent: 17,
                  descent: 5,
                  children: [TextSpan(text: 'pending')],
                ),
                TextSpan(text: ' today'),
              ],
            ),
            style: TextStyle(fontFamily: family, fontFamilyFallback: const ['Fx'], fontSize: 16),
            strutStyle: StrutStyle(fontFamily: family, fontSize: 16, height: 1.5, forceStrutHeight: true),
          ),
        ),
      ),
    ),
  );

  testWidgets('a frame on a line whose first face draws none of it is painted', (tester) async {
    await tester.pumpWidget(page('Digits'));
    expect(tester.renderObject(find.byType(InlineFrames)), paints..rect(color: _red));
  });

  testWidgets('a frame on a line whose first face draws it is painted, as ever', (tester) async {
    await tester.pumpWidget(page('Fx'));
    expect(tester.renderObject(find.byType(InlineFrames)), paints..rect(color: _red));
  });
}
