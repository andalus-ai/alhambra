import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../theme/app_colors.dart';
import '../models/skill_entity.dart';
import '../providers/skills_provider.dart';
import 'skill_editor_dialog.dart';

class SkillsSettingsView extends ConsumerStatefulWidget {
  const SkillsSettingsView({super.key});

  @override
  ConsumerState<SkillsSettingsView> createState() => _SkillsSettingsViewState();
}

class _SkillsSettingsViewState extends ConsumerState<SkillsSettingsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const Color _errorColor = Color(0xFFE06C75);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md', 'markdown', 'txt'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();

        // Infer slug from file name
        final fileName = result.files.single.name
            .replaceAll(RegExp(r'\.(md|markdown|txt)$'), '');
        final defaultId =
            fileName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '-');

        // Parse frontmatter
        final frontmatterRegex =
            RegExp(r'^---\s*\n(.*?)\n---\s*\n(.*)$', dotAll: true);
        final match = frontmatterRegex.firstMatch(content);

        String name = fileName;
        String desc = '';
        String category = 'coding';
        String reasoning = 'standard';
        bool mutates = false;
        List<String> tools = [];
        String instructions = content;

        if (match != null) {
          final frontmatter = match.group(1) ?? '';
          instructions = (match.group(2) ?? '').trim();

          for (final line in frontmatter.split('\n')) {
            final parts = line.split(':');
            if (parts.length >= 2) {
              final key = parts[0].trim();
              final val = parts.sublist(1).join(':').trim();
              if (key == 'name') name = val;
              if (key == 'description') desc = val;
              if (key == 'category') category = val;
              if (key == 'reasoningMode') reasoning = val;
              if (key == 'mutatesWorkspace')
                mutates = val.toLowerCase() == 'true';
            }
          }
        }

        final importedSkill = SkillEntity(
          id: defaultId,
          name: name,
          description: desc,
          category: category,
          reasoningMode: reasoning,
          mutatesWorkspace: mutates,
          allowedTools: tools,
          instructions: instructions,
          rawMarkdown: content,
        );

        if (mounted) {
          SkillEditorDialog.show(context, skill: importedSkill);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import file: $e')),
        );
      }
    }
  }

  Future<void> _handleExport(SkillEntity skill) async {
    try {
      final detail = await ref.read(skillDetailProvider(skill.id).future);
      final content =
          detail.rawMarkdown != null && detail.rawMarkdown!.isNotEmpty
              ? detail.rawMarkdown!
              : _generateMarkdownForSkill(detail);

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export ${skill.id}',
        fileName: '${skill.id}.md',
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
        await Clipboard.setData(ClipboardData(text: content));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copied SKILL.md to clipboard!')),
          );
        }
      }
    } catch (_) {
      // Fallback: Copy ID / Description
      await Clipboard.setData(
          ClipboardData(text: '# ${skill.name}\n${skill.description}'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied to clipboard!')),
        );
      }
    }
  }

  String _generateMarkdownForSkill(SkillEntity skill) {
    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('name: ${skill.name}');
    buffer.writeln('description: ${skill.description}');
    if (skill.category != null) buffer.writeln('category: ${skill.category}');
    if (skill.reasoningMode != null)
      buffer.writeln('reasoningMode: ${skill.reasoningMode}');
    buffer.writeln('mutatesWorkspace: ${skill.mutatesWorkspace}');
    if (skill.allowedTools.isNotEmpty) {
      buffer.writeln('allowedTools:');
      for (final t in skill.allowedTools) {
        buffer.writeln('  - $t');
      }
    }
    buffer.writeln('---');
    buffer.writeln();
    buffer.write(skill.instructions ?? '');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and action toolbar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Skills Management',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Runtime modification, internal editing, soft-delete & hot reload.',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.file_upload_outlined, size: 16),
                  label: const Text('Import'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.border),
                  ),
                  onPressed: _handleImport,
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Skill'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentBlue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => SkillEditorDialog.show(context),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh,
                      size: 20, color: AppTheme.textSecondary),
                  tooltip: 'Hot Reload Skills',
                  onPressed: () => ref
                      .read(skillsControllerProvider.notifier)
                      .reloadSkills(),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Search & Filter Bar
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.trim().toLowerCase()),
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search,
                        size: 18, color: AppTheme.textSecondary),
                    hintText:
                        'Search skills by name, description, or capability...',
                    hintStyle: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: AppTheme.panel,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Tab selection
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.accentBlue,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.accentBlue,
          tabs: const [
            Tab(text: 'Active Skills'),
            Tab(text: 'Trash (Soft Deleted)'),
          ],
        ),

        const SizedBox(height: 12),

        // Tab Content
        SizedBox(
          height: 380,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildActiveSkills(context, ref),
              _buildTrashedSkills(context, ref),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveSkills(BuildContext context, WidgetRef ref) {
    final asyncSkills = ref.watch(skillsListProvider);
    return asyncSkills.when(
      data: (allSkills) {
        final skills = _searchQuery.isEmpty
            ? allSkills
            : allSkills.where((s) {
                return s.name.toLowerCase().contains(_searchQuery) ||
                    s.id.toLowerCase().contains(_searchQuery) ||
                    s.description.toLowerCase().contains(_searchQuery) ||
                    (s.category != null &&
                        s.category!.toLowerCase().contains(_searchQuery));
              }).toList();

        if (skills.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.psychology_outlined,
                    size: 44, color: AppTheme.textMuted),
                const SizedBox(height: 12),
                Text(
                  _searchQuery.isEmpty
                      ? 'No active skills found.'
                      : 'No skills matching "$_searchQuery"',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Create New Skill'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentBlue,
                      foregroundColor: Colors.white),
                  onPressed: () => SkillEditorDialog.show(context),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          itemCount: skills.length,
          separatorBuilder: (_, __) =>
              const Divider(color: AppTheme.border, height: 1),
          itemBuilder: (context, index) {
            final skill = skills[index];
            return Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                onTap: () => SkillEditorDialog.show(context, skill: skill),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.panel,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Icon(Icons.psychology,
                      color: AppTheme.accentBlue, size: 20),
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        skill.name,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (skill.category != null &&
                        skill.category!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.chip,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          skill.category!,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  skill.description.isNotEmpty ? skill.description : skill.id,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download_outlined,
                          color: AppTheme.textSecondary, size: 18),
                      tooltip: 'Export SKILL.md',
                      onPressed: () => _handleExport(skill),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: AppTheme.accentBlue, size: 18),
                      tooltip: 'Edit Skill',
                      onPressed: () =>
                          SkillEditorDialog.show(context, skill: skill),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: _errorColor, size: 18),
                      tooltip: 'Move to Trash',
                      onPressed: () {
                        ref
                            .read(skillsControllerProvider.notifier)
                            .softDeleteSkill(skill.id);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 40, color: _errorColor),
            const SizedBox(height: 12),
            Text('Failed to load skills: $e',
                style: const TextStyle(color: _errorColor)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.invalidate(skillsListProvider),
              child: const Text('Retry'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTrashedSkills(BuildContext context, WidgetRef ref) {
    final asyncTrash = ref.watch(trashedSkillsProvider);
    return asyncTrash.when(
      data: (skills) {
        if (skills.isEmpty) {
          return const Center(
            child: Text('Trash is empty.',
                style: TextStyle(color: AppTheme.textSecondary)),
          );
        }
        return ListView.separated(
          itemCount: skills.length,
          separatorBuilder: (_, __) =>
              const Divider(color: AppTheme.border, height: 1),
          itemBuilder: (context, index) {
            final skill = skills[index];
            return Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                title: Text(skill.name,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500)),
                subtitle: Text(skill.description,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.restore,
                          color: AppTheme.accentBlue, size: 18),
                      tooltip: 'Restore Skill',
                      onPressed: () {
                        ref
                            .read(skillsControllerProvider.notifier)
                            .restoreSkill(skill.id);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_forever,
                          color: _errorColor, size: 18),
                      tooltip: 'Delete Permanently',
                      onPressed: () {
                        ref
                            .read(skillsControllerProvider.notifier)
                            .hardDeleteSkill(skill.id);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text('Error: $e', style: const TextStyle(color: _errorColor))),
    );
  }
}
