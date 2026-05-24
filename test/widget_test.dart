import 'package:flutter_test/flutter_test.dart';

import 'package:journal/main.dart';

void main() {
  testWidgets('App boots to AuthGate', (tester) async {
    await tester.pumpWidget(const JournalApp());
    await tester.pump();
    expect(find.text('Tap to unlock'), findsOneWidget);
  });
}
