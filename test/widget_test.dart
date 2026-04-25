import 'package:flutter_test/flutter_test.dart';
import 'package:client_flutter/main.dart';

void main() {
  testWidgets('App smoke test — renders EditorPage', (WidgetTester tester) async {
    await tester.pumpWidget(const NewsletterApp());
    expect(find.text('Newspaper Live Layout Studio'), findsOneWidget);
  });
}
