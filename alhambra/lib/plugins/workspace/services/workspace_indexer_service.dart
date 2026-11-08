import '../models/agent_context.dart';
import '../models/impact_report.dart';
import '../models/workspace_symbol.dart';

class WorkspaceIndexerService {
  final List<WorkspaceSymbol> _symbols = [];
  final List<WorkspaceReference> _references = [];

  WorkspaceIndexerService() {
    _initSampleIndex();
  }

  void addSymbol(WorkspaceSymbol symbol) {
    _symbols.add(symbol);
  }

  void addReference(WorkspaceReference reference) {
    _references.add(reference);
  }

  List<WorkspaceSymbol> searchSymbols(String query) {
    if (query.trim().isEmpty) return _symbols;
    final q = query.toLowerCase();
    return _symbols.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  /// Builds high-relevance semantic context for an agent prompt
  AgentContext buildContext(String prompt, String? activeFilePath) {
    final List<AgentContextItem> items = [];

    // 1. Active file always gets top ranking (0.98)
    if (activeFilePath != null) {
      items.add(AgentContextItem(
        type: AgentContextType.file,
        label: activeFilePath.split('/').last,
        path: activeFilePath,
        relevance: 0.98,
        reasonIncluded: 'Currently active editor file',
      ));
    }

    // 2. Identify relevant symbols from query
    final lowerPrompt = prompt.toLowerCase();
    for (final sym in _symbols) {
      if (lowerPrompt.contains(sym.name.toLowerCase())) {
        items.add(AgentContextItem(
          type: AgentContextType.symbol,
          label: '${sym.name}()',
          path: sym.filePath,
          startLine: sym.startLine,
          endLine: sym.endLine,
          relevance: 0.92,
          reasonIncluded: 'Symbol explicitly mentioned in prompt',
        ));
      }
    }

    // Sort by relevance descending
    items.sort((a, b) => b.relevance.compareTo(a.relevance));

    return AgentContext(
      prompt: prompt,
      items: items,
      createdAt: DateTime.now(),
    );
  }

  /// Calculates caller and test impact for a given symbol
  ImpactReport analyzeImpact(WorkspaceSymbol symbol) {
    final callers = _symbols
        .where((s) => s.id != symbol.id && s.filePath == symbol.filePath)
        .toList();
    final tests = _symbols
        .where((s) => s.filePath.contains('test') || s.name.contains('Test'))
        .toList();

    return ImpactReport(
      target: symbol,
      callers: callers,
      tests: tests,
      affectedFiles: [symbol.filePath],
    );
  }

  void _initSampleIndex() {
    _symbols.addAll([
      const WorkspaceSymbol(
        id: 'sym-1',
        name: 'SecretScrubber',
        kind: SymbolKind.class_,
        filePath: 'lib/security/secret_scrubber.dart',
        startLine: 1,
        endLine: 80,
      ),
      const WorkspaceSymbol(
        id: 'sym-2',
        name: 'scrub',
        kind: SymbolKind.method,
        filePath: 'lib/security/secret_scrubber.dart',
        startLine: 25,
        endLine: 65,
        parentId: 'sym-1',
      ),
      const WorkspaceSymbol(
        id: 'sym-3',
        name: 'SecretScrubberTest',
        kind: SymbolKind.class_,
        filePath: 'test/security/secret_scrubber_test.dart',
        startLine: 1,
        endLine: 50,
      ),
    ]);
  }
}
