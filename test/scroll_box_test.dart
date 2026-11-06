import 'dart:ui' as ui;

import 'package:css_box/css_box.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _colors = [Color(0xFFE53935), Color(0xFF43A047), Color(0xFF1E88E5), Color(0xFFFDD835), Color(0xFF8E24AA)];

/// Five 60px bands in a 200 x 100 box that cuts them: 300 of content, laid
/// out at the box's size and running out of it the way a lowered scroll
/// container's content does. [tapped] hears which band a tap lands on.
Widget _box({required bool scrolls, Axis axis = Axis.vertical, bool both = false, void Function(int)? tapped}) {
  final bands = [
    for (var i = 0; i < _colors.length; i++)
      GestureDetector(
        onTap: () => tapped?.call(i),
        child: SizedBox(
          width: axis == Axis.vertical ? 200 : 60,
          height: axis == Axis.vertical ? 60 : 100,
          child: ColoredBox(color: _colors[i]),
        ),
      ),
  ];
  final Widget content = Spill(
    axis: both ? null : axis,
    child: axis == Axis.vertical
        ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: bands)
        : Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: bands),
  );
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        child: SizedBox(
          width: 200,
          height: 100,
          child: ClipRect(
            child: scrolls
                ? ScrollBox(
                    vertical: axis == Axis.vertical || both,
                    horizontal: axis == Axis.horizontal || both,
                    child: content,
                  )
                : content,
          ),
        ),
      ),
    ),
  );
}

Future<List<int>> _pixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return bytes!.buffer.asUint8List().toList();
  }))!;
}

ScrollPosition _position(WidgetTester tester, Axis axis) => tester
    .stateList<ScrollableState>(find.byType(Scrollable))
    .firstWhere((s) => axisDirectionToAxis(s.axisDirection) == axis)
    .position;

