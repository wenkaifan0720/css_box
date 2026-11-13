// A PAGE THAT SCROLLS ITSELF, AN EMPTY WIDGET AT THE END OF ITS SCROLL VIEW:
// a page whose header pins is a `CustomScrollView` of its own -- the header
// a `PinnedHeaderSliver`, the rest of the page a `SliverToBoxAdapter` drawn
// up under it ([Inset]) and measured by a [DocumentExtent], shrink-wrapped
// so that the window it is handed scrolls it -- and a bar the page fixes to
// the window's foot ([FixedLayer]) is a layer over the scroll view. A widget
// of the page's own, empty until something is added to it, is the scroll
// view's last sliver; on a page that scrolls in a `SingleChildScrollView`,
// the last child of its `Column`; in a `ListView`, the last of its
// children.
//
// Against the same page without it: with the widget empty, the page is
// laid out and scrolled as it was, short or long, on a phone, a tablet and a
// desktop window, and laid out with no bound below it is as tall as it was;
// with something in it, the page is still as it was, its header pinned and
// its bar at the window's foot, and what is added stands after the last of
// the page at the scroll view's width and is scrolled to, under the bar.
// NEGATIVE: an empty widget adds nothing to scroll. (A `ListView` lays its
// children out only as they are scrolled to, and until its end is laid out
// guesses how far it scrolls from those it has: one more child moves that
// guess, not where anything is nor where the scroll ends.)
import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _head = ValueKey('head'), _body = ValueKey('body'), _page = ValueKey('page'), _foot = ValueKey('foot');
const _keys = [_head, _body, _page, _foot];
const _more = ValueKey('more'), _bar = ValueKey('bar');

