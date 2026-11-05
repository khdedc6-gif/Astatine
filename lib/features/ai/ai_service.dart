import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

typedef GeminiRequest = Future<String> Function({
  required String userQuestion,
  required String interfaceName,
});

class AssignmentDraftQuestion {
  const AssignmentDraftQuestion({
    required this.text,
    required this.options,
    required this.correctOption,
    this.points = 10,
    this.explanation,
  });

  final String text;
  final List<String> options;
  final int correctOption;
  final double points;
  final String? explanation;
}

class AssignmentDraft {
  const AssignmentDraft({
    required this.title,
    required this.subject,
    required this.questions,
  });

  final String title;
  final String subject;
  final List<AssignmentDraftQuestion> questions;
}

class LabAIService {
  static const int maxPromptCharacters = 4000;
  static const int maxContextCharacters = 6000;

  static String? extractGeminiPrompt(String message) {
    final mention = RegExp(
      r'(^|\s)@Gemini\b',
      caseSensitive: false,
    ).firstMatch(message);
    if (mention == null) return null;
    return message
        .replaceRange(mention.start, mention.end, ' ')
        .replaceFirst(RegExp(r'^[\s,:-]+'), '')
        .trim();
  }

  static Future<String> askAssistant({
    required String userQuestion,
    required String interfaceName,
  }) => askGemini(
    userQuestion: userQuestion,
    labName: interfaceName,
    currentVariables: const {},
  );

  static Future<String> askGemini({
    required String userQuestion,
    required String labName,
    required Map<String, dynamic> currentVariables,
  }) async {
    final prompt = userQuestion.trim();
    if (prompt.isEmpty) {
      throw ArgumentError.value(
        userQuestion,
        'userQuestion',
        'Cannot be empty',
      );
    }
    if (prompt.length > maxPromptCharacters) {
      throw ArgumentError.value(
        userQuestion,
        'userQuestion',
        'Exceeds the $maxPromptCharacters character limit',
      );
    }

    final context = <String, dynamic>{
      'labName': labName,
      'variables': currentVariables,
    };
    // Encode once: used for length validation and then sent in the request body.
    final encodedContext = jsonEncode(context);
    if (encodedContext.length > maxContextCharacters) {
      throw ArgumentError.value(
        context,
        'context',
        'Exceeds the $maxContextCharacters character limit',
      );
    }

    final response = await Supabase.instance.client.functions.invoke(
      'generate-ai',
      body: {'prompt': prompt, 'context': context},
    );
    final data = response.data;
    if (data is Map && data['text'] is String) {
      return (data['text'] as String).trim();
    }
    throw StateError('AI service returned an invalid response.');
  }

  static Future<AssignmentDraft> createAssignmentDraft({
    required String request,
    required String subject,
    required String languageCode,
  }) async {
    final prompt = request.trim();
    if (prompt.isEmpty) {
      throw ArgumentError.value(request, 'request', 'Cannot be empty');
    }
    if (prompt.length > maxPromptCharacters) {
      throw ArgumentError.value(
        request,
        'request',
        'Exceeds the $maxPromptCharacters character limit',
      );
    }

    final response = await Supabase.instance.client.functions.invoke(
      'generate-ai',
      body: {
        'mode': 'create_assignment_draft',
        'prompt': prompt,
        'context': {
          'subject': subject,
          'language': languageCode,
          'template': 'multiple_choice_four_options',
        },
      },
    );
    final data = response.data;
    if (data is! Map || data['type'] != 'assignment_draft') {
      throw StateError('AI did not return an assignment draft.');
    }
    final draft = data['draft'];
    if (draft is! Map || draft['title'] is! String || draft['questions'] is! List) {
      throw StateError('AI returned an invalid assignment draft.');
    }

    final questions = <AssignmentDraftQuestion>[];
    for (final rawQuestion in draft['questions'] as List) {
      if (rawQuestion is! Map ||
          rawQuestion['text'] is! String ||
          rawQuestion['options'] is! List ||
          rawQuestion['correct_option'] is! num) {
        throw StateError('AI returned an invalid question.');
      }
      final options = (rawQuestion['options'] as List)
          .whereType<String>()
          .map((option) => option.trim())
          .toList();
      final correctOption = (rawQuestion['correct_option'] as num).toInt();
      final points = rawQuestion['points'] is num
          ? (rawQuestion['points'] as num).toDouble()
          : 10.0;
      if (options.length != 4 ||
          options.any((option) => option.isEmpty) ||
          correctOption < 0 ||
          correctOption >= options.length ||
          points <= 0 ||
          points > 10) {
        throw StateError('AI returned a question outside the assignment template.');
      }
      questions.add(
        AssignmentDraftQuestion(
          text: (rawQuestion['text'] as String).trim(),
          options: options,
          correctOption: correctOption,
          points: points,
          explanation: rawQuestion['explanation'] is String
              ? (rawQuestion['explanation'] as String).trim()
              : null,
        ),
      );
    }
    if (questions.isEmpty) {
      throw StateError('AI returned an empty assignment draft.');
    }
    return AssignmentDraft(
      title: (draft['title'] as String).trim(),
      subject: draft['subject'] is String
          ? (draft['subject'] as String).trim()
          : subject,
      questions: questions,
    );
  }
}
