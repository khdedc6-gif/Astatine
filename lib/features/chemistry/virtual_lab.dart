import 'package:flutter/material.dart';

import 'package:astatine_dashboard/core/theme/app_theme.dart';
import 'package:astatine_dashboard/core/ui/search_bar.dart';

import 'atomic_virtual_lab.dart';
import 'virtual_lab_chemistry.dart';

// Model dữ liệu cho mỗi thí nghiệm
class Experiment {
  final String title;
  final String author;
  final String grade;

  const Experiment({
    required this.title,
    this.author = 'AstatineEdu',
    this.grade = 'Lớp 9',
  });
}

class SubjectData {
  final String name;
  final List<Experiment> experiments;

  const SubjectData({required this.name, required this.experiments});
}

const _virtualLabSubjects = [
  SubjectData(
    name: 'Vật lý',
    experiments: [
      Experiment(
        title: 'Sự phụ thuộc của cường độ dòng điện vào hiệu điện thế',
      ),
      Experiment(title: 'Đo công suất tiêu thụ điện năng của dụng cụ điện'),
      Experiment(title: 'Hiện tượng cảm ứng điện từ - Dòng điện xoay chiều'),
      Experiment(title: 'Thấu kính hội tụ và cách tạo ảnh trên màn chắn'),
      Experiment(title: 'Sự khúc xạ ánh sáng qua lăng kính thủy tinh'),
    ],
  ),
  SubjectData(
    name: 'Hóa học',
    experiments: [
      Experiment(title: 'Tính chất hóa học của bazơ và oxit bazơ'),
      Experiment(title: 'Phản ứng trao đổi trong dung dịch chất muối'),
      Experiment(title: 'Điều chế và thử tính chất khí Hidro / Oxi'),
      Experiment(title: 'Nhận biết một số ion và phân biệt phân bón hóa học'),
      Experiment(title: 'Tính chất hóa học của Axit và kim loại hoạt động'),
    ],
  ),
  SubjectData(
    name: 'Sinh học',
    experiments: [
      Experiment(title: 'Thí nghiệm lai một cặp tính trạng của Menđen'),
      Experiment(title: 'Quan sát cấu trúc ADN và mô hình nhiễm sắc thể'),
      Experiment(title: 'Sự biến dị thích nghi ở thực vật và động vật'),
      Experiment(title: 'Khảo sát hệ sinh thái và chuỗi thức ăn trên cạn'),
      Experiment(title: 'Thực hành quan sát cấu trúc tế bào dưới kính hiển vi'),
    ],
  ),
];

class VirtualLabScreen extends StatefulWidget {
  static List<LabSearchItem> get searchableLessons => [
    for (
      var subjectIndex = 0;
      subjectIndex < _virtualLabSubjects.length;
      subjectIndex++
    )
      for (final experiment in _virtualLabSubjects[subjectIndex].experiments)
        LabSearchItem(
          title: experiment.title,
          subtitle: _virtualLabSubjects[subjectIndex].name,
          searchText:
              '${experiment.title} ${_virtualLabSubjects[subjectIndex].name} ${experiment.grade}',
          type: LabSearchItemType.lesson,
          value: (subjectIndex, experiment),
        ),
  ];

  const VirtualLabScreen({
    super.key,
    this.onNavigate,
    this.onOpenProjectHub,
    this.languageToggle,
    this.isVietnamese = false,
    this.initialSearchItem,
    this.onInitialSearchHandled,
  });

  final ValueChanged<int>? onNavigate;
  final VoidCallback? onOpenProjectHub;
  final Widget? languageToggle;
  final bool isVietnamese;
  final LabSearchItem? initialSearchItem;
  final VoidCallback? onInitialSearchHandled;

  @override
  State<VirtualLabScreen> createState() => _VirtualLabScreenState();
}

class _VirtualLabScreenState extends State<VirtualLabScreen> {
  AstatinePalette get _palette =>
      Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;

