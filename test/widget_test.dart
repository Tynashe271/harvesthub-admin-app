import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub_admin_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows secure admin login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AdminApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('HARVESTHUB CONTROL CENTRE'), findsOneWidget);
    expect(find.text('Open admin workspace'), findsOneWidget);
  });
}
