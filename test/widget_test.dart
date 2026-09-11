import 'package:flutter_test/flutter_test.dart';
import 'package:musky/main.dart';

void main() {
  testWidgets('Musky launches with its welcome screen', (tester) async {
    await tester.pumpWidget(const MuskyApp());
    expect(find.text('Welcome to Musky'), findsOneWidget);
    expect(find.text('Stock and client management'), findsOneWidget);
  });
}