  List<SubjectData> get _subjects => _virtualLabSubjects;

  final Set<int> _expandedSubjects = {};
  final ScrollController _scrollController = ScrollController();
  bool _showLaboratory = false;
  bool _showChemistryLab = false;
  bool _showAtomicLab = false;
  int _selectedRoomIndex = 0;
  late final List<GlobalKey> _subjectKeys = List.generate(
    _subjects.length,
    (_) => GlobalKey(),
  );

  List<LabSearchItem> get _searchItems => [
    LabSearchItem(
      title: 'Virtual Lab',
      subtitle: 'Phòng thí nghiệm tương tác',
      searchText: ' Virtual Lab Phòng thí nghiệm Vật lý Hóa học Sinh học',
      type: LabSearchItemType.destination,
      destinationIndex: 2,
    ),
    LabSearchItem(
      title: 'Dashboard Overview',
      subtitle: 'Tổng quan',
      searchText: 'Dashboard Overview Tổng quan trang chủ',
      type: LabSearchItemType.destination,
      destinationIndex: 0,
    ),
    LabSearchItem(
      title: 'Classroom Chat',
      subtitle: 'Phòng chat lớp học',
      searchText: 'Classroom Chat Phòng chat lớp học',
      type: LabSearchItemType.destination,
      destinationIndex: 1,
    ),
    LabSearchItem(
      title: 'Assignments',
      subtitle: 'Nhiệm vụ',
      searchText: 'Assignments Nhiệm vụ bài kiểm tra',
      type: LabSearchItemType.destination,
      destinationIndex: 3,
    ),
    LabSearchItem(
      title: 'Class Schedule',
      subtitle: 'Lịch học',
      searchText: 'Class Schedule Schedule Lịch học thời khóa biểu',
      type: LabSearchItemType.destination,
      destinationIndex: 4,
    ),
    LabSearchItem(
      title: 'Settings',
      subtitle: 'Cài đặt',
      searchText: 'Settings Cài đặt',
      type: LabSearchItemType.destination,
      destinationIndex: 5,
    ),
    LabSearchItem(
      title: 'Project Hub',
      subtitle: 'Quản lý dự án và nhóm học tập',
      searchText: 'Project Hub dự án nhóm học tập quản lý file',
      type: LabSearchItemType.destination,
      value: 'project-hub',
    ),
    ...VirtualLabScreen.searchableLessons,
  ];

