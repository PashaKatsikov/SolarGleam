import 'package:flutter/painting.dart';

import '../assets.dart';

/// Presentation data of the world: names, art, colours and story text. All the
/// balance (difficulty, rewards, costs) lives in the Rust core.

class SpriteRef {
  const SpriteRef(this.group, this.index);

  final String group;
  final int index;

  String get path => Art.sprite(group, index);
}

class OrbDef {
  const OrbDef({
    required this.id,
    required this.name,
    required this.role,
    required this.blurb,
    required this.story,
    required this.sprite,
    required this.glow,
  });

  final int id;
  final String name;
  final String role;
  final String blurb;
  final String story;
  final SpriteRef sprite;
  final Color glow;
}

/// Discovery order, the same order the core uses for orb ids.
const orbDefs = <OrbDef>[
  OrbDef(
    id: 0,
    name: 'Azure Orb',
    role: 'STABLE',
    blurb: 'The steady heart of every memory.',
    story:
        'The first orb ever woken. Azure holds the plainest memories, so the '
        'Restorers learn the rhythm of the old world from it.',
    sprite: SpriteRef('orbs_b', 0),
    glow: Color(0xFF3A8CFF),
  ),
  OrbDef(
    id: 1,
    name: 'Rose Orb',
    role: 'ECHO',
    blurb: 'Answers every signal with a warm pulse.',
    story:
        'Rose orbs sang the district awake each evening. Their pulse is the '
        'easiest thing in the mirage to follow, and the hardest to forget.',
    sprite: SpriteRef('orbs_b', 1),
    glow: Color(0xFFFF5BC8),
  ),
  OrbDef(
    id: 2,
    name: 'Cyan Orb',
    role: 'CLEAR',
    blurb: 'Bright, quick and impossible to miss.',
    story:
        'Cyan carried messages between towers. It flashes first and fades '
        'last, which makes it a favourite of new Restorers.',
    sprite: SpriteRef('orbs_b', 3),
    glow: Color(0xFF35F2E6),
  ),
  OrbDef(
    id: 3,
    name: 'White Orb',
    role: 'PURE',
    blurb: 'A blank page that remembers everything.',
    story:
        'White holds no colour of its own. Old records say it stores the '
        'moments between two memories, the quiet nobody wrote down.',
    sprite: SpriteRef('orbs_rare', 2),
    glow: Color(0xFFEAF6FF),
  ),
  OrbDef(
    id: 4,
    name: 'Violet Orb',
    role: 'HIDDEN',
    blurb: 'Opens the glyphs sleeping inside its core.',
    story:
        'Violet turns its light inwards. Look closely and a glyph appears, '
        'an ancient mark that only this orb can show.',
    sprite: SpriteRef('orbs_b', 2),
    glow: Color(0xFFA56BFF),
  ),
  OrbDef(
    id: 5,
    name: 'Amber Orb',
    role: 'WARM',
    blurb: 'Keeps memories from the age of the forest.',
    story:
        'Amber grew where the data trees fell. Its dome is cracked with '
        'tiny roots, still reaching for light that no longer comes.',
    sprite: SpriteRef('orbs_rare', 1),
    glow: Color(0xFFFFA33A),
  ),
  OrbDef(
    id: 6,
    name: 'Crimson Orb',
    role: 'SHIFTING',
    blurb: 'Rearranges memories while you watch.',
    story:
        'Crimson never stays where you left it. The temple priests used it '
        'to test whether a student remembered the order, or only the place.',
    sprite: SpriteRef('orbs_rare', 3),
    glow: Color(0xFFFF3B4E),
  ),
  OrbDef(
    id: 7,
    name: 'Prism Orb',
    role: 'RARE',
    blurb: 'Splits one memory into every colour.',
    story:
        'Light enters Prism as one thought and leaves as a hundred. It was '
        'cut from the first wave that ever crossed the digital ocean.',
    sprite: SpriteRef('orbs_a', 1),
    glow: Color(0xFFFF9BF0),
  ),
  OrbDef(
    id: 8,
    name: 'Crystal Orb',
    role: 'RARE',
    blurb: 'Faceted like a thousand tiny mirrors.',
    story:
        'Crystal grows slowly on the ocean floor, one facet for each '
        'memory it swallows. Divers say it hums when someone is near.',
    sprite: SpriteRef('orbs_a', 3),
    glow: Color(0xFFB6E6FF),
  ),
  OrbDef(
    id: 9,
    name: 'Emerald Orb',
    role: 'ANALYTIC',
    blurb: 'Finds the pattern hiding in the noise.',
    story:
        'Emerald sits on a pedestal of its own, always measuring. In the '
        'Quantum Desert it is the only orb that holds one shape.',
    sprite: SpriteRef('orbs_rare', 0),
    glow: Color(0xFF52F56A),
  ),
  OrbDef(
    id: 10,
    name: 'Gold Orb',
    role: 'RARE',
    blurb: 'Wrapped in rings of ancient circuitry.',
    story:
        'Gold was forged where the dunes remember being water. Its spinning '
        'rings are a map that nobody has finished reading.',
    sprite: SpriteRef('orbs_a', 0),
    glow: Color(0xFFFFC738),
  ),
  OrbDef(
    id: 11,
    name: 'Void Orb',
    role: 'RARE',
    blurb: 'The memory the civilisation chose to hide.',
    story:
        'Void lives at the centre of the Memory Core, behind every other '
        'orb. It holds the last thing the old world ever recorded.',
    sprite: SpriteRef('orbs_a', 2),
    glow: Color(0xFF7A4DFF),
  ),
];

