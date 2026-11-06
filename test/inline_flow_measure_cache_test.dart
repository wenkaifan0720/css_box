// AN INLINE FLOW LETS GO OF THE WIDTHS OF WORDS IT NO LONGER HOLDS. It
// measures each word, space and run of a line by shaping it, and keeps the
// width: the lines broken again at another width, and the same words given
// again, shape nothing twice. It kept every width it ever measured, for as
// long as it lived -- a feed or a status line whose words change every
// second held all of them. A width is now kept for two generations of the
// content: a content flattened again starts one, and what the last asked
// for and this one does not is dropped with the next.
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _font = InlineFont(size: 10, ascent: 7.5, descent: 2.5, lineHeight: 12);
const _style = TextStyle(fontFamily: 'FlutterTest', fontSize: 10);

/// Twenty words of their own for [generation].
List<InlineNode> _words(int generation) => [for (var i = 0; i < 20; i++) InlineText('g${generation}w$i ')];

Widget _host(List<InlineNode> children, {double width = 120}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: InlineFlow(font: _font, style: _style, children: children),
    ),
  ),
);

({int shaped, int held}) _measured(WidgetTester t) =>
    t.renderObject<RenderInlineFlow>(find.byType(InlineFlow)).debugMeasured;

void main() {
  testWidgets('new words given again and again: the widths held stay those of the last two contents', (t) async {
    await t.pumpWidget(_host(_words(0)));
    final one = _measured(t).held;
    expect(one, greaterThan(20));
    var most = 0;
    for (var g = 1; g <= 40; g++) {
      await t.pumpWidget(_host(_words(g)));
      final held = _measured(t).held;
      if (held > most) most = held;
    }
    // Two contents' worth, however many came before: forty would hold
    // forty times one.
    expect(most, lessThanOrEqualTo(2 * one + 2));
    expect(_measured(t).shaped, greaterThan(40 * 20));
  });

  testWidgets('a content of more words than a generation holds keeps no more than two generations', (t) async {
    final many = [for (var i = 0; i < 5000; i++) InlineText('m$i ')];
    await t.pumpWidget(_host(many, width: 400));
    expect(_measured(t).held, lessThanOrEqualTo(2 * 4096));
    expect(_measured(t).shaped, greaterThan(5000));
  });

  testWidgets('NEGATIVE: laid out again at a width it was laid out at before, it shapes nothing again', (t) async {
    final words = _words(0);
    await t.pumpWidget(_host(words, width: 120));
    await t.pumpWidget(_host(words, width: 70));
    final shaped = _measured(t).shaped;
    await t.pumpWidget(_host(words, width: 120));
    await t.pumpWidget(_host(words, width: 70));
    expect(_measured(t).shaped, shaped);
  });

  testWidgets('NEGATIVE: the same words in a new list (the widget rebuilt) are shaped once', (t) async {
    await t.pumpWidget(_host(_words(0)));
    final shaped = _measured(t).shaped;
    for (var i = 0; i < 5; i++) {
      await t.pumpWidget(_host(_words(0)));
    }
    expect(_measured(t).shaped, shaped);
  });

  testWidgets('NEGATIVE: words let go and given back are measured to the same lines', (t) async {
    await t.pumpWidget(_host(_words(0)));
    final r = t.renderObject<RenderInlineFlow>(find.byType(InlineFlow));
    final before = [for (final p in r.pieces) (p.text, p.x, p.baseline, p.width)];
    final size = r.size;
    for (var g = 1; g <= 3; g++) {
      await t.pumpWidget(_host(_words(g)));
    }
    await t.pumpWidget(_host(_words(0)));
    expect([for (final p in r.pieces) (p.text, p.x, p.baseline, p.width)], before);
    expect(r.size, size);
  });
}
