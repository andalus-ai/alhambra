enum SymbolKind {
  class_,
  method,
  function,
  variable,
  field,
  constructor,
  interface_,
  enum_,
  parameter,
  property,
}

class WorkspaceSymbol {
  final String id;
  final String name;
  final SymbolKind kind;
  final String filePath;
  final int startLine;
  final int endLine;
  final String? parentId;

  const WorkspaceSymbol({
    required this.id,
    required this.name,
    required this.kind,
    required this.filePath,
    required this.startLine,
    required this.endLine,
    this.parentId,
  });
}

enum ReferenceKind {
  definition,
  call,
  import,
  inheritance,
  implementation,
  read,
  write,
}

class WorkspaceReference {
  final String sourceSymbolId;
  final String targetSymbolId;
  final ReferenceKind kind;

  const WorkspaceReference({
    required this.sourceSymbolId,
    required this.targetSymbolId,
    required this.kind,
  });
}
