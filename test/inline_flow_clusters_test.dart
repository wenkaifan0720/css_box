// InlineFlow cuts text only between grapheme clusters (UAX #29; css-text-3
// 5 keeps a cluster whole): `overflow-wrap: anywhere` and its no-fit
// fallback, `word-break: break-all` and the ellipsis never split an emoji's
// two UTF-16 units, a letter from its accent, or a ZWJ sequence -- a cluster
// wider than the line is set whole, overflowing. Latin text is cut between
// any two letters as before.
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const font = InlineFont(size: 16, ascent: 12, descent: 4, lineHeight: 20);

Future<RenderInlineFlow> lay(
  WidgetTester tester,
  double width,
  String text, {
  OverflowWrap overflowWrap = OverflowWrap.normal,
  WordBreak wordBreak = WordBreak.normal,
  bool ellipsis = false,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: InlineFlow(
            font: font,
            style: const TextStyle(fontSize: 16),
            overflowWrap: overflowWrap,
            wordBreak: wordBreak,
            whiteSpace: ellipsis ? WhiteSpace.nowrap : WhiteSpace.normal,
            ellipsis: ellipsis,
            children: [InlineText(text)],
          ),
        ),
      ),
    ),
  );
  return tester.renderObject<RenderInlineFlow>(find.byType(InlineFlow));
}

List<String> texts(RenderInlineFlow r) => [for (final p in r.pieces) p.text];

bool loneSurrogate(String s) => s.runes.any((c) => c >= 0xD800 && c <= 0xDFFF);

void main() {
  testWidgets('overflow-wrap: anywhere keeps each emoji whole in a line narrower than one', (tester) async {
    // The review's probe: 5px wide, two emoji of 16px each. Each is set on
    // a line of its own, whole; no half-surrogate is measured or painted.
    final r = await lay(tester, 5, '😀😀', overflowWrap: OverflowWrap.anywhere);
    expect(tester.takeException(), isNull);
    expect(texts(r), ['😀', '😀']);
    expect(texts(r).any(loneSurrogate), isFalse);
  });

  testWidgets('overflow-wrap: anywhere keeps a letter with its combining accent', (tester) async {
    final r = await lay(tester, 5, 'éé', overflowWrap: OverflowWrap.anywhere);
    expect(tester.takeException(), isNull);
    expect(texts(r), ['é', 'é']);
  });

  testWidgets('overflow-wrap: anywhere keeps a ZWJ family and a skin tone whole', (tester) async {
    const family = '👨‍👩‍👧', thumb = '👍🏽';
    final r = await lay(tester, 5, '$family$thumb', overflowWrap: OverflowWrap.anywhere);
    expect(tester.takeException(), isNull);
    expect(texts(r), [family, thumb]);
  });

  testWidgets('word-break: break-all breaks between clusters, not inside one', (tester) async {
    final r = await lay(tester, 40, 'ééé 👍🏽👍🏽', wordBreak: WordBreak.breakAll);
    expect(tester.takeException(), isNull);
    for (final t in texts(r)) {
      expect(t.startsWith('́'), isFalse, reason: 'a piece starts on an accent: $t');
      expect(t.startsWith('🏽'), isFalse, reason: 'a piece starts on a skin tone: $t');
      expect(loneSurrogate(t), isFalse);
    }
  });

  testWidgets('an ellipsis cuts the text between clusters', (tester) async {
    const family = '👨‍👩‍👧';
    final r = await lay(tester, 100, family * 6, ellipsis: true);
    expect(tester.takeException(), isNull);
    final kept = texts(r).first;
    expect(texts(r).last, '…');
    expect(kept, isNotEmpty);
    expect(kept.replaceAll(family, ''), isEmpty, reason: 'the cut splits a family: ${kept.runes.toList()}');
  });

  testWidgets('an ellipsis keeps a first emoji whole where nothing of the line fits', (tester) async {
    final r = await lay(tester, 10, '😀😀😀', ellipsis: true);
    expect(tester.takeException(), isNull);
    expect(texts(r).first, '😀');
  });

  testWidgets('NEGATIVE: Latin text under overflow-wrap: anywhere still breaks between any two letters', (
    tester,
  ) async {
    // Every glyph one em: three a line in 50px.
    final r = await lay(tester, 50, 'abcdefgh', overflowWrap: OverflowWrap.anywhere);
    expect(texts(r), ['abc', 'def', 'gh']);
  });

  testWidgets('NEGATIVE: Latin text under word-break: break-all still breaks between any two letters', (tester) async {
    // Chrome 151: `abcdefg hi` three glyphs wide is `abc`, `def`, `g h`, `i`.
    final r = await lay(tester, 48, 'abcdefg hi', wordBreak: WordBreak.breakAll);
    final lines = <double, String>{};
    for (final p in r.pieces) {
      lines[p.baseline] = (lines[p.baseline] ?? '') + p.text;
    }
    expect([for (final l in lines.values) l.trim()], ['abc', 'def', 'g h', 'i']);
  });
}
