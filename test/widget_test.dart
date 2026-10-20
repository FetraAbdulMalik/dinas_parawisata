import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:guriang_garut/main.dart';
import 'package:guriang_garut/providers/app_state.dart';
import 'package:guriang_garut/widgets/guriang_loading_screen.dart';

void main() {
  testWidgets('shows the Garut-themed loading screen during initialization',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const GuriangApp(),
      ),
    );

    expect(find.byType(GuriangLoadingScreen), findsOneWidget);
  });
}
