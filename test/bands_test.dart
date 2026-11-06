import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/bands.dart';

void main() {
  Future<List<Object?>> at(WidgetTester tester, double width, Object? Function(BuildContext) read) async {
    final got = <Object?>[];
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: Builder(
          builder: (context) {
            got.add(read(context));
            return const SizedBox();
          },
        ),
      ),
    );
    return got;
  }

  testWidgets('a band is keyed by its least width', (tester) async {
    Object? read(BuildContext c) => c.band({0: 'narrow', 768: 'tablet', 1024: 'wide'});
    expect(await at(tester, 320, read), ['narrow']);
    expect(await at(tester, 767.5, read), ['narrow']);
    expect(await at(tester, 768, read), ['tablet']);
    expect(await at(tester, 1023, read), ['tablet']);
    expect(await at(tester, 1024, read), ['wide']);
    expect(await at(tester, 3000, read), ['wide']);
  });

  testWidgets('a window under the first band takes the first value', (tester) async {
    expect(await at(tester, 200, (c) => c.band({320: 1.0, 768: 2.0})), [1.0]);
  });

  testWidgets('from and below split at the width', (tester) async {
    expect(await at(tester, 767, (c) => (c.widthFrom(768), c.widthBelow(768))), [(false, true)]);
    expect(await at(tester, 768, (c) => (c.widthFrom(768), c.widthBelow(768))), [(true, false)]);
  });

  testWidgets('wrap builds the band frame round the content', (tester) async {
    Object? read(BuildContext c) => c.wrap<String, String>('card', {0: (s) => '[$s]', 768: (s) => '($s)'});
    expect(await at(tester, 500, read), ['[card]']);
    expect(await at(tester, 900, read), ['(card)']);
  });

  testWidgets('a banded value in a widget tree types as the slot it is in', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(900, 800)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) => Padding(
              padding: context.band({0: const EdgeInsets.all(12), 768: const EdgeInsets.all(24)}),
              child: context.wrap(const SizedBox(key: ValueKey('box'), width: 10, height: 10), {
                0: (Widget c) => Align(alignment: Alignment.topLeft, child: c),
                768: (Widget c) => Align(alignment: Alignment.topRight, child: c),
              }),
            ),
          ),
        ),
      ),
    );
    final r = tester.getRect(find.byKey(const ValueKey('box')));
    // The band is the MediaQuery's 900; the room is the test surface's 800.
    expect(r.left, 800 - 24 - 10);
    expect(r.top, 24);
  });
}
