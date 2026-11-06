import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A piece of the flow: a box of [h] at whatever width the column is.
Widget piece(double h, [Key? key]) => SizedBox(key: key, height: h);

/// [columns] [width] wide, as tall as they come to.
Widget page(Widget columns, {double width = 346}) => Directionality(
  textDirection: TextDirection.ltr,
  child: OverflowBox(
    alignment: Alignment.topLeft,
    minWidth: 0,
    maxWidth: width,
    minHeight: 0,
    maxHeight: double.infinity,
    child: SizedBox(width: width, child: columns),
  ),
);

void main() {
  // A phone's testimonial wall: `column-count: 2; column-gap: 8px` over
  // nine `inline-block`s at `width: 100%`, each alone on a line 6px deeper
  // than the card (the strut's descent under the baseline the card stands
  // on). Chrome's columns, 346 wide: the first four lines in the first,
  // 1018.3 tall, the last five in the second, 1052.6 -- and the container
  // is 1052.6 tall, where one column of the nine was 2070.9.
  const phone = [328.0, 198.0, 164.3, 328.0, 164.3, 198.0, 198.0, 328.0, 164.3];

  testWidgets('balanced columns break where Chrome breaks them', (tester) async {
    final keys = [for (var i = 0; i < phone.length; i++) GlobalKey()];
    await tester.pumpWidget(
      page(MultiColumn(count: 2, gap: 8, children: [for (var i = 0; i < phone.length; i++) piece(phone[i], keys[i])])),
    );
    final box = tester.renderObject<RenderBox>(find.byType(MultiColumn));
    expect(box.size.width, 346);
    expect(box.size.height, closeTo(1052.6, 1e-9));
    Offset at(int i) => tester.getTopLeft(find.byKey(keys[i]));
    // (346 + 8) / 2 - 8 = 169 wide, the second column at 177.
    expect(tester.getSize(find.byKey(keys[0])).width, 169);
    expect(at(0), Offset.zero);
    expect(at(3).dx, 0);
    expect(at(3).dy, closeTo(328 + 198 + 164.3, 1e-9));
    expect(at(4), const Offset(177, 0));
    expect(at(8).dx, 177);
    expect(at(8).dy, closeTo(164.3 + 198 + 198 + 328, 1e-9));
  });

  testWidgets('three columns of a desktop wall, each 1442 tall', (tester) async {
    const lines = [722.0, 360.0, 360.0, 722.0, 360.0, 360.0, 360.0, 722.0, 360.0];
    final keys = [for (var i = 0; i < lines.length; i++) GlobalKey()];
    await tester.pumpWidget(
      page(
        MultiColumn(count: 3, gap: 8, children: [for (var i = 0; i < lines.length; i++) piece(lines[i], keys[i])]),
        width: 1242,
      ),
    );
    expect(tester.getSize(find.byType(MultiColumn)).height, 1442);
    final w = (1242 + 8) / 3 - 8;
    expect(tester.getSize(find.byKey(keys[0])).width, closeTo(w, 1e-9));
    expect(tester.getTopLeft(find.byKey(keys[3])), Offset(w + 8, 0));
    expect(tester.getTopLeft(find.byKey(keys[6])), Offset(2 * (w + 8), 0));
    expect(tester.getTopLeft(find.byKey(keys[8])).dy, 1082);
  });

  // Ten list items 44 tall, each with a 16px bottom margin, in two columns
  // 71 apart: Chrome's list is 300 tall, five items a column. The margin
  // over the break is truncated -- the sixth item stands at the top of the
  // second column -- and the last one's is the flow's, under it.
  testWidgets('a space at a break is truncated; the one under the last piece is kept', (tester) async {
    final keys = [for (var i = 0; i < 10; i++) GlobalKey()];
    await tester.pumpWidget(
      page(
        MultiColumn(
          count: 2,
          gap: 71,
          spaces: const [0, 16, 16, 16, 16, 16, 16, 16, 16, 16],
          end: 16,
          children: [for (var i = 0; i < 10; i++) piece(44, keys[i])],
        ),
        width: 1242,
      ),
    );
    expect(tester.getSize(find.byType(MultiColumn)).height, 300);
    expect(tester.getTopLeft(find.byKey(keys[4])).dy, 240);
    expect(tester.getTopLeft(find.byKey(keys[5])), const Offset((1242 + 71) / 2, 0));
    expect(tester.getTopLeft(find.byKey(keys[9])).dy, 240);
  });

  testWidgets('the first space is the flow\'s own, above the first column', (tester) async {
    final keys = [for (var i = 0; i < 2; i++) GlobalKey()];
    await tester.pumpWidget(
      page(MultiColumn(count: 2, spaces: const [10, 10], children: [piece(50, keys[0]), piece(50, keys[1])])),
    );
    expect(tester.getTopLeft(find.byKey(keys[0])).dy, 10);
    expect(tester.getTopLeft(find.byKey(keys[1])).dy, 0);
    expect(tester.getSize(find.byType(MultiColumn)).height, 60);
  });

  testWidgets('a column width: as many columns as fit, sharing the room', (tester) async {
    final keys = [for (var i = 0; i < 6; i++) GlobalKey()];
    // (650 + 10) / (200 + 10) = 3.14: three columns of 210.
    await tester.pumpWidget(
      page(MultiColumn(width: 200, gap: 10, children: [for (var i = 0; i < 6; i++) piece(20, keys[i])]), width: 650),
    );
    expect(tester.getSize(find.byKey(keys[0])).width, 210);
    expect(tester.getTopLeft(find.byKey(keys[2])), const Offset(220, 0));
    expect(tester.getTopLeft(find.byKey(keys[4])), const Offset(440, 0));
    expect(tester.getSize(find.byType(MultiColumn)).height, 40);
    // And a count caps it: two columns of (650 + 10) / 2 - 10.
    await tester.pumpWidget(
      page(
        MultiColumn(count: 2, width: 200, gap: 10, children: [for (var i = 0; i < 6; i++) piece(20, keys[i])]),
        width: 650,
      ),
    );
    expect(tester.getSize(find.byKey(keys[0])).width, 320);
    expect(tester.getTopLeft(find.byKey(keys[3])), const Offset(330, 0));
  });

  testWidgets('right to left, the first column is at the right', (tester) async {
    final keys = [for (var i = 0; i < 2; i++) GlobalKey()];
    await tester.pumpWidget(
      page(
        MultiColumn(
          count: 2,
          gap: 8,
          textDirection: TextDirection.rtl,
          children: [piece(30, keys[0]), piece(30, keys[1])],
        ),
      ),
    );
    expect(tester.getTopLeft(find.byKey(keys[0])), const Offset(177, 0));
    expect(tester.getTopLeft(find.byKey(keys[1])), Offset.zero);
  });

  testWidgets('NEGATIVE: a piece taller than the rest is never cut', (tester) async {
    final keys = [for (var i = 0; i < 3; i++) GlobalKey()];
    await tester.pumpWidget(
      page(MultiColumn(count: 2, children: [piece(500, keys[0]), piece(10, keys[1]), piece(10, keys[2])])),
    );
    expect(tester.getSize(find.byType(MultiColumn)).height, 500);
    expect(tester.getTopLeft(find.byKey(keys[1])).dy, 0);
    expect(tester.getTopLeft(find.byKey(keys[2])).dy, 10);
  });

  testWidgets('NEGATIVE: one column is a column', (tester) async {
    final keys = [for (var i = 0; i < 3; i++) GlobalKey()];
    await tester.pumpWidget(
      page(MultiColumn(count: 1, spaces: const [0, 5, 5], children: [for (var i = 0; i < 3; i++) piece(10, keys[i])])),
    );
    expect(tester.getSize(find.byType(MultiColumn)), const Size(346, 40));
    expect(tester.getTopLeft(find.byKey(keys[2])), const Offset(0, 30));
  });

  test('the balancer stretches by the least shortage, never past the count', () {
    // 30 of content in two columns: a guess of 15 leaves three columns,
    // and the least shortage, 5, gives 20 -- two.
    final b = RenderMultiColumn.balance(const [10, 10, 10], const [], 0, 2);
    expect(b.height, 20);
    expect(b.starts, [0, 2]);
    // Four in three columns: 13.3, then 20 -- two columns hold them, the
    // third stays empty.
    final c = RenderMultiColumn.balance(const [10, 10, 10, 10], const [], 0, 3);
    expect(c.height, 20);
    expect(c.starts, [0, 2]);
  });

  // WIDOWS: five lines of one paragraph, four short and the last 106
  // tall. A guess of 106 holds the first four in the first column and
  // leaves the last one alone in the second; `widows: 2` takes the break up
  // a line, and the second column is the last two, 132 -- Chrome's.
  test('a paragraph leaves two lines after a break, where it can', () {
    final b = RenderMultiColumn.balance(const [26, 26, 26, 26, 106], const [], 0, 2, lines: null);
    expect(b.starts, [0, 3]);
    expect(b.height, 132);
    // The same pieces as blocks break where the column runs out.
    final c = RenderMultiColumn.balance(const [26, 26, 26, 26, 106], const [], 0, 2);
    expect(c.starts, [0, 4]);
    expect(c.height, 106);
  });

  // Three lines in two columns: no break leaves two on each side, and
  // Chrome breaks where the column runs out, two lines over one.
  test('NEGATIVE: where no break leaves orphans and widows, the column runs out where it does', () {
    final b = RenderMultiColumn.balance(const [46, 46, 46], const [], 0, 2, lines: null);
    expect(b.starts, [0, 2]);
    expect(b.height, 92);
  });

  testWidgets('MultiColumn.lines sets one paragraph', (tester) async {
    final keys = [for (var i = 0; i < 5; i++) GlobalKey()];
    await tester.pumpWidget(
      page(
        MultiColumn.lines(
          count: 2,
          gap: 8,
          children: [
            for (final (i, h) in const [26.0, 26.0, 26.0, 26.0, 106.0].indexed) piece(h, keys[i]),
          ],
        ),
      ),
    );
    expect(tester.getSize(find.byType(MultiColumn)).height, 132);
    expect(tester.getTopLeft(find.byKey(keys[3])), const Offset(177, 0));
  });

  testWidgets('dry layout and intrinsic sizes agree with layout', (tester) async {
    // 100 of content: a guess of 50 leaves three columns ([40], [30, 20],
    // [10]), the least shortage is 10, and 60 holds [40] and [30, 20, 10].
    final columns = MultiColumn(
      count: 2,
      gap: 10,
      children: [
        for (final h in [40.0, 30.0, 20.0, 10.0]) SizedBox(height: h, child: const SizedBox(width: 100)),
      ],
    );
    await tester.pumpWidget(page(columns, width: 410));
    final box = tester.renderObject<RenderMultiColumn>(find.byType(MultiColumn));
    expect(box.size, const Size(410, 60));
    expect(box.getDryLayout(const BoxConstraints(maxWidth: 410)), box.size);
    expect(box.getMinIntrinsicHeight(410), 60);
    expect(box.getMaxIntrinsicHeight(410), 60);
    // Two columns of the widest piece's 100 and the gap between.
    expect(box.getMaxIntrinsicWidth(double.infinity), 210);
    expect(box.getMinIntrinsicWidth(double.infinity), 210);
  });

  testWidgets('a column width caps the least width at itself, one column of it', (tester) async {
    final columns = MultiColumn(
      count: 3,
      width: 80,
      gap: 10,
      children: [
        for (final h in [40.0, 30.0]) SizedBox(height: h, child: const SizedBox(width: 100)),
      ],
    );
    await tester.pumpWidget(page(columns, width: 410));
    final box = tester.renderObject<RenderMultiColumn>(find.byType(MultiColumn));
    expect(box.getMinIntrinsicWidth(double.infinity), 80);
    expect(box.getMaxIntrinsicWidth(double.infinity), 3 * 100 + 2 * 10);
  });

  testWidgets('the baseline is the first piece\'s, under the flow\'s first space', (tester) async {
    // A row lines the columns up with a word on its baseline: the word
    // stands as far down as the first piece's space puts the first line.
    const style = TextStyle(fontSize: 20, height: 1);
    final word = GlobalKey();
    await tester.pumpWidget(
      page(
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const SizedBox(
              width: 200,
              child: MultiColumn(
                count: 2,
                spaces: [7],
                children: [
                  Text('Ab', style: style),
                  SizedBox(height: 10),
                ],
              ),
            ),
            Text('Ab', key: word, style: style),
          ],
        ),
      ),
    );
    expect(tester.getTopLeft(find.byKey(word)).dy, 7);
    expect(tester.getTopLeft(find.byType(MultiColumn)).dy, 0);
    // Dry, the same: the first piece's dry baseline, under the space.
    final box = tester.renderObject<RenderMultiColumn>(find.byType(MultiColumn));
    final first = tester.renderObject<RenderBox>(find.byType(RichText).first);
    final own = first.getDryBaseline(const BoxConstraints.tightFor(width: 100), TextBaseline.alphabetic)!;
    expect(box.getDryBaseline(const BoxConstraints(maxWidth: 200), TextBaseline.alphabetic), own + 7);
  });
}
