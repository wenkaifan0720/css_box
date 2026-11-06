import 'package:css_box/css_box.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 390 x 600 screen of [page], under a [PressWhereDrawn] where [drawn].
Widget _screen(Widget page, {bool drawn = true}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 390, height: 600, child: drawn ? PressWhereDrawn(child: page) : page),
  ),
);

/// A control of [width] x [height] that says [name] to [pressed] when pressed.
Widget _control(String name, List<String> pressed, {double width = 120, double height = 40}) => GestureDetector(
  behavior: HitTestBehavior.opaque,
  onTap: () => pressed.add(name),
  child: SizedBox(width: width, height: height),
);

/// A page's column of [rows] 100 tall, with [bar] after them: a box of no
/// height at the foot of the window, its bar placed at its foot and drawn
/// above it, as a page's fixed bar is lowered.
Widget _barPage(List<String> pressed, {Widget Function(Widget bar)? round, Widget? over}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    for (var i = 0; i < 5; i++) SizedBox(height: 100, child: _control('row $i', pressed, width: 390, height: 100)),
    SizedBox(height: 100),
    Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        const SizedBox(width: 390, height: 0),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: (round ?? (bar) => bar)(Row(children: [_control('add to', pressed), _control('plan', pressed)])),
        ),
        if (over != null) Positioned(left: 0, right: 0, bottom: 0, child: over),
      ],
    ),
  ],
);

/// The bar page with [words] across its bar (560 to 600) in a stack round
/// it, painted after the page, or before it where [under].
Widget _wordsPage(List<String> pressed, Widget words, {bool under = false}) {
  final across = Positioned(left: 0, right: 0, top: 560, child: words);
  final page = Positioned.fill(child: _barPage(pressed));
  return Stack(children: under ? [across, page] : [page, across]);
}

