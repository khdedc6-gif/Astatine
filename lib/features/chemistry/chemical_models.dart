import 'package:flutter/material.dart';

enum ChemicalCategory { metal, oxide, acid, base, salt, solvent, gas, water }

enum ChemicalState { solid, liquid, gas, aqueous }

enum Solubility { soluble, insoluble, slightlySoluble, reactive }

enum OxideKind { basic, acidic, amphoteric }

enum PaletteCategory { metals, oxides, acids, bases, salts, solvents }

enum ReactionType {
  neutralization,
  metalWater,
  hydrolysis,
  thermalDecomposition,
  oxideWater,
  singleDisplacement,
  doubleDisplacement,
  gasEvolution,
}

enum ReactionIntensity { normal, vigorous, explosive }

enum ParticleKind { bubble, precipitate, steam }

enum SymbolicParticleMotion { suspended, solid, gas, precipitate, consumed }

class MoleculeTile {
  MoleculeTile({
    required this.formula,
    required this.color,
    required this.motion,
    required this.seed,
    this.createdAt,
    this.velocityX = 0,
    this.velocityY = 0,
    this.isFluid = false,
    this.scale = 1,
    this.thermalTime = 0,
    this.reactionCooldown = 0,
    this.remainingLife = double.infinity,
    this.x = 0.5,
    this.y = 0.68,
    this.tileColor,
    this.textColor,
  });

  final String formula;
  final Color color;
  SymbolicParticleMotion motion;
  final double seed;
  final DateTime? createdAt;
  double x;
  double y;
  double velocityX;
  double velocityY;
  bool isFluid;
  double scale;
  double thermalTime;
  double reactionCooldown;
  double remainingLife;
  final Color? tileColor;
  final Color? textColor;

  Color get backgroundColor => tileColor ?? _styleFor(formula).$1;
  Color get borderColor => _styleFor(formula).$2;
  Color get foregroundColor => textColor ?? _styleFor(formula).$3;

  static Color reagentTextColor(String formula) => _styleFor(formula).$3;

  MoleculeTile copyWith({
    SymbolicParticleMotion? motion,
    double? x,
    double? y,
    DateTime? createdAt,
    double? velocityX,
    double? velocityY,
    bool? isFluid,
    double? scale,
    double? thermalTime,
    double? reactionCooldown,
    double? remainingLife,
  }) => MoleculeTile(
    formula: formula,
    color: color,
    motion: motion ?? this.motion,
    seed: seed,
    createdAt: createdAt ?? this.createdAt,
    velocityX: velocityX ?? this.velocityX,
    velocityY: velocityY ?? this.velocityY,
    isFluid: isFluid ?? this.isFluid,
    scale: scale ?? this.scale,
    thermalTime: thermalTime ?? this.thermalTime,
    reactionCooldown: reactionCooldown ?? this.reactionCooldown,
    remainingLife: remainingLife ?? this.remainingLife,
    x: x ?? this.x,
    y: y ?? this.y,
    tileColor: tileColor,
    textColor: textColor,
  );

