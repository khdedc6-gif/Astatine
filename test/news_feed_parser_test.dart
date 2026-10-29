import 'package:flutter_test/flutter_test.dart';
import 'package:astatine_dashboard/features/dashboard/news_feed_parser.dart';

void main() {
  test('parses RSS article text, enclosure image, and encoded URL', () {
    const rss = '''
<rss><channel><item>
  <title><![CDATA[Tiêu đề &amp; công nghệ]]></title>
  <description><![CDATA[<p>Mô tả bài viết.</p><img src="https://example.com/anh.jpg?x=1&amp;y=2"></description>
  <link>https://example.com/bai-viet</link>
  <enclosure url="https://example.com/anh-rss.jpg" type="image/jpeg" />
</item></channel></rss>
''';

    final articles = parseNewsFeedRss(rss);

    expect(articles, hasLength(1));
    expect(articles.single.title, 'Tiêu đề & công nghệ');
    expect(articles.single.description, contains('Mô tả bài viết.'));
    expect(articles.single.link, 'https://example.com/bai-viet');
    expect(articles.single.imageUrl, 'https://example.com/anh-rss.jpg');
  });

  test('uses image embedded in description when enclosure is absent', () {
    const rss = '''
<item>
  <title><![CDATA[Ảnh trong nội dung]]></title>
  <description><![CDATA[<img src="https://example.com/anh.jpg?x=1&amp;y=2"><p>Mô tả.</p>]]></description>
  <link>https://example.com/bai-viet</link>
</item>
''';

    final article = parseNewsFeedRss(rss).single;

    expect(article.description, contains('Mô tả.'));
    expect(article.imageUrl, 'https://example.com/anh.jpg?x=1&y=2');
  });

  test('ignores invalid image URLs and empty article titles', () {
    const rss = '''
<item><title><![CDATA[ ]]></title><description>ignored</description></item>
<item>
  <title><![CDATA[No image]]></title>
  <description><![CDATA[<img src="javascript:alert(1)">Text]]></description>
  <link>https://example.com/</link>
</item>
''';

    final articles = parseNewsFeedRss(rss);

    expect(articles, hasLength(1));
    expect(articles.single.title, 'No image');
    expect(articles.single.imageUrl, isNull);
  });
}
