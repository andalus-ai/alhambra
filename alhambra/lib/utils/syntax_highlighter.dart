import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A small, dependency-free syntax highlighter. Not a full grammar — just
/// enough regex-based tokenizing per language to make the code editor,
/// diff viewer, and chat code blocks readable instead of flat monospace.
class SyntaxHighlighter {
  SyntaxHighlighter._();

  static const _javaKeywords =
      r'\b(class|public|private|protected|static|void|new|return|import|package|'
      r'final|if|else|for|while|extends|implements|interface|enum|throws|try|catch|'
      r'this|super|null|true|false|int|long|double|float|boolean|String|var)\b';

  static const _sqlKeywords =
      r'\b(SELECT|INSERT|INTO|VALUES|UPDATE|SET|WHERE|FROM|CREATE|TABLE|INDEX|ON|'
      r'DROP|ALTER|PRIMARY|KEY|FOREIGN|REFERENCES|NOT|NULL|DEFAULT|AND|OR|JOIN|'
      r'GROUP BY|ORDER BY|LIMIT)\b';

  /// Highlights a single line of [code] for [language], returning spans
  /// styled relative to [base].
  static List<InlineSpan> highlightLine(
      String code, String language, TextStyle base) {
    switch (language) {
      case 'properties':
        return _highlightProperties(code, base);
      case 'yaml':
        return _highlightYaml(code, base);
      case 'java':
      case 'dart':
        return _tokenize(code, base, [
          _Rule(RegExp('//.*'), AppTheme.codeComment),
          _Rule(RegExp(r'"(?:[^"\\]|\\.)*"'), AppTheme.codeValue),
          _Rule(RegExp(r'@\w+'), AppTheme.accentAmber),
          _Rule(RegExp(_javaKeywords), AppTheme.codeKeyword),
          _Rule(RegExp(r'\b[A-Z][A-Za-z0-9_]*\b'), AppTheme.codeType),
        ]);
      case 'sql':
        return _tokenize(code, base, [
          _Rule(RegExp(r'--.*'), AppTheme.codeComment),
          _Rule(RegExp(r"'(?:[^'\\]|\\.)*'"), AppTheme.codeValue),
          _Rule(
              RegExp(_sqlKeywords, caseSensitive: false), AppTheme.codeKeyword),
        ]);
      case 'xml':
        return _tokenize(code, base, [
          _Rule(RegExp(r'<!--.*?-->'), AppTheme.codeComment),
          _Rule(RegExp(r'"[^"]*"'), AppTheme.codeValue),
          _Rule(RegExp(r'</?[\w:.-]+'), AppTheme.codeKeyword),
        ]);
      case 'json':
        return _tokenize(code, base, [
          _Rule(RegExp(r'"[^"]*"\s*:'), AppTheme.codeKey),
          _Rule(RegExp(r'"[^"]*"'), AppTheme.codeValue),
          _Rule(RegExp(r'\b(true|false|null)\b'), AppTheme.codeKeyword),
        ]);
      default:
        return [TextSpan(text: code, style: base)];
    }
  }

  /// Highlights a multi-line block (chat fenced code blocks), joining
  /// per-line spans with explicit newlines.
  static List<InlineSpan> highlightBlock(
      String code, String language, TextStyle base) {
    final lines = code.split('\n');
    final spans = <InlineSpan>[];
    for (var i = 0; i < lines.length; i++) {
      spans.addAll(highlightLine(lines[i], language, base));
      if (i != lines.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    return spans;
  }

  static List<InlineSpan> _highlightProperties(String line, TextStyle base) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('#')) {
      return [
        TextSpan(text: line, style: base.copyWith(color: AppTheme.codeComment))
      ];
    }
    final eq = line.indexOf('=');
    if (eq == -1) return [TextSpan(text: line, style: base)];
    final key = line.substring(0, eq);
    final value = line.substring(eq + 1);
    return [
      TextSpan(text: key, style: base.copyWith(color: AppTheme.codeKey)),
      TextSpan(text: '=', style: base),
      ..._highlightInterpolation(value, base),
    ];
  }

  static List<InlineSpan> _highlightYaml(String line, TextStyle base) {
    final trimmed = line.trimLeft();
    final indent = line.substring(0, line.length - trimmed.length);
    if (trimmed.startsWith('#')) {
      return [
        TextSpan(text: line, style: base.copyWith(color: AppTheme.codeComment))
      ];
    }
    final colon = trimmed.indexOf(':');
    if (colon == -1) return [TextSpan(text: line, style: base)];
    final key = trimmed.substring(0, colon);
    final value = trimmed.substring(colon + 1);
    return [
      TextSpan(text: indent, style: base),
      TextSpan(text: key, style: base.copyWith(color: AppTheme.codeKey)),
      TextSpan(text: ':', style: base),
      TextSpan(text: value, style: base.copyWith(color: AppTheme.codeValue)),
    ];
  }

  /// Colors `${VAR:default}`-style interpolations inside a value string.
  static List<InlineSpan> _highlightInterpolation(String text, TextStyle base) {
    final pattern = RegExp(r'\$\{[^}]+\}');
    final spans = <InlineSpan>[];
    int last = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(
            text: text.substring(last, m.start),
            style: base.copyWith(color: AppTheme.codeValue)));
      }
      spans.add(TextSpan(
          text: m.group(0), style: base.copyWith(color: AppTheme.accentAmber)));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(
          text: text.substring(last),
          style: base.copyWith(color: AppTheme.codeValue)));
    }
    return spans;
  }

  /// Generic first-match-wins tokenizer: tries each rule at the current
  /// position's remaining text and takes whichever match starts earliest.
  static List<InlineSpan> _tokenize(
      String line, TextStyle base, List<_Rule> rules) {
    final spans = <InlineSpan>[];
    int pos = 0;
    while (pos < line.length) {
      _Rule? bestRule;
      Match? bestMatch;
      for (final rule in rules) {
        final m = rule.pattern.matchAsPrefix(line, pos) ??
            _firstMatchFrom(rule.pattern, line, pos);
        if (m != null && (bestMatch == null || m.start < bestMatch.start)) {
          bestMatch = m;
          bestRule = rule;
        }
      }
      if (bestMatch == null || bestRule == null) {
        spans.add(TextSpan(text: line.substring(pos), style: base));
        break;
      }
      if (bestMatch.start > pos) {
        spans.add(
            TextSpan(text: line.substring(pos, bestMatch.start), style: base));
      }
      spans.add(TextSpan(
          text: bestMatch.group(0),
          style: base.copyWith(color: bestRule.color)));
      pos = bestMatch.end;
    }
    return spans;
  }

  static Match? _firstMatchFrom(RegExp pattern, String line, int from) {
    final it = pattern.allMatches(line, from);
    return it.isEmpty ? null : it.first;
  }
}

class _Rule {
  final RegExp pattern;
  final Color color;
  const _Rule(this.pattern, this.color);
}