  static (Color, Color, Color) _styleFor(String formula) {
    const steelBackground = Color(0xFFE2E8F0);
    const steelBorder = Color(0xFF64748B);
    const paleGreen = Color(0xFFDCFCE7);
    const greenBorder = Color(0xFF22C55E);
    const paleYellow = Color(0xFFFEF9C3);
    const yellowBorder = Color(0xFFEAB308);
    const paleGray = Color(0xFFF1F5F9);
    const grayBorder = Color(0xFF64748B);

    return switch (formula) {
      'H2O' => (
        const Color(0xFFE0F2FE),
        const Color(0xFF38BDF8),
        const Color(0xFF0284C7),
      ),
      'H2' => (
        const Color(0xFFF8FAFC),
        const Color(0xFF94A3B8),
        const Color(0xFF334155),
      ),
      'CO2' || 'SO2' || 'SO3' || 'Cl2' || 'O2' => (
        const Color(0xFFF1F5F9),
        const Color(0xFF64748B),
        const Color(0xFF334155),
      ),
      'K' => (
        const Color(0xFFDDD6FE),
        const Color(0xFF8B5CF6),
        const Color(0xFF6D28D9),
      ),
      'Na' => (
        const Color(0xFFC7D2FE),
        const Color(0xFF6366F1),
        const Color(0xFF4338CA),
      ),
      'Ba' ||
      'Ca' ||
      'Mg' ||
      'Al' ||
      'Zn' ||
      'Pb' => (steelBackground, steelBorder, const Color(0xFF334155)),
      'Fe' => (const Color(0xFF475569), const Color(0xFF1E293B), Colors.white),
      'Cu' => (const Color(0xFFEA580C), const Color(0xFF9A3412), Colors.white),
      'Ag' => (
        const Color(0xFFF8FAFC),
        const Color(0xFF38BDF8),
        const Color(0xFF0369A1),
      ),
      'NaOH' ||
      'KOH' ||
      'Ba(OH)2' ||
      'Ca(OH)2' => (paleGreen, greenBorder, const Color(0xFF166534)),
      'Cu(OH)2' => (
        const Color(0xFF0284C7),
        const Color(0xFF0369A1),
        Colors.white,
      ),
      'Fe(OH)3' => (
        const Color(0xFF9A3412),
        const Color(0xFF7C2D12),
        Colors.white,
      ),
      'Fe(OH)2' => (
        const Color(0xFF166534),
        const Color(0xFF14532D),
        Colors.white,
      ),
      'Al(OH)3' || 'Mg(OH)2' => (
        const Color(0xFFF1F5F9),
        const Color(0xFFCBD5E1),
        const Color(0xFF334155),
      ),
      'Na2O' || 'K2O' || 'CaO' || 'BaO' || 'Al2O3' => (
        const Color(0xFFFEF3C7),
        const Color(0xFFF59E0B),
        const Color(0xFF92400E),
      ),
      'CuO' => (const Color(0xFF1E293B), const Color(0xFF0F172A), Colors.white),
      'Fe2O3' => (
        const Color(0xFF881337),
        const Color(0xFF4C0519),
        Colors.white,
      ),
      'P2O5' => (
        const Color(0xFFFAFAF9),
        const Color(0xFFD6D3D1),
        const Color(0xFF57534E),
      ),
      'HCl' || 'H2SO4' || 'HNO3' || 'H3PO4' || 'H2CO3' || 'H2SO3' || 'H2S' => (
        const Color(0xFFFEE2E2),
        const Color(0xFFEF4444),
        const Color(0xFFB91C1C),
      ),
      'CuSO4' => (
        const Color(0xFF0284C7),
        const Color(0xFF0369A1),
        Colors.white,
      ),
      'FeCl3' => (
        const Color(0xFFD97706),
        const Color(0xFFB45309),
        Colors.white,
      ),
      'AgCl' || 'BaSO4' || 'BaCO3' => (
        Colors.white,
        const Color(0xFF94A3B8),
        const Color(0xFF334155),
      ),
      'CaCO3' => (
        steelBackground,
        const Color(0xFF94A3B8),
        const Color(0xFF334155),
      ),
      'CuS' => (const Color(0xFF0F172A), Colors.black, Colors.white),
      _
          when formula.contains('Cl') ||
              formula.contains('NO3') ||
              formula.endsWith('SO4') ||
              formula.endsWith('CO3') =>
        (paleYellow, yellowBorder, const Color(0xFF854D0E)),
      _ => (paleGray, grayBorder, const Color(0xFF334155)),
    };
  }
}

typedef TextParticle = MoleculeTile;

class ChemicalIon {
  const ChemicalIon({
    required this.symbol,
    required this.charge,
    this.activityRank = 99,
    this.isPolyatomic = false,
    this.isAlkaliMetal = false,
    this.gasWithAcid,
  });

  final String symbol;
  final int charge;
  final int activityRank;
  final bool isPolyatomic;
  final bool isAlkaliMetal;
  final String? gasWithAcid;
}

class Chemical {
  const Chemical({
    required this.id,
    required this.name,
    required this.nameVietnamese,
    required this.formula,
    required this.category,
    required this.state,
    required this.color,
    this.solubility = Solubility.soluble,
    this.cation,
    this.anion,
    this.activityRank = 99,
    this.oxideKind,
    this.acidProtons = 0,
    this.baseHydroxides = 0,
    this.cationCount = 1,
    this.anionCount = 1,
    this.isAlkaliMetal = false,
    this.reactsWithWater = false,
    this.waterProductFormula,
    this.paletteCategory,
  });

