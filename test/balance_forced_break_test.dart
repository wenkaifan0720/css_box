import 'package:css_box/css_box.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// A FORCED BREAK ENDS A PARAGRAPH, each broken on its own: a balanced
// block re-breaks its first alone (Blink's `initiate_balancing_`), a
// pretty one every paragraph. Read whole, no set of breaks keeping the
// count moved them, and the block was left greedy
// (fixtures/inline-flow-pre-line-balance p4, p5). The test font's glyphs
// are 10 square at 10px.
void main() {
  Widget page(Widget Function(Widget) wrap, String text, double room) => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: room,
        child: wrap(Text(text, key: const Key('t'), style: const TextStyle(fontSize: 10))),
      ),
    ),
  );

  List<String> lines(WidgetTester tester) =>
      tester.renderObject<RenderParagraph>(find.byKey(const Key('t'))).text.toPlainText().split('\n');

  testWidgets('a balanced block over a forced break balances its first paragraph and leaves the next greedy', (
    tester,
  ) async {
    await tester.pumpWidget(page((c) => Balance(child: c), 'aaa bbb ccc ddd eee\naaa bbb ccc ddd eee', 150));
    final l = lines(tester);
    expect(l, hasLength(3));
    // Greedy, the first is `aaa bbb ccc ddd` / `eee`; balanced, its longer
    // line is 11 wide.
    expect([l[0].length, l[1].length].reduce((a, b) => a > b ? a : b), 11);
    // The second as it was, set greedily over two lines.
    expect(l[2], 'aaa bbb ccc ddd eee');
    expect(tester.getSize(find.byKey(const Key('t'))).height, 40);
  });

  testWidgets('a pretty block over forced breaks pulls a word down to each widow', (tester) async {
    await tester.pumpWidget(page((c) => Pretty(child: c), 'aaa bbb ccc ddd e\naaa bbb ccc ddd e', 150));
    expect(lines(tester), ['aaa bbb ccc', 'ddd e', 'aaa bbb ccc', 'ddd e']);
  });

  testWidgets('pretty over a forced break the paragraph before holds a widow', (tester) async {
    await tester.pumpWidget(page((c) => Pretty(child: c), 'aaa\naaa bbb ccc ddd e', 150));
    expect(lines(tester), ['aaa', 'aaa bbb ccc', 'ddd e']);
  });

  testWidgets('NEGATIVE: a balanced block whose first paragraph is one line is greedy after it', (tester) async {
    await tester.pumpWidget(page((c) => Balance(child: c), 'aaa\naaa bbb ccc ddd eee', 150));
    expect(lines(tester), ['aaa', 'aaa bbb ccc ddd eee']);
  });
}
