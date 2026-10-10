import '../plan/plan.dart';

enum ImageKind { photo, silhouette }

/// A bundled picture the planner may attach to an item. Pictures never carry
/// data: sizes always come from facts. The catalog only says how to draw the
/// object so the measured dimension is to scale.
class ImageAsset {
  const ImageAsset({
    required this.key,
    required this.label,
    required this.kind,
    required this.shapes,
    required this.aspect,
    this.disc = 1,
    this.stretch = false,
  });

  /// Wire key, e.g. `earth`, `blue_whale`.
  final String key;
  final String label;
  final ImageKind kind;

  /// Which scale_zoom shapes this picture can stand in for: circle (measured
  /// across), bar (measured lengthwise) or tower (measured in height).
  final Set<ItemShape> shapes;

  /// Width / height of the object as drawn.
  final double aspect;

  /// Fraction of the picture's width that is the measured body (Saturn's
  /// rings make the photo wider than the planet).
  final double disc;

  /// Icon-style silhouettes are stretched to [aspect] so their proportions
  /// match the real object.
  final bool stretch;

  /// Path relative to the viz bundle (photos) or silhouette key.
  String get src => kind == ImageKind.photo ? 'img/$key.webp' : key;

  Map<String, Object?> toRenderJson() => {
        'key': key,
        'kind': kind.name,
        'src': src,
        'aspect': aspect,
        'disc': disc,
        'stretch': stretch,
      };
}

const _circle = {ItemShape.circle};
const _bar = {ItemShape.bar};
const _tower = {ItemShape.tower};

ImageAsset _photo(String key, String label, {double aspect = 1, double disc = 1}) =>
    ImageAsset(key: key, label: label, kind: ImageKind.photo, shapes: _circle, aspect: aspect, disc: disc);

/// Every picture bundled with the app. Sources are listed in
/// `app/assets/viz/img/CREDITS.md`.
final Map<String, ImageAsset> imageCatalog = {
  for (final a in <ImageAsset>[
    _photo('sun', 'the Sun'),
    _photo('mercury', 'Mercury'),
    _photo('venus', 'Venus'),
    _photo('earth', 'Earth'),
    _photo('moon', 'the Moon'),
    _photo('mars', 'Mars'),
    _photo('jupiter', 'Jupiter'),
    _photo('saturn', 'Saturn (with rings)', aspect: 2.45, disc: 0.441),
    _photo('uranus', 'Uranus'),
    _photo('neptune', 'Neptune'),
    _photo('pluto', 'Pluto'),
    const ImageAsset(key: 'blue_whale', label: 'blue whale', kind: ImageKind.silhouette, shapes: _bar, aspect: 3.3),
    const ImageAsset(key: 'sperm_whale', label: 'sperm whale', kind: ImageKind.silhouette, shapes: _bar, aspect: 2.33),
    const ImageAsset(
      key: 'elephant',
      label: 'elephant',
      kind: ImageKind.silhouette,
      shapes: {ItemShape.bar, ItemShape.tower},
      aspect: 1.55,
    ),
    const ImageAsset(key: 't_rex', label: 'Tyrannosaurus rex', kind: ImageKind.silhouette, shapes: _bar, aspect: 2.02),
    const ImageAsset(
      key: 'dog',
      label: 'dog',
      kind: ImageKind.silhouette,
      shapes: {ItemShape.bar, ItemShape.tower},
      aspect: 0.99,
    ),
    const ImageAsset(key: 'person', label: 'adult person', kind: ImageKind.silhouette, shapes: _tower, aspect: 0.36),
    const ImageAsset(key: 'school_bus', label: 'school bus', kind: ImageKind.silhouette, shapes: _bar, aspect: 3.86),
    const ImageAsset(key: 'car', label: 'car', kind: ImageKind.silhouette, shapes: _bar, aspect: 2.7, stretch: true),
    const ImageAsset(
      key: 'eiffel_tower',
      label: 'Eiffel Tower',
      kind: ImageKind.silhouette,
      shapes: _tower,
      aspect: 0.38,
      stretch: true,
    ),
    const ImageAsset(
      key: 'skyscraper',
      label: 'skyscraper',
      kind: ImageKind.silhouette,
      shapes: _tower,
      aspect: 0.3,
      stretch: true,
    ),
    const ImageAsset(key: 'rocket', label: 'rocket', kind: ImageKind.silhouette, shapes: _tower, aspect: 0.3, stretch: true),
  ])
    a.key: a,
};
