import 'package:flutter/material.dart';

import 'plugin_filter_bar.dart';

class PluginSearchBar extends StatelessWidget {
  final String query;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  const PluginSearchBar({
    super.key,
    required this.query,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        onChanged: onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search plugins...',
          hintStyle: TextStyle(
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
          prefixIcon: Icon(
            Icons.search,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                  onPressed: onClearSearch,
                )
              : const PluginFilterButton(),
          filled: true,
          fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
      ),
    );
  }
}
