# css_box example

A gallery of every snippet in css_box's README, one card each, laid out at
320 wide. Each card is a function in `lib/snippets.dart`, keyed by the README
section it illustrates, such as these two:

```dart
Widget lineBox() =>
    const SizedBox(width: 48, child: LineBox(child: Text('Unbreakable word')));

Widget flexLine() => const FlexLine(
  spacing: 12,
  children: [
    FlexCell(child: Text('a headline that gives up room grudgingly')),
    FlexCell(
      shrink: 3,
      child: Text('a caption that gives up three times as much'),
    ),
    FlexCell(shrink: 0, child: Icon(Icons.chevron_right)),
  ],
);
```

Run the gallery:

```sh
flutter run
```

The tests pump every snippet (`test/snippets_test.dart`) and check that each
Dart block of css_box's README is one of them (`test/readme_test.dart`):

```sh
flutter test
```
