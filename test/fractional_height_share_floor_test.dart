// A FLOOR THAT IS A SHARE OF THE SAME HEIGHT (`FractionalHeight.minFactor`):
// `height: 49.01%; min-height: calc(40% + 10px)` is the floor under 102px
// of room -- 0.4 of it and 10 -- and the share past it (CSS 2.1 10.7).
// Chrome, `fixtures/abs-share-height-floor` p7: a Russian news site's thumb at that
// floor, in a track as tall as the words beside it.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _box = ValueKey('box');

Widget _page(double room, {double? cap}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 50,
      height: room,
      child: Align(
        alignment: Alignment.topLeft,
        child: FractionalHeight(
          factor: 0.4901,
          minFactor: 0.4,
          minOffset: 10,
          maxFactor: cap,
          child: const SizedBox(key: _box, width: 50),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('under 102px of room the floor binds', (t) async {
    await t.pumpWidget(_page(50));
    expect(t.getSize(find.byKey(_box)).height, closeTo(30, 1e-9));
  });

  testWidgets('past it the share does', (t) async {
    await t.pumpWidget(_page(200));
    expect(t.getSize(find.byKey(_box)).height, closeTo(98.02, 1e-9));
  });

  testWidgets('the floor wins over a share cap under it', (t) async {
    // A cap of a fifth of 200 is 40, under the share's 98.02 and the
    // floor's 90: the floor.
    await t.pumpWidget(_page(200, cap: 0.2));
    expect(t.getSize(find.byKey(_box)).height, closeTo(90, 1e-9));
  });

  testWidgets('NEGATIVE: offered no height, a share floor is nothing', (t) async {
    await t.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(
            child: FractionalHeight(
              factor: 0.5,
              minFactor: 0.4,
              minOffset: 10,
              child: SizedBox(key: _box, width: 50, height: 7),
            ),
          ),
        ),
      ),
    );
    expect(t.getSize(find.byKey(_box)).height, 7);
  });
}
