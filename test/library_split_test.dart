// WHAT A PAGE IMPORTS IS ITS WIDGETS; THE RENDER LAYER IS A LIBRARY OF ITS
// OWN; AND EACH NAME A LIBRARY GIVES IS ONE IT SHOWS BY NAME.
// `package:css_box/css_box.dart` shows the widgets, decorations, clippers,
// enums and value classes of lib/src, and the spans the generator writes
// (`han`, `edgeSpan`, `indentSpan`); `package:css_box/rendering.dart` the
// render objects, their parent data and the few protocols render objects
// share; `package:css_box/bands.dart` the width switches. SHOWN, NOT HIDDEN:
// a public name added to lib/src is no library's until one lists it, or it
// is marked `@internal` -- a helper the files of lib/src share and nothing
// outside the package should call (`hanCloses`, the dry questions' guards).
// Hidden by name instead, every helper made public for a sibling file was
// a page's at once. This test makes each public name of lib/src -- type,
// extension, function, getter or variable -- one or the other, and keeps
// the render layer out of the page's library.
//
// NEITHER LIBRARY DECLARES ANYTHING: each is export lines only. The
// generator reads css_box's names off the declarations in lib/ and
// lib/src/, so a library that only re-exports changes no name it reads.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _export = RegExp(r"^export '(src/[a-z_]+\.dart)'([^;]*);", multiLine: true);

/// A declaration at the top level of a file: a type or an extension, a
/// variable, or a function or getter, each read whole off the line that
/// starts it -- a name that starts with `_` too, and then left out as the
/// file's own.
final _type = RegExp(
  r'^(?:(?:abstract|final|base|sealed|interface|mixin)\s+)*(?:class|mixin|enum|typedef|extension type|extension)\s+([A-Za-z_]\w*)',
);
final _variable = RegExp(r'^(?:late\s+)?(?:final|const|var)\s+(?:[\w<>,? ]+\s+)?([A-Za-z_]\w*)\s*[=;]');
final _typedVariable = RegExp(r'^[A-Za-z][\w<>,? ]*\s+([A-Za-z_]\w*)\s*[=;]');
final _function = RegExp(
  r'^(?:external\s+)?(?:[A-Za-z][\w<>,? .()]*?\s+)?(?:get\s+)?([A-Za-z_]\w*)\s*(?:<[^>]*>)?\s*(?:\(|=>|\{)',
);

/// The public names [file] (under lib/) declares, each with whether it is
/// marked `@internal`.
Map<String, bool> _declared(String file) {
  final out = <String, bool>{};
  final lines = File('lib/$file').readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.isEmpty || !RegExp('[A-Za-z]').hasMatch(line[0])) continue;
    if (RegExp(r'^(?:import|export|part|library)\b').hasMatch(line)) continue;
    final m =
        _type.firstMatch(line) ??
        _variable.firstMatch(line) ??
        _typedVariable.firstMatch(line) ??
        _function.firstMatch(line);
    if (m == null || m[1]!.startsWith('_') || const {'get', 'set', 'on'}.contains(m[1])) continue;
    out[m[1]!] = i > 0 && lines[i - 1].trim() == '@internal';
  }
  return out;
}

/// Each file [library] exports, with the names it shows of it; null where
/// it shows them all.
Map<String, Set<String>?> _shows(String library) => {
  for (final m in _export.allMatches(File('lib/$library').readAsStringSync()))
    m[1]!: m[2]!.contains('show')
        ? {
            for (final c in RegExp(r'show([^;]*)').allMatches(m[2]!))
              ...c[1]!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
          }
        : null,
};

const _libraries = ['css_box.dart', 'rendering.dart', 'bands.dart'];

bool _renderLayer(String name) => name.startsWith('Render') || name.endsWith('ParentData');

