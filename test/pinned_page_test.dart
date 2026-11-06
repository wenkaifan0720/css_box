// A page with pinned headers as a CSS-to-Flutter lowerer writes it:
// the cut's parts slivers of a shrink-wrapped `CustomScrollView`, the page
// after them one more, drawn up by the cut's height.
import 'package:css_box/css_box.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The generated app's delegate for a header with a negative `top`
/// (written to the app's `widgets/pin_rise.dart`).
class PinRise extends SliverPersistentHeaderDelegate {
  const PinRise({required this.extent, required this.rise, required this.child});

  final double extent;
  final double rise;
  final Widget child;

  @override
  double get maxExtent => extent;

  @override
  double get minExtent => extent - rise;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      OverflowBox(alignment: Alignment.bottomCenter, maxHeight: double.infinity, child: child);

  @override
  bool shouldRebuild(PinRise oldDelegate) =>
      extent != oldDelegate.extent || rise != oldDelegate.rise || child != oldDelegate.child;
}

/// The page as the app puts it up: the window handed to it as it is.
Widget _window(Widget page) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(size: Size(390, 844)),
    child: page,
  ),
);

Widget _box(Key key, double h) => ColoredBox(
  key: key,
  color: const Color(0xFF808080),
  child: SizedBox(height: h),
);

/// The page after the cut: its flow, the parts' places held by boxes of
/// their heights, drawn up by [cut].
Widget _after(double cut, List<Widget> flow) => SliverToBoxAdapter(
  child: Inset(
    insets: EdgeInsets.only(top: -cut),
    child: DocumentExtent(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: flow),
    ),
  ),
);

double _y(WidgetTester tester, Key key) => tester.getTopLeft(find.byKey(key)).dy;

Future<void> _scroll(WidgetTester tester, double to) async {
  final s = tester.state<ScrollableState>(find.byType(Scrollable));
  s.position.jumpTo(to);
  await tester.pump();
}

