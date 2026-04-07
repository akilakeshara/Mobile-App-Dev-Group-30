import 'package:flutter_test/flutter_test.dart';
import 'package:govease/app.dart';

void main() {
  testWidgets('GovEase app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GovEaseApp());
    expect(find.byType(GovEaseApp), findsOneWidget);
  });
}
