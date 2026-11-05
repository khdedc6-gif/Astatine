import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astatine_dashboard/features/ai/gemini_assistant.dart';

void main() {
  test('recognizes common assignment drafting requests', () {
    expect(
      isAssignmentDraftRequest('Tạo cho tôi 5 câu Hóa học lớp 10'),
      isTrue,
    );
    expect(
      isAssignmentDraftRequest('Soạn bài về phản ứng oxi hóa khử'),
      isTrue,
    );
    expect(isAssignmentDraftRequest('Generate 10 chemistry questions'), isTrue);
    expect(isAssignmentDraftRequest('Độ khó của câu này thế nào?'), isFalse);
  });

  testWidgets(
    'assignment assistant turns draft requests into question drafts',
    (tester) async {
      String? receivedRequest;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 420,
                height: 600,
                child: GeminiAssistantBubble(
                  isVietnamese: true,
                  interfaceName: 'Soạn bài tập',
                  onAssignmentDraftRequest: (request) async {
                    receivedRequest = request;
                    return 'Đã soạn 5 câu hỏi.';
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('floating-gemini-bubble')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('floating-gemini-input')),
        'Tạo cho tôi 5 câu Hóa học lớp 10',
      );
      await tester.tap(find.byKey(const Key('floating-gemini-send')));
      await tester.pumpAndSettle();

      expect(receivedRequest, 'Tạo cho tôi 5 câu Hóa học lớp 10');
      expect(find.text('Đã soạn 5 câu hỏi.'), findsOneWidget);
    },
  );
}
