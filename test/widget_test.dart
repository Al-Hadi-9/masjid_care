import 'package:flutter_test/flutter_test.dart';
import 'package:masjid_care_project/main.dart';
import 'package:masjid_care_project/screen/app_shell.dart';

void main() {
  testWidgets('app renders the main shell', (WidgetTester tester) async {
    await initializeApp();

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(MyApp), findsOneWidget);
    expect(find.byType(AppShell), findsOneWidget);
  });
}
