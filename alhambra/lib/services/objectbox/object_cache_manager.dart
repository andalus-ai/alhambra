import 'package:alhambra_coding_core/alhambra_coding_core.dart'
    hide logDebug, logInfo, logWarning, logError;
import '../../models/attachment_dto.dart';
import '../../models/chat_entry_dto.dart';
import '../../models/session_dto.dart';
import '../../utils/logger.dart';
import '../../objectbox.g.dart';
import 'object_store.dart';

class ObjectBoxObjectBoxCacheManager {
  static final ObjectBoxObjectBoxCacheManager _instance =
      ObjectBoxObjectBoxCacheManager._internal();
  factory ObjectBoxObjectBoxCacheManager() => _instance;
  ObjectBoxObjectBoxCacheManager._internal();

  ObjectBoxStore get _store => ObjectBoxStore();

  /// Initialize cache
  Future<void> init() async {
    await _store.init();
  }

  // ─── Session Caching ──────────────────────────────────────────────────

  /// Cache a session
  Future<void> cacheSession(Session session) async {
    try {
      final entity = SessionEntity.fromSession(session);
      // Check if exists
      final existing = _store.sessionBox
          .query(SessionEntity_.sessionId.equals(session.id))
          .build()
          .findFirst();

      if (existing != null) {
        entity.id = existing.id;
        _store.sessionBox.put(entity);
      } else {
        _store.sessionBox.put(entity);
      }
    } catch (e) {
      logDebug('Failed to cache session: $e');
    }
  }

  /// Get cached session
  Future<Session?> getCachedSession(String sessionId) async {
    try {
      final entity = _store.sessionBox
          .query(SessionEntity_.sessionId.equals(sessionId))
          .build()
          .findFirst();

      return entity?.toSession();
    } catch (e) {
      logDebug('Failed to get cached session: $e');
      return null;
    }
  }

  /// Get all cached sessions
  Future<List<Session>> getCachedSessions() async {
    try {
      final entities = _store.sessionBox
          .query()
          .order(SessionEntity_.lastActiveAt, flags: Order.descending)
          .build()
          .find();

      return entities.map((e) => e.toSession()).toList();
    } catch (e) {
      logDebug('Failed to get cached sessions: $e');
      return [];
    }
  }

  /// Delete cached session and all related data
  Future<void> deleteCachedSession(String sessionId) async {
    try {
      // Delete all chat entries for this session
      final entries = _store.chatEntryBox
          .query(ChatEntryEntity_.sessionId.equals(sessionId))
          .build()
          .find();

      for (final entry in entries) {
        // Delete attachments
        final attachments = _store.attachmentBox
            .query(AttachmentEntity_.chatEntryId.equals(entry.entryId))
            .build()
            .find();
        _store.attachmentBox.removeMany(attachments.map((a) => a.id).toList());
      }

      // Delete chat entries
      _store.chatEntryBox.removeMany(entries.map((e) => e.id).toList());

      // Delete session
      final session = _store.sessionBox
          .query(SessionEntity_.sessionId.equals(sessionId))
          .build()
          .findFirst();

      if (session != null) {
        _store.sessionBox.remove(session.id);
      }
    } catch (e) {
      logDebug('Failed to delete cached session: $e');
    }
  }

  // ─── Transcript Caching ──────────────────────────────────────────────

  /// Cache transcript entries for a session
  Future<void> cacheTranscript(
    String sessionId,
    List<ChatEntry> entries,
  ) async {
    try {
      // Delete existing entries for this session
      final existing = _store.chatEntryBox
          .query(ChatEntryEntity_.sessionId.equals(sessionId))
          .build()
          .find();

      // Delete associated attachments
      for (final entry in existing) {
        final attachments = _store.attachmentBox
            .query(AttachmentEntity_.chatEntryId.equals(entry.entryId))
            .build()
            .find();
        _store.attachmentBox.removeMany(attachments.map((a) => a.id).toList());
      }

      _store.chatEntryBox.removeMany(existing.map((e) => e.id).toList());

      // Insert new entries
      for (final entry in entries) {
        final entity = ChatEntryEntity.fromChatEntry(entry, sessionId);
        _store.chatEntryBox.put(entity);

        // Save attachments
        if (entry.attachments != null) {
          for (final attachment in entry.attachments!) {
            final attachmentEntity = AttachmentEntity.fromAttachment(
              attachment,
              entry.id,
            );
            _store.attachmentBox.put(attachmentEntity);
          }
        }
      }
    } catch (e) {
      logDebug('Failed to cache transcript: $e');
    }
  }

