import 'package:file_picker/file_picker.dart' as plugin;
import 'package:kurone_ko_alarm/domain/ports/outbound/file_picker.dart';

/// Small seam over the plugin static API so the adapter remains unit-testable.
abstract interface class FlutterFilePickerGateway {
  Future<FlutterFilePickerGatewayResult?> pick({
    required List<String>? allowedExtensions,
  });
}

/// Plugin-neutral selected-file DTO used by [FlutterFilePickerAdapter].
final class FlutterFilePickerGatewayResult {
  final String? path;
  final String name;
  final String? extension;

  const FlutterFilePickerGatewayResult({
    required this.path,
    required this.name,
    required this.extension,
  });
}

/// File picker adapter backed by the `file_picker` Flutter plugin.
final class FlutterFilePickerAdapter implements FilePicker {
  FlutterFilePickerAdapter({FlutterFilePickerGateway? gateway})
    : _gateway = gateway ?? const _PluginFlutterFilePickerGateway();

  final FlutterFilePickerGateway _gateway;

  @override
  Future<FilePickResult?> pick({required FilePickType type}) async {
    final selected = await _gateway.pick(
      allowedExtensions: _allowedExtensionsFor(type),
    );
    final path = selected?.path;
    if (selected == null || path == null) {
      return null;
    }

    return FilePickResult(
      path: path,
      fileName: selected.name,
      extension: selected.extension?.toLowerCase(),
    );
  }

  List<String>? _allowedExtensionsFor(FilePickType type) {
    return switch (type) {
      FilePickType.image => const ['jpg', 'jpeg', 'png', 'webp'],
      FilePickType.excel => const ['xlsx'],
      FilePickType.any => null,
    };
  }
}

final class _PluginFlutterFilePickerGateway
    implements FlutterFilePickerGateway {
  const _PluginFlutterFilePickerGateway();

  @override
  Future<FlutterFilePickerGatewayResult?> pick({
    required List<String>? allowedExtensions,
  }) async {
    final result = await plugin.FilePicker.platform.pickFiles(
      type: allowedExtensions == null
          ? plugin.FileType.any
          : plugin.FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: false,
      withData: false,
    );
    final file = result?.files.firstOrNull;
    if (file == null) {
      return null;
    }

    return FlutterFilePickerGatewayResult(
      path: file.path,
      name: file.name,
      extension: file.extension,
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
