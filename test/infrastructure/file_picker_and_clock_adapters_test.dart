import 'package:flutter_test/flutter_test.dart';
import 'package:kurone_ko_alarm/domain/ports/outbound/file_picker.dart';
import 'package:kurone_ko_alarm/infrastructure/adapters/clock/system_clock.dart';
import 'package:kurone_ko_alarm/infrastructure/adapters/file_picker/flutter_file_picker_adapter.dart';

void main() {
  group('FlutterFilePickerAdapter', () {
    test(
      'maps image picking to image extensions and returns selected file metadata',
      () async {
        final gateway = _FakeFilePickerGateway(
          result: const FlutterFilePickerGatewayResult(
            path: r'C:\imports\break_schedule.PNG',
            name: 'break_schedule.PNG',
            extension: 'PNG',
          ),
        );
        final adapter = FlutterFilePickerAdapter(gateway: gateway);

        final result = await adapter.pick(type: FilePickType.image);

        expect(gateway.lastAllowedExtensions, ['jpg', 'jpeg', 'png', 'webp']);
        expect(result?.path, r'C:\imports\break_schedule.PNG');
        expect(result?.fileName, 'break_schedule.PNG');
        expect(result?.extension, 'png');
      },
    );

    test(
      'returns null when the picker is cancelled or returns a file without a path',
      () async {
        final cancelledGateway = _FakeFilePickerGateway(result: null);
        final nullPathGateway = _FakeFilePickerGateway(
          result: const FlutterFilePickerGatewayResult(
            path: null,
            name: 'memory-only.xlsx',
            extension: 'xlsx',
          ),
        );

        final cancelled = await FlutterFilePickerAdapter(
          gateway: cancelledGateway,
        ).pick(type: FilePickType.excel);
        final missingPath = await FlutterFilePickerAdapter(
          gateway: nullPathGateway,
        ).pick(type: FilePickType.excel);

        expect(cancelledGateway.lastAllowedExtensions, ['xlsx']);
        expect(nullPathGateway.lastAllowedExtensions, ['xlsx']);
        expect(cancelled, isNull);
        expect(missingPath, isNull);
      },
    );
  });

  group('SystemClock', () {
    test('returns the current local time within the call window', () {
      final clock = SystemClock();
      final before = DateTime.now();

      final actual = clock.now();
      final after = DateTime.now();

      expect(actual.isBefore(before), isFalse);
      expect(actual.isAfter(after), isFalse);
    });
  });
}

final class _FakeFilePickerGateway implements FlutterFilePickerGateway {
  _FakeFilePickerGateway({required this.result});

  final FlutterFilePickerGatewayResult? result;
  List<String>? lastAllowedExtensions;

  @override
  Future<FlutterFilePickerGatewayResult?> pick({
    required List<String>? allowedExtensions,
  }) async {
    lastAllowedExtensions = allowedExtensions;
    return result;
  }
}
