// GENERATED from taffy's grid fixtures as Chrome laid them out
// (taffy's grid_*.json fixtures at 1440x900): each grid rebuilt
// as the lowerer states one -- `Tracks` and `TrackCell` -- with every
// item's Ahem text a paragraph with Ahem's metrics, and every rect Chrome's.
//
// Only fixtures the test can state exactly are here: one absolutely
// positioned grid, left to right, items with nothing but Ahem text inside,
// lengths in px or %, no named lines, baselines, offsets or ratios, and a
// template short enough to write out -- 275 of taffy's 544 grid
// fixtures. 15 of them are left out:
// the engine itself is off Chrome there, and `Grid` comes out at the same
// numbers as `Tracks` (the grid-line limits of the `overlarge` fixtures,
// and one span over intrinsic tracks):
//   grid_grid_overlarge_auto_flow_after_max_row_item
//   grid_grid_overlarge_auto_flow_column_dense_extreme_row
//   grid_grid_overlarge_auto_flow_column_huge_row_span
//   grid_grid_overlarge_auto_placed_huge_span
//   grid_grid_overlarge_explicit_tracks_at_limit
//   grid_grid_overlarge_explicit_tracks_just_over_limit
//   grid_grid_overlarge_extreme_both_directions
//   grid_grid_overlarge_negative_span_from_negative_line
//   grid_grid_overlarge_negative_start_huge_span
//   grid_grid_overlarge_placement_at_negative_limit
//   grid_grid_overlarge_placement_just_past_limit
//   grid_grid_overlarge_row_span_overflows_positive_limit
//   grid_grid_overlarge_span_overflow_secondary_axis
//   grid_grid_overlarge_span_overflows_negative_limit
//   grid_xgrid_span_2_max_content_minmax_max_content_min_content_indefinite
//
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

/// A paragraph of Ahem at `font-size: 10px; line-height: 1`, which is every
/// taffy fixture's text: every glyph a 10px square, lines 10px apart,
/// broken only at the zero-width spaces between the words.
class _Ahem extends LeafRenderObjectWidget {
  const _Ahem(this.text, {super.key});
  final String text;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderAhem(text.isEmpty ? const [] : text.split('​'));
}

class _RenderAhem extends RenderBox {
  _RenderAhem(this.words);
  final List<String> words;

  double get _min => words.fold(0.0, (a, w) => math.max(a, w.length * 10.0));
  double get _max => words.fold(0.0, (a, w) => a + w.length * 10.0);

  /// Lines at [width], greedily, a word too long for it on a line of its own.
  int _lines(double width) {
    if (words.isEmpty) return 0;
    var lines = 1;
    var at = 0.0;
    for (final w in words) {
      final len = w.length * 10.0;
      if (at > 0 && at + len > width + 1e-6) {
        lines++;
        at = len;
      } else {
        at += len;
      }
    }
    return lines;
  }

  Size _size(BoxConstraints c) {
    final w = c.constrainWidth(c.hasBoundedWidth ? c.maxWidth : _max);
    return c.constrain(Size(w, _lines(w) * 10.0));
  }

  @override
  double computeMinIntrinsicWidth(double height) => _min;
  @override
  double computeMaxIntrinsicWidth(double height) => _max;
  @override
  double computeMinIntrinsicHeight(double width) => _lines(width) * 10.0;
  @override
  double computeMaxIntrinsicHeight(double width) => _lines(width) * 10.0;
  @override
  Size computeDryLayout(BoxConstraints constraints) => _size(constraints);
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => words.isEmpty ? null : 8;
  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) => words.isEmpty ? null : 8;
  @override
  void performLayout() => size = _size(constraints);
}

/// An absolutely positioned box at the viewport's left edge: its own size
/// where it states one, and `fit-content` against the viewport where it
/// does not (CSS 2.1 10.3.7) -- the min-content and max-content the grid
/// answers, clamped by the 1440 it has.
class _FitContent extends SingleChildRenderObjectWidget {
  const _FitContent({super.child});
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFitContent();
}

class _RenderFitContent extends RenderProxyBox {
  @override
  void performLayout() {
    final c = child!;
    final w = math.min(
      c.getMaxIntrinsicWidth(double.infinity),
      math.max(c.getMinIntrinsicWidth(double.infinity), 1440.0),
    );
    c.layout(BoxConstraints.tightFor(width: w), parentUsesSize: true);
    size = c.size;
  }
}

/// Item [key]'s box, holding Ahem [text].
Widget _a(String key, [String text = '']) => _Ahem(text, key: ValueKey(key));

Widget _grid({double? width, double? height, required EdgeInsets frame, required Tracks tracks}) {
  Widget box = SizedBox(
    key: const ValueKey('root'),
    width: width,
    height: height,
    child: Padding(padding: frame, child: tracks),
  );
  if (width == null) box = _FitContent(child: box);
  // Clipped: a grid wider than the viewport is measured, not reported.
  return UnconstrainedBox(alignment: Alignment.topLeft, clipBehavior: Clip.hardEdge, child: box);
}

/// `--dart-define=REPORT=true` prints every box's distance from Chrome's.
const _report = bool.fromEnvironment('REPORT');

/// Chrome lays boxes out in 1/64 px; the grid, in doubles.
const _tolerance = 0.05;

void main() {
  for (final (name, build, expected) in _cases) {
    testWidgets(name, (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: build()));
      final origin = tester.getTopLeft(find.byKey(const ValueKey('root')));
      final off = <String>[];
      for (final MapEntry(:key, :value) in expected.entries) {
        final got = tester.getRect(find.byKey(ValueKey(key))).shift(-origin);
        final d = [
          got.left - value.left,
          got.top - value.top,
          got.width - value.width,
          got.height - value.height,
        ].map((x) => x.abs()).reduce(math.max);
        // ignore: avoid_print
        if (_report) print('TRACKS-CHROME $name $key ${d.toStringAsFixed(4)}');
        if (d > _tolerance) off.add('$key: tracks $got, Chrome $value');
      }
      expect(off, isEmpty);
    });
  }
}

