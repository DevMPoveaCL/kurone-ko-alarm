import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurone_ko_alarm/main.dart';

void main() {
  testWidgets('app opens on the import/review flow', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KuroneKoAlarmApp()));

    expect(find.text('Kurone-ko Alarm'), findsOneWidget);
    expect(find.text('Importar Excel'), findsOneWidget);
    expect(find.text('Importar imagen'), findsOneWidget);
  });
}
