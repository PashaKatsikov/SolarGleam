/// Asset paths. Sprites live flat in `assets/art` as `<group>_<index>.webp`.
class Art {
  static String sprite(String group, int index) => 'assets/art/${group}_$index.webp';
  static String background(int region) => 'assets/art/bg_$region.webp';
}

class GleamAssets {
  static const gameName = 'assets/branding/game_name.webp';
  static const verticalLoading = 'assets/loading/vertical_loading.webp';
  static const horizontalLoading = 'assets/loading/horizontal_loading.webp';

  /// Logo artwork occupies this part of the 512 x 512 canvas.
  static const gameNameSource = (width: 512.0, height: 512.0);

  /// Decoded before the menu opens so the first screens never pop in.
  static List<String> get preload => [
    gameName,
    verticalLoading,
    horizontalLoading,
    Art.background(0),
    Art.background(1),
    Art.sprite('core', 0),
    Art.sprite('neon_tower', 0),
    Art.sprite('platforms', 0),
    for (var i = 0; i < 4; i++) Art.sprite('orbs_b', i),
    for (var i = 0; i < 4; i++) Art.sprite('orbs_rare', i),
    for (var i = 0; i < 4; i++) Art.sprite('orbs_a', i),
    for (var i = 0; i < 4; i++) Art.sprite('symbols', i),
  ];
}
