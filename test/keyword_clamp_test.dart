// A MINIMUM WINS OVER THE WIDTH THE BOX IS HANDED (CSS 2.1 10.4), and a
// box wider than its room hangs off the room's END: the right under `ltr`,
// the LEFT under `rtl` (CSS 2.1 10.3.3, css-text-3 7.1). Chrome, a 300px
// `rtl` block holding `display: inline-block; width: stretch; min-width:
// max-content` round 439.172px of unbroken words: the box is 439.172 wide
// and stands at -139.172, its right edge on the block's
// (`fixtures/width-stretch-atomic` p18). Here the words are a 160px box in
// a 100px room.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _box = ValueKey('box');
const _clamp = ValueKey('clamp');

Widget _page(double inner, TextDirection dir) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 100,
      child: KeywordClamp(
        key: _clamp,
        floor: ContentWidth.max,
        textDirection: dir,
        child: SizedBox(key: _box, width: inner, height: 10),
      ),
    ),
  ),
);

void main() {
  testWidgets('under rtl a floor past the room hangs off its LEFT', (t) async {
    await t.pumpWidget(_page(160, TextDirection.rtl));
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(-60, 0, 160, 10));
    // The clamp reports the room it was handed.
    expect(t.getRect(find.byKey(_clamp)), const Rect.fromLTWH(0, 0, 100, 10));
  });

  testWidgets('under ltr it hangs off the right', (t) async {
    await t.pumpWidget(_page(160, TextDirection.ltr));
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(0, 0, 160, 10));
  });

  testWidgets('NEGATIVE: a floor under the room fills it, and nothing hangs', (t) async {
    await t.pumpWidget(_page(60, TextDirection.rtl));
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(0, 0, 100, 10));
  });
}
