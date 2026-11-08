import 'package:flutter_test/flutter_test.dart';
import 'package:alhambra/plugins/workspace/models/agent_context.dart';
import 'package:alhambra/plugins/workspace/services/workspace_indexer_service.dart';

void main() {
  group('WorkspaceIndexerService Unit Tests', () {
    late WorkspaceIndexerService indexer;

    setUp(() {
      indexer = WorkspaceIndexerService();
    });

    test('searchSymbols returns matching symbols', () {
      final results = indexer.searchSymbols('Scrubber');
      expect(results.length, greaterThanOrEqualTo(1));
      expect(results.any((s) => s.name == 'SecretScrubber'), isTrue);
    });

    test('buildContext assigns top relevance to active file and query symbols', () {
      final context = indexer.buildContext(
        'Please refactor scrub logic',
        'lib/security/secret_scrubber.dart',
      );

      expect(context.items.length, greaterThanOrEqualTo(2));
      expect(context.items.first.relevance, 0.98);
      expect(context.items.first.type, AgentContextType.file);
      expect(context.items.any((i) => i.label == 'scrub()'), isTrue);
    });

    test('analyzeImpact returns callers and test targets', () {
      final sym = indexer.searchSymbols('scrub').firstWhere((s) => s.name == 'scrub');
      final report = indexer.analyzeImpact(sym);

      expect(report.target.name, 'scrub');
      expect(report.tests.isNotEmpty, isTrue);
      expect(report.totalImpactScore, greaterThan(0));
    });
  });
}
