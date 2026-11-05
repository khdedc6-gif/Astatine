import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:astatine_dashboard/core/theme/app_theme.dart';
import 'package:astatine_dashboard/core/ui/glide_select.dart';
import 'package:astatine_dashboard/core/ui/hover_ripple.dart';

import 'chemical_models.dart';
import 'molecule_tile_physics.dart';
import 'pseudo_3d_beaker.dart';
import 'reaction_engine.dart';

class _LabBottleOption {
  const _LabBottleOption({
    required this.id,
    required this.objectName,
    required this.formula,
    required this.chemicalId,
  });

  final String id;
  final String objectName;
  final String formula;
  final String chemicalId;
}

class VirtualChemistryLabScreen extends StatefulWidget {
  const VirtualChemistryLabScreen({
    super.key,
    required this.isVietnamese,
    this.languageToggle,
    this.onClose,
  });

  final bool isVietnamese;
  final Widget? languageToggle;
  final VoidCallback? onClose;

  @override
  State<VirtualChemistryLabScreen> createState() =>
      _VirtualChemistryLabScreenState();
}

class _VirtualChemistryLabScreenState extends State<VirtualChemistryLabScreen>
    with TickerProviderStateMixin {
  AstatinePalette get _palette =>
      Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;
  Color get _background => _palette.background;
  Color get _panel => _palette.card;
  Color get _blue => _palette.accent;
  Color get _muted => _palette.secondaryText;

  final _engine = const ReactionEngine();
  final List<Chemical> _contents = [];
  final List<MoleculeTile> _moleculeTiles = [];
  final math.Random _spawnRandom = math.Random();
  final MoleculeTilePhysics _physics = MoleculeTilePhysics();
  final ReactionQueue _reactionQueue = ReactionQueue();
  final ScrollController _categoryScrollController = ScrollController();
  final GlobalKey _beakerCanvasKey = GlobalKey();
  late final AnimationController _animationController;
  late final AnimationController _reactionAnimationController;
  Duration _lastPhysicsFrame = Duration.zero;
  Timer? _reactionTimer;
  bool _isPaused = false;
  bool _isSlowMotion = false;
  bool _burnerLit = false;
  double _temperature = 24;
  ReactionResult? _result;
  bool _isHoveringBeaker = false;
  bool _showLabware = false;
  String _selectedBottleId = 'flask-05';
  final Map<String, int> _bottleCounts = {};
  PaletteCategory _paletteCategory = PaletteCategory.metals;
  String _paletteSearch = '';

  static const _bottleOptions = [
    _LabBottleOption(
      id: 'flask-01',
      objectName: 'Flask_01',
      formula: 'HCl',
      chemicalId: 'hcl',
    ),
    _LabBottleOption(
      id: 'flask-05',
      objectName: 'Flask_05',
      formula: 'NaOH',
      chemicalId: 'naoh',
    ),
  ];

  String _text(String english, String vietnamese) =>
      widget.isVietnamese ? vietnamese : english;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 30))
          ..addListener(_updatePhysics)
          ..repeat();
    _reactionAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
  }

  @override
  void didUpdateWidget(covariant VirtualChemistryLabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVietnamese != widget.isVietnamese && _contents.isNotEmpty) {
      _result = _engine.evaluateLocalized(
        _contents,
        _temperature,
        isVietnamese: widget.isVietnamese,
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _reactionAnimationController.dispose();
    _reactionTimer?.cancel();
    _reactionQueue.clear();
    _categoryScrollController.dispose();
    super.dispose();
  }

  void _addChemical(Chemical chemical, {Offset? dropGlobalPosition}) {
    setState(() {
      _contents.add(chemical);
      final dropPosition = dropGlobalPosition == null
          ? null
          : _dropPositionInBeaker(dropGlobalPosition);
      _addMoleculeTiles(chemical, dropPosition: dropPosition);
      _evaluateReaction(addedChemical: chemical);
    });
  }

  Offset? _dropPositionInBeaker(Offset globalPosition) {
    final object = _beakerCanvasKey.currentContext?.findRenderObject();
    if (object is! RenderBox || !object.hasSize) return null;
    final local = object.globalToLocal(globalPosition);
    final normalized = Offset(
      local.dx / object.size.width,
      local.dy / object.size.height,
    );
    final y = normalized.dy.clamp(0.16, 0.82);
    final narrowing = (y * 0.10);
    final minX = 0.22 + narrowing + 0.03;
    final maxX = 0.78 - narrowing - 0.03;
    return Offset(normalized.dx.clamp(minX, maxX), y);
  }

  void _addMoleculeTiles(Chemical chemical, {Offset? dropPosition}) {
    final liquid =
        chemical.state == ChemicalState.aqueous ||
        chemical.state == ChemicalState.liquid;
    final gas = chemical.state == ChemicalState.gas;
    final count = liquid
        ? _liquidSpawnCount
        : gas
        ? 5
        : 1;
    final existingLiquidTiles = _moleculeTiles
        .where((tile) => tile.formula == chemical.formula && tile.isFluid)
        .length;
    final spawnCount = count;
    for (var copy = 0; copy < spawnCount; copy++) {
      final motion = gas
          ? SymbolicParticleMotion.gas
          : chemical.solubility == Solubility.insoluble
          ? SymbolicParticleMotion.precipitate
          : chemical.state == ChemicalState.solid
          ? SymbolicParticleMotion.solid
          : SymbolicParticleMotion.suspended;
      final isFluid = liquid;
      final position = isFluid
          ? _liquidGridPosition(
              existingLiquidTiles + copy,
              formula: chemical.formula,
            )
          : dropPosition ??
                Offset(
                  0.48 + _spawnRandom.nextDouble() * 0.04,
                  gas ? 0.58 : 0.16,
                );
      _moleculeTiles.add(
        MoleculeTile(
          formula: chemical.formula,
          color: chemical.color,
          motion: motion,
          seed: _spawnRandom.nextDouble(),
          createdAt: DateTime.now(),
          x: position.dx,
          y: position.dy,
          velocityX: isFluid ? (_spawnRandom.nextDouble() - 0.5) * 0.12 : 0,
          velocityY: gas ? -0.16 : 0,
          isFluid: isFluid,
          remainingLife: gas ? 5.5 : double.infinity,
        ),
      );
    }
  }

  static const int _liquidSpawnCount = 100;

  Offset _liquidGridPosition(int index, {String formula = 'H2O'}) {
    const columns = 10;
    const rows = 10;
    final column = index % columns;
    final row = index ~/ columns % rows;
    final xStep = columns == 1 ? 0.0 : column / (columns - 1);
    final yStep = rows == 1 ? 0.0 : row / (rows - 1);
    final existingCopies = _moleculeTiles
        .where((particle) => particle.formula == formula && particle.isFluid)
        .length;
    final batch = existingCopies ~/ _liquidSpawnCount;
    final layer = (formula.hashCode % 5) + batch % 3;
    final y = 0.50 + yStep * 0.34;
    final left = 0.22 + y * 0.10 + 0.055;
    final right = 0.78 - y * 0.10 - 0.055;
    return Offset(
      (left + xStep * (right - left) + layer * 0.001)
          .clamp(left, right)
          .toDouble(),
      y,
    );
  }

  void _toggleSimulationPause() {
    setState(() {
      _isPaused = !_isPaused;
      _lastPhysicsFrame =
          _animationController.lastElapsedDuration ?? Duration.zero;
      if (_isPaused) {
        _animationController.stop(canceled: false);
        _reactionAnimationController.stop(canceled: false);
      } else {
        _animationController.repeat();
        if (_reactionAnimationController.value > 0 &&
            _reactionAnimationController.value < 1) {
          _reactionAnimationController.forward();
        }
      }
    });
  }

  void _toggleSlowMotion() {
    setState(() => _isSlowMotion = !_isSlowMotion);
  }

  void _updatePhysics() {
    final object = _beakerCanvasKey.currentContext?.findRenderObject();
    if (object is! RenderBox || !object.hasSize) {
      _lastPhysicsFrame =
          _animationController.lastElapsedDuration ?? Duration.zero;
      return;
    }
    final now = _animationController.lastElapsedDuration ?? Duration.zero;
    final delta = (now - _lastPhysicsFrame).inMicroseconds / 1000000;
    _lastPhysicsFrame = now;
    if (delta <= 0) return;

    final reactions = _physics.update(
      _moleculeTiles,
      size: object.size,
      deltaSeconds: delta * (_isSlowMotion ? 0.5 : 1.0),
      temperature: _temperature,
      burnerLit: _burnerLit,
    );
    if (reactions.isEmpty || !mounted) return;
    setState(() {
      for (final reaction in reactions) {
        final result = _engine.evaluateReactionFormulas(
          reaction.firstFormula,
          reaction.secondFormula,
          temperature: _temperature,
          isVietnamese: widget.isVietnamese,
          burnerLit: _burnerLit,
        );
        if (result != null) _result = result;
      }
      _reactionAnimationController.forward(from: 0);
    });
  }

  void _addBottle(_LabBottleOption bottle) {
    final chemical = ChemicalCatalog.reagents.firstWhere(
      (item) => item.id == bottle.chemicalId,
    );
    setState(() {
      _selectedBottleId = bottle.id;
      _bottleCounts.update(bottle.id, (count) => count + 1, ifAbsent: () => 1);
      _contents.add(chemical);
      _addMoleculeTiles(chemical);
      _evaluateReaction(addedChemical: chemical);
    });
  }

  void _evaluateReaction({Chemical? addedChemical}) {
    if (addedChemical == null) {
      _result = _engine.evaluateLocalized(
        _contents,
        _temperature,
        isVietnamese: widget.isVietnamese,
        burnerLit: _burnerLit,
      );
      return;
    }
    final collidingMetalWaterPair =
        _contents.any((item) => item.formula == 'H2O') &&
        _contents.any(
          (item) => const {'K', 'Na', 'Ba', 'Ca'}.contains(item.formula),
        );
    if (collidingMetalWaterPair &&
        (const {'K', 'Na', 'Ba', 'Ca', 'H2O'}.contains(addedChemical.formula) ||
            addedChemical.category == ChemicalCategory.salt)) {
      _result = null;
      return;
    }
    final metal = _contents.lastWhere(
      (item) => item.category == ChemicalCategory.metal,
      orElse: () => addedChemical,
    );
    final acid = _contents.lastWhere(
      (item) => item.category == ChemicalCategory.acid,
      orElse: () => addedChemical,
    );
    if (metal.category == ChemicalCategory.metal &&
        acid.category == ChemicalCategory.acid &&
        const {
          'K',
          'Na',
          'Mg',
          'Al',
          'Zn',
          'Fe',
          'Pb',
          'Ca',
          'Ba',
        }.contains(metal.formula) &&
        const {'HCl', 'H2SO4'}.contains(acid.formula)) {
      _result = null;
      return;
    }
    _reactionTimer?.cancel();
    _reactionQueue.clear();
    final stages = _engine.evaluateReactionSequence(
      _contents.take(_contents.length - 1).toList(),
      addedChemical,
      temperature: _temperature,
      isVietnamese: widget.isVietnamese,
    );
    if (stages.isEmpty) {
      _result = _engine.evaluateLocalized(
        _contents,
        _temperature,
        isVietnamese: widget.isVietnamese,
        burnerLit: _burnerLit,
      );
      return;
    }
    _reactionQueue.replaceWith(stages);
    _advanceReactionQueue();
  }

  void _advanceReactionQueue() {
    final stage = _reactionQueue.takeNext();
    if (stage == null) return;

    _result = stage;
    _consumeReactantTiles(stage.equation);
    final spawnedAt = DateTime.now();
    var nextFluidIndex = _moleculeTiles
        .where((particle) => particle.isFluid)
        .length;
    _moleculeTiles.addAll(
      stage.textParticles.map((tile) {
        final position = tile.motion == SymbolicParticleMotion.gas
            ? Offset(0.5, 0.62)
            : _liquidGridPosition(
                nextFluidIndex++ % _liquidSpawnCount,
                formula: tile.formula,
              );
        return tile.copyWith(
          createdAt: spawnedAt,
          x: position.dx,
          y: position.dy,
          velocityX: (_spawnRandom.nextDouble() - 0.5) * 0.18,
          velocityY: tile.motion == SymbolicParticleMotion.gas ? -0.18 : 0,
          isFluid: tile.motion == SymbolicParticleMotion.suspended,
          remainingLife: tile.motion == SymbolicParticleMotion.gas
              ? 5.5
              : double.infinity,
        );
      }),
    );
    _reactionAnimationController.forward(from: 0);

    _scheduleReactionAdvance();
  }

  void _scheduleReactionAdvance() {
    _reactionTimer?.cancel();
    final speed = _isSlowMotion ? 0.5 : 1.0;
    _reactionTimer = Timer(Duration(milliseconds: (900 / speed).round()), () {
      if (!mounted) return;
      if (_isPaused) {
        _scheduleReactionAdvance();
        return;
      }
      setState(() {
        _moleculeTiles.removeWhere(
          (tile) => tile.motion == SymbolicParticleMotion.consumed,
        );
        _advanceReactionQueue();
      });
    });
  }

  void _consumeReactantTiles(String equation) {
    if (equation.startsWith('2K + 2H2O →')) return;
    final separator = equation.indexOf('→');
    if (separator < 0) return;
    final reactants = equation.substring(0, separator).split(' + ');
    for (final term in reactants) {
      final normalized = term.trim();
      final coefficient =
          int.tryParse(
            RegExp(r'^\d+').firstMatch(normalized)?.group(0) ?? '',
          ) ??
          1;
      final formula = normalized.replaceFirst(RegExp(r'^\d+'), '');
      var remaining = coefficient;
      for (
        var index = 0;
        index < _moleculeTiles.length && remaining > 0;
        index++
      ) {
        final tile = _moleculeTiles[index];
        if (tile.formula != formula ||
            tile.motion == SymbolicParticleMotion.consumed) {
          continue;
        }
        _moleculeTiles[index] = tile.copyWith(
          motion: SymbolicParticleMotion.consumed,
        );
        remaining--;
      }
    }
  }

  void _flushBeaker() {
    setState(() {
      _contents.clear();
      _moleculeTiles.clear();
      _reactionTimer?.cancel();
      _reactionQueue.clear();
      _temperature = 24;
      _result = null;
      _reactionAnimationController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => constraints.maxWidth >= 1000
                    ? _buildWideLayout()
                    : _buildCompactLayout(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 18, 12),
      child: Row(
        children: [
          IconButton(
            key: const Key('chemistry-lab-back'),
            tooltip: _text('Back to laboratories', 'Quay lại phòng thí nghiệm'),
            onPressed: widget.onClose,
            color: Colors.white,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 8),
          Icon(Icons.science_outlined, color: _blue, size: 23),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text(
                    '3D Virtual Chemistry Lab',
                    'Phòng thí nghiệm Hóa học 3D',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _palette.canvasText,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _text('AstatineEdu  ·  Grade 9', 'AstatineEdu  ·  Lớp 9'),
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (widget.languageToggle != null) ...[
            const SizedBox(width: 10),
            widget.languageToggle!,
          ],
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 250, child: _buildPalette()),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildBeakerStage()),
                const SizedBox(height: 14),
                _buildTemperatureControl(),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(width: 286, child: _buildResultCard()),
        ],
      ),
    );
  }

  Widget _buildCompactLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 370, child: _buildPalette()),
          const SizedBox(height: 14),
          SizedBox(height: 340, child: _buildBeakerStage()),
          const SizedBox(height: 14),
          _buildTemperatureControl(),
          const SizedBox(height: 14),
          _buildResultCard(),
        ],
      ),
    );
  }

  Widget _buildPalette() {
    final reagents = ChemicalCatalog.reagents.where((chemical) {
      if (chemical.paletteGroup != _paletteCategory) return false;
      final query = _paletteSearch.trim().toLowerCase();
      return query.isEmpty ||
          chemical.formula.toLowerCase().contains(query) ||
          chemical
              .localizedName(widget.isVietnamese)
              .toLowerCase()
              .contains(query);
    }).toList();

    return _panelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            Icons.inventory_2_outlined,
            _text('Reagents', 'Hóa chất'),
          ),
          const SizedBox(height: 9),
          TextField(
            key: const Key('reagent-search'),
            onChanged: (value) => setState(() => _paletteSearch = value),
            style: TextStyle(color: _palette.primaryText, fontSize: 12),
            decoration: InputDecoration(
              hintText: _text('Find a reagent', 'Tìm hóa chất'),
              hintStyle: TextStyle(color: _muted, fontSize: 11),
              prefixIcon: Icon(Icons.search, color: _muted, size: 17),
              isDense: true,
              filled: true,
              fillColor: _palette.input,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _palette.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _palette.border),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Scrollbar(
            key: const Key('palette-category-scrollbar'),
            controller: _categoryScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            interactive: true,
            thickness: 4,
            child: SingleChildScrollView(
              controller: _categoryScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  for (final category in PaletteCategory.values) ...[
                    ChoiceChip(
                      key: Key('palette-filter-${category.name}'),
                      label: GlideSelect(
                        selected: _paletteCategory == category,
                        child: Text(_categoryLabel(category)),
                      ),
                      selected: _paletteCategory == category,
                      onSelected: (_) => setState(() {
                        _paletteCategory = category;
                        _paletteSearch = '';
                      }),
                      labelStyle: TextStyle(
                        color: _paletteCategory == category
                            ? _palette.accent
                            : _muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: _palette.input,
                      selectedColor: _palette.accent.withValues(alpha: 0.2),
                      side: BorderSide(
                        color: _paletteCategory == category
                            ? _blue.withValues(alpha: 0.65)
                            : _palette.border,
                      ),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                    ),
                    const SizedBox(width: 5),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => reagents.isEmpty
                  ? Center(
                      child: Text(
                        _text('No reagents found', 'Không tìm thấy hóa chất'),
                        style: TextStyle(color: _muted, fontSize: 11),
                      ),
                    )
                  : GridView.builder(
                      key: const Key('reagent-grid'),
                      padding: const EdgeInsets.only(bottom: 4),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 7,
                            mainAxisSpacing: 7,
                            childAspectRatio: 1.08,
                          ),
                      itemCount: reagents.length,
                      itemBuilder: (context, index) =>
                          _buildReagentTile(reagents[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(PaletteCategory category) => switch (category) {
    PaletteCategory.metals => _text('Metals', 'Kim loại'),
    PaletteCategory.oxides => _text('Oxides', 'Oxit'),
    PaletteCategory.acids => _text('Acids', 'Axit'),
    PaletteCategory.bases => _text('Bases', 'Bazơ'),
    PaletteCategory.salts => _text('Salts', 'Muối'),
    PaletteCategory.solvents => _text('Medium & gases', 'Môi trường & khí'),
  };

  Color _categoryColor(PaletteCategory category) => switch (category) {
    PaletteCategory.metals => const Color(0xFF9DBCD4),
    PaletteCategory.oxides => const Color(0xFFE9A05B),
    PaletteCategory.acids => const Color(0xFFF08AA4),
    PaletteCategory.bases => const Color(0xFF67D8A2),
    PaletteCategory.salts => const Color(0xFFE8C66A),
    PaletteCategory.solvents => const Color(0xFF8DD8EE),
  };

  Widget _buildReagentTile(Chemical chemical) {
    final categoryColor = _categoryColor(chemical.paletteGroup);
    final formulaColor = MoleculeTile.reagentTextColor(chemical.formula);
    final tile = Material(
      color: _palette.input,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: Key('reagent-${chemical.id}'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => _addChemical(chemical),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: categoryColor.withValues(alpha: 0.38)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                chemical.formula,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: formulaColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                chemical.localizedName(widget.isVietnamese),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _palette.primaryText,
                  fontSize: 9,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Draggable<Chemical>(
      data: chemical,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.92, child: tile),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      child: tile,
    );
  }

  Widget _buildBeakerStage() {
    final selectedBottle = _bottleOptions.firstWhere(
      (item) => item.id == _selectedBottleId,
    );
    return DragTarget<Chemical>(
      onWillAcceptWithDetails: (_) {
        setState(() => _isHoveringBeaker = true);
        return true;
      },
      onLeave: (_) => setState(() => _isHoveringBeaker = false),
      onAcceptWithDetails: (details) {
        setState(() => _isHoveringBeaker = false);
        _addChemical(details.data, dropGlobalPosition: details.offset);
      },
      builder: (context, candidates, rejected) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isHoveringBeaker ? _blue : _palette.border,
            width: _isHoveringBeaker ? 1.5 : 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: MoleculeTileCanvas(
                key: _beakerCanvasKey,
                animation: _animationController,
                reactionAnimation: _reactionAnimationController,
                temperature: _temperature,
                tiles: _moleculeTiles,
                accentColor: _palette.accent,
              ),
            ),
            Positioned(
              top: 14,
              left: 12,
              right: 12,
              child: IgnorePointer(
                child: Text(
                  _showLabware
                      ? '${selectedBottle.objectName} · ${_contents.isEmpty ? selectedBottle.formula : _contents.map((item) => item.formula).join('  ·  ')}'
                      : _contents.isEmpty
                      ? _text(
                          'Drop reagents into the beaker',
                          'Thả hóa chất vào cốc',
                        )
                      : _contents.map((item) => item.formula).join('  ·  '),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
              ),
            ),
            if (candidates.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: _palette.card.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _palette.border),
                      ),
                      child: Text(
                        _text('Release to add', 'Thả để thêm'),
                        style: TextStyle(
                          color: _palette.primaryText,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_showLabware)
              Positioned(
                left: 10,
                right: 10,
                bottom: 54,
                child: _buildBottleTable(),
              ),
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment<bool>(
                          value: false,
                          icon: Icon(Icons.layers_outlined, size: 16),
                          label: GlideSelect(
                            selected: !_showLabware,
                            child: Text(_text('Molecules', 'Phân tử')),
                          ),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          icon: Icon(Icons.view_in_ar_outlined, size: 16),
                          label: GlideSelect(
                            selected: _showLabware,
                            child: Text(_text('Labware', 'Dụng cụ')),
                          ),
                        ),
                      ],
                      selected: {_showLabware},
                      onSelectionChanged: (selection) {
                        setState(() => _showLabware = selection.first);
                      },
                      style: SegmentedButton.styleFrom(
                        foregroundColor: _palette.secondaryText,
                        selectedForegroundColor: _palette.accentText,
                        selectedBackgroundColor: _palette.accent,
                        backgroundColor: _palette.card,
                        side: BorderSide(color: _palette.border),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('simulation-pause'),
                      onPressed: _toggleSimulationPause,
                      icon: Icon(
                        _isPaused ? Icons.play_arrow_rounded : Icons.pause,
                        size: 16,
                      ),
                      label: Text(
                        _isPaused
                            ? _text('Resume', 'Tiếp tục')
                            : _text('Pause', 'Tạm dừng'),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _palette.primaryText,
                        backgroundColor: _palette.card,
                        side: BorderSide(color: _palette.border),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                      ),
                    ),
                    OutlinedButton(
                      key: const Key('simulation-slow-motion'),
                      onPressed: _toggleSlowMotion,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _isSlowMotion
                            ? _palette.accentText
                            : _palette.primaryText,
                        backgroundColor: _isSlowMotion
                            ? _palette.accent
                            : _palette.card,
                        side: BorderSide(
                          color: _isSlowMotion
                              ? _palette.accent
                              : _palette.border,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: Text(_isSlowMotion ? '0.5×' : '1×'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottleTable() {
    return Container(
      key: const Key('chemistry-bottle-table'),
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 3),
      decoration: BoxDecoration(
        color: _palette.card.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _palette.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 5, bottom: 2),
            child: _sectionHeading(
              Icons.science_outlined,
              _text('3D bottles', 'Chai lọ 3D'),
            ),
          ),
          DataTable(
            horizontalMargin: 6,
            columnSpacing: 16,
            headingRowHeight: 27,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 32,
            columns: [
              DataColumn(label: Text(_text('Object', 'Mẫu bình'))),
              DataColumn(label: Text(_text('Reagent', 'Hóa chất'))),
              DataColumn(label: Text(_text('Add', 'Thêm'))),
            ],
            rows: [
              for (final bottle in _bottleOptions)
                DataRow(
                  selected: bottle.id == _selectedBottleId,
                  cells: [
                    DataCell(
                      Text(
                        bottle.objectName,
                        style: TextStyle(
                          color: bottle.id == _selectedBottleId
                              ? _palette.accent
                              : _palette.primaryText,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        bottle.formula,
                        style: TextStyle(color: _muted, fontSize: 11),
                      ),
                    ),
                    DataCell(
                      IconButton(
                        key: Key('add-bottle-${bottle.id}'),
                        tooltip: '${_text('Add', 'Thêm')} ${bottle.objectName}',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 30,
                          height: 30,
                        ),
                        onPressed: () => _addBottle(bottle),
                        icon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_circle_outline,
                              color: _blue,
                              size: 17,
                            ),
                            if ((_bottleCounts[bottle.id] ?? 0) > 0)
                              Text(
                                '${_bottleCounts[bottle.id]}',
                                style: TextStyle(
                                  color: _palette.primaryText,
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTemperatureControl() {
    return _panelCard(
      child: Row(
        children: [
          Icon(Icons.device_thermostat, color: _blue, size: 20),
          const SizedBox(width: 8),
          Text(
            _text('Temp', 'Nhiệt độ'),
            style: TextStyle(color: _palette.primaryText, fontSize: 12),
          ),
          Expanded(
            child: Slider(
              key: const Key('chemistry-temperature'),
              value: _temperature,
              min: 0,
              max: 400,
              divisions: 400,
              activeColor: _blue,
              inactiveColor: _palette.border,
              onChanged: (value) => setState(() {
                _temperature = value;
                _evaluateReaction();
              }),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '${_temperature.round()}°C',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: _palette.primaryText,
                fontSize: 12,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            key: const Key('chemistry-burner'),
            onPressed: () => setState(() {
              _burnerLit = !_burnerLit;
              _evaluateReaction();
            }),
            icon: Icon(
              _burnerLit ? Icons.local_fire_department : Icons.fireplace,
              size: 15,
            ),
            label: Text(_text('Burner', 'Đèn cồn')),
            style: OutlinedButton.styleFrom(
              foregroundColor: _burnerLit ? const Color(0xFFFF9F43) : _muted,
              side: BorderSide(
                color: _burnerLit ? const Color(0xFFFF9F43) : _palette.border,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            key: const Key('flush-beaker'),
            onPressed: _flushBeaker,
            icon: const Icon(Icons.water_drop_outlined, size: 15),
            label: Text(_text('Reset', 'Đặt lại')),
            style: OutlinedButton.styleFrom(
              foregroundColor: _palette.secondaryText,
              side: BorderSide(color: _palette.border),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return _panelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            Icons.analytics_outlined,
            _text('Reaction result', 'Kết quả phản ứng'),
          ),
          const SizedBox(height: 18),
          Text(
            _text('BALANCED EQUATION', 'PHƯƠNG TRÌNH CÂN BẰNG'),
            style: TextStyle(
              color: _muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 9),
          if (_result == null)
            Text(
              _text(
                'Add reagents to see a rule-based reaction.',
                'Thêm hóa chất để xem phản ứng theo quy tắc.',
              ),
              key: const Key('reaction-empty-state'),
              style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
            )
          else
            SelectableText(
              _result!.equation,
              key: const Key('reaction-result-equation'),
              style: TextStyle(
                color: _palette.accent,
                fontSize: 16,
                height: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 20),
          Text(
            _text('OBSERVATION', 'HIỆN TƯỢNG'),
            style: TextStyle(
              color: _muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            _result?.phenomenon ??
                _text(
                  'The beaker is ready for an experiment.',
                  'Cốc thí nghiệm đã sẵn sàng.',
                ),
            key: const Key('reaction-phenomenon'),
            style: TextStyle(
              color: _palette.primaryText,
              fontSize: 12,
              height: 1.55,
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _resultBadge(_reactionLabel(_result!.type), _blue),
                _resultBadge(
                  _intensityLabel(_result!.intensity),
                  _intensityColor(_result!.intensity),
                ),
                _resultBadge(
                  '+${_result!.heatRelease.round()}°',
                  _palette.cream,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _reactionLabel(ReactionType type) => switch (type) {
    ReactionType.neutralization => _text('NEUTRALIZATION', 'TRUNG HÒA'),
    ReactionType.metalWater => _text('METAL + WATER', 'KIM LOẠI + NƯỚC'),
    ReactionType.hydrolysis => _text('HYDROLYSIS', 'THỦY PHÂN'),
    ReactionType.thermalDecomposition => _text(
      'THERMAL DECOMPOSITION',
      'NHIỆT PHÂN',
    ),
    ReactionType.oxideWater => _text('OXIDE + WATER', 'OXIT + NƯỚC'),
    ReactionType.singleDisplacement => _text('SINGLE DISPLACEMENT', 'THẾ ĐƠN'),
    ReactionType.doubleDisplacement => _text('PRECIPITATION', 'KẾT TỦA'),
    ReactionType.gasEvolution => _text('GAS EVOLUTION', 'GIẢI PHÓNG KHÍ'),
  };

  String _intensityLabel(ReactionIntensity intensity) => switch (intensity) {
    ReactionIntensity.normal => _text('NORMAL', 'BÌNH THƯỜNG'),
    ReactionIntensity.vigorous => _text('VIOLENT', 'MÃNH LIỆT'),
    ReactionIntensity.explosive => _text('EXPLOSIVE', 'NỔ TUNG'),
  };

  Color _intensityColor(ReactionIntensity intensity) => switch (intensity) {
    ReactionIntensity.normal => const Color(0xFF70D6A6),
    ReactionIntensity.vigorous => const Color(0xFFFFB65C),
    ReactionIntensity.explosive => const Color(0xFFFF6B73),
  };

  Widget _resultBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.28)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700),
    ),
  );

  Widget _sectionHeading(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: _blue, size: 17),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: _palette.primaryText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _panelCard({required Widget child}) {
    return HoverRipple(
      borderRadius: BorderRadius.circular(8),
      color: _palette.accent,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _palette.border),
        ),
        child: child,
      ),
    );
  }
}
