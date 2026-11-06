// `FloatText` AND `InlineFlow` SCALE THEIR TEXT AS A `Text` DOES: by the
// `textScaler` they are given, or the ambient `MediaQuery`'s where they are
// given none. The glyphs of every run, the strut every line stands on and
// each inline box's font scale together, so the lines grow with what they
// hold. Under a text scale of 2 both stood as they were at 1 -- a
// `FloatText` of `Hello` 50 wide, an `InlineFlow`'s line 12 tall -- beside
// `Text`s twice their size.
// NEGATIVE: ONLY TEXT SCALES. An atomic inline, or a `WidgetSpan` on a
// `FloatText`'s line, is laid out at its own size, and a `Text` inside it
// scales once, by its own reading of the scale: 2x at 2, not the 4x a box
// scaled as a whole round a `Text` that scales again would draw; a box of a
// stated size, and an inline box's padding, stay as written. And
// `TextScaler.noScaling` keeps everything as written under any ambient
// scale. The test font's glyphs are 1em square, 0.75em over the baseline.
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _ten = TextStyle(fontSize: 10);
const _font = InlineFont(size: 10, ascent: 8, descent: 2, lineHeight: 12);
const _key = ValueKey('box');

Widget host(Widget child, {double scale = 1}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: DefaultTextStyle(
      style: _ten,
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

Future<Size> sizeAt(WidgetTester t, Widget child, double scale) async {
  await t.pumpWidget(host(child, scale: scale));
  return t.getSize(find.byKey(_key));
}

void main() {
  group('FloatText', () {
    testWidgets('follows the ambient text scale', (t) async {
      // At 2 the paragraph is the one its text makes at twice the size:
      // 100 wide, and its `normal` line the face's at 20px, rounded as
      // Blink rounds it (15 + 5), not 11 twice.
      const text = FloatText(TextSpan(text: 'Hello'), key: _key);
      expect(await sizeAt(t, text, 1), const Size(50, 11));
      const big = FloatText(
        TextSpan(text: 'Hello'),
        key: _key,
        style: TextStyle(fontSize: 20),
      );
      final twice = await sizeAt(t, big, 1);
      expect(twice, const Size(100, 20));
      expect(await sizeAt(t, text, 2), twice);
    });

    testWidgets('a line height told scales with the glyphs', (t) async {
      const text = FloatText(TextSpan(text: 'Hello'), key: _key, lineHeight: 20);
      expect(await sizeAt(t, text, 1), const Size(50, 20));
      expect(await sizeAt(t, text, 2), const Size(100, 40));
    });

    testWidgets('a scaler given beats the ambient one', (t) async {
      const text = FloatText(
        TextSpan(text: 'Hello'),
        key: _key,
        lineHeight: 20,
        textScaler: TextScaler.noScaling,
      );
      expect(await sizeAt(t, text, 2), const Size(50, 20));
      const doubled = FloatText(
        TextSpan(text: 'Hello'),
        key: _key,
        lineHeight: 20,
        textScaler: TextScaler.linear(2),
      );
      expect(await sizeAt(t, doubled, 1), const Size(100, 40));
    });

    testWidgets('NEGATIVE: a widget on the line is laid out at its own size, its text scaled once', (t) async {
      const text = FloatText(
        TextSpan(
          children: [
            TextSpan(text: 'Go '),
            WidgetSpan(child: Text('ab', style: _ten)),
            WidgetSpan(child: SizedBox(key: ValueKey('pic'), width: 30, height: 6)),
          ],
        ),
        key: _key,
        lineHeight: 20,
      );
      await t.pumpWidget(host(text));
      expect(t.getSize(find.text('ab')).width, 20);
      await t.pumpWidget(host(text, scale: 2));
      expect(t.getSize(find.text('ab')).width, 40);
      expect(t.getSize(find.byKey(const ValueKey('pic'))), const Size(30, 6));
    });
  });

  group('InlineFlow', () {
    testWidgets('follows the ambient text scale, strut and all', (t) async {
      const flow = InlineFlow(key: _key, font: _font, children: [InlineText('Hello')]);
      expect(await sizeAt(t, const SizedBox(width: 300, child: flow), 1), const Size(300, 12));
      final two = await sizeAt(t, const SizedBox(width: 300, child: flow), 2);
      expect(two.height, 24);
      // Ten glyphs of 20 do not fit 150: the words break where 20px glyphs
      // do.
      const narrow = InlineFlow(key: _key, font: _font, children: [InlineText('Hello Hello')]);
      expect((await sizeAt(t, const SizedBox(width: 150, child: narrow), 1)).height, 12);
      expect((await sizeAt(t, const SizedBox(width: 150, child: narrow), 2)).height, 48);
    });

    testWidgets('an inline box\'s own size scales once, an inherited one once', (t) async {
      // `aa` in a box of 20px text, `bb` in one of colour alone: at 2 the
      // first is 80 wide and the second 40 -- not 160 and 80, scaled again
      // over a scaled parent.
      const flow = InlineFlow(
        key: _key,
        font: _font,
        children: [
          InlineBox(
            key: ValueKey('big'),
            style: TextStyle(fontSize: 20),
            font: InlineFont(size: 20, ascent: 15, descent: 5, lineHeight: 24),
            children: [InlineText('aa')],
          ),
          InlineBox(
            key: ValueKey('plain'),
            style: TextStyle(color: Color(0xFF00FF00)),
            children: [InlineText('bb')],
          ),
        ],
      );
      double widthOf(WidgetTester t, String key) {
        final r = t.renderObject<RenderInlineFlow>(find.byKey(_key));
        return r.boxRects[ValueKey(key)]!.width;
      }

      await t.pumpWidget(host(const SizedBox(width: 400, child: flow)));
      expect([widthOf(t, 'big'), widthOf(t, 'plain')], [40, 20]);
      await t.pumpWidget(host(const SizedBox(width: 400, child: flow), scale: 2));
      expect([widthOf(t, 'big'), widthOf(t, 'plain')], [80, 40]);
      // The line is the larger box's 24, scaled: 48.
      expect(t.getSize(find.byKey(_key)).height, 48);
    });

    testWidgets('a scaler given beats the ambient one', (t) async {
      const flow = InlineFlow(
        key: _key,
        font: _font,
        textScaler: TextScaler.noScaling,
        children: [InlineText('Hello')],
      );
      expect(await sizeAt(t, const SizedBox(width: 300, child: flow), 2), const Size(300, 12));
    });

    testWidgets('NEGATIVE: an atomic inline is laid out at its own size, its text scaled once', (t) async {
      const flow = InlineFlow(
        key: _key,
        font: _font,
        children: [
          InlineText('Go '),
          InlineAtom(child: Text('ab', style: _ten)),
          InlineAtom(child: SizedBox(key: ValueKey('pic'), width: 30, height: 6)),
          InlineBox(key: ValueKey('pad'), padding: EdgeInsets.symmetric(horizontal: 5), children: [InlineText('c')]),
        ],
      );
      await t.pumpWidget(host(const SizedBox(width: 400, child: flow)));
      expect(t.getSize(find.text('ab')).width, 20);
      await t.pumpWidget(host(const SizedBox(width: 400, child: flow), scale: 2));
      expect(t.getSize(find.text('ab')).width, 40);
      expect(t.getSize(find.byKey(const ValueKey('pic'))), const Size(30, 6));
      final r = t.renderObject<RenderInlineFlow>(find.byKey(_key));
      // `c` at 20, and the padding's 5 a side as written.
      expect(r.boxRects[const ValueKey('pad')]!.width, 30);
    });
  });
}
