import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A section's header (`position: sticky` held by a block that ends before
/// the page does) pinned under the page's pinned headers: a
/// `PinnedHeaderSliver` of [child] in the section's `SliverMainAxisGroup`,
/// pushed out by the section's end as the browser pushes it.
///
/// THE SECTION'S END PUSHES THE HEADER BY ITS BOTTOM, wherever it is held
/// (css-position-3 3.4): a header held 60px down, under the page's own,
/// starts to leave once less than 60px and its height are left of its
/// section. `SliverMainAxisGroup` pushes its pinned headers out only once
/// less than their own height is left: it stood the header at 60 over what
/// came after the section until the last 40px, and then dropped it at once
/// (`pinned_page_test.dart`). So the header says it obstructs the page's
/// headers' height too, which the group pushes it out by.
class SectionPin extends StatelessWidget {
  const SectionPin({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => _SectionPin(sliver: PinnedHeaderSliver(child: child));
}

class _SectionPin extends SingleChildRenderObjectWidget {
  const _SectionPin({required Widget sliver}) : super(child: sliver);

  @override
  RenderSectionPin createRenderObject(BuildContext context) => RenderSectionPin();
}

/// The render object behind [SectionPin]: its sliver's geometry, obstructing
/// what it is held under ([SliverConstraints.overlap]) as well.
class RenderSectionPin extends RenderProxySliver {
  @override
  void performLayout() {
    super.performLayout();
    final g = geometry;
    if (g == null || g.scrollOffsetCorrection != null || g.maxScrollObstructionExtent <= 0) return;
    geometry = g.copyWith(maxScrollObstructionExtent: g.maxScrollObstructionExtent + constraints.overlap);
  }
}
