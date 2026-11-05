// Lucian UX/UI Prompt #046 · MIT License (c) 2026 Seokwoooo · https://lucianlabs.dev/uxui-prompt/#046
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final _focusNode = FocusNode(debugLabel: 'Search command palette');
  String _query = '';
  int _activeIndex = 0;
  bool _isOpen = false;

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
  void dispose() {
    _focusNode.dispose();
    super.dispose();
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

        return Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.keyK, control: true):
                _OpenPaletteIntent(),
            SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                _OpenPaletteIntent(),
          },
          child: Actions(
            actions: {
              _OpenPaletteIntent: CallbackAction<_OpenPaletteIntent>(
                onInvoke: (_) {
                  _openPalette();
                  return null;
                },
              ),
            },
            child: OverlayPortal(
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
                child: Focus(
                  onKeyEvent: _handleKeyEvent,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: const Cubic(0.2, 0.8, 0.2, 1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_isOpen ? 14 : 28),
                      boxShadow: [
                        BoxShadow(
                          color: palette.accent.withValues(
                            alpha: _isOpen ? 0.12 : 0.06,
                          ),
                          blurRadius: _isOpen ? 18 : 12,
                          spreadRadius: -5,
                        ),
                      ],
                    ),
                    child: TextField(
                      key: widget.searchKey,
                      focusNode: _focusNode,
                      onChanged: _updateQuery,
                      onTap: _handleFieldTap,
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 13,
                      ),
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
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 13,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            _isOpen ? 14 : 28,
                          ),
                          borderSide: BorderSide(color: palette.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            _isOpen ? 14 : 28,
                          ),
                          borderSide: BorderSide(color: palette.accent),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _updateQuery(String value) {
    final hasQuery = value.trim().isNotEmpty;
    setState(() {
      _query = value;
      _activeIndex = 0;
      _isOpen = hasQuery;
    });
    if (hasQuery) {
      _overlayController.show();
    } else {
      _overlayController.hide();
    }
  }

  void _clearQuery() {
    setState(() {
      _query = '';
      _activeIndex = 0;
      _isOpen = false;
    });
    _overlayController.hide();
    _focusNode.requestFocus();
  }

  void _openPalette() {
    _focusNode.requestFocus();
    if (_query.trim().isEmpty) {
      _overlayController.hide();
      return;
    }
    setState(() => _isOpen = true);
    _overlayController.show();
  }

  void _handleFieldTap() {
    if (_query.trim().isNotEmpty) {
      _openPalette();
    } else {
      if (_isOpen) setState(() => _isOpen = false);
      _overlayController.hide();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() {
        _isOpen = false;
        _query = '';
      });
      _overlayController.hide();
      node.unfocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final matches = _matches;
      if (matches.isEmpty) return KeyEventResult.handled;
      setState(() {
        final delta = event.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1;
        _activeIndex = (_activeIndex + delta + matches.length) % matches.length;
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final matches = _matches;
      if (matches.isNotEmpty) {
        _select(matches[_activeIndex]);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Widget _buildResults() {
    final matches = _matches;
    final palette =
        Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;
    return Material(
      key: const Key('lab-search-results'),
      color: palette.card,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
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
            : Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 400),
                    curve: const Cubic(0.34, 1.45, 0.64, 1),
                    top: _activeIndex * 54.0,
                    left: 8,
                    right: 8,
                    height: 54,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [
                            BoxShadow(
                              color: palette.accent.withValues(alpha: 0.1),
                              blurRadius: 12,
                              spreadRadius: -5,
                            ),
                          ],
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 3,
                            margin: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: palette.accent,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var index = 0; index < matches.length; index++)
                        _buildResult(matches[index], index),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildResult(LabSearchItem item, int index) {
    final palette =
        Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;
    return InkWell(
      onTap: () => _select(item),
      onHover: (_) {
        if (_activeIndex != index) {
          setState(() => _activeIndex = index);
        }
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
                borderRadius: BorderRadius.circular(8),
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

  void _select(LabSearchItem item) {
    _overlayController.hide();
    setState(() {
      _query = '';
      _isOpen = false;
      _activeIndex = 0;
    });
    _focusNode.unfocus();
    widget.onSelected(item);
  }
}

class _OpenPaletteIntent extends Intent {
  const _OpenPaletteIntent();
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
