/// Snapshot reference stored in persisted layout state to allow graceful recovery when plugins are unloaded.
class PersistedViewReference {
  final String viewId;
  final String? title;
  final String? pluginId;

  const PersistedViewReference({
    required this.viewId,
    this.title,
    this.pluginId,
  });

  Map<String, dynamic> toJson() => {
        'viewId': viewId,
        if (title != null) 'title': title,
        if (pluginId != null) 'pluginId': pluginId,
      };

  factory PersistedViewReference.fromJson(Map<String, dynamic> json) =>
      PersistedViewReference(
        viewId: json['viewId'] as String,
        title: json['title'] as String?,
        pluginId: json['pluginId'] as String?,
      );
}

/// Store for persisting and retrieving view metadata snapshots.
abstract interface class ViewReferenceStore {
  PersistedViewReference? get(String viewId);
  void remember(PersistedViewReference reference);
  void forget(String viewId);
  Iterable<PersistedViewReference> get all;
}

/// Interface for migrating renamed view IDs across versions.
abstract interface class ViewIdMigration {
  String? migrate(String oldViewId);
}