void main() {
  testWidgets("a page's pair of pinned headers holds at 0 and 68 once the page has scrolled 500", (tester) async {
    const a = Key('a'), b = Key('b'), list = Key('list');
    await tester.pumpWidget(
      _window(
        CustomScrollView(
          shrinkWrap: true,
          clipBehavior: Clip.none,
          slivers: [
            PinnedHeaderSliver(child: _box(a, 68)),
            PinnedHeaderSliver(child: _box(b, 68)),
            _after(136, [const SizedBox(height: 68), const SizedBox(height: 68), _box(list, 3000)]),
          ],
        ),
      ),
    );
    expect([_y(tester, a), _y(tester, b), _y(tester, list)], [0, 68, 136]);
    await _scroll(tester, 500);
    expect([_y(tester, a), _y(tester, b), _y(tester, list)], [0, 68, 136 - 500]);
    // A press where the pair stands lands on it, not on the list under it.
    final hit = HitTestResult();
    WidgetsBinding.instance.hitTestInView(hit, const Offset(100, 100), tester.view.viewId);
    final listBox = tester.renderObject(find.byKey(list));
    final bBox = tester.renderObject(find.byKey(b));
    expect(hit.path.any((e) => e.target == bBox), isTrue);
    expect(hit.path.any((e) => e.target == listBox), isFalse);
  });

  Future<void> section(WidgetTester tester, {bool bare = false}) async {
    const head = Key('head'), h2 = Key('h2'), footer = Key('footer');
    await tester.pumpWidget(
      _window(
        CustomScrollView(
          shrinkWrap: true,
          clipBehavior: Clip.none,
          slivers: [
            PinnedHeaderSliver(child: _box(head, 60)),
            const SliverToBoxAdapter(child: SizedBox(height: 400)),
            SliverMainAxisGroup(
              slivers: [
                if (bare) PinnedHeaderSliver(child: _box(h2, 40)) else SectionPin(child: _box(h2, 40)),
                const SliverToBoxAdapter(child: SizedBox(height: 1500)),
              ],
            ),
            _after(2000, [const SizedBox(height: 2000), _box(footer, 2000)]),
          ],
        ),
      ),
    );
    expect([_y(tester, head), _y(tester, h2), _y(tester, footer)], [0, 460, 2000]);
    await _scroll(tester, 1000);
    expect([_y(tester, head), _y(tester, h2)], [0, 60]);
    // The block ends at 2000, and its header's bottom with it: once less
    // than 100 of the block is left, the header is pushed up from 60.
    for (final (s, y) in [(1900.0, 60.0), (1940.0, 20.0), (1950.0, 10.0), (1990.0, -30.0)]) {
      await _scroll(tester, s);
      expect([_y(tester, head), _y(tester, h2), _y(tester, footer)], [0, y, 2000 - s], reason: 'at $s');
    }
  }

  testWidgets('a section header holds under the page header and leaves at its block end', (tester) => section(tester));

  // A group's bare pinned header obstructs its own height alone. Through
  // Flutter 3.38 the group then pushed it out only once less than that was
  // left, so it stood over what follows its section (`section(bare: true)`
  // fails there); from 3.47 the group pushes it by its bottom itself. The
  // SectionPin obstructs the headers it is held under too, which leaves at
  // the block end on both.
  testWidgets("NEGATIVE: a group's bare pinned header obstructs only its own height", (tester) async {
    const head = Key('head'), bare = Key('bare'), held = Key('held');
    await tester.pumpWidget(
      _window(
        CustomScrollView(
          shrinkWrap: true,
          clipBehavior: Clip.none,
          slivers: [
            PinnedHeaderSliver(child: _box(head, 60)),
            const SliverToBoxAdapter(child: SizedBox(height: 400)),
            SliverMainAxisGroup(
              slivers: [
                PinnedHeaderSliver(child: _box(bare, 40)),
                SectionPin(child: _box(held, 40)),
                const SliverToBoxAdapter(child: SizedBox(height: 1500)),
              ],
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 2000)),
          ],
        ),
      ),
    );
    await _scroll(tester, 1000);
    RenderObject? o = tester.renderObject(find.byKey(bare));
    while (o != null && o is! RenderSliver) {
      o = o.parent;
    }
    expect((o! as RenderSliver).geometry!.maxScrollObstructionExtent, 40);
    final pin = tester.renderObject<RenderSliver>(find.byType(SectionPin));
    expect(pin.geometry!.maxScrollObstructionExtent, 40 + pin.constraints.overlap);
    expect(pin.constraints.overlap, greaterThan(0));
  });

  testWidgets('a header at top: -50 rises by 50 and holds what is left', (tester) async {
    const head = Key('head'), list = Key('list');
    await tester.pumpWidget(
      _window(
        CustomScrollView(
          shrinkWrap: true,
          clipBehavior: Clip.none,
          slivers: [
            SliverPersistentHeader(pinned: true, delegate: PinRise(extent: 90, rise: 50, child: _box(head, 90))),
            _after(90, [const SizedBox(height: 90), _box(list, 3000)]),
          ],
        ),
      ),
    );
    expect([_y(tester, head), _y(tester, list)], [0, 90]);
    await _scroll(tester, 30);
    expect([_y(tester, head), _y(tester, list)], [-30, 60]);
    await _scroll(tester, 500);
    expect([_y(tester, head), _y(tester, list)], [-50, 90 - 500]);
  });

  testWidgets('laid out in no height, the page is all of itself at scroll 0', (tester) async {
    // The shooter's host: the page in a scroll of its own, never scrolled.
    const a = Key('a'), list = Key('list');
    await tester.pumpWidget(
      _window(
        SingleChildScrollView(
          child: CustomScrollView(
            shrinkWrap: true,
            clipBehavior: Clip.none,
            slivers: [
              PinnedHeaderSliver(child: _box(a, 68)),
              _after(68, [const SizedBox(height: 68), _box(list, 3000)]),
            ],
          ),
        ),
      ),
    );
    expect([_y(tester, a), _y(tester, list)], [0, 68]);
    expect(tester.getSize(find.byType(CustomScrollView)).height, 3068);
  });
}
