import 'provenance_ref.dart';

/// A directional relation connecting two entities in the provenance graph.
final class ProvenanceLink {
  final ProvenanceRef from;
  final String relation;
  final ProvenanceRef to;

  const ProvenanceLink({
    required this.from,
    required this.relation,
    required this.to,
  });

  @override
  String toString() => '$from --$relation--> $to';
}

/// A graph of provenance references and relations supporting end-to-end traceability.
final class ProvenanceGraph {
  final List<ProvenanceLink> links;

  const ProvenanceGraph([this.links = const []]);

  /// Finds all outbound links from [ref].
  List<ProvenanceLink> getOutgoing(ProvenanceRef ref) =>
      links.where((l) => l.from == ref).toList();

  /// Finds all inbound links pointing to [ref].
  List<ProvenanceLink> getIncoming(ProvenanceRef ref) =>
      links.where((l) => l.to == ref).toList();

  /// Returns all directly referenced ancestors of [ref].
  Set<ProvenanceRef> getAncestors(ProvenanceRef ref) =>
      links.where((l) => l.from == ref).map((l) => l.to).toSet();

  /// Validates whether all references are reachable or whether any dangling references exist.
  bool containsRef(ProvenanceRef ref) =>
      links.any((l) => l.from == ref || l.to == ref);
}