/// Where one restorable object stands on the region diorama.
class SlotSpot {
  const SlotSpot(this.cx, this.base, this.boxW, this.boxH);

  final double cx;
  final double base;
  final double boxW;
  final double boxH;
}

/// Level 1 stands at the front, level 8 is the great centrepiece.
const slotSpots = <SlotSpot>[
  SlotSpot(0.50, 0.94, 0.30, 0.30),
  SlotSpot(0.24, 0.85, 0.27, 0.28),
  SlotSpot(0.76, 0.85, 0.27, 0.28),
  SlotSpot(0.14, 0.67, 0.26, 0.27),
  SlotSpot(0.86, 0.67, 0.26, 0.27),
  SlotSpot(0.27, 0.51, 0.24, 0.28),
  SlotSpot(0.73, 0.51, 0.24, 0.28),
  SlotSpot(0.50, 0.63, 0.36, 0.55),
];

const decorSpots = <SlotSpot>[
  SlotSpot(0.07, 0.98, 0.14, 0.15),
  SlotSpot(0.93, 0.98, 0.14, 0.15),
  SlotSpot(0.10, 0.36, 0.13, 0.15),
  SlotSpot(0.90, 0.36, 0.13, 0.15),
];

class SlotDef {
  const SlotDef(this.name, this.restored, {this.ruined});

  final String name;
  final SpriteRef restored;

  /// A separate "before" picture. Without one the restored art is shown dim.
  final SpriteRef? ruined;
}

class DecorDef {
  const DecorDef(this.name, this.sprite);

  final String name;
  final SpriteRef sprite;
}

class RegionDef {
  const RegionDef({
    required this.index,
    required this.name,
    required this.line,
    required this.blurb,
    required this.teaches,
    required this.accent,
    required this.accent2,
    required this.platform,
    required this.slots,
    required this.decor,
    required this.memoryTitle,
    required this.memory,
  });

  final int index;
  final String name;
  final String line;
  final String blurb;
  final String teaches;
  final Color accent;
  final Color accent2;
  final SpriteRef platform;
  final List<SlotDef> slots;
  final List<DecorDef> decor;
  final String memoryTitle;
  final String memory;

