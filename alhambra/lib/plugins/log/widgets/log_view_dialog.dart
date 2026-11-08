import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

class LogViewDialog extends StatefulWidget {
  const LogViewDialog({super.key});

  @override
  State<LogViewDialog> createState() => _LogViewDialogState();
}

class _LogViewDialogState extends State<LogViewDialog> {
  final ScrollController _scrollController = ScrollController();
  List<String> _logLines = [];
  Timer? _refreshTimer;
  File? _logFile;

  @override
  void initState() {
    super.initState();
    _initLogFile();
    _loadLogs();

    // Auto-refresh every 2 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _loadLogs();
    });
  }

  void _initLogFile() {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null) {
      _logFile = File('$home/.andalus/logs/alhambra.log');
    }
  }

  Future<void> _loadLogs() async {
    if (_logFile == null || !_logFile!.existsSync()) {
      setState(() {
        _logLines = ['Log file not found at ${_logFile?.path}'];
      });
      return;
    }

    try {
      final lines = await _logFile!.readAsLines();
      // Keep only the last 1000 lines to avoid UI lag
      final displayLines =
          lines.length > 1000 ? lines.sublist(lines.length - 1000) : lines;

      final bool wasAtBottom = _scrollController.hasClients &&
          _scrollController.offset >=
              _scrollController.position.maxScrollExtent - 50;

      setState(() {
        _logLines = displayLines;
      });

      if (wasAtBottom && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    } catch (e) {
      setState(() {
        _logLines = ['Failed to read logs: $e'];
      });
    }
  }

  Future<void> _clearLogs() async {
    if (_logFile != null && _logFile!.existsSync()) {
      await _logFile!.writeAsString('');
      _loadLogs();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Alhambra Application Logs',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _clearLogs,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Clear'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: SelectionArea(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _logLines.length,
                    itemBuilder: (context, index) {
                      final line = _logLines[index];
                      Color textColor =
                          Theme.of(context).textTheme.bodyMedium?.color ??
                              Colors.black;

                      if (line.contains('[ERROR]') ||
                          line.contains('[FATAL]')) {
                        textColor = Colors.red;
                      } else if (line.contains('[WARNING]')) {
                        textColor = Colors.orange;
                      } else if (line.contains('[DEBUG]')) {
                        textColor = Colors.grey;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Text(
                          line,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: textColor,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
