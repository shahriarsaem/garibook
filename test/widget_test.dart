import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garibook/main.dart';

void main() {
  testWidgets('RouteApp renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: RouteApp(),
      ),
    );
    // TODO: Add meaningful widget assertions as features are implemented
  });
}
