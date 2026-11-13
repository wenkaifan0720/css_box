// A FACE THAT LOADS AFTER THE TEXT WAS LAID OUT REFLOWS IT, AS A BROWSER
// DOES: an app that loads its fonts as it runs (`google_fonts`, a font
// fetched or read from a file, `FontLoader`) lays its text out in a
// fallback face until the face is in, and then in the face. Flutter tells
// every render object that mixes in `RelayoutWhenSystemFontsChangeMixin`
// (`RenderParagraph`, `RenderEditable`); a box of css_box's that measured
// words itself, or holds what it measured, keeps the fallback's widths
// until it is mounted again. Each case lays its words out in a family not
// yet loaded (flutter_test's own face, every glyph one em wide), loads the
// family, and asks for the layout a fresh mount gives.
//
// NOT HERE: a `Text` whose width a box asks before laying it out (a float,
// a flex line, `IntrinsicWidth`) keeps the fallback's width on Flutter 3.38
// and 3.47 whatever its parent does: `RenderParagraph.systemFontsDidChange`
// lays its text out again but not the painter its intrinsic widths and dry
// layout read (`_textIntrinsicsCache`), so `getMaxIntrinsicWidth` answers
// the fallback's width after the face is in, marked dirty or not.
import 'dart:io';
import 'dart:typed_data';

import 'package:css_box/css_box.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _words = 'aaaa bbbb cccc dddd eeee ffff';

/// [family] loaded from Inter, as an app loads a face while it runs.
Future<void> _load(WidgetTester t, String family) => t.runAsync(() async {
  final b = File('test/fonts/Inter.ttf').readAsBytesSync();
  await (FontLoader(family)..addFont(Future.value(ByteData.view(Uint8List.fromList(b).buffer)))).load();
});

Widget _page(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 200, child: child),
  ),
);

/// Each box under the page's root, where it is laid out.
List<Rect> _boxes(WidgetTester t, List<Key> keys) => [
  for (final k in keys)
    if (find.byKey(k).evaluate().isNotEmpty)
      if (t.renderObject(find.byKey(k)) case final RenderBox b) b.localToGlobal(Offset.zero) & b.size,
];

void main() {
  const font = InlineFont(size: 10, ascent: 10, descent: 2, lineHeight: 12, xHeight: 5);
  final cases = <String, Widget Function(TextStyle)>{
    'an inline flow': (s) => InlineFlow(key: const Key('a'), font: font, style: s, children: [InlineText(_words)]),
    'a float text': (s) => FloatText(
      TextSpan(text: _words),
      key: const Key('a'),
      style: s,
      lineHeight: 12,
    ),
    'an indented text': (s) => IndentedText(_words, key: const Key('a'), indent: 20, style: s),
    // A header's two groups of links floated side by side: in the fallback
    // face they do not fit beside each other and the right one drops a line.
    'floats holding inline flows': (s) => FloatFlow(
      children: [
        FloatSlot(
          float: FloatSide.left,
          bfc: true,
          child: InlineFlow(key: const Key('a'), font: font, style: s, children: [InlineText('aaaa bbbb cccc')]),
        ),
        FloatSlot(
          float: FloatSide.right,
          bfc: true,
          child: InlineFlow(key: const Key('b'), font: font, style: s, children: [InlineText('dddd eeee')]),
        ),
      ],
    ),
  };
  for (final MapEntry(key: name, value: build) in cases.entries) {
    testWidgets('$name: a face loaded after the first layout reflows it', (tester) async {
      tester.view
        ..physicalSize = const Size(800, 600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final family = 'Late ${name.replaceAll(' ', '_')}';
      final page = _page(build(TextStyle(fontFamily: family, fontSize: 10)));
      const keys = [Key('a'), Key('b')];
      await tester.pumpWidget(page);
      final fallback = _boxes(tester, keys);
      await _load(tester, family);
      await tester.pump();
      final reflowed = _boxes(tester, keys);
      // What a fresh mount lays out in the face, now loaded.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(page);
      final mounted = _boxes(tester, keys);
      expect(fallback, isNot(mounted), reason: 'the fallback face lays the words out otherwise');
      expect(reflowed, mounted, reason: 'laid out again in the face, without a new mount');
      expect(tester.takeException(), isNull);
    });
  }
}
