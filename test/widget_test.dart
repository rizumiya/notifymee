import 'package:flutter_test/flutter_test.dart';
import 'package:notif_webhook/main.dart';

void main() {
  testWidgets('NotifymeeApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NotifymeeApp());
    expect(find.text('Notifymee'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