/// A page that scrolls itself: a header 64 tall pinned at the top, [body]
/// tall of content after it and a foot 120 tall at the end of it; [last],
/// the scroll view's last sliver, where there is one; and [bar] tall of a
/// bar fixed to the foot of a [window] over it, where there is one.
Widget _pinned(double body, {Widget? last, double? bar, Size? window}) {
  final scroll = CustomScrollView(
    shrinkWrap: true,
    clipBehavior: Clip.none,
    slivers: [
      const PinnedHeaderSliver(
        child: SizedBox(key: _head, height: 64, child: ColoredBox(color: Color(0xFF3050A0))),
      ),
      SliverToBoxAdapter(
        child: Inset(
          key: _body,
          insets: const EdgeInsets.only(top: -64),
          child: DocumentExtent(
            child: ColoredBox(
              key: _page,
              color: const Color(0xFFEEEEEE),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Where the header stood in the page, which pins it.
                  const SizedBox(height: 64),
                  SizedBox(height: body),
                  const SizedBox(key: _foot, height: 120),
                ],
              ),
            ),
          ),
        ),
      ),
      if (last != null) SliverToBoxAdapter(child: last),
    ],
  );
  if (bar == null) return scroll;
  return Stack(
    clipBehavior: Clip.none,
    children: [
      scroll,
      Positioned(
        left: 0,
        top: 0,
        child: FixedLayer(
          child: SizedBox.fromSize(
            size: window,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SizedBox(key: _bar, height: bar, child: const ColoredBox(color: Color(0xFF202020))),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

/// The app round [page], which it hands the window as it is.
Widget _app(Widget page) => WidgetsApp(
  color: const Color(0xFFFFFFFF),
  initialRoute: '/',
  routes: {'/': (context) => page},
  pageRouteBuilder: <T>(settings, builder) =>
      PageRouteBuilder<T>(settings: settings, pageBuilder: (context, _, __) => builder(context)),
);

/// Each keyed box of [app] it builds and how far its page scrolls,
/// scrolled to [scroll] (to the end past it).
Future<({Map<Key, Rect> rects, double extent})> _laidOut(
  WidgetTester t,
  Widget app, {
  double scroll = 0,
  List<Key> keys = _keys,
}) async {
  await t.pumpWidget(app);
  await t.pumpAndSettle();
  final position = t.state<ScrollableState>(find.byType(Scrollable)).position;
  if (scroll != 0) {
    position.jumpTo(scroll.clamp(0, position.maxScrollExtent));
    await t.pumpAndSettle();
    // A list that lays its children out only as they are scrolled to
    // guesses how far it scrolls until its end is laid out: to its end
    // again, until it is.
    while (scroll == double.infinity && position.pixels != position.maxScrollExtent) {
      position.jumpTo(position.maxScrollExtent);
      await t.pumpAndSettle();
    }
  }
  final got = (
    rects: {
      for (final k in keys)
        if (find.byKey(k).evaluate().isNotEmpty) k: t.getRect(find.byKey(k)),
    },
    extent: position.maxScrollExtent,
  );
  // The next pump starts from a fresh tree.
  await t.pumpWidget(const SizedBox());
  return got;
}

void main() {
  for (final (w, h) in const [(390.0, 844.0), (1024.0, 768.0), (1440.0, 900.0)]) {
    for (final body in const [200.0, 3000.0]) {
      testWidgets('a page $body tall that scrolls itself, an empty last sliver in it, in a $w x $h window is laid out as '
          'without', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(w, h);
        addTearDown(t.view.reset);
        for (final scroll in const [0.0, 500.0, double.infinity]) {
          final was = await _laidOut(t, _app(_pinned(body)), scroll: scroll);
          final now = await _laidOut(t, _app(_pinned(body, last: const SizedBox.shrink())), scroll: scroll);
          expect(now.rects, was.rects, reason: 'scrolled to $scroll');
          expect(now.extent, was.extent, reason: 'scrolled to $scroll');
          // The header stays pinned at the top.
          expect(now.rects[_head], Rect.fromLTWH(0, 0, w, 64), reason: 'scrolled to $scroll');
        }
      });

      testWidgets('what is added as the last sliver of a page $body tall in a $w x $h window stands after it and is '
          'scrolled to', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(w, h);
        addTearDown(t.view.reset);
        const added = SizedBox(key: _more, height: 80);
        final was = await _laidOut(t, _app(_pinned(body)));
        final now = await _laidOut(t, _app(_pinned(body, last: added)), keys: const [..._keys, _more]);
        // The page is where it was, as tall as it was, and what is added
        // starts where the page's sliver ends, at the scroll view's width.
        expect({for (final k in _keys) k: now.rects[k]}, was.rects);
        expect(now.rects[_more], Rect.fromLTWH(0, was.rects[_body]!.bottom, w, 80));
        // A page longer than the window scrolls by that much more; one the
        // window holds with it still scrolls not at all.
        expect(now.extent, body > h ? was.extent + 80 : 0);
        if (body > h) {
          // Scrolled to its end, the last of what is added is at the window's foot.
          final end = await _laidOut(t, _app(_pinned(body, last: added)), scroll: double.infinity,
              keys: const [..._keys, _more]);
          expect(end.rects[_more]!.bottom, h);
          expect(end.rects[_head], Rect.fromLTWH(0, 0, w, 64));
        }
      });
    }
  }

  testWidgets('a bar the page fixes to the foot of the window stays there, over what is added where the scroll ends', (t) async {
    const window = Size(390, 844);
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = window;
    addTearDown(t.view.reset);
    final pressed = <String>[];
    Widget page({required bool added}) => _app(
      _pinned(
        3000,
        bar: 60,
        window: window,
        last: added
            ? GestureDetector(
                key: _more,
                behavior: HitTestBehavior.opaque,
                onTap: () => pressed.add('more'),
                child: const SizedBox(height: 80),
              )
            : const SizedBox.shrink(),
      ),
    );
    // Empty, the page with its bar is as without it.
    for (final scroll in const [0.0, 500.0, double.infinity]) {
      final was = await _laidOut(t, _app(_pinned(3000, bar: 60, window: window)), scroll: scroll, keys: const [..._keys, _bar]);
      final now = await _laidOut(t, page(added: false), scroll: scroll, keys: const [..._keys, _bar]);
      expect(now.rects, was.rects, reason: 'scrolled to $scroll');
      expect(now.extent, was.extent, reason: 'scrolled to $scroll');
      expect(was.rects[_bar], const Rect.fromLTWH(0, 844 - 60, 390, 60));
    }
    // With something added: the bar is at the window's foot at every
    // scroll, and at the end of the scroll what is added lies under it.
    await t.pumpWidget(page(added: true));
    await t.pumpAndSettle();
    final position = t.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(t.getRect(find.byKey(_bar)), const Rect.fromLTWH(0, 844 - 60, 390, 60));
    position.jumpTo(position.maxScrollExtent);
    await t.pump();
    expect(t.getRect(find.byKey(_bar)), const Rect.fromLTWH(0, 844 - 60, 390, 60));
    expect(t.getRect(find.byKey(_more)), const Rect.fromLTWH(0, 844 - 80, 390, 80));
    // It takes a press above the bar: what is added leaves the bar room below it.
    await t.tapAt(const Offset(195, 844 - 70));
    expect(pressed, ['more']);
  });

  testWidgets('laid out with no bound below, a page with an empty last sliver is as tall as without, and one with something '
      'in it taller by that', (t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(390, 844);
    addTearDown(t.view.reset);
    Future<double> tall(Widget? last) async {
      await t.pumpWidget(
        _app(OverflowBox(alignment: Alignment.topCenter, maxHeight: double.infinity, child: _pinned(3000, last: last))),
      );
      await t.pumpAndSettle();
      final height = t.getSize(find.byType(CustomScrollView)).height;
      await t.pumpWidget(const SizedBox());
      return height;
    }

    final was = await tall(null);
    expect(was, greaterThan(3000));
    expect(await tall(const SizedBox.shrink()), was);
    expect(await tall(const SizedBox(height: 80)), was + 80);
  });

  for (final listed in const [false, true]) {
    final kind = listed ? 'a ListView' : 'the Column of a SingleChildScrollView';
    testWidgets('an empty last child of $kind a page scrolls itself in adds nothing to scroll', (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(390, 844);
      addTearDown(t.view.reset);
      Widget page(double body, {Widget? last}) {
        final children = <Widget>[
          SizedBox(key: _page, height: body),
          const SizedBox(key: _foot, height: 120),
          if (last != null) last,
        ];
        return listed
            ? ListView(padding: EdgeInsets.zero, children: children)
            : SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
              );
      }

      for (final body in const [200.0, 3000.0]) {
        for (final scroll in const [0.0, 500.0, double.infinity]) {
          final was = await _laidOut(t, _app(page(body)), scroll: scroll, keys: const [_page, _foot]);
          final now = await _laidOut(t, _app(page(body, last: const SizedBox.shrink())), scroll: scroll,
              keys: const [_page, _foot]);
          expect(now.rects, was.rects, reason: '$body tall, scrolled to $scroll');
          // A ListView lays its children out only as they are scrolled to,
          // and until its end is laid out guesses how far it scrolls from
          // those it has: one more child moves the guess, not where anything
          // is nor where the scroll ends.
          if (!listed || scroll == double.infinity || body < 844) {
            expect(now.extent, was.extent, reason: '$body tall, scrolled to $scroll');
          }
        }
        // Something added stands after the foot, at the page's width, and
        // is scrolled to.
        final added = await _laidOut(t, _app(page(body, last: const SizedBox(key: _more, height: 80))),
            scroll: double.infinity, keys: const [_foot, _more]);
        expect(added.rects[_more], Rect.fromLTWH(0, added.rects[_foot]!.bottom, 390, 80));
        if (body > 844) expect(added.rects[_more]!.bottom, 844);
      }
    });
  }
}
