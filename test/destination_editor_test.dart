import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guriang_garut/screens/admin_destinations_screen.dart';

void main() {
  testWidgets('requires destination details and valid coordinates',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: DestinationEditorScreen()),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Simpan destinasi'));
    await tester.tap(find.text('Simpan destinasi'));
    await tester.pumpAndSettle();

    expect(find.text('Wajib diisi.'), findsNWidgets(4));
    expect(
      find.text('Masukkan koordinat antara -90.0 dan 90.0.'),
      findsOneWidget,
    );
    expect(
      find.text('Masukkan koordinat antara -180.0 dan 180.0.'),
      findsOneWidget,
    );
  });
}
