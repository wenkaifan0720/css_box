import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

// AlignBox(overflow: true) lays its child out with no bound on its width: the
// child is as wide as it asks to be, whatever this box's width, and its
// height is the one it has there. Its intrinsic height is asked there too.

const _words = 'aaaa bbbb cccc dddd';
const _style = TextStyle(fontSize: 10, height: 1.0);

Widget _box(Widget child, {double width = 100}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: child),
  ),
);

RenderBox _ro(WidgetTester tester) => tester.renderObject(find.byKey(const Key('a')));

void main() {
  testWidgets('a child wider than the box: its height at its own width, as laid out', (tester) async {
    // 200 wide in a 100 box: the words are 190 on one line, 10 tall. Asked
    // at the box's 100 they wrapped to two lines, 20.
    await tester.pumpWidget(
      _box(
        const AlignBox(
          key: Key('a'),
          alignment: Alignment.topLeft,
          heightFactor: 1,
          overflow: true,
          child: SizedBox(width: 200, child: Text(_words, style: _style)),
        ),
      ),
    );
    expect(_ro(tester).size.height, 10);
    expect(_ro(tester).getMaxIntrinsicHeight(100), 10);
    expect(_ro(tester).getMinIntrinsicHeight(100), 10);
    // A SizedBox hands on the width it is asked at: asked at no width at
    // all, the words would be one line where a 120-wide child wraps them.
    await tester.pumpWidget(
      _box(
        const AlignBox(
          key: Key('a'),
          alignment: Alignment.topLeft,
          heightFactor: 1,
          overflow: true,
          child: SizedBox(width: 120, child: Text(_words, style: _style)),
        ),
      ),
    );
    expect(_ro(tester).size.height, 20);
    expect(_ro(tester).getMaxIntrinsicHeight(100), 20);
    expect(_ro(tester).getMaxIntrinsicHeight(60), 20);
  });

  testWidgets('NEGATIVE: a child that may not overflow is asked at the width given', (tester) async {
    await tester.pumpWidget(
      _box(
        const AlignBox(
          key: Key('a'),
          alignment: Alignment.topLeft,
          heightFactor: 1,
          child: Text(_words, style: _style),
        ),
      ),
    );
    // Squeezed to the 100 box: two lines; asked at 40, four.
    expect(_ro(tester).size.height, 20);
    expect(_ro(tester).getMaxIntrinsicHeight(100), 20);
    expect(_ro(tester).getMaxIntrinsicHeight(40), 40);
  });
}
