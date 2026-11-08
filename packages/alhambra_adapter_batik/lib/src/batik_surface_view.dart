import 'package:flutter/material.dart';
import 'package:batik/batik.dart' as batik;
import 'package:alhambra_ui/alhambra_ui.dart' as a2ui;

import 'alhambra_action_handler.dart';
import 'batik_to_a2ui_converter.dart';

/// A Flutter widget that:
/// 1. Accepts a [batik.AgentUIResponse] (produced by any Batik adapter)
/// 2. Converts it to an [a2ui.UiSurface] via [BatikToA2UiConverter]
/// 3. Renders it using Alhambra's [a2ui.UiSurfaceView] with the guard applied
///
/// This is the primary integration point for Alhambra apps using Batik
/// as the A2UI provider.
///
/// ```dart
/// BatikSurfaceView(
///   response: agentResponse,
///   guard: const a2ui.DefaultA2UiActionGuard(),
///   onAction: (action) => handleAction(action),
/// )
/// ```
class BatikSurfaceView extends StatelessWidget {
  final batik.AgentUIResponse response;
  final a2ui.A2UiActionGuard? guard;
  final void Function(a2ui.UiAction action)? onAction;
  final a2ui.UiNodeRenderer renderer;
  final String? surfaceTitle;

  const BatikSurfaceView({
    super.key,
    required this.response,
    this.guard,
    this.onAction,
    this.renderer = const a2ui.DefaultUiNodeRenderer(),
    this.surfaceTitle,
  });

  @override
  Widget build(BuildContext context) {
    final surface = BatikToA2UiConverter.convert(
      response,
      title: surfaceTitle,
    );

    return a2ui.UiSurfaceView(
      surface: surface,
      renderer: renderer,
      guard: guard,
      onAction: onAction,
    );
  }
}

/// A widget that drives a Batik agent interaction and renders the response
/// through Alhambra's surface view.
///
/// Manages the full lifecycle: idle → loading → rendered / error.
class BatikAgentSurfaceView extends StatefulWidget {
  final batik.AgentAdapter adapter;
  final String? initialPrompt;
  final a2ui.A2UiActionGuard guard;
  final void Function(a2ui.UiAction action)? onAction;

  const BatikAgentSurfaceView({
    super.key,
    required this.adapter,
    required this.guard,
    this.initialPrompt,
    this.onAction,
  });

  @override
  State<BatikAgentSurfaceView> createState() => _BatikAgentSurfaceViewState();
}

class _BatikAgentSurfaceViewState extends State<BatikAgentSurfaceView> {
  batik.AgentTurnOutput? _output;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt != null) {
      _sendTurn(widget.initialPrompt!);
    }
  }

  Future<void> _sendTurn(String message) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final out = await widget.adapter.sendTurn(
      batik.AgentTurnInput(userMessage: message),
    );
    if (mounted) {
      setState(() {
        _loading = false;
        _output = out;
        _error = out.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      final uiError = a2ui.UiError.unknown(detail: _error);
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(uiError.headline,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(uiError.guidance,
                style: Theme.of(context).textTheme.bodySmall),
            if (uiError.isRetryable)
              TextButton(
                onPressed: () =>
                    _sendTurn(widget.initialPrompt ?? 'retry'),
                child: const Text('Retry'),
              ),
          ],
        ),
      );
    }

    final response = _output?.uiResponse;
    if (response == null) {
      return const SizedBox.shrink();
    }

    return BatikSurfaceView(
      response: response,
      guard: widget.guard,
      onAction: widget.onAction,
    );
  }
}
