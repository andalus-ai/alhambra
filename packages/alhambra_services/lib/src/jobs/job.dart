import 'job_status.dart';

/// Representation of an asynchronous background job.
final class Job {
  final String id;
  final String type;
  final JobStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final Map<String, Object?> payload;
  final String? error;

  const Job({
    required this.id,
    required this.type,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.payload = const {},
    this.error,
  });

  @override
  String toString() => 'Job($id: $type [$status])';
}
