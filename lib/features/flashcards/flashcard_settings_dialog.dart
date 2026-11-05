import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import 'flashcard_service.dart';

class FlashcardSettingsDialog extends StatefulWidget {
  const FlashcardSettingsDialog({super.key});

  @override
  State<FlashcardSettingsDialog> createState() =>
      _FlashcardSettingsDialogState();
}

class _FlashcardSettingsDialogState extends State<FlashcardSettingsDialog> {
  bool _reminderEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool _shuffleMode = false;
  bool _reverseCard = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await FlashcardService.getSettings();
    final timeStr = settings['reminderTime'] as String? ?? '20:00';
    final parts = timeStr.split(':');
    setState(() {
      _reminderEnabled = settings['reminderEnabled'] as bool? ?? true;
      _reminderTime = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 20,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      );
      _shuffleMode = settings['shuffleMode'] as bool? ?? false;
      _reverseCard = settings['reverseCard'] as bool? ?? false;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    await FlashcardService.saveSettings({
      'reminderEnabled': _reminderEnabled,
      'reminderTime':
          '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}',
      'shuffleMode': _shuffleMode,
      'reverseCard': _reverseCard,
    });
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.settings, color: Color(0xFF89B4FA)),
          const Gap(12),
          Text(
            'Cài đặt & Nhắc nhở Flashcard',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 150,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: Text(
                      'Bật nhắc nhở ôn tập hàng ngày',
                      style: GoogleFonts.outfit(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Nhận thông báo in-app & banner đúng giờ',
                      style: GoogleFonts.outfit(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    value: _reminderEnabled,
                    onChanged: (val) => setState(() => _reminderEnabled = val),
                  ),
                  if (_reminderEnabled) ..._buildReminderTimePicker(),
                  const Divider(color: Colors.white24, height: 24),
                  SwitchListTile(
                    title: Text(
                      'Xáo trộn thứ tự thẻ (Shuffle Mode)',
                      style: GoogleFonts.outfit(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Trộn ngẫu nhiên danh sách thẻ trong mỗi phiên',
                      style: GoogleFonts.outfit(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    value: _shuffleMode,
                    onChanged: (val) => setState(() => _shuffleMode = val),
                  ),
                  SwitchListTile(
                    title: Text(
                      'Đảo chiều thẻ (Mặt sau -> Mặt trước)',
                      style: GoogleFonts.outfit(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Hiển thị Đáp án trước, Câu hỏi sau',
                      style: GoogleFonts.outfit(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    value: _reverseCard,
                    onChanged: (val) => setState(() => _reverseCard = val),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Hủy', style: GoogleFonts.outfit(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF89B4FA),
            foregroundColor: Colors.black,
          ),
          onPressed: _save,
          child: Text(
            'Lưu cài đặt',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildReminderTimePicker() {
    return [
      const Gap(8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Thời gian nhắc nhở:',
              style: GoogleFonts.outfit(color: Colors.white70),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF89B4FA),
                side: const BorderSide(color: Color(0xFF89B4FA)),
              ),
              icon: const Icon(Icons.access_time, size: 16),
              label: Text(
                _reminderTime.format(context),
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _reminderTime,
                );
                if (picked != null) {
                  setState(() => _reminderTime = picked);
                }
              },
            ),
          ],
        ),
      ),
    ];
  }
}