final _cases = <(String, Widget Function(), Map<String, Rect>)>[
  (
    'grid_grid_align_content_center',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        alignContent: TrackContent.center,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(0, 40, 40, 40),
      '1': Rect.fromLTWH(40, 40, 40, 40),
      '2': Rect.fromLTWH(80, 40, 40, 40),
      '3': Rect.fromLTWH(0, 80, 40, 40),
      '4': Rect.fromLTWH(40, 80, 40, 40),
      '5': Rect.fromLTWH(80, 80, 40, 40),
      '6': Rect.fromLTWH(0, 120, 40, 40),
      '7': Rect.fromLTWH(40, 120, 40, 40),
      '8': Rect.fromLTWH(80, 120, 40, 40),
    },
  ),
  (
    'grid_grid_align_content_end',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        alignContent: TrackContent.end,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(0, 80, 40, 40),
      '1': Rect.fromLTWH(40, 80, 40, 40),
      '2': Rect.fromLTWH(80, 80, 40, 40),
      '3': Rect.fromLTWH(0, 120, 40, 40),
      '4': Rect.fromLTWH(40, 120, 40, 40),
      '5': Rect.fromLTWH(80, 120, 40, 40),
      '6': Rect.fromLTWH(0, 160, 40, 40),
      '7': Rect.fromLTWH(40, 160, 40, 40),
      '8': Rect.fromLTWH(80, 160, 40, 40),
    },
  ),
  (
    'grid_grid_align_content_end_with_padding_border',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.fromLTRB(48, 12, 24, 36),
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        alignContent: TrackContent.end,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(48, 44, 40, 40),
      '1': Rect.fromLTWH(88, 44, 40, 40),
      '2': Rect.fromLTWH(128, 44, 40, 40),
      '3': Rect.fromLTWH(48, 84, 40, 40),
      '4': Rect.fromLTWH(88, 84, 40, 40),
      '5': Rect.fromLTWH(128, 84, 40, 40),
      '6': Rect.fromLTWH(48, 124, 40, 40),
      '7': Rect.fromLTWH(88, 124, 40, 40),
      '8': Rect.fromLTWH(128, 124, 40, 40),
    },
  ),
  (
    'grid_grid_align_content_space_around',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        alignContent: TrackContent.spaceAround,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(0, 13.33, 40, 40),
      '1': Rect.fromLTWH(40, 13.33, 40, 40),
      '2': Rect.fromLTWH(80, 13.33, 40, 40),
      '3': Rect.fromLTWH(0, 79.98, 40, 40),
      '4': Rect.fromLTWH(40, 79.98, 40, 40),
      '5': Rect.fromLTWH(80, 79.98, 40, 40),
      '6': Rect.fromLTWH(0, 146.64, 40, 40),
      '7': Rect.fromLTWH(40, 146.64, 40, 40),
      '8': Rect.fromLTWH(80, 146.64, 40, 40),
    },
  ),
  (
    'grid_grid_align_content_space_around_with_padding_border',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.fromLTRB(48, 12, 24, 36),
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        alignContent: TrackContent.spaceAround,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(48, 17.33, 40, 40),
      '1': Rect.fromLTWH(88, 17.33, 40, 40),
      '2': Rect.fromLTWH(128, 17.33, 40, 40),
      '3': Rect.fromLTWH(48, 67.98, 40, 40),
      '4': Rect.fromLTWH(88, 67.98, 40, 40),
      '5': Rect.fromLTWH(128, 67.98, 40, 40),
      '6': Rect.fromLTWH(48, 118.64, 40, 40),
      '7': Rect.fromLTWH(88, 118.64, 40, 40),
      '8': Rect.fromLTWH(128, 118.64, 40, 40),
    },
  ),
  (
    'grid_grid_align_content_space_between',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        alignContent: TrackContent.spaceBetween,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 40, 40),
      '2': Rect.fromLTWH(80, 0, 40, 40),
      '3': Rect.fromLTWH(0, 80, 40, 40),
      '4': Rect.fromLTWH(40, 80, 40, 40),
      '5': Rect.fromLTWH(80, 80, 40, 40),
      '6': Rect.fromLTWH(0, 160, 40, 40),
      '7': Rect.fromLTWH(40, 160, 40, 40),
      '8': Rect.fromLTWH(80, 160, 40, 40),
    },
  ),
  (
    'grid_grid_align_content_space_between_with_padding_border',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.fromLTRB(48, 12, 24, 36),
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        alignContent: TrackContent.spaceBetween,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(48, 12, 40, 40),
      '1': Rect.fromLTWH(88, 12, 40, 40),
      '2': Rect.fromLTWH(128, 12, 40, 40),
      '3': Rect.fromLTWH(48, 68, 40, 40),
      '4': Rect.fromLTWH(88, 68, 40, 40),
      '5': Rect.fromLTWH(128, 68, 40, 40),
      '6': Rect.fromLTWH(48, 124, 40, 40),
      '7': Rect.fromLTWH(88, 124, 40, 40),
      '8': Rect.fromLTWH(128, 124, 40, 40),
    },
  ),
  (
    'grid_grid_align_content_space_evenly',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        alignContent: TrackContent.spaceEvenly,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(0, 20, 40, 40),
      '1': Rect.fromLTWH(40, 20, 40, 40),
      '2': Rect.fromLTWH(80, 20, 40, 40),
      '3': Rect.fromLTWH(0, 80, 40, 40),
      '4': Rect.fromLTWH(40, 80, 40, 40),
      '5': Rect.fromLTWH(80, 80, 40, 40),
      '6': Rect.fromLTWH(0, 140, 40, 40),
      '7': Rect.fromLTWH(40, 140, 40, 40),
      '8': Rect.fromLTWH(80, 140, 40, 40),
    },
  ),
  (
    'grid_grid_align_content_space_evenly_with_padding_border',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.fromLTRB(48, 12, 24, 36),
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        alignContent: TrackContent.spaceEvenly,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(48, 20, 40, 40),
      '1': Rect.fromLTWH(88, 20, 40, 40),
      '2': Rect.fromLTWH(128, 20, 40, 40),
      '3': Rect.fromLTWH(48, 68, 40, 40),
      '4': Rect.fromLTWH(88, 68, 40, 40),
      '5': Rect.fromLTWH(128, 68, 40, 40),
      '6': Rect.fromLTWH(48, 116, 40, 40),
      '7': Rect.fromLTWH(88, 116, 40, 40),
      '8': Rect.fromLTWH(128, 116, 40, 40),
    },
  ),
  (
    'grid_grid_align_content_start',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        alignContent: TrackContent.start,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 40, 40),
      '2': Rect.fromLTWH(80, 0, 40, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 40, 40, 40),
      '5': Rect.fromLTWH(80, 40, 40, 40),
      '6': Rect.fromLTWH(0, 80, 40, 40),
      '7': Rect.fromLTWH(40, 80, 40, 40),
      '8': Rect.fromLTWH(80, 80, 40, 40),
    },
  ),
  (
    'grid_grid_align_content_start_with_padding_border',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.fromLTRB(48, 12, 24, 36),
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        alignContent: TrackContent.start,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(48, 12, 40, 40),
      '1': Rect.fromLTWH(88, 12, 40, 40),
      '2': Rect.fromLTWH(128, 12, 40, 40),
      '3': Rect.fromLTWH(48, 52, 40, 40),
      '4': Rect.fromLTWH(88, 52, 40, 40),
      '5': Rect.fromLTWH(128, 52, 40, 40),
      '6': Rect.fromLTWH(48, 92, 40, 40),
      '7': Rect.fromLTWH(88, 92, 40, 40),
      '8': Rect.fromLTWH(128, 92, 40, 40),
    },
  ),
  (
    'grid_grid_align_items_sized_center',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        align: CellAlign.center,
        children: [
          TrackCell(column: 0, row: 0, width: 20, height: 20, child: _a('0')),
          TrackCell(column: 2, row: 2, width: 60, height: 60, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 120, 120), '0': Rect.fromLTWH(0, 10, 20, 20), '1': Rect.fromLTWH(80, 70, 60, 60)},
  ),
  (
    'grid_grid_align_items_sized_end',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        align: CellAlign.end,
        children: [
          TrackCell(column: 0, row: 0, width: 20, height: 20, child: _a('0')),
          TrackCell(column: 2, row: 2, width: 60, height: 60, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 120, 120), '0': Rect.fromLTWH(0, 20, 20, 20), '1': Rect.fromLTWH(80, 60, 60, 60)},
  ),
  (
    'grid_grid_align_items_sized_start',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        align: CellAlign.start,
        children: [
          TrackCell(column: 0, row: 0, width: 20, height: 20, child: _a('0')),
          TrackCell(column: 2, row: 2, width: 60, height: 60, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 120, 120), '0': Rect.fromLTWH(0, 0, 20, 20), '1': Rect.fromLTWH(80, 80, 60, 60)},
  ),
  (
    'grid_grid_align_items_sized_stretch',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(column: 0, row: 0, width: 20, height: 20, child: _a('0')),
          TrackCell(column: 2, row: 2, width: 60, height: 60, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 120, 120), '0': Rect.fromLTWH(0, 0, 20, 20), '1': Rect.fromLTWH(80, 80, 60, 60)},
  ),
  (
    'grid_grid_align_self_sized_all',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(width: 20, height: 20, align: CellAlign.start, child: _a('0')),
          TrackCell(width: 60, height: 60, align: CellAlign.start, child: _a('1')),
          TrackCell(width: 20, height: 20, align: CellAlign.end, child: _a('2')),
          TrackCell(width: 60, height: 60, align: CellAlign.end, child: _a('3')),
          TrackCell(width: 20, height: 20, align: CellAlign.center, child: _a('4')),
          TrackCell(width: 60, height: 60, align: CellAlign.center, child: _a('5')),
          TrackCell(width: 20, height: 20, align: CellAlign.stretch, child: _a('6')),
          TrackCell(width: 60, height: 60, align: CellAlign.stretch, child: _a('7')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(0, 0, 20, 20),
      '1': Rect.fromLTWH(40, 0, 60, 60),
      '2': Rect.fromLTWH(80, 20, 20, 20),
      '3': Rect.fromLTWH(0, 20, 60, 60),
      '4': Rect.fromLTWH(40, 50, 20, 20),
      '5': Rect.fromLTWH(80, 30, 60, 60),
      '6': Rect.fromLTWH(0, 80, 20, 20),
      '7': Rect.fromLTWH(40, 80, 60, 60),
    },
  ),
  (
    'grid_grid_auto_columns',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(100)],
        flow: TrackFlow.column,
        autoColumns: const [TrackSize.fixed(10), TrackSize.fixed(20), TrackSize.fixed(30)],
        children: [
          TrackCell(column: -2, child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 190, 100),
      '0': Rect.fromLTWH(0, 0, 30, 100),
      '1': Rect.fromLTWH(30, 0, 40, 100),
      '2': Rect.fromLTWH(70, 0, 10, 100),
      '3': Rect.fromLTWH(80, 0, 20, 100),
      '4': Rect.fromLTWH(100, 0, 30, 100),
      '5': Rect.fromLTWH(130, 0, 10, 100),
      '6': Rect.fromLTWH(140, 0, 20, 100),
      '7': Rect.fromLTWH(160, 0, 30, 100),
    },
  ),
  (
    'grid_grid_auto_columns_fixed_width',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.auto, TrackSize.fixed(40), TrackSize.auto],
        rows: const [TrackSize.fixed(40), TrackSize.auto, TrackSize.fixed(40), TrackSize.auto],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
          TrackCell(child: _a('9')),
          TrackCell(child: _a('10')),
          TrackCell(child: _a('11')),
          TrackCell(child: _a('12')),
          TrackCell(child: _a('13')),
          TrackCell(child: _a('14')),
          TrackCell(child: _a('15')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 60, 40),
      '2': Rect.fromLTWH(100, 0, 40, 40),
      '3': Rect.fromLTWH(140, 0, 60, 40),
      '4': Rect.fromLTWH(0, 40, 40, 60),
      '5': Rect.fromLTWH(40, 40, 60, 60),
      '6': Rect.fromLTWH(100, 40, 40, 60),
      '7': Rect.fromLTWH(140, 40, 60, 60),
      '8': Rect.fromLTWH(0, 100, 40, 40),
      '9': Rect.fromLTWH(40, 100, 60, 40),
      '10': Rect.fromLTWH(100, 100, 40, 40),
      '11': Rect.fromLTWH(140, 100, 60, 40),
      '12': Rect.fromLTWH(0, 140, 40, 60),
      '13': Rect.fromLTWH(40, 140, 60, 60),
      '14': Rect.fromLTWH(100, 140, 40, 60),
      '15': Rect.fromLTWH(140, 140, 60, 60),
    },
  ),
  (
    'grid_grid_auto_fill_fixed_size',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.fixed(40),
          TrackSize.fill([TrackSize.fixed(40)]),
        ],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 40, 40),
      '2': Rect.fromLTWH(80, 0, 40, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 40, 40, 40),
      '5': Rect.fromLTWH(80, 40, 40, 40),
      '6': Rect.fromLTWH(0, 80, 40, 40),
      '7': Rect.fromLTWH(40, 80, 40, 40),
      '8': Rect.fromLTWH(80, 80, 40, 40),
    },
  ),
  (
    'grid_grid_auto_fill_with_empty_auto_track',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.fill([TrackSize.fixed(40)]),
        ],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        justifyContent: TrackContent.spaceEvenly,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 120, 120), '0': Rect.fromLTWH(0, 0, 40, 40), '1': Rect.fromLTWH(40, 0, 40, 40)},
  ),
  (
    'grid_grid_auto_fit_with_empty_auto_track',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.fit([TrackSize.fixed(40)]),
        ],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        justifyContent: TrackContent.spaceEvenly,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 120, 120), '0': Rect.fromLTWH(13.33, 0, 40, 40), '1': Rect.fromLTWH(66.66, 0, 40, 40)},
  ),
  (
    'grid_grid_auto_rows',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(100)],
        rows: const [TrackSize.fixed(40)],
        autoRows: const [TrackSize.fixed(10), TrackSize.fixed(20), TrackSize.fixed(30)],
        children: [
          TrackCell(row: -3, child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 100, 180),
      '0': Rect.fromLTWH(0, 0, 100, 20),
      '1': Rect.fromLTWH(0, 20, 100, 30),
      '2': Rect.fromLTWH(0, 50, 100, 40),
      '3': Rect.fromLTWH(0, 90, 100, 10),
      '4': Rect.fromLTWH(0, 100, 100, 20),
      '5': Rect.fromLTWH(0, 120, 100, 30),
      '6': Rect.fromLTWH(0, 150, 100, 10),
      '7': Rect.fromLTWH(0, 160, 100, 20),
    },
  ),
  (
    'grid_grid_auto_single_item',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.auto, TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(width: 100, child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 180, 120),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 100, 40),
      '2': Rect.fromLTWH(140, 0, 40, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 40, 100, 40),
      '5': Rect.fromLTWH(140, 40, 40, 40),
      '6': Rect.fromLTWH(0, 80, 40, 40),
      '7': Rect.fromLTWH(40, 80, 100, 40),
      '8': Rect.fromLTWH(140, 80, 40, 40),
    },
  ),
  (
    'grid_grid_auto_single_item_fixed_width',
    () => _grid(
      width: 200,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.auto, TrackSize.auto],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(minWidth: 100, child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 120),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 130, 40),
      '2': Rect.fromLTWH(170, 0, 30, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 40, 130, 40),
      '5': Rect.fromLTWH(170, 40, 30, 40),
      '6': Rect.fromLTWH(0, 80, 40, 40),
      '7': Rect.fromLTWH(40, 80, 130, 40),
      '8': Rect.fromLTWH(170, 80, 30, 40),
    },
  ),
  (
    'grid_grid_auto_single_item_fixed_width_with_definite_width',
    () => _grid(
      width: 200,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.auto, TrackSize.auto],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(width: 100, child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 120),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 100, 40),
      '2': Rect.fromLTWH(170, 0, 30, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 40, 130, 40),
      '5': Rect.fromLTWH(170, 40, 30, 40),
      '6': Rect.fromLTWH(0, 80, 40, 40),
      '7': Rect.fromLTWH(40, 80, 130, 40),
      '8': Rect.fromLTWH(170, 80, 30, 40),
    },
  ),
  (
    'grid_grid_auto_takes_precedence_over_fr',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.auto, TrackSize.flex(1)],
        rows: const [TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 200, 200), '0': Rect.fromLTWH(0, 0, 0, 40), '1': Rect.fromLTWH(0, 0, 200, 40)},
  ),
  (
    'grid_grid_basic',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 40, 40),
      '2': Rect.fromLTWH(80, 0, 40, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 40, 40, 40),
      '5': Rect.fromLTWH(80, 40, 40, 40),
      '6': Rect.fromLTWH(0, 80, 40, 40),
      '7': Rect.fromLTWH(40, 80, 40, 40),
      '8': Rect.fromLTWH(80, 80, 40, 40),
    },
  ),
  (
    'grid_grid_basic_implicit_tracks',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(width: 35, height: 35, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 40, 75), '0': Rect.fromLTWH(0, 0, 40, 40), '1': Rect.fromLTWH(0, 40, 35, 35)},
  ),
  (
    'grid_grid_basic_with_overflow',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
          TrackCell(child: _a('9')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 40, 40),
      '2': Rect.fromLTWH(80, 0, 40, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 40, 40, 40),
      '5': Rect.fromLTWH(80, 40, 40, 40),
      '6': Rect.fromLTWH(0, 80, 40, 40),
      '7': Rect.fromLTWH(40, 80, 40, 40),
      '8': Rect.fromLTWH(80, 80, 40, 40),
      '9': Rect.fromLTWH(0, 120, 40, 0),
    },
  ),
  (
    'grid_grid_basic_with_padding',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.fromLTRB(40, 10, 20, 30),
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 180, 160),
      '0': Rect.fromLTWH(40, 10, 40, 40),
      '1': Rect.fromLTWH(80, 10, 40, 40),
      '2': Rect.fromLTWH(120, 10, 40, 40),
      '3': Rect.fromLTWH(40, 50, 40, 40),
      '4': Rect.fromLTWH(80, 50, 40, 40),
      '5': Rect.fromLTWH(120, 50, 40, 40),
      '6': Rect.fromLTWH(40, 90, 40, 40),
      '7': Rect.fromLTWH(80, 90, 40, 40),
      '8': Rect.fromLTWH(120, 90, 40, 40),
    },
  ),
  (
    'grid_grid_content_sized_columns_max_content_and_max_content_fixed_and_max_content',
    () => _grid(
      width: 300,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.maxContent,
          TrackSize.between(TrackSize.maxContent, TrackSize.fixed(20)),
          TrackSize.maxContent,
        ],
        children: [
          TrackCell(column: 0, row: 0, child: _a('0', 'X\u200bX\u200bX\u200bX\u200bX')),
          TrackCell(column: 2, row: 0, child: _a('1', 'X\u200bX\u200bX')),
          TrackCell(
            column: 0,
            row: 0,
            columnEnd: -1,
            child: _a('2', 'XX\u200bXX\u200bXX\u200bXX\u200bXX\u200bXX\u200bXX'),
          ),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 300, 10),
      '0': Rect.fromLTWH(0, 0, 70, 10),
      '1': Rect.fromLTWH(90, 0, 50, 10),
      '2': Rect.fromLTWH(0, 0, 140, 10),
    },
  ),
  (
    'grid_grid_fit_content_percent_definite_argument',
    () => _grid(
      width: 60,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.upToFraction(0.5)],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HH\u200bHH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 60, 40), '0': Rect.fromLTWH(0, 0, 30, 40)},
  ),
  (
    'grid_grid_fit_content_percent_definite_max_content',
    () => _grid(
      width: 60,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.upToFraction(0.5)],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 60, 40), '0': Rect.fromLTWH(0, 0, 20, 40)},
  ),
  (
    'grid_grid_fit_content_percent_definite_min_content',
    () => _grid(
      width: 60,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.upToFraction(0.5)],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HHHH\u200bHH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 60, 40), '0': Rect.fromLTWH(0, 0, 40, 40)},
  ),
  (
    'grid_grid_fit_content_percent_indefinite_argument',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.upToFraction(0.5)],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HH\u200bHH\u200bHH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 60, 40), '0': Rect.fromLTWH(0, 0, 30, 40)},
  ),
  (
    'grid_grid_fit_content_percent_indefinite_max_content',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.upToFraction(0.5)],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 20, 40), '0': Rect.fromLTWH(0, 0, 20, 40)},
  ),
  (
    'grid_grid_fit_content_percent_indefinite_max_content_hidden',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.upToFraction(0.5)],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(clips: true, child: _a('0', 'HH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 20, 40), '0': Rect.fromLTWH(0, 0, 10, 40)},
  ),
  (
    'grid_grid_fit_content_percent_indefinite_min_content',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.upToFraction(0.5)],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HHHH\u200bHH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 60, 40), '0': Rect.fromLTWH(0, 0, 40, 40)},
  ),
  (
    'grid_grid_fit_content_percent_indefinite_min_content_hidden',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.upToFraction(0.5)],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(clips: true, child: _a('0', 'HHHH\u200bHH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 60, 40), '0': Rect.fromLTWH(0, 0, 30, 40)},
  ),
  (
    'grid_grid_fit_content_points_argument',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.upTo(30)],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HH\u200bHH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 30, 40), '0': Rect.fromLTWH(0, 0, 30, 40)},
  ),
  (
    'grid_grid_fit_content_points_max_content',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.upTo(30)],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 20, 40), '0': Rect.fromLTWH(0, 0, 20, 40)},
  ),
  (
    'grid_grid_fit_content_points_min_content',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.upTo(30)],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HHHH\u200bHH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 40, 40), '0': Rect.fromLTWH(0, 0, 40, 40)},
  ),
  (
    'grid_grid_fit_content_points_min_content_hidden',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.upTo(30)],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(clips: true, child: _a('0', 'HHHH\u200bHH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 30, 40), '0': Rect.fromLTWH(0, 0, 30, 40)},
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span1_0fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.flex(0)],
        rows: const [TrackSize.flex(0)],
        children: [
          TrackCell(column: 0, row: 0, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 50, 50), '0': Rect.fromLTWH(3, 3, 100, 100), '1': Rect.fromLTWH(3, 3, 100, 100)},
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span1_1fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.flex(1)],
        rows: const [TrackSize.flex(1)],
        children: [
          TrackCell(column: 0, row: 0, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 50, 50), '0': Rect.fromLTWH(3, 3, 100, 100), '1': Rect.fromLTWH(3, 3, 100, 100)},
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span1_2fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.flex(2)],
        rows: const [TrackSize.flex(2)],
        children: [
          TrackCell(column: 0, row: 0, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 50, 50), '0': Rect.fromLTWH(3, 3, 100, 100), '1': Rect.fromLTWH(3, 3, 100, 100)},
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span1_minmax_0_0fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.fixed(0), TrackSize.flex(0))],
        rows: const [TrackSize.between(TrackSize.fixed(0), TrackSize.flex(0))],
        children: [
          TrackCell(column: 0, row: 0, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 50, 50), '0': Rect.fromLTWH(3, 3, 100, 100), '1': Rect.fromLTWH(3, 3, 0, 0)},
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span1_minmax_0_0point5fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.fixed(0), TrackSize.flex(0.5))],
        rows: const [TrackSize.between(TrackSize.fixed(0), TrackSize.flex(0.5))],
        children: [
          TrackCell(column: 0, row: 0, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 50, 50), '0': Rect.fromLTWH(3, 3, 100, 100), '1': Rect.fromLTWH(3, 3, 22, 22)},
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span1_minmax_0_1fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1))],
        rows: const [TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1))],
        children: [
          TrackCell(column: 0, row: 0, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 50, 50), '0': Rect.fromLTWH(3, 3, 100, 100), '1': Rect.fromLTWH(3, 3, 44, 44)},
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span1_minmax_0_2fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.fixed(0), TrackSize.flex(2))],
        rows: const [TrackSize.between(TrackSize.fixed(0), TrackSize.flex(2))],
        children: [
          TrackCell(column: 0, row: 0, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 50, 50), '0': Rect.fromLTWH(3, 3, 100, 100), '1': Rect.fromLTWH(3, 3, 44, 44)},
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span1_minmax_75px_1fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.fixed(75), TrackSize.flex(1))],
        rows: const [TrackSize.between(TrackSize.fixed(75), TrackSize.flex(1))],
        children: [
          TrackCell(column: 0, row: 0, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 50, 50), '0': Rect.fromLTWH(3, 3, 100, 100), '1': Rect.fromLTWH(3, 3, 75, 75)},
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span2_0fr_0fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.flex(0), TrackSize.flex(0)],
        rows: const [TrackSize.flex(0), TrackSize.flex(0)],
        children: [
          TrackCell(column: 0, row: 0, columnSpan: 2, rowSpan: 2, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 100, 100),
      '1': Rect.fromLTWH(3, 3, 50, 50),
      '2': Rect.fromLTWH(53, 53, 50, 50),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span2_0fr_0fr_1fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.flex(0), TrackSize.flex(0), TrackSize.flex(1)],
        rows: const [TrackSize.flex(0), TrackSize.flex(0), TrackSize.flex(1)],
        children: [
          TrackCell(column: 0, row: 0, columnSpan: 2, rowSpan: 2, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
          TrackCell(column: 2, row: 2, child: _a('3')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 100, 100),
      '1': Rect.fromLTWH(3, 3, 50, 50),
      '2': Rect.fromLTWH(53, 53, 50, 50),
      '3': Rect.fromLTWH(103, 103, 0, 0),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span2_0fr_1fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.flex(0), TrackSize.flex(1)],
        rows: const [TrackSize.flex(0), TrackSize.flex(1)],
        children: [
          TrackCell(column: 0, row: 0, columnSpan: 2, rowSpan: 2, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 100, 100),
      '1': Rect.fromLTWH(3, 3, 0, 0),
      '2': Rect.fromLTWH(3, 3, 100, 100),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span2_0fr_auto',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.flex(0), TrackSize.auto],
        rows: const [TrackSize.flex(0), TrackSize.auto],
        children: [
          TrackCell(column: 0, row: 0, columnSpan: 2, rowSpan: 2, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 100, 100),
      '1': Rect.fromLTWH(3, 3, 100, 100),
      '2': Rect.fromLTWH(103, 103, 0, 0),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span2_0fr_minmax_0_0fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.flex(0), TrackSize.between(TrackSize.fixed(0), TrackSize.flex(0))],
        rows: const [TrackSize.flex(0), TrackSize.between(TrackSize.fixed(0), TrackSize.flex(0))],
        children: [
          TrackCell(column: 0, row: 0, columnSpan: 2, rowSpan: 2, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 100, 100),
      '1': Rect.fromLTWH(3, 3, 100, 100),
      '2': Rect.fromLTWH(103, 103, 0, 0),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span2_0fr_minmax_0_1fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.flex(0), TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1))],
        rows: const [TrackSize.flex(0), TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1))],
        children: [
          TrackCell(column: 0, row: 0, columnSpan: 2, rowSpan: 2, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 100, 100),
      '1': Rect.fromLTWH(3, 3, 100, 100),
      '2': Rect.fromLTWH(103, 103, 0, 0),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span2_1fr_0fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.flex(1), TrackSize.flex(0)],
        rows: const [TrackSize.flex(1), TrackSize.flex(0)],
        children: [
          TrackCell(column: 0, row: 0, columnSpan: 2, rowSpan: 2, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 100, 100),
      '1': Rect.fromLTWH(3, 3, 100, 100),
      '2': Rect.fromLTWH(103, 103, 0, 0),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span2_1fr_1fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.flex(1), TrackSize.flex(1)],
        rows: const [TrackSize.flex(1), TrackSize.flex(1)],
        children: [
          TrackCell(column: 0, row: 0, columnSpan: 2, rowSpan: 2, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 100, 100),
      '1': Rect.fromLTWH(3, 3, 50, 50),
      '2': Rect.fromLTWH(53, 53, 50, 50),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span2_1fr_3fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.flex(1), TrackSize.flex(3)],
        rows: const [TrackSize.flex(1), TrackSize.flex(3)],
        children: [
          TrackCell(column: 0, row: 0, columnSpan: 2, rowSpan: 2, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 100, 100),
      '1': Rect.fromLTWH(3, 3, 25, 25),
      '2': Rect.fromLTWH(28, 28, 75, 75),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span2_1fr_auto',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.flex(1), TrackSize.auto],
        rows: const [TrackSize.flex(1), TrackSize.auto],
        children: [
          TrackCell(column: 0, row: 0, columnSpan: 2, rowSpan: 2, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 100, 100),
      '1': Rect.fromLTWH(3, 3, 100, 100),
      '2': Rect.fromLTWH(103, 103, 0, 0),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span2_1fr_max_content',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.flex(1), TrackSize.maxContent],
        rows: const [TrackSize.flex(1), TrackSize.maxContent],
        children: [
          TrackCell(column: 0, row: 0, columnSpan: 2, rowSpan: 2, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 100, 100),
      '1': Rect.fromLTWH(3, 3, 100, 100),
      '2': Rect.fromLTWH(103, 103, 0, 0),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span2_1fr_minmax_0_1fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.flex(1), TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1))],
        rows: const [TrackSize.flex(1), TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1))],
        children: [
          TrackCell(column: 0, row: 0, columnSpan: 2, rowSpan: 2, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 100, 100),
      '1': Rect.fromLTWH(3, 3, 100, 100),
      '2': Rect.fromLTWH(103, 103, 0, 0),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span2_1fr_minmax_25px_1fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.flex(1), TrackSize.between(TrackSize.fixed(25), TrackSize.flex(1))],
        rows: const [TrackSize.flex(1), TrackSize.between(TrackSize.fixed(25), TrackSize.flex(1))],
        children: [
          TrackCell(column: 0, row: 0, columnSpan: 2, rowSpan: 2, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 100, 100),
      '1': Rect.fromLTWH(3, 3, 75, 75),
      '2': Rect.fromLTWH(78, 78, 25, 25),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span2_minmax_0_0fr_auto',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.fixed(0), TrackSize.flex(0)), TrackSize.auto],
        rows: const [TrackSize.between(TrackSize.fixed(0), TrackSize.flex(0)), TrackSize.auto],
        children: [
          TrackCell(column: 0, row: 0, columnSpan: 2, rowSpan: 2, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 100, 100),
      '1': Rect.fromLTWH(3, 3, 0, 0),
      '2': Rect.fromLTWH(3, 3, 44, 44),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span2_minmax_0_0fr_minmax_0_0fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [
          TrackSize.between(TrackSize.fixed(0), TrackSize.flex(0)),
          TrackSize.between(TrackSize.fixed(0), TrackSize.flex(0)),
        ],
        rows: const [
          TrackSize.between(TrackSize.fixed(0), TrackSize.flex(0)),
          TrackSize.between(TrackSize.fixed(0), TrackSize.flex(0)),
        ],
        children: [
          TrackCell(column: 0, row: 0, columnSpan: 2, rowSpan: 2, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 100, 100),
      '1': Rect.fromLTWH(3, 3, 0, 0),
      '2': Rect.fromLTWH(3, 3, 0, 0),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span2_minmax_0_0fr_minmax_0_1fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [
          TrackSize.between(TrackSize.fixed(0), TrackSize.flex(0)),
          TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1)),
        ],
        rows: const [
          TrackSize.between(TrackSize.fixed(0), TrackSize.flex(0)),
          TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1)),
        ],
        children: [
          TrackCell(column: 0, row: 0, columnSpan: 2, rowSpan: 2, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 100, 100),
      '1': Rect.fromLTWH(3, 3, 0, 0),
      '2': Rect.fromLTWH(3, 3, 44, 44),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span2_minmax_0_1fr_auto',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1)), TrackSize.auto],
        rows: const [TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1)), TrackSize.auto],
        children: [
          TrackCell(column: 0, row: 0, columnSpan: 2, rowSpan: 2, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 100, 100),
      '1': Rect.fromLTWH(3, 3, 44, 44),
      '2': Rect.fromLTWH(47, 47, 0, 0),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span2_minmax_15px_0fr_minmax_0_1fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [
          TrackSize.between(TrackSize.fixed(15), TrackSize.flex(0)),
          TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1)),
        ],
        rows: const [
          TrackSize.between(TrackSize.fixed(15), TrackSize.flex(0)),
          TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1)),
        ],
        children: [
          TrackCell(column: 0, row: 0, columnSpan: 2, rowSpan: 2, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 100, 100),
      '1': Rect.fromLTWH(3, 3, 15, 15),
      '2': Rect.fromLTWH(18, 18, 29, 29),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span2_minmax_20px_1fr_minmax_0_1fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [
          TrackSize.between(TrackSize.fixed(20), TrackSize.flex(1)),
          TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1)),
        ],
        rows: const [
          TrackSize.between(TrackSize.fixed(20), TrackSize.flex(1)),
          TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1)),
        ],
        children: [
          TrackCell(column: 0, row: 0, columnSpan: 2, rowSpan: 2, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 100, 100),
      '1': Rect.fromLTWH(3, 3, 22, 22),
      '2': Rect.fromLTWH(25, 25, 22, 22),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span2_minmax_25px_0fr_auto',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.fixed(25), TrackSize.flex(0)), TrackSize.auto],
        rows: const [TrackSize.between(TrackSize.fixed(25), TrackSize.flex(0)), TrackSize.auto],
        children: [
          TrackCell(column: 0, row: 0, columnSpan: 2, rowSpan: 2, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 100, 100),
      '1': Rect.fromLTWH(3, 3, 25, 25),
      '2': Rect.fromLTWH(28, 28, 19, 19),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span2_minmax_25px_1fr_auto',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.fixed(25), TrackSize.flex(1)), TrackSize.auto],
        rows: const [TrackSize.between(TrackSize.fixed(25), TrackSize.flex(1)), TrackSize.auto],
        children: [
          TrackCell(column: 0, row: 0, columnSpan: 2, rowSpan: 2, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 100, 100),
      '1': Rect.fromLTWH(3, 3, 44, 44),
      '2': Rect.fromLTWH(47, 47, 0, 0),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_001_span2_minmax_30px_1fr_minmax_0_1fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [
          TrackSize.between(TrackSize.fixed(30), TrackSize.flex(1)),
          TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1)),
        ],
        rows: const [
          TrackSize.between(TrackSize.fixed(30), TrackSize.flex(1)),
          TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1)),
        ],
        children: [
          TrackCell(column: 0, row: 0, columnSpan: 2, rowSpan: 2, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 100, 100),
      '1': Rect.fromLTWH(3, 3, 30, 30),
      '2': Rect.fromLTWH(33, 33, 14, 14),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_002_1fr_1fr_1fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.flex(1), TrackSize.flex(1), TrackSize.flex(1)],
        rows: const [TrackSize.flex(1), TrackSize.flex(1), TrackSize.flex(1)],
        children: [
          TrackCell(column: 0, row: 0, columnEnd: 1, rowEnd: 1, width: 60, height: 60, child: _a('0')),
          TrackCell(column: 0, row: 0, columnEnd: 3, rowEnd: 3, width: 150, height: 150, child: _a('1')),
          TrackCell(column: 0, row: 0, child: _a('2')),
          TrackCell(column: 1, row: 1, child: _a('3')),
          TrackCell(column: 2, row: 2, child: _a('4')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 60, 60),
      '1': Rect.fromLTWH(3, 3, 150, 150),
      '2': Rect.fromLTWH(3, 3, 60, 60),
      '3': Rect.fromLTWH(63, 63, 50, 50),
      '4': Rect.fromLTWH(113, 113, 50, 50),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_002_1fr_1fr_1fr_1fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.flex(1), TrackSize.flex(1), TrackSize.flex(1), TrackSize.flex(1)],
        rows: const [TrackSize.flex(1), TrackSize.flex(1), TrackSize.flex(1), TrackSize.flex(1)],
        children: [
          TrackCell(column: 0, row: 0, columnEnd: 2, rowEnd: 2, width: 60, height: 60, child: _a('0')),
          TrackCell(column: 1, row: 1, columnEnd: 4, rowEnd: 4, width: 150, height: 150, child: _a('1')),
          TrackCell(column: 0, row: 0, child: _a('2')),
          TrackCell(column: 1, row: 1, child: _a('3')),
          TrackCell(column: 2, row: 2, child: _a('4')),
          TrackCell(column: 3, row: 3, child: _a('5')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 60, 60),
      '1': Rect.fromLTWH(33, 33, 150, 150),
      '2': Rect.fromLTWH(3, 3, 30, 30),
      '3': Rect.fromLTWH(33, 33, 50, 50),
      '4': Rect.fromLTWH(83, 83, 50, 50),
      '5': Rect.fromLTWH(133, 133, 50, 50),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_002_1fr_1fr_1fr_4fr',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.flex(1), TrackSize.flex(1), TrackSize.flex(1), TrackSize.flex(4)],
        rows: const [TrackSize.flex(1), TrackSize.flex(1), TrackSize.flex(1), TrackSize.flex(4)],
        children: [
          TrackCell(column: 0, row: 0, columnEnd: 2, rowEnd: 2, width: 60, height: 60, child: _a('0')),
          TrackCell(column: 1, row: 1, columnEnd: 4, rowEnd: 4, width: 150, height: 150, child: _a('1')),
          TrackCell(column: 0, row: 0, child: _a('2')),
          TrackCell(column: 1, row: 1, child: _a('3')),
          TrackCell(column: 2, row: 2, child: _a('4')),
          TrackCell(column: 3, row: 3, child: _a('5')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 60, 60),
      '1': Rect.fromLTWH(33, 33, 150, 150),
      '2': Rect.fromLTWH(3, 3, 30, 30),
      '3': Rect.fromLTWH(33, 33, 30, 30),
      '4': Rect.fromLTWH(63, 63, 25, 25),
      '5': Rect.fromLTWH(88, 88, 100, 100),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_002_1fr_auto_auto_auto',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.flex(1), TrackSize.auto, TrackSize.auto, TrackSize.auto],
        rows: const [TrackSize.flex(1), TrackSize.auto, TrackSize.auto, TrackSize.auto],
        children: [
          TrackCell(column: 0, row: 0, columnEnd: 2, rowEnd: 2, width: 60, height: 60, child: _a('0')),
          TrackCell(column: 1, row: 1, columnEnd: 4, rowEnd: 4, width: 150, height: 150, child: _a('1')),
          TrackCell(column: 0, row: 0, child: _a('2')),
          TrackCell(column: 1, row: 1, child: _a('3')),
          TrackCell(column: 2, row: 2, child: _a('4')),
          TrackCell(column: 3, row: 3, child: _a('5')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 60, 60),
      '1': Rect.fromLTWH(13, 13, 150, 150),
      '2': Rect.fromLTWH(3, 3, 10, 10),
      '3': Rect.fromLTWH(13, 13, 50, 50),
      '4': Rect.fromLTWH(63, 63, 50, 50),
      '5': Rect.fromLTWH(113, 113, 50, 50),
    },
  ),
  (
    'grid_grid_flex_track_intrinsic_sizes_002_minmax_0_1fr_auto_auto_auto',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [
          TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1)),
          TrackSize.auto,
          TrackSize.auto,
          TrackSize.auto,
        ],
        rows: const [
          TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1)),
          TrackSize.auto,
          TrackSize.auto,
          TrackSize.auto,
        ],
        children: [
          TrackCell(column: 0, row: 0, columnEnd: 2, rowEnd: 2, width: 60, height: 60, child: _a('0')),
          TrackCell(column: 1, row: 1, columnEnd: 4, rowEnd: 4, width: 150, height: 150, child: _a('1')),
          TrackCell(column: 0, row: 0, child: _a('2')),
          TrackCell(column: 1, row: 1, child: _a('3')),
          TrackCell(column: 2, row: 2, child: _a('4')),
          TrackCell(column: 3, row: 3, child: _a('5')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 50),
      '0': Rect.fromLTWH(3, 3, 60, 60),
      '1': Rect.fromLTWH(3, 3, 150, 150),
      '2': Rect.fromLTWH(3, 3, 0, 0),
      '3': Rect.fromLTWH(3, 3, 50, 50),
      '4': Rect.fromLTWH(53, 53, 50, 50),
      '5': Rect.fromLTWH(103, 103, 50, 50),
    },
  ),
  (
    'grid_grid_fr_fixed_size_no_content_proportions',
    () => _grid(
      width: 200,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.flex(1), TrackSize.flex(2), TrackSize.flex(3)],
        rows: const [TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 40),
      '0': Rect.fromLTWH(0, 0, 33.33, 40),
      '1': Rect.fromLTWH(33.33, 0, 66.67, 40),
      '2': Rect.fromLTWH(100, 0, 100, 40),
    },
  ),
  (
    'grid_grid_fr_fixed_size_no_content_proportions_sub_1_sum',
    () => _grid(
      width: 100,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.flex(0.3), TrackSize.flex(0.2)],
        rows: const [TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 100, 40), '0': Rect.fromLTWH(0, 0, 30, 40), '1': Rect.fromLTWH(30, 0, 20, 40)},
  ),
  (
    'grid_grid_fr_fixed_size_single_item',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.flex(1), TrackSize.flex(1)],
        rows: const [TrackSize.fixed(40), TrackSize.flex(1), TrackSize.flex(1)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(width: 100, child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 100, 40),
      '2': Rect.fromLTWH(140, 0, 60, 40),
      '3': Rect.fromLTWH(0, 40, 40, 80),
      '4': Rect.fromLTWH(40, 40, 100, 80),
      '5': Rect.fromLTWH(140, 40, 60, 80),
      '6': Rect.fromLTWH(0, 120, 40, 80),
      '7': Rect.fromLTWH(40, 120, 100, 80),
      '8': Rect.fromLTWH(140, 120, 60, 80),
    },
  ),
  (
    'grid_grid_fr_minimum_zero_sum_with_other_flex_track',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(20)],
        rows: const [TrackSize.flex(0), TrackSize.flex(1)],
        children: [TrackCell(row: 0, rowEnd: 1, height: 100, child: _a('0'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 20, 200), '0': Rect.fromLTWH(0, 0, 20, 100)},
  ),
  (
    'grid_grid_fr_minimum_zero_sum_with_other_flex_track_definite',
    () => _grid(
      width: null,
      height: 500,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(20)],
        rows: const [TrackSize.flex(0), TrackSize.flex(1)],
        children: [
          TrackCell(row: 0, rowEnd: 1, height: 100, child: _a('0')),
          TrackCell(row: 1, rowEnd: 2, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 20, 500), '0': Rect.fromLTWH(0, 0, 20, 100), '1': Rect.fromLTWH(0, 100, 20, 400)},
  ),
  (
    'grid_grid_fr_no_sized_items_indefinite',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.flex(1), TrackSize.flex(1)],
        rows: const [TrackSize.fixed(40), TrackSize.flex(1), TrackSize.flex(1)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 40, 40),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 0, 40),
      '2': Rect.fromLTWH(40, 0, 0, 40),
      '3': Rect.fromLTWH(0, 40, 40, 0),
      '4': Rect.fromLTWH(40, 40, 0, 0),
      '5': Rect.fromLTWH(40, 40, 0, 0),
      '6': Rect.fromLTWH(0, 40, 40, 0),
      '7': Rect.fromLTWH(40, 40, 0, 0),
      '8': Rect.fromLTWH(40, 40, 0, 0),
    },
  ),
  (
    'grid_grid_fr_row_max_content_uses_column_width',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(50)],
        rows: const [
          TrackSize.between(TrackSize.fixed(10), TrackSize.flex(1)),
          TrackSize.between(TrackSize.minContent, TrackSize.fixed(50)),
        ],
        children: [
          TrackCell(child: _a('0', 'HHHHH\u200bHHHH')),
          TrackCell(child: _a('1', 'HHHHH\u200bHHHH')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 50, 70), '0': Rect.fromLTWH(0, 0, 50, 20), '1': Rect.fromLTWH(0, 20, 50, 50)},
  ),
  (
    'grid_grid_fr_single_item_indefinite',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.flex(1), TrackSize.flex(1)],
        rows: const [TrackSize.fixed(40), TrackSize.flex(1), TrackSize.flex(1)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(width: 100, child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 240, 40),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 100, 40),
      '2': Rect.fromLTWH(140, 0, 100, 40),
      '3': Rect.fromLTWH(0, 40, 40, 0),
      '4': Rect.fromLTWH(40, 40, 100, 0),
      '5': Rect.fromLTWH(140, 40, 100, 0),
      '6': Rect.fromLTWH(0, 40, 40, 0),
      '7': Rect.fromLTWH(40, 40, 100, 0),
      '8': Rect.fromLTWH(140, 40, 100, 0),
    },
  ),
  (
    'grid_grid_fr_span_2_proportion',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.flex(1), TrackSize.flex(2)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(columnSpan: 2, width: 60, child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 60, 80),
      '0': Rect.fromLTWH(0, 0, 60, 40),
      '1': Rect.fromLTWH(0, 40, 20, 40),
      '2': Rect.fromLTWH(20, 40, 40, 40),
    },
  ),
  (
    'grid_grid_fr_span_2_proportion_sub_1_sum',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.flex(0.2), TrackSize.flex(0.3)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(columnSpan: 2, width: 60, child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 60, 80),
      '0': Rect.fromLTWH(0, 0, 60, 40),
      '1': Rect.fromLTWH(0, 40, 24, 40),
      '2': Rect.fromLTWH(24, 40, 36, 40),
    },
  ),
  (
    'grid_grid_fr_span_2_proportion_with_non_spanned_track',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.flex(1), TrackSize.flex(2), TrackSize.flex(3)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(columnSpan: 2, width: 60, child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 80),
      '0': Rect.fromLTWH(0, 0, 60, 40),
      '1': Rect.fromLTWH(60, 0, 60, 40),
      '2': Rect.fromLTWH(0, 40, 20, 40),
      '3': Rect.fromLTWH(20, 40, 40, 40),
      '4': Rect.fromLTWH(60, 40, 60, 40),
    },
  ),
  (
    'grid_grid_fr_span_2_proportion_zero_sum',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.flex(0), TrackSize.flex(0)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(columnSpan: 2, width: 60, child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 60, 80),
      '0': Rect.fromLTWH(0, 0, 60, 40),
      '1': Rect.fromLTWH(0, 40, 30, 40),
      '2': Rect.fromLTWH(30, 40, 30, 40),
    },
  ),
  (
    'grid_grid_fr_span_2_proportion_zero_sum_with_non_spanned_track',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.flex(0), TrackSize.flex(0), TrackSize.flex(0)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(columnSpan: 2, width: 60, child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 60, 80),
      '0': Rect.fromLTWH(0, 0, 60, 40),
      '1': Rect.fromLTWH(60, 0, 0, 40),
      '2': Rect.fromLTWH(0, 40, 30, 40),
      '3': Rect.fromLTWH(30, 40, 30, 40),
      '4': Rect.fromLTWH(60, 40, 0, 40),
    },
  ),
  (
    'grid_grid_gap',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        spacing: 40,
        runSpacing: 40,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(80, 0, 40, 40),
      '2': Rect.fromLTWH(160, 0, 40, 40),
      '3': Rect.fromLTWH(0, 80, 40, 40),
      '4': Rect.fromLTWH(80, 80, 40, 40),
      '5': Rect.fromLTWH(160, 80, 40, 40),
      '6': Rect.fromLTWH(0, 160, 40, 40),
      '7': Rect.fromLTWH(80, 160, 40, 40),
      '8': Rect.fromLTWH(160, 160, 40, 40),
    },
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span1_auto',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.auto],
        rows: const [TrackSize.auto],
        children: [
          TrackCell(column: 0, row: 0, minWidth: 12, minHeight: 12, child: _a('0', 'XXX\u200bXX\u200bX')),
          TrackCell(column: 0, row: 0, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 120, 120), '0': Rect.fromLTWH(3, 3, 114, 114), '1': Rect.fromLTWH(3, 3, 114, 114)},
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span1_max_content',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.maxContent],
        rows: const [TrackSize.maxContent],
        children: [
          TrackCell(column: 0, row: 0, minWidth: 12, minHeight: 12, child: _a('0', 'XXX\u200bXX\u200bX')),
          TrackCell(column: 0, row: 0, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 120, 120), '0': Rect.fromLTWH(3, 3, 60, 12), '1': Rect.fromLTWH(3, 3, 60, 12)},
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span1_min_content',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.minContent],
        rows: const [TrackSize.minContent],
        children: [
          TrackCell(column: 0, row: 0, minWidth: 12, minHeight: 12, child: _a('0', 'XXX\u200bXX\u200bX')),
          TrackCell(column: 0, row: 0, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 120, 120), '0': Rect.fromLTWH(3, 3, 30, 20), '1': Rect.fromLTWH(3, 3, 30, 20)},
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span1_minmax_0_auto',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.fixed(0), TrackSize.auto)],
        rows: const [TrackSize.between(TrackSize.fixed(0), TrackSize.auto)],
        children: [
          TrackCell(column: 0, row: 0, minWidth: 12, minHeight: 12, child: _a('0', 'XXX\u200bXX\u200bX')),
          TrackCell(column: 0, row: 0, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 120, 120), '0': Rect.fromLTWH(3, 3, 114, 114), '1': Rect.fromLTWH(3, 3, 114, 114)},
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span1_minmax_0_max_content',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.fixed(0), TrackSize.maxContent)],
        rows: const [TrackSize.between(TrackSize.fixed(0), TrackSize.maxContent)],
        children: [
          TrackCell(column: 0, row: 0, minWidth: 12, minHeight: 12, child: _a('0', 'XXX\u200bXX\u200bX')),
          TrackCell(column: 0, row: 0, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 120, 120), '0': Rect.fromLTWH(3, 3, 60, 12), '1': Rect.fromLTWH(3, 3, 60, 12)},
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span1_minmax_0_min_content',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.fixed(0), TrackSize.minContent)],
        rows: const [TrackSize.between(TrackSize.fixed(0), TrackSize.minContent)],
        children: [
          TrackCell(column: 0, row: 0, minWidth: 12, minHeight: 12, child: _a('0', 'XXX\u200bXX\u200bX')),
          TrackCell(column: 0, row: 0, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 120, 120), '0': Rect.fromLTWH(3, 3, 30, 20), '1': Rect.fromLTWH(3, 3, 30, 20)},
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span1_minmax_auto_10px',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.auto, TrackSize.fixed(10))],
        rows: const [TrackSize.between(TrackSize.auto, TrackSize.fixed(10))],
        children: [
          TrackCell(column: 0, row: 0, minWidth: 12, minHeight: 12, child: _a('0', 'XXX\u200bXX\u200bX')),
          TrackCell(column: 0, row: 0, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 120, 120), '0': Rect.fromLTWH(3, 3, 12, 12), '1': Rect.fromLTWH(3, 3, 12, 12)},
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span1_minmax_max_content_10px',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.maxContent, TrackSize.fixed(10))],
        rows: const [TrackSize.between(TrackSize.maxContent, TrackSize.fixed(10))],
        children: [
          TrackCell(column: 0, row: 0, minWidth: 12, minHeight: 12, child: _a('0', 'XXX\u200bXX\u200bX')),
          TrackCell(column: 0, row: 0, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 120, 120), '0': Rect.fromLTWH(3, 3, 60, 12), '1': Rect.fromLTWH(3, 3, 60, 12)},
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span1_minmax_min_content_10px',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.minContent, TrackSize.fixed(10))],
        rows: const [TrackSize.between(TrackSize.minContent, TrackSize.fixed(10))],
        children: [
          TrackCell(column: 0, row: 0, minWidth: 12, minHeight: 12, child: _a('0', 'XXX\u200bXX\u200bX')),
          TrackCell(column: 0, row: 0, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 120, 120), '0': Rect.fromLTWH(3, 3, 30, 20), '1': Rect.fromLTWH(3, 3, 30, 20)},
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span2_20px_auto',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.fixed(20), TrackSize.auto],
        rows: const [TrackSize.fixed(20), TrackSize.auto],
        children: [
          TrackCell(
            column: 0,
            row: 0,
            columnSpan: 2,
            rowSpan: 2,
            minWidth: 12,
            minHeight: 12,
            child: _a('0', 'XXX\u200bXX\u200bX'),
          ),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(3, 3, 114, 114),
      '1': Rect.fromLTWH(3, 3, 20, 20),
      '2': Rect.fromLTWH(23, 23, 94, 94),
    },
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span2_20px_max_content',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.fixed(20), TrackSize.maxContent],
        rows: const [TrackSize.fixed(20), TrackSize.maxContent],
        children: [
          TrackCell(
            column: 0,
            row: 0,
            columnSpan: 2,
            rowSpan: 2,
            minWidth: 12,
            minHeight: 12,
            child: _a('0', 'XXX\u200bXX\u200bX'),
          ),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(3, 3, 60, 20),
      '1': Rect.fromLTWH(3, 3, 20, 20),
      '2': Rect.fromLTWH(23, 23, 40, 0),
    },
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span2_20px_min_content',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.fixed(20), TrackSize.minContent],
        rows: const [TrackSize.fixed(20), TrackSize.minContent],
        children: [
          TrackCell(
            column: 0,
            row: 0,
            columnSpan: 2,
            rowSpan: 2,
            minWidth: 12,
            minHeight: 12,
            child: _a('0', 'XXX\u200bXX\u200bX'),
          ),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(3, 3, 30, 20),
      '1': Rect.fromLTWH(3, 3, 20, 20),
      '2': Rect.fromLTWH(23, 23, 10, 0),
    },
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span2_20px_minmax_0_auto',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.fixed(20), TrackSize.between(TrackSize.fixed(0), TrackSize.auto)],
        rows: const [TrackSize.fixed(20), TrackSize.between(TrackSize.fixed(0), TrackSize.auto)],
        children: [
          TrackCell(
            column: 0,
            row: 0,
            columnSpan: 2,
            rowSpan: 2,
            minWidth: 12,
            minHeight: 12,
            child: _a('0', 'XXX\u200bXX\u200bX'),
          ),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(3, 3, 114, 114),
      '1': Rect.fromLTWH(3, 3, 20, 20),
      '2': Rect.fromLTWH(23, 23, 94, 94),
    },
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span2_20px_minmax_0_max_content',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.fixed(20), TrackSize.between(TrackSize.fixed(0), TrackSize.maxContent)],
        rows: const [TrackSize.fixed(20), TrackSize.between(TrackSize.fixed(0), TrackSize.maxContent)],
        children: [
          TrackCell(
            column: 0,
            row: 0,
            columnSpan: 2,
            rowSpan: 2,
            minWidth: 12,
            minHeight: 12,
            child: _a('0', 'XXX\u200bXX\u200bX'),
          ),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(3, 3, 60, 20),
      '1': Rect.fromLTWH(3, 3, 20, 20),
      '2': Rect.fromLTWH(23, 23, 40, 0),
    },
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span2_20px_minmax_0_min_content',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.fixed(20), TrackSize.between(TrackSize.fixed(0), TrackSize.minContent)],
        rows: const [TrackSize.fixed(20), TrackSize.between(TrackSize.fixed(0), TrackSize.minContent)],
        children: [
          TrackCell(
            column: 0,
            row: 0,
            columnSpan: 2,
            rowSpan: 2,
            minWidth: 12,
            minHeight: 12,
            child: _a('0', 'XXX\u200bXX\u200bX'),
          ),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(3, 3, 30, 20),
      '1': Rect.fromLTWH(3, 3, 20, 20),
      '2': Rect.fromLTWH(23, 23, 10, 0),
    },
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span2_20px_minmax_auto_30px',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.fixed(20), TrackSize.between(TrackSize.auto, TrackSize.fixed(30))],
        rows: const [TrackSize.fixed(20), TrackSize.between(TrackSize.auto, TrackSize.fixed(30))],
        children: [
          TrackCell(
            column: 0,
            row: 0,
            columnSpan: 2,
            rowSpan: 2,
            minWidth: 12,
            minHeight: 12,
            child: _a('0', 'XXX\u200bXX\u200bX'),
          ),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(3, 3, 50, 50),
      '1': Rect.fromLTWH(3, 3, 20, 20),
      '2': Rect.fromLTWH(23, 23, 30, 30),
    },
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span2_20px_minmax_max_content_30px',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.fixed(20), TrackSize.between(TrackSize.maxContent, TrackSize.fixed(30))],
        rows: const [TrackSize.fixed(20), TrackSize.between(TrackSize.maxContent, TrackSize.fixed(30))],
        children: [
          TrackCell(
            column: 0,
            row: 0,
            columnSpan: 2,
            rowSpan: 2,
            minWidth: 12,
            minHeight: 12,
            child: _a('0', 'XXX\u200bXX\u200bX'),
          ),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(3, 3, 60, 50),
      '1': Rect.fromLTWH(3, 3, 20, 20),
      '2': Rect.fromLTWH(23, 23, 40, 30),
    },
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span2_20px_minmax_max_content_6px',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.fixed(20), TrackSize.between(TrackSize.maxContent, TrackSize.fixed(6))],
        rows: const [TrackSize.fixed(20), TrackSize.between(TrackSize.maxContent, TrackSize.fixed(6))],
        children: [
          TrackCell(
            column: 0,
            row: 0,
            columnSpan: 2,
            rowSpan: 2,
            minWidth: 12,
            minHeight: 12,
            child: _a('0', 'XXX\u200bXX\u200bX'),
          ),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(3, 3, 60, 26),
      '1': Rect.fromLTWH(3, 3, 20, 20),
      '2': Rect.fromLTWH(23, 23, 40, 6),
    },
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span2_20px_minmax_min_content_40px',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.fixed(20), TrackSize.between(TrackSize.minContent, TrackSize.fixed(40))],
        rows: const [TrackSize.fixed(20), TrackSize.between(TrackSize.minContent, TrackSize.fixed(40))],
        children: [
          TrackCell(
            column: 0,
            row: 0,
            columnSpan: 2,
            rowSpan: 2,
            minWidth: 12,
            minHeight: 12,
            child: _a('0', 'XXX\u200bXX\u200bX'),
          ),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(3, 3, 60, 60),
      '1': Rect.fromLTWH(3, 3, 20, 20),
      '2': Rect.fromLTWH(23, 23, 40, 40),
    },
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span2_20px_minmax_min_content_6px',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.fixed(20), TrackSize.between(TrackSize.minContent, TrackSize.fixed(6))],
        rows: const [TrackSize.fixed(20), TrackSize.between(TrackSize.minContent, TrackSize.fixed(6))],
        children: [
          TrackCell(
            column: 0,
            row: 0,
            columnSpan: 2,
            rowSpan: 2,
            minWidth: 12,
            minHeight: 12,
            child: _a('0', 'XXX\u200bXX\u200bX'),
          ),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(3, 3, 30, 26),
      '1': Rect.fromLTWH(3, 3, 20, 20),
      '2': Rect.fromLTWH(23, 23, 10, 6),
    },
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span2_auto_auto',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.auto, TrackSize.auto],
        rows: const [TrackSize.auto, TrackSize.auto],
        children: [
          TrackCell(
            column: 0,
            row: 0,
            columnSpan: 2,
            rowSpan: 2,
            minWidth: 12,
            minHeight: 12,
            child: _a('0', 'XXX\u200bXX\u200bX'),
          ),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(3, 3, 114, 114),
      '1': Rect.fromLTWH(3, 3, 57, 57),
      '2': Rect.fromLTWH(60, 60, 57, 57),
    },
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span2_max_content_max_content',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.maxContent, TrackSize.maxContent],
        rows: const [TrackSize.maxContent, TrackSize.maxContent],
        children: [
          TrackCell(
            column: 0,
            row: 0,
            columnSpan: 2,
            rowSpan: 2,
            minWidth: 12,
            minHeight: 12,
            child: _a('0', 'XXX\u200bXX\u200bX'),
          ),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(3, 3, 60, 12),
      '1': Rect.fromLTWH(3, 3, 30, 6),
      '2': Rect.fromLTWH(33, 9, 30, 6),
    },
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span2_max_content_min_content',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.maxContent, TrackSize.minContent],
        rows: const [TrackSize.maxContent, TrackSize.minContent],
        children: [
          TrackCell(
            column: 0,
            row: 0,
            columnSpan: 2,
            rowSpan: 2,
            minWidth: 12,
            minHeight: 12,
            child: _a('0', 'XXX\u200bXX\u200bX'),
          ),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(3, 3, 60, 12),
      '1': Rect.fromLTWH(3, 3, 45, 6),
      '2': Rect.fromLTWH(48, 9, 15, 6),
    },
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span2_min_content_min_content',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [TrackSize.minContent, TrackSize.minContent],
        rows: const [TrackSize.minContent, TrackSize.minContent],
        children: [
          TrackCell(
            column: 0,
            row: 0,
            columnSpan: 2,
            rowSpan: 2,
            minWidth: 12,
            minHeight: 12,
            child: _a('0', 'XXX\u200bXX\u200bX'),
          ),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(3, 3, 30, 20),
      '1': Rect.fromLTWH(3, 3, 15, 10),
      '2': Rect.fromLTWH(18, 13, 15, 10),
    },
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span2_minmax_0_auto_minmax_0_auto',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [
          TrackSize.between(TrackSize.fixed(0), TrackSize.auto),
          TrackSize.between(TrackSize.fixed(0), TrackSize.auto),
        ],
        rows: const [
          TrackSize.between(TrackSize.fixed(0), TrackSize.auto),
          TrackSize.between(TrackSize.fixed(0), TrackSize.auto),
        ],
        children: [
          TrackCell(
            column: 0,
            row: 0,
            columnSpan: 2,
            rowSpan: 2,
            minWidth: 12,
            minHeight: 12,
            child: _a('0', 'XXX\u200bXX\u200bX'),
          ),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(3, 3, 114, 114),
      '1': Rect.fromLTWH(3, 3, 57, 57),
      '2': Rect.fromLTWH(60, 60, 57, 57),
    },
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span2_minmax_0_max_content_minmax_0_max_content',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [
          TrackSize.between(TrackSize.fixed(0), TrackSize.maxContent),
          TrackSize.between(TrackSize.fixed(0), TrackSize.maxContent),
        ],
        rows: const [
          TrackSize.between(TrackSize.fixed(0), TrackSize.maxContent),
          TrackSize.between(TrackSize.fixed(0), TrackSize.maxContent),
        ],
        children: [
          TrackCell(
            column: 0,
            row: 0,
            columnSpan: 2,
            rowSpan: 2,
            minWidth: 12,
            minHeight: 12,
            child: _a('0', 'XXX\u200bXX\u200bX'),
          ),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(3, 3, 60, 12),
      '1': Rect.fromLTWH(3, 3, 30, 6),
      '2': Rect.fromLTWH(33, 9, 30, 6),
    },
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span2_minmax_0_min_content_minmax_0_min_content',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [
          TrackSize.between(TrackSize.fixed(0), TrackSize.minContent),
          TrackSize.between(TrackSize.fixed(0), TrackSize.minContent),
        ],
        rows: const [
          TrackSize.between(TrackSize.fixed(0), TrackSize.minContent),
          TrackSize.between(TrackSize.fixed(0), TrackSize.minContent),
        ],
        children: [
          TrackCell(
            column: 0,
            row: 0,
            columnSpan: 2,
            rowSpan: 2,
            minWidth: 12,
            minHeight: 12,
            child: _a('0', 'XXX\u200bXX\u200bX'),
          ),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(3, 3, 30, 20),
      '1': Rect.fromLTWH(3, 3, 15, 10),
      '2': Rect.fromLTWH(18, 13, 15, 10),
    },
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span2_minmax_auto_10px_minmax_auto_10px',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [
          TrackSize.between(TrackSize.auto, TrackSize.fixed(10)),
          TrackSize.between(TrackSize.auto, TrackSize.fixed(10)),
        ],
        rows: const [
          TrackSize.between(TrackSize.auto, TrackSize.fixed(10)),
          TrackSize.between(TrackSize.auto, TrackSize.fixed(10)),
        ],
        children: [
          TrackCell(
            column: 0,
            row: 0,
            columnSpan: 2,
            rowSpan: 2,
            minWidth: 12,
            minHeight: 12,
            child: _a('0', 'XXX\u200bXX\u200bX'),
          ),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(3, 3, 20, 20),
      '1': Rect.fromLTWH(3, 3, 10, 10),
      '2': Rect.fromLTWH(13, 13, 10, 10),
    },
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span2_minmax_auto_4px_minmax_auto_4px',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [
          TrackSize.between(TrackSize.auto, TrackSize.fixed(4)),
          TrackSize.between(TrackSize.auto, TrackSize.fixed(4)),
        ],
        rows: const [
          TrackSize.between(TrackSize.auto, TrackSize.fixed(4)),
          TrackSize.between(TrackSize.auto, TrackSize.fixed(4)),
        ],
        children: [
          TrackCell(
            column: 0,
            row: 0,
            columnSpan: 2,
            rowSpan: 2,
            minWidth: 12,
            minHeight: 12,
            child: _a('0', 'XXX\u200bXX\u200bX'),
          ),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(3, 3, 12, 12),
      '1': Rect.fromLTWH(3, 3, 6, 6),
      '2': Rect.fromLTWH(9, 9, 6, 6),
    },
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span2_minmax_max_content_10px_minmax_max_content_10px',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [
          TrackSize.between(TrackSize.maxContent, TrackSize.fixed(10)),
          TrackSize.between(TrackSize.maxContent, TrackSize.fixed(10)),
        ],
        rows: const [
          TrackSize.between(TrackSize.maxContent, TrackSize.fixed(10)),
          TrackSize.between(TrackSize.maxContent, TrackSize.fixed(10)),
        ],
        children: [
          TrackCell(
            column: 0,
            row: 0,
            columnSpan: 2,
            rowSpan: 2,
            minWidth: 12,
            minHeight: 12,
            child: _a('0', 'XXX\u200bXX\u200bX'),
          ),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(3, 3, 60, 20),
      '1': Rect.fromLTWH(3, 3, 30, 10),
      '2': Rect.fromLTWH(33, 13, 30, 10),
    },
  ),
  (
    'grid_grid_intrinsic_track_sizes_001_span2_minmax_min_content_10px_minmax_min_content_10px',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.fromLTRB(3, 3, 3, 3),
      tracks: Tracks(
        columns: const [
          TrackSize.between(TrackSize.minContent, TrackSize.fixed(10)),
          TrackSize.between(TrackSize.minContent, TrackSize.fixed(10)),
        ],
        rows: const [
          TrackSize.between(TrackSize.minContent, TrackSize.fixed(10)),
          TrackSize.between(TrackSize.minContent, TrackSize.fixed(10)),
        ],
        children: [
          TrackCell(
            column: 0,
            row: 0,
            columnSpan: 2,
            rowSpan: 2,
            minWidth: 12,
            minHeight: 12,
            child: _a('0', 'XXX\u200bXX\u200bX'),
          ),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(column: 1, row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(3, 3, 30, 20),
      '1': Rect.fromLTWH(3, 3, 15, 10),
      '2': Rect.fromLTWH(18, 13, 15, 10),
    },
  ),
  (
    'grid_grid_justify_content_center',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        justifyContent: TrackContent.center,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(40, 0, 40, 40),
      '1': Rect.fromLTWH(80, 0, 40, 40),
      '2': Rect.fromLTWH(120, 0, 40, 40),
      '3': Rect.fromLTWH(40, 40, 40, 40),
      '4': Rect.fromLTWH(80, 40, 40, 40),
      '5': Rect.fromLTWH(120, 40, 40, 40),
      '6': Rect.fromLTWH(40, 80, 40, 40),
      '7': Rect.fromLTWH(80, 80, 40, 40),
      '8': Rect.fromLTWH(120, 80, 40, 40),
    },
  ),
  (
    'grid_grid_justify_content_center_with_padding_border',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.fromLTRB(48, 12, 24, 36),
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        justifyContent: TrackContent.center,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(52, 12, 40, 40),
      '1': Rect.fromLTWH(92, 12, 40, 40),
      '2': Rect.fromLTWH(132, 12, 40, 40),
      '3': Rect.fromLTWH(52, 52, 40, 40),
      '4': Rect.fromLTWH(92, 52, 40, 40),
      '5': Rect.fromLTWH(132, 52, 40, 40),
      '6': Rect.fromLTWH(52, 92, 40, 40),
      '7': Rect.fromLTWH(92, 92, 40, 40),
      '8': Rect.fromLTWH(132, 92, 40, 40),
    },
  ),
  (
    'grid_grid_justify_content_end',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        justifyContent: TrackContent.end,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(80, 0, 40, 40),
      '1': Rect.fromLTWH(120, 0, 40, 40),
      '2': Rect.fromLTWH(160, 0, 40, 40),
      '3': Rect.fromLTWH(80, 40, 40, 40),
      '4': Rect.fromLTWH(120, 40, 40, 40),
      '5': Rect.fromLTWH(160, 40, 40, 40),
      '6': Rect.fromLTWH(80, 80, 40, 40),
      '7': Rect.fromLTWH(120, 80, 40, 40),
      '8': Rect.fromLTWH(160, 80, 40, 40),
    },
  ),
  (
    'grid_grid_justify_content_end_with_padding_border',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.fromLTRB(48, 12, 24, 36),
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        justifyContent: TrackContent.end,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(56, 12, 40, 40),
      '1': Rect.fromLTWH(96, 12, 40, 40),
      '2': Rect.fromLTWH(136, 12, 40, 40),
      '3': Rect.fromLTWH(56, 52, 40, 40),
      '4': Rect.fromLTWH(96, 52, 40, 40),
      '5': Rect.fromLTWH(136, 52, 40, 40),
      '6': Rect.fromLTWH(56, 92, 40, 40),
      '7': Rect.fromLTWH(96, 92, 40, 40),
      '8': Rect.fromLTWH(136, 92, 40, 40),
    },
  ),
  (
    'grid_grid_justify_content_space_around',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        justifyContent: TrackContent.spaceAround,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(13.33, 0, 40, 40),
      '1': Rect.fromLTWH(79.98, 0, 40, 40),
      '2': Rect.fromLTWH(146.64, 0, 40, 40),
      '3': Rect.fromLTWH(13.33, 40, 40, 40),
      '4': Rect.fromLTWH(79.98, 40, 40, 40),
      '5': Rect.fromLTWH(146.64, 40, 40, 40),
      '6': Rect.fromLTWH(13.33, 80, 40, 40),
      '7': Rect.fromLTWH(79.98, 80, 40, 40),
      '8': Rect.fromLTWH(146.64, 80, 40, 40),
    },
  ),
  (
    'grid_grid_justify_content_space_around_with_padding_border',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.fromLTRB(48, 12, 24, 36),
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        justifyContent: TrackContent.spaceAround,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(49.33, 12, 40, 40),
      '1': Rect.fromLTWH(91.98, 12, 40, 40),
      '2': Rect.fromLTWH(134.64, 12, 40, 40),
      '3': Rect.fromLTWH(49.33, 52, 40, 40),
      '4': Rect.fromLTWH(91.98, 52, 40, 40),
      '5': Rect.fromLTWH(134.64, 52, 40, 40),
      '6': Rect.fromLTWH(49.33, 92, 40, 40),
      '7': Rect.fromLTWH(91.98, 92, 40, 40),
      '8': Rect.fromLTWH(134.64, 92, 40, 40),
    },
  ),
  (
    'grid_grid_justify_content_space_between',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        justifyContent: TrackContent.spaceBetween,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(80, 0, 40, 40),
      '2': Rect.fromLTWH(160, 0, 40, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(80, 40, 40, 40),
      '5': Rect.fromLTWH(160, 40, 40, 40),
      '6': Rect.fromLTWH(0, 80, 40, 40),
      '7': Rect.fromLTWH(80, 80, 40, 40),
      '8': Rect.fromLTWH(160, 80, 40, 40),
    },
  ),
  (
    'grid_grid_justify_content_space_between_with_padding_border',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.fromLTRB(48, 12, 24, 36),
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        justifyContent: TrackContent.spaceBetween,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(48, 12, 40, 40),
      '1': Rect.fromLTWH(92, 12, 40, 40),
      '2': Rect.fromLTWH(136, 12, 40, 40),
      '3': Rect.fromLTWH(48, 52, 40, 40),
      '4': Rect.fromLTWH(92, 52, 40, 40),
      '5': Rect.fromLTWH(136, 52, 40, 40),
      '6': Rect.fromLTWH(48, 92, 40, 40),
      '7': Rect.fromLTWH(92, 92, 40, 40),
      '8': Rect.fromLTWH(136, 92, 40, 40),
    },
  ),
  (
    'grid_grid_justify_content_space_evenly',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        justifyContent: TrackContent.spaceEvenly,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(20, 0, 40, 40),
      '1': Rect.fromLTWH(80, 0, 40, 40),
      '2': Rect.fromLTWH(140, 0, 40, 40),
      '3': Rect.fromLTWH(20, 40, 40, 40),
      '4': Rect.fromLTWH(80, 40, 40, 40),
      '5': Rect.fromLTWH(140, 40, 40, 40),
      '6': Rect.fromLTWH(20, 80, 40, 40),
      '7': Rect.fromLTWH(80, 80, 40, 40),
      '8': Rect.fromLTWH(140, 80, 40, 40),
    },
  ),
  (
    'grid_grid_justify_content_space_evenly_with_padding_border',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.fromLTRB(48, 12, 24, 36),
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        justifyContent: TrackContent.spaceEvenly,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(50, 12, 40, 40),
      '1': Rect.fromLTWH(92, 12, 40, 40),
      '2': Rect.fromLTWH(134, 12, 40, 40),
      '3': Rect.fromLTWH(50, 52, 40, 40),
      '4': Rect.fromLTWH(92, 52, 40, 40),
      '5': Rect.fromLTWH(134, 52, 40, 40),
      '6': Rect.fromLTWH(50, 92, 40, 40),
      '7': Rect.fromLTWH(92, 92, 40, 40),
      '8': Rect.fromLTWH(134, 92, 40, 40),
    },
  ),
  (
    'grid_grid_justify_content_start',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        justifyContent: TrackContent.start,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 40, 40),
      '2': Rect.fromLTWH(80, 0, 40, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 40, 40, 40),
      '5': Rect.fromLTWH(80, 40, 40, 40),
      '6': Rect.fromLTWH(0, 80, 40, 40),
      '7': Rect.fromLTWH(40, 80, 40, 40),
      '8': Rect.fromLTWH(80, 80, 40, 40),
    },
  ),
  (
    'grid_grid_justify_content_start_with_padding_border',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.fromLTRB(48, 12, 24, 36),
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        justifyContent: TrackContent.start,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(48, 12, 40, 40),
      '1': Rect.fromLTWH(88, 12, 40, 40),
      '2': Rect.fromLTWH(128, 12, 40, 40),
      '3': Rect.fromLTWH(48, 52, 40, 40),
      '4': Rect.fromLTWH(88, 52, 40, 40),
      '5': Rect.fromLTWH(128, 52, 40, 40),
      '6': Rect.fromLTWH(48, 92, 40, 40),
      '7': Rect.fromLTWH(88, 92, 40, 40),
      '8': Rect.fromLTWH(128, 92, 40, 40),
    },
  ),
  (
    'grid_grid_justify_items_sized_center',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        justify: CellAlign.center,
        children: [
          TrackCell(column: 0, row: 0, width: 20, height: 20, child: _a('0')),
          TrackCell(column: 2, row: 2, width: 60, height: 60, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 120, 120), '0': Rect.fromLTWH(10, 0, 20, 20), '1': Rect.fromLTWH(70, 80, 60, 60)},
  ),
  (
    'grid_grid_justify_items_sized_end',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        justify: CellAlign.end,
        children: [
          TrackCell(column: 0, row: 0, width: 20, height: 20, child: _a('0')),
          TrackCell(column: 2, row: 2, width: 60, height: 60, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 120, 120), '0': Rect.fromLTWH(20, 0, 20, 20), '1': Rect.fromLTWH(60, 80, 60, 60)},
  ),
  (
    'grid_grid_justify_items_sized_start',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        justify: CellAlign.start,
        children: [
          TrackCell(column: 0, row: 0, width: 20, height: 20, child: _a('0')),
          TrackCell(column: 2, row: 2, width: 60, height: 60, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 120, 120), '0': Rect.fromLTWH(0, 0, 20, 20), '1': Rect.fromLTWH(80, 80, 60, 60)},
  ),
  (
    'grid_grid_justify_items_sized_stretch',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(column: 0, row: 0, width: 20, height: 20, child: _a('0')),
          TrackCell(column: 2, row: 2, width: 60, height: 60, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 120, 120), '0': Rect.fromLTWH(0, 0, 20, 20), '1': Rect.fromLTWH(80, 80, 60, 60)},
  ),
  (
    'grid_grid_justify_self_self_end',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(column: 0, row: 0, width: 20, height: 20, justify: CellAlign.end, child: _a('0')),
          TrackCell(column: 1, row: 1, width: 20, height: 20, justify: CellAlign.end, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 120, 120), '0': Rect.fromLTWH(20, 0, 20, 20), '1': Rect.fromLTWH(60, 40, 20, 20)},
  ),
  (
    'grid_grid_justify_self_self_start',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(column: 0, row: 0, width: 20, height: 20, justify: CellAlign.start, child: _a('0')),
          TrackCell(column: 1, row: 1, width: 20, height: 20, justify: CellAlign.start, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 120, 120), '0': Rect.fromLTWH(0, 0, 20, 20), '1': Rect.fromLTWH(40, 40, 20, 20)},
  ),
  (
    'grid_grid_justify_self_sized_all',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(width: 20, height: 20, justify: CellAlign.start, child: _a('0')),
          TrackCell(width: 60, height: 60, justify: CellAlign.start, child: _a('1')),
          TrackCell(width: 20, height: 20, justify: CellAlign.end, child: _a('2')),
          TrackCell(width: 60, height: 60, justify: CellAlign.end, child: _a('3')),
          TrackCell(width: 20, height: 20, justify: CellAlign.center, child: _a('4')),
          TrackCell(width: 60, height: 60, justify: CellAlign.center, child: _a('5')),
          TrackCell(width: 20, height: 20, justify: CellAlign.stretch, child: _a('6')),
          TrackCell(width: 60, height: 60, justify: CellAlign.stretch, child: _a('7')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(0, 0, 20, 20),
      '1': Rect.fromLTWH(40, 0, 60, 60),
      '2': Rect.fromLTWH(100, 0, 20, 20),
      '3': Rect.fromLTWH(-20, 40, 60, 60),
      '4': Rect.fromLTWH(50, 40, 20, 20),
      '5': Rect.fromLTWH(70, 40, 60, 60),
      '6': Rect.fromLTWH(0, 80, 20, 20),
      '7': Rect.fromLTWH(40, 80, 60, 60),
    },
  ),
  (
    'grid_grid_margins_auto_margins',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.fromLTRB(40, 10, 20, 30),
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(
            width: 20,
            justify: CellAlign.start,
            autoMargin: AutoEdges(right: true, left: true),
            child: _a('2'),
          ),
          TrackCell(child: _a('3')),
          TrackCell(height: 20, align: CellAlign.start, autoMargin: AutoEdges(top: true, bottom: true), child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(
            width: 20,
            height: 20,
            align: CellAlign.start,
            justify: CellAlign.start,
            autoMargin: AutoEdges(top: true, right: true, bottom: true, left: true),
            child: _a('6'),
          ),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 180, 160),
      '0': Rect.fromLTWH(40, 10, 40, 40),
      '1': Rect.fromLTWH(80, 10, 40, 40),
      '2': Rect.fromLTWH(130, 10, 20, 40),
      '3': Rect.fromLTWH(40, 50, 40, 40),
      '4': Rect.fromLTWH(80, 60, 40, 20),
      '5': Rect.fromLTWH(120, 50, 40, 40),
      '6': Rect.fromLTWH(50, 100, 20, 20),
      '7': Rect.fromLTWH(80, 90, 40, 40),
      '8': Rect.fromLTWH(120, 90, 40, 40),
    },
  ),
  (
    'grid_grid_margins_auto_margins_override_stretch',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.fromLTRB(40, 10, 20, 30),
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(
            align: CellAlign.stretch,
            justify: CellAlign.stretch,
            autoMargin: AutoEdges(top: true, right: true, bottom: true, left: true),
            child: _a('6', 'HH\u200bHH'),
          ),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 180, 160),
      '0': Rect.fromLTWH(40, 10, 40, 40),
      '1': Rect.fromLTWH(80, 10, 40, 40),
      '2': Rect.fromLTWH(120, 10, 40, 40),
      '3': Rect.fromLTWH(40, 50, 40, 40),
      '4': Rect.fromLTWH(80, 50, 40, 40),
      '5': Rect.fromLTWH(120, 50, 40, 40),
      '6': Rect.fromLTWH(40, 105, 40, 10),
      '7': Rect.fromLTWH(80, 90, 40, 40),
      '8': Rect.fromLTWH(120, 90, 40, 40),
    },
  ),
  (
    'grid_grid_margins_fixed_center',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.fromLTRB(40, 10, 20, 30),
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(
            width: 20,
            height: 20,
            align: CellAlign.center,
            justify: CellAlign.center,
            margin: EdgeInsets.fromLTRB(8, 2, 4, 6),
            child: _a('0'),
          ),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 180, 160),
      '0': Rect.fromLTWH(52, 18, 20, 20),
      '1': Rect.fromLTWH(80, 10, 40, 40),
      '2': Rect.fromLTWH(120, 10, 40, 40),
      '3': Rect.fromLTWH(40, 50, 40, 40),
      '4': Rect.fromLTWH(80, 50, 40, 40),
      '5': Rect.fromLTWH(120, 50, 40, 40),
    },
  ),
  (
    'grid_grid_margins_fixed_end',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.fromLTRB(40, 10, 20, 30),
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(
            width: 20,
            height: 20,
            align: CellAlign.end,
            justify: CellAlign.end,
            margin: EdgeInsets.fromLTRB(4, 1, 2, 3),
            child: _a('0'),
          ),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 180, 160),
      '0': Rect.fromLTWH(58, 27, 20, 20),
      '1': Rect.fromLTWH(80, 10, 40, 40),
      '2': Rect.fromLTWH(120, 10, 40, 40),
      '3': Rect.fromLTWH(40, 50, 40, 40),
      '4': Rect.fromLTWH(80, 50, 40, 40),
      '5': Rect.fromLTWH(120, 50, 40, 40),
    },
  ),
  (
    'grid_grid_margins_fixed_start',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.fromLTRB(40, 10, 20, 30),
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(
            width: 20,
            height: 20,
            align: CellAlign.start,
            justify: CellAlign.start,
            margin: EdgeInsets.fromLTRB(4, 1, 2, 3),
            child: _a('0'),
          ),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 180, 160),
      '0': Rect.fromLTWH(44, 11, 20, 20),
      '1': Rect.fromLTWH(80, 10, 40, 40),
      '2': Rect.fromLTWH(120, 10, 40, 40),
      '3': Rect.fromLTWH(40, 50, 40, 40),
      '4': Rect.fromLTWH(80, 50, 40, 40),
      '5': Rect.fromLTWH(120, 50, 40, 40),
    },
  ),
  (
    'grid_grid_margins_fixed_stretch',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.fromLTRB(40, 10, 20, 30),
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(
            width: 20,
            height: 20,
            align: CellAlign.stretch,
            justify: CellAlign.stretch,
            margin: EdgeInsets.fromLTRB(4, 1, 2, 3),
            child: _a('0'),
          ),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 180, 160),
      '0': Rect.fromLTWH(44, 11, 20, 20),
      '1': Rect.fromLTWH(80, 10, 40, 40),
      '2': Rect.fromLTWH(120, 10, 40, 40),
      '3': Rect.fromLTWH(40, 50, 40, 40),
      '4': Rect.fromLTWH(80, 50, 40, 40),
      '5': Rect.fromLTWH(120, 50, 40, 40),
    },
  ),
  (
    'grid_grid_max_content_maximum_single_item',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.fixed(40),
          TrackSize.between(TrackSize.fixed(0), TrackSize.maxContent),
          TrackSize.fixed(40),
        ],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1', 'HH\u200bHH')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 40, 40),
      '2': Rect.fromLTWH(80, 0, 40, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 40, 40, 40),
      '5': Rect.fromLTWH(80, 40, 40, 40),
      '6': Rect.fromLTWH(0, 80, 40, 40),
      '7': Rect.fromLTWH(40, 80, 40, 40),
      '8': Rect.fromLTWH(80, 80, 40, 40),
    },
  ),
  (
    'grid_grid_max_content_single_item',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.maxContent, TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1', 'HH\u200bHH')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 40, 40),
      '2': Rect.fromLTWH(80, 0, 40, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 40, 40, 40),
      '5': Rect.fromLTWH(80, 40, 40, 40),
      '6': Rect.fromLTWH(0, 80, 40, 40),
      '7': Rect.fromLTWH(40, 80, 40, 40),
      '8': Rect.fromLTWH(80, 80, 40, 40),
    },
  ),
  (
    'grid_grid_max_content_single_item_margin_auto',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.maxContent, TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(
            autoMargin: AutoEdges(top: true, right: true, bottom: true, left: true),
            child: _a('1', 'HH\u200bHH'),
          ),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 15, 40, 10),
      '2': Rect.fromLTWH(80, 0, 40, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 40, 40, 40),
      '5': Rect.fromLTWH(80, 40, 40, 40),
      '6': Rect.fromLTWH(0, 80, 40, 40),
      '7': Rect.fromLTWH(40, 80, 40, 40),
      '8': Rect.fromLTWH(80, 80, 40, 40),
    },
  ),
  (
    'grid_grid_max_content_single_item_margin_fixed',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.maxContent, TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(margin: EdgeInsets.fromLTRB(20, 5, 10, 15), child: _a('1', 'HH\u200bHH')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 150, 120),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(60, 5, 40, 20),
      '2': Rect.fromLTWH(110, 0, 40, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 40, 70, 40),
      '5': Rect.fromLTWH(110, 40, 40, 40),
      '6': Rect.fromLTWH(0, 80, 40, 40),
      '7': Rect.fromLTWH(40, 80, 70, 40),
      '8': Rect.fromLTWH(110, 80, 40, 40),
    },
  ),
  (
    'grid_grid_max_content_single_item_span_2',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.maxContent, TrackSize.maxContent],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(columnSpan: 2, child: _a('1', 'HH\u200bHH')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 80, 120),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 40, 40),
      '2': Rect.fromLTWH(0, 40, 40, 40),
      '3': Rect.fromLTWH(40, 40, 20, 40),
      '4': Rect.fromLTWH(60, 40, 20, 40),
      '5': Rect.fromLTWH(0, 80, 40, 40),
      '6': Rect.fromLTWH(40, 80, 20, 40),
      '7': Rect.fromLTWH(60, 80, 20, 40),
      '8': Rect.fromLTWH(0, 120, 40, 0),
    },
  ),
  (
    'grid_grid_max_content_single_item_span_2_gap_fixed',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.maxContent, TrackSize.maxContent],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        spacing: 20,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(columnSpan: 2, child: _a('1', 'HH\u200bHH\u200bHH')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(60, 0, 60, 40),
      '2': Rect.fromLTWH(0, 40, 40, 40),
      '3': Rect.fromLTWH(60, 40, 20, 40),
      '4': Rect.fromLTWH(100, 40, 20, 40),
      '5': Rect.fromLTWH(0, 80, 40, 40),
      '6': Rect.fromLTWH(60, 80, 20, 40),
      '7': Rect.fromLTWH(100, 80, 20, 40),
      '8': Rect.fromLTWH(0, 120, 40, 0),
    },
  ),
  (
    'grid_grid_max_content_single_item_span_2_gap_percent_definite',
    () => _grid(
      width: 100,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.maxContent, TrackSize.maxContent],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        spacingFraction: 0.2,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(columnSpan: 2, child: _a('1', 'HH\u200bHH\u200bHH')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 100, 120),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(60, 0, 60, 40),
      '2': Rect.fromLTWH(0, 40, 40, 40),
      '3': Rect.fromLTWH(60, 40, 20, 40),
      '4': Rect.fromLTWH(100, 40, 20, 40),
      '5': Rect.fromLTWH(0, 80, 40, 40),
      '6': Rect.fromLTWH(60, 80, 20, 40),
      '7': Rect.fromLTWH(100, 80, 20, 40),
      '8': Rect.fromLTWH(0, 120, 40, 0),
    },
  ),
  (
    'grid_grid_max_content_single_item_span_2_gap_percent_indefinite',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.maxContent, TrackSize.maxContent],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        spacingFraction: 0.2,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(columnSpan: 2, child: _a('1', 'HH\u200bHH\u200bHH')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 100, 120),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(60, 0, 60, 40),
      '2': Rect.fromLTWH(0, 40, 40, 40),
      '3': Rect.fromLTWH(60, 40, 20, 40),
      '4': Rect.fromLTWH(100, 40, 20, 40),
      '5': Rect.fromLTWH(0, 80, 40, 40),
      '6': Rect.fromLTWH(60, 80, 20, 40),
      '7': Rect.fromLTWH(100, 80, 20, 40),
      '8': Rect.fromLTWH(0, 120, 40, 0),
    },
  ),
  (
    'grid_grid_min_content_flex_single_item',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.minContent, TrackSize.flex(1)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(minWidth: 10, child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(columnSpan: 2, child: _a('4', 'HH\u200bHH')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 80, 120),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 10, 40),
      '2': Rect.fromLTWH(50, 0, 30, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 40, 40, 40),
      '5': Rect.fromLTWH(0, 80, 40, 40),
      '6': Rect.fromLTWH(40, 80, 10, 40),
      '7': Rect.fromLTWH(50, 80, 30, 40),
    },
  ),
  (
    'grid_grid_min_content_flex_single_item_margin_auto',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.minContent, TrackSize.flex(1)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(
            minWidth: 10,
            autoMargin: AutoEdges(top: true, right: true, bottom: true, left: true),
            child: _a('1'),
          ),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(
            columnSpan: 2,
            autoMargin: AutoEdges(top: true, right: true, bottom: true, left: true),
            child: _a('4', 'HH\u200bHH'),
          ),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 80, 120),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 20, 10, 0),
      '2': Rect.fromLTWH(50, 0, 30, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 55, 40, 10),
      '5': Rect.fromLTWH(0, 80, 40, 40),
      '6': Rect.fromLTWH(40, 80, 10, 40),
      '7': Rect.fromLTWH(50, 80, 30, 40),
    },
  ),
  (
    'grid_grid_min_content_flex_single_item_margin_fixed',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.minContent, TrackSize.flex(1)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(minWidth: 10, margin: EdgeInsets.fromLTRB(20, 5, 10, 15), child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(columnSpan: 2, margin: EdgeInsets.fromLTRB(20, 5, 10, 15), child: _a('4', 'HH\u200bHH')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 110, 120),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(60, 5, 10, 20),
      '2': Rect.fromLTWH(80, 0, 30, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(60, 45, 40, 20),
      '5': Rect.fromLTWH(0, 80, 40, 40),
      '6': Rect.fromLTWH(40, 80, 40, 40),
      '7': Rect.fromLTWH(80, 80, 30, 40),
    },
  ),
  (
    'grid_grid_min_content_maximum_single_item',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.fixed(40),
          TrackSize.between(TrackSize.fixed(0), TrackSize.minContent),
          TrackSize.fixed(40),
        ],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1', 'HH\u200bHH')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 100, 120),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 20, 40),
      '2': Rect.fromLTWH(60, 0, 40, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 40, 20, 40),
      '5': Rect.fromLTWH(60, 40, 40, 40),
      '6': Rect.fromLTWH(0, 80, 40, 40),
      '7': Rect.fromLTWH(40, 80, 20, 40),
      '8': Rect.fromLTWH(60, 80, 40, 40),
    },
  ),
  (
    'grid_grid_min_content_single_item',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.minContent, TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1', 'HH\u200bHH')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 100, 120),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 20, 40),
      '2': Rect.fromLTWH(60, 0, 40, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 40, 20, 40),
      '5': Rect.fromLTWH(60, 40, 40, 40),
      '6': Rect.fromLTWH(0, 80, 40, 40),
      '7': Rect.fromLTWH(40, 80, 20, 40),
      '8': Rect.fromLTWH(60, 80, 40, 40),
    },
  ),
  (
    'grid_grid_minmax_auto_fixed_0px_with_sized_item',
    () => _grid(
      width: 100,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.auto, TrackSize.fixed(0))],
        rows: const [TrackSize.fixed(10), TrackSize.fixed(10)],
        children: [
          TrackCell(width: 60, child: _a('0')),
          TrackCell(child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 100, 20), '0': Rect.fromLTWH(0, 0, 60, 10), '1': Rect.fromLTWH(0, 10, 60, 10)},
  ),
  (
    'grid_grid_minmax_auto_fixed_10px',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.auto, TrackSize.fixed(10))],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HH\u200bHH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 10, 40), '0': Rect.fromLTWH(0, 0, 10, 40)},
  ),
  (
    'grid_grid_minmax_auto_max_content',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.auto, TrackSize.maxContent)],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HH\u200bHH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 40, 40), '0': Rect.fromLTWH(0, 0, 40, 40)},
  ),
  (
    'grid_grid_minmax_auto_min_content',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.auto, TrackSize.minContent)],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HH\u200bHH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 20, 40), '0': Rect.fromLTWH(0, 0, 20, 40)},
  ),
  (
    'grid_grid_minmax_auto_percent_definite',
    () => _grid(
      width: 100,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.auto, TrackSize.fraction(0.2))],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HH\u200bHH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 100, 40), '0': Rect.fromLTWH(0, 0, 20, 40)},
  ),
  (
    'grid_grid_minmax_auto_percent_indefinite',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.auto, TrackSize.fraction(0.2))],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HH\u200bHH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 40, 40), '0': Rect.fromLTWH(0, 0, 8, 40)},
  ),
  (
    'grid_grid_minmax_column_fixed_width_above_range',
    () => _grid(
      width: 140,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.fixed(40),
          TrackSize.between(TrackSize.fixed(20), TrackSize.fixed(40)),
          TrackSize.fixed(40),
        ],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 140, 120),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 40, 40),
      '2': Rect.fromLTWH(80, 0, 40, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 40, 40, 40),
      '5': Rect.fromLTWH(80, 40, 40, 40),
      '6': Rect.fromLTWH(0, 80, 40, 40),
      '7': Rect.fromLTWH(40, 80, 40, 40),
      '8': Rect.fromLTWH(80, 80, 40, 40),
    },
  ),
  (
    'grid_grid_minmax_column_fixed_width_below_range',
    () => _grid(
      width: 90,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.fixed(40),
          TrackSize.between(TrackSize.fixed(20), TrackSize.fixed(40)),
          TrackSize.fixed(40),
        ],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 90, 120),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 20, 40),
      '2': Rect.fromLTWH(60, 0, 40, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 40, 20, 40),
      '5': Rect.fromLTWH(60, 40, 40, 40),
      '6': Rect.fromLTWH(0, 80, 40, 40),
      '7': Rect.fromLTWH(40, 80, 20, 40),
      '8': Rect.fromLTWH(60, 80, 40, 40),
    },
  ),
  (
    'grid_grid_minmax_column_fixed_width_within_range',
    () => _grid(
      width: 110,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.fixed(40),
          TrackSize.between(TrackSize.fixed(20), TrackSize.fixed(40)),
          TrackSize.fixed(40),
        ],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 110, 120),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 30, 40),
      '2': Rect.fromLTWH(70, 0, 40, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 40, 30, 40),
      '5': Rect.fromLTWH(70, 40, 40, 40),
      '6': Rect.fromLTWH(0, 80, 40, 40),
      '7': Rect.fromLTWH(40, 80, 30, 40),
      '8': Rect.fromLTWH(70, 80, 40, 40),
    },
  ),
  (
    'grid_grid_minmax_column_indefinite',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.fixed(40),
          TrackSize.between(TrackSize.fixed(20), TrackSize.fixed(40)),
          TrackSize.fixed(40),
        ],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 40, 40),
      '2': Rect.fromLTWH(80, 0, 40, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 40, 40, 40),
      '5': Rect.fromLTWH(80, 40, 40, 40),
      '6': Rect.fromLTWH(0, 80, 40, 40),
      '7': Rect.fromLTWH(40, 80, 40, 40),
      '8': Rect.fromLTWH(80, 80, 40, 40),
    },
  ),
  (
    'grid_grid_minmax_column_with_auto_fixed',
    () => _grid(
      width: 60,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.fixed(20), TrackSize.fixed(40)), TrackSize.auto],
        rows: const [TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 60, 40), '0': Rect.fromLTWH(0, 0, 40, 40), '1': Rect.fromLTWH(40, 0, 20, 40)},
  ),
  (
    'grid_grid_minmax_column_with_fr_fixed',
    () => _grid(
      width: 60,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.fixed(20), TrackSize.fixed(40)), TrackSize.flex(1)],
        rows: const [TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 60, 40), '0': Rect.fromLTWH(0, 0, 40, 40), '1': Rect.fromLTWH(40, 0, 20, 40)},
  ),
  (
    'grid_grid_minmax_max_content_1fr',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.maxContent, TrackSize.flex(1))],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HH\u200bHH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 40, 40), '0': Rect.fromLTWH(0, 0, 40, 40)},
  ),
  (
    'grid_grid_minmax_max_content_auto',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.maxContent, TrackSize.auto)],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HH\u200bHH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 40, 40), '0': Rect.fromLTWH(0, 0, 40, 40)},
  ),
  (
    'grid_grid_minmax_max_content_fixed_10px',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.maxContent, TrackSize.fixed(10))],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HH\u200bHH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 40, 40), '0': Rect.fromLTWH(0, 0, 40, 40)},
  ),
  (
    'grid_grid_minmax_max_content_min_content',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.maxContent, TrackSize.minContent)],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HH\u200bHH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 40, 40), '0': Rect.fromLTWH(0, 0, 40, 40)},
  ),
  (
    'grid_grid_minmax_max_content_percent_definite',
    () => _grid(
      width: 100,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.maxContent, TrackSize.fraction(0.2))],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HH\u200bHH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 100, 40), '0': Rect.fromLTWH(0, 0, 40, 40)},
  ),
  (
    'grid_grid_minmax_max_content_percent_indefinite',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.maxContent, TrackSize.fraction(0.2))],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HH\u200bHH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 40, 40), '0': Rect.fromLTWH(0, 0, 40, 40)},
  ),
  (
    'grid_grid_minmax_min_content_1fr',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.minContent, TrackSize.flex(1))],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HH\u200bHH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 40, 40), '0': Rect.fromLTWH(0, 0, 40, 40)},
  ),
  (
    'grid_grid_minmax_min_content_auto',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.minContent, TrackSize.auto)],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HH\u200bHH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 40, 40), '0': Rect.fromLTWH(0, 0, 40, 40)},
  ),
  (
    'grid_grid_minmax_min_content_fixed_10px',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.minContent, TrackSize.fixed(10))],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HH\u200bHH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 20, 40), '0': Rect.fromLTWH(0, 0, 20, 40)},
  ),
  (
    'grid_grid_minmax_min_content_max_content',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.minContent, TrackSize.maxContent)],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HH\u200bHH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 40, 40), '0': Rect.fromLTWH(0, 0, 40, 40)},
  ),
  (
    'grid_grid_minmax_min_content_percent_definite',
    () => _grid(
      width: 100,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.minContent, TrackSize.fraction(0.2))],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HH\u200bHH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 100, 40), '0': Rect.fromLTWH(0, 0, 20, 40)},
  ),
  (
    'grid_grid_minmax_min_content_percent_indefinite',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.between(TrackSize.minContent, TrackSize.fraction(0.2))],
        rows: const [TrackSize.fixed(40)],
        children: [TrackCell(child: _a('0', 'HH\u200bHH'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 40, 40), '0': Rect.fromLTWH(0, 0, 20, 40)},
  ),
  (
    'grid_grid_out_of_order_items',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        flow: TrackFlow.rowDense,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(column: 0, width: 35, height: 35, child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(column: 0, row: 0, width: 20, height: 20, child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(row: 0, width: 10, height: 10, child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(80, 0, 40, 40),
      '1': Rect.fromLTWH(0, 40, 40, 40),
      '2': Rect.fromLTWH(0, 80, 35, 35),
      '3': Rect.fromLTWH(40, 40, 40, 40),
      '4': Rect.fromLTWH(80, 40, 40, 40),
      '5': Rect.fromLTWH(0, 0, 20, 20),
      '6': Rect.fromLTWH(40, 80, 40, 40),
      '7': Rect.fromLTWH(40, 0, 10, 10),
      '8': Rect.fromLTWH(80, 80, 40, 40),
    },
  ),
  (
    'grid_grid_overflow_inline_axis_hidden',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.zero,
      tracks: Tracks(children: [TrackCell(clips: true, child: _a('0', 'HHHHHHHHHH'))]),
    ),
    {'root': Rect.fromLTWH(0, 0, 50, 50), '0': Rect.fromLTWH(0, 0, 50, 50)},
  ),
  (
    'grid_grid_overflow_inline_axis_scroll',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.zero,
      tracks: Tracks(children: [TrackCell(clips: true, child: _a('0', 'HHHHHHHHHH'))]),
    ),
    {'root': Rect.fromLTWH(0, 0, 50, 50), '0': Rect.fromLTWH(0, 0, 50, 50)},
  ),
  (
    'grid_grid_overflow_inline_axis_visible',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.zero,
      tracks: Tracks(children: [TrackCell(child: _a('0', 'HHHHHHHHHH'))]),
    ),
    {'root': Rect.fromLTWH(0, 0, 50, 50), '0': Rect.fromLTWH(0, 0, 100, 50)},
  ),
  (
    'grid_grid_overflow_rows',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.minContent, TrackSize.maxContent, TrackSize.fixed(10), TrackSize.fraction(0.2)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(column: 0, columnSpan: 4, child: _a('0', 'HHHHHHHHHHHHHHHH\u200bHHHHHHHHHHHHHHHH')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 320, 80),
      '0': Rect.fromLTWH(0, 0, 320, 40),
      '1': Rect.fromLTWH(0, 40, 43, 40),
      '2': Rect.fromLTWH(43, 40, 203, 40),
      '3': Rect.fromLTWH(246, 40, 10, 40),
      '4': Rect.fromLTWH(256, 40, 64, 40),
      '5': Rect.fromLTWH(0, 80, 43, 0),
    },
  ),
  (
    'grid_grid_overlarge_auto_fill_tiny_tracks_huge_container',
    () => _grid(
      width: 100000,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.fill([TrackSize.fixed(1)]),
        ],
        children: [TrackCell(height: 20, child: _a('0'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 100000, 20), '0': Rect.fromLTWH(0, 0, 1, 20)},
  ),
  (
    'grid_grid_overlarge_auto_fill_zero_sized_tracks',
    () => _grid(
      width: 200,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.fill([TrackSize.fixed(0)]),
        ],
        children: [TrackCell(height: 20, child: _a('0'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 200, 20), '0': Rect.fromLTWH(0, 0, 0, 20)},
  ),
  (
    'grid_grid_overlarge_auto_flow_column_explicit_columns_large_negative_row_start',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.upTo(80),
          TrackSize.upTo(80),
          TrackSize.between(TrackSize.maxContent, TrackSize.auto),
        ],
        rows: const [TrackSize.auto],
        flow: TrackFlow.column,
        children: [
          TrackCell(column: 6, width: 20, height: 20, child: _a('0')),
          TrackCell(column: 6, width: 20, height: 20, child: _a('1')),
          TrackCell(column: 6, width: 20, height: 20, child: _a('2')),
          TrackCell(column: 6, row: -19552, width: 20, height: 20, child: _a('3')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 20, 80),
      '0': Rect.fromLTWH(0, 20, 20, 20),
      '1': Rect.fromLTWH(0, 40, 20, 20),
      '2': Rect.fromLTWH(0, 60, 20, 20),
      '3': Rect.fromLTWH(0, 0, 20, 20),
    },
  ),
  (
    'grid_grid_overlarge_auto_flow_column_large_negative_row_start',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        flow: TrackFlow.column,
        children: [
          TrackCell(column: 6, width: 20, height: 20, child: _a('0')),
          TrackCell(column: 6, width: 20, height: 20, child: _a('1')),
          TrackCell(column: 6, width: 20, height: 20, child: _a('2')),
          TrackCell(row: -19552, width: 20, height: 20, child: _a('3')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 40, 60),
      '0': Rect.fromLTWH(20, 0, 20, 20),
      '1': Rect.fromLTWH(20, 20, 20, 20),
      '2': Rect.fromLTWH(20, 40, 20, 20),
      '3': Rect.fromLTWH(0, 0, 20, 20),
    },
  ),
  (
    'grid_grid_overlarge_extreme_line_numbers',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        children: [
          TrackCell(column: 32766, row: -32767, width: 20, height: 20, child: _a('0')),
          TrackCell(
            column: -42768,
            row: 32766,
            columnEnd: -32768,
            rowSpan: 10000,
            width: 20,
            height: 20,
            child: _a('1'),
          ),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 40, 40), '0': Rect.fromLTWH(20, 0, 20, 20), '1': Rect.fromLTWH(0, 20, 20, 20)},
  ),
  (
    'grid_grid_overlarge_fixed_tracks_plus_auto_fill_repetition_over_limit',
    () => _grid(
      width: 200,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.repeat(9990, [TrackSize.fixed(0)]),
          TrackSize.fill([
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
          ]),
        ],
        children: [
          TrackCell(width: 20, height: 20, child: _a('0')),
          TrackCell(column: 10009, columnEnd: 10010, width: 20, height: 20, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 200, 20), '0': Rect.fromLTWH(0, 0, 20, 20), '1': Rect.fromLTWH(0, 0, 20, 20)},
  ),
  (
    'grid_grid_overlarge_fixed_tracks_plus_auto_fit_repetition_over_limit',
    () => _grid(
      width: 200,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.repeat(9995, [TrackSize.fixed(0)]),
          TrackSize.fit([
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
            TrackSize.fixed(0),
          ]),
        ],
        children: [
          TrackCell(column: 9989, columnSpan: 10, width: 20, height: 20, child: _a('0')),
          TrackCell(width: 20, height: 20, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 200, 20), '0': Rect.fromLTWH(0, 0, 20, 20), '1': Rect.fromLTWH(0, 0, 20, 20)},
  ),
  (
    'grid_grid_overlarge_huge_repeat_count',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.repeat(32768, [TrackSize.upTo(512)]),
          TrackSize.upToFraction(1),
        ],
        rows: const [TrackSize.fixed(90)],
        children: [TrackCell(width: 20, height: 20, child: _a('0'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 20, 90), '0': Rect.fromLTWH(0, 0, 20, 20)},
  ),
  (
    'grid_grid_overlarge_negative_line_with_explicit_tracks',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.repeat(9000, [TrackSize.fixed(0)]),
        ],
        children: [
          TrackCell(column: -19004, width: 20, height: 20, child: _a('0')),
          TrackCell(column: 8999, width: 20, height: 20, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 20, 20), '0': Rect.fromLTWH(0, 0, 20, 20), '1': Rect.fromLTWH(20, 0, 20, 20)},
  ),
  (
    'grid_grid_overlarge_repeat_track_count_product_overflow',
    () => _grid(
      width: 200,
      height: 100,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.repeat(40000, [TrackSize.fixed(10), TrackSize.fixed(10)]),
        ],
        children: [TrackCell(child: _a('0'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 200, 100), '0': Rect.fromLTWH(0, 0, 10, 100)},
  ),
  (
    'grid_grid_overlarge_span_crossing_max_line',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        autoColumns: const [TrackSize.fixed(0)],
        children: [TrackCell(column: 9994, columnSpan: 10, height: 20, child: _a('0'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 0, 20), '0': Rect.fromLTWH(0, 0, 0, 20)},
  ),
  (
    'grid_grid_overlarge_span_over_limit',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        autoColumns: const [TrackSize.fixed(0)],
        children: [TrackCell(column: 0, columnSpan: 20000, height: 20, child: _a('0'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 0, 20), '0': Rect.fromLTWH(0, 0, 0, 20)},
  ),
  (
    'grid_grid_overlarge_span_overflows_positive_limit',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        autoColumns: const [TrackSize.fixed(0)],
        children: [TrackCell(column: 9989, columnSpan: 50, height: 20, child: _a('0'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 0, 20), '0': Rect.fromLTWH(0, 0, 0, 20)},
  ),
  (
    'grid_grid_overlarge_span_to_negative_end',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.repeat(3, [TrackSize.fixed(10)]),
        ],
        children: [TrackCell(column: -10001, columnEnd: -1, height: 20, child: _a('0'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 30, 20), '0': Rect.fromLTWH(0, 0, 30, 20)},
  ),
  (
    'grid_grid_padding_border_overrides_container_size',
    () => _grid(
      width: 22,
      height: 14,
      frame: EdgeInsets.fromLTRB(15, 3, 7, 11),
      tracks: Tracks(children: [TrackCell(child: _a('0'))]),
    ),
    {'root': Rect.fromLTWH(0, 0, 22, 14), '0': Rect.fromLTWH(15, 3, 0, 0)},
  ),
  (
    'grid_grid_padding_border_overrides_max_size',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        children: [
          TrackCell(
            maxWidth: 22,
            maxHeight: 14,
            child: Padding(key: ValueKey('0'), padding: EdgeInsets.fromLTRB(15, 3, 7, 11), child: _Ahem('')),
          ),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 22, 14), '0': Rect.fromLTWH(0, 0, 22, 14)},
  ),
  (
    'grid_grid_padding_border_overrides_min_size',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        children: [
          TrackCell(
            minWidth: 22,
            minHeight: 14,
            child: Padding(key: ValueKey('0'), padding: EdgeInsets.fromLTRB(15, 3, 7, 11), child: _Ahem('')),
          ),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 22, 14), '0': Rect.fromLTWH(0, 0, 22, 14)},
  ),
  (
    'grid_grid_padding_border_overrides_size',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        children: [
          TrackCell(
            width: 22,
            height: 14,
            child: Padding(key: ValueKey('0'), padding: EdgeInsets.fromLTRB(15, 3, 7, 11), child: _Ahem('')),
          ),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 22, 14), '0': Rect.fromLTWH(0, 0, 22, 14)},
  ),
  (
    'grid_grid_percent_items_100_percent_2_col_auto',
    () => _grid(
      width: 200,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.auto, TrackSize.auto],
        rows: const [TrackSize.fixed(50), TrackSize.fixed(50)],
        children: [
          TrackCell(widthFraction: 1, height: 50, child: _a('0')),
          TrackCell(column: 1, row: 1, widthFraction: 1, height: 50, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 200, 100), '0': Rect.fromLTWH(0, 0, 100, 50), '1': Rect.fromLTWH(100, 50, 100, 50)},
  ),
  (
    'grid_grid_percent_items_100_percent_2_col_fr',
    () => _grid(
      width: 200,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.auto, TrackSize.auto],
        rows: const [TrackSize.fixed(50), TrackSize.fixed(50)],
        children: [
          TrackCell(widthFraction: 1, height: 50, child: _a('0')),
          TrackCell(column: 1, row: 1, widthFraction: 1, height: 50, child: _a('1')),
        ],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 200, 100), '0': Rect.fromLTWH(0, 0, 100, 50), '1': Rect.fromLTWH(100, 50, 100, 50)},
  ),
  (
    'grid_grid_percent_tracks_definite_overflow',
    () => _grid(
      width: 120,
      height: 60,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fraction(0.4), TrackSize.fraction(0.4), TrackSize.fraction(0.4)],
        rows: const [TrackSize.fraction(0.5), TrackSize.fraction(0.8)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 60),
      '0': Rect.fromLTWH(0, 0, 48, 30),
      '1': Rect.fromLTWH(48, 0, 48, 30),
      '2': Rect.fromLTWH(96, 0, 48, 30),
      '3': Rect.fromLTWH(0, 30, 48, 48),
      '4': Rect.fromLTWH(48, 30, 48, 48),
      '5': Rect.fromLTWH(96, 30, 48, 48),
    },
  ),
  (
    'grid_grid_percent_tracks_definite_underflow',
    () => _grid(
      width: 120,
      height: 60,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fraction(0.1), TrackSize.fraction(0.2), TrackSize.fraction(0.3)],
        rows: const [TrackSize.fraction(0.3), TrackSize.fraction(0.6)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 60),
      '0': Rect.fromLTWH(0, 0, 12, 18),
      '1': Rect.fromLTWH(12, 0, 24, 18),
      '2': Rect.fromLTWH(36, 0, 36, 18),
      '3': Rect.fromLTWH(0, 18, 12, 36),
      '4': Rect.fromLTWH(12, 18, 24, 36),
      '5': Rect.fromLTWH(36, 18, 36, 36),
    },
  ),
  (
    'grid_grid_percent_tracks_indefinite_only',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fraction(0.1), TrackSize.fraction(0.2), TrackSize.fraction(0.3)],
        rows: const [TrackSize.fraction(0.3), TrackSize.fraction(0.6)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 0, 0),
      '0': Rect.fromLTWH(0, 0, 0, 0),
      '1': Rect.fromLTWH(0, 0, 0, 0),
      '2': Rect.fromLTWH(0, 0, 0, 0),
      '3': Rect.fromLTWH(0, 0, 0, 0),
      '4': Rect.fromLTWH(0, 0, 0, 0),
      '5': Rect.fromLTWH(0, 0, 0, 0),
    },
  ),
  (
    'grid_grid_percent_tracks_indefinite_with_content_overflow',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fraction(0.4), TrackSize.fraction(0.4), TrackSize.fraction(0.4)],
        rows: const [TrackSize.fraction(0.5), TrackSize.fraction(0.8)],
        children: [
          TrackCell(column: 0, row: 0, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 100, 100),
      '0': Rect.fromLTWH(0, 0, 100, 100),
      '1': Rect.fromLTWH(0, 0, 40, 50),
      '2': Rect.fromLTWH(40, 0, 40, 50),
      '3': Rect.fromLTWH(80, 0, 40, 50),
      '4': Rect.fromLTWH(0, 50, 40, 80),
      '5': Rect.fromLTWH(40, 50, 40, 80),
      '6': Rect.fromLTWH(80, 50, 40, 80),
    },
  ),
  (
    'grid_grid_percent_tracks_indefinite_with_content_underflow',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fraction(0.1), TrackSize.fraction(0.2), TrackSize.fraction(0.3)],
        rows: const [TrackSize.fraction(0.3), TrackSize.fraction(0.6)],
        children: [
          TrackCell(column: 0, row: 0, width: 100, height: 100, child: _a('0')),
          TrackCell(column: 0, row: 0, child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 100, 100),
      '0': Rect.fromLTWH(0, 0, 100, 100),
      '1': Rect.fromLTWH(0, 0, 10, 30),
      '2': Rect.fromLTWH(10, 0, 20, 30),
      '3': Rect.fromLTWH(30, 0, 30, 30),
      '4': Rect.fromLTWH(0, 30, 10, 60),
      '5': Rect.fromLTWH(10, 30, 20, 60),
      '6': Rect.fromLTWH(30, 30, 30, 60),
    },
  ),
  (
    'grid_grid_placement_auto_negative',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(column: -4, row: 0, child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(row: 1, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(0, 0, 20, 40),
      '1': Rect.fromLTWH(20, 0, 20, 40),
      '2': Rect.fromLTWH(0, 40, 20, 40),
    },
  ),
  (
    'grid_grid_placement_definite_in_secondary_axis_with_fully_definite_negative',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(row: 1, child: _a('0')),
          TrackCell(column: -3, row: 1, child: _a('1')),
          TrackCell(row: 0, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(40, 40, 40, 40),
      '1': Rect.fromLTWH(0, 40, 40, 40),
      '2': Rect.fromLTWH(0, 0, 40, 40),
    },
  ),
  (
    'grid_grid_placement_definite_primary',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fraction(0.33), TrackSize.fraction(0.74)],
        children: [
          TrackCell(column: 0, child: _a('0')),
          TrackCell(column: 1, child: _a('1')),
          TrackCell(column: 0, child: _a('2')),
          TrackCell(column: 1, child: _a('3')),
          TrackCell(column: 0, child: _a('4')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(0, 0, 66, 66.66),
      '1': Rect.fromLTWH(66, 0, 148, 66.66),
      '2': Rect.fromLTWH(0, 66.66, 66, 66.67),
      '3': Rect.fromLTWH(66, 66.66, 148, 66.67),
      '4': Rect.fromLTWH(0, 133.33, 66, 66.67),
    },
  ),
  (
    'grid_grid_repeat_integer',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.repeat(3, [TrackSize.fixed(40)]),
        ],
        rows: const [
          TrackSize.repeat(3, [TrackSize.fixed(40)]),
        ],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 40, 40),
      '2': Rect.fromLTWH(80, 0, 40, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 40, 40, 40),
      '5': Rect.fromLTWH(80, 40, 40, 40),
      '6': Rect.fromLTWH(0, 80, 40, 40),
      '7': Rect.fromLTWH(40, 80, 40, 40),
      '8': Rect.fromLTWH(80, 80, 40, 40),
    },
  ),
  (
    'grid_grid_repeat_mixed',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.fixed(40),
          TrackSize.repeat(1, [TrackSize.fixed(40)]),
          TrackSize.fill([TrackSize.fixed(40)]),
        ],
        rows: const [
          TrackSize.fixed(40),
          TrackSize.repeat(1, [TrackSize.fixed(40)]),
          TrackSize.fill([TrackSize.fixed(40)]),
        ],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 40, 40),
      '2': Rect.fromLTWH(80, 0, 40, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 40, 40, 40),
      '5': Rect.fromLTWH(80, 40, 40, 40),
      '6': Rect.fromLTWH(0, 80, 40, 40),
      '7': Rect.fromLTWH(40, 80, 40, 40),
      '8': Rect.fromLTWH(80, 80, 40, 40),
    },
  ),
  (
    'grid_grid_safe_align_content_center_overflow',
    () => _grid(
      width: 100,
      height: 100,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        alignContent: TrackContent.safeCenter,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 100, 100),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 40, 40),
      '2': Rect.fromLTWH(80, 0, 40, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 40, 40, 40),
      '5': Rect.fromLTWH(80, 40, 40, 40),
      '6': Rect.fromLTWH(0, 80, 40, 40),
      '7': Rect.fromLTWH(40, 80, 40, 40),
      '8': Rect.fromLTWH(80, 80, 40, 40),
    },
  ),
  (
    'grid_grid_safe_align_content_end_overflow',
    () => _grid(
      width: 100,
      height: 100,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        alignContent: TrackContent.safeEnd,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 100, 100),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 40, 40),
      '2': Rect.fromLTWH(80, 0, 40, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 40, 40, 40),
      '5': Rect.fromLTWH(80, 40, 40, 40),
      '6': Rect.fromLTWH(0, 80, 40, 40),
      '7': Rect.fromLTWH(40, 80, 40, 40),
      '8': Rect.fromLTWH(80, 80, 40, 40),
    },
  ),
  (
    'grid_grid_safe_align_self_end_no_overflow',
    () => _grid(
      width: 100,
      height: 100,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(100)],
        rows: const [TrackSize.fixed(100)],
        children: [TrackCell(width: 50, height: 40, align: CellAlign.safeEnd, child: _a('0'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 100, 100), '0': Rect.fromLTWH(0, 60, 50, 40)},
  ),
  (
    'grid_grid_safe_align_self_end_overflow',
    () => _grid(
      width: 100,
      height: 100,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(100)],
        rows: const [TrackSize.fixed(100)],
        children: [TrackCell(width: 50, height: 150, align: CellAlign.safeEnd, child: _a('0'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 100, 100), '0': Rect.fromLTWH(0, 0, 50, 150)},
  ),
  (
    'grid_grid_safe_justify_content_center_overflow',
    () => _grid(
      width: 100,
      height: 100,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        justifyContent: TrackContent.safeCenter,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 100, 100),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 40, 40),
      '2': Rect.fromLTWH(80, 0, 40, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 40, 40, 40),
      '5': Rect.fromLTWH(80, 40, 40, 40),
      '6': Rect.fromLTWH(0, 80, 40, 40),
      '7': Rect.fromLTWH(40, 80, 40, 40),
      '8': Rect.fromLTWH(80, 80, 40, 40),
    },
  ),
  (
    'grid_grid_safe_justify_content_end_no_overflow',
    () => _grid(
      width: 200,
      height: 200,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        justifyContent: TrackContent.safeEnd,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 200, 200),
      '0': Rect.fromLTWH(80, 0, 40, 40),
      '1': Rect.fromLTWH(120, 0, 40, 40),
      '2': Rect.fromLTWH(160, 0, 40, 40),
      '3': Rect.fromLTWH(80, 40, 40, 40),
      '4': Rect.fromLTWH(120, 40, 40, 40),
      '5': Rect.fromLTWH(160, 40, 40, 40),
      '6': Rect.fromLTWH(80, 80, 40, 40),
      '7': Rect.fromLTWH(120, 80, 40, 40),
      '8': Rect.fromLTWH(160, 80, 40, 40),
    },
  ),
  (
    'grid_grid_safe_justify_content_end_overflow',
    () => _grid(
      width: 100,
      height: 100,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        justifyContent: TrackContent.safeEnd,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 100, 100),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 40, 40),
      '2': Rect.fromLTWH(80, 0, 40, 40),
      '3': Rect.fromLTWH(0, 40, 40, 40),
      '4': Rect.fromLTWH(40, 40, 40, 40),
      '5': Rect.fromLTWH(80, 40, 40, 40),
      '6': Rect.fromLTWH(0, 80, 40, 40),
      '7': Rect.fromLTWH(40, 80, 40, 40),
      '8': Rect.fromLTWH(80, 80, 40, 40),
    },
  ),
  (
    'grid_grid_safe_justify_self_center_overflow',
    () => _grid(
      width: 100,
      height: 100,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(100)],
        rows: const [TrackSize.fixed(100)],
        children: [TrackCell(width: 150, height: 50, justify: CellAlign.safeCenter, child: _a('0'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 100, 100), '0': Rect.fromLTWH(0, 0, 150, 50)},
  ),
  (
    'grid_grid_safe_justify_self_end_overflow',
    () => _grid(
      width: 100,
      height: 100,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(100)],
        rows: const [TrackSize.fixed(100)],
        children: [TrackCell(width: 150, height: 50, justify: CellAlign.safeEnd, child: _a('0'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 100, 100), '0': Rect.fromLTWH(0, 0, 150, 50)},
  ),
  (
    'grid_grid_size_child_fixed_tracks',
    () => _grid(
      width: 120,
      height: 120,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(align: CellAlign.start, justify: CellAlign.start, child: _a('0', 'HH\u200bHH\u200bHH\u200bHH')),
          TrackCell(align: CellAlign.start, justify: CellAlign.start, child: _a('1', 'HHH\u200bHHH')),
          TrackCell(align: CellAlign.start, justify: CellAlign.start, child: _a('2', 'HH\u200bHHHH')),
          TrackCell(
            width: 20,
            align: CellAlign.start,
            justify: CellAlign.start,
            child: _a('3', 'HH\u200bHH\u200bHH\u200bHH'),
          ),
          TrackCell(
            maxWidth: 30,
            align: CellAlign.start,
            justify: CellAlign.start,
            child: _a('4', 'HH\u200bHH\u200bHH\u200bHH'),
          ),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 120, 120),
      '0': Rect.fromLTWH(0, 0, 40, 20),
      '1': Rect.fromLTWH(40, 0, 40, 20),
      '2': Rect.fromLTWH(80, 0, 40, 20),
      '3': Rect.fromLTWH(0, 40, 20, 40),
      '4': Rect.fromLTWH(40, 40, 30, 40),
    },
  ),
  (
    'grid_grid_span_13_most_non_flex_with_minmax_indefinite',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.minContent,
          TrackSize.maxContent,
          TrackSize.upTo(20),
          TrackSize.auto,
          TrackSize.fixed(10),
          TrackSize.fraction(0.2),
          TrackSize.between(TrackSize.fixed(2), TrackSize.auto),
          TrackSize.between(TrackSize.fixed(2), TrackSize.fixed(4)),
          TrackSize.between(TrackSize.fixed(2), TrackSize.minContent),
          TrackSize.between(TrackSize.fixed(2), TrackSize.maxContent),
          TrackSize.between(TrackSize.minContent, TrackSize.maxContent),
          TrackSize.between(TrackSize.minContent, TrackSize.auto),
          TrackSize.between(TrackSize.maxContent, TrackSize.auto),
        ],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(column: 0, columnSpan: 13, child: _a('0', 'HHHHHHHHHHHHHHHH\u200bHHHHHHHHHHHHHHHH')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
          TrackCell(child: _a('9')),
          TrackCell(child: _a('10')),
          TrackCell(child: _a('11')),
          TrackCell(child: _a('12')),
          TrackCell(child: _a('13')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 322, 80),
      '0': Rect.fromLTWH(0, 0, 322, 40),
      '1': Rect.fromLTWH(0, 40, 11.08, 40),
      '2': Rect.fromLTWH(11.08, 40, 91.08, 40),
      '3': Rect.fromLTWH(102.16, 40, 11.08, 40),
      '4': Rect.fromLTWH(113.23, 40, 11.09, 40),
      '5': Rect.fromLTWH(124.33, 40, 10, 40),
      '6': Rect.fromLTWH(134.33, 40, 64.39, 40),
      '7': Rect.fromLTWH(198.72, 40, 2, 40),
      '8': Rect.fromLTWH(200.72, 40, 4, 40),
      '9': Rect.fromLTWH(204.72, 40, 2, 40),
      '10': Rect.fromLTWH(206.72, 40, 2, 40),
      '11': Rect.fromLTWH(208.72, 40, 11.09, 40),
      '12': Rect.fromLTWH(219.81, 40, 11.09, 40),
      '13': Rect.fromLTWH(230.91, 40, 91.09, 40),
    },
  ),
  (
    'grid_grid_span_13_most_non_flex_with_minmax_indefinite_hidden',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.minContent,
          TrackSize.maxContent,
          TrackSize.upTo(20),
          TrackSize.auto,
          TrackSize.fixed(10),
          TrackSize.fraction(0.2),
          TrackSize.between(TrackSize.fixed(2), TrackSize.auto),
          TrackSize.between(TrackSize.fixed(2), TrackSize.fixed(4)),
          TrackSize.between(TrackSize.fixed(2), TrackSize.minContent),
          TrackSize.between(TrackSize.fixed(2), TrackSize.maxContent),
          TrackSize.between(TrackSize.minContent, TrackSize.maxContent),
          TrackSize.between(TrackSize.minContent, TrackSize.auto),
          TrackSize.between(TrackSize.maxContent, TrackSize.auto),
        ],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(column: 0, columnSpan: 13, clips: true, child: _a('0', 'HHHHHHHHHHHHHHHH\u200bHHHHHHHHHHHHHHHH')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
          TrackCell(child: _a('9')),
          TrackCell(child: _a('10')),
          TrackCell(child: _a('11')),
          TrackCell(child: _a('12')),
          TrackCell(child: _a('13')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 322, 80),
      '0': Rect.fromLTWH(0, 0, 322, 40),
      '1': Rect.fromLTWH(0, 40, 15.52, 40),
      '2': Rect.fromLTWH(15.52, 40, 95.52, 40),
      '3': Rect.fromLTWH(111.03, 40, 0, 40),
      '4': Rect.fromLTWH(111.03, 40, 0, 40),
      '5': Rect.fromLTWH(111.03, 40, 10, 40),
      '6': Rect.fromLTWH(121.03, 40, 64.39, 40),
      '7': Rect.fromLTWH(185.42, 40, 2, 40),
      '8': Rect.fromLTWH(187.42, 40, 4, 40),
      '9': Rect.fromLTWH(191.42, 40, 2, 40),
      '10': Rect.fromLTWH(193.42, 40, 2, 40),
      '11': Rect.fromLTWH(195.42, 40, 15.52, 40),
      '12': Rect.fromLTWH(210.94, 40, 15.53, 40),
      '13': Rect.fromLTWH(226.47, 40, 95.53, 40),
    },
  ),
  (
    'grid_grid_span_2_max_content_auto_indefinite',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.maxContent, TrackSize.auto],
        rows: const [TrackSize.fixed(40)],
        children: [
          TrackCell(column: 0, row: 0, child: _a('0')),
          TrackCell(column: 1, row: 0, child: _a('1')),
          TrackCell(column: 0, row: 0, columnSpan: 2, child: _a('2', 'HHHH\u200bHHHH')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 80, 40),
      '0': Rect.fromLTWH(0, 0, 60, 40),
      '1': Rect.fromLTWH(60, 0, 20, 40),
      '2': Rect.fromLTWH(0, 0, 80, 40),
    },
  ),
  (
    'grid_grid_span_2_max_content_auto_indefinite_hidden',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.maxContent, TrackSize.auto],
        rows: const [TrackSize.fixed(40)],
        children: [
          TrackCell(column: 0, row: 0, child: _a('0')),
          TrackCell(column: 1, row: 0, child: _a('1')),
          TrackCell(column: 0, row: 0, columnSpan: 2, clips: true, child: _a('2', 'HHHH\u200bHHHH')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 80, 40),
      '0': Rect.fromLTWH(0, 0, 80, 40),
      '1': Rect.fromLTWH(80, 0, 0, 40),
      '2': Rect.fromLTWH(0, 0, 80, 40),
    },
  ),
  (
    'grid_grid_span_2_max_content_fit_content_10px_indefinite',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.maxContent, TrackSize.upTo(10)],
        rows: const [TrackSize.fixed(40)],
        children: [
          TrackCell(column: 0, row: 0, child: _a('0')),
          TrackCell(column: 1, row: 0, child: _a('1')),
          TrackCell(column: 0, row: 0, columnSpan: 2, child: _a('2', 'HHHH\u200bHHHH')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 80, 40),
      '0': Rect.fromLTWH(0, 0, 60, 40),
      '1': Rect.fromLTWH(60, 0, 20, 40),
      '2': Rect.fromLTWH(0, 0, 80, 40),
    },
  ),
  (
    'grid_grid_span_2_max_content_fit_content_10px_indefinite_hidden',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.maxContent, TrackSize.upTo(10)],
        rows: const [TrackSize.fixed(40)],
        children: [
          TrackCell(column: 0, row: 0, child: _a('0')),
          TrackCell(column: 1, row: 0, child: _a('1')),
          TrackCell(column: 0, row: 0, columnSpan: 2, clips: true, child: _a('2', 'HHHH\u200bHHHH')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 80, 40),
      '0': Rect.fromLTWH(0, 0, 80, 40),
      '1': Rect.fromLTWH(80, 0, 0, 40),
      '2': Rect.fromLTWH(0, 0, 80, 40),
    },
  ),
  (
    'grid_grid_span_2_max_content_fit_content_80px_indefinite',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.maxContent, TrackSize.upTo(80)],
        rows: const [TrackSize.fixed(40)],
        children: [
          TrackCell(column: 0, row: 0, child: _a('0')),
          TrackCell(column: 1, row: 0, child: _a('1')),
          TrackCell(column: 0, row: 0, columnSpan: 2, child: _a('2', 'HHHH\u200bHHHH')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 80, 40),
      '0': Rect.fromLTWH(0, 0, 60, 40),
      '1': Rect.fromLTWH(60, 0, 20, 40),
      '2': Rect.fromLTWH(0, 0, 80, 40),
    },
  ),
  (
    'grid_grid_span_2_max_content_fit_content_80px_indefinite_hidden',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.maxContent, TrackSize.upTo(80)],
        rows: const [TrackSize.fixed(40)],
        children: [
          TrackCell(column: 0, row: 0, child: _a('0')),
          TrackCell(column: 1, row: 0, child: _a('1')),
          TrackCell(column: 0, row: 0, columnSpan: 2, clips: true, child: _a('2', 'HHHH\u200bHHHH')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 80, 40),
      '0': Rect.fromLTWH(0, 0, 80, 40),
      '1': Rect.fromLTWH(80, 0, 0, 40),
      '2': Rect.fromLTWH(0, 0, 80, 40),
    },
  ),
  (
    'grid_grid_span_2_max_content_max_content_indefinite',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.maxContent, TrackSize.maxContent],
        rows: const [TrackSize.fixed(40)],
        children: [
          TrackCell(column: 0, row: 0, child: _a('0')),
          TrackCell(column: 1, row: 0, child: _a('1')),
          TrackCell(column: 0, row: 0, columnSpan: 2, child: _a('2', 'HHHH\u200bHHHH')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 80, 40),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 40, 40),
      '2': Rect.fromLTWH(0, 0, 80, 40),
    },
  ),
  (
    'grid_grid_span_2_min_content_auto_indefinite',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.minContent, TrackSize.auto],
        rows: const [TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(column: 0, columnSpan: 2, child: _a('2', 'HHHH\u200bHHHH')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 80, 50),
      '0': Rect.fromLTWH(0, 0, 20, 40),
      '1': Rect.fromLTWH(20, 0, 60, 40),
      '2': Rect.fromLTWH(0, 40, 80, 10),
    },
  ),
  (
    'grid_grid_span_2_min_content_auto_indefinite_hidden',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.minContent, TrackSize.auto],
        rows: const [TrackSize.fixed(40)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(column: 0, columnSpan: 2, clips: true, child: _a('2', 'HHHH\u200bHHHH')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 80, 50),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 40, 40),
      '2': Rect.fromLTWH(0, 40, 80, 10),
    },
  ),
  (
    'grid_grid_span_2_min_content_fit_content_10px_indefinite',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.minContent, TrackSize.upTo(10)],
        rows: const [TrackSize.fixed(40)],
        children: [
          TrackCell(column: 0, row: 0, child: _a('0')),
          TrackCell(column: 1, row: 0, child: _a('1')),
          TrackCell(column: 0, row: 0, columnSpan: 2, child: _a('2', 'HHHH\u200bHHHH')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 40, 40),
      '0': Rect.fromLTWH(0, 0, 20, 40),
      '1': Rect.fromLTWH(20, 0, 20, 40),
      '2': Rect.fromLTWH(0, 0, 40, 40),
    },
  ),
  (
    'grid_grid_span_2_min_content_fit_content_10px_indefinite_hidden',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.minContent, TrackSize.upTo(10)],
        rows: const [TrackSize.fixed(40)],
        children: [
          TrackCell(column: 0, row: 0, child: _a('0')),
          TrackCell(column: 1, row: 0, child: _a('1')),
          TrackCell(column: 0, row: 0, columnSpan: 2, clips: true, child: _a('2', 'HHHH\u200bHHHH')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 40),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 10, 40),
      '2': Rect.fromLTWH(0, 0, 50, 40),
    },
  ),
  (
    'grid_grid_span_2_min_content_fit_content_30px_indefinite',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.minContent, TrackSize.upTo(30)],
        rows: const [TrackSize.fixed(40)],
        children: [
          TrackCell(column: 0, row: 0, child: _a('0')),
          TrackCell(column: 1, row: 0, child: _a('1')),
          TrackCell(column: 0, row: 0, columnSpan: 2, child: _a('2', 'HHHH\u200bHHHH')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 50, 40),
      '0': Rect.fromLTWH(0, 0, 20, 40),
      '1': Rect.fromLTWH(20, 0, 30, 40),
      '2': Rect.fromLTWH(0, 0, 50, 40),
    },
  ),
  (
    'grid_grid_span_2_min_content_fit_content_30px_indefinite_hidden',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.minContent, TrackSize.upTo(30)],
        rows: const [TrackSize.fixed(40)],
        children: [
          TrackCell(column: 0, row: 0, child: _a('0')),
          TrackCell(column: 1, row: 0, child: _a('1')),
          TrackCell(column: 0, row: 0, columnSpan: 2, clips: true, child: _a('2', 'HHHH\u200bHHHH')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 70, 40),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 30, 40),
      '2': Rect.fromLTWH(0, 0, 70, 40),
    },
  ),
  (
    'grid_grid_span_2_min_content_fit_content_80px_indefinite',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.minContent, TrackSize.upTo(80)],
        rows: const [TrackSize.fixed(40)],
        children: [
          TrackCell(column: 0, row: 0, child: _a('0')),
          TrackCell(column: 1, row: 0, child: _a('1')),
          TrackCell(column: 0, row: 0, columnSpan: 2, child: _a('2', 'HHHH\u200bHHHH')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 80, 40),
      '0': Rect.fromLTWH(0, 0, 20, 40),
      '1': Rect.fromLTWH(20, 0, 60, 40),
      '2': Rect.fromLTWH(0, 0, 80, 40),
    },
  ),
  (
    'grid_grid_span_2_min_content_fit_content_80px_indefinite_hidden',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.minContent, TrackSize.upTo(80)],
        rows: const [TrackSize.fixed(40)],
        children: [
          TrackCell(column: 0, row: 0, child: _a('0')),
          TrackCell(column: 1, row: 0, child: _a('1')),
          TrackCell(column: 0, row: 0, columnSpan: 2, clips: true, child: _a('2', 'HHHH\u200bHHHH')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 80, 40),
      '0': Rect.fromLTWH(0, 0, 40, 40),
      '1': Rect.fromLTWH(40, 0, 40, 40),
      '2': Rect.fromLTWH(0, 0, 80, 40),
    },
  ),
  (
    'grid_grid_span_2_min_content_max_content_indefinite',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.minContent, TrackSize.maxContent],
        rows: const [TrackSize.fixed(40)],
        children: [
          TrackCell(column: 0, row: 0, child: _a('0')),
          TrackCell(column: 1, row: 0, child: _a('1')),
          TrackCell(column: 0, row: 0, columnSpan: 2, child: _a('2', 'HHHH\u200bHHHH')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 80, 40),
      '0': Rect.fromLTWH(0, 0, 20, 40),
      '1': Rect.fromLTWH(20, 0, 60, 40),
      '2': Rect.fromLTWH(0, 0, 80, 40),
    },
  ),
  (
    'grid_grid_span_2_min_content_min_content_indefinite',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.minContent, TrackSize.minContent],
        rows: const [TrackSize.fixed(40)],
        children: [
          TrackCell(column: 0, row: 0, child: _a('0')),
          TrackCell(column: 1, row: 0, child: _a('1')),
          TrackCell(column: 0, row: 0, columnSpan: 2, child: _a('2', 'HHHH\u200bHHHH')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 40, 40),
      '0': Rect.fromLTWH(0, 0, 20, 40),
      '1': Rect.fromLTWH(20, 0, 20, 40),
      '2': Rect.fromLTWH(0, 0, 40, 40),
    },
  ),
  (
    'grid_grid_span_6_all_non_flex_indefinite',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.minContent,
          TrackSize.maxContent,
          TrackSize.upTo(20),
          TrackSize.auto,
          TrackSize.fixed(10),
          TrackSize.fraction(0.2),
        ],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(column: 0, columnSpan: 6, child: _a('0', 'HHHHHHHH\u200bHHHHHHHH')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 160, 80),
      '0': Rect.fromLTWH(0, 0, 160, 40),
      '1': Rect.fromLTWH(0, 40, 9.5, 40),
      '2': Rect.fromLTWH(9.5, 40, 89.5, 40),
      '3': Rect.fromLTWH(99, 40, 9.5, 40),
      '4': Rect.fromLTWH(108.5, 40, 9.5, 40),
      '5': Rect.fromLTWH(118, 40, 10, 40),
      '6': Rect.fromLTWH(128, 40, 32, 40),
    },
  ),
  (
    'grid_grid_span_6_all_non_flex_indefinite_hidden',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.minContent,
          TrackSize.maxContent,
          TrackSize.upTo(20),
          TrackSize.auto,
          TrackSize.fixed(10),
          TrackSize.fraction(0.2),
        ],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(column: 0, columnSpan: 6, clips: true, child: _a('0', 'HHHHHHHH\u200bHHHHHHHH')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 160, 80),
      '0': Rect.fromLTWH(0, 0, 160, 40),
      '1': Rect.fromLTWH(0, 40, 19, 40),
      '2': Rect.fromLTWH(19, 40, 99, 40),
      '3': Rect.fromLTWH(118, 40, 0, 40),
      '4': Rect.fromLTWH(118, 40, 0, 40),
      '5': Rect.fromLTWH(118, 40, 10, 40),
      '6': Rect.fromLTWH(128, 40, 32, 40),
    },
  ),
  (
    'grid_grid_span_8_all_track_types_indefinite',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [
          TrackSize.minContent,
          TrackSize.maxContent,
          TrackSize.upTo(20),
          TrackSize.auto,
          TrackSize.fixed(10),
          TrackSize.fraction(0.2),
          TrackSize.flex(1),
          TrackSize.flex(2),
        ],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(column: 0, columnSpan: 8, child: _a('0', 'HHHHHHHH\u200bHHHHHHHH')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 160, 80),
      '0': Rect.fromLTWH(0, 0, 160, 40),
      '1': Rect.fromLTWH(0, 40, 0, 40),
      '2': Rect.fromLTWH(0, 40, 0, 40),
      '3': Rect.fromLTWH(0, 40, 0, 40),
      '4': Rect.fromLTWH(0, 40, 0, 40),
      '5': Rect.fromLTWH(0, 40, 10, 40),
      '6': Rect.fromLTWH(10, 40, 32, 40),
      '7': Rect.fromLTWH(42, 40, 39.33, 40),
      '8': Rect.fromLTWH(81.33, 40, 78.67, 40),
    },
  ),
  (
    'grid_grid_taffy_issue_624',
    () => _grid(
      width: 320,
      height: 640,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.auto, TrackSize.auto, TrackSize.flex(1)],
        rows: const [TrackSize.auto, TrackSize.auto, TrackSize.auto, TrackSize.flex(1)],
        justify: CellAlign.start,
        justifyContent: TrackContent.start,
        children: [
          TrackCell(column: 0, row: 0, rowSpan: 2, width: 100, height: 50, child: _a('0')),
          TrackCell(column: 1, row: 0, columnSpan: 2, rowSpan: 2, width: 40, height: 30, child: _a('1')),
          TrackCell(column: 0, row: 2, columnSpan: 2, width: 120, height: 20, child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 320, 640),
      '0': Rect.fromLTWH(0, 0, 100, 50),
      '1': Rect.fromLTWH(100, 0, 40, 30),
      '2': Rect.fromLTWH(0, 50, 120, 20),
    },
  ),
  (
    'grid_grid_template_serialization_fractional_tracks',
    () => _grid(
      width: 100,
      height: 50,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.flex(1), TrackSize.flex(1), TrackSize.flex(1)],
        rows: const [TrackSize.between(TrackSize.fixed(10), TrackSize.flex(1)), TrackSize.flex(2)],
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 100, 50),
      '0': Rect.fromLTWH(0, 0, 33.33, 16.66),
      '1': Rect.fromLTWH(33.33, 0, 33.33, 16.66),
      '2': Rect.fromLTWH(66.66, 0, 33.33, 16.66),
    },
  ),
  (
    'grid_grid_template_serialization_negative_implicit_column',
    () => _grid(
      width: 10,
      height: 10,
      frame: EdgeInsets.zero,
      tracks: Tracks(children: [TrackCell(columnEnd: 0, width: 10, height: 10, child: _a('0'))]),
    ),
    {'root': Rect.fromLTWH(0, 0, 10, 10), '0': Rect.fromLTWH(0, 0, 10, 10)},
  ),
  (
    'grid_grid_template_serialization_negative_implicit_row',
    () => _grid(
      width: 10,
      height: 10,
      frame: EdgeInsets.zero,
      tracks: Tracks(children: [TrackCell(rowEnd: 0, width: 10, height: 10, child: _a('0'))]),
    ),
    {'root': Rect.fromLTWH(0, 0, 10, 10), '0': Rect.fromLTWH(0, 0, 10, 10)},
  ),
  (
    'grid_grid_template_serialization_none',
    () => _grid(
      width: 50,
      height: 50,
      frame: EdgeInsets.zero,
      tracks: Tracks(children: []),
    ),
    {'root': Rect.fromLTWH(0, 0, 50, 50)},
  ),
  (
    'grid_grid_unsafe_align_self_end_overflow',
    () => _grid(
      width: 100,
      height: 100,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(100)],
        rows: const [TrackSize.fixed(100)],
        children: [TrackCell(width: 50, height: 150, align: CellAlign.end, child: _a('0'))],
      ),
    ),
    {'root': Rect.fromLTWH(0, 0, 100, 100), '0': Rect.fromLTWH(0, -50, 50, 150)},
  ),
  (
    'grid_grid_unsafe_justify_content_end_overflow',
    () => _grid(
      width: 100,
      height: 100,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40), TrackSize.fixed(40)],
        justifyContent: TrackContent.end,
        children: [
          TrackCell(child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
          TrackCell(child: _a('5')),
          TrackCell(child: _a('6')),
          TrackCell(child: _a('7')),
          TrackCell(child: _a('8')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 100, 100),
      '0': Rect.fromLTWH(-20, 0, 40, 40),
      '1': Rect.fromLTWH(20, 0, 40, 40),
      '2': Rect.fromLTWH(60, 0, 40, 40),
      '3': Rect.fromLTWH(-20, 40, 40, 40),
      '4': Rect.fromLTWH(20, 40, 40, 40),
      '5': Rect.fromLTWH(60, 40, 40, 40),
      '6': Rect.fromLTWH(-20, 80, 40, 40),
      '7': Rect.fromLTWH(20, 80, 40, 40),
      '8': Rect.fromLTWH(60, 80, 40, 40),
    },
  ),
  (
    'grid_xgrid_fr_span_2_proportion_sub_1_sum_with_non_spanned_track',
    () => _grid(
      width: null,
      height: null,
      frame: EdgeInsets.zero,
      tracks: Tracks(
        columns: const [TrackSize.flex(0.2), TrackSize.flex(0.3), TrackSize.flex(0.5)],
        rows: const [TrackSize.fixed(40), TrackSize.fixed(40)],
        children: [
          TrackCell(columnSpan: 2, width: 60, child: _a('0')),
          TrackCell(child: _a('1')),
          TrackCell(child: _a('2')),
          TrackCell(child: _a('3')),
          TrackCell(child: _a('4')),
        ],
      ),
    ),
    {
      'root': Rect.fromLTWH(0, 0, 78, 80),
      '0': Rect.fromLTWH(0, 0, 60, 40),
      '1': Rect.fromLTWH(60, 0, 9, 40),
      '2': Rect.fromLTWH(0, 40, 24, 40),
      '3': Rect.fromLTWH(24, 40, 36, 40),
      '4': Rect.fromLTWH(60, 40, 9, 40),
    },
  ),
];
