String languageForPath(String path) {
  final ext = path.split('.').last.toLowerCase();
  switch (ext) {
    case 'dart':
      return 'dart';
    case 'js':
      return 'javascript';
    case 'ts':
    case 'tsx':
      return 'typescript';
    case 'java':
      return 'java';
    case 'py':
      return 'python';
    case 'go':
      return 'go';
    case 'rs':
      return 'rust';
    case 'kt':
    case 'kts':
      return 'kotlin';
    case 'c':
      return 'c';
    case 'cpp':
    case 'cc':
    case 'cxx':
      return 'cpp';
    case 'cs':
      return 'csharp';
    case 'html':
      return 'html';
    case 'css':
      return 'css';
    case 'xml':
      return 'xml';
    case 'json':
      return 'json';
    case 'yaml':
    case 'yml':
      return 'yaml';
    case 'sql':
      return 'sql';
    case 'sh':
    case 'bash':
    case 'zsh':
      return 'shell';
    case 'md':
      return 'markdown';
    case 'txt':
    default:
      return 'text';
  }
}
