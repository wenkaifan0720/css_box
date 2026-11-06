// A LINE ASKS ITS PARAGRAPH NOTHING THAT ASSERTS, ON EVERY FLUTTER. A
// paragraph asks a dry baseline of each span's box that stands on the
// baseline, whatever it is asked (`RenderParagraph.computeMaxIntrinsicWidth`,
// its intrinsic heights, its dry layout). From Flutter 3.41 to 3.47 a proxy
// over a box that has no baseline -- the box a `WidgetSpan` puts round an
// empty box, a picture -- answers that by asking `RenderBox.
// computeDryBaseline`, which asserts in debug (flutter#189711). A `LineBox`
// asks its paragraph its widths to find the room its lines break in, in
// layout as well as when it is measured, and asks each atom of a line of
// atoms its dry baseline; each of those questions goes through css_box's
// hatch (`dry.dart`, `guardedAsk`), opened only where what the question
// reaches may assert. So such a line lays out, is measured and is asked dry
// alike on 3.38 and on 3.47, with the sizes the paragraph has laid out.
//
// NEGATIVE: the stock paragraph asked its width with nothing round it
// asserts where Flutter's proxies do (3.41 to 3.47), and answers elsewhere.
import 'package:css_box/css_box.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The test font draws every glyph 14px wide at 14px.
const _style = TextStyle(fontSize: 14, height: 1.0);

const _line = ValueKey('line');
const _text = ValueKey('text');

/// Whether this Flutter's proxies assert over a child that answers no dry
/// baseline (flutter#189711, 3.41 to 3.47).
final bool _proxiesAssert = () {
  try {
    RenderProxyBox().getDryBaseline(const BoxConstraints(), TextBaseline.alphabetic);
    return false;
  } on FlutterError {
    return true;
  }
}();

/// `aa` then a 20 x 10 box with no baseline, standing on the baseline.
Widget _para({bool softWrap = true, bool words = true}) => Text.rich(
  key: _text,
  TextSpan(
    children: [
      if (words) const TextSpan(text: 'aa'),
      const WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: SizedBox(width: 20, height: 10),
      ),
    ],
  ),
  softWrap: softWrap,
  style: _style,
);

Widget _page(Widget box) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 300,
      child: Align(alignment: Alignment.topLeft, child: box),
    ),
  ),
);

RenderBox _box(WidgetTester t, Key key) => t.renderObject<RenderBox>(find.byKey(key));

void main() {
  testWidgets('a line that never wraps lays out and answers its least width', (t) async {
    await t.pumpWidget(_page(LineBox(key: _line, child: _para(softWrap: false))));
    expect(t.takeException(), isNull);
    expect(t.getSize(find.byKey(_line)).width, 48);
    expect(_box(t, _line).getMinIntrinsicWidth(double.infinity), 48);
    expect(_box(t, _line).getMaxIntrinsicWidth(double.infinity), 48);
  });

  testWidgets('a line that wraps, measured across and down, is as wide and as tall as laid out', (t) async {
    await t.pumpWidget(_page(LineBox(key: _line, child: _para())));
    final laid = t.getSize(find.byKey(_line));
    await t.pumpWidget(
      _page(
        IntrinsicWidth(
          child: LineBox(key: _line, child: _para()),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    expect(t.getSize(find.byKey(_line)), laid);
    await t.pumpWidget(
      _page(
        IntrinsicHeight(
          child: LineBox(key: _line, child: _para()),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    expect(t.getSize(find.byKey(_line)), laid);
  });

  testWidgets('asked dry, the line answers the size it is laid out at', (t) async {
    await t.pumpWidget(_page(LineBox(key: _line, child: _para())));
    final line = _box(t, _line);
    expect(line.getDryLayout(const BoxConstraints(maxWidth: 300)), line.size);
    expect(line.getDryBaseline(const BoxConstraints(maxWidth: 300), TextBaseline.alphabetic), isNotNull);
  });

  testWidgets('a line of nothing but the box, its height given, measured down', (t) async {
    Widget line() => LineBox(
      key: _line,
      lineHeight: 20,
      ascent: 15,
      child: Text.rich(
        key: _text,
        const TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: SizedBox(width: 20, height: 10),
            ),
          ],
        ),
        style: _style,
        strutStyle: const StrutStyle(fontSize: 14, height: 20 / 14, forceStrutHeight: true),
      ),
    );
    await t.pumpWidget(_page(line()));
    final laid = t.getSize(find.byKey(_line));
    await t.pumpWidget(_page(IntrinsicHeight(child: line())));
    expect(t.takeException(), isNull);
    expect(t.getSize(find.byKey(_line)), laid);
  });

  testWidgets('NEGATIVE: the stock paragraph asked its width asserts where the proxies do', (t) async {
    await t.pumpWidget(_page(_para(softWrap: false)));
    final text = _box(t, _text);
    if (_proxiesAssert) {
      expect(() => text.getMaxIntrinsicWidth(double.infinity), throwsA(isA<FlutterError>()));
    } else {
      expect(text.getMaxIntrinsicWidth(double.infinity), 48);
    }
  });
}
