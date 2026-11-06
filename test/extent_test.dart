import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A page one window tall over content that runs out of it.
  Widget page(CustomClipper<Rect>? clipper) => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: DocumentExtent(
        child: SizedBox(
          width: 300,
          height: 100,
          child: ClipRect(
            clipper: clipper,
            child: const OverflowBox(
              minHeight: 0,
              maxHeight: double.infinity,
              alignment: Alignment.topLeft,
              child: SizedBox(width: 300, height: 500),
            ),
          ),
        ),
      ),
    ),
  );

  double extent(WidgetTester tester) => tester.getSize(find.byType(DocumentExtent)).height;

  // Each page laid out from nothing: a clipper swapped on a live tree
  // repaints the clip and asks the document for no new layout.
  Future<void> pump(WidgetTester tester, CustomClipper<Rect>? clipper) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(page(clipper));
  }

  testWidgets('a clip across the page lets the document run on down it (a news site, widen14)', (tester) async {
    // `overflow-x: clip` beside a `visible`: cut on the left and the right,
    // open above and below.
    await pump(tester, const InsetClip(px: EdgeInsets.only(top: -1e6, bottom: -1e6)));
    expect(extent(tester), 500);
    // A clip that opens part of the way down ends there.
    await pump(tester, const InsetClip(px: EdgeInsets.only(bottom: -150)));
    expect(extent(tester), 250);
  });

  testWidgets('NEGATIVE: a clip of the box itself ends the document at the box', (tester) async {
    await pump(tester, null);
    expect(extent(tester), 100);
    await pump(tester, const InsetClip(px: EdgeInsets.only(left: -50, right: -50)));
    expect(extent(tester), 100);
  });

  // `left: 40%; top: 90%`: a box as big as its block, carried that far.
  Widget placed(double dy, double label) => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: DocumentExtent(
        child: SizedBox(
          width: 300,
          height: 100,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: FractionalTranslation(
                  translation: Offset(0.4, dy),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(width: 20, height: label),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  testWidgets('a box placed by a share of its block counts, not the block it is carried in', (tester) async {
    await tester.pumpWidget(placed(0.9, 10));
    expect(extent(tester), 100);
    // What it places runs past the page's foot: the document goes on to it.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(placed(0.9, 30));
    expect(extent(tester), 120);
  });

  testWidgets('NEGATIVE: a box of its own carried past the foot still counts', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: DocumentExtent(
            child: SizedBox(
              width: 300,
              height: 100,
              child: Stack(
                clipBehavior: Clip.none,
                children: const [
                  Positioned.fill(
                    child: FractionalTranslation(
                      translation: Offset(0, 0.5),
                      child: ColoredBox(color: Color(0xFF000000)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(extent(tester), 150);
  });
}
