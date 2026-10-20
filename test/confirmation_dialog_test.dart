import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guriang_garut/utils/confirmation_dialog.dart';

void main() {
  testWidgets('shows the branded confirmation dialog and returns the choice',
      (tester) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showConfirmationDialog(
                  context: context,
                  title: 'Buka Google Maps?',
                  message: 'Buka rute ke Gunung Papandayan di Google Maps?',
                );
              },
              child: const Text('Open confirmation'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open confirmation'));
    await tester.pumpAndSettle();

    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.backgroundColor, Colors.white);
    expect(find.text('Buka Google Maps?'), findsOneWidget);
    expect(find.text('Buka rute ke Gunung Papandayan di Google Maps?'),
        findsOneWidget);
    expect(find.text('IYA'), findsOneWidget);
    expect(find.text('TIDAK'), findsOneWidget);
    expect(
      find.image(const AssetImage(
        'assets/images/logo_kabupaten_garut_transparent.png',
      )),
      findsOneWidget,
    );

    await tester.tap(find.text('IYA'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
