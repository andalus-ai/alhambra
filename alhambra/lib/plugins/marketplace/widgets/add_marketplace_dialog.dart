import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AddMarketplaceDialog extends ConsumerStatefulWidget {
  const AddMarketplaceDialog({super.key});

  @override
  ConsumerState<AddMarketplaceDialog> createState() =>
      _AddMarketplaceDialogState();
}

class _AddMarketplaceDialogState extends ConsumerState<AddMarketplaceDialog> {
  final _formKey = GlobalKey<FormState>();
  String? selectedOption = 'browse';
  String? repositoryUrl;
  String? customName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? Colors.grey[850] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 450,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark),
              const SizedBox(height: 16),
              _buildOptionCard(
                isDark,
                'browse',
                Icons.storefront,
                'Browse Anthropic sources',
                'Curated marketplaces of plugins built by Anthropic',
              ),
              const SizedBox(height: 12),
              _buildOptionCard(
                isDark,
                'repository',
                Icons.code,
                'Add from a repository',
                'Sync a plugin marketplace from a GitHub repository or git URL',
              ),
              if (selectedOption == 'repository') ...[
                const SizedBox(height: 16),
                _buildRepositoryFields(),
              ],
              const SizedBox(height: 20),
              _buildActions(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Text(
          'Add Marketplace',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildOptionCard(
    bool isDark,
    String value,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final isSelected = selectedOption == value;

    return InkWell(
      onTap: () => setState(() => selectedOption = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.1)
              : isDark
                  ? Colors.grey[800]
                  : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[700]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue : Colors.grey[400],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildRepositoryFields() {
    return Column(
      children: [
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Repository URL',
            hintText: 'https://github.com/username/repo',
            prefixIcon: Icon(Icons.link),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a repository URL';
            }
            try {
              final uri = Uri.parse(value);
              if (!uri.isAbsolute) {
                return 'Please enter a valid URL';
              }
            } catch (e) {
              return 'Please enter a valid URL';
            }
            return null;
          },
          onChanged: (value) => repositoryUrl = value,
        ),
        const SizedBox(height: 12),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Marketplace Name (optional)',
            hintText: 'Custom name for this marketplace',
            prefixIcon: Icon(Icons.label),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
          onChanged: (value) => customName = value,
        ),
      ],
    );
  }

  Widget _buildActions(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style:
                TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _handleAddMarketplace,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: selectedOption == 'browse'
              ? const Text('Add Marketplace')
              : const Text('Sync Repository'),
        ),
      ],
    );
  }

  void _handleAddMarketplace() async {
    // Implementation...
  }
}