  @override
  void initState() {
    super.initState();
    final initialSearchItem = widget.initialSearchItem;
    if (initialSearchItem != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _selectSearchItem(initialSearchItem);
        widget.onInitialSearchHandled?.call();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _selectSearchItem(LabSearchItem item) {
    if (item.value == 'project-hub') {
      widget.onOpenProjectHub?.call();
      return;
    }
    final destinationIndex = item.destinationIndex;
    if (destinationIndex != null) {
      if (destinationIndex == 2) {
        setState(() => _showLaboratory = true);
      } else {
        widget.onNavigate?.call(destinationIndex);
      }
      return;
    }

    final (subjectIndex, _) = item.value! as (int, Experiment);
    setState(() => _expandedSubjects.add(subjectIndex));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _subjectKeys[subjectIndex].currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          alignment: 0.12,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _palette.background,
      body: _showChemistryLab
          ? VirtualChemistryLabScreen(
              isVietnamese: widget.isVietnamese,
              languageToggle: widget.languageToggle,
              onClose: () => setState(() => _showChemistryLab = false),
            )
          : _showAtomicLab
          ? AtomicVirtualLabScreen(
              isVietnamese: widget.isVietnamese,
              languageToggle: widget.languageToggle,
              onClose: () => setState(() => _showAtomicLab = false),
            )
          : _showLaboratory
          ? _buildLaboratoryWorkspace()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Row(
                    children: [
                      const Spacer(),
                      Flexible(
                        flex: 4,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: LabSearchBar(
                            items: _searchItems,
                            onSelected: _selectSearchItem,
                            hintText: 'Tìm bài học, màn hình, dự án...',
                          ),
                        ),
                      ),
                      if (widget.languageToggle != null) ...[
                        const SizedBox(width: 12),
                        widget.languageToggle!,
                      ],
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        key: const Key('open-laboratory'),
                        onPressed: () => setState(() => _showLaboratory = true),
                        icon: const Icon(Icons.science_outlined, size: 17),
                        label: Text(_text('Laboratory', 'Phòng thí nghiệm')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _palette.accent,
                          side: BorderSide(color: _palette.border),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Column(
                      children: [
                        for (var index = 0; index < _subjects.length; index++)
                          _buildSubjectSection(index),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _text(String english, String vietnamese) =>
      widget.isVietnamese ? vietnamese : english;

  Widget _buildLaboratoryWorkspace() {
    final rooms = [
      (
        title: _text('Physics Lab', 'Phòng Vật lý'),
        detail: _text(
          'Explore forces, light, and electrical circuits.',
          'Khám phá lực, ánh sáng và các mạch điện.',
        ),
        icon: Icons.bolt_rounded,
        color: _palette.accent,
      ),
      (
        title: _text('Chemistry Lab', 'Phòng Hóa học'),
        detail: _text(
          'Study reactions and the properties of matter.',
          'Tìm hiểu phản ứng và tính chất của vật chất.',
        ),
        icon: Icons.science_outlined,
        color: _palette.accent,
      ),
      (
        title: _text('Biology Lab', 'Phòng Sinh học'),
        detail: _text(
          'Observe cells, organisms, and ecosystems.',
          'Quan sát tế bào, sinh vật và hệ sinh thái.',
        ),
        icon: Icons.biotech_outlined,
        color: _palette.accent,
      ),
      (
        title: _text('Atomic Model', 'Mô hình nguyên tử'),
        detail: _text(
          'Explore atomic structure, orbitals, and nuclear reactions.',
          'Khám phá cấu trúc nguyên tử, orbital và phản ứng hạt nhân.',
        ),
        icon: Icons.blur_circular_rounded,
        color: const Color(0xFF42D9E8),
      ),
    ];
    final selectedRoom = rooms[_selectedRoomIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              IconButton(
                key: const Key('laboratory-back'),
                tooltip: _text('Back to lessons', 'Quay lại bài học'),
                onPressed: () => setState(() => _showLaboratory = false),
                icon: const Icon(Icons.arrow_back_rounded),
                color: _palette.canvasText,
              ),
              const Spacer(),
              if (widget.languageToggle != null) widget.languageToggle!,
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text('Laboratory', 'Phòng thí nghiệm'),
                      style: TextStyle(
                        color: _palette.canvasText,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _text(
                        'Choose a workspace to begin exploring.',
                        'Chọn không gian để bắt đầu khám phá.',
                      ),
                      style: TextStyle(
                        color: _palette.canvasMutedText,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        for (var index = 0; index < rooms.length; index++)
                          _buildLaboratoryRoom(index, rooms[index]),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: _palette.card,
                        border: Border.all(
                          color: selectedRoom.color.withValues(alpha: 0.5),
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedRoom.icon,
                            color: selectedRoom.color,
                            size: 30,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedRoom.title,
                                  style: TextStyle(
                                    color: _palette.primaryText,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  selectedRoom.detail,
                                  style: TextStyle(
                                    color: _palette.secondaryText,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.check_circle_rounded,
                            color: selectedRoom.color,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLaboratoryRoom(
    int index,
    ({String title, String detail, IconData icon, Color color}) room,
  ) {
    final isSelected = _selectedRoomIndex == index;
    return SizedBox(
      width: 300,
      child: InkWell(
        key: Key('laboratory-room-$index'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() {
          _selectedRoomIndex = index;
          _showChemistryLab = index == 1;
          _showAtomicLab = index == 3;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _palette.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? room.color.withValues(alpha: 0.75)
                  : _palette.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(room.icon, color: room.color, size: 24),
              const SizedBox(height: 18),
              Text(
                room.title,
                style: TextStyle(
                  color: _palette.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                room.detail,
                style: TextStyle(
                  color: _palette.secondaryText,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectSection(int subjectIndex) {
    final subject = _subjects[subjectIndex];
    final expanded = _expandedSubjects.contains(subjectIndex);
    final accentColor = _subjectColor(subjectIndex);

    return Padding(
      key: _subjectKeys[subjectIndex],
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 22,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  subject.name,
                  style: TextStyle(
                    color: _palette.canvasText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${subject.experiments.length} bài',
                style: TextStyle(color: _palette.canvasMutedText, fontSize: 11),
              ),
              const SizedBox(width: 4),
              IconButton(
                key: Key('subject-toggle-$subjectIndex'),
                tooltip: expanded ? 'Thu gọn' : 'Xem toàn bộ thí nghiệm',
                onPressed: () => setState(() {
                  if (expanded) {
                    _expandedSubjects.remove(subjectIndex);
                  } else {
                    _expandedSubjects.add(subjectIndex);
                  }
                }),
                icon: AnimatedRotation(
                  turns: expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: accentColor,
                    size: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (expanded)
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final experiment in subject.experiments)
                  _buildExperimentCard(experiment, subjectIndex, accentColor),
              ],
            )
          else
            SizedBox(
              height: 206,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: subject.experiments.length > 2
                    ? 2
                    : subject.experiments.length,
                separatorBuilder: (context, index) => const SizedBox(width: 14),
                itemBuilder: (context, index) => _buildExperimentCard(
                  subject.experiments[index],
                  subjectIndex,
                  accentColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExperimentCard(
    Experiment experiment,
    int subjectIndex,
    Color accentColor,
  ) {
    return SizedBox(
      width: 224,
      height: 206,
      child: _ExperimentCard(
        experiment: experiment,
        subject: _subjects[subjectIndex].name,
        icon: _subjectIcon(subjectIndex),
        accentColor: accentColor,
      ),
    );
  }

  Color _subjectColor(int index) => _palette.accent;

  IconData _subjectIcon(int index) => switch (index) {
    0 => Icons.bolt_rounded,
    1 => Icons.science_outlined,
    _ => Icons.biotech_outlined,
  };
}

class _ExperimentCard extends StatefulWidget {
  const _ExperimentCard({
    required this.experiment,
    required this.subject,
    required this.icon,
    required this.accentColor,
  });

  final Experiment experiment;
  final String subject;
  final IconData icon;
  final Color accentColor;

  @override
  State<_ExperimentCard> createState() => _ExperimentCardState();
}

class _ExperimentCardState extends State<_ExperimentCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedSlide(
        offset: Offset(0, _hovered ? -0.035 : 0),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered
                  ? widget.accentColor.withValues(alpha: 0.65)
                  : palette.border,
            ),
            boxShadow: _hovered && palette.glowEnabled
                ? [
                    BoxShadow(
                      color: widget.accentColor.withValues(alpha: 0.16),
                      blurRadius: 20,
                      offset: const Offset(0, 9),
                    ),
                  ]
                : const [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 92,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.accentColor.withValues(alpha: 0.2),
                        palette.background,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: 12,
                        top: 10,
                        child: Icon(
                          Icons.view_in_ar_outlined,
                          size: 19,
                          color: palette.primaryText.withValues(alpha: 0.55),
                        ),
                      ),
                      Center(
                        child: Icon(
                          widget.icon,
                          color: widget.accentColor,
                          size: 35,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.experiment.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.primaryText,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              widget.subject,
                              style: TextStyle(
                                color: widget.accentColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              widget.experiment.grade,
                              style: TextStyle(
                                color: palette.secondaryText,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
