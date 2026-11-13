// A BOX OF A RATIO SHRINKING INTO A SHARE OF ITS ROOM, OFFERED NO HEIGHT.
// `ShrinkWidth` with a `roomFactor` asks what it holds how wide it would be
// laid out with no bound (`shrink.dart`, `_fit`); offered no height either,
// that is no bound on either axis, which `RenderAspectRatio` cannot be laid
// out in: it asserted in a debug build -- a red screen -- and in release
// answered an infinite width, which took the whole room. With no height to
// transfer, a ratio's box is as wide as its content (css-sizing-4 5.1): an
// absolutely positioned `aspect-ratio` box past `left: 50%`, round a 120px
// picture, is 120 wide and 60 tall at 2:1.
// NEGATIVE: offered a height, the ratio still takes its width from it, as it
// did; and a box of words is as wide as it was.
import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _box = ValueKey('box');

// The test font draws every glyph 14px wide at 14px.
const _style = TextStyle(fontSize: 14, height: 1.0);

Widget _page(Widget child, {double? height}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 400,
      height: height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [ShrinkWidth(key: _box, roomFactor: 0.5, child: child)],
      ),
    ),
  ),
);

void main() {
  testWidgets('offered no height, a ratio round a picture is the picture wide', (t) async {
    await t.pumpWidget(_page(const AspectRatio(aspectRatio: 2, child: SizedBox(width: 120))));
    expect(t.takeException(), isNull);
    expect(t.getSize(find.byKey(_box)), const Size(120, 60));
    // Asked, it answers the same box.
    final box = t.renderObject<RenderBox>(find.byKey(_box));
    expect(box.getMaxIntrinsicHeight(400), 60);
  });

  testWidgets('offered no height, an empty ratio is nothing wide', (t) async {
    await t.pumpWidget(_page(const AspectRatio(aspectRatio: 2, child: ColoredBox(color: Color(0xFF000000)))));
    expect(t.takeException(), isNull);
    expect(t.getSize(find.byKey(_box)), Size.zero);
  });

  testWidgets('NEGATIVE: offered a height, the ratio takes its width from it', (t) async {
    // A ratio told a tight height: 50 tall is 100 wide, inside the room.
    await t.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          height: 50,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShrinkWidth(key: _box, roomFactor: 0.5, child: const AspectRatio(aspectRatio: 2, child: SizedBox(width: 120))),
            ],
          ),
        ),
      ),
    ));
    expect(t.takeException(), isNull);
    expect(t.getSize(find.byKey(_box)), const Size(100, 50));
  });

  testWidgets('NEGATIVE: words are as wide as they were', (t) async {
    // 'aaa bb' is 84 at most, and a share of 200 holds it on one line.
    await t.pumpWidget(_page(const Text('aaa bb', style: _style)));
    expect(t.takeException(), isNull);
    expect(t.getSize(find.byKey(_box)), const Size(84, 14));
  });
}
