// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:cpos/main.dart';

void main() {
  testWidgets('POS Dashboard renders correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the dashboard title is displayed.
    expect(find.text('Point of Sale'), findsWidgets);
    expect(find.text('Today\'s Revenue'), findsOneWidget);
    expect(find.text('Recent Transactions'), findsOneWidget);
    expect(find.text('Quick Actions'), findsOneWidget);
  });
}