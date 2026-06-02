import 'package:flutter_test/flutter_test.dart';
import 'package:lyricflow/app.dart';

void main() {
  testWidgets('shows the library screen', (tester) async {
    await tester.pumpWidget(const LyricFlowApp());

    expect(find.text('LyricFlow'), findsOneWidget);
    expect(find.text('Selecciona una carpeta de musica'), findsOneWidget);
    expect(find.text('Seleccionar carpeta'), findsOneWidget);
  });
}
