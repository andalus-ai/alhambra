import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alhambra_coding_core/alhambra_coding_core.dart';

import '../providers/terminal_provider.dart';

/// Real interactive terminal buffer that executes commands in the active project directory.
class TerminalPanel extends ConsumerStatefulWidget {
  const TerminalPanel({super.key});

  @override
  ConsumerState<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends ConsumerState<TerminalPanel> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<String> _history = [];
  int _historyIndex = -1;

  Process? _runningProcess;
  bool _isRunning = false;
  String? _customCwd;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _runningProcess?.kill();
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  String _resolveCwd() {
    if (_customCwd != null && Directory(_customCwd!).existsSync()) {
      return _customCwd!;
    }
    final project = ref.read(activeProjectProvider);
    if (project != null &&
        project.rootPath.isNotEmpty &&
        Directory(project.rootPath).existsSync()) {
      return project.rootPath;
    }
    return Directory.current.path;
  }

  Future<void> _executeCommand(String rawCommand) async {
    final command = rawCommand.trim();
    if (command.isEmpty) return;

    _history.add(command);
    _historyIndex = _history.length;
    _inputController.clear();

    final logNotifier = ref.read(terminalLogProvider.notifier);
    final cwd = _resolveCwd();
    final shortCwd = cwd.split(Platform.pathSeparator).last;

    logNotifier.append('➜ $shortCwd $command');
    _scrollToBottom();

    // Built-in commands
    if (command == 'clear') {
      logNotifier.clear();
      return;
    }

    if (command.startsWith('cd ') || command == 'cd') {
      final target = command.length > 3 ? command.substring(3).trim() : '';
      if (target.isEmpty || target == '~') {
        _customCwd = Platform.environment['HOME'] ?? Directory.current.path;
      } else {
        final newDir = Directory(
          target.startsWith('/') ? target : '$cwd/$target',
        );
        if (newDir.existsSync()) {
          _customCwd = newDir.absolute.path;
        } else {
          logNotifier.append('cd: no such file or directory: $target');
        }
      }
      _scrollToBottom();
      return;
    }

    // Run real shell process
    setState(() => _isRunning = true);

    try {
      final shell = Platform.isWindows
          ? 'cmd.exe'
          : (Platform.environment['SHELL'] ?? '/bin/zsh');
      final args = Platform.isWindows ? ['/c', command] : ['-c', command];

      final env = Map<String, String>.from(Platform.environment);
      env['PATH'] =
          env['PATH'] ??
          '/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin';

      final process = await Process.start(
        shell,
        args,
        workingDirectory: cwd,
        environment: env,
      );

      _runningProcess = process;

      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (mounted) {
              logNotifier.append(line);
              _scrollToBottom();
            }
          });

      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (mounted) {
              logNotifier.append('⚠ $line');
              _scrollToBottom();
            }
          });

      final exitCode = await process.exitCode;
      if (mounted && exitCode != 0) {
        logNotifier.append('Process exited with code $exitCode');
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        logNotifier.append('Error executing command: $e');
        _scrollToBottom();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
          _runningProcess = null;
        });
        _scrollToBottom();
        _focusNode.requestFocus();
      }
    }
  }

  void _killCurrentProcess() {
    _runningProcess?.kill(ProcessSignal.sigint);
    ref.read(terminalLogProvider.notifier).append('^C');
    setState(() {
      _isRunning = false;
      _runningProcess = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final log = ref.watch(terminalLogProvider);
    final cwd = _resolveCwd();

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Container(
      color: const Color(0xFF0F0F0F),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Terminal top header bar
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              color: AppTheme.panelAlt,
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.terminal_rounded,
                  size: 15,
                  color: AppTheme.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cwd,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                if (_isRunning)
                  InkWell(
                    onTap: _killCurrentProcess,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.stop_circle_outlined,
                            size: 12,
                            color: Colors.red,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Stop (^C)',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Clear Terminal',
                  icon: const Icon(
                    Icons.cleaning_services_outlined,
                    size: 15,
                    color: AppTheme.textMuted,
                  ),
                  onPressed: () =>
                      ref.read(terminalLogProvider.notifier).clear(),
                ),
              ],
            ),
          ),

          // Output buffer
          Expanded(
            child: SelectionArea(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: log.length,
                itemBuilder: (context, i) {
                  final line = log[i];
                  final isPrompt = line.startsWith('➜');
                  final isError =
                      line.startsWith('⚠') ||
                      line.contains('Error') ||
                      line.contains('FAILED');

                  Color textColor = AppTheme.textSecondary;
                  if (isPrompt) {
                    textColor = const Color(0xFF7EE787);
                  } else if (isError) {
                    textColor = const Color(0xFFFFA198);
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1.5),
                    child: Text(
                      line,
                      style: TextStyle(
                        color: textColor,
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Command input line
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF0D1117),
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Text(
                  '➜ ',
                  style: TextStyle(
                    color: _isRunning ? Colors.amber : const Color(0xFF7EE787),
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
                Expanded(
                  child: KeyboardListener(
                    focusNode: FocusNode(),
                    onKeyEvent: (event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
                            _history.isNotEmpty) {
                          if (_historyIndex > 0) {
                            _historyIndex--;
                            _inputController.text = _history[_historyIndex];
                            _inputController.selection =
                                TextSelection.collapsed(
                                  offset: _inputController.text.length,
                                );
                          }
                        } else if (event.logicalKey ==
                                LogicalKeyboardKey.arrowDown &&
                            _history.isNotEmpty) {
                          if (_historyIndex < _history.length - 1) {
                            _historyIndex++;
                            _inputController.text = _history[_historyIndex];
                            _inputController.selection =
                                TextSelection.collapsed(
                                  offset: _inputController.text.length,
                                );
                          } else {
                            _historyIndex = _history.length;
                            _inputController.clear();
                          }
                        }
                      }
                    },
                    child: TextField(
                      controller: _inputController,
                      focusNode: _focusNode,
                      enabled: !_isRunning,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                        color: Color(0xFFE6EDF3),
                      ),
                      decoration: InputDecoration(
                        hintText: _isRunning ? 'Command running...' : 'Type a shell command (e.g. ls, git status, mvn clean)...',
                        hintStyle: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textMuted.withValues(alpha: 0.6),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: _executeCommand,
                    ),
                  ),
                ),
                if (_isRunning)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accent,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
