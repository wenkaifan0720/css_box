// FloatText and IndentedText tell a reader what a Text tells: the words,
// with each span's semanticsLabel in that span's place -- `Dr.` read as
// `Doctor` -- and a text that changes is told again.
import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: DefaultTextStyle(
    style: const TextStyle(fontSize: 10),
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 200, child: child),
    ),
  ),
);

const key = ValueKey('text');

void main() {
  testWidgets('FloatText tells a span by its semanticsLabel', (t) async {
    // The review's probe.
    final semantics = t.ensureSemantics();
    await t.pumpWidget(
      host(
        const FloatText(
          TextSpan(text: 'Dr.', semanticsLabel: 'Doctor'),
          key: key,
        ),
      ),
    );
    expect(t.getSemantics(find.byKey(key)).label, 'Doctor');
    semantics.dispose();
  });

  testWidgets('FloatText tells a labelled span in its place among the others', (t) async {
    final semantics = t.ensureSemantics();
    await t.pumpWidget(
      host(
        const FloatText(
          TextSpan(
            children: [
              TextSpan(text: 'Call '),
              TextSpan(text: 'Dr.', semanticsLabel: 'Doctor'),
              TextSpan(text: ' Who'),
            ],
          ),
          key: key,
        ),
      ),
    );
    expect(t.getSemantics(find.byKey(key)).label, 'Call Doctor Who');
    semantics.dispose();
  });

  testWidgets('IndentedText tells a span by its semanticsLabel', (t) async {
    final semantics = t.ensureSemantics();
    await t.pumpWidget(
      host(
        const IndentedText.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Call '),
              TextSpan(text: 'Dr.', semanticsLabel: 'Doctor'),
            ],
          ),
          key: key,
          indent: 8,
        ),
      ),
    );
    expect(t.getSemantics(find.byKey(key)).label, 'Call Doctor');
    semantics.dispose();
  });

  testWidgets('IndentedText tells its new words when its text changes', (t) async {
    final semantics = t.ensureSemantics();
    await t.pumpWidget(host(IndentedText('AAAA', key: key, indent: 8)));
    expect(t.getSemantics(find.byKey(key)).label, 'AAAA');
    await t.pumpWidget(host(IndentedText('BBBB', key: key, indent: 8)));
    expect(t.getSemantics(find.byKey(key)).label, 'BBBB');
    semantics.dispose();
  });

  testWidgets('NEGATIVE: FloatText with no labels tells its words, without the breaks it adds', (t) async {
    // A break after a hyphen between letters is a U+200B in the words laid
    // out; a reader is not told it.
    final semantics = t.ensureSemantics();
    await t.pumpWidget(host(const FloatText(TextSpan(text: 'a well-known name'), key: key)));
    expect(t.getSemantics(find.byKey(key)).label, 'a well-known name');
    await t.pumpWidget(host(const FloatText(TextSpan(text: 'BBBB'), key: key)));
    expect(t.getSemantics(find.byKey(key)).label, 'BBBB');
    semantics.dispose();
  });

  testWidgets('NEGATIVE: IndentedText with no labels tells its words', (t) async {
    final semantics = t.ensureSemantics();
    await t.pumpWidget(host(IndentedText('a well-known name', key: key, indent: 8)));
    expect(t.getSemantics(find.byKey(key)).label, 'a well-known name');
    semantics.dispose();
  });
}
