import 'package:flutter_test/flutter_test.dart';

import 'package:user_app/main.dart';

void main() {
  testWidgets('App boots to login route', (WidgetTester tester) async {
    await tester.pumpWidget(const UniApp(initialRoute: '/login'));
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);
  });
}
