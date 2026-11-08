import 'package:flutter/material.dart';

class ViewErrorBoundary extends StatefulWidget {
  final String viewId;
  final String viewTitle;
  final Widget Function() builder;

  const ViewErrorBoundary({
    super.key,
    required this.viewId,
    required this.viewTitle,
    required this.builder,
  });

  @override
  State<ViewErrorBoundary> createState() => _ViewErrorBoundaryState();
}

class _ViewErrorBoundaryState extends State<ViewErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  void _resetError() {
    setState(() {
      _error = null;
      _stackTrace = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        color: const Color(0xFF1E1E1E),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 40, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                'View Error: ${widget.viewTitle}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                _error.toString(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF8B949E), fontFamily: 'monospace'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _resetError,
                icon: const Icon(Icons.refresh, size: 15),
                label: const Text('Reload View'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Builder(
      builder: (ctx) {
        try {
          return widget.builder();
        } catch (e, st) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _error = e;
                _stackTrace = st;
              });
            }
          });
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
      },
    );
  }
}
