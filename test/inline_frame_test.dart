import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';

// The test font draws every glyph 14px wide at 14px, 10.5 of it above the
// baseline and 3.5 below.
const _style = TextStyle(fontSize: 14, height: 1.0);
const _chip = Color(0xFFFEE440);

Widget _frame({Widget child = const Text('chip', style: _style)}) => InlineFrame(
  key: const Key('f'),
  decoration: const BoxDecoration(color: _chip),
  insets: const EdgeInsets.fromLTRB(8, 2, 8, 2),
  margin: const EdgeInsets.only(left: 3, right: 5),
  ascent: 11,
  descent: 3,
  child: child,
);

Widget _page(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(alignment: Alignment.topLeft, child: child),
);

void main() {
  testWidgets('the room across is round the content, and the height is the content\'s', (tester) async {
    await tester.pumpWidget(_page(_frame()));
    // `chip` is 56 wide; 8 + 8 of padding and 3 + 5 of margin across.
    expect(tester.getSize(find.byKey(const Key('f'))), const Size(80, 14));
    expect(tester.getTopLeft(find.text('chip')), const Offset(11, 0));
    final r = tester.renderObject<RenderInlineFrame>(find.byKey(const Key('f')));
    expect(r.getDryBaseline(const BoxConstraints(), TextBaseline.alphabetic), 10.5);
    expect(r.getMinIntrinsicWidth(double.infinity), 80);
    expect(r.getMaxIntrinsicWidth(double.infinity), 80);
  });

  testWidgets('the frame is painted round the content area, out over and under the line', (tester) async {
    await tester.pumpWidget(_page(_frame()));
    final r = tester.renderObject<RenderInlineFrame>(find.byKey(const Key('f')));
    // From the margin, 56 + 16 across; 11 over the baseline and 3 under
    // it, each grown by the 2 of padding: -2.5 to 15.5, snapped to whole
    // pixels half up: -2 to 16.
    expect(r, paints..rect(rect: const Rect.fromLTRB(3, -2, 75, 16), color: _chip));
  });

  testWidgets('the frame\'s edges are snapped to whole pixels where it lands, as Blink does', (tester) async {
    for (final (at, left, right) in const [(10.25, 2.75, 74.75), (10.5, 3.5, 75.5)]) {
      await tester.pumpWidget(
        _page(
          Padding(
            padding: EdgeInsets.only(left: at),
            child: _frame(),
          ),
        ),
      );
      final r = tester.renderObject<RenderInlineFrame>(find.byKey(const Key('f')));
      // 13.25 and 85.25 on the page are 13 and 85; 13.5 and 85.5 are 14
      // and 86.
      expect(
        r,
        paints..rect(rect: Rect.fromLTRB(left, -2, right, 16), color: _chip),
        reason: '$at',
      );
    }
  });

  testWidgets('in a paragraph it stands on the line\'s baseline', (tester) async {
    await tester.pumpWidget(
      _page(
        Text.rich(
          const TextSpan(
            children: [
              TextSpan(text: 'ab '),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: InlineFrame(
                  key: Key('f'),
                  decoration: BoxDecoration(color: _chip),
                  insets: EdgeInsets.symmetric(horizontal: 4),
                  ascent: 11,
                  descent: 3,
                  child: Text('cd', style: _style),
                ),
              ),
              TextSpan(text: ' ef'),
            ],
          ),
          style: _style,
        ),
      ),
    );
    // After `ab ` (42), the frame's left padding, then `cd` on the line.
    expect(tester.getTopLeft(find.byKey(const Key('f'))), const Offset(42, 0));
    expect(tester.getTopLeft(find.text('cd')), const Offset(46, 0));
    expect(tester.getSize(find.byKey(const Key('f'))), const Size(36, 14));
  });
}
