import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vfcost_presupuesto/main.dart';

void main() {
  testWidgets('VFCOST App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const VfCostApp());
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('VF COST Pro'), findsOneWidget);
  });
}