  /// Get cached transcript
  Future<List<ChatEntry>> getCachedTranscript(String sessionId) async {
    try {
      final entities = _store.chatEntryBox
          .query(ChatEntryEntity_.sessionId.equals(sessionId))
          .order(ChatEntryEntity_.timestamp)
          .build()
          .find();

      final entries = <ChatEntry>[];
      for (final entity in entities) {
        // Load attachments
        final attachments = _store.attachmentBox
            .query(AttachmentEntity_.chatEntryId.equals(entity.entryId))
            .build()
            .find();

        final chatEntry = entity.toChatEntry();
        // Add attachments to entry
        if (attachments.isNotEmpty) {
          entries.add(ChatEntry(
            id: chatEntry.id,
            type: chatEntry.type,
            status: chatEntry.status,
            text: chatEntry.text,
            isLoading: chatEntry.isLoading,
            timestamp: chatEntry.timestamp,
            toolCall: chatEntry.toolCall,
            approval: chatEntry.approval,
            plan: chatEntry.plan,
            attachments: attachments.map((a) => a.toAttachment()).toList(),
            errorMessage: chatEntry.errorMessage,
            retryCount: chatEntry.retryCount,
            metadata: chatEntry.metadata,
            jobId: chatEntry.jobId,
            queuePosition: chatEntry.queuePosition,
          ));
        } else {
          entries.add(chatEntry);
        }
      }

      return entries;
    } catch (e) {
      logDebug('Failed to get cached transcript: $e');
      return [];
    }
  }

  /// Get transcript metadata
  Future<Map<String, dynamic>> getTranscriptMetadata(String sessionId) async {
    try {
      final count = _store.chatEntryBox
          .query(ChatEntryEntity_.sessionId.equals(sessionId))
          .build()
          .count();

      final lastEntry = _store.chatEntryBox
          .query(ChatEntryEntity_.sessionId.equals(sessionId))
          .order(ChatEntryEntity_.timestamp, flags: Order.descending)
          .build()
          .findFirst();

      return {
        'entryCount': count,
        'lastModified': lastEntry != null
            ? DateTime.fromMillisecondsSinceEpoch(lastEntry.timestamp)
            : null,
        'sessionId': sessionId,
      };
    } catch (e) {
      logDebug('Failed to get transcript metadata: $e');
      return {};
    }
  }

  // ─── Search Operations ───────────────────────────────────────────────

  /// Search transcripts by text
  Future<List<ChatEntry>> searchTranscript(
    String sessionId,
    String query,
  ) async {
    try {
      final entities = _store.chatEntryBox
          .query(ChatEntryEntity_.sessionId.equals(sessionId) &
              ChatEntryEntity_.text.contains(query, caseSensitive: false))
          .order(ChatEntryEntity_.timestamp)
          .build()
          .find();

      return entities.map((e) => e.toChatEntry()).toList();
    } catch (e) {
      logDebug('Failed to search transcript: $e');
      return [];
    }
  }

  /// Get entries by status
  Future<List<ChatEntry>> getEntriesByStatus(
    String sessionId,
    ChatEntryStatus status,
  ) async {
    try {
      final entities = _store.chatEntryBox
          .query(ChatEntryEntity_.sessionId.equals(sessionId) &
              ChatEntryEntity_.statusIndex.equals(status.index))
          .build()
          .find();

      return entities.map((e) => e.toChatEntry()).toList();
    } catch (e) {
      logDebug('Failed to get entries by status: $e');
      return [];
    }
  }

  // ─── Batch Operations ────────────────────────────────────────────────

  /// Batch cache sessions
  Future<void> cacheSessionsBatch(List<Session> sessions) async {
    try {
      final entities =
          sessions.map((s) => SessionEntity.fromSession(s)).toList();
      _store.sessionBox.putMany(entities);
    } catch (e) {
      logDebug('Failed to cache sessions batch: $e');
    }
  }

  // ─── Cache Maintenance ───────────────────────────────────────────────

  /// Clear old caches
  Future<void> clearOldCaches({int olderThanDays = 7}) async {
    try {
      final cutoff = DateTime.now()
          .subtract(Duration(days: olderThanDays))
          .millisecondsSinceEpoch;

      final oldSessions = _store.sessionBox
          .query(SessionEntity_.lastActiveAt.lessThan(cutoff))
          .build()
          .find();

      for (final session in oldSessions) {
        await deleteCachedSession(session.sessionId);
      }

      logDebug('Cleaned up ${oldSessions.length} old sessions');
    } catch (e) {
      logDebug('Failed to clear old caches: $e');
    }
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    try {
      _store.chatEntryBox.removeAll();
      _store.attachmentBox.removeAll();
      _store.sessionBox.removeAll();
      logDebug('Cleared all cache');
    } catch (e) {
      logDebug('Failed to clear all cache: $e');
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final sessionCount = _store.sessionBox.count();
      final entryCount = _store.chatEntryBox.count();
      final attachmentCount = _store.attachmentBox.count();

      return {
        'sessionCount': sessionCount,
        'entryCount': entryCount,
        'attachmentCount': attachmentCount,
        'lastCleaned': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      logDebug('Failed to get cache stats: $e');
      return {};
    }
  }

  // ─── Dispose ──────────────────────────────────────────────────────────

  /// Close store
  void dispose() {
    _store.close();
  }
}