  final String id;
  final String name;
  final String nameVietnamese;
  final String formula;
  final ChemicalCategory category;
  final ChemicalState state;
  final Solubility solubility;
  final int activityRank;
  final Color color;
  final ChemicalIon? cation;
  final ChemicalIon? anion;
  final OxideKind? oxideKind;
  final int acidProtons;
  final int baseHydroxides;
  final int cationCount;
  final int anionCount;
  final bool isAlkaliMetal;
  final bool reactsWithWater;
  final String? waterProductFormula;
  final PaletteCategory? paletteCategory;

  PaletteCategory get paletteGroup =>
      paletteCategory ??
      switch (category) {
        ChemicalCategory.metal => PaletteCategory.metals,
        ChemicalCategory.oxide => PaletteCategory.oxides,
        ChemicalCategory.acid => PaletteCategory.acids,
        ChemicalCategory.base => PaletteCategory.bases,
        ChemicalCategory.salt => PaletteCategory.salts,
        ChemicalCategory.solvent ||
        ChemicalCategory.water ||
        ChemicalCategory.gas => PaletteCategory.solvents,
      };

  String localizedName(bool isVietnamese) =>
      isVietnamese ? nameVietnamese : name;
}

typedef ChemicalClass = Chemical;

class ChemicalCatalog {
  ChemicalCatalog._();

  static const hydrogen = ChemicalIon(symbol: 'H', charge: 1, activityRank: 10);
  static const potassium = ChemicalIon(
    symbol: 'K',
    charge: 1,
    activityRank: 1,
    isAlkaliMetal: true,
  );
  static const sodiumIon = ChemicalIon(
    symbol: 'Na',
    charge: 1,
    activityRank: 2,
    isAlkaliMetal: true,
  );
  static const ammonium = ChemicalIon(
    symbol: 'NH4',
    charge: 1,
    isPolyatomic: true,
  );
  static const barium = ChemicalIon(symbol: 'Ba', charge: 2, activityRank: 3);
  static const calcium = ChemicalIon(symbol: 'Ca', charge: 2, activityRank: 4);
  static const magnesium = ChemicalIon(
    symbol: 'Mg',
    charge: 2,
    activityRank: 5,
  );
  static const aluminium = ChemicalIon(
    symbol: 'Al',
    charge: 3,
    activityRank: 6,
  );
  static const zinc = ChemicalIon(symbol: 'Zn', charge: 2, activityRank: 7);
  static const iron = ChemicalIon(symbol: 'Fe', charge: 2, activityRank: 8);
  static const ironThree = ChemicalIon(
    symbol: 'Fe',
    charge: 3,
    activityRank: 8,
  );
  static const lead = ChemicalIon(symbol: 'Pb', charge: 2, activityRank: 9);
  static const copper = ChemicalIon(symbol: 'Cu', charge: 2, activityRank: 11);
  static const silver = ChemicalIon(symbol: 'Ag', charge: 1, activityRank: 12);
  static const chloride = ChemicalIon(symbol: 'Cl', charge: -1);
  static const bromide = ChemicalIon(symbol: 'Br', charge: -1);
  static const oxide = ChemicalIon(symbol: 'O', charge: -2);
  static const hydroxide = ChemicalIon(
    symbol: 'OH',
    charge: -1,
    isPolyatomic: true,
  );
  static const nitrate = ChemicalIon(
    symbol: 'NO3',
    charge: -1,
    isPolyatomic: true,
  );
  static const sulfate = ChemicalIon(
    symbol: 'SO4',
    charge: -2,
    isPolyatomic: true,
  );
  static const carbonate = ChemicalIon(
    symbol: 'CO3',
    charge: -2,
    isPolyatomic: true,
    gasWithAcid: 'CO2',
  );
  static const sulfite = ChemicalIon(
    symbol: 'SO3',
    charge: -2,
    isPolyatomic: true,
    gasWithAcid: 'SO2',
  );
  static const sulfide = ChemicalIon(
    symbol: 'S',
    charge: -2,
    gasWithAcid: 'H2S',
  );
  static const phosphate = ChemicalIon(
    symbol: 'PO4',
    charge: -3,
    isPolyatomic: true,
  );
  static const acetate = ChemicalIon(
    symbol: 'CH3COO',
    charge: -1,
    isPolyatomic: true,
  );
  static const permanganate = ChemicalIon(
    symbol: 'MnO4',
    charge: -1,
    isPolyatomic: true,
  );

