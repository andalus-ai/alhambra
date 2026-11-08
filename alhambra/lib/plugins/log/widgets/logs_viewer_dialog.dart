import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/log_file_service.dart';

class LogsViewerDialog extends StatefulWidget {
  const LogsViewerDialog({super.key});

  @override
  State<LogsViewerDialog> createState() => _LogsViewerDialogState();
}

enum _LogViewMode { raw, pretty, structured }

class _LogsViewerDialogState extends State<LogsViewerDialog> {
  LogScope _scope = LogScope.designer;
  _LogViewMode _viewMode = _LogViewMode.raw;
  List<File> _files = const [];
  String? _selectedPath;
  String _content = '';
  Object? _parsedJson;
  bool _isJson = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _rawScrollController = ScrollController();
  String _searchQuery = '';
  List<int> _matchOffsets = const [];
  int _activeMatchIndex = -1;
  bool _loadingFiles = true;
  bool _loadingContent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshFiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _rawScrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshFiles() async {
    setState(() {
      _loadingFiles = true;
      _error = null;
    });
    try {
      final files = await LogFileService.listLogFiles(scope: _scope);
      String? selectedPath = _selectedPath;
      if (files.isEmpty) {
        selectedPath = null;
      } else if (selectedPath == null ||
          !files.any((f) => f.path == selectedPath)) {
        selectedPath = files.first.path;
      }
      setState(() {
        _files = files;
        _selectedPath = selectedPath;
      });
      if (selectedPath != null) {
        await _loadContent(selectedPath);
      } else {
        setState(() => _content = '');
      }
    } catch (e) {
      setState(() {
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingFiles = false);
      }
    }
  }

