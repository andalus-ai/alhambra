import 'reactive_context_contracts.dart';

/// Core context keys.
abstract final class CoreContextKeys {
  /// The ID of the workspace.
  static const workspaceId = ContextKey<String>('alhambra.workspace.id');

  /// The name of the workspace.
  static const workspaceName = ContextKey<String>('alhambra.workspace.name');

  /// The ID of the active view.
  static const activeViewId = ContextKey<String>(
    'alhambra.workbench.activeViewId',
  );

  /// The path of the active file.
  static const activeFilePath = ContextKey<String>(
    'alhambra.editor.activeFilePath',
  );

  /// The path of the file.
  static const filePath = ContextKey<String>('alhambra.file.path');

  /// The language of the editor.
  static const editorLanguage = ContextKey<String>('alhambra.editor.language');

  /// The language of the file.
  static const language = ContextKey<String>('alhambra.file.language');

  /// The text selected in the editor.
  static const selectionText = ContextKey<String>(
    'alhambra.editor.selectionText',
  );

  /// Whether there is text selected in the editor.
  static const hasSelection = ContextKey<bool>('alhambra.editor.hasSelection');

  /// Whether the chat is general.
  static const isGeneralChat = ContextKey<bool>('alhambra.chat.isGeneral');

  /// The branch of the git repository.
  static const gitBranch = ContextKey<String>('alhambra.git.branch');
}
