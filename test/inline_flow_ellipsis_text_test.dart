// InlineFlow.ellipsisText: where the block's primary face has no `…`,
// Blink's `NGLineTruncator` writes three full stops instead, and the line
// is cut for their room (fixtures/inline-frame-ellipsis n3).
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('an ellipsis of three full stops asks for their room and stands after what is kept', (tester) async {
    const font = InlineFont(size: 16, ascent: 13, descent: 3, lineHeight: 20, xHeight: 12.8);
    Future<RenderInlineFlow> lay(String text) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 100,
              child: InlineFlow(
                font: font,
                style: const TextStyle(fontSize: 16),
                whiteSpace: WhiteSpace.nowrap,
                ellipsis: true,
                ellipsisText: text,
                children: const [InlineText('ab cd ef gh')],
              ),
            ),
          ),
        ),
      );
      return tester.renderObject<RenderInlineFlow>(find.byType(InlineFlow));
    }

    // Every glyph one em: `…` leaves 84 of the 100, `ab cd` in it; three
    // full stops leave 52, `ab ` in it.
    var r = await lay('…');
    expect([for (final p in r.pieces) (p.text, p.x, p.width)], [('ab cd', 0.0, 80.0), ('…', 80.0, 16.0)]);
    r = await lay('...');
    expect([for (final p in r.pieces) (p.text, p.x, p.width)], [('ab ', 0.0, 48.0), ('...', 48.0, 48.0)]);
  });
}
