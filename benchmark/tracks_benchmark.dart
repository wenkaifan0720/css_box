// Tracks on a large page: 400 items on four tracks -- one as wide as its
// widest item, two sharing what is left, one fixed -- laid out again at a
// new width each run, beside Flutter's Table of the same cells, and the
// same grid with every tenth row's header spanning two tracks, which a
// Table cannot state.
//
//   flutter test benchmark/tracks_benchmark.dart
//
// Times are a debug build's (flutter test runs with assertions on): read
// them against each other, not as frame times.
import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bench.dart';
import 'words.dart';

const _rows = 100;

List<Widget> _cells({required bool spans}) => [
  for (var r = 0; r < _rows; r++) ...[
    if (spans && r % 10 == 0)
      TrackCell(columnSpan: 2, child: Text(sentence(6, seed: r)))
    else ...[
      Text(sentence(1 + r % 3, seed: r)),
      Text(sentence(4 + r % 7, seed: r + 1000)),
    ],
    Text(sentence(3 + r % 5, seed: r + 2000)),
    Text('${r * 7 % 100}'),
  ],
];

Widget _tracks({required bool spans}) => Tracks(
  columns: const [TrackSize.auto, TrackSize.flex(1), TrackSize.flex(2), TrackSize.fixed(80)],
  spacing: 8,
  runSpacing: 4,
  children: _cells(spans: spans),
);

Widget _table() => Table(
  columnWidths: const {
    0: IntrinsicColumnWidth(),
    1: FlexColumnWidth(1),
    2: FlexColumnWidth(2),
    3: FixedColumnWidth(80),
  },
  children: [
    for (var r = 0; r < _rows; r++)
      TableRow(
        children: [
          Text(sentence(1 + r % 3, seed: r)),
          Text(sentence(4 + r % 7, seed: r + 1000)),
          Text(sentence(3 + r % 5, seed: r + 2000)),
          Text('${r * 7 % 100}'),
        ],
      ),
  ],
);

void main() {
  testWidgets('Tracks: 400 items on four tracks, relaid at a new width', (tester) async {
    final times = await timePages(tester, {
      'Tracks, 400 items': _tracks(spans: false),
      'Table, the same 400 cells (stock)': _table(),
      'Tracks, 390 items, 10 spanning two tracks': _tracks(spans: true),
    });
    // ignore: avoid_print
    print(reportAll(times));
  });
}