  String get background => Art.background(index);
  SlotDef get centrepiece => slots.last;
}

const regionDefs = <RegionDef>[
  RegionDef(
    index: 0,
    name: 'NEON DISTRICT',
    line: 'The first district to wake',
    blurb:
        'Once the technology heart of the civilisation. The glitch cut its '
        'power, but the towers still wait for a signal.',
    teaches: 'Colour sequences',
    accent: Color(0xFF35D6FF),
    accent2: Color(0xFFFF4FD8),
    platform: SpriteRef('platforms', 0),
    slots: [
      SlotDef('Signal Spire', SpriteRef('restored', 0), ruined: SpriteRef('destroyed', 0)),
      SlotDef('Hologram Fountain', SpriteRef('restored', 2), ruined: SpriteRef('destroyed', 1)),
      SlotDef('Neon Plaza', SpriteRef('restored', 1), ruined: SpriteRef('destroyed', 2)),
      SlotDef('Energy Tree', SpriteRef('restored', 3), ruined: SpriteRef('destroyed', 3)),
      SlotDef('Azure Tower', SpriteRef('buildings', 0)),
      SlotDef('Pulse Dome', SpriteRef('buildings', 1)),
      SlotDef('Emerald Spire', SpriteRef('buildings', 2)),
      SlotDef('Central Neon Tower', SpriteRef('neon_tower', 0)),
    ],
    decor: [
      DecorDef('Holo Cylinder', SpriteRef('holo_city', 0)),
      DecorDef('Holo Skyline', SpriteRef('holo_city', 1)),
      DecorDef('Light Billboard', SpriteRef('holo_city', 2)),
      DecorDef('Signal Post', SpriteRef('holo_city', 3)),
    ],
    memoryTitle: 'The Last Broadcast',
    memory:
        'On the final night the towers sent one message to every orb in the '
        'city: "Remember us." Nobody has decoded the rest.',
  ),
  RegionDef(
    index: 1,
    name: 'CRYSTAL DATA FOREST',
    line: 'Where data turned into life',
    blurb:
        'After the collapse, lost data grew into glowing crystal plants. '
        'Every leaf hides a pattern waiting to be read.',
    teaches: 'Hidden glyphs',
    accent: Color(0xFF4DFFC3),
    accent2: Color(0xFFB77CFF),
    platform: SpriteRef('platforms', 1),
    slots: [
      SlotDef('Azure Crystal Tree', SpriteRef('crystal_trees', 0)),
      SlotDef('Lilac Canopy', SpriteRef('crystal_trees', 1)),
      SlotDef('Aqua Sapling', SpriteRef('crystal_trees', 2)),
      SlotDef('Rose Blossom', SpriteRef('crystal_trees', 3)),
      SlotDef('Glass Lotus', SpriteRef('plants', 0)),
      SlotDef('Amethyst Bloom', SpriteRef('plants', 1)),
      SlotDef('Cherry Core', SpriteRef('plants', 3)),
      SlotDef('Central Data Tree', SpriteRef('data_tree', 0)),
    ],
    decor: [
      DecorDef('Azure Shard', SpriteRef('crystals', 0)),
      DecorDef('Violet Shard', SpriteRef('crystals', 1)),
      DecorDef('Emerald Shard', SpriteRef('crystals', 2)),
      DecorDef('Prism Shard', SpriteRef('crystals', 3)),
    ],
    memoryTitle: 'The Seed Archive',
    memory:
        'The forest was never planted. It grew from a backup that tried to '
        'save itself, one crystal for every thing it loved.',
  ),
  RegionDef(
    index: 2,
    name: 'AURORA SKY TEMPLE',
    line: 'A library above the clouds',
    blurb:
        'A temple that floats inside a virtual sky. Its pillars point the '
        'way, but the orbs rarely stay where you saw them.',
    teaches: 'Reversed order and moving orbs',
    accent: Color(0xFFFFC857),
    accent2: Color(0xFF9CE7FF),
    platform: SpriteRef('platforms', 2),
    slots: [
      SlotDef('Azure Pillar', SpriteRef('light_columns', 0)),
      SlotDef('Violet Pillar', SpriteRef('light_columns', 1)),
      SlotDef('Golden Pillar', SpriteRef('light_columns', 2)),
      SlotDef('Aurora Pillar', SpriteRef('light_columns', 3)),
      SlotDef('Ancient Column', SpriteRef('ancient_column', 0)),
      SlotDef('Gate of Echoes', SpriteRef('holo_portal', 0)),
      SlotDef('Sky Portal', SpriteRef('sky_portal', 0)),
      SlotDef('Aurora Altar', SpriteRef('altar', 0)),
    ],
    decor: [
      DecorDef('Azure Ring', SpriteRef('rings', 0)),
      DecorDef('Violet Ring', SpriteRef('rings', 1)),
      DecorDef('Jade Ring', SpriteRef('rings', 2)),
      DecorDef('Golden Ring', SpriteRef('rings', 3)),
    ],
    memoryTitle: 'The Teaching Hour',
    memory:
        'Priests asked students to say the memory backwards. Anyone could '
        'repeat a story; only those who understood it could unwind it.',
  ),
  RegionDef(
    index: 3,
    name: 'CYBER OCEAN',
    line: 'The sea that remembers',
    blurb:
        'An ocean of liquid information. Drowned archives glow beneath the '
        'waves, and false signals ripple across the surface.',
    teaches: 'False signals',
    accent: Color(0xFF2AE0F0),
    accent2: Color(0xFF7C8CFF),
    platform: SpriteRef('platforms', 3),
    slots: [
      SlotDef('Blue Current', SpriteRef('waves', 0)),
      SlotDef('Violet Current', SpriteRef('waves', 1)),
      SlotDef('Cyan Current', SpriteRef('waves', 2)),
      SlotDef('Prism Current', SpriteRef('waves', 3)),
      SlotDef('Sunken Archive', SpriteRef('data_archive', 0)),
      SlotDef('Light Coral', SpriteRef('underwater', 0)),
      SlotDef('Glass Jelly', SpriteRef('underwater', 2)),
      SlotDef('Sunken Tower', SpriteRef('sunken_tower', 0)),
    ],
    decor: [
      DecorDef('Signal Kelp', SpriteRef('underwater', 1)),
      DecorDef('Reef Crystals', SpriteRef('underwater', 3)),
      DecorDef('Drift Diamond', SpriteRef('deco', 0)),
      DecorDef('Wave Orb', SpriteRef('deco', 3)),
    ],
    memoryTitle: 'Voices Under the Surface',
    memory:
        'The tide carried half-truths on purpose. The old divers trained '
        'their ears to ignore the loud signal and keep the quiet one.',
  ),
  RegionDef(
    index: 4,
    name: 'QUANTUM DESERT',
    line: 'Nothing here holds one shape',
    blurb:
        'An unstable zone where objects exist in several states at once. '
        'Rules overlap, and the sand never stops moving.',
    teaches: 'Several rules at once',
    accent: Color(0xFFFFB23E),
    accent2: Color(0xFFB86BFF),
    platform: SpriteRef('platforms', 1),
    slots: [
      SlotDef('Azure Dune', SpriteRef('dunes', 0)),
      SlotDef('Violet Dune', SpriteRef('dunes', 1)),
      SlotDef('Golden Dune', SpriteRef('dunes', 2)),
      SlotDef('Frost Dune', SpriteRef('dunes', 3)),
      SlotDef('Blue Quantum Rock', SpriteRef('rocks', 0)),
      SlotDef('Violet Quantum Rock', SpriteRef('rocks', 1)),
      SlotDef('Green Quantum Rock', SpriteRef('rocks', 2)),
      SlotDef('Desert Core', SpriteRef('desert_core', 0)),
    ],
    decor: [
      DecorDef('Azure Obelisk', SpriteRef('obelisks', 0)),
      DecorDef('Violet Obelisk', SpriteRef('obelisks', 1)),
      DecorDef('Golden Obelisk', SpriteRef('obelisks', 2)),
      DecorDef('Frost Obelisk', SpriteRef('obelisks', 3)),
    ],
    memoryTitle: 'The Unfinished Equation',
    memory:
        'The desert is a calculation that never stopped. Each dune is a '
        'step, each rock a guess, and the answer keeps moving away.',
  ),
  RegionDef(
    index: 5,
    name: 'MEMORY CORE',
    line: 'Everything the world remembers',
    blurb:
        'The final vault of a lost civilisation. Every rule you have '
        'learned meets here, and the Void Orb waits at its centre.',
    teaches: 'Every rule combined',
    accent: Color(0xFFBFE9FF),
    accent2: Color(0xFF8E7CFF),
    platform: SpriteRef('platforms', 0),
    slots: [
      SlotDef('Azure Server', SpriteRef('server_crystals', 0)),
      SlotDef('Violet Server', SpriteRef('server_crystals', 1)),
      SlotDef('Emerald Server', SpriteRef('server_crystals', 2)),
      SlotDef('Prism Server', SpriteRef('server_crystals', 3)),
      SlotDef('Archive Portal', SpriteRef('archive_portal', 0)),
      SlotDef('Final Structure', SpriteRef('final_structure', 0)),
      SlotDef('Memory Lens', SpriteRef('deco', 2)),
      SlotDef('Main Memory Core', SpriteRef('memory_core', 0)),
    ],
    decor: [
      DecorDef('Plasma Lamp', SpriteRef('light_deco', 0)),
      DecorDef('Light Crystal', SpriteRef('light_deco', 1)),
      DecorDef('Infinity Loop', SpriteRef('light_deco', 2)),
      DecorDef('Cube Reactor', SpriteRef('light_deco', 3)),
    ],
    memoryTitle: 'The Last Thing Remembered',
    memory:
        'At the end, the civilisation recorded only this: someone would '
        'come and listen. You did. The mirage can finally rest.',
  ),
];

