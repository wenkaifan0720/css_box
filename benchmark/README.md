# Benchmarks

Large pages of the three layouts that do the most work per frame, each laid
out again at a new width on every run (so no layout or dry layout is answered
from the run before), beside the stock widgets' page of the same content.

| File | Page |
| --- | --- |
| `tracks_benchmark.dart` | `Tracks`: 400 items on `auto`, `1fr`, `2fr` and `80px` tracks; Flutter's `Table` of the same cells; the grid with a header spanning two tracks every tenth row |
| `inline_flow_benchmark.dart` | `InlineFlow`: 2,000 words with a padded, filled inline box every 25 words and an atomic inline every 100; `Text.rich` of the same; both over the words alone |
| `float_flow_benchmark.dart` | `FloatFlow`: 60 floats, left and right in turn, each with an 80-word paragraph whose lines shorten beside it; a `Column` of `Row`s as the closest stock page |
| `scaling_benchmark.dart` | How the work grows with the content, at 1,000, 2,000 and 4,000 words: one `FloatText` paragraph beside a float in a half-width column; `InlineFlow` with a faded or moved box round every tenth word; and `InlineFlow` with every word in such a box, painted again without a layout. Each size's time over the first: 2 and 4 where the work grows with the content, 4 and 16 where it grows as its square |

Run one, or each in turn:

```sh
flutter test benchmark/tracks_benchmark.dart
for f in benchmark/*_benchmark.dart; do flutter test "$f"; done
```

Each page is laid out whole in a scroll view, as a document is. Every page is
first laid out at 10 widths, and then each is timed at 30 more: the median and
90th percentile in milliseconds, from the width changing to the frame being
drawn (the build of the box that states the width, layout and paint).
`flutter test` runs a debug build with assertions on, and the test font sets
every glyph one em square, so the times are for comparing the pages with each
other, and a change with the commit before it; they are not frame times on a
device.
