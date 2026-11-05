import 'dart:math' as math;

enum ElementKind { metal, nonmetal, metalloid }

enum MolecularGeometry {
  linear,
  trigonalPlanar,
  tetrahedral,
  trigonalBipyramidal,
  octahedral,
}

class PolyatomicGroupDefinition {
  const PolyatomicGroupDefinition({
    required this.id,
    required this.name,
    required this.formula,
    required this.centralElement,
    required this.peripheralElement,
    required this.peripheralCount,
    required this.charge,
    required this.geometry,
  });

  final String id;
  final String name;
  final String formula;
  final String centralElement;
  final String peripheralElement;
  final int peripheralCount;
  final int charge;
  final MolecularGeometry geometry;

  int get valency => charge.abs();
  String get valencyRoman => switch (valency) {
    1 => 'I',
    2 => 'II',
    3 => 'III',
    4 => 'IV',
    _ => '$valency',
  };
  String get chargeSuffix => switch (charge) {
    -1 => '⁻',
    -2 => '²⁻',
    -3 => '³⁻',
    1 => '⁺',
    2 => '²⁺',
    3 => '³⁺',
    _ => '',
  };
}

class PolyatomicGroupInstance {
  const PolyatomicGroupInstance({
    required this.definition,
    required this.centralAtomId,
    required this.peripheralAtomIds,
  });

  final PolyatomicGroupDefinition definition;
  final String centralAtomId;
  final List<String> peripheralAtomIds;

  Set<String> get atomIds => {centralAtomId, ...peripheralAtomIds};

  String get packageKey {
    final ids = atomIds.toList()..sort();
    return '${definition.id}:${ids.join(',')}';
  }
}

const polyatomicGroupDictionary = <PolyatomicGroupDefinition>[
  PolyatomicGroupDefinition(
    id: 'hydroxide',
    name: 'Gốc Hydroxit',
    formula: 'OH',
    centralElement: 'O',
    peripheralElement: 'H',
    peripheralCount: 1,
    charge: -1,
    geometry: MolecularGeometry.linear,
  ),
  PolyatomicGroupDefinition(
    id: 'nitrite',
    name: 'Gốc Nitrit',
    formula: 'NO₂',
    centralElement: 'N',
    peripheralElement: 'O',
    peripheralCount: 2,
    charge: -1,
    geometry: MolecularGeometry.linear,
  ),
  PolyatomicGroupDefinition(
    id: 'carbonate',
    name: 'Gốc Cacbonat',
    formula: 'CO₃',
    centralElement: 'C',
    peripheralElement: 'O',
    peripheralCount: 3,
    charge: -2,
    geometry: MolecularGeometry.trigonalPlanar,
  ),
  PolyatomicGroupDefinition(
    id: 'nitrate',
    name: 'Gốc Nitrat',
    formula: 'NO₃',
    centralElement: 'N',
    peripheralElement: 'O',
    peripheralCount: 3,
    charge: -1,
    geometry: MolecularGeometry.trigonalPlanar,
  ),
  PolyatomicGroupDefinition(
    id: 'sulfite',
    name: 'Gốc Sunfit',
    formula: 'SO₃',
    centralElement: 'S',
    peripheralElement: 'O',
    peripheralCount: 3,
    charge: -2,
    geometry: MolecularGeometry.trigonalPlanar,
  ),
  PolyatomicGroupDefinition(
    id: 'sulfate',
    name: 'Gốc Sunfat',
    formula: 'SO₄',
    centralElement: 'S',
    peripheralElement: 'O',
    peripheralCount: 4,
    charge: -2,
    geometry: MolecularGeometry.tetrahedral,
  ),
  PolyatomicGroupDefinition(
    id: 'phosphate',
    name: 'Gốc Photphat',
    formula: 'PO₄',
    centralElement: 'P',
    peripheralElement: 'O',
    peripheralCount: 4,
    charge: -3,
    geometry: MolecularGeometry.tetrahedral,
  ),
  PolyatomicGroupDefinition(
    id: 'chlorate',
    name: 'Gốc Clorat',
    formula: 'ClO₃',
    centralElement: 'Cl',
    peripheralElement: 'O',
    peripheralCount: 3,
    charge: -1,
    geometry: MolecularGeometry.trigonalPlanar,
  ),
  PolyatomicGroupDefinition(
    id: 'perchlorate',
    name: 'Gốc Peclorat',
    formula: 'ClO₄',
    centralElement: 'Cl',
    peripheralElement: 'O',
    peripheralCount: 4,
    charge: -1,
    geometry: MolecularGeometry.tetrahedral,
  ),
];