void main() {
  final sources = [
    for (final f in Directory('lib/src').listSync().whereType<File>())
      if (f.path.endsWith('.dart')) 'src/${f.uri.pathSegments.last}',
  ]..sort();
  final declared = {for (final f in sources) f: _declared(f)};
  final shows = {for (final l in _libraries) l: _shows(l)};
  final page = shows['css_box.dart']!, render = shows['rendering.dart']!;

  /// The libraries that show [name] of [file].
  List<String> shownBy(String file, String name) => [
    for (final l in _libraries)
      if (shows[l]!.containsKey(file) && shows[l]![file]!.contains(name)) l,
  ];

  test('every library lists the names it shows', () {
    for (final l in _libraries) {
      for (final MapEntry(key: file, value: names) in shows[l]!.entries) {
        expect(names, isNotNull, reason: '$l exports $file whole');
      }
    }
  });

  test('every name a library shows is declared, public, in the file it exports', () {
    for (final l in _libraries) {
      for (final MapEntry(key: file, value: names) in shows[l]!.entries) {
        final there = declared[file] ?? const <String, bool>{};
        for (final n in names ?? const <String>{}) {
          expect(there.containsKey(n), isTrue, reason: '$l shows $n of $file');
          expect(there[n], isFalse, reason: '$l shows $n of $file, which is @internal');
        }
      }
    }
  });

  test('every public name of lib/src is shown by a library or marked @internal', () {
    for (final MapEntry(key: file, value: names) in declared.entries) {
      for (final MapEntry(key: n, value: internal) in names.entries) {
        if (internal) continue;
        expect(shownBy(file, n), isNotEmpty, reason: '$n of $file');
      }
    }
  });

  test('the page library shows no render object or parent data, and nothing the rendering library shows', () {
    for (final MapEntry(key: file, value: names) in page.entries) {
      for (final n in names!) {
        expect(_renderLayer(n), isFalse, reason: '$n of $file');
        expect(render[file] ?? const <String>{}, isNot(contains(n)), reason: '$n of $file');
      }
    }
  });

  test('every render object and parent data in lib/src is in the rendering library', () {
    for (final MapEntry(key: file, value: names) in declared.entries) {
      for (final n in names.keys.where(_renderLayer)) {
        expect(render[file] ?? const <String>{}, contains(n), reason: '$n of $file');
      }
    }
  });

  test('neither library declares a name of its own', () {
    for (final l in _libraries) {
      expect(_declared(l), isEmpty, reason: l);
    }
  });

  test('the parser reads every kind of top-level name', () {
    // One of each, as lib/src declares them: a class, a mixin, an
    // extension, a typedef of a record, a generic function, a function
    // returning a record, a function of a nullable type.
    expect(declared['src/linebox.dart'], containsPair('LineBox', false));
    expect(declared['src/dry.dart'], containsPair('KeptUnderHatch', true));
    expect(declared['src/bands.dart'], containsPair('WidthBands', false));
    expect(declared['src/linebox.dart'], containsPair('GrownLine', false));
    expect(declared['src/dry.dart'], containsPair('guardedSize', true));
    expect(declared['src/edge_span.dart'], containsPair('edgeSpan', false));
    expect(declared['src/dry.dart'], containsPair('dryBaselineOf', false));
    expect(declared['src/dry.dart'], containsPair('lastNotAboveFirst', true));
  });

  test('NEGATIVE: a widget and the spans the generator writes are the page\'s; a shared helper is no library\'s', () {
    expect(page['src/linebox.dart'], contains('LineBox'));
    expect(page['src/tracks.dart'], contains('Tracks'));
    expect(page['src/press_where_drawn.dart'], contains('PressWhereDrawn'));
    expect(page['src/han.dart'], contains('han'));
    expect(page['src/edge_span.dart'], containsAll(['edgeSpan', 'indentSpan']));
    expect(shownBy('src/han.dart', 'hanCloses'), isEmpty);
    expect(declared['src/han.dart'], containsPair('hanCloses', true));
  });
}
