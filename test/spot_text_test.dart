import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

Widget _page(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 30, child: child),
  ),
);

// The test face is an em square a glyph, so at 10px `ab` is 20 wide, and
// a forced strut of twice the size makes every line 20 tall.
const _style = TextStyle(fontSize: 10);
const _strut = StrutStyle(fontSize: 10, height: 2, forceStrutHeight: true);

Widget _marked(List<InlineSpan> spans, Map<int, GlobalKey> boxes) => SpotScope(
  child: Stack(
    clipBehavior: Clip.none,
    fit: StackFit.passthrough,
    children: [
      SpotText(
        child: LineBox(
          child: Text.rich(
            TextSpan(children: spans),
            style: _style,
            strutStyle: _strut,
          ),
        ),
      ),
      for (final MapEntry(:key, :value) in boxes.entries)
        Positioned(
          left: 0,
          top: 0,
          child: SpotShift(
            id: key,
            across: true,
            child: SizedBox(key: value, width: 4, height: 4),
          ),
        ),
    ],
  ),
);

void main() {
  testWidgets('a mark inside a word keeps the word whole, and the box at the letter after it', (tester) async {
    final box = GlobalKey();
    await tester.pumpWidget(
      _page(_marked(const [TextSpan(text: 'ab'), SpotSpan(id: 4), TextSpan(text: 'cd')], {4: box})),
    );
    // One line: `abcd` is one word, too wide for 30 and overflowing it.
    expect(tester.getSize(find.byType(LineBox)).height, 20);
    expect(tester.getTopLeft(find.byKey(box)), const Offset(20, 0));
  });

  testWidgets('NEGATIVE: a placeholder mark breaks the word in two', (tester) async {
    await tester.pumpWidget(
      _page(
        SpotScope(
          child: LineBox(
            child: Text.rich(
              const TextSpan(
                children: [
                  TextSpan(text: 'ab'),
                  WidgetSpan(child: SpotMark(id: 4), alignment: PlaceholderAlignment.top),
                  TextSpan(text: 'cd'),
                ],
              ),
              style: _style,
              strutStyle: _strut,
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(LineBox)).height, 40);
  });

  testWidgets('each mark reads its own point, on the line it is on', (tester) async {
    final first = GlobalKey(), second = GlobalKey();
    await tester.pumpWidget(
      _page(
        _marked(
          const [TextSpan(text: 'a'), SpotSpan(id: 1), TextSpan(text: 'a b'), SpotSpan(id: 2), TextSpan(text: 'b')],
          {1: first, 2: second},
        ),
      ),
    );
    // `aa ` / `bb`: the second mark is on the second line, one letter in.
    expect(tester.getSize(find.byType(LineBox)).height, 40);
    expect(tester.getTopLeft(find.byKey(first)), const Offset(10, 0));
    expect(tester.getTopLeft(find.byKey(second)), const Offset(10, 20));
  });

  testWidgets('a placeholder before the span counts as one character', (tester) async {
    final box = GlobalKey();
    await tester.pumpWidget(
      _page(
        _marked(
          const [
            WidgetSpan(child: SizedBox(width: 6, height: 6)),
            TextSpan(text: 'a'),
            SpotSpan(id: 3),
            TextSpan(text: 'b'),
          ],
          {3: box},
        ),
      ),
    );
    expect(tester.getTopLeft(find.byKey(box)), const Offset(16, 0));
  });
}