  Future<void> _loadContent(String path) async {
    setState(() => _loadingContent = true);
    try {
      final text = await LogFileService.readLogFile(path);
      final parsed = _tryParseJson(text);
      if (!mounted) return;
      setState(() {
        _selectedPath = path;
        _content = text;
        _parsedJson = parsed;
        _isJson = parsed != null;
        _searchController.clear();
        _searchQuery = '';
        _matchOffsets = const [];
        _activeMatchIndex = -1;
        if (!_isJson && _viewMode != _LogViewMode.raw) {
          _viewMode = _LogViewMode.raw;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _loadingContent = false);
      }
    }
  }

  Future<void> _clearLogs() async {
    await LogFileService.clearLogFiles(scope: _scope);
    await _refreshFiles();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 1000,
        height: 650,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Row(
                children: [
                  SizedBox(width: 320, child: _buildFileList()),
                  const VerticalDivider(width: 1),
                  Expanded(child: _buildContentViewer()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Logs Viewer',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<LogScope>(
                segments: const [
                  ButtonSegment<LogScope>(
                    value: LogScope.designer,
                    label: Text('Designer'),
                    icon: Icon(Icons.design_services),
                  ),
                  ButtonSegment<LogScope>(
                    value: LogScope.server,
                    label: Text('Server'),
                    icon: Icon(Icons.dns),
                  ),
                ],
                selected: {_scope},
                onSelectionChanged: (selected) {
                  setState(() {
                    _scope = selected.first;
                  });
                  _refreshFiles();
                },
              ),
              TextButton.icon(
                onPressed: _refreshFiles,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              TextButton.icon(
                onPressed: _files.isEmpty ? null : _clearLogs,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear'),
              ),
              TextButton.icon(
                onPressed:
                    _selectedPath == null ? null : _copyCurrentLogContent,
                icon: const Icon(Icons.copy_all),
                label: const Text('Copy Content'),
              ),
              if (_selectedPath != null)
                SegmentedButton<_LogViewMode>(
                  segments: [
                    const ButtonSegment<_LogViewMode>(
                      value: _LogViewMode.raw,
                      label: Text('Raw'),
                      icon: Icon(Icons.text_snippet, size: 16),
                    ),
                    ButtonSegment<_LogViewMode>(
                      value: _LogViewMode.pretty,
                      label: const Text('Pretty'),
                      icon: const Icon(Icons.data_object, size: 16),
                      enabled: _isJson,
                    ),
                    ButtonSegment<_LogViewMode>(
                      value: _LogViewMode.structured,
                      label: const Text('Structured'),
                      icon: const Icon(Icons.view_list, size: 16),
                      enabled: _isJson,
                    ),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (selected) {
                    setState(() {
                      _viewMode = selected.first;
                      _recomputeSearchMatches(resetActiveIndex: true);
                    });
                    _scrollToActiveMatch();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    if (_loadingFiles) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Failed to load logs:\n$_error',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_files.isEmpty) {
      return const Center(child: Text('No log files'));
    }

    return ListView.separated(
      itemCount: _files.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final file = _files[index];
        final name = file.path.split(Platform.pathSeparator).last;
        final selected = _selectedPath == file.path;
        return ListTile(
          dense: true,
          selected: selected,
          leading: const Icon(Icons.description_outlined, size: 18),
          title: Text(name, overflow: TextOverflow.ellipsis),
          onTap: () => _loadContent(file.path),
        );
      },
    );
  }

  Widget _buildContentViewer() {
    if (_loadingContent) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_selectedPath == null) {
      return const Center(child: Text('Select a log file'));
    }
    final text = _viewMode == _LogViewMode.pretty && _isJson
        ? const JsonEncoder.withIndent('  ').convert(_parsedJson)
        : (_content.isEmpty ? '(Empty file)' : _content);
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: _viewMode == _LogViewMode.structured && _isJson
              ? _buildStructuredJsonViewer(_parsedJson)
              : _buildRawTextViewer(text),
        ),
      ],
    );
  }

  Widget _buildRawTextViewer(String text) {
    final activeOffset =
        _activeMatchIndex >= 0 && _activeMatchIndex < _matchOffsets.length
            ? _matchOffsets[_activeMatchIndex]
            : null;
    return Container(
      padding: const EdgeInsets.all(12),
      alignment: Alignment.topLeft,
      child: SelectionArea(
        child: SingleChildScrollView(
          controller: _rawScrollController,
          child: SelectableText.rich(
            _highlightOccurrences(
              text,
              _searchQuery,
              activeOffset: activeOffset,
              baseStyle: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStructuredJsonViewer(Object? value) {
    if (value is List) {
      final filteredItems = value.asMap().entries.where((entry) {
        return _matchesQuery(entry.value);
      }).toList();
      if (filteredItems.isEmpty) {
        return const Center(child: Text('[]'));
      }
      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: filteredItems.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final entry = filteredItems[index];
          final item = entry.value;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${entry.key}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _buildStructuredValue(item),
                ],
              ),
            ),
          );
        },
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: _buildStructuredValue(value),
    );
  }

  Widget _buildStructuredValue(Object? value) {
    if (value is Map) {
      final entries = value.entries.where((entry) {
        return _matchesQuery(entry.key.toString()) ||
            _matchesQuery(entry.value);
      }).toList();
      if (entries.isEmpty) {
        return const Text('{}');
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 180,
                  child: SelectableText.rich(
                    _highlightOccurrences(
                      entry.key.toString(),
                      _searchQuery,
                      baseStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _buildStructuredLeaf(entry.value)),
              ],
            ),
          );
        }).toList(),
      );
    }
    return _buildStructuredLeaf(value);
  }

  Widget _buildStructuredLeaf(Object? value) {
    if (value is Map || value is List) {
      final pretty = const JsonEncoder.withIndent('  ').convert(value);
      return SelectionArea(
        child: SelectableText.rich(
          _highlightOccurrences(
            pretty,
            _searchQuery,
            baseStyle: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      );
    }
    return SelectionArea(
      child: SelectableText.rich(
        _highlightOccurrences(value?.toString() ?? 'null', _searchQuery),
      ),
    );
  }

  Widget _buildSearchBar() {
    final matches = _matchOffsets.length;
    final active = matches == 0 ? 0 : _activeMatchIndex + 1;
    final canNavigate = matches > 0 && _isRawTextView;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            if (HardwareKeyboard.instance.isShiftPressed) {
              _goToPreviousMatch();
            } else {
              _goToNextMatch();
            }
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            if (_searchQuery.isNotEmpty) {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _recomputeSearchMatches(resetActiveIndex: true);
              });
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          focusNode: _searchFocusNode,
          controller: _searchController,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search logs',
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _recomputeSearchMatches(resetActiveIndex: true);
                      });
                    },
                    icon: const Icon(Icons.close, size: 18),
                  ),
            helperText: _searchQuery.isEmpty
                ? 'Type to search in current log view'
                : canNavigate
                    ? '$active/$matches match${matches == 1 ? '' : 'es'}'
                    : '$matches match${matches == 1 ? '' : 'es'}',
            suffix: canNavigate
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Previous match (Shift+Enter)',
                        onPressed: _goToPreviousMatch,
                        icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                      ),
                      IconButton(
                        tooltip: 'Next match (Enter)',
                        onPressed: _goToNextMatch,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                      ),
                    ],
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.trim();
              _recomputeSearchMatches(resetActiveIndex: true);
            });
            _scrollToActiveMatch();
          },
        ),
      ),
    );
  }

  bool _matchesQuery(Object? value) {
    if (_searchQuery.isEmpty) return true;
    return (value?.toString() ?? 'null').toLowerCase().contains(
          _searchQuery.toLowerCase(),
        );
  }

  TextSpan _highlightOccurrences(
    String source,
    String query, {
    int? activeOffset,
    TextStyle? baseStyle,
  }) {
    final style = baseStyle ?? const TextStyle();
    if (query.isEmpty || source.isEmpty) {
      return TextSpan(text: source, style: style);
    }

    final lowerSource = source.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    var cursor = 0;

    while (true) {
      final index = lowerSource.indexOf(lowerQuery, cursor);
      if (index < 0) {
        spans.add(TextSpan(text: source.substring(cursor), style: style));
        break;
      }
      if (index > cursor) {
        spans
            .add(TextSpan(text: source.substring(cursor, index), style: style));
      }
      spans.add(
        TextSpan(
          text: source.substring(index, index + query.length),
          style: style.copyWith(
            backgroundColor: (activeOffset != null && index == activeOffset)
                ? Colors.orange.withValues(alpha: 0.55)
                : Colors.yellow.withValues(alpha: 0.45),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      cursor = index + query.length;
    }
    return TextSpan(children: spans, style: style);
  }

  Object? _tryParseJson(String text) {
    if (text.trim().isEmpty) return null;
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }

  Future<void> _copyCurrentLogContent() async {
    if (_selectedPath == null) return;
    final contentToCopy = _content.isEmpty ? '(Empty file)' : _content;
    await Clipboard.setData(ClipboardData(text: contentToCopy));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Log content copied to clipboard')),
    );
  }

  bool get _isRawTextView =>
      _viewMode == _LogViewMode.raw ||
      (_viewMode == _LogViewMode.pretty && _isJson);

  String _currentSearchableText() {
    if (_viewMode == _LogViewMode.structured && _isJson) {
      return const JsonEncoder.withIndent('  ').convert(_parsedJson);
    }
    if (_viewMode == _LogViewMode.pretty && _isJson) {
      return const JsonEncoder.withIndent('  ').convert(_parsedJson);
    }
    return _content.isEmpty ? '(Empty file)' : _content;
  }

  List<int> _findMatchOffsets(String source, String query) {
    if (query.isEmpty || source.isEmpty) return const [];
    final lowerSource = source.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final offsets = <int>[];
    var start = 0;
    while (true) {
      final index = lowerSource.indexOf(lowerQuery, start);
      if (index < 0) break;
      offsets.add(index);
      start = index + lowerQuery.length;
    }
    return offsets;
  }

  void _recomputeSearchMatches({required bool resetActiveIndex}) {
    final searchable = _currentSearchableText();
    _matchOffsets = _findMatchOffsets(searchable, _searchQuery);
    if (_matchOffsets.isEmpty) {
      _activeMatchIndex = -1;
      return;
    }
    if (resetActiveIndex) {
      _activeMatchIndex = 0;
      return;
    }
    if (_activeMatchIndex < 0 || _activeMatchIndex >= _matchOffsets.length) {
      _activeMatchIndex = 0;
    }
  }

  void _goToNextMatch() {
    if (_matchOffsets.isEmpty || !_isRawTextView) return;
    setState(() {
      _activeMatchIndex = (_activeMatchIndex + 1) % _matchOffsets.length;
    });
    _scrollToActiveMatch();
  }

  void _goToPreviousMatch() {
    if (_matchOffsets.isEmpty || !_isRawTextView) return;
    setState(() {
      _activeMatchIndex = _activeMatchIndex <= 0
          ? _matchOffsets.length - 1
          : _activeMatchIndex - 1;
    });
    _scrollToActiveMatch();
  }

  void _scrollToActiveMatch() {
    if (!_isRawTextView || _matchOffsets.isEmpty || _activeMatchIndex < 0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_rawScrollController.hasClients) return;
      final text = _currentSearchableText();
      final matchOffset = _matchOffsets[_activeMatchIndex];
      final lineNumber = '\n'.allMatches(text.substring(0, matchOffset)).length;
      const lineHeight = 16.0;
      final targetOffset = lineNumber * lineHeight;
      final maxScroll = _rawScrollController.position.maxScrollExtent;
      _rawScrollController.animateTo(
        targetOffset.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }
}
