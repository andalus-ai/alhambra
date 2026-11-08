import '../model/workspace.dart';

/// Contract for pre-publication validation gates.
///
/// An application can register multiple gates (e.g. required metadata,
/// validation checks, domain-specific compliance).
/// If any gate returns non-empty blocker messages, publication will fail.
abstract interface class PublishGate {
  Future<List<String>> blockers(Workspace workspace);
}
