import 'package:flutter_test/flutter_test.dart';
import 'package:padel_reservation/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PadelApp());
    expect(find.text('Padel Club'), findsNothing);
  });
}