  static Chemical _metal(
    String id,
    String name,
    String vi,
    ChemicalIon ion, {
    bool alkali = false,
  }) => Chemical(
    id: id,
    name: name,
    nameVietnamese: vi,
    formula: ion.symbol,
    category: ChemicalCategory.metal,
    state: ChemicalState.solid,
    solubility: Solubility.reactive,
    activityRank: ion.activityRank,
    color: const Color(0xFFC5D3E5),
    cation: ion,
    isAlkaliMetal: alkali,
    reactsWithWater: const {'k', 'na', 'ba', 'ca'}.contains(id),
  );

  static Chemical _oxide(
    String id,
    String name,
    String vi,
    String formula,
    ChemicalIon? cation,
    int cationCount,
    OxideKind kind, {
    bool reactsWithWater = false,
    String? waterProduct,
    bool gas = false,
  }) => Chemical(
    id: id,
    name: name,
    nameVietnamese: vi,
    formula: formula,
    category: ChemicalCategory.oxide,
    state: gas ? ChemicalState.gas : ChemicalState.solid,
    solubility: reactsWithWater ? Solubility.reactive : Solubility.insoluble,
    color: const Color(0xFF8FB8D8),
    cation: cation,
    anion: kind == OxideKind.acidic ? null : oxide,
    cationCount: cationCount,
    oxideKind: kind,
    reactsWithWater: reactsWithWater,
    waterProductFormula: waterProduct,
  );

  static Chemical _acid(
    String id,
    String name,
    String vi,
    String formula,
    ChemicalIon anion,
    int protons,
  ) => Chemical(
    id: id,
    name: name,
    nameVietnamese: vi,
    formula: formula,
    category: ChemicalCategory.acid,
    state: ChemicalState.aqueous,
    solubility: Solubility.soluble,
    color: const Color(0xFF58C8F4),
    cation: hydrogen,
    anion: anion,
    acidProtons: protons,
  );

  static Chemical _base(
    String id,
    String name,
    String vi,
    String formula,
    ChemicalIon cation,
    int hydroxides, {
    Solubility solubility = Solubility.soluble,
  }) => Chemical(
    id: id,
    name: name,
    nameVietnamese: vi,
    formula: formula,
    category: ChemicalCategory.base,
    state: solubility == Solubility.soluble
        ? ChemicalState.aqueous
        : ChemicalState.solid,
    solubility: solubility,
    color: const Color(0xFF67D8B0),
    cation: cation,
    anion: hydroxide,
    baseHydroxides: hydroxides,
  );

  static Chemical _salt(
    String id,
    String name,
    String vi,
    String formula,
    ChemicalIon cation,
    ChemicalIon anion, {
    Solubility solubility = Solubility.soluble,
  }) {
    final cationCount =
        anion.charge.abs() ~/ _gcd(cation.charge.abs(), anion.charge.abs());
    final anionCount =
        cation.charge.abs() ~/ _gcd(cation.charge.abs(), anion.charge.abs());
    return Chemical(
      id: id,
      name: name,
      nameVietnamese: vi,
      formula: formula,
      category: ChemicalCategory.salt,
      state: solubility == Solubility.soluble
          ? ChemicalState.aqueous
          : ChemicalState.solid,
      solubility: solubility,
      color: const Color(0xFF91A8F4),
      cation: cation,
      anion: anion,
      cationCount: cationCount,
      anionCount: anionCount,
    );
  }

  static int _gcd(int a, int b) {
    while (b != 0) {
      final remainder = a % b;
      a = b;
      b = remainder;
    }
    return a;
  }

  static final potassiumMetal = _metal(
    'k',
    'Potassium',
    'Kali',
    potassium,
    alkali: true,
  );
  static final sodiumMetal = _metal(
    'na',
    'Sodium',
    'Natri',
    sodiumIon,
    alkali: true,
  );
  static final bariumMetal = _metal('ba', 'Barium', 'Bari', barium);
  static final calciumMetal = _metal('ca', 'Calcium', 'Canxi', calcium);
  static final magnesiumMetal = _metal('mg', 'Magnesium', 'Magiê', magnesium);
  static final aluminiumMetal = _metal('al', 'Aluminium', 'Nhôm', aluminium);
  static final zincMetal = _metal('zn', 'Zinc', 'Kẽm', zinc);
  static final ironMetal = _metal('fe', 'Iron', 'Sắt', iron);
  static final leadMetal = _metal('pb', 'Lead', 'Chì', lead);
  static final copperMetal = _metal('cu', 'Copper', 'Đồng', copper);
  static final silverMetal = _metal('ag', 'Silver', 'Bạc', silver);

