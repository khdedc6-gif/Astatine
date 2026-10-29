import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:astatine_dashboard/core/theme/app_theme.dart';

enum LabSearchItemType { destination, lesson }

class LabSearchItem {
  const LabSearchItem({
    required this.title,
    required this.subtitle,
    required this.searchText,
    required this.type,
    this.destinationIndex,
    this.value,
  });

  final String title;
  final String subtitle;
  final String searchText;
  final LabSearchItemType type;
  final int? destinationIndex;
  final Object? value;
}

class LabSearchBar extends StatefulWidget {
  const LabSearchBar({
    super.key,
    required this.items,
    required this.onSelected,
    this.searchKey = const Key('virtual-lab-search'),
    this.hintText = 'Tìm bài học hoặc màn hình...',
  });

  final List<LabSearchItem> items;
  final ValueChanged<LabSearchItem> onSelected;
  final Key searchKey;
  final String hintText;

  @override
  State<LabSearchBar> createState() => _LabSearchBarState();
}

class _LabSearchBarState extends State<LabSearchBar> {
  final _overlayController = OverlayPortalController();
  final _layerLink = LayerLink();
  String _query = '';

  List<LabSearchItem> get _matches {
    final query = _normalize(_query.trim());
    if (query.isEmpty) return const [];

    final scored = <(LabSearchItem, double)>[];
    for (final item in widget.items) {
      final score = _score(query, _normalize(item.searchText));
      if (score >= 0.34) scored.add((item, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(5).map((entry) => entry.$1).toList();
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 320.0;

        return OverlayPortal(
          controller: _overlayController,
          overlayChildBuilder: (context) => CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 7),
            child: Material(
              color: Colors.transparent,
              child: SizedBox(width: width, child: _buildResults()),
            ),
          ),
          child: CompositedTransformTarget(
            link: _layerLink,
            child: TextField(
              key: widget.searchKey,
              onChanged: _updateQuery,
              style: TextStyle(color: palette.primaryText, fontSize: 13),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  color: palette.secondaryText,
                  fontSize: 12,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: palette.secondaryText,
                  size: 19,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Xóa tìm kiếm',
                        onPressed: _clearQuery,
                        icon: const Icon(Icons.close_rounded, size: 17),
                      ),
                filled: true,
                fillColor: palette.input,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: palette.accent),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _updateQuery(String value) {
    setState(() => _query = value);
    if (value.trim().isEmpty) {
      _overlayController.hide();
    } else {
      _overlayController.show();
    }
  }

  void _clearQuery() {
    setState(() => _query = '');
    _overlayController.hide();
  }

  Widget _buildResults() {
    final matches = _matches;
    final palette =
        Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;
    return Material(
      key: const Key('lab-search-results'),
      color: palette.card,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.border),
        ),
        child: matches.isEmpty
            ? Padding(
                padding: EdgeInsets.all(14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Không tìm thấy kết quả phù hợp',
                    style: TextStyle(
                      color: palette.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < matches.length; index++)
                    _buildResult(matches[index], index),
                ],
              ),
      ),
    );
  }

  Widget _buildResult(LabSearchItem item, int index) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;
    return InkWell(
      onTap: () {
        _overlayController.hide();
        setState(() => _query = '');
        widget.onSelected(item);
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: index == 0
              ? null
              : Border(top: BorderSide(color: palette.border)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: palette.input,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                item.type == LabSearchItemType.destination
                    ? Icons.view_in_ar_outlined
                    : Icons.menu_book_outlined,
                color: item.type == LabSearchItemType.destination
                    ? palette.accent
                    : palette.secondaryText,
                size: 17,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.secondaryText,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.north_west_rounded,
              color: palette.secondaryText,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

double _score(String query, String text) {
  if (text.contains(query)) return 1.2 - text.indexOf(query) / text.length;

  final queryWords = query.split(' ').where((word) => word.isNotEmpty);
  final textWords = text.split(RegExp(r'\s+'));
  var total = 0.0;
  var matchedWords = 0;

  for (final queryWord in queryWords) {
    var best = 0.0;
    for (final textWord in textWords) {
      if (textWord.startsWith(queryWord)) {
        best = 1;
      } else if (textWord.contains(queryWord)) {
        best = math.max(best, 0.88);
      } else if (queryWord.length >= 4) {
        final distance = _editDistance(queryWord, textWord);
        final allowedDistance = math.max(1, (queryWord.length * 0.4).ceil());
        if (distance <= allowedDistance) {
          best = math.max(
            best,
            1 - distance / math.max(queryWord.length, textWord.length),
          );
        }
      }
    }
    if (best > 0) matchedWords++;
    total += best;
  }

  if (matchedWords == 0) return 0;
  return total / queryWords.length;
}

int _editDistance(String first, String second) {
  var previous = List<int>.generate(second.length + 1, (index) => index);
  for (var row = 1; row <= first.length; row++) {
    final current = List<int>.filled(second.length + 1, 0);
    current[0] = row;
    for (var column = 1; column <= second.length; column++) {
      final substitutionCost = first[row - 1] == second[column - 1] ? 0 : 1;
      current[column] = math.min(
        math.min(current[column - 1] + 1, previous[column] + 1),
        previous[column - 1] + substitutionCost,
      );
    }
    previous = current;
  }
  return previous[second.length];
}

String _normalize(String value) {
  var normalized = value.toLowerCase();
  const groups = <String, String>{
    'a': 'áàảãạăắằẳẵặâấầẩẫậ',
    'e': 'éèẻẽẹêếềểễệ',
    'i': 'íìỉĩị',
    'o': 'óòỏõọôốồổỗộơớờởỡợ',
    'u': 'úùủũụưứừửữự',
    'y': 'ýỳỷỹỵ',
    'd': 'đ',
  };
  for (final entry in groups.entries) {
    for (final character in entry.value.split('')) {
      normalized = normalized.replaceAll(character, entry.key);
    }
  }
  return normalized.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}
