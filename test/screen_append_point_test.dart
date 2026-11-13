// A PAGE IN A COLUMN HELD TO THE WINDOW'S HEIGHT, AN EMPTY WIDGET UNDER IT:
// a screen scrolls a `Column` whose first child is the page, held at least
// as tall as the window, and whose second is a widget of the page's own,
// empty until something is added to it.
//
// Against the same screen without the `Column` (the page alone, held to the
// window's height): with the widget empty, a page is laid out and scrolled
// as it was, short or long, on a phone, a tablet and a desktop window; with
// something in it, the page is still as it was, and what is added stands
// under the last of it at the page's width and is scrolled to. A bar the
// page fixes to the window's foot ([FixedLayer]) stays at the window's
// foot, and what is added lies over it where the scroll ends: what is added
// leaves the bar room.
// NEGATIVE: an empty widget adds nothing to scroll.
import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _keys = [ValueKey('page'), ValueKey('head'), ValueKey('foot')];
const _more = ValueKey('more'), _bar = ValueKey('bar');

/// The screen without the `Column`: the page alone, held to the window's
/// height, in the scroll.
class _Screen extends StatelessWidget {
  const _Screen(this.page);

  final Widget page;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height),
      child: page,
    ),
  );
}

/// The screen with the `Column`: the page held to the window's height, and
/// [after], the page's own widget, under it.
class _Appended extends StatelessWidget {
  const _Appended(this.page, {this.after});

  final Widget page;
  final Widget? after;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height),
          child: page,
        ),
        if (after case final after?) after,
      ],
    ),
  );
}

/// A page: a head, [body] tall of content, and a foot set at the end of a
/// root that fills what it is held to; [bar] tall of a bar fixed to the
/// foot of a [window] over it, where there is one.
Widget _page(double body, {double? bar, Size? window}) {
  final flow = ColoredBox(
    key: const ValueKey('page'),
    color: const Color(0xFFEEEEEE),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(key: ValueKey('head'), height: 64),
        SizedBox(height: body),
        const SizedBox(key: ValueKey('foot'), height: 120),
      ],
    ),
  );
  if (bar == null) return flow;
  return Stack(
    clipBehavior: Clip.none,
    fit: StackFit.passthrough,
    children: [
      flow,
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

/// The app round [screen], its one route.
Widget _app(Widget screen) => WidgetsApp(
  color: const Color(0xFFFFFFFF),
  initialRoute: '/',
  routes: {'/': (context) => screen},
  pageRouteBuilder: <T>(settings, builder) =>
      PageRouteBuilder<T>(settings: settings, pageBuilder: (context, _, __) => builder(context)),
);

/// Each keyed box of [app] and how far its page scrolls, scrolled to
/// [scroll] (to the end past it).
Future<({Map<Key, Rect> rects, double extent})> _laidOut(
  WidgetTester t,
  Widget app, {
  double scroll = 0,
  List<Key> more = const [],
}) async {
  await t.pumpWidget(app);
  await t.pumpAndSettle();
  final position = t.state<ScrollableState>(find.byType(Scrollable)).position;
  if (scroll != 0) {
    position.jumpTo(scroll.clamp(0, position.maxScrollExtent));
    await t.pump();
  }
  final got = (
    rects: {for (final k in [..._keys, ...more]) k: t.getRect(find.byKey(k))},
    extent: position.maxScrollExtent,
  );
  // The next pump starts from a fresh tree.
  await t.pumpWidget(const SizedBox());
  return got;
}

void main() {
  for (final (w, h) in const [(390.0, 844.0), (1024.0, 768.0), (1440.0, 900.0)]) {
    for (final body in const [200.0, 3000.0]) {
      testWidgets('a page $body tall with an empty widget under it in a $w x $h window is laid out as without', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(w, h);
        addTearDown(t.view.reset);
        for (final scroll in const [0.0, 500.0, double.infinity]) {
          final was = await _laidOut(t, _app(_Screen(_page(body))), scroll: scroll);
          final now = await _laidOut(t, _app(_Appended(_page(body), after: const SizedBox.shrink())), scroll: scroll);
          expect(now.rects, was.rects, reason: 'scrolled to $scroll');
          expect(now.extent, was.extent, reason: 'scrolled to $scroll');
          // The same with no widget at all for the page: a page left out.
          final none = await _laidOut(t, _app(_Appended(_page(body))), scroll: scroll);
          expect(none.rects, was.rects, reason: 'scrolled to $scroll');
          expect(none.extent, was.extent, reason: 'scrolled to $scroll');
        }
      });

      testWidgets('what is added under a page $body tall in a $w x $h window stands after it and is scrolled to', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(w, h);
        addTearDown(t.view.reset);
        const added = SizedBox(key: _more, height: 80);
        final was = await _laidOut(t, _app(_Screen(_page(body))));
        final now = await _laidOut(t, _app(_Appended(_page(body), after: added)), more: const [_more]);
        // The page is where it was, as tall as it was.
        expect({for (final k in _keys) k: now.rects[k]}, was.rects);
        final page = was.rects[const ValueKey('page')]!;
        expect(now.rects[_more], Rect.fromLTWH(0, page.bottom, w, 80));
        expect(now.extent, was.extent + 80);
        // Scrolled to its end, the last of what is added is at the window's foot.
        final end = await _laidOut(t, _app(_Appended(_page(body), after: added)), scroll: double.infinity, more: const [_more]);
        expect(end.rects[_more]!.bottom, h);
      });
    }
  }

  testWidgets('a bar the page fixes to the foot of the window stays there, under what is added where the scroll ends', (t) async {
    const window = Size(390, 844);
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = window;
    addTearDown(t.view.reset);
    final pressed = <String>[];
    Widget screen({required bool added}) => _app(
      _Appended(
        _page(3000, bar: 60, window: window),
        after: added
            ? GestureDetector(
                key: _more,
                behavior: HitTestBehavior.opaque,
                onTap: () => pressed.add('more'),
                child: const SizedBox(height: 80),
              )
            : const SizedBox.shrink(),
      ),
    );
    // Empty, the page with its bar is as on the screen without it.
    for (final scroll in const [0.0, 500.0, double.infinity]) {
      final was = await _laidOut(t, _app(_Screen(_page(3000, bar: 60, window: window))), scroll: scroll, more: const [_bar]);
      final now = await _laidOut(t, screen(added: false), scroll: scroll, more: const [_bar]);
      expect(now.rects, was.rects, reason: 'scrolled to $scroll');
      expect(now.extent, was.extent, reason: 'scrolled to $scroll');
      expect(was.rects[_bar], const Rect.fromLTWH(0, 844 - 60, 390, 60));
    }
    // With something added: the bar is at the window's foot at every scroll,
    // and at the end of the scroll what is added lies where the bar is.
    await t.pumpWidget(screen(added: true));
    await t.pumpAndSettle();
    final position = t.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(t.getRect(find.byKey(_bar)), const Rect.fromLTWH(0, 844 - 60, 390, 60));
    position.jumpTo(position.maxScrollExtent);
    await t.pump();
    expect(t.getRect(find.byKey(_bar)), const Rect.fromLTWH(0, 844 - 60, 390, 60));
    expect(t.getRect(find.byKey(_more)), const Rect.fromLTWH(0, 844 - 80, 390, 80));
    // It takes the press there: what is added leaves the bar room below it.
    await t.tapAt(const Offset(195, 844 - 30));
    expect(pressed, ['more']);
  });
}
