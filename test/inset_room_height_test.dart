// A HEIGHT ASKED AT A WIDTH IS THE HEIGHT LAID OUT THAT WIDE, so a share
// of a room inside is taken of that width (css-sizing-3 5.2.1: a
// percentage is cyclic only against a size still being worked out). A
// flex row whose items stretch to the tallest asks each its height at its
// width -- Flutter's `IntrinsicHeight` round a `Row` -- and a square made
// of `padding-bottom: 100%` came to nothing there. Every rect is Chrome's:
//
//   .row   { display: flex; gap: 8px; width: 408px }
//   .item  { flex: 1 }
//   .label { display: flex; align-items: flex-end; justify-content: center;
//            padding: 0 8px 12px }
//   .label::after { content: ''; padding-bottom: 100% }
//   .text  { width: 50px; height: 20px }
//
// <div class=row><div class=item><div class=label><span class=text>
// </div></div><div class=item><div style="height: 10px"></div></div></div>
//
// row 0,0 408x196; label 0,0 200x196; text 75,164 50x20.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';
import 'package:css_box/src/inset.dart' show RenderInset;

ValueKey<String> _k(String name) => ValueKey(name);

/// The label: padded `0 8px 12px`, a room for the square beside its text.
Widget _label({bool ofRoom = true}) => Padding(
  padding: const EdgeInsets.only(left: 8, right: 8, bottom: 12),
  child: Inset(
    key: _k('room'),
    insets: EdgeInsets.zero,
    room: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(child: SizedBox(key: _k('text'), width: 50, height: 20)),
        Inset(key: _k('square'), insets: EdgeInsets.zero, shares: const EdgeInsets.only(bottom: 1), ofRoom: ofRoom),
      ],
    ),
  ),
);

Widget _row({bool intrinsic = true, bool ofRoom = true}) {
  final row = Row(
    key: _k('row'),
    crossAxisAlignment: intrinsic ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
    spacing: 8,
    children: [
      Expanded(
        child: SizedBox(
          key: _k('label'),
          child: _label(ofRoom: ofRoom),
        ),
      ),
      Expanded(child: SizedBox(key: _k('other'), height: 10)),
    ],
  );
  return intrinsic ? IntrinsicHeight(child: row) : row;
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(600, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 408, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('a row stretched to its tallest item is as tall as the share of the room in it', (tester) async {
    await _pump(tester, _row());
    expect(tester.getRect(find.byKey(_k('row'))), const Rect.fromLTWH(0, 0, 408, 196));
    expect(tester.getRect(find.byKey(_k('label'))), const Rect.fromLTWH(0, 0, 200, 196));
    expect(tester.getRect(find.byKey(_k('text'))), const Rect.fromLTWH(75, 164, 50, 20));
    expect(tester.getSize(find.byKey(_k('other'))).height, 196);
  });

  testWidgets('laid out without being asked, the same', (tester) async {
    await _pump(tester, _row(intrinsic: false));
    expect(tester.getRect(find.byKey(_k('label'))), const Rect.fromLTWH(0, 0, 200, 196));
    expect(tester.getRect(find.byKey(_k('text'))), const Rect.fromLTWH(75, 164, 50, 20));
  });

  testWidgets('a room asked its height at two widths answers each of its own', (tester) async {
    await _pump(tester, _row(intrinsic: false));
    final room = tester.renderObject<RenderInset>(find.byKey(_k('room')));
    // The square asked the same question both times: its height at its own
    // width of nothing.
    expect(room.getMaxIntrinsicHeight(100), 100);
    expect(room.getMaxIntrinsicHeight(300), 300);
    expect(room.getMinIntrinsicHeight(120), 120);
    expect(room.getDryLayout(const BoxConstraints.tightFor(width: 150)).height, 150);
    expect(room.getDryLayout(const BoxConstraints.tightFor(width: 250)).height, 250);
  });

  testWidgets('what a layout offered is what the room keeps after a question at another width', (tester) async {
    await _pump(tester, _row(intrinsic: false));
    final room = tester.renderObject<RenderInset>(find.byKey(_k('room')));
    expect(room.getMaxIntrinsicHeight(100), 100);
    tester.renderObject<RenderInset>(find.byKey(_k('square'))).markNeedsLayout();
    await tester.pump();
    expect(tester.getSize(find.byKey(_k('square'))).height, 184);
    expect(tester.getRect(find.byKey(_k('label'))), const Rect.fromLTWH(0, 0, 200, 196));
  });

  testWidgets('a share of its own width is not a share of the room', (tester) async {
    // Without ofRoom the square is a share of its own width, nothing: the
    // row is as tall as the text and its padding.
    await _pump(tester, _row(ofRoom: false));
    expect(tester.getRect(find.byKey(_k('row'))), const Rect.fromLTWH(0, 0, 408, 32));
    expect(tester.getSize(find.byKey(_k('square'))).height, 0);
  });

  testWidgets('a box with no share asks as before, and keeps its answers', (tester) async {
    await _pump(
      tester,
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Inset(
                key: _k('plain'),
                insets: const EdgeInsets.all(5),
                room: true,
                child: const SizedBox(height: 40),
              ),
            ),
          ],
        ),
      ),
    );
    expect(tester.getSize(find.byKey(_k('plain'))).height, 50);
  });
}