void main() {
  testWidgets('at rest a scroll container draws what the clip it replaces draws', (tester) async {
    for (final axis in Axis.values) {
      await tester.pumpWidget(_box(scrolls: false, axis: axis));
      final cut = await _pixels(tester);
      await tester.pumpWidget(_box(scrolls: true, axis: axis));
      final scrolled = await _pixels(tester);
      expect(scrolled, cut, reason: '$axis');
    }
  });

  testWidgets('it scrolls over the furthest edge its content reaches', (tester) async {
    await tester.pumpWidget(_box(scrolls: true));
    expect(_position(tester, Axis.vertical).maxScrollExtent, 200);
    await tester.pumpWidget(_box(scrolls: true, axis: Axis.horizontal));
    expect(_position(tester, Axis.horizontal).maxScrollExtent, 100);
  });

  testWidgets('a drag scrolls it, and a tap lands on what is drawn under it', (tester) async {
    int? hit;
    await tester.pumpWidget(_box(scrolls: true, tapped: (i) => hit = i));
    await tester.drag(find.byType(ScrollBox), const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(_position(tester, Axis.vertical).pixels, greaterThan(0));
    _position(tester, Axis.vertical).jumpTo(130);
    await tester.pump();
    // 10 down the box is 140 down the content: the third band (120-180).
    await tester.tapAt(const Offset(100, 10));
    expect(hit, 2);
  });

  testWidgets('a tap lands on what is scrolled in past every box the content spills from', (tester) async {
    // A carousel as the lowering writes one: padding round a box its row
    // spills from, both the view's width, the cards past them once it is
    // scrolled. Then the same row under a clip, under a box that lets no
    // press through, and under one off the stage: nothing there is hit.
    int? hit;
    Widget carousel(Widget Function(Widget row) round) {
      final row = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 10; i++)
            GestureDetector(
              onTap: () => hit = i,
              child: SizedBox(width: 100, height: 80, child: ColoredBox(color: _colors[i % _colors.length])),
            ),
        ],
      );
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 100,
            child: ClipRect(
              child: ScrollBox(
                horizontal: true,
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, top: 10),
                  child: round(Spill(axis: Axis.horizontal, child: row)),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Future<int?> tapScrolled(Widget Function(Widget row) round, double scrolled, Offset at) async {
      hit = null;
      await tester.pumpWidget(carousel(round));
      _position(tester, Axis.horizontal).jumpTo(scrolled);
      await tester.pump();
      await tester.tapAt(at);
      return hit;
    }

    // At rest: the second card (20 + 100 to 220).
    expect(await tapScrolled((row) => row, 0, const Offset(150, 50)), 1);
    // 500 across: 150 in the view is 650 in, 630 past the padding -- the
    // seventh card (600 to 700).
    expect(await tapScrolled((row) => row, 500, const Offset(150, 50)), 6);
    // NEGATIVE: what a clip cuts there is not drawn there.
    expect(await tapScrolled((row) => ClipRect(child: row), 500, const Offset(150, 50)), isNull);
    expect(await tapScrolled((row) => IgnorePointer(child: row), 500, const Offset(150, 50)), isNull);
    expect(await tapScrolled((row) => Offstage(child: row), 500, const Offset(150, 50)), isNull);
    // NEGATIVE: under the padding, past the cards' height, nothing is hit.
    expect(await tapScrolled((row) => row, 500, const Offset(150, 95)), isNull);
  });

  testWidgets('scrolling both ways, the vertical view reads the content through the horizontal one', (tester) async {
    await tester.pumpWidget(_box(scrolls: true, both: true));
    expect(_position(tester, Axis.vertical).maxScrollExtent, 200);
    expect(_position(tester, Axis.horizontal).maxScrollExtent, 0);
  });

  testWidgets('a ClipBox that scrolls draws what it cuts at rest, and scrolls to the rest', (tester) async {
    Widget clip({required bool scrolls}) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          child: SizedBox(
            width: 200,
            height: 100,
            child: ClipBox(
              floors: false,
              scrollsVertically: scrolls,
              child: Spill(
                axis: Axis.vertical,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final color in _colors) SizedBox(width: 200, height: 60, child: ColoredBox(color: color)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(clip(scrolls: false));
    final cut = await _pixels(tester);
    expect(find.byType(Scrollable), findsNothing);
    await tester.pumpWidget(clip(scrolls: true));
    expect(await _pixels(tester), cut);
    expect(_position(tester, Axis.vertical).maxScrollExtent, 200);
  });

  testWidgets('a sticky box in it is held to the box, whichever ways it scrolls', (tester) async {
    for (final both in [false, true]) {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              height: 100,
              child: ClipBox(
                scrollsVertically: true,
                scrollsHorizontally: both,
                child: Spill(
                  axis: Axis.vertical,
                  child: StickyBlock(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Sticky(top: 0, child: SizedBox(key: ValueKey('bar'), width: 200, height: 20)),
                        SizedBox(width: 200, height: 300),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.getTopLeft(find.byKey(const ValueKey('bar'))).dy, 0, reason: 'at rest, both: $both');
      _position(tester, Axis.vertical).jumpTo(150);
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(const ValueKey('bar'))).dy, 0, reason: 'scrolled, both: $both');
    }
  });

  testWidgets('it draws no scrollbar and no overscroll on any platform', (tester) async {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS, TargetPlatform.windows]) {
      debugDefaultTargetPlatformOverride = platform;
      await tester.pumpWidget(_box(scrolls: true, both: true));
      final chrome = find.descendant(
        of: find.byType(ScrollBox),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Transform ||
              w is RawScrollbar ||
              w is GlowingOverscrollIndicator ||
              w is StretchingOverscrollIndicator,
        ),
      );
      expect(chrome, findsNothing, reason: '$platform');
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the document does not run on into a scroll container', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: DocumentExtent(
            child: SizedBox(
              width: 200,
              height: 100,
              child: ClipRect(
                child: ScrollBox(
                  vertical: true,
                  child: Spill(axis: Axis.vertical, child: const SizedBox(width: 200, height: 300)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(DocumentExtent)).height, 100);
  });

  testWidgets('its dry baseline is its content\'s, asked past the scrollable round it', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: 100,
            child: ScrollBox(
              vertical: true,
              // Nothing in it has a baseline: Flutter 3.41-3.47's proxies
              // assert on that in debug where it is asked through them.
              child: const SizedBox(width: 200, height: 300),
            ),
          ),
        ),
      ),
    );
    final box = tester.renderObject<RenderBox>(find.byType(ScrollBox));
    const tight = BoxConstraints.tightFor(width: 200, height: 100);
    expect(box.getDryBaseline(tight, TextBaseline.alphabetic), isNull);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: 100,
            child: ScrollBox(vertical: true, child: const Text('Ag', style: TextStyle(fontSize: 20))),
          ),
        ),
      ),
    );
    final text = tester.renderObject<RenderBox>(find.byType(ScrollBox));
    expect(
      text.getDryBaseline(const BoxConstraints(maxWidth: 200, maxHeight: 100), TextBaseline.alphabetic),
      isNotNull,
    );
  });

  group('a scroll container that is pointer-events: none takes no pointer of its own (css-ui-4 8.1)', () {
    // a pricing page: a layer the window's size that scrolls and says
    // `none`, round a panel that says `auto`, over a button of the page.
    var under = 0, panel = 0;
    Widget page({required bool takesPointer}) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 300,
          height: 400,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 300,
                child: GestureDetector(
                  onTap: () => under++,
                  child: const SizedBox(width: 300, height: 100, child: ColoredBox(color: Color(0xFF1E88E5))),
                ),
              ),
              Positioned.fill(
                child: ClipBox(
                  scrollsVertically: true,
                  takesPointer: takesPointer,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: GestureDetector(
                      onTap: () => panel++,
                      child: const SizedBox(width: 300, height: 100, child: ColoredBox(color: Color(0xFFE53935))),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    testWidgets('a press beside what it holds is the box drawn under it; one on what it holds is that one\'s', (
      tester,
    ) async {
      await tester.pumpWidget(page(takesPointer: false));
      under = panel = 0;
      await tester.tapAt(const Offset(150, 350));
      await tester.tapAt(const Offset(150, 50));
      expect((under, panel), (1, 1));
    });

    testWidgets('NEGATIVE: a scroll container that takes pointers is hit over its whole port', (tester) async {
      await tester.pumpWidget(page(takesPointer: true));
      under = panel = 0;
      await tester.tapAt(const Offset(150, 350));
      await tester.tapAt(const Offset(150, 50));
      expect((under, panel), (0, 1));
    });
  });
}
