import '../task/intelligence_request.dart';
import 'knowledge_item.dart';
import 'knowledge_query.dart';
import 'knowledge_repository.dart';

/// Contract for resolving relevant knowledge items for a given [IntelligenceRequest].
abstract interface class KnowledgeResolver {
  Future<List<KnowledgeItem>> resolve(IntelligenceRequest request);
}

/// Default implementation querying a [KnowledgeRepository] based on request subject and parameters.
final class DefaultKnowledgeResolver implements KnowledgeResolver {
  final KnowledgeRepository repository;

  const DefaultKnowledgeResolver(this.repository);

  @override
  Future<List<KnowledgeItem>> resolve(IntelligenceRequest request) async {
    return repository.search(
      KnowledgeQuery(text: request.subject),
    );
  }
}
