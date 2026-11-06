/// Which of a child's margin edges take the room LEFT OVER rather than a
/// length of their own.
///
/// An `auto` margin is how CSS centres a child in the space it was given
/// and how it pushes one to the far end: the leftover space is shared
/// equally between the auto edges of an axis before any alignment applies
/// (css-flexbox-1 8.1, css-align-3 10.1). It is a different thing from an
/// alignment, because it is the CHILD that asks for it.
class AutoEdges {
  const AutoEdges({this.left = false, this.right = false, this.top = false, this.bottom = false});

  /// Both edges of an axis, which is what centres the child in it.
  const AutoEdges.symmetric({bool horizontal = false, bool vertical = false})
    : left = horizontal,
      right = horizontal,
      top = vertical,
      bottom = vertical;

  final bool left, right, top, bottom;

  static const AutoEdges none = AutoEdges();

  bool get any => left || right || top || bottom;

  @override
  bool operator ==(Object other) =>
      other is AutoEdges && other.left == left && other.right == right && other.top == top && other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, right, top, bottom);

  @override
  String toString() => 'AutoEdges(left: $left, right: $right, top: $top, bottom: $bottom)';
}