  static final sodium = sodiumMetal;
  static final water = Chemical(
    id: 'h2o',
    name: 'Water',
    nameVietnamese: 'Nước',
    formula: 'H2O',
    category: ChemicalCategory.water,
    state: ChemicalState.liquid,
    solubility: Solubility.soluble,
    color: const Color(0xFF36BDF8),
  );
  static final hydrochloricAcid = _acid(
    'hcl',
    'Hydrochloric acid',
    'Axit clohiđric',
    'HCl',
    chloride,
    1,
  );
  static final sodiumHydroxide = _base(
    'naoh',
    'Sodium hydroxide',
    'Natri hiđroxit',
    'NaOH',
    sodiumIon,
    1,
  );
  static final silverNitrate = _salt(
    'agno3',
    'Silver nitrate',
    'Bạc nitrat',
    'AgNO3',
    silver,
    nitrate,
  );
  static final aluminiumChloride = _salt(
    'alcl3',
    'Aluminium chloride',
    'Nhôm clorua',
    'AlCl3',
    aluminium,
    chloride,
  );
  static final aluminiumSulfate = _salt(
    'al2so43',
    'Aluminium sulfate',
    'Nhôm sunfat',
    'Al2(SO4)3',
    aluminium,
    sulfate,
    solubility: Solubility.soluble,
  );
  static final zincSulfate = _salt(
    'znso4',
    'Zinc sulfate',
    'Kẽm sunfat',
    'ZnSO4',
    zinc,
    sulfate,
  );
  static final calciumCarbide = Chemical(
    id: 'cac2',
    name: 'Calcium carbide',
    nameVietnamese: 'Canxi cacbua',
    formula: 'CaC2',
    category: ChemicalCategory.salt,
    state: ChemicalState.solid,
    solubility: Solubility.reactive,
    color: const Color(0xFF64748B),
    cation: calcium,
    anion: const ChemicalIon(symbol: 'C2', charge: -2),
  );
  static final aluminiumCarbide = Chemical(
    id: 'al4c3',
    name: 'Aluminium carbide',
    nameVietnamese: 'Nhôm cacbua',
    formula: 'Al4C3',
    category: ChemicalCategory.salt,
    state: ChemicalState.solid,
    solubility: Solubility.reactive,
    color: const Color(0xFF475569),
    cation: aluminium,
    anion: const ChemicalIon(symbol: 'C', charge: -4),
    cationCount: 4,
    anionCount: 3,
  );
  static final sodiumAcetate = _salt(
    'ch3coona',
    'Sodium acetate',
    'Natri axetat',
    'CH3COONa',
    sodiumIon,
    acetate,
  );
  static final ammoniumChloride = _salt(
    'nh4cl',
    'Ammonium chloride',
    'Amoni clorua',
    'NH4Cl',
    ammonium,
    chloride,
  );
  static final potassiumPermanganate = _salt(
    'kmno4',
    'Potassium permanganate',
    'Kali pemanganat',
    'KMnO4',
    potassium,
    permanganate,
  );
  static final calciumPhosphide = Chemical(
    id: 'ca3p2',
    name: 'Calcium phosphide',
    nameVietnamese: 'Canxi photphua',
    formula: 'Ca3P2',
    category: ChemicalCategory.salt,
    state: ChemicalState.solid,
    solubility: Solubility.reactive,
    color: const Color(0xFF64748B),
    cation: calcium,
    anion: const ChemicalIon(symbol: 'P', charge: -3),
    cationCount: 3,
    anionCount: 2,
  );

