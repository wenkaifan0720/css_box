// A FLOATTEXT LINE IS READ OFF THE WORDS UP TO A CUT NOT FAR PAST IT, AND
// BREAKS WHERE IT DID WHEN IT WAS READ OFF ALL THE REST OF THE PARAGRAPH.
// Set from all the rest, each line shaped what was left of the paragraph,
// and a long one in a narrow column grew as the square of its length
// (benchmark/scaling_benchmark.dart). Over a sweep of paragraphs -- words
// and spans of other sizes, hyphens, brackets and quotes, forced breaks, a
// word longer than any cut, Japanese with its punctuation, widgets on the
// lines, Hebrew -- at widths from a few words to many, alone and beside a
// float, set at the start and justified: every line, where it is drawn,
// how wide, and every widget on it, is the same either way. A paragraph
// with a letter or word spacing in it is set from all the rest: there a
// cut did move lines.
import 'dart:io';

import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _style = TextStyle(fontFamily: 'FlutterTest', fontSize: 10);

const _vocabulary = [
  'the', 'line', 'box', 'of', 'a', 'paragraph', 'is', 'set', 'beside', 'float', 'and', 'its', //
  'words', 'break', 'where', 'they', 'fit', 'long-term', '(see', 'below)', '"quoted"', '2,048',
  'internationalization', 'x', 'room', 'it', 'to', 'in', 'well-known', 'e.g.', 'U.S.', 'end.',
];

/// [n] words off the vocabulary, the same ones each time for [seed].
List<String> _words(int n, int seed) => [
  for (var i = 0; i < n; i++) _vocabulary[(i * 7 + seed * 13 + i ~/ 5) % _vocabulary.length],
];

const _bold = TextStyle(fontSize: 14, fontWeight: FontWeight.bold);
const _small = TextStyle(fontSize: 7);

/// The paragraphs of the sweep, each a span.
Map<String, InlineSpan> _paragraphs() {
  final w = _words(700, 1);
  return {
    'words': TextSpan(text: w.join(' ')),
    'spans and breaks': TextSpan(
      children: [
        for (var i = 0; i < 40; i++)
          TextSpan(
            text: '${_words(14, i).join(' ')}${i % 9 == 8 ? '\n' : ' '}',
            style: i % 3 == 1 ? _bold : (i % 5 == 2 ? _small : null),
          ),
      ],
    ),
    'a word longer than a cut': TextSpan(text: '${_words(60, 2).join(' ')} ${'y' * 700} ${_words(80, 3).join(' ')}'),
    'widgets on the lines': TextSpan(
      children: [
        for (var i = 0; i < 30; i++) ...[
          TextSpan(text: '${_words(12, i + 5).join(' ')} '),
          WidgetSpan(
            alignment: i.isEven ? PlaceholderAlignment.baseline : PlaceholderAlignment.middle,
            baseline: TextBaseline.alphabetic,
            child: SizedBox(width: 12.0 + i % 4 * 9, height: 8.0 + i % 3 * 5),
          ),
          const TextSpan(text: ' '),
        ],
      ],
    ),
    'japanese': TextSpan(
      text: List.filled(
        60,
        '日本語の文章は、空白を置かずに続けて書かれる。「括弧」や（丸括弧）の前後でも行は折り返される。'
        'ひらがなとカタカナ、そして漢字が混ざり合う。',
      ).join(),
    ),
    'hebrew': TextSpan(text: List.filled(80, 'שלום עולם זה משפט ארוך 123 and some words').join(' ')),
  };
}

/// One FloatText of [text] in [width], beside a float where [floated],
/// laid out from nothing.
Widget _page(InlineSpan text, double width, {required bool floated, required TextAlign align, Key? key}) {
  final para = FloatText(text, style: _style, lineHeight: 14, textAlign: align);
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        key: key,
        width: width,
        child: floated
            ? FloatFlow(
                children: [
                  FloatSlot(float: FloatSide.left, width: width / 3, height: 90, child: const SizedBox()),
                  para,
                ],
              )
            : para,
      ),
    ),
  );
}

