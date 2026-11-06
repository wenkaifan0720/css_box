// A BOX ALIGNED AT ITS STATIC POSITION is aligned by its MARGIN box
// (css-flexbox-1 4.1), and a `safe` alignment asks whether the margin box
// fits (css-align-3 4.4) -- `SpotShift.margin`. And what is aligned is what
// the child LAYS OUT where that is past what it reports (`Overhangs`): a
// `FractionalHeight` at 150% of a 32px room is 48 tall however much of the
// room it reports. Chrome, `fixtures/abs-static-share-aligned`: a 32px fade
// at `margin-top: 4px; align-self: safe center` in a 32px row stands 4 down
// (p7), and a `height: 150%` fade centred in it 8 above (p8).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _box = ValueKey('box');

Widget _page(Widget shifted) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SpotScope(
      child: SizedBox(
        width: 300,
        height: 32,
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.passthrough,
          children: [
            const SpotArea(id: 0, child: SizedBox(width: 300, height: 32)),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Align(alignment: Alignment.topLeft, widthFactor: 1, child: shifted),
            ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('a margin box that does not fit a safe alignment stands at the start, the box its margin down', (
    t,
  ) async {
    await t.pumpWidget(
      _page(
        const SpotShift(
          id: 0,
          alignY: 0.5,
          safeY: true,
          margin: EdgeInsets.only(top: 4),
          child: SizedBox(key: _box, width: 50, height: 32),
        ),
      ),
    );
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(0, 4, 50, 32));
  });

  testWidgets('not safe, the margin box is centred: 2 down', (t) async {
    await t.pumpWidget(
      _page(
        const SpotShift(
          id: 0,
          alignY: 0.5,
          margin: EdgeInsets.only(top: 4),
          child: SizedBox(key: _box, width: 50, height: 32),
        ),
      ),
    );
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(0, 2, 50, 32));
  });

  testWidgets('a share past the room is centred by what it lays out', (t) async {
    await t.pumpWidget(
      _page(
        const SpotShift(
          id: 0,
          alignY: 0.5,
          child: FractionalHeight(factor: 1.5, child: SizedBox(key: _box, width: 50)),
        ),
      ),
    );
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(0, -8, 50, 48));
  });

  testWidgets('NEGATIVE: held in a box that reports the room, the room is what is centred', (t) async {
    await t.pumpWidget(
      _page(
        const SpotShift(
          id: 0,
          alignY: 0.5,
          child: SizedBox(
            width: 50,
            child: FractionalHeight(factor: 1.5, child: SizedBox(key: _box, width: 50)),
          ),
        ),
      ),
    );
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(0, 0, 50, 48));
  });
}
