// A KEYWORD FLOOR IS THE CONTENT'S WIDTH, whatever the box's own `width`
// says (css-sizing-3 5.1: a box's min- and max-content sizes are its
// content's), and `fit-content` is that clamped into the room less the
// margins: min(max-content, max(min-content, stretch-fit)). Chrome, a
// `<fieldset>` at `width: 100px; min-width: fit-content` round `seven
// eight nine ten` in a 220px column is as wide as the words on one line
// (`fixtures/fieldset-in-float-flow` p5, was f5).
import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The test font sets every glyph one em wide: at 10px 'aaaa bbbb' is 90
// wide on one line and 40 at its longest word.
const _style = TextStyle(fontFamily: 'FlutterTest', fontSize: 10, height: 1, color: Color(0xFF000000));
const _box = Key('box');

Future<double> _width(
  WidgetTester t, {
  required double room,
  double? width,
  required FloatWidth floor,
  double margin = 0,
}) async {
  t.view.physicalSize = const Size(800, 600);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: room,
          child: FloatFlow(
            children: [
              FloatSlot(
                width: width,
                minWidthKeyword: floor,
                margin: EdgeInsets.only(left: margin),
                child: const Text('aaaa bbbb', key: _box, style: _style),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return t.getSize(find.byKey(_box)).width;
}

// A CONTEXT OF ITS OWN BESIDE A FLOAT is clamped into the room BESIDE it:
// the stretch-fit size is the room the flow tries the box in, less its
// margins (css-sizing-3 5.1, CSS 2.1 9.5), so the floor is the words' at
// most that, their longest word at the least, and the box stands beside the
// float wherever that fits (`fixtures/fieldset-in-float-flow` n6).
Future<Rect> _beside(WidgetTester t, {FloatClear clear = FloatClear.none}) async {
  t.view.physicalSize = const Size(800, 600);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 200,
          child: FloatFlow(
            children: [
              const FloatSlot(float: FloatSide.left, width: 60, height: 30, child: SizedBox(width: 60, height: 30)),
              FloatSlot(
                bfc: true,
                width: 20,
                clear: clear,
                minWidthKeyword: FloatWidth.fitContent,
                child: const Text('aaaa bbbb cccc dddd', key: _box, style: _style),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return t.getTopLeft(find.byKey(_box)) & t.getSize(find.byKey(_box));
}

void main() {
  testWidgets('a fit-content floor past a width of its own is the words on one line where they fit', (t) async {
    expect(await _width(t, room: 200, width: 60, floor: FloatWidth.fitContent), 90);
  });

  testWidgets('and the room less the margins where they do not', (t) async {
    expect(await _width(t, room: 80, width: 30, floor: FloatWidth.fitContent, margin: 10), 70);
    // Never under the longest word.
    expect(await _width(t, room: 30, width: 20, floor: FloatWidth.fitContent), 40);
  });

  testWidgets('a min-content floor is the longest word, not the width it floors', (t) async {
    expect(await _width(t, room: 200, width: 20, floor: FloatWidth.minContent), 40);
  });

  testWidgets('NEGATIVE: a width of its own past the floor is the width', (t) async {
    expect(await _width(t, room: 200, width: 120, floor: FloatWidth.fitContent), 120);
  });

  testWidgets('a fit-content floor beside a float is clamped into the room beside it', (t) async {
    // 'aaaa bbbb cccc dddd' is 190 on one line, past the 140 beside the
    // float: the floor is 140, and the box stands there, its words on two
    // lines. Clamped into the block's 200 it was 190 and went down past
    // the float.
    expect(await _beside(t), const Rect.fromLTWH(60, 0, 140, 20));
  });

  testWidgets('NEGATIVE: below every float the room is the block\'s', (t) async {
    expect(await _beside(t, clear: FloatClear.both), const Rect.fromLTWH(0, 30, 190, 10));
  });
}
