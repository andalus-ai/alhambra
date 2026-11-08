import 'dart:convert';
import 'package:objectbox/objectbox.dart';

import 'package:alhambra_coding_core/alhambra_coding_core.dart';

@Entity()
class SessionEntity {
  @Id()
  int id = 0;

  @Index()
  String sessionId;

  @Index()
  String projectId;

  String title;
  String? description;
  int statusIndex;
  int modeIndex;
  int createdAt;
  int updatedAt;
  int? lastActiveAt;
  String? forkOf;
  bool isPinned;
  int fileChanges;
  int messageCount;
  int pendingCount;
  int queueSize;
  int totalDurationMs;

  String metadataJson;

  bool isSelected;

  SessionEntity({
    this.id = 0,
    required this.sessionId,
    required this.projectId,
    required this.title,
    this.description,
    required this.statusIndex,
    required this.modeIndex,
    required this.createdAt,
    required this.updatedAt,
    this.lastActiveAt,
    this.forkOf,
    this.isPinned = false,
    this.fileChanges = 0,
    this.messageCount = 0,
    this.pendingCount = 0,
    this.queueSize = 0,
    this.totalDurationMs = 0,
    this.metadataJson = '{}',
    this.isSelected = false,
  });

  factory SessionEntity.fromSession(Session session) {
    return SessionEntity(
      sessionId: session.id,
      projectId: session.projectId,
      title: session.title,
      description: session.description,
      statusIndex: session.status.index,
      modeIndex: session.mode.index,
      createdAt: session.createdAt.millisecondsSinceEpoch,
      updatedAt: session.updatedAt.millisecondsSinceEpoch,
      lastActiveAt: session.lastActiveAt?.millisecondsSinceEpoch,
      forkOf: session.forkOf,
      isPinned: session.isPinned,
      fileChanges: session.fileChanges,
      messageCount: session.messageCount,
      pendingCount: session.pendingCount,
      queueSize: session.queueSize,
      totalDurationMs: session.totalDuration.inMilliseconds,
      metadataJson: jsonEncode(session.metadata),
      isSelected: session.isSelected,
    );
  }

  Session toSession() {
    return Session(
      id: sessionId,
      projectId: projectId,
      title: title,
      description: description,
      status: SessionStatus.values[statusIndex],
      mode: SessionMode.values[modeIndex],
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
      lastActiveAt: lastActiveAt != null
          ? DateTime.fromMillisecondsSinceEpoch(lastActiveAt!)
          : null,
      forkOf: forkOf,
      isPinned: isPinned,
      fileChanges: fileChanges,
      messageCount: messageCount,
      pendingCount: pendingCount,
      queueSize: queueSize,
      totalDuration: Duration(milliseconds: totalDurationMs),
      metadata: jsonDecode(metadataJson) as Map<String, dynamic>,
      isSelected: isSelected,
    );
  }
}
