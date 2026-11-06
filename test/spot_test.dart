import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

Widget _page(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 300, child: child),
  ),
);

void main() {
  testWidgets('a box at a mark is drawn where the flow left off', (tester) async {
    final tag = GlobalKey();
    await tester.pumpWidget(
      _page(
        SpotScope(
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.passthrough,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: const [SizedBox(height: 40, width: 300), SpotMark(id: 0), SizedBox(height: 12, width: 300)],
              ),
              Positioned(
                left: 8,
                top: 0,
                child: SpotShift(id: 0, child: SizedBox(key: tag, width: 20, height: 10)),
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.getTopLeft(find.byKey(tag)), const Offset(8, 40));
  });

  testWidgets('a box at a mark is pressed where it is drawn, over the flow it is drawn on', (tester) async {
    final pressed = <String>[];
    await tester.pumpWidget(
      _page(
        SpotScope(
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.passthrough,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => pressed.add('field'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [SizedBox(height: 40, width: 300), SpotMark(id: 0), SizedBox(height: 12, width: 300)],
                ),
              ),
              Positioned(
                left: 8,
                top: 0,
                child: SpotShift(
                  id: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => pressed.add('icon'),
                    child: const SizedBox(width: 20, height: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // Drawn at (8, 40); laid out at (8, 0), where nothing of it is drawn.
    await tester.tapAt(const Offset(18, 45));
    await tester.tapAt(const Offset(18, 5));
    expect(pressed, ['icon', 'field']);
  });

  testWidgets('a mark that says so has the box END at its point', (tester) async {
    final tag = GlobalKey(), plain = GlobalKey();
    await tester.pumpWidget(
      _page(
        SpotScope(
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.passthrough,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [SizedBox(height: 40), SpotMark(id: 0, along: 1, end: true), SpotMark(id: 1, along: 1)],
              ),
              Positioned(
                left: 0,
                top: 0,
                child: SpotShift(id: 0, across: true, child: SizedBox(key: tag, width: 30, height: 10)),
              ),
              Positioned(
                left: 0,
                top: 0,
                child: SpotShift(id: 1, across: true, child: SizedBox(key: plain, width: 30, height: 10)),
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.getTopLeft(find.byKey(tag)), const Offset(270, 40));
    expect(tester.getTopLeft(find.byKey(plain)), const Offset(300, 40));
  });

  testWidgets('the mark moves with the content above it', (tester) async {
    final tag = GlobalKey();
    Widget build(double first) => _page(
      SpotScope(
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.passthrough,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: first, width: 300),
                const SpotMark(id: 7),
              ],
            ),
            Positioned(
              left: 0,
              top: 0,
              child: SpotShift(id: 7, child: SizedBox(key: tag, width: 20, height: 10)),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(build(40));
    expect(tester.getTopLeft(find.byKey(tag)).dy, 40);
    await tester.pumpWidget(build(90));
    expect(tester.getTopLeft(find.byKey(tag)).dy, 90);
  });

  testWidgets('a mark deeper than the stack still places the box', (tester) async {
    final tag = GlobalKey();
    await tester.pumpWidget(
      _page(
        SpotScope(
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.passthrough,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16, left: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [SizedBox(height: 30, width: 200), SpotMark(id: 1)],
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                child: SpotShift(id: 1, child: SizedBox(key: tag, width: 20, height: 10)),
              ),
            ],
          ),
        ),
      ),
    );
    // 16 of padding and 30 of content: the mark carries both, and only the
    // down half of it -- the box is placed across by its own inset.
    expect(tester.getTopLeft(find.byKey(tag)), const Offset(0, 46));
  });

  testWidgets('a box whose mark is nowhere sits at the top', (tester) async {
    final tag = GlobalKey();
    await tester.pumpWidget(
      _page(
        SpotScope(
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.passthrough,
            children: [
              const SizedBox(height: 40, width: 300),
              Positioned(
                left: 0,
                top: 0,
                child: SpotShift(id: 99, child: SizedBox(key: tag, width: 20, height: 10)),
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.getTopLeft(find.byKey(tag)), Offset.zero);
  });

  testWidgets('a mark settles the place across the stack too', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SpotScope(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [Padding(padding: EdgeInsets.only(left: 24, top: 10), child: SpotMark(id: 0))],
              ),
              const Positioned(
                left: 0,
                top: 0,
                child: SpotShift(id: 0, across: true, child: SizedBox(width: 30, height: 30, key: ValueKey('box'))),
              ),
            ],
          ),
        ),
      ),
    );
    final at = tester.getTopLeft(find.byKey(const ValueKey('box')));
    expect(at.dx, 24);
    expect(at.dy, 10);
  });

  testWidgets('a shift told to move only across leaves the other axis alone', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SpotScope(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [Padding(padding: EdgeInsets.only(left: 24, top: 10), child: SpotMark(id: 0))],
              ),
              const Positioned(
                left: 0,
                top: 50,
                child: SpotShift(
                  id: 0,
                  across: true,
                  down: false,
                  child: SizedBox(width: 30, height: 30, key: ValueKey('box')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final at = tester.getTopLeft(find.byKey(const ValueKey('box')));
    expect(at.dx, 24);
    expect(at.dy, 50);
  });
}
