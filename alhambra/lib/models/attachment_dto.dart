import 'dart:convert';
import 'package:objectbox/objectbox.dart';

import 'package:alhambra_coding_core/alhambra_coding_core.dart';

@Entity()
class AttachmentEntity {
  @Id()
  int id = 0;

  String attachmentId;
  String name;
  int typeIndex;
  String? url;
  String? localPath;
  int size;
  String? mimeType;
  int statusIndex;
  String? thumbnailUrl;
  int? durationMs;

  String? metadataJson;

  String? errorMessage;

  @Index()
  String chatEntryId;

  AttachmentEntity({
    this.id = 0,
    required this.attachmentId,
    required this.name,
    required this.typeIndex,
    this.url,
    this.localPath,
    required this.size,
    this.mimeType,
    required this.statusIndex,
    this.thumbnailUrl,
    this.durationMs,
    this.metadataJson,
    this.errorMessage,
    required this.chatEntryId,
  });

  factory AttachmentEntity.fromAttachment(
      Attachment attachment, String chatEntryId) {
    return AttachmentEntity(
      attachmentId: attachment.id,
      name: attachment.name,
      typeIndex: attachment.type.index,
      url: attachment.url,
      localPath: attachment.localPath,
      size: attachment.size,
      mimeType: attachment.mimeType,
      statusIndex: attachment.status.index,
      thumbnailUrl: attachment.thumbnailUrl,
      durationMs: attachment.duration?.inMilliseconds,
      metadataJson:
          attachment.metadata != null ? jsonEncode(attachment.metadata) : null,
      errorMessage: attachment.errorMessage,
      chatEntryId: chatEntryId,
    );
  }

  Attachment toAttachment() {
    return Attachment(
      id: attachmentId,
      name: name,
      type: AttachmentType.values[typeIndex],
      url: url,
      localPath: localPath,
      size: size,
      mimeType: mimeType,
      status: AttachmentStatus.values[statusIndex],
      thumbnailUrl: thumbnailUrl,
      duration: durationMs != null ? Duration(milliseconds: durationMs!) : null,
      metadata: metadataJson != null
          ? jsonDecode(metadataJson!) as Map<String, dynamic>
          : null,
      errorMessage: errorMessage,
    );
  }
}
