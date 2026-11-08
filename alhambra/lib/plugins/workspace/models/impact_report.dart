import 'workspace_symbol.dart';

class ImpactReport {
  final WorkspaceSymbol target;
  final List<WorkspaceSymbol> callers;
  final List<WorkspaceSymbol> tests;
  final List<WorkspaceSymbol> implementations;
  final List<String> affectedFiles;

  const ImpactReport({
    required this.target,
    this.callers = const [],
    this.tests = const [],
    this.implementations = const [],
    this.affectedFiles = const [],
  });

  int get totalImpactScore =>
      callers.length +
      (tests.length * 2) +
      implementations.length +
      affectedFiles.length;
}
