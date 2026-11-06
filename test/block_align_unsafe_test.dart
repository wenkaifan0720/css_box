// A BLOCK'S CONTENT UNDER `align-content: unsafe end` OR `unsafe center`
// IS PLACED AS CSS SAYS WHATEVER THE SIGN OF THE FREE SPACE: the box's
// height less the content's, all of it before the content for `end`, half
// for `center` -- out of the top where the content is the taller
// (css-align-3 4.4 `unsafe`, 5.1). The lowerer writes the block's column at its content's height in
//   OverflowBox(minHeight: 0, maxHeight: double.infinity,
//       fit: OverflowBoxFit.deferToChild,
//       alignment: AlignmentDirectional.bottomStart /* centerStart */,
//       child: Column(mainAxisSize: MainAxisSize.min, ...))
// which offers the column no floor and no ceiling down the page and is
// `constrain` of it in the slot (`rendering/shifted_box.dart`,
// `RenderConstrainedOverflowBox.performLayout`): the box's height where
// the slot states one, the content clamped between a `min-height` and a
// `max-height` where it does not, and the column placed by the alignment
// in that. This pins it to CSS's numbers in a box shorter than the
// content, as tall and taller, and under a floor and a cap alone
// (`fixtures/block-align-content-unsafe`).
// NEGATIVE: the `Column` held to the box packs its content at the top and
// reports what passes its end; the `Spill` the default and `safe` are
// written with puts the content at the top, which is where Chrome puts
// `align-content: end` (`fixtures/block-align-content-safe` n1) and not
// where it puts `unsafe end`.
import 'package:css_box/css_box.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _one = ValueKey('one');
const _two = ValueKey('two');
const _box = ValueKey('box');

Widget _page(Widget w) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(alignment: Alignment.topLeft, child: w),
);

// Two blocks 40 tall: 80 of content.
Widget _column({MainAxisAlignment? along}) => Column(
  mainAxisSize: MainAxisSize.min,
  mainAxisAlignment: along ?? MainAxisAlignment.start,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: const [
    SizedBox(key: _one, height: 40),
    SizedBox(key: _two, height: 40),
  ],
);

Widget _hung(String along) => OverflowBox(
  minHeight: 0,
  maxHeight: double.infinity,
  fit: OverflowBoxFit.deferToChild,
  alignment: along == 'end' ? AlignmentDirectional.bottomStart : AlignmentDirectional.centerStart,
  child: _column(),
);

// The block: `height`, or a `min-height` / `max-height` alone.
Widget _block(Widget content, {double? height, double? min, double? max}) => SizedBox(
  key: _box,
  width: 120,
  height: height,
  child: ConstrainedBox(
    constraints: BoxConstraints(minHeight: min ?? 0, maxHeight: max ?? double.infinity),
    child: content,
  ),
);

void main() {
  for (final (along, at) in const [('end', 1.0), ('center', 0.5)]) {
    for (final height in const [40.0, 60.0, 80.0, 140.0]) {
      testWidgets('unsafe $along in a box $height tall: the content at its place, past the top where it is taller', (
        t,
      ) async {
        await t.pumpWidget(_page(_block(_hung(along), height: height)));
        expect(t.takeException(), isNull);
        // CSS: the free space, negative or not, `at` of it before the content.
        final free = (height - 80) * at;
        expect(t.getRect(find.byKey(_box)).height, height);
        expect(t.getRect(find.byKey(_one)).top, free);
        expect(t.getRect(find.byKey(_two)).top, free + 40);
      });
    }
  }

  testWidgets('unsafe end under a min-height alone: the box is the more of the two, the content at its end', (t) async {
    await t.pumpWidget(_page(_block(_hung('end'), min: 100)));
    expect(t.takeException(), isNull);
    expect(t.getRect(find.byKey(_box)).height, 100);
    expect(t.getRect(find.byKey(_one)).top, 20);
    await t.pumpWidget(_page(_block(_hung('end'), min: 50)));
    expect(t.getRect(find.byKey(_box)).height, 80);
    expect(t.getRect(find.byKey(_one)).top, 0);
  });

  testWidgets('unsafe end and center under a max-height alone: the box is the cap, the content out of its top', (
    t,
  ) async {
    await t.pumpWidget(_page(_block(_hung('end'), max: 60)));
    expect(t.takeException(), isNull);
    expect(t.getRect(find.byKey(_box)).height, 60);
    expect(t.getRect(find.byKey(_one)).top, -20);
    await t.pumpWidget(_page(_block(_hung('center'), max: 60)));
    expect(t.getRect(find.byKey(_one)).top, -10);
    // Under a cap it does not reach, the box is the content.
    await t.pumpWidget(_page(_block(_hung('end'), max: 200)));
    expect(t.getRect(find.byKey(_box)).height, 80);
    expect(t.getRect(find.byKey(_one)).top, 0);
  });

  testWidgets('NEGATIVE: the column held to a box shorter than it packs at the top and reports its end', (t) async {
    await t.pumpWidget(_page(_block(_column(along: MainAxisAlignment.end), height: 60)));
    expect(t.takeException(), isA<FlutterError>());
    expect(t.getRect(find.byKey(_one)).top, 0);
  });

  testWidgets('NEGATIVE: the spill the default and safe are written with puts the content at the top', (t) async {
    await t.pumpWidget(
      _page(
        _block(
          Spill(
            axis: Axis.vertical,
            floor: true,
            child: _column(along: MainAxisAlignment.end),
          ),
          height: 60,
        ),
      ),
    );
    expect(t.takeException(), isNull);
    expect(t.getRect(find.byKey(_one)).top, 0);
    expect(t.getRect(find.byKey(_one)).top, isNot(-20));
  });
}
