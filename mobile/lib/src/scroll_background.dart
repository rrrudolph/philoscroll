import 'package:flutter/widgets.dart';

import 'theme.dart';

/// Parchment / slate scroll backgrounds shared with the web app (`src/styles.css`).
abstract final class ScrollBackground {
  static const lightTextureAsset = 'assets/textures/old-parchment.jpg';
  /// JPEG so Flutter tests and Linux CI can decode it (AVIF is web-only in `dist/textures`).
  static const darkTextureAsset = 'assets/textures/darkslate.jpg';

  static String textureAssetFor(Brightness brightness) {
    return brightness == Brightness.dark ? darkTextureAsset : lightTextureAsset;
  }

  /// Matches `[data-theme="light"] body` / `[data-theme="dark"] body` wash gradients.
  static Gradient bodyWash(Brightness brightness) {
    const center = Alignment(0, -0.08);
    if (brightness == Brightness.dark) {
      return RadialGradient(
        center: center,
        radius: 0.95,
        colors: [
          const Color(0x61000000),
          const Color(0x38000000),
          const Color(0x14000000),
          const Color(0x00000000),
        ],
        stops: const [0, 0.48, 0.68, 0.78],
      );
    }
    return RadialGradient(
      center: center,
      radius: 0.95,
      colors: [
        const Color(0x61FFFDF8),
        const Color(0x29FFFAF0),
        const Color(0x00FFFAF0),
      ],
      stops: const [0, 0.52, 0.78],
    );
  }

  /// Matches `.scroll-vignette` for each theme (stacked when light needs two passes).
  static List<BoxDecoration> vignetteLayers(Brightness brightness) {
    const center = Alignment(0, -0.08);
    if (brightness == Brightness.dark) {
      return [
        BoxDecoration(
          gradient: RadialGradient(
            center: center,
            radius: 0.95,
            colors: [
              const Color(0x61000000),
              const Color(0x38000000),
              const Color(0x14000000),
              const Color(0x00000000),
            ],
            stops: const [0, 0.48, 0.68, 0.78],
          ),
        ),
      ];
    }
    return [
      BoxDecoration(
        gradient: RadialGradient(
          center: center,
          radius: 0.95,
          colors: [
            const Color(0x8CFFFDF8),
            const Color(0x4DFFFAF0),
            const Color(0x1AFFFAF0),
            const Color(0x00FFFAF0),
          ],
          stops: const [0, 0.48, 0.68, 0.82],
        ),
      ),
      BoxDecoration(
        gradient: RadialGradient(
          center: center,
          radius: 1.05,
          colors: [
            const Color(0x00000000),
            const Color(0x3D000000),
            const Color(0x94000000),
          ],
          stops: const [0.4, 0.68, 1],
        ),
      ),
    ];
  }
}

/// Background stack under quote cards: texture, washes, glow, vignette.
class ScrollBackgroundLayers extends StatelessWidget {
  const ScrollBackgroundLayers({super.key, required this.palette});

  final PhiloPalette palette;

  @override
  Widget build(BuildContext context) {
    final vignettes = ScrollBackground.vignetteLayers(palette.brightness);
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          key: const Key('scroll-texture'),
          ScrollBackground.textureAssetFor(palette.brightness),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
        ),
        DecoratedBox(decoration: BoxDecoration(gradient: ScrollBackground.bodyWash(palette.brightness))),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -1.15),
              radius: 1.05,
              colors: [palette.glow, palette.glowClear],
              stops: const [0, 0.68],
            ),
          ),
        ),
        for (var i = 0; i < vignettes.length; i++)
          DecoratedBox(
            key: i == 0 ? const Key('scroll-vignette') : const Key('scroll-vignette-edge'),
            decoration: vignettes[i],
          ),
      ],
    );
  }
}
