// A gallery of css_box's widgets: each snippet of the package's README,
// laid out in a column 320 wide.
//
// To run it on a platform, add the platform folders first:
//
//   flutter create . --platforms=web,macos
//   flutter run -d chrome
import 'package:flutter/material.dart';

import 'snippets.dart';

void main() => runApp(const CssBoxGallery());

/// Every snippet of the README, one after the other.
class CssBoxGallery extends StatelessWidget {
  const CssBoxGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'css_box gallery',
      home: Scaffold(
        appBar: AppBar(title: const Text('css_box')),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            for (final MapEntry(key: name, value: build) in snippets.entries)
              _Entry(name: name, child: build()),
          ],
        ),
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.name, required this.child});

  final String name;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(width: 320, child: child),
        ],
      ),
    );
  }
}