/// Everything the layout and the paint come to: the lines, the box's size,
/// each line's drawn width, and where each widget on them stands.
Future<List<Object>> _laid(WidgetTester t, Widget page) async {
  await t.pumpWidget(page);
  final r = t.renderObject<RenderFloatText>(find.byType(FloatText));
  final kids = <Offset>[];
  r.visitChildren((c) => kids.add((c as RenderBox).localToGlobal(Offset.zero)));
  return [
    [for (final l in r.debugLines) (l.text, l.x, l.y, l.baseline, l.width)],
    r.size,
    r.debugDrawnWidths,
    kids,
  ];
}

void main() {
  tearDown(() => RenderFloatText.debugWholeRest = false);

  final paragraphs = _paragraphs();
  for (final MapEntry(key: name, value: text) in paragraphs.entries) {
    testWidgets('$name: the lines read off a cut are the lines read off all the rest', (t) async {
      var cases = 0;
      for (final width in const [44.0, 97.0, 163.0, 290.0, 610.0]) {
        for (final floated in const [false, true]) {
          for (final align in const [TextAlign.start, TextAlign.justify]) {
            RenderFloatText.debugWholeRest = false;
            final cut = await _laid(t, _page(text, width, floated: floated, align: align, key: UniqueKey()));
            RenderFloatText.debugWholeRest = true;
            final whole = await _laid(t, _page(text, width, floated: floated, align: align, key: UniqueKey()));
            expect(cut, whole, reason: '$name at $width, floated: $floated, $align');
            expect((cut[0] as List).length, greaterThan(1), reason: '$name at $width');
            cases++;
          }
        }
      }
      expect(cases, 20);
    });
  }

  testWidgets('NEGATIVE: words with a letter or word spacing in them are set from all the rest, '
      'and come out the same', (t) async {
    // Skia spaces such a paragraph in one pass, and a line can move with
    // words far past it: set from a cut, 46 of these 72 came out otherwise
    // in Inter. Without the spacing the same paragraphs set from a cut
    // came out the same, all 72.
    final inter = File('test/fonts/Inter.ttf').readAsBytesSync();
    await (FontLoader('Inter')..addFont(Future.value(ByteData.view(Uint8List.fromList(inter).buffer)))).load();
    InlineSpan text(int variant) => TextSpan(
      children: [
        for (var i = 0; i < 80; i++)
          TextSpan(
            text: '${_words(9, i + 2).join(' ')} ',
            style: switch ((i + variant) % 6) {
              1 => const TextStyle(letterSpacing: 1.5, fontSize: 12),
              2 => const TextStyle(fontSize: 19, fontStyle: FontStyle.italic),
              3 => const TextStyle(wordSpacing: 4, fontWeight: FontWeight.w300),
              4 => const TextStyle(height: 1.8),
              _ => null,
            },
          ),
      ],
    );
    Widget page(int variant, double width) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          key: UniqueKey(),
          width: width,
          child: FloatText(text(variant), style: const TextStyle(fontFamily: 'Inter', fontSize: 15), lineHeight: 22),
        ),
      ),
    );
    var cases = 0;
    for (var v = 0; v < 6; v++) {
      for (final width in const [47.0, 77.0, 120.0, 172.0, 211.0, 263.0, 333.0, 414.0, 512.0, 640.0, 777.0, 1000.0]) {
        RenderFloatText.debugWholeRest = false;
        final cut = await _laid(t, page(v, width));
        RenderFloatText.debugWholeRest = true;
        final whole = await _laid(t, page(v, width));
        expect(cut, whole, reason: 'variant $v at $width');
        cases++;
      }
    }
    expect(cases, 72);
  });

  testWidgets('NEGATIVE: a paragraph with no cut in it is set from all the rest, and comes out the same', (t) async {
    // One unbroken run: no space, no ideograph, so no cut, and every line
    // is set as it always was.
    final text = TextSpan(text: 'z' * 3000);
    RenderFloatText.debugWholeRest = false;
    final cut = await _laid(t, _page(text, 120, floated: false, align: TextAlign.start, key: UniqueKey()));
    RenderFloatText.debugWholeRest = true;
    final whole = await _laid(t, _page(text, 120, floated: false, align: TextAlign.start, key: UniqueKey()));
    expect(cut, whole);
  });
}