void main() {
  testWidgets('a hung control where it takes no press leaves the press to the control hung under it', (tester) async {
    final pressed = <String>[];
    // A row laid over the bar, drawn from 560 to 600 as the bar is and as
    // wide, that takes a press on its button alone (150 to 210): a gesture
    // detector that defers to its child.
    final over = GestureDetector(
      onTap: () => pressed.add('over'),
      child: const Padding(
        padding: EdgeInsets.only(left: 150),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ColoredBox(color: Color(0xFF000000), child: SizedBox(width: 60, height: 40)),
        ),
      ),
    );
    await tester.pumpWidget(_screen(_barPage(pressed, over: over)));
    await tester.tapAt(const Offset(60, 580));
    expect(pressed, ['add to']);
    // NEGATIVE: on its button it takes the press, painted over the bar's.
    await tester.tapAt(const Offset(180, 580));
    expect(pressed.last, 'over');
    // And beside it the bar's own.
    await tester.tapAt(const Offset(225, 580));
    expect(pressed.last, 'plan');
  });

  testWidgets('a bar hung above a box of no height is pressed where it is drawn', (tester) async {
    final pressed = <String>[];
    // The bar is drawn from 560 to 600, over the last 40 of the space under
    // the rows; the box it hangs from stands at 600, no taller than nothing.
    await tester.pumpWidget(_screen(_barPage(pressed), drawn: false));
    await tester.tapAt(const Offset(60, 580));
    expect(pressed, isEmpty, reason: 'a box hit-tests only inside itself');
    await tester.pumpWidget(_screen(_barPage(pressed)));
    await tester.tapAt(const Offset(60, 580));
    await tester.tapAt(const Offset(180, 580));
    expect(pressed, ['add to', 'plan']);
    // A row is pressed as it was.
    await tester.tapAt(const Offset(60, 450));
    expect(pressed.last, 'row 4');
  });

  testWidgets('a dialog moved out of the frame it stands in is pressed where it is drawn', (tester) async {
    final pressed = <String>[];
    Widget dialog({bool drawn = true}) => _screen(
      Stack(
        fit: StackFit.passthrough,
        children: [
          _control('barrier', pressed, width: 390, height: 600),
          Stack(
            clipBehavior: Clip.none,
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(),
                child: Transform.translate(
                  offset: const Offset(110, 354),
                  child: IntrinsicWidth(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _control('join', pressed, width: 260, height: 50),
                        _control('create', pressed, width: 260, height: 50),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      drawn: drawn,
    );
    await tester.pumpWidget(dialog(drawn: false));
    await tester.tapAt(const Offset(240, 379));
    expect(pressed, ['barrier'], reason: 'the frame the dialog stands in holds none of it');
    pressed.clear();
    await tester.pumpWidget(dialog());
    await tester.tapAt(const Offset(240, 379));
    await tester.tapAt(const Offset(240, 429));
    await tester.tapAt(const Offset(40, 300));
    expect(pressed, ['join', 'create', 'barrier']);
  });

  testWidgets('a box hung over the press and every box round it is on the path', (tester) async {
    final pressed = <String>[];
    final heard = <String>[];
    await tester.pumpWidget(
      _screen(
        _barPage(
          pressed,
          round: (bar) => Listener(onPointerDown: (_) => heard.add('bar'), child: bar),
        ),
      ),
    );
    await tester.tapAt(const Offset(60, 580));
    expect(pressed, ['add to']);
    expect(heard, ['bar']);
  });

  testWidgets('NEGATIVE: what is painted over a hung control takes the press', (tester) async {
    final pressed = <String>[];
    await tester.pumpWidget(_screen(_barPage(pressed, over: _control('sheet', pressed, width: 390, height: 60))));
    await tester.tapAt(const Offset(60, 580));
    expect(pressed, ['sheet']);
  });

  testWidgets('NEGATIVE: a hung control a clip cuts, or under a box that lets no press through, is not pressed', (
    tester,
  ) async {
    final pressed = <String>[];
    for (final round in <Widget Function(Widget)>[
      (bar) => ClipRect(
        child: SizedBox(
          height: 0,
          child: OverflowBox(maxHeight: 40, alignment: Alignment.bottomCenter, child: bar),
        ),
      ),
      (bar) => IgnorePointer(child: bar),
      (bar) => Offstage(child: bar),
    ]) {
      await tester.pumpWidget(_screen(_barPage(pressed, round: round)));
      await tester.tapAt(const Offset(60, 580));
    }
    // What is under the bar where it is not drawn: nothing (the space under
    // the rows is no control).
    expect(pressed, isEmpty);
  });

  testWidgets('NEGATIVE: a control inside every box round it is hit as any box is', (tester) async {
    final pressed = <String>[];
    await tester.pumpWidget(
      _screen(
        Stack(
          children: [
            Positioned(left: 0, top: 0, child: _control('under', pressed)),
            Positioned(left: 0, top: 0, child: _control('over', pressed)),
          ],
        ),
      ),
    );
    await tester.tapAt(const Offset(10, 10));
    expect(pressed, ['over']);
  });

  testWidgets('a bar its box paints last takes the press over a control hung under it', (tester) async {
    final pressed = <String>[];
    // A bar 60 tall, held first; under it a box whose card is placed 40
    // above it, drawn over the bar's foot (20 to 60).
    Widget page(List<int> z) => Layers(
      direction: Axis.vertical,
      z: z,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _control('bar', pressed, width: 390, height: 60),
        Stack(
          clipBehavior: Clip.none,
          children: [
            const SizedBox(width: 390, height: 100),
            Positioned(left: 0, top: -40, child: _control('card', pressed)),
          ],
        ),
      ],
    );
    // A sticky bar's z: painted over what scrolls under it.
    await tester.pumpWidget(_screen(page([1, 0])));
    await tester.tapAt(const Offset(60, 40));
    expect(pressed, ['bar']);
    // NEGATIVE: painted in the order it is held, the card is over the bar.
    await tester.pumpWidget(_screen(page([0, 0])));
    await tester.tapAt(const Offset(60, 40));
    expect(pressed, ['bar', 'card']);
  });

  testWidgets("a view's pinned header takes the press over a control hung under it from a later sliver", (
    tester,
  ) async {
    final pressed = <String>[];
    // A pinned header 60 tall, the view's first sliver; the next sliver's
    // card, 80 tall, placed 40 above its box: drawn under the header's foot
    // (20 to 60) and on past it. A view paints its first sliver last, a
    // group its slivers too.
    final header = PinnedHeaderSliver(child: _control('header', pressed, width: 390, height: 60));
    final body = SliverToBoxAdapter(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const SizedBox(width: 390, height: 100),
          Positioned(left: 0, top: -40, child: _control('card', pressed, height: 80)),
        ],
      ),
    );
    for (final page in [
      CustomScrollView(shrinkWrap: true, slivers: [header, body]),
      CustomScrollView(slivers: [header, body]),
      CustomScrollView(
        shrinkWrap: true,
        slivers: [
          SliverMainAxisGroup(slivers: [header, body]),
        ],
      ),
    ]) {
      await tester.pumpWidget(_screen(page));
      await tester.tapAt(const Offset(60, 40));
    }
    expect(pressed, ['header', 'header', 'header']);
    // NEGATIVE: where the header is not drawn the card is pressed.
    await tester.tapAt(const Offset(60, 70));
    expect(pressed.last, 'card');
  });

  testWidgets('NEGATIVE: what a scroll port hits where it is drawn is not hung', (tester) async {
    final pressed = <String>[];
    // Content laid out at the view's size, the rest scrolled into view: a
    // box that paints its first child last, 1000 down it.
    await tester.pumpWidget(
      _screen(
        ClipRect(
          child: ScrollBox(
            vertical: true,
            child: Spill(
              axis: Axis.vertical,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < 10; i++) const SizedBox(width: 390, height: 100),
                  Flow(delegate: const _FirstLast(), children: [_control('over', pressed), _control('under', pressed)]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    tester.state<ScrollableState>(find.byType(Scrollable)).position.jumpTo(900);
    await tester.pump();
    await tester.tapAt(const Offset(60, 120));
    expect(pressed, ['over']);
  });

  testWidgets('a hung line with a link in it is pressed on its letters', (tester) async {
    final pressed = <String>[];
    final link = TapGestureRecognizer()..onTap = () => pressed.add('link');
    addTearDown(link.dispose);
    await tester.pumpWidget(
      _screen(
        _barPage(
          pressed,
          round: (bar) =>
              Text.rich(TextSpan(text: 'see all', recognizer: link, style: const TextStyle(fontSize: 20, height: 2))),
        ),
      ),
    );
    await tester.tapAt(const Offset(20, 580));
    expect(pressed, ['link']);
  });

  // A press on a letter is hit in the line of text it is in: the span of the
  // letter is first on the path, before the paragraph -- no box, and not
  // nothing hit.
  testWidgets('words painted over a hung control take the press on their letters, as off them', (tester) async {
    final pressed = <String>[];
    // A chip of words across the bar, inside every box round it; its letters
    // from 0 to 60 across, 570 to 590 down.
    await tester.pumpWidget(
      _screen(
        _wordsPage(
          pressed,
          GestureDetector(
            onTap: () => pressed.add('chip'),
            child: const Text('All', style: _words),
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(10, 580));
    await tester.tapAt(const Offset(200, 580));
    expect(pressed, ['chip', 'chip']);
    // Words that are no control take the press all the same.
    await tester.pumpWidget(_screen(_wordsPage(pressed, const Text('All', style: _words))));
    await tester.tapAt(const Offset(10, 580));
    expect(pressed, ['chip', 'chip']);
  });

  testWidgets('a bar of words its box paints last takes the press on its letters over a control hung under it', (
    tester,
  ) async {
    final pressed = <String>[];
    // A sticky bar of words 60 tall, its letters from 10 to 30; a card hung
    // 40 above the box under it, drawn over the bar from 20 to 60.
    Widget page(List<int> z) => Layers(
      direction: Axis.vertical,
      z: z,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => pressed.add('bar'),
          child: const SizedBox(width: 390, height: 60, child: Text('All Homes', style: _words)),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            const SizedBox(width: 390, height: 100),
            Positioned(left: 0, top: -40, child: _control('card', pressed)),
          ],
        ),
      ],
    );
    await tester.pumpWidget(_screen(page([1, 0])));
    await tester.tapAt(const Offset(10, 25));
    expect(pressed, ['bar']);
    // NEGATIVE: painted in the order it is held, the card is over the bar's words.
    await tester.pumpWidget(_screen(page([0, 0])));
    await tester.tapAt(const Offset(10, 25));
    expect(pressed, ['bar', 'card']);
  });

  testWidgets('NEGATIVE: words painted under a hung control do not take its press', (tester) async {
    final pressed = <String>[];
    await tester.pumpWidget(
      _screen(
        _wordsPage(
          pressed,
          GestureDetector(
            onTap: () => pressed.add('chip'),
            child: const Text('All', style: _words),
          ),
          under: true,
        ),
      ),
    );
    await tester.tapAt(const Offset(10, 580));
    await tester.tapAt(const Offset(200, 580));
    expect(pressed, ['add to', 'plan']);
  });
}

/// Words on a line 40 tall, each letter a 20 x 20 square in its middle.
const _words = TextStyle(fontSize: 20, height: 2);

/// A box that paints its children last to first, each where it stands: the
/// first is over the rest.
class _FirstLast extends FlowDelegate {
  const _FirstLast();

  @override
  Size getSize(BoxConstraints constraints) => const Size(390, 100);

  @override
  void paintChildren(FlowPaintingContext context) {
    for (var i = context.childCount - 1; i >= 0; i--) {
      context.paintChild(i);
    }
  }

  @override
  bool shouldRepaint(_FirstLast oldDelegate) => false;
}