class ChemicalElement {
  const ChemicalElement({
    required this.number,
    required this.symbol,
    required this.name,
    required this.kind,
    required this.massNumber,
  });

  final int number;
  final String symbol;
  final String name;
  final ElementKind kind;
  final int massNumber;
  int get protons => number;
  int get neutrons => math.max(0, massNumber - number);
  int get valenceElectrons => electronShells(number).last;

  List<int> get valencies {
    const known = <String, List<int>>{
      'H': [1],
      'He': [0],
      'Li': [1],
      'Be': [2],
      'B': [3],
      'C': [4],
      'N': [3, 5],
      'O': [2],
      'F': [1],
      'Ne': [0],
      'Na': [1],
      'Mg': [2],
      'Al': [3],
      'Si': [4],
      'P': [3, 5],
      'S': [2, 4, 6],
      'Cl': [1, 3, 5, 7],
      'Ar': [0],
      'K': [1],
      'Ca': [2],
      'Fe': [2, 3],
      'Cu': [1, 2],
      'Zn': [2],
      'Ag': [1],
      'Sn': [2, 4],
      'I': [1, 3, 5, 7],
      'Ba': [2],
      'Au': [1, 3],
      'Hg': [1, 2],
      'Pb': [2, 4],
    };
    final configured = known[symbol];
    if (configured != null) return configured;
    if (kind == ElementKind.metal) {
      return [valenceElectrons.clamp(1, 3)];
    }
    if (kind == ElementKind.metalloid) return [3, 5];
    if (valenceElectrons == 8) return [0];
    return [valenceElectrons.clamp(1, 7)];
  }
}

final _symbols = 'H He Li Be B C N O F Ne Na Mg Al Si P S Cl Ar K Ca Sc Ti V Cr Mn Fe Co Ni Cu Zn Ga Ge As Se Br Kr Rb Sr Y Zr Nb Mo Tc Ru Rh Pd Ag Cd In Sn Sb Te I Xe Cs Ba La Ce Pr Nd Pm Sm Eu Gd Tb Dy Ho Er Tm Yb Lu Hf Ta W Re Os Ir Pt Au Hg Tl Pb Bi Po At Rn Fr Ra Ac Th Pa U Np Pu Am Cm Bk Cf Es Fm Md No Lr Rf Db Sg Bh Hs Mt Ds Rg Cn Nh Fl Mc Lv Ts Og'
    .split(' ');
final _names = 'Hydrogen Helium Lithium Beryllium Boron Carbon Nitrogen Oxygen Fluorine Neon Sodium Magnesium Aluminium Silicon Phosphorus Sulfur Chlorine Argon Potassium Calcium Scandium Titanium Vanadium Chromium Manganese Iron Cobalt Nickel Copper Zinc Gallium Germanium Arsenic Selenium Bromine Krypton Rubidium Strontium Yttrium Zirconium Niobium Molybdenum Technetium Ruthenium Rhodium Palladium Silver Cadmium Indium Tin Antimony Tellurium Iodine Xenon Caesium Barium Lanthanum Cerium Praseodymium Neodymium Promethium Samarium Europium Gadolinium Terbium Dysprosium Holmium Erbium Thulium Ytterbium Lutetium Hafnium Tantalum Tungsten Rhenium Osmium Iridium Platinum Gold Mercury Thallium Lead Bismuth Polonium Astatine Radon Francium Radium Actinium Thorium Protactinium Uranium Neptunium Plutonium Americium Curium Berkelium Californium Einsteinium Fermium Mendelevium Nobelium Lawrencium Rutherfordium Dubnium Seaborgium Bohrium Hassium Meitnerium Darmstadtium Roentgenium Copernicium Nihonium Flerovium Moscovium Livermorium Tennessine Oganesson'
    .split(' ');

