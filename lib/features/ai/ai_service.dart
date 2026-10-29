import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

typedef GeminiRequest = Future<String> Function({
  required String userQuestion,
  required String interfaceName,
});

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
      throw ArgumentError.value(userQuestion, 'userQuestion', 'Cannot be empty');
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
}
