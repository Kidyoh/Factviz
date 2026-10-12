import '../plan/plan.dart';

part 'silhouette_catalog.g.dart';

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
        'shapes': [for (final s in shapes) s.name],
      };
}

const _circle = {ItemShape.circle};

ImageAsset _photo(String key, String label, {double aspect = 1, double disc = 1}) =>
    ImageAsset(key: key, label: label, kind: ImageKind.photo, shapes: _circle, aspect: aspect, disc: disc);

/// Every picture bundled with the app: planet photos plus the generated
/// [silhouetteAssets] (see `app/tool/silhouettes/`). Sources are listed in
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
    ...silhouetteAssets,
  ])
    a.key: a,
};
