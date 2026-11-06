/// The width switches -- `context.band`, `context.wrap`,
/// `context.widthFrom`, `context.widthBelow` -- for a page laid out on its
/// own, with no app round it. An app writes its own, in stock Flutter,
/// beside its breakpoints, so an app that imports this package for its
/// widgets sees one `band`, not two.
library;

export 'src/bands.dart' show WidthBands;
