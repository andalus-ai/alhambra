import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../theme/app_colors.dart';
import '../models/skill_entity.dart';
import '../providers/skills_provider.dart';

class SkillEditorDialog extends ConsumerStatefulWidget {
  final SkillEntity? skill; // null if creating new

  const SkillEditorDialog({super.key, this.skill});

  static Future<void> show(BuildContext context, {SkillEntity? skill}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => SkillEditorDialog(skill: skill),
    );
  }

  @override
  ConsumerState<SkillEditorDialog> createState() => _SkillEditorDialogState();
}

class _SkillEditorDialogState extends ConsumerState<SkillEditorDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _idController;
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _instructionsController;
  late TextEditingController _allowedToolsController;
  late TextEditingController _rawMarkdownController;

  String _category = 'coding';
  String _reasoningMode = 'standard';
  bool _mutatesWorkspace = false;
  bool _isLoading = false;

  final List<String> _categories = [
    'coding',
    'architecture',
    'debugging',
    'review',
    'workflow',
    'tools',
    'documentation',
    'security',
    'general',
  ];

  final List<String> _reasoningModes = [
    'standard',
    'react',
    'plan_and_solve',
    'reflection',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final s = widget.skill;

    _idController = TextEditingController(text: s?.id ?? '');
    _nameController = TextEditingController(text: s?.name ?? '');
    _descriptionController = TextEditingController(text: s?.description ?? '');
    _instructionsController =
        TextEditingController(text: s?.instructions ?? '');
    _allowedToolsController =
        TextEditingController(text: s?.allowedTools.join(', ') ?? '');
    _category = s?.category ?? 'coding';
    _reasoningMode = s?.reasoningMode ?? 'standard';
    _mutatesWorkspace = s?.mutatesWorkspace ?? false;

    _rawMarkdownController =
        TextEditingController(text: _generateRawMarkdown());

    // If editing existing, fetch complete detail if instructions are empty
    if (widget.skill != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchDetails());
    }

    _tabController.addListener(() {
      if (_tabController.index == 1) {
        // Switching to Raw Markdown tab
        _rawMarkdownController.text = _generateRawMarkdown();
      }
    });
  }

  Future<void> _fetchDetails() async {
    if (widget.skill == null) return;
    try {
      final detail =
          await ref.read(skillDetailProvider(widget.skill!.id).future);
      if (mounted) {
        setState(() {
          _instructionsController.text = detail.instructions ?? '';
          _rawMarkdownController.text =
              detail.rawMarkdown ?? _generateRawMarkdown();
          if (detail.category != null && detail.category!.isNotEmpty) {
            _category = detail.category!;
          }
          if (detail.reasoningMode != null &&
              detail.reasoningMode!.isNotEmpty) {
            _reasoningMode = detail.reasoningMode!;
          }
          _mutatesWorkspace = detail.mutatesWorkspace;
          _allowedToolsController.text = detail.allowedTools.join(', ');
        });
      }
    } catch (_) {}
  }

  String _generateRawMarkdown() {
    final toolsList = _allowedToolsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('name: ${_nameController.text.trim()}');
    buffer.writeln('description: ${_descriptionController.text.trim()}');
    buffer.writeln('category: $_category');
    buffer.writeln('reasoningMode: $_reasoningMode');
    buffer.writeln('mutatesWorkspace: $_mutatesWorkspace');
    if (toolsList.isNotEmpty) {
      buffer.writeln('allowedTools:');
      for (final t in toolsList) {
        buffer.writeln('  - $t');
      }
    }
    buffer.writeln('---');
    buffer.writeln();
    buffer.write(_instructionsController.text);
    return buffer.toString();
  }

  void _parseRawMarkdown(String raw) {
    final frontmatterRegex =
        RegExp(r'^---\s*\n(.*?)\n---\s*\n(.*)$', dotAll: true);
    final match = frontmatterRegex.firstMatch(raw);
    if (match != null) {
      final frontmatter = match.group(1) ?? '';
      final body = match.group(2) ?? '';
      _instructionsController.text = body.trim();

      for (final line in frontmatter.split('\n')) {
        final parts = line.split(':');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final val = parts.sublist(1).join(':').trim();
          if (key == 'name') _nameController.text = val;
          if (key == 'description') _descriptionController.text = val;
          if (key == 'category' && _categories.contains(val)) _category = val;
          if (key == 'reasoningMode' && _reasoningModes.contains(val))
            _reasoningMode = val;
          if (key == 'mutatesWorkspace')
            _mutatesWorkspace = val.toLowerCase() == 'true';
        }
      }
    } else {
      _instructionsController.text = raw.trim();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _idController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _allowedToolsController.dispose();
    _rawMarkdownController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_tabController.index == 1) {
      _parseRawMarkdown(_rawMarkdownController.text);
    }

    if (!_formKey.currentState!.validate()) {
      _tabController.animateTo(0);
      return;
    }

    setState(() => _isLoading = true);

    final tools = _allowedToolsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final skill = SkillEntity(
      id: _idController.text.trim(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _category,
      reasoningMode: _reasoningMode,
      mutatesWorkspace: _mutatesWorkspace,
      allowedTools: tools,
      instructions: _instructionsController.text,
    );

    final success = await ref.read(skillsControllerProvider.notifier).saveSkill(
          skill,
          isNew: widget.skill == null,
        );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Skill "${skill.name}" saved successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to save skill. Check backend logs.')),
        );
      }
    }
  }

  Future<void> _handleExport() async {
    final content = _generateRawMarkdown();
    final fileName =
        '${_idController.text.trim().isNotEmpty ? _idController.text.trim() : "skill"}.md';

    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Skill Markdown',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['md', 'markdown'],
      );

      if (savePath != null) {
        final file = File(savePath);
        await file.writeAsString(content);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported to $savePath')),
          );
        }
      } else {
        // Fallback: Copy to clipboard
        await Clipboard.setData(ClipboardData(text: content));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copied SKILL.md to clipboard!')),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: content));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied SKILL.md to clipboard!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.skill == null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 840,
        height: 700,
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top header bar
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology,
                          color: AppTheme.accentBlue, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        isNew
                            ? 'Create New Skill'
                            : 'Edit Skill: ${widget.skill!.name}',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Export SKILL.md'),
                        style: TextButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary),
                        onPressed: _handleExport,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: AppTheme.textSecondary, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab bar
            Container(
              color: AppTheme.panel,
              child: TabBar(
                controller: _tabController,
                labelColor: AppTheme.accentBlue,
                unselectedLabelColor: AppTheme.textSecondary,
                indicatorColor: AppTheme.accentBlue,
                tabs: const [
                  Tab(icon: Icon(Icons.tune, size: 16), text: 'Visual Editor'),
                  Tab(icon: Icon(Icons.code, size: 16), text: 'Raw SKILL.md'),
                ],
              ),
            ),

            // Editor Content
            Expanded(
              child: Form(
                key: _formKey,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildVisualEditor(),
                    _buildRawEditor(),
                  ],
                ),
              ),
            ),

            // Bottom action bar
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.skill?.sourcePath != null &&
                              widget.skill!.sourcePath!.isNotEmpty
                          ? 'Path: ${widget.skill!.sourcePath}'
                          : 'Saved in ~/.andalus/skills/',
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(isNew ? 'Create Skill' : 'Save Changes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualEditor() {
    final isNew = widget.skill == null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _idController,
                  enabled: isNew,
                  decoration: const InputDecoration(
                    labelText: 'Skill ID * (unique slug)',
                    hintText: 'e.g. git-commit-assistant',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: AppTheme.panel,
                  ),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Skill ID is required';
                    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(v.trim())) {
                      return 'Only letters, numbers, hyphens and underscores allowed';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Skill Name *',
                    hintText: 'e.g. Git Commit Assistant',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: AppTheme.panel,
                  ),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Name is required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description *',
              hintText:
                  'Brief summary of what this skill does and when the agent should trigger it',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: AppTheme.panel,
            ),
            style: const TextStyle(color: AppTheme.textPrimary),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Description is required'
                : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue:
                      _categories.contains(_category) ? _category : 'general',
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: AppTheme.panel,
                  ),
                  dropdownColor: AppTheme.panelAlt,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  items: _categories
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.toUpperCase(),
                              style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v ?? 'coding'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _reasoningModes.contains(_reasoningMode)
                      ? _reasoningMode
                      : 'standard',
                  decoration: const InputDecoration(
                    labelText: 'Reasoning Mode',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: AppTheme.panel,
                  ),
                  dropdownColor: AppTheme.panelAlt,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  items: _reasoningModes
                      .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m.toUpperCase(),
                              style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _reasoningMode = v ?? 'standard'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _allowedToolsController,
                  decoration: const InputDecoration(
                    labelText: 'Allowed Capabilities / Tools',
                    hintText: 'Comma separated: fs, git, patch, index',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: AppTheme.panel,
                  ),
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  Switch(
                    value: _mutatesWorkspace,
                    activeThumbColor: AppTheme.accentBlue,
                    onChanged: (v) => setState(() => _mutatesWorkspace = v),
                  ),
                  const Text('Mutates Workspace',
                      style:
                          TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Instructions (Markdown body)',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _instructionsController,
            maxLines: 12,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontFamily: 'monospace',
                fontSize: 13),
            decoration: const InputDecoration(
              hintText:
                  '# Instructions\n\nDetailed guidance and step-by-step actions for the agent...',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: AppTheme.panel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRawEditor() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.panelAlt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Direct SKILL.md Editor (YAML frontmatter + Markdown body)',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextFormField(
              controller: _rawMarkdownController,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontFamily: 'monospace',
                  fontSize: 13),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
                fillColor: AppTheme.panel,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
