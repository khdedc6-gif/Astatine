import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astatine_dashboard/core/theme/app_theme.dart';
import 'package:astatine_dashboard/features/dashboard/mini_news_ticker.dart';

void main() {
  testWidgets('news feed card displays image, gradient, and clamped copy', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 170,
            child: NewsFeedCard(
              title:
                  'A long technology headline that must stay within two lines',
              description: 'A long article description that needs to be shortened to fit this compact editorial news card without overflowing its bounds.',
              imageUrl: 'https://example.com/news.jpg',
              palette: AstatinePalette.dark,
              isVietnamese: true,
              onTap: () => opened = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.cover);

    final gradientBox = tester.widget<DecoratedBox>(
      find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).gradient is LinearGradient,
      ),
    );
    final gradient =
        (gradientBox.decoration as BoxDecoration).gradient! as LinearGradient;
    expect(gradient.begin, Alignment.topCenter);
    expect(gradient.end, Alignment.bottomCenter);
    expect(gradient.colors.first, Colors.transparent);
    expect(gradient.colors.last, const Color.fromRGBO(0, 0, 0, 0.85));

    final card = tester.widget<Material>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Material &&
            widget.borderRadius == BorderRadius.circular(16),
      ),
    );
    expect(card.clipBehavior, Clip.antiAlias);

    final copy = tester.widgetList<Text>(find.byType(Text)).toList();
    expect(copy[0].maxLines, 2);
    expect(copy[0].overflow, TextOverflow.ellipsis);
    expect(copy[1].maxLines, 2);
    expect(copy[1].overflow, TextOverflow.ellipsis);
    expect(find.textContaining('A long technology headline'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(InkWell));
    expect(opened, isTrue);
  });

  testWidgets('news feed card remains bounded with enlarged text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: Scaffold(
            body: SizedBox(
              width: 220,
              height: 120,
              child: NewsFeedCard(
                title: 'Long headline with enlarged text that wraps',
                description: 'Long description that may need scrolling.',
                imageUrl: null,
                palette: AstatinePalette.dark,
                isVietnamese: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