/// Rule bits used by the core. Keep in step with `tables.rs`.
class Rule {
  static const echo = 1;
  static const mirror = 2;
  static const glyph = 4;
  static const ghost = 8;
  static const shift = 16;
}

class RuleInfo {
  const RuleInfo(this.bit, this.name, this.line, this.how);

  final int bit;
  final String name;
  final String line;
  final String how;
}

const ruleInfos = <RuleInfo>[
  RuleInfo(
    Rule.echo,
    'ECHO',
    'Watch, then repeat',
    'The orbs light up one by one. Wait until they stop, then tap them in '
        'the same order.',
  ),
  RuleInfo(
    Rule.mirror,
    'MIRROR',
    'Repeat it backwards',
    'This time the order is reversed. Tap the last orb that lit up first, '
        'and the first orb last.',
  ),
  RuleInfo(
    Rule.glyph,
    'GLYPH',
    'Read the core',
    'Symbols flash inside the core. Every orb carries one symbol: tap the '
        'orb that holds the symbol you saw.',
  ),
  RuleInfo(
    Rule.ghost,
    'GHOST',
    'Ignore the flickers',
    'Grey flickers are false signals. They are not part of the sequence, '
        'so leave them out when you answer.',
  ),
  RuleInfo(
    Rule.shift,
    'SHIFT',
    'Follow the swap',
    'After the preview the orbs swap places. Track each orb to its new '
        'spot before you answer.',
  ),
];

RuleInfo ruleInfo(int bit) => ruleInfos.firstWhere((r) => r.bit == bit);

/// Short chip labels for a mode mask, in display order.
List<RuleInfo> rulesOf(int modes) => [
  for (final r in ruleInfos)
    if (modes & r.bit != 0) r,
];
