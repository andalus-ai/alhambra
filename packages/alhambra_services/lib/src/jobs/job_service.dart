import 'job.dart';
import 'job_status.dart';

/// Contract for dispatching, inspecting, and cancelling background jobs.
abstract interface class JobService {
  /// Enqueues a new background job with the given [type] and [payload].
  Future<Job> enqueue(
    String type, {
    Map<String, Object?> payload = const {},
  });

  /// Retrieves a job by its [jobId].
  Future<Job?> get(String jobId);

  /// Requests cancellation of a queued or running job.
  Future<void> cancel(String jobId);
}

/// In-memory implementation of [JobService] for development and testing.
final class InMemoryJobService implements JobService {
  final Map<String, Job> _jobs = {};

  @override
  Future<Job> enqueue(
    String type, {
    Map<String, Object?> payload = const {},
  }) async {
    final id = 'job-${DateTime.now().microsecondsSinceEpoch}-${_jobs.length}';
    final job = Job(
      id: id,
      type: type,
      status: JobStatus.pending,
      createdAt: DateTime.now(),
      payload: payload,
    );
    _jobs[id] = job;
    return job;
  }

  @override
  Future<Job?> get(String jobId) async => _jobs[jobId];

  @override
  Future<void> cancel(String jobId) async {
    final existing = _jobs[jobId];
    if (existing != null && existing.status != JobStatus.completed) {
      _jobs[jobId] = Job(
        id: existing.id,
        type: existing.type,
        status: JobStatus.cancelled,
        createdAt: existing.createdAt,
        startedAt: existing.startedAt,
        completedAt: DateTime.now(),
        payload: existing.payload,
      );
    }
  }

  /// Helper to advance a job status for tests.
  void updateStatus(String jobId, JobStatus status, {String? error}) {
    final existing = _jobs[jobId];
    if (existing != null) {
      _jobs[jobId] = Job(
        id: existing.id,
        type: existing.type,
        status: status,
        createdAt: existing.createdAt,
        startedAt: status == JobStatus.running ? DateTime.now() : existing.startedAt,
        completedAt: (status == JobStatus.completed || status == JobStatus.failed)
            ? DateTime.now()
            : existing.completedAt,
        payload: existing.payload,
        error: error ?? existing.error,
      );
    }
  }
}
