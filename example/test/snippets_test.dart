// Every snippet of the README lays out and paints with no error, in a
// column 320 wide as the gallery shows it, and the gallery itself does.
import 'package:css_box_example/main.dart';
import 'package:css_box_example/snippets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final MapEntry(key: name, value: build) in snippets.entries) {
    testWidgets('$name lays out and paints', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 320, child: build()),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the gallery shows every snippet by name', (tester) async {
    await tester.pumpWidget(const CssBoxGallery());
    expect(find.text('LineBox'), findsOneWidget);
    // The gallery's own list; some snippets scroll inside it.
    await tester.scrollUntilVisible(
      find.text('Width bands'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Width bands'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
