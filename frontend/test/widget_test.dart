import 'package:flutter_test/flutter_test.dart';
import 'package:ultimate_frisbee_rules_router/main.dart';

void main() {
  testWidgets('App smoke test - verifies Ultimate Rules Assistant builds successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const UltimateRulesAssistantApp());

    // Verify that our app name is displayed in the sticky header.
    expect(find.text('Ultimate Rules Assistant'), findsOneWidget);
  });
}
