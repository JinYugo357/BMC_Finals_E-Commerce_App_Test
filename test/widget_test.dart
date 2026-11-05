import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/main.dart';

void main() {
  testWidgets('Product list shows items', (WidgetTester tester) async {
    await tester.pumpWidget(const ShopApp());

    expect(find.text('Tech Out'), findsOneWidget);
    expect(find.text('POWERBANK'), findsOneWidget);
    expect(find.text('AIRPODS'), findsOneWidget);
  });
}