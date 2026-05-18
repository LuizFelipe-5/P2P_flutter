import 'package:flutter_test/flutter_test.dart';

import 'package:offline_sharing/main.dart';

void main() {
  testWidgets('App should render home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const OfflineSharingApp());
    expect(find.text('Offline Share'), findsOneWidget);
  });
}
