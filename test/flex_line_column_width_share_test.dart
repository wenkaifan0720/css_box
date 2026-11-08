// A SHARE OF A COLUMN'S WIDTH IS OF THE WIDTH THE COLUMN COMES TO. A column
// handed no width of its own is as wide as its content (fit-content,
// css-sizing-3 5.2.2), and an item's percentage width counts as `auto` while
// that width is worked out, then is of it (css-sizing-3 5.2.1). A `width:
// 90%` column of words under a `max-width: 90%` item of a centring column:
// Chrome's item is 351 and its words 315.89 wide
// (`fixtures/flex-column-fit-width-share` p1). FlexLine read the share as
// nothing, and the words were laid out across the whole 351. NEGATIVE: a
// column handed its width reads the share of that width, as before (n1).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

/// Content `most` wide at most, laid out across whatever width it is given
/// (a column that stretches its words).
Widget _words(String key, double most) => Column(
  key: ValueKey(key),
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [SizedBox(width: most, height: 24)],
);

Future<void> _pump(WidgetTester t, Widget line, {double room = 351, bool tight = false}) async {
  t.view
    ..physicalSize = const Size(1440, 900)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: room,
          child: tight ? line : Align(alignment: Alignment.topLeft, child: line),
        ),
      ),
    ),
  );
}

FlexLine _line(double most, double beside) => FlexLine(
  key: const ValueKey('line'),
  direction: Axis.vertical,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    FlexCell(crossSizeFraction: 0.9, child: _words('share', most)),
    SizedBox(key: const ValueKey('beside'), width: beside, height: 18),
  ],
);

double _width(WidgetTester t, String key) => t.getSize(find.byKey(ValueKey(key))).width;

void main() {
  testWidgets('content wider than the room: the column is the room, the share 90% of it (p1)', (t) async {
    await _pump(t, _line(600, 176));
    expect(_width(t, 'line'), 351);
    expect(_width(t, 'share'), closeTo(315.9, 1e-9));
    expect(_width(t, 'beside'), 176);
  });

  testWidgets('content narrower than the room: the column is its widest item, the share 90% of that (p3)', (t) async {
    await _pump(t, _line(90, 157.33));
    expect(_width(t, 'line'), closeTo(157.33, 1e-9));
    expect(_width(t, 'share'), closeTo(141.597, 1e-9));
  });

  testWidgets('the share\'s own content can be the widest item', (t) async {
    await _pump(t, _line(200, 120));
    expect(_width(t, 'line'), 200);
    expect(_width(t, 'share'), 180);
  });

  testWidgets('NEGATIVE: a column handed its width reads the share of that width (n1)', (t) async {
    await _pump(t, _line(600, 176), room: 300, tight: true);
    expect(_width(t, 'line'), 300);
    expect(_width(t, 'share'), 270);
  });
}
