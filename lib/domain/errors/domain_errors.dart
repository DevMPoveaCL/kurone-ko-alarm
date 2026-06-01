import 'package:kurone_ko_alarm/domain/value_objects/import_source.dart';

/// Base class for domain errors.
sealed class DomainError {
  const DomainError();
}

/// Raised when image or Excel extraction fails.
final class ExtractionFailure extends DomainError {
  final ImportSource? source;
  final String message;

  const ExtractionFailure({this.source, required this.message});

  @override
  String toString() => 'ExtractionFailure(source: $source, message: $message)';
}

/// Raised when alarm scheduling fails.
final class SchedulingFailure extends DomainError {
  final String message;

  const SchedulingFailure({required this.message});

  @override
  String toString() => 'SchedulingFailure(message: $message)';
}

/// Raised when required Android permissions are denied.
final class PermissionDenied extends DomainError {
  final String permission;

  const PermissionDenied({required this.permission});

  @override
  String toString() => 'PermissionDenied(permission: $permission)';
}

/// Raised when reviewed schedule fields cannot be safely scheduled.
final class ScheduleValidationFailure extends DomainError {
  final String message;

  const ScheduleValidationFailure({required this.message});

  @override
  String toString() => 'ScheduleValidationFailure(message: $message)';
}

/// Raised when a file format is not supported.
final class FileNotSupported extends DomainError {
  final String extension;

  const FileNotSupported({required this.extension});

  @override
  String toString() => 'FileNotSupported(extension: $extension)';
}