const _nonmetals = <String>{
  'H',
  'He',
  'C',
  'N',
  'O',
  'F',
  'Ne',
  'P',
  'S',
  'Cl',
  'Ar',
  'Se',
  'Br',
  'Kr',
  'I',
  'Xe',
  'Rn',
  'Og',
  'Ts',
};
const _metalloids = <String>{'B', 'Si', 'Ge', 'As', 'Sb', 'Te', 'Po'};
const _massNumbers = <int>[
  1,
  4,
  7,
  9,
  11,
  12,
  14,
  16,
  19,
  20,
  23,
  24,
  27,
  28,
  31,
  32,
  35,
  40,
  39,
  40,
  45,
  48,
  51,
  52,
  55,
  56,
  59,
  58,
  64,
  65,
  70,
  73,
  75,
  79,
  80,
  84,
  85,
  88,
  89,
  91,
  93,
  96,
  98,
  101,
  103,
  106,
  108,
  112,
  115,
  119,
  122,
  128,
  127,
  131,
  133,
  137,
  139,
  140,
  141,
  144,
  145,
  150,
  152,
  157,
  159,
  163,
  165,
  167,
  169,
  173,
  175,
  178,
  181,
  184,
  186,
  190,
  192,
  195,
  197,
  201,
  204,
  207,
  209,
  209,
  210,
  222,
  223,
  226,
  227,
  232,
  231,
  238,
  237,
  244,
  243,
  247,
  247,
  251,
  252,
  257,
  258,
  259,
  266,
  267,
  268,
  269,
  270,
  277,
  281,
  282,
  285,
  286,
  289,
  290,
  293,
  294,
  294,
  294,
];

final periodicElements = List<ChemicalElement>.unmodifiable([
  for (var index = 0; index < _symbols.length; index++)
    ChemicalElement(
      number: index + 1,
      symbol: _symbols[index],
      name: _names[index],
      kind: _nonmetals.contains(_symbols[index])
          ? ElementKind.nonmetal
          : _metalloids.contains(_symbols[index])
          ? ElementKind.metalloid
          : ElementKind.metal,
      massNumber: _massNumbers[index],
    ),
]);

ChemicalElement? elementBySymbol(String symbol) {
  for (final element in periodicElements) {
    if (element.symbol == symbol) return element;
  }
  return null;
}

List<int> electronShells(int atomicNumber) {
  var remaining = atomicNumber.clamp(0, 118);
  final shells = List<int>.filled(7, 0);
  const orbitals = <(int, int)>[
    (1, 2),
    (2, 2),
    (2, 6),
    (3, 2),
    (3, 6),
    (4, 2),
    (3, 10),
    (4, 6),
    (5, 2),
    (4, 10),
    (5, 6),
    (6, 2),
    (4, 14),
    (5, 10),
    (6, 6),
    (7, 2),
    (5, 14),
    (6, 10),
    (7, 6),
  ];
  for (final (shell, capacity) in orbitals) {
    final electrons = math.min(remaining, capacity);
    shells[shell - 1] += electrons;
    remaining -= electrons;
    if (remaining == 0) break;
  }
  var lastOccupiedShell = shells.length - 1;
  while (lastOccupiedShell > 0 && shells[lastOccupiedShell] == 0) {
    lastOccupiedShell--;
  }
  return shells.sublist(0, lastOccupiedShell + 1);
}

class AtomNode {
  AtomNode({
    required this.id,
    required this.element,
    required this.x,
    required this.y,
    int? neutrons,
  }) : neutrons = neutrons ?? element.neutrons;

  final String id;
  final ChemicalElement element;
  int neutrons;
  double x;
  double y;
}

enum BondKind { ionic, covalent, metallic }

class AtomBond {
  const AtomBond(this.firstId, this.secondId, this.kind, {this.order = 1});
  final String firstId;
  final String secondId;
  final BondKind kind;
  final int order;
}
