import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:astatine_dashboard/core/localization/app_localizations.dart';
import 'package:astatine_dashboard/core/theme/app_theme.dart';

import 'ai_service.dart';

typedef AssignmentDraftRequest = Future<String> Function(String request);

bool isAssignmentDraftRequest(String message) {
  final normalized = message.toLowerCase();
  final hasVietnameseDraftIntent = ['soạn', 'ra đề'].any(normalized.contains);
  if (hasVietnameseDraftIntent) return true;

  final asksToGenerate =
      RegExp(r'\b(create|generate|draft|make|write)\b').hasMatch(normalized) ||
      ['tạo', 'viết'].any(normalized.contains);
  final asksForQuestions =
      RegExp(r'\b(questions?|quiz|assignment)\b').hasMatch(normalized) ||
      [
        'câu hỏi',
        'câu trắc nghiệm',
        'câu ',
        'câu.',
        'câu,',
        'bài tập',
        'đề',
      ].any(normalized.contains);
  return asksToGenerate && asksForQuestions;
}

class GeminiAssistantBubble extends StatefulWidget {
  const GeminiAssistantBubble({
    super.key,
    required this.isVietnamese,
    this.languageCode,
    required this.interfaceName,
    this.maxPanelHeight,
    this.onAssignmentDraftRequest,
  });

  final bool isVietnamese;
  final String? languageCode;
  final String interfaceName;
  final double? maxPanelHeight;
  final AssignmentDraftRequest? onAssignmentDraftRequest;

  @override
  State<GeminiAssistantBubble> createState() => _GeminiAssistantBubbleState();
}

class _GeminiAssistantBubbleState extends State<GeminiAssistantBubble> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_AssistantMessage>[];
  bool _isOpen = false;
  bool _isThinking = false;

  bool get _vi => widget.isVietnamese;
  String get _languageCode => widget.languageCode ?? (_vi ? 'vi' : 'en');
  AstatinePalette get _palette =>
      Theme.of(context).extension<AstatinePalette>() ?? AstatinePalette.dark;

  String _text(String english, String vietnamese) => _languageCode == 'zh'
      ? AppLocalizations.translateInline(english, languageCode: _languageCode)
      : _vi
      ? vietnamese
      : english;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _isThinking) return;
    final isDraftRequest =
        widget.onAssignmentDraftRequest != null &&
        isAssignmentDraftRequest(question);
    setState(() {
      _messages.add(_AssistantMessage(text: question, isUser: true));
      _controller.clear();
      _isThinking = true;
    });
    _scrollToEnd();

    String answer;
    try {
      answer = isDraftRequest
          ? await widget.onAssignmentDraftRequest!(question)
          : await LabAIService.askAssistant(
              userQuestion: _languageCode == 'zh'
                  ? '请使用简体中文回答：$question'
                  : question,
              interfaceName: widget.interfaceName,
            );
    } catch (error) {
      final errorText = error.toString().toLowerCase();
      final quotaReached =
          errorText.contains('quota') ||
          errorText.contains('resource_exhausted') ||
          errorText.contains('429');
      final responseTruncated =
          errorText.contains('response_truncated') ||
          errorText.contains('max_tokens') ||
          errorText.contains('truncated');
      answer = quotaReached
          ? _text(
              'Gemini has reached today\'s free-tier limit. Please try again after the quota resets.',
              'Gemini đã hết hạn mức miễn phí hôm nay. Vui lòng thử lại sau khi quota được đặt lại.',
            )
          : responseTruncated
          ? _text(
              'Câu trả lời bị giới hạn độ dài. Hãy yêu cầu ngắn hơn hoặc chia nhỏ yêu cầu.',
              'The response exceeded the output limit. Ask for a shorter answer or split the request.',
            )
          : isDraftRequest
          ? _text(
              'Không thể soạn bản nháp lúc này. Hãy thử lại sau.',
              'Could not draft the questions right now. Please try again later.',
            )
          : _text(
              'The AI service is temporarily unavailable. Please try again later.',
              'Dịch vụ AI hiện không khả dụng. Vui lòng thử lại sau.',
            );
    }
    if (!mounted) return;
    setState(() {
      _messages.add(_AssistantMessage(text: answer, isUser: false));
      _isThinking = false;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isOpen) ...[
          Container(
            width: math.min(380, screenSize.width - 32),
            height: math.min(
              math.min(500, screenSize.height * 0.68),
              widget.maxPanelHeight ?? double.infinity,
            ),
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _palette.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _palette.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: _palette.border)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: _palette.accent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gemini',
                              style: TextStyle(
                                color: _palette.primaryText,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.interfaceName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _palette.secondaryText,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: _text('Close', 'Đóng'),
                        onPressed: () => setState(() => _isOpen = false),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              _text(
                                'Ask about lessons or this screen.',
                                'Hỏi về bài học hoặc giao diện này.',
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _palette.secondaryText),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          itemCount: _messages.length + (_isThinking ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length) {
                              return Text(
                                _text(
                                  'Gemini is thinking...',
                                  'Gemini đang suy nghĩ...',
                                ),
                                style: TextStyle(color: _palette.secondaryText),
                              );
                            }
                            final message = _messages[index];
                            return Align(
                              alignment: message.isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 300,
                                ),
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: message.isUser
                                      ? _palette.accent.withValues(alpha: 0.18)
                                      : _palette.input,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  message.text,
                                  style: TextStyle(color: _palette.primaryText),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('floating-gemini-input'),
                          controller: _controller,
                          maxLength: LabAIService.maxPromptCharacters,
                          buildCounter: (
                            context, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => null,
                          minLines: 1,
                          maxLines: 3,
                          onSubmitted: (_) => _send(),
                          style: TextStyle(color: _palette.primaryText),
                          decoration: InputDecoration(
                            hintText: widget.onAssignmentDraftRequest == null
                                ? _text('Ask Gemini...', 'Hỏi Gemini...')
                                : _text(
                                    'Ask or request a quiz draft...',
                                    'Hỏi hoặc yêu cầu soạn câu hỏi...',
                                  ),
                            filled: true,
                            fillColor: _palette.input,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filled(
                        key: const Key('floating-gemini-send'),
                        tooltip: _text('Send', 'Gửi'),
                        onPressed: _send,
                        style: IconButton.styleFrom(
                          backgroundColor: _palette.accent,
                          foregroundColor: _palette.accentText,
                        ),
                        icon: const Icon(Icons.send_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        FloatingActionButton.small(
          key: const Key('floating-gemini-bubble'),
          tooltip: _isOpen ? 'Gemini' : _text('Ask Gemini', 'Hỏi Gemini'),
          onPressed: () => setState(() => _isOpen = !_isOpen),
          backgroundColor: _palette.accent,
          foregroundColor: _palette.accentText,
          child: Icon(_isOpen ? Icons.close : Icons.auto_awesome),
        ),
      ],
    );
  }
}

class _AssistantMessage {
  const _AssistantMessage({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}
