import 'dart:io';
import 'dart:typed_data';

import 'package:css_box/css_box.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The test font draws every glyph, the space too, 10 square at 10px: a
// 150px room holds fifteen characters a line.
const _style = TextStyle(fontSize: 10);

Widget _page(Widget child, {double room = 150, bool loose = false}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: room,
      child: loose ? Column(crossAxisAlignment: CrossAxisAlignment.center, children: [child]) : child,
    ),
  ),
);

/// A paragraph clamped at [lines], broken as [wrap] says.
Widget _clamped(String text, int lines, TextWrapStyle wrap, {TextAlign align = TextAlign.start}) => BlockEllipsis(
  textWrap: wrap,
  child: Text(
    text,
    key: const Key('p'),
    maxLines: lines,
    overflow: TextOverflow.ellipsis,
    textAlign: align,
    style: _style,
  ),
);

/// The paragraph's text as it is laid out: a line feed where a line is
/// forced to end, the clamp's cut and its ellipsis, and what is laid out
/// after it.
String _shown(WidgetTester t) =>
    t.renderObject<RenderParagraph>(find.byKey(const Key('p'))).text.toPlainText(includeSemanticsLabels: false);

void main() {
  testWidgets('a clamp the paragraph never reaches leaves it balanced whole', (tester) async {
    // Greedy: `aaa bbb ccc ddd / eeee`; balanced: 40 and 70 over, not 0 and 110.
    await tester.pumpWidget(_page(_clamped('aaa bbb ccc ddd eeee', 3, TextWrapStyle.balance)));
    expect(_shown(tester), 'aaa bbb ccc\nddd eeee');
    // Two lines high, as the greedy pair is.
    expect(tester.getSize(find.byType(BlockEllipsis)).height, 20);
  });

  testWidgets('a clamp the paragraph reaches balances the lines it keeps, and cuts where the last ended', (
    tester,
  ) async {
    // Greedy: `aaa bbb ccc ddd / ee / ffffffffffffff / g` -- the second line
    // short, the long word not fitting after it. Blink re-breaks the text
    // of the two lines kept (`aaa bbb / ccc ddd ee`, 80 and 50 over) and
    // puts the ellipsis after `ee`, where the second line ended greedily.
    // Balanced whole and then cut, the four lines would end elsewhere.
    const text = 'aaa bbb ccc ddd ee ffffffffffffff g';
    await tester.pumpWidget(_page(_clamped(text, 2, TextWrapStyle.balance)));
    expect(_shown(tester), 'aaa bbb\nccc ddd ee…\nffffffffffffff g');
    expect(tester.getSize(find.byType(BlockEllipsis)).height, 20);
    // NEGATIVE: greedy, the same clamp cuts the greedy lines.
    await tester.pumpWidget(_page(_clamped(text, 2, TextWrapStyle.auto)));
    expect(_shown(tester), 'aaa bbb ccc ddd ee…\nffffffffffffff g');
  });

  testWidgets('NEGATIVE: more lines kept than Blink balances stay greedy', (tester) async {
    // Eight greedy lines of `aaa bbb ccc ddd / ee` pairs under a clamp of
    // seven: past `kMaxLinesForBalance` (six), broken greedily.
    const text =
        'aaa bbb ccc ddd ee ffffffffffffff aaa bbb ccc ddd ee ffffffffffffff aaa bbb ccc ddd ee ffffffffffffff g h';
    await tester.pumpWidget(_page(_clamped(text, 7, TextWrapStyle.auto)));
    final greedy = _shown(tester);
    await tester.pumpWidget(_page(_clamped(text, 7, TextWrapStyle.balance)));
    expect(_shown(tester), greedy);
    expect(greedy.split('\n').first, endsWith('…'));
  });

  testWidgets('pretty: a clamp never reached spares the last line a word alone', (tester) async {
    // Greedy: `aaaaaaaaaaaaaaa / eee fff ggg hhh / ii`; pretty moves `hhh` down
    // (the first line, one word, has none to give).
    await tester.pumpWidget(_page(_clamped('aaaaaaaaaaaaaaa eee fff ggg hhh ii', 3, TextWrapStyle.pretty)));
    expect(_shown(tester), 'aaaaaaaaaaaaaaa\neee fff ggg\nhhh ii');
  });

  testWidgets('NEGATIVE: pretty under a clamp whose line is full is the greedy cut', (tester) async {
    // The clamp's line, `eee fff ggg hhh`, is no widow: nothing moves.
    const text = 'aaa bbb ccc ddd eee fff ggg hhh ii';
    await tester.pumpWidget(_page(_clamped(text, 2, TextWrapStyle.pretty)));
    final pretty = _shown(tester);
    await tester.pumpWidget(_page(_clamped(text, 2, TextWrapStyle.auto)));
    expect(pretty, _shown(tester));
  });

  testWidgets('NEGATIVE: one line, a word wider than the room, and a forced break stay as they are', (tester) async {
    for (final text in ['aaa bbb', 'aaa bbbbbbbbbbbbbbbbbbbb ccc ddd', 'aaa bbb ccc ddd\neeee']) {
      await tester.pumpWidget(_page(_clamped(text, 3, TextWrapStyle.auto)));
      final greedy = _shown(tester);
      await tester.pumpWidget(_page(_clamped(text, 3, TextWrapStyle.balance)));
      expect(_shown(tester), greedy, reason: text);
    }
  });

  testWidgets('re-broken lines that wrap fill their loose room, as the greedy ones do', (tester) async {
    await tester.pumpWidget(
      _page(_clamped('aaa bbb ccc ddd eeee', 3, TextWrapStyle.balance, align: TextAlign.center), loose: true),
    );
    expect(_shown(tester), 'aaa bbb ccc\nddd eeee');
    expect(tester.getSize(find.byType(BlockEllipsis)).width, 150);
    // Its widths are the greedy ones: balancing sizes nothing.
    final b = tester.renderObject<RenderBox>(find.byType(BlockEllipsis));
    expect(b.getMaxIntrinsicWidth(double.infinity), 200);
    expect(b.getMinIntrinsicWidth(double.infinity), 40);
  });

  testWidgets('under a clamp over blocks, the paragraph holding the cut balances the lines left it', (tester) async {
    // One line before it, so the clamp of three leaves it two.
    await tester.pumpWidget(
      _page(
        LineClamp(
          lines: 3,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ClampedBlock(
                child: BlockEllipsis(child: Text('one', style: _style)),
              ),
              ClampedBlock(
                child: BlockEllipsis(
                  textWrap: TextWrapStyle.balance,
                  child: const Text('aaa bbb ccc ddd ee ffffffffffffff g', key: Key('p'), style: _style),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(_shown(tester), 'aaa bbb\nccc ddd ee…\nffffffffffffff g');
    expect(tester.getSize(find.byType(LineClamp)).height, 30);
  });

  // THE LINES CHROME KEPT, read off `fixtures/line-clamp-text-wrap` (Inter
  // 20px on 28px lines in a 260px block): each block's first rows, the
  // clamp's ellipsis aside.
  group('in Chrome', () {
    setUpAll(() async {
      final bytes = Uint8List.fromList(await File('${Directory.current.path}/test/fonts/Inter.ttf').readAsBytes());
      await (FontLoader('Fx')..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
    });
    const inter = TextStyle(fontFamily: 'Fx', fontSize: 20, height: 1.4);

    /// The first [lines] lines the paragraph is laid out on, the ellipsis off.
    List<String> kept(WidgetTester tester, int lines) {
      final p = tester.renderObject<RenderParagraph>(find.byKey(const Key('p')));
      final painter = TextPainter(text: p.text, textDirection: TextDirection.ltr)..layout(maxWidth: p.size.width);
      final plain = p.text.toPlainText(includeSemanticsLabels: false);
      final out = <String>[];
      for (final m in painter.computeLineMetrics().take(lines)) {
        final r = painter.getLineBoundary(painter.getPositionForOffset(Offset(m.left + 1, m.baseline)));
        out.add(plain.substring(r.start, r.end).replaceAll('…', '').trim());
      }
      painter.dispose();
      return out;
    }

    for (final (text, lines, wrap, rows) in const [
      // b1, b2: a clamp never reached.
      (
        'Plans for every stage of your company today',
        3,
        TextWrapStyle.balance,
        ['Plans for every stage', 'of your company today'],
      ),
      (
        'Plans for every stage of your company today',
        3,
        TextWrapStyle.auto,
        ['Plans for every stage of', 'your company today'],
      ),
      // b3: the widow pulls the tail down.
      (
        'Organize your content with built-in type checks for each',
        3,
        TextWrapStyle.pretty,
        ['Organize your content', 'with built-in type checks', 'for each'],
      ),
      // b5, b6: the two lines kept balanced, the second ending at `team`.
      (
        'Plans for every stage of the team internationalization included today',
        2,
        TextWrapStyle.balance,
        ['Plans for every', 'stage of the team'],
      ),
      (
        'Plans for every stage of the team internationalization included today',
        2,
        TextWrapStyle.auto,
        ['Plans for every stage of', 'the team'],
      ),
      // b7, b8: the clamp's line one short word.
      (
        'Find a quiet place to read a book counterrevolutionaries territory',
        2,
        TextWrapStyle.pretty,
        ['Find a quiet place to read', 'a book'],
      ),
      (
        'Find a quiet place to read a book counterrevolutionaries territory',
        2,
        TextWrapStyle.auto,
        ['Find a quiet place to read a', 'book'],
      ),
      // b20: the three lines kept are even already; all four balanced would not be.
      (
        'Pick a plan and upgrade anytime from the billing page of your workspace settings menu',
        3,
        TextWrapStyle.balance,
        ['Pick a plan and upgrade', 'anytime from the billing', 'page of your workspace'],
      ),
      // b9: seven lines kept, more than Blink balances.
      (
        'Astor was designed to work with your content, no matter where it lives, so you can load data from the file '
            'system, an external API, or whichever content system your team already writes in every day of the week.',
        7,
        TextWrapStyle.balance,
        [
          'Astor was designed to',
          'work with your content, no',
          'matter where it lives, so',
          'you can load data from the',
          'file system, an external',
          'API, or whichever content',
          'system your team already',
        ],
      ),
    ]) {
      testWidgets('${wrap.name}, clamp of $lines: ${rows.first} ...', (tester) async {
        await tester.pumpWidget(
          _page(
            BlockEllipsis(
              textWrap: wrap,
              child: Text(text, key: const Key('p'), maxLines: lines, overflow: TextOverflow.ellipsis, style: inter),
            ),
            room: 260,
          ),
        );
        expect(kept(tester, lines), rows);
      });
    }
  });
}
