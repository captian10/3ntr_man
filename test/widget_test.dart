import 'package:flutter_test/flutter_test.dart';

import 'package:antrman/main.dart' as app;

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    app.main();
    await tester.pump(); // first frame
  });
}
