// Deterministic filler text for the benchmark pages.
import 'dart:math' as math;

const _vocabulary = [
  'grid',
  'track',
  'line',
  'float',
  'word',
  'paragraph',
  'inline',
  'box',
  'margin',
  'baseline',
  'the',
  'of',
  'and',
  'a',
  'to',
  'in',
  'is',
  'room',
  'shrink',
  'content',
  'width',
  'height',
  'page',
  'browser',
  'layout',
  'internationalization',
  'measure',
  'span',
  'cell',
  'row',
  'column',
  'it',
];

/// [count] words drawn from a fixed vocabulary by a generator seeded with
/// [seed], so every run lays out the same text.
List<String> words(int count, {int seed = 1}) {
  final random = math.Random(seed);
  return [for (var i = 0; i < count; i++) _vocabulary[random.nextInt(_vocabulary.length)]];
}

/// [count] words as one string.
String sentence(int count, {int seed = 1}) => words(count, seed: seed).join(' ');