  static final reagents = <Chemical>[
    potassiumMetal,
    sodiumMetal,
    bariumMetal,
    calciumMetal,
    magnesiumMetal,
    aluminiumMetal,
    zincMetal,
    ironMetal,
    leadMetal,
    copperMetal,
    silverMetal,
    _oxide(
      'na2o',
      'Sodium oxide',
      'Natri oxit',
      'Na2O',
      sodiumIon,
      2,
      OxideKind.basic,
      reactsWithWater: true,
    ),
    _oxide(
      'k2o',
      'Potassium oxide',
      'Kali oxit',
      'K2O',
      potassium,
      2,
      OxideKind.basic,
      reactsWithWater: true,
    ),
    _oxide(
      'cao',
      'Calcium oxide',
      'Canxi oxit',
      'CaO',
      calcium,
      1,
      OxideKind.basic,
      reactsWithWater: true,
    ),
    _oxide(
      'bao',
      'Barium oxide',
      'Bari oxit',
      'BaO',
      barium,
      1,
      OxideKind.basic,
      reactsWithWater: true,
    ),
    _oxide(
      'cuo',
      'Copper(II) oxide',
      'Đồng(II) oxit',
      'CuO',
      copper,
      1,
      OxideKind.basic,
    ),
    _oxide(
      'fe2o3',
      'Iron(III) oxide',
      'Sắt(III) oxit',
      'Fe2O3',
      ironThree,
      2,
      OxideKind.basic,
    ),
    _oxide(
      'al2o3',
      'Aluminium oxide',
      'Nhôm oxit',
      'Al2O3',
      aluminium,
      2,
      OxideKind.amphoteric,
    ),
    _oxide(
      'co2',
      'Carbon dioxide',
      'Cacbon đioxit',
      'CO2',
      null,
      0,
      OxideKind.acidic,
      reactsWithWater: true,
      waterProduct: 'H2CO3',
      gas: true,
    ),
    _oxide(
      'so2',
      'Sulfur dioxide',
      'Lưu huỳnh đioxit',
      'SO2',
      null,
      0,
      OxideKind.acidic,
      reactsWithWater: true,
      waterProduct: 'H2SO3',
      gas: true,
    ),
    _oxide(
      'so3',
      'Sulfur trioxide',
      'Lưu huỳnh trioxit',
      'SO3',
      null,
      0,
      OxideKind.acidic,
      reactsWithWater: true,
      waterProduct: 'H2SO4',
      gas: true,
    ),
    _oxide(
      'p2o5',
      'Phosphorus pentoxide',
      'Điphotpho pentaoxit',
      'P2O5',
      null,
      0,
      OxideKind.acidic,
      reactsWithWater: true,
      waterProduct: 'H3PO4',
    ),
    _acid('hcl', 'Hydrochloric acid', 'Axit clohiđric', 'HCl', chloride, 1),
    _acid('h2so4', 'Sulfuric acid', 'Axit sunfuric', 'H2SO4', sulfate, 2),
    _acid('hno3', 'Nitric acid', 'Axit nitric', 'HNO3', nitrate, 1),
    _acid('h2co3', 'Carbonic acid', 'Axit cacbonic', 'H2CO3', carbonate, 2),
    _acid('h2so3', 'Sulfurous acid', 'Axit sunfurơ', 'H2SO3', sulfite, 2),
    _acid('h2s', 'Hydrosulfuric acid', 'Axit sunfuhiđric', 'H2S', sulfide, 2),
    _acid('h3po4', 'Phosphoric acid', 'Axit photphoric', 'H3PO4', phosphate, 3),
    _base('naoh', 'Sodium hydroxide', 'Natri hiđroxit', 'NaOH', sodiumIon, 1),
    _base('koh', 'Potassium hydroxide', 'Kali hiđroxit', 'KOH', potassium, 1),
    _base('baoh2', 'Barium hydroxide', 'Bari hiđroxit', 'Ba(OH)2', barium, 2),
    _base(
      'caoh2',
      'Calcium hydroxide',
      'Canxi hiđroxit',
      'Ca(OH)2',
      calcium,
      2,
      solubility: Solubility.slightlySoluble,
    ),
    _base(
      'cuoh2',
      'Copper(II) hydroxide',
      'Đồng(II) hiđroxit',
      'Cu(OH)2',
      copper,
      2,
      solubility: Solubility.insoluble,
    ),
    _base(
      'feoh3',
      'Iron(III) hydroxide',
      'Sắt(III) hiđroxit',
      'Fe(OH)3',
      ironThree,
      3,
      solubility: Solubility.insoluble,
    ),
    _base(
      'feoh2',
      'Iron(II) hydroxide',
      'Sắt(II) hiđroxit',
      'Fe(OH)2',
      iron,
      2,
      solubility: Solubility.insoluble,
    ),
    _base(
      'aloh3',
      'Aluminium hydroxide',
      'Nhôm hiđroxit',
      'Al(OH)3',
      aluminium,
      3,
      solubility: Solubility.insoluble,
    ),
    _base(
      'mgoh2',
      'Magnesium hydroxide',
      'Magiê hiđroxit',
      'Mg(OH)2',
      magnesium,
      2,
      solubility: Solubility.slightlySoluble,
    ),
    _salt(
      'nacl',
      'Sodium chloride',
      'Natri clorua',
      'NaCl',
      sodiumIon,
      chloride,
    ),
    _salt(
      'kcl',
      'Potassium chloride',
      'Kali clorua',
      'KCl',
      potassium,
      chloride,
    ),
    _salt('bacl2', 'Barium chloride', 'Bari clorua', 'BaCl2', barium, chloride),
    silverNitrate,
    _salt(
      'cuso4',
      'Copper(II) sulfate',
      'Đồng(II) sunfat',
      'CuSO4',
      copper,
      sulfate,
    ),
    _salt(
      'fecl3',
      'Iron(III) chloride',
      'Sắt(III) clorua',
      'FeCl3',
      ironThree,
      chloride,
    ),
    aluminiumChloride,
    aluminiumSulfate,
    zincSulfate,
    _salt(
      'na2co3',
      'Sodium carbonate',
      'Natri cacbonat',
      'Na2CO3',
      sodiumIon,
      carbonate,
    ),
    _salt(
      'agcl',
      'Silver chloride',
      'Bạc clorua',
      'AgCl',
      silver,
      chloride,
      solubility: Solubility.insoluble,
    ),
    _salt(
      'baso4',
      'Barium sulfate',
      'Bari sunfat',
      'BaSO4',
      barium,
      sulfate,
      solubility: Solubility.insoluble,
    ),
    _salt(
      'caco3',
      'Calcium carbonate',
      'Canxi cacbonat',
      'CaCO3',
      calcium,
      carbonate,
      solubility: Solubility.insoluble,
    ),
    _salt(
      'cus',
      'Copper(II) sulfide',
      'Đồng(II) sunfua',
      'CuS',
      copper,
      sulfide,
      solubility: Solubility.insoluble,
    ),
    calciumCarbide,
    aluminiumCarbide,
    calciumPhosphide,
    sodiumAcetate,
    ammoniumChloride,
    potassiumPermanganate,
    water,
    Chemical(
      id: 'cl2',
      name: 'Chlorine',
      nameVietnamese: 'Clo',
      formula: 'Cl2',
      category: ChemicalCategory.gas,
      state: ChemicalState.gas,
      solubility: Solubility.slightlySoluble,
      color: const Color(0xFFD7E76A),
    ),
    Chemical(
      id: 'o2',
      name: 'Oxygen',
      nameVietnamese: 'Oxi',
      formula: 'O2',
      category: ChemicalCategory.gas,
      state: ChemicalState.gas,
      solubility: Solubility.slightlySoluble,
      color: const Color(0xFFB8D5FF),
    ),
    Chemical(
      id: 'h2',
      name: 'Hydrogen',
      nameVietnamese: 'Hiđro',
      formula: 'H2',
      category: ChemicalCategory.gas,
      state: ChemicalState.gas,
      solubility: Solubility.slightlySoluble,
      color: const Color(0xFFC5F2FF),
    ),
  ];
}

class ReactionParticle {
  const ReactionParticle({
    required this.kind,
    required this.color,
    this.count = 16,
    this.speed = 1,
  });

  final ParticleKind kind;
  final Color color;
  final int count;
  final double speed;
}

class ReactionResult {
  const ReactionResult({
    required this.type,
    required this.equation,
    required this.phenomenon,
    required this.liquidColor,
    this.particles = const [],
    this.textParticles = const [],
    this.heatRelease = 0,
    this.intensity = ReactionIntensity.normal,
  });

  final ReactionType type;
  final String equation;
  final String phenomenon;
  final Color liquidColor;
  final List<ReactionParticle> particles;
  final List<MoleculeTile> textParticles;
  final double heatRelease;
  final ReactionIntensity intensity;

  bool get isExothermic => heatRelease > 0;
}
