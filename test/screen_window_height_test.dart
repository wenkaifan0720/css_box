// A PAGE IS HELD TO THE WINDOW'S HEIGHT AT LEAST, AND SCROLLED PAST IT: the
// initial containing block is the viewport (CSS 2.1 10.1), so a page's root
// of `min-height: 100vh` -- every captured page's background, and a footer
// pushed to the foot of a short page -- reaches the foot of the window, and
// a longer page scrolls. Each generated app puts its pages up as such a
// screen (`bin/app.dart`, `appMain`): a `SingleChildScrollView` round a
// `ConstrainedBox` of the window's height as its floor. The window's height
// was read off the route's constraints by a `LayoutBuilder`; it is the
// height `MediaQuery.sizeOf` says: the app's `WidgetsApp` puts each route up
// in an `Overlay` that lays it out tight at the whole view
// (`RenderTheater`), and the `View` that `runApp` puts round it says that
// view's size (`MediaQueryData.fromView`: its physical size over its pixel
// ratio), the size the root `RenderView` is laid out at.
//
// This pins the two screens to the same boxes, in the app's own
// `WidgetsApp` and route, on a phone, a tablet and a desktop window: a page
// shorter than the window (its foot at the window's foot), a page longer
// than it (scrolled, too), and the view resized under the app. NEGATIVE: a
// screen put up in less than the whole view -- which no generated app does --
// is held to the view's height, not to the room it has.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _keys = [ValueKey('page'), ValueKey('head'), ValueKey('foot')];

/// The screen as it was: the window's height read off the route's
/// constraints.
class _Built extends StatelessWidget {
  const _Built(this.page);

  final Widget page;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, window) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: window.maxHeight),
        child: page,
      ),
    ),
  );
}

/// The screen as `appMain` now writes it.
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

/// A page: a head, [body] tall of content, and a foot set at the end of a
/// root that fills what it is held to (`justify-content: space-between`).
Widget _page(double body) => ColoredBox(
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

/// The app round [screen], as `appMain` writes it, put up in [host].
Widget _app(Widget screen, {TransitionBuilder? host}) => WidgetsApp(
  color: const Color(0xFFFFFFFF),
  initialRoute: '/',
  builder: host,
  routes: {'/': (context) => screen},
  pageRouteBuilder: <T>(settings, builder) =>
      PageRouteBuilder<T>(settings: settings, pageBuilder: (context, _, __) => builder(context)),
);

Future<Map<Key, Rect>> _rects(WidgetTester t, Widget app, {double scroll = 0}) async {
  await t.pumpWidget(app);
  await t.pumpAndSettle();
  if (scroll != 0) {
    t.state<ScrollableState>(find.byType(Scrollable)).position.jumpTo(scroll);
    await t.pump();
  }
  final rects = {for (final k in _keys) k: t.getRect(find.byKey(k))};
  // The next pump starts from a fresh tree.
  await t.pumpWidget(const SizedBox());
  return rects;
}

void main() {
  for (final (w, h) in const [(390.0, 844.0), (1024.0, 768.0), (1440.0, 900.0)]) {
    for (final body in const [200.0, 3000.0]) {
      testWidgets('a page $body tall in a $w x $h window is laid out alike', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(w, h);
        addTearDown(t.view.reset);
        final built = await _rects(t, _app(_Built(_page(body))));
        final screen = await _rects(t, _app(_Screen(_page(body))));
        expect(screen, built);
        final page = built[const ValueKey('page')]!;
        if (body < h) {
          // Held to the window, the foot at its foot.
          expect(page.height, h);
          expect(built[const ValueKey('foot')]!.bottom, h);
        } else {
          expect(page.height, 64 + body + 120);
        }
      });
    }

    testWidgets('a long page scrolled in a $w x $h window is laid out alike', (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = Size(w, h);
      addTearDown(t.view.reset);
      final built = await _rects(t, _app(_Built(_page(3000))), scroll: 500);
      final screen = await _rects(t, _app(_Screen(_page(3000))), scroll: 500);
      expect(screen, built);
      expect(built[const ValueKey('head')]!.top, -500);
    });
  }

  testWidgets('the view resized under the app is the window either way', (t) async {
    t.view.devicePixelRatio = 2;
    t.view.physicalSize = const Size(780, 1688);
    addTearDown(t.view.reset);
    Future<Map<Key, Rect>> resized(Widget screen) async {
      t.view.physicalSize = const Size(780, 1688);
      await t.pumpWidget(_app(screen));
      await t.pumpAndSettle();
      t.view.physicalSize = const Size(2048, 1536);
      await t.pumpAndSettle();
      final rects = {for (final k in _keys) k: t.getRect(find.byKey(k))};
      await t.pumpWidget(const SizedBox());
      return rects;
    }

    final built = await resized(_Built(_page(200)));
    final screen = await resized(_Screen(_page(200)));
    expect(screen, built);
    expect(built[const ValueKey('page')]!.height, 768);
  });

  testWidgets('NEGATIVE: a screen put up in less than the whole view is held to the view', (t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(390, 844);
    addTearDown(t.view.reset);
    Widget inset(BuildContext context, Widget? child) =>
        Padding(padding: const EdgeInsets.only(top: 100), child: child);
    final built = await _rects(t, _app(_Built(_page(200)), host: inset));
    final screen = await _rects(t, _app(_Screen(_page(200)), host: inset));
    expect(built[const ValueKey('page')]!.height, 744);
    expect(screen[const ValueKey('page')]!.height, 844);
  });
}
