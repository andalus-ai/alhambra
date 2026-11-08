import 'package:path_provider/path_provider.dart';

import '../../models/attachment_dto.dart';
import '../../models/chat_entry_dto.dart';
import '../../models/session_dto.dart';
import '../../plugins/dashboard/models/metrics_entry.dart';
import '../../plugins/settings/models/app_settings_entity.dart';
import '../../utils/logger.dart';
import '../../objectbox.g.dart';

class ObjectBoxStore {
  static final ObjectBoxStore _instance = ObjectBoxStore._internal();
  factory ObjectBoxStore() => _instance;
  ObjectBoxStore._internal();

  late Store _store;
  bool _isInitialized = false;

  // Boxes
  late Box<ChatEntryEntity> _chatEntryBox;
  late Box<AttachmentEntity> _attachmentBox;
  late Box<SessionEntity> _sessionBox;
  late Box<AppSettingsEntity> _settingsBox;
  late Box<MetricsEntry> _metricsBox;

  /// Initialize ObjectBox store
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = '${dir.path}/alhambra_data';
      
      _store = await openStore(
        directory: dbPath,
        macosApplicationGroup: 'group.com.yourapp',
      );

      _chatEntryBox = _store.box<ChatEntryEntity>();
      _attachmentBox = _store.box<AttachmentEntity>();
      _sessionBox = _store.box<SessionEntity>();
      _settingsBox = _store.box<AppSettingsEntity>();
      _metricsBox = _store.box<MetricsEntry>();

      _isInitialized = true;
      logDebug('ObjectBox initialized at ${dir.path}');
    } catch (e) {
      logDebug('Failed to initialize ObjectBox: $e');
      rethrow;
    }
  }

  /// Get store instance
  Store get store {
    if (!_isInitialized) {
      throw StateError('ObjectBox not initialized. Call init() first.');
    }
    return _store;
  }

  /// Get chat entry box
  Box<ChatEntryEntity> get chatEntryBox {
    if (!_isInitialized) {
      throw StateError('ObjectBox not initialized. Call init() first.');
    }
    return _chatEntryBox;
  }

  /// Get attachment box
  Box<AttachmentEntity> get attachmentBox {
    if (!_isInitialized) {
      throw StateError('ObjectBox not initialized. Call init() first.');
    }
    return _attachmentBox;
  }

  /// Get session box
  Box<SessionEntity> get sessionBox {
    if (!_isInitialized) {
      throw StateError('ObjectBox not initialized. Call init() first.');
    }
    return _sessionBox;
  }

  /// Get settings box
  Box<AppSettingsEntity> get settingsBox {
    if (!_isInitialized) {
      throw StateError('ObjectBox not initialized. Call init() first.');
    }
    return _settingsBox;
  }

  /// Get metrics box
  Box<MetricsEntry> get metricsBox {
    if (!_isInitialized) {
      throw StateError('ObjectBox not initialized. Call init() first.');
    }
    return _metricsBox;
  }

  /// Close store
  void close() {
    if (_isInitialized) {
      _store.close();
      _isInitialized = false;
    }
  }
}
