// A SHARE OF THE BLOCK'S HEIGHT BESIDE OTHER BOXES (`Spill.room`,
// `FractionalHeight.ofRoom`): a percentage height is of the containing
// block's content height where that is definite (CSS 2.1 10.5), whatever
// else is in the flow. Chrome, `fixtures/calc-share-height` n9: `height:
// calc(50% + 10px)` over a 10px box in a 160px grid row is 90, and the box
// after it starts at 90. The flow is a `Column`, which hands each child an
// unbounded height, so the share reads the block's off the room above it.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _share = ValueKey('share');
const _after = ValueKey('after');

Widget _page(double? room, {bool marked = true, bool reads = true}) {
  final flow = Spill(
    axis: Axis.vertical,
    room: marked,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FractionalHeight(
          factor: 0.5,
          offset: 10,
          ofRoom: reads,
          child: const SizedBox(key: _share),
        ),
        const SizedBox(key: _after, height: 10),
      ],
    ),
  );
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: room == null
          ? SingleChildScrollView(child: SizedBox(width: 160, child: flow))
          : SizedBox(width: 160, height: room, child: flow),
    ),
  );
}

void main() {
  testWidgets('beside a box after it, the share is of the room the flow was offered', (t) async {
    await t.pumpWidget(_page(160));
    expect(t.getSize(find.byKey(_share)).height, closeTo(90, 1e-9));
    expect(t.getTopLeft(find.byKey(_after)).dy, closeTo(90, 1e-9));
  });

  testWidgets('past the room the box is the share, and what follows is pushed past it', (t) async {
    // 8 and 10 in a 16px row: 18, and the box after it overflows the row.
    await t.pumpWidget(_page(16));
    expect(t.getSize(find.byKey(_share)).height, closeTo(18, 1e-9));
    expect(t.getTopLeft(find.byKey(_after)).dy, closeTo(18, 1e-9));
  });

  testWidgets('laid out again where the room changes and the column does not', (t) async {
    // The column is handed the same unbounded height at 160 and at 200,
    // so nothing but the room has the share taken again.
    await t.pumpWidget(_page(160));
    await t.pumpWidget(_page(200));
    expect(t.getSize(find.byKey(_share)).height, closeTo(110, 1e-9));
    expect(t.getTopLeft(find.byKey(_after)).dy, closeTo(110, 1e-9));
  });

  testWidgets('a dry pass reads the room it is asked at', (t) async {
    await t.pumpWidget(_page(160));
    // Asked at no more than 60, the flow is 40 of share and the 10 after
    // it -- not the 90 and 10 it was laid out at.
    final flow = t.renderObject<RenderBox>(find.byType(Spill));
    expect(flow.getDryLayout(const BoxConstraints(maxWidth: 160, maxHeight: 60)).height, closeTo(50, 1e-9));
  });

  testWidgets('NEGATIVE: with no room above, the share is the content', (t) async {
    await t.pumpWidget(_page(160, marked: false));
    expect(t.getSize(find.byKey(_share)).height, 0);
    expect(t.getTopLeft(find.byKey(_after)).dy, 0);
  });

  testWidgets('NEGATIVE: a share not of the room does not read it', (t) async {
    await t.pumpWidget(_page(160, reads: false));
    expect(t.getSize(find.byKey(_share)).height, 0);
  });

  testWidgets('NEGATIVE: a room offered no height is no height to take a share of', (t) async {
    await t.pumpWidget(_page(null));
    expect(t.getSize(find.byKey(_share)).height, 0);
    expect(t.getTopLeft(find.byKey(_after)).dy, 0);
  });
}
