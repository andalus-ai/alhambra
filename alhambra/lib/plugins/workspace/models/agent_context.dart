enum AgentContextType {
  file,
  symbol,
  selection,
  test,
  reference,
  dependency,
  gitChange,
}

class AgentContextItem {
  final AgentContextType type;
  final String label;
  final String path;
  final int? startLine;
  final int? endLine;
  final double relevance;
  final String? reasonIncluded;

  const AgentContextItem({
    required this.type,
    required this.label,
    required this.path,
    this.startLine,
    this.endLine,
    this.relevance = 0.0,
    this.reasonIncluded,
  });
}

class AgentContext {
  final String prompt;
  final List<AgentContextItem> items;
  final DateTime createdAt;

  const AgentContext({
    required this.prompt,
    required this.items,
    required this.createdAt,
  });
}
