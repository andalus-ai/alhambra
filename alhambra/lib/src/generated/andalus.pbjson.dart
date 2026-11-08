// This is a generated file - do not edit.
//
// Generated from andalus.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use projectDescriptor instead')
const Project$json = {
  '1': 'Project',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'tenant_id', '3': 2, '4': 1, '5': 9, '10': 'tenantId'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'description', '3': 4, '4': 1, '5': 9, '10': 'description'},
    {'1': 'base_path', '3': 5, '4': 1, '5': 9, '10': 'basePath'},
    {'1': 'metadata', '3': 6, '4': 1, '5': 9, '10': 'metadata'},
    {'1': 'archived', '3': 7, '4': 1, '5': 8, '10': 'archived'},
  ],
};

/// Descriptor for `Project`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List projectDescriptor = $convert.base64Decode(
    'CgdQcm9qZWN0Eg4KAmlkGAEgASgJUgJpZBIbCgl0ZW5hbnRfaWQYAiABKAlSCHRlbmFudElkEh'
    'IKBG5hbWUYAyABKAlSBG5hbWUSIAoLZGVzY3JpcHRpb24YBCABKAlSC2Rlc2NyaXB0aW9uEhsK'
    'CWJhc2VfcGF0aBgFIAEoCVIIYmFzZVBhdGgSGgoIbWV0YWRhdGEYBiABKAlSCG1ldGFkYXRhEh'
    'oKCGFyY2hpdmVkGAcgASgIUghhcmNoaXZlZA==');

@$core.Deprecated('Use sessionDescriptor instead')
const Session$json = {
  '1': 'Session',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'project_id', '3': 2, '4': 1, '5': 9, '10': 'projectId'},
    {'1': 'tenant_id', '3': 3, '4': 1, '5': 9, '10': 'tenantId'},
    {'1': 'name', '3': 4, '4': 1, '5': 9, '10': 'name'},
    {'1': 'status', '3': 5, '4': 1, '5': 9, '10': 'status'},
    {'1': 'metadata', '3': 6, '4': 1, '5': 9, '10': 'metadata'},
  ],
};

/// Descriptor for `Session`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionDescriptor = $convert.base64Decode(
    'CgdTZXNzaW9uEg4KAmlkGAEgASgJUgJpZBIdCgpwcm9qZWN0X2lkGAIgASgJUglwcm9qZWN0SW'
    'QSGwoJdGVuYW50X2lkGAMgASgJUgh0ZW5hbnRJZBISCgRuYW1lGAQgASgJUgRuYW1lEhYKBnN0'
    'YXR1cxgFIAEoCVIGc3RhdHVzEhoKCG1ldGFkYXRhGAYgASgJUghtZXRhZGF0YQ==');

@$core.Deprecated('Use apiKeyDescriptor instead')
const ApiKey$json = {
  '1': 'ApiKey',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'tenant_id', '3': 2, '4': 1, '5': 9, '10': 'tenantId'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'key_prefix', '3': 4, '4': 1, '5': 9, '10': 'keyPrefix'},
    {'1': 'enabled', '3': 5, '4': 1, '5': 8, '10': 'enabled'},
  ],
};

/// Descriptor for `ApiKey`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List apiKeyDescriptor = $convert.base64Decode(
    'CgZBcGlLZXkSDgoCaWQYASABKAlSAmlkEhsKCXRlbmFudF9pZBgCIAEoCVIIdGVuYW50SWQSEg'
    'oEbmFtZRgDIAEoCVIEbmFtZRIdCgprZXlfcHJlZml4GAQgASgJUglrZXlQcmVmaXgSGAoHZW5h'
    'YmxlZBgFIAEoCFIHZW5hYmxlZA==');

@$core.Deprecated('Use emptyDescriptor instead')
const Empty$json = {
  '1': 'Empty',
};

/// Descriptor for `Empty`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List emptyDescriptor =
    $convert.base64Decode('CgVFbXB0eQ==');

@$core.Deprecated('Use createProjectRequestDescriptor instead')
const CreateProjectRequest$json = {
  '1': 'CreateProjectRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'description', '3': 2, '4': 1, '5': 9, '10': 'description'},
    {'1': 'base_path', '3': 3, '4': 1, '5': 9, '10': 'basePath'},
  ],
};

/// Descriptor for `CreateProjectRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createProjectRequestDescriptor = $convert.base64Decode(
    'ChRDcmVhdGVQcm9qZWN0UmVxdWVzdBISCgRuYW1lGAEgASgJUgRuYW1lEiAKC2Rlc2NyaXB0aW'
    '9uGAIgASgJUgtkZXNjcmlwdGlvbhIbCgliYXNlX3BhdGgYAyABKAlSCGJhc2VQYXRo');

@$core.Deprecated('Use listProjectsRequestDescriptor instead')
const ListProjectsRequest$json = {
  '1': 'ListProjectsRequest',
  '2': [
    {'1': 'include_archived', '3': 1, '4': 1, '5': 8, '10': 'includeArchived'},
  ],
};

/// Descriptor for `ListProjectsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listProjectsRequestDescriptor = $convert.base64Decode(
    'ChNMaXN0UHJvamVjdHNSZXF1ZXN0EikKEGluY2x1ZGVfYXJjaGl2ZWQYASABKAhSD2luY2x1ZG'
    'VBcmNoaXZlZA==');

@$core.Deprecated('Use listProjectsResponseDescriptor instead')
const ListProjectsResponse$json = {
  '1': 'ListProjectsResponse',
  '2': [
    {
      '1': 'projects',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.andalus.Project',
      '10': 'projects'
    },
  ],
};

/// Descriptor for `ListProjectsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listProjectsResponseDescriptor = $convert.base64Decode(
    'ChRMaXN0UHJvamVjdHNSZXNwb25zZRIsCghwcm9qZWN0cxgBIAMoCzIQLmFuZGFsdXMuUHJvam'
    'VjdFIIcHJvamVjdHM=');

@$core.Deprecated('Use createSessionRequestDescriptor instead')
const CreateSessionRequest$json = {
  '1': 'CreateSessionRequest',
  '2': [
    {'1': 'project_id', '3': 1, '4': 1, '5': 9, '10': 'projectId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `CreateSessionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createSessionRequestDescriptor = $convert.base64Decode(
    'ChRDcmVhdGVTZXNzaW9uUmVxdWVzdBIdCgpwcm9qZWN0X2lkGAEgASgJUglwcm9qZWN0SWQSEg'
    'oEbmFtZRgCIAEoCVIEbmFtZQ==');

@$core.Deprecated('Use listSessionsRequestDescriptor instead')
const ListSessionsRequest$json = {
  '1': 'ListSessionsRequest',
  '2': [
    {'1': 'project_id', '3': 1, '4': 1, '5': 9, '10': 'projectId'},
  ],
};

/// Descriptor for `ListSessionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listSessionsRequestDescriptor = $convert.base64Decode(
    'ChNMaXN0U2Vzc2lvbnNSZXF1ZXN0Eh0KCnByb2plY3RfaWQYASABKAlSCXByb2plY3RJZA==');

@$core.Deprecated('Use listSessionsResponseDescriptor instead')
const ListSessionsResponse$json = {
  '1': 'ListSessionsResponse',
  '2': [
    {
      '1': 'sessions',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.andalus.Session',
      '10': 'sessions'
    },
  ],
};

/// Descriptor for `ListSessionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listSessionsResponseDescriptor = $convert.base64Decode(
    'ChRMaXN0U2Vzc2lvbnNSZXNwb25zZRIsCghzZXNzaW9ucxgBIAMoCzIQLmFuZGFsdXMuU2Vzc2'
    'lvblIIc2Vzc2lvbnM=');

@$core.Deprecated('Use forkSessionRequestDescriptor instead')
const ForkSessionRequest$json = {
  '1': 'ForkSessionRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'message_id', '3': 2, '4': 1, '5': 9, '10': 'messageId'},
  ],
};

/// Descriptor for `ForkSessionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List forkSessionRequestDescriptor = $convert.base64Decode(
    'ChJGb3JrU2Vzc2lvblJlcXVlc3QSHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbklkEh0KCm'
    '1lc3NhZ2VfaWQYAiABKAlSCW1lc3NhZ2VJZA==');

@$core.Deprecated('Use deleteSessionRequestDescriptor instead')
const DeleteSessionRequest$json = {
  '1': 'DeleteSessionRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
  ],
};

/// Descriptor for `DeleteSessionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteSessionRequestDescriptor = $convert.base64Decode(
    'ChREZWxldGVTZXNzaW9uUmVxdWVzdBIdCgpzZXNzaW9uX2lkGAEgASgJUglzZXNzaW9uSWQ=');

@$core.Deprecated('Use deleteSessionResponseDescriptor instead')
const DeleteSessionResponse$json = {
  '1': 'DeleteSessionResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
  ],
};

/// Descriptor for `DeleteSessionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteSessionResponseDescriptor =
    $convert.base64Decode(
        'ChVEZWxldGVTZXNzaW9uUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2Vzcw==');

@$core.Deprecated('Use indexWorkspaceRequestDescriptor instead')
const IndexWorkspaceRequest$json = {
  '1': 'IndexWorkspaceRequest',
  '2': [
    {'1': 'project_id', '3': 1, '4': 1, '5': 9, '10': 'projectId'},
    {'1': 'workspace_path', '3': 2, '4': 1, '5': 9, '10': 'workspacePath'},
  ],
};

/// Descriptor for `IndexWorkspaceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List indexWorkspaceRequestDescriptor = $convert.base64Decode(
    'ChVJbmRleFdvcmtzcGFjZVJlcXVlc3QSHQoKcHJvamVjdF9pZBgBIAEoCVIJcHJvamVjdElkEi'
    'UKDndvcmtzcGFjZV9wYXRoGAIgASgJUg13b3Jrc3BhY2VQYXRo');

@$core.Deprecated('Use indexWorkspaceResponseDescriptor instead')
const IndexWorkspaceResponse$json = {
  '1': 'IndexWorkspaceResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'files_indexed', '3': 2, '4': 1, '5': 5, '10': 'filesIndexed'},
    {'1': 'symbols_indexed', '3': 3, '4': 1, '5': 5, '10': 'symbolsIndexed'},
    {
      '1': 'dependencies_indexed',
      '3': 4,
      '4': 1,
      '5': 5,
      '10': 'dependenciesIndexed'
    },
    {'1': 'duration_ms', '3': 5, '4': 1, '5': 3, '10': 'durationMs'},
    {'1': 'repository_hash', '3': 6, '4': 1, '5': 9, '10': 'repositoryHash'},
    {'1': 'error', '3': 7, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `IndexWorkspaceResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List indexWorkspaceResponseDescriptor = $convert.base64Decode(
    'ChZJbmRleFdvcmtzcGFjZVJlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3MSIwoNZm'
    'lsZXNfaW5kZXhlZBgCIAEoBVIMZmlsZXNJbmRleGVkEicKD3N5bWJvbHNfaW5kZXhlZBgDIAEo'
    'BVIOc3ltYm9sc0luZGV4ZWQSMQoUZGVwZW5kZW5jaWVzX2luZGV4ZWQYBCABKAVSE2RlcGVuZG'
    'VuY2llc0luZGV4ZWQSHwoLZHVyYXRpb25fbXMYBSABKANSCmR1cmF0aW9uTXMSJwoPcmVwb3Np'
    'dG9yeV9oYXNoGAYgASgJUg5yZXBvc2l0b3J5SGFzaBIUCgVlcnJvchgHIAEoCVIFZXJyb3I=');

@$core.Deprecated('Use updateSessionStatusRequestDescriptor instead')
const UpdateSessionStatusRequest$json = {
  '1': 'UpdateSessionStatusRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'status', '3': 2, '4': 1, '5': 9, '10': 'status'},
  ],
};

/// Descriptor for `UpdateSessionStatusRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateSessionStatusRequestDescriptor =
    $convert.base64Decode(
        'ChpVcGRhdGVTZXNzaW9uU3RhdHVzUmVxdWVzdBIdCgpzZXNzaW9uX2lkGAEgASgJUglzZXNzaW'
        '9uSWQSFgoGc3RhdHVzGAIgASgJUgZzdGF0dXM=');

@$core.Deprecated('Use taskDescriptor instead')
const Task$json = {
  '1': 'Task',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'tenant_id', '3': 3, '4': 1, '5': 9, '10': 'tenantId'},
    {'1': 'task_type', '3': 4, '4': 1, '5': 9, '10': 'taskType'},
    {'1': 'payload', '3': 5, '4': 1, '5': 9, '10': 'payload'},
    {'1': 'status', '3': 6, '4': 1, '5': 9, '10': 'status'},
    {'1': 'priority', '3': 7, '4': 1, '5': 5, '10': 'priority'},
    {'1': 'attempts', '3': 8, '4': 1, '5': 5, '10': 'attempts'},
    {'1': 'max_attempts', '3': 9, '4': 1, '5': 5, '10': 'maxAttempts'},
    {'1': 'error', '3': 10, '4': 1, '5': 9, '10': 'error'},
    {'1': 'scheduled_at', '3': 11, '4': 1, '5': 9, '10': 'scheduledAt'},
    {'1': 'started_at', '3': 12, '4': 1, '5': 9, '10': 'startedAt'},
    {'1': 'completed_at', '3': 13, '4': 1, '5': 9, '10': 'completedAt'},
    {'1': 'created_at', '3': 14, '4': 1, '5': 9, '10': 'createdAt'},
  ],
};

/// Descriptor for `Task`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List taskDescriptor = $convert.base64Decode(
    'CgRUYXNrEg4KAmlkGAEgASgJUgJpZBIdCgpzZXNzaW9uX2lkGAIgASgJUglzZXNzaW9uSWQSGw'
    'oJdGVuYW50X2lkGAMgASgJUgh0ZW5hbnRJZBIbCgl0YXNrX3R5cGUYBCABKAlSCHRhc2tUeXBl'
    'EhgKB3BheWxvYWQYBSABKAlSB3BheWxvYWQSFgoGc3RhdHVzGAYgASgJUgZzdGF0dXMSGgoIcH'
    'Jpb3JpdHkYByABKAVSCHByaW9yaXR5EhoKCGF0dGVtcHRzGAggASgFUghhdHRlbXB0cxIhCgxt'
    'YXhfYXR0ZW1wdHMYCSABKAVSC21heEF0dGVtcHRzEhQKBWVycm9yGAogASgJUgVlcnJvchIhCg'
    'xzY2hlZHVsZWRfYXQYCyABKAlSC3NjaGVkdWxlZEF0Eh0KCnN0YXJ0ZWRfYXQYDCABKAlSCXN0'
    'YXJ0ZWRBdBIhCgxjb21wbGV0ZWRfYXQYDSABKAlSC2NvbXBsZXRlZEF0Eh0KCmNyZWF0ZWRfYX'
    'QYDiABKAlSCWNyZWF0ZWRBdA==');

@$core.Deprecated('Use createTaskRequestDescriptor instead')
const CreateTaskRequest$json = {
  '1': 'CreateTaskRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'task_type', '3': 2, '4': 1, '5': 9, '10': 'taskType'},
    {'1': 'payload', '3': 3, '4': 1, '5': 9, '10': 'payload'},
    {'1': 'priority', '3': 4, '4': 1, '5': 5, '10': 'priority'},
  ],
};

/// Descriptor for `CreateTaskRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createTaskRequestDescriptor = $convert.base64Decode(
    'ChFDcmVhdGVUYXNrUmVxdWVzdBIdCgpzZXNzaW9uX2lkGAEgASgJUglzZXNzaW9uSWQSGwoJdG'
    'Fza190eXBlGAIgASgJUgh0YXNrVHlwZRIYCgdwYXlsb2FkGAMgASgJUgdwYXlsb2FkEhoKCHBy'
    'aW9yaXR5GAQgASgFUghwcmlvcml0eQ==');

@$core.Deprecated('Use listTasksRequestDescriptor instead')
const ListTasksRequest$json = {
  '1': 'ListTasksRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
  ],
};

/// Descriptor for `ListTasksRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTasksRequestDescriptor = $convert.base64Decode(
    'ChBMaXN0VGFza3NSZXF1ZXN0Eh0KCnNlc3Npb25faWQYASABKAlSCXNlc3Npb25JZA==');

@$core.Deprecated('Use listTasksResponseDescriptor instead')
const ListTasksResponse$json = {
  '1': 'ListTasksResponse',
  '2': [
    {
      '1': 'tasks',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.andalus.Task',
      '10': 'tasks'
    },
  ],
};

/// Descriptor for `ListTasksResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTasksResponseDescriptor = $convert.base64Decode(
    'ChFMaXN0VGFza3NSZXNwb25zZRIjCgV0YXNrcxgBIAMoCzINLmFuZGFsdXMuVGFza1IFdGFza3'
    'M=');

@$core.Deprecated('Use updateTaskStatusRequestDescriptor instead')
const UpdateTaskStatusRequest$json = {
  '1': 'UpdateTaskStatusRequest',
  '2': [
    {'1': 'task_id', '3': 1, '4': 1, '5': 9, '10': 'taskId'},
    {'1': 'status', '3': 2, '4': 1, '5': 9, '10': 'status'},
    {'1': 'error', '3': 3, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `UpdateTaskStatusRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateTaskStatusRequestDescriptor =
    $convert.base64Decode(
        'ChdVcGRhdGVUYXNrU3RhdHVzUmVxdWVzdBIXCgd0YXNrX2lkGAEgASgJUgZ0YXNrSWQSFgoGc3'
        'RhdHVzGAIgASgJUgZzdGF0dXMSFAoFZXJyb3IYAyABKAlSBWVycm9y');

@$core.Deprecated('Use chatMessageDescriptor instead')
const ChatMessage$json = {
  '1': 'ChatMessage',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'tenant_id', '3': 3, '4': 1, '5': 9, '10': 'tenantId'},
    {'1': 'role', '3': 4, '4': 1, '5': 9, '10': 'role'},
    {'1': 'content', '3': 5, '4': 1, '5': 9, '10': 'content'},
    {'1': 'tool_calls', '3': 6, '4': 1, '5': 9, '10': 'toolCalls'},
    {'1': 'tokens', '3': 7, '4': 1, '5': 5, '10': 'tokens'},
    {'1': 'model', '3': 8, '4': 1, '5': 9, '10': 'model'},
    {'1': 'created_at', '3': 9, '4': 1, '5': 9, '10': 'createdAt'},
  ],
};

/// Descriptor for `ChatMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatMessageDescriptor = $convert.base64Decode(
    'CgtDaGF0TWVzc2FnZRIOCgJpZBgBIAEoCVICaWQSHQoKc2Vzc2lvbl9pZBgCIAEoCVIJc2Vzc2'
    'lvbklkEhsKCXRlbmFudF9pZBgDIAEoCVIIdGVuYW50SWQSEgoEcm9sZRgEIAEoCVIEcm9sZRIY'
    'Cgdjb250ZW50GAUgASgJUgdjb250ZW50Eh0KCnRvb2xfY2FsbHMYBiABKAlSCXRvb2xDYWxscx'
    'IWCgZ0b2tlbnMYByABKAVSBnRva2VucxIUCgVtb2RlbBgIIAEoCVIFbW9kZWwSHQoKY3JlYXRl'
    'ZF9hdBgJIAEoCVIJY3JlYXRlZEF0');

@$core.Deprecated('Use listChatMessagesRequestDescriptor instead')
const ListChatMessagesRequest$json = {
  '1': 'ListChatMessagesRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'limit', '3': 2, '4': 1, '5': 5, '10': 'limit'},
    {'1': 'offset', '3': 3, '4': 1, '5': 5, '10': 'offset'},
  ],
};

/// Descriptor for `ListChatMessagesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listChatMessagesRequestDescriptor =
    $convert.base64Decode(
        'ChdMaXN0Q2hhdE1lc3NhZ2VzUmVxdWVzdBIdCgpzZXNzaW9uX2lkGAEgASgJUglzZXNzaW9uSW'
        'QSFAoFbGltaXQYAiABKAVSBWxpbWl0EhYKBm9mZnNldBgDIAEoBVIGb2Zmc2V0');

@$core.Deprecated('Use listChatMessagesResponseDescriptor instead')
const ListChatMessagesResponse$json = {
  '1': 'ListChatMessagesResponse',
  '2': [
    {
      '1': 'messages',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.andalus.ChatMessage',
      '10': 'messages'
    },
  ],
};

/// Descriptor for `ListChatMessagesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listChatMessagesResponseDescriptor =
    $convert.base64Decode(
        'ChhMaXN0Q2hhdE1lc3NhZ2VzUmVzcG9uc2USMAoIbWVzc2FnZXMYASADKAsyFC5hbmRhbHVzLk'
        'NoYXRNZXNzYWdlUghtZXNzYWdlcw==');

@$core.Deprecated('Use addChatMessageRequestDescriptor instead')
const AddChatMessageRequest$json = {
  '1': 'AddChatMessageRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'role', '3': 2, '4': 1, '5': 9, '10': 'role'},
    {'1': 'content', '3': 3, '4': 1, '5': 9, '10': 'content'},
    {'1': 'tool_calls', '3': 4, '4': 1, '5': 9, '10': 'toolCalls'},
    {'1': 'tokens', '3': 5, '4': 1, '5': 5, '10': 'tokens'},
    {'1': 'model', '3': 6, '4': 1, '5': 9, '10': 'model'},
  ],
};

/// Descriptor for `AddChatMessageRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addChatMessageRequestDescriptor = $convert.base64Decode(
    'ChVBZGRDaGF0TWVzc2FnZVJlcXVlc3QSHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbklkEh'
    'IKBHJvbGUYAiABKAlSBHJvbGUSGAoHY29udGVudBgDIAEoCVIHY29udGVudBIdCgp0b29sX2Nh'
    'bGxzGAQgASgJUgl0b29sQ2FsbHMSFgoGdG9rZW5zGAUgASgFUgZ0b2tlbnMSFAoFbW9kZWwYBi'
    'ABKAlSBW1vZGVs');

@$core.Deprecated('Use observeSessionRequestDescriptor instead')
const ObserveSessionRequest$json = {
  '1': 'ObserveSessionRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
  ],
};

/// Descriptor for `ObserveSessionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List observeSessionRequestDescriptor = $convert.base64Decode(
    'ChVPYnNlcnZlU2Vzc2lvblJlcXVlc3QSHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbklk');

@$core.Deprecated('Use createApiKeyRequestDescriptor instead')
const CreateApiKeyRequest$json = {
  '1': 'CreateApiKeyRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `CreateApiKeyRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createApiKeyRequestDescriptor = $convert
    .base64Decode('ChNDcmVhdGVBcGlLZXlSZXF1ZXN0EhIKBG5hbWUYASABKAlSBG5hbWU=');

@$core.Deprecated('Use createApiKeyResponseDescriptor instead')
const CreateApiKeyResponse$json = {
  '1': 'CreateApiKeyResponse',
  '2': [
    {
      '1': 'api_key',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.andalus.ApiKey',
      '10': 'apiKey'
    },
    {'1': 'plain_text_key', '3': 2, '4': 1, '5': 9, '10': 'plainTextKey'},
  ],
};

/// Descriptor for `CreateApiKeyResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createApiKeyResponseDescriptor = $convert.base64Decode(
    'ChRDcmVhdGVBcGlLZXlSZXNwb25zZRIoCgdhcGlfa2V5GAEgASgLMg8uYW5kYWx1cy5BcGlLZX'
    'lSBmFwaUtleRIkCg5wbGFpbl90ZXh0X2tleRgCIAEoCVIMcGxhaW5UZXh0S2V5');

@$core.Deprecated('Use listApiKeysResponseDescriptor instead')
const ListApiKeysResponse$json = {
  '1': 'ListApiKeysResponse',
  '2': [
    {
      '1': 'api_keys',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.andalus.ApiKey',
      '10': 'apiKeys'
    },
  ],
};

/// Descriptor for `ListApiKeysResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listApiKeysResponseDescriptor = $convert.base64Decode(
    'ChNMaXN0QXBpS2V5c1Jlc3BvbnNlEioKCGFwaV9rZXlzGAEgAygLMg8uYW5kYWx1cy5BcGlLZX'
    'lSB2FwaUtleXM=');

@$core.Deprecated('Use runAgentRequestDescriptor instead')
const RunAgentRequest$json = {
  '1': 'RunAgentRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'prompt', '3': 2, '4': 1, '5': 9, '10': 'prompt'},
    {'1': 'provider_id', '3': 3, '4': 1, '5': 9, '10': 'providerId'},
    {'1': 'model_id', '3': 4, '4': 1, '5': 9, '10': 'modelId'},
    {'1': 'workspace_path', '3': 5, '4': 1, '5': 9, '10': 'workspacePath'},
    {'1': 'agent_profile', '3': 6, '4': 1, '5': 9, '10': 'agentProfile'},
  ],
};

/// Descriptor for `RunAgentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List runAgentRequestDescriptor = $convert.base64Decode(
    'Cg9SdW5BZ2VudFJlcXVlc3QSHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbklkEhYKBnByb2'
    '1wdBgCIAEoCVIGcHJvbXB0Eh8KC3Byb3ZpZGVyX2lkGAMgASgJUgpwcm92aWRlcklkEhkKCG1v'
    'ZGVsX2lkGAQgASgJUgdtb2RlbElkEiUKDndvcmtzcGFjZV9wYXRoGAUgASgJUg13b3Jrc3BhY2'
    'VQYXRoEiMKDWFnZW50X3Byb2ZpbGUYBiABKAlSDGFnZW50UHJvZmlsZQ==');

@$core.Deprecated('Use runAgentEventDescriptor instead')
const RunAgentEvent$json = {
  '1': 'RunAgentEvent',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 9, '10': 'type'},
    {'1': 'content', '3': 2, '4': 1, '5': 9, '10': 'content'},
    {'1': 'payload', '3': 3, '4': 1, '5': 9, '10': 'payload'},
  ],
};

/// Descriptor for `RunAgentEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List runAgentEventDescriptor = $convert.base64Decode(
    'Cg1SdW5BZ2VudEV2ZW50EhIKBHR5cGUYASABKAlSBHR5cGUSGAoHY29udGVudBgCIAEoCVIHY2'
    '9udGVudBIYCgdwYXlsb2FkGAMgASgJUgdwYXlsb2Fk');

@$core.Deprecated('Use providerInfoDescriptor instead')
const ProviderInfo$json = {
  '1': 'ProviderInfo',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
    {'1': 'capabilities', '3': 4, '4': 3, '5': 9, '10': 'capabilities'},
  ],
};

/// Descriptor for `ProviderInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List providerInfoDescriptor = $convert.base64Decode(
    'CgxQcm92aWRlckluZm8SDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSIAoLZG'
    'VzY3JpcHRpb24YAyABKAlSC2Rlc2NyaXB0aW9uEiIKDGNhcGFiaWxpdGllcxgEIAMoCVIMY2Fw'
    'YWJpbGl0aWVz');

@$core.Deprecated('Use listProvidersResponseDescriptor instead')
const ListProvidersResponse$json = {
  '1': 'ListProvidersResponse',
  '2': [
    {
      '1': 'providers',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.andalus.ProviderInfo',
      '10': 'providers'
    },
  ],
};

/// Descriptor for `ListProvidersResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listProvidersResponseDescriptor = $convert.base64Decode(
    'ChVMaXN0UHJvdmlkZXJzUmVzcG9uc2USMwoJcHJvdmlkZXJzGAEgAygLMhUuYW5kYWx1cy5Qcm'
    '92aWRlckluZm9SCXByb3ZpZGVycw==');

@$core.Deprecated('Use modelInfoDescriptor instead')
const ModelInfo$json = {
  '1': 'ModelInfo',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
    {'1': 'format', '3': 4, '4': 1, '5': 9, '10': 'format'},
    {'1': 'size_bytes', '3': 5, '4': 1, '5': 3, '10': 'sizeBytes'},
  ],
};

/// Descriptor for `ModelInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List modelInfoDescriptor = $convert.base64Decode(
    'CglNb2RlbEluZm8SDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSIAoLZGVzY3'
    'JpcHRpb24YAyABKAlSC2Rlc2NyaXB0aW9uEhYKBmZvcm1hdBgEIAEoCVIGZm9ybWF0Eh0KCnNp'
    'emVfYnl0ZXMYBSABKANSCXNpemVCeXRlcw==');

@$core.Deprecated('Use listModelsRequestDescriptor instead')
const ListModelsRequest$json = {
  '1': 'ListModelsRequest',
  '2': [
    {'1': 'provider_id', '3': 1, '4': 1, '5': 9, '10': 'providerId'},
  ],
};

/// Descriptor for `ListModelsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listModelsRequestDescriptor = $convert.base64Decode(
    'ChFMaXN0TW9kZWxzUmVxdWVzdBIfCgtwcm92aWRlcl9pZBgBIAEoCVIKcHJvdmlkZXJJZA==');

@$core.Deprecated('Use listModelsResponseDescriptor instead')
const ListModelsResponse$json = {
  '1': 'ListModelsResponse',
  '2': [
    {
      '1': 'models',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.andalus.ModelInfo',
      '10': 'models'
    },
  ],
};

/// Descriptor for `ListModelsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listModelsResponseDescriptor = $convert.base64Decode(
    'ChJMaXN0TW9kZWxzUmVzcG9uc2USKgoGbW9kZWxzGAEgAygLMhIuYW5kYWx1cy5Nb2RlbEluZm'
    '9SBm1vZGVscw==');

@$core.Deprecated('Use mcpServerInfoDescriptor instead')
const McpServerInfo$json = {
  '1': 'McpServerInfo',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'url', '3': 2, '4': 1, '5': 9, '10': 'url'},
    {'1': 'command', '3': 3, '4': 1, '5': 9, '10': 'command'},
    {'1': 'args', '3': 4, '4': 3, '5': 9, '10': 'args'},
    {'1': 'transport', '3': 5, '4': 1, '5': 9, '10': 'transport'},
    {'1': 'enabled', '3': 6, '4': 1, '5': 8, '10': 'enabled'},
  ],
};

/// Descriptor for `McpServerInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mcpServerInfoDescriptor = $convert.base64Decode(
    'Cg1NY3BTZXJ2ZXJJbmZvEg4KAmlkGAEgASgJUgJpZBIQCgN1cmwYAiABKAlSA3VybBIYCgdjb2'
    '1tYW5kGAMgASgJUgdjb21tYW5kEhIKBGFyZ3MYBCADKAlSBGFyZ3MSHAoJdHJhbnNwb3J0GAUg'
    'ASgJUgl0cmFuc3BvcnQSGAoHZW5hYmxlZBgGIAEoCFIHZW5hYmxlZA==');

@$core.Deprecated('Use listMcpServersResponseDescriptor instead')
const ListMcpServersResponse$json = {
  '1': 'ListMcpServersResponse',
  '2': [
    {
      '1': 'servers',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.andalus.McpServerInfo',
      '10': 'servers'
    },
  ],
};

/// Descriptor for `ListMcpServersResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listMcpServersResponseDescriptor =
    $convert.base64Decode(
        'ChZMaXN0TWNwU2VydmVyc1Jlc3BvbnNlEjAKB3NlcnZlcnMYASADKAsyFi5hbmRhbHVzLk1jcF'
        'NlcnZlckluZm9SB3NlcnZlcnM=');

@$core.Deprecated('Use registerMcpServerRequestDescriptor instead')
const RegisterMcpServerRequest$json = {
  '1': 'RegisterMcpServerRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'url', '3': 2, '4': 1, '5': 9, '10': 'url'},
    {'1': 'command', '3': 3, '4': 1, '5': 9, '10': 'command'},
    {'1': 'args', '3': 4, '4': 3, '5': 9, '10': 'args'},
    {'1': 'transport', '3': 5, '4': 1, '5': 9, '10': 'transport'},
    {'1': 'enabled', '3': 6, '4': 1, '5': 8, '10': 'enabled'},
  ],
};

/// Descriptor for `RegisterMcpServerRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerMcpServerRequestDescriptor = $convert.base64Decode(
    'ChhSZWdpc3Rlck1jcFNlcnZlclJlcXVlc3QSDgoCaWQYASABKAlSAmlkEhAKA3VybBgCIAEoCV'
    'IDdXJsEhgKB2NvbW1hbmQYAyABKAlSB2NvbW1hbmQSEgoEYXJncxgEIAMoCVIEYXJncxIcCgl0'
    'cmFuc3BvcnQYBSABKAlSCXRyYW5zcG9ydBIYCgdlbmFibGVkGAYgASgIUgdlbmFibGVk');

@$core.Deprecated('Use removeMcpServerRequestDescriptor instead')
const RemoveMcpServerRequest$json = {
  '1': 'RemoveMcpServerRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `RemoveMcpServerRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeMcpServerRequestDescriptor = $convert
    .base64Decode('ChZSZW1vdmVNY3BTZXJ2ZXJSZXF1ZXN0Eg4KAmlkGAEgASgJUgJpZA==');

@$core.Deprecated('Use removeMcpServerResponseDescriptor instead')
const RemoveMcpServerResponse$json = {
  '1': 'RemoveMcpServerResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `RemoveMcpServerResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeMcpServerResponseDescriptor =
    $convert.base64Decode(
        'ChdSZW1vdmVNY3BTZXJ2ZXJSZXNwb25zZRIYCgdzdWNjZXNzGAEgASgIUgdzdWNjZXNzEhgKB2'
        '1lc3NhZ2UYAiABKAlSB21lc3NhZ2U=');

@$core.Deprecated('Use reloadMcpResponseDescriptor instead')
const ReloadMcpResponse$json = {
  '1': 'ReloadMcpResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'server_count', '3': 2, '4': 1, '5': 5, '10': 'serverCount'},
    {'1': 'tool_count', '3': 3, '4': 1, '5': 5, '10': 'toolCount'},
  ],
};

/// Descriptor for `ReloadMcpResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reloadMcpResponseDescriptor = $convert.base64Decode(
    'ChFSZWxvYWRNY3BSZXNwb25zZRIYCgdzdWNjZXNzGAEgASgIUgdzdWNjZXNzEiEKDHNlcnZlcl'
    '9jb3VudBgCIAEoBVILc2VydmVyQ291bnQSHQoKdG9vbF9jb3VudBgDIAEoBVIJdG9vbENvdW50');

@$core.Deprecated('Use mcpToolInfoDescriptor instead')
const McpToolInfo$json = {
  '1': 'McpToolInfo',
  '2': [
    {'1': 'server_id', '3': 1, '4': 1, '5': 9, '10': 'serverId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
    {'1': 'input_schema_json', '3': 4, '4': 1, '5': 9, '10': 'inputSchemaJson'},
  ],
};

/// Descriptor for `McpToolInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mcpToolInfoDescriptor = $convert.base64Decode(
    'CgtNY3BUb29sSW5mbxIbCglzZXJ2ZXJfaWQYASABKAlSCHNlcnZlcklkEhIKBG5hbWUYAiABKA'
    'lSBG5hbWUSIAoLZGVzY3JpcHRpb24YAyABKAlSC2Rlc2NyaXB0aW9uEioKEWlucHV0X3NjaGVt'
    'YV9qc29uGAQgASgJUg9pbnB1dFNjaGVtYUpzb24=');

@$core.Deprecated('Use listMcpToolsResponseDescriptor instead')
const ListMcpToolsResponse$json = {
  '1': 'ListMcpToolsResponse',
  '2': [
    {
      '1': 'tools',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.andalus.McpToolInfo',
      '10': 'tools'
    },
  ],
};

/// Descriptor for `ListMcpToolsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listMcpToolsResponseDescriptor = $convert.base64Decode(
    'ChRMaXN0TWNwVG9vbHNSZXNwb25zZRIqCgV0b29scxgBIAMoCzIULmFuZGFsdXMuTWNwVG9vbE'
    'luZm9SBXRvb2xz');

@$core.Deprecated('Use exportMemoryRequestDescriptor instead')
const ExportMemoryRequest$json = {
  '1': 'ExportMemoryRequest',
  '2': [
    {'1': 'agent_id', '3': 1, '4': 1, '5': 9, '10': 'agentId'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'tenant_id', '3': 3, '4': 1, '5': 9, '10': 'tenantId'},
  ],
};

/// Descriptor for `ExportMemoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exportMemoryRequestDescriptor = $convert.base64Decode(
    'ChNFeHBvcnRNZW1vcnlSZXF1ZXN0EhkKCGFnZW50X2lkGAEgASgJUgdhZ2VudElkEhcKB3VzZX'
    'JfaWQYAiABKAlSBnVzZXJJZBIbCgl0ZW5hbnRfaWQYAyABKAlSCHRlbmFudElk');

@$core.Deprecated('Use exportMemoryResponseDescriptor instead')
const ExportMemoryResponse$json = {
  '1': 'ExportMemoryResponse',
  '2': [
    {'1': 'snapshot_id', '3': 1, '4': 1, '5': 9, '10': 'snapshotId'},
    {'1': 'agent_id', '3': 2, '4': 1, '5': 9, '10': 'agentId'},
    {'1': 'record_count', '3': 3, '4': 1, '5': 5, '10': 'recordCount'},
    {'1': 'tiers', '3': 4, '4': 3, '5': 9, '10': 'tiers'},
    {'1': 'snapshot_json', '3': 5, '4': 1, '5': 9, '10': 'snapshotJson'},
    {'1': 'captured_at', '3': 6, '4': 1, '5': 9, '10': 'capturedAt'},
  ],
};

/// Descriptor for `ExportMemoryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exportMemoryResponseDescriptor = $convert.base64Decode(
    'ChRFeHBvcnRNZW1vcnlSZXNwb25zZRIfCgtzbmFwc2hvdF9pZBgBIAEoCVIKc25hcHNob3RJZB'
    'IZCghhZ2VudF9pZBgCIAEoCVIHYWdlbnRJZBIhCgxyZWNvcmRfY291bnQYAyABKAVSC3JlY29y'
    'ZENvdW50EhQKBXRpZXJzGAQgAygJUgV0aWVycxIjCg1zbmFwc2hvdF9qc29uGAUgASgJUgxzbm'
    'Fwc2hvdEpzb24SHwoLY2FwdHVyZWRfYXQYBiABKAlSCmNhcHR1cmVkQXQ=');

@$core.Deprecated('Use importMemoryRequestDescriptor instead')
const ImportMemoryRequest$json = {
  '1': 'ImportMemoryRequest',
  '2': [
    {'1': 'agent_id', '3': 1, '4': 1, '5': 9, '10': 'agentId'},
    {'1': 'snapshot_json', '3': 2, '4': 1, '5': 9, '10': 'snapshotJson'},
    {'1': 'overwrite', '3': 3, '4': 1, '5': 8, '10': 'overwrite'},
  ],
};

/// Descriptor for `ImportMemoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List importMemoryRequestDescriptor = $convert.base64Decode(
    'ChNJbXBvcnRNZW1vcnlSZXF1ZXN0EhkKCGFnZW50X2lkGAEgASgJUgdhZ2VudElkEiMKDXNuYX'
    'BzaG90X2pzb24YAiABKAlSDHNuYXBzaG90SnNvbhIcCglvdmVyd3JpdGUYAyABKAhSCW92ZXJ3'
    'cml0ZQ==');

@$core.Deprecated('Use importMemoryResponseDescriptor instead')
const ImportMemoryResponse$json = {
  '1': 'ImportMemoryResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'snapshot_id', '3': 2, '4': 1, '5': 9, '10': 'snapshotId'},
    {'1': 'agent_id', '3': 3, '4': 1, '5': 9, '10': 'agentId'},
    {'1': 'total_records', '3': 4, '4': 1, '5': 5, '10': 'totalRecords'},
    {'1': 'written_records', '3': 5, '4': 1, '5': 5, '10': 'writtenRecords'},
    {'1': 'skipped_records', '3': 6, '4': 1, '5': 5, '10': 'skippedRecords'},
    {'1': 'imported_at', '3': 7, '4': 1, '5': 9, '10': 'importedAt'},
  ],
};

/// Descriptor for `ImportMemoryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List importMemoryResponseDescriptor = $convert.base64Decode(
    'ChRJbXBvcnRNZW1vcnlSZXNwb25zZRIYCgdzdWNjZXNzGAEgASgIUgdzdWNjZXNzEh8KC3NuYX'
    'BzaG90X2lkGAIgASgJUgpzbmFwc2hvdElkEhkKCGFnZW50X2lkGAMgASgJUgdhZ2VudElkEiMK'
    'DXRvdGFsX3JlY29yZHMYBCABKAVSDHRvdGFsUmVjb3JkcxInCg93cml0dGVuX3JlY29yZHMYBS'
    'ABKAVSDndyaXR0ZW5SZWNvcmRzEicKD3NraXBwZWRfcmVjb3JkcxgGIAEoBVIOc2tpcHBlZFJl'
    'Y29yZHMSHwoLaW1wb3J0ZWRfYXQYByABKAlSCmltcG9ydGVkQXQ=');

@$core.Deprecated('Use backupMemoryRequestDescriptor instead')
const BackupMemoryRequest$json = {
  '1': 'BackupMemoryRequest',
  '2': [
    {'1': 'agent_id', '3': 1, '4': 1, '5': 9, '10': 'agentId'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'tenant_id', '3': 3, '4': 1, '5': 9, '10': 'tenantId'},
    {'1': 'destination_path', '3': 4, '4': 1, '5': 9, '10': 'destinationPath'},
  ],
};

/// Descriptor for `BackupMemoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List backupMemoryRequestDescriptor = $convert.base64Decode(
    'ChNCYWNrdXBNZW1vcnlSZXF1ZXN0EhkKCGFnZW50X2lkGAEgASgJUgdhZ2VudElkEhcKB3VzZX'
    'JfaWQYAiABKAlSBnVzZXJJZBIbCgl0ZW5hbnRfaWQYAyABKAlSCHRlbmFudElkEikKEGRlc3Rp'
    'bmF0aW9uX3BhdGgYBCABKAlSD2Rlc3RpbmF0aW9uUGF0aA==');

@$core.Deprecated('Use backupMemoryResponseDescriptor instead')
const BackupMemoryResponse$json = {
  '1': 'BackupMemoryResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'snapshot_id', '3': 2, '4': 1, '5': 9, '10': 'snapshotId'},
    {'1': 'agent_id', '3': 3, '4': 1, '5': 9, '10': 'agentId'},
    {'1': 'record_count', '3': 4, '4': 1, '5': 5, '10': 'recordCount'},
    {'1': 'file_path', '3': 5, '4': 1, '5': 9, '10': 'filePath'},
    {'1': 'captured_at', '3': 6, '4': 1, '5': 9, '10': 'capturedAt'},
  ],
};

/// Descriptor for `BackupMemoryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List backupMemoryResponseDescriptor = $convert.base64Decode(
    'ChRCYWNrdXBNZW1vcnlSZXNwb25zZRIYCgdzdWNjZXNzGAEgASgIUgdzdWNjZXNzEh8KC3NuYX'
    'BzaG90X2lkGAIgASgJUgpzbmFwc2hvdElkEhkKCGFnZW50X2lkGAMgASgJUgdhZ2VudElkEiEK'
    'DHJlY29yZF9jb3VudBgEIAEoBVILcmVjb3JkQ291bnQSGwoJZmlsZV9wYXRoGAUgASgJUghmaW'
    'xlUGF0aBIfCgtjYXB0dXJlZF9hdBgGIAEoCVIKY2FwdHVyZWRBdA==');

@$core.Deprecated('Use skillInfoDescriptor instead')
const SkillInfo$json = {
  '1': 'SkillInfo',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
    {'1': 'category', '3': 4, '4': 1, '5': 9, '10': 'category'},
    {'1': 'reasoning_mode', '3': 5, '4': 1, '5': 9, '10': 'reasoningMode'},
    {
      '1': 'mutates_workspace',
      '3': 6,
      '4': 1,
      '5': 8,
      '10': 'mutatesWorkspace'
    },
    {'1': 'allowed_tools', '3': 7, '4': 3, '5': 9, '10': 'allowedTools'},
    {'1': 'source_path', '3': 8, '4': 1, '5': 9, '10': 'sourcePath'},
    {'1': 'in_trash', '3': 9, '4': 1, '5': 8, '10': 'inTrash'},
  ],
};

/// Descriptor for `SkillInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List skillInfoDescriptor = $convert.base64Decode(
    'CglTa2lsbEluZm8SDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSIAoLZGVzY3'
    'JpcHRpb24YAyABKAlSC2Rlc2NyaXB0aW9uEhoKCGNhdGVnb3J5GAQgASgJUghjYXRlZ29yeRIl'
    'Cg5yZWFzb25pbmdfbW9kZRgFIAEoCVINcmVhc29uaW5nTW9kZRIrChFtdXRhdGVzX3dvcmtzcG'
    'FjZRgGIAEoCFIQbXV0YXRlc1dvcmtzcGFjZRIjCg1hbGxvd2VkX3Rvb2xzGAcgAygJUgxhbGxv'
    'd2VkVG9vbHMSHwoLc291cmNlX3BhdGgYCCABKAlSCnNvdXJjZVBhdGgSGQoIaW5fdHJhc2gYCS'
    'ABKAhSB2luVHJhc2g=');

@$core.Deprecated('Use skillDetailDescriptor instead')
const SkillDetail$json = {
  '1': 'SkillDetail',
  '2': [
    {
      '1': 'info',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.andalus.SkillInfo',
      '10': 'info'
    },
    {'1': 'instructions', '3': 2, '4': 1, '5': 9, '10': 'instructions'},
    {
      '1': 'references',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.andalus.SkillDetail.ReferencesEntry',
      '10': 'references'
    },
    {'1': 'scripts', '3': 4, '4': 3, '5': 9, '10': 'scripts'},
    {'1': 'raw_markdown', '3': 5, '4': 1, '5': 9, '10': 'rawMarkdown'},
  ],
  '3': [SkillDetail_ReferencesEntry$json],
};

@$core.Deprecated('Use skillDetailDescriptor instead')
const SkillDetail_ReferencesEntry$json = {
  '1': 'ReferencesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `SkillDetail`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List skillDetailDescriptor = $convert.base64Decode(
    'CgtTa2lsbERldGFpbBImCgRpbmZvGAEgASgLMhIuYW5kYWx1cy5Ta2lsbEluZm9SBGluZm8SIg'
    'oMaW5zdHJ1Y3Rpb25zGAIgASgJUgxpbnN0cnVjdGlvbnMSRAoKcmVmZXJlbmNlcxgDIAMoCzIk'
    'LmFuZGFsdXMuU2tpbGxEZXRhaWwuUmVmZXJlbmNlc0VudHJ5UgpyZWZlcmVuY2VzEhgKB3Njcm'
    'lwdHMYBCADKAlSB3NjcmlwdHMSIQoMcmF3X21hcmtkb3duGAUgASgJUgtyYXdNYXJrZG93bho9'
    'Cg9SZWZlcmVuY2VzRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAlSBXZhbH'
    'VlOgI4AQ==');

@$core.Deprecated('Use listSkillsRequestDescriptor instead')
const ListSkillsRequest$json = {
  '1': 'ListSkillsRequest',
  '2': [
    {'1': 'category', '3': 1, '4': 1, '5': 9, '10': 'category'},
    {'1': 'query', '3': 2, '4': 1, '5': 9, '10': 'query'},
    {'1': 'include_trash', '3': 3, '4': 1, '5': 8, '10': 'includeTrash'},
  ],
};

/// Descriptor for `ListSkillsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listSkillsRequestDescriptor = $convert.base64Decode(
    'ChFMaXN0U2tpbGxzUmVxdWVzdBIaCghjYXRlZ29yeRgBIAEoCVIIY2F0ZWdvcnkSFAoFcXVlcn'
    'kYAiABKAlSBXF1ZXJ5EiMKDWluY2x1ZGVfdHJhc2gYAyABKAhSDGluY2x1ZGVUcmFzaA==');

@$core.Deprecated('Use listSkillsResponseDescriptor instead')
const ListSkillsResponse$json = {
  '1': 'ListSkillsResponse',
  '2': [
    {
      '1': 'skills',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.andalus.SkillInfo',
      '10': 'skills'
    },
    {'1': 'total_count', '3': 2, '4': 1, '5': 5, '10': 'totalCount'},
  ],
};

/// Descriptor for `ListSkillsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listSkillsResponseDescriptor = $convert.base64Decode(
    'ChJMaXN0U2tpbGxzUmVzcG9uc2USKgoGc2tpbGxzGAEgAygLMhIuYW5kYWx1cy5Ta2lsbEluZm'
    '9SBnNraWxscxIfCgt0b3RhbF9jb3VudBgCIAEoBVIKdG90YWxDb3VudA==');

@$core.Deprecated('Use getSkillRequestDescriptor instead')
const GetSkillRequest$json = {
  '1': 'GetSkillRequest',
  '2': [
    {'1': 'skill_id', '3': 1, '4': 1, '5': 9, '10': 'skillId'},
  ],
};

/// Descriptor for `GetSkillRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSkillRequestDescriptor = $convert.base64Decode(
    'Cg9HZXRTa2lsbFJlcXVlc3QSGQoIc2tpbGxfaWQYASABKAlSB3NraWxsSWQ=');

@$core.Deprecated('Use getSkillResponseDescriptor instead')
const GetSkillResponse$json = {
  '1': 'GetSkillResponse',
  '2': [
    {'1': 'found', '3': 1, '4': 1, '5': 8, '10': 'found'},
    {
      '1': 'skill',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.andalus.SkillDetail',
      '10': 'skill'
    },
    {'1': 'message', '3': 3, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `GetSkillResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSkillResponseDescriptor = $convert.base64Decode(
    'ChBHZXRTa2lsbFJlc3BvbnNlEhQKBWZvdW5kGAEgASgIUgVmb3VuZBIqCgVza2lsbBgCIAEoCz'
    'IULmFuZGFsdXMuU2tpbGxEZXRhaWxSBXNraWxsEhgKB21lc3NhZ2UYAyABKAlSB21lc3NhZ2U=');

@$core.Deprecated('Use saveSkillRequestDescriptor instead')
const SaveSkillRequest$json = {
  '1': 'SaveSkillRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
    {'1': 'category', '3': 4, '4': 1, '5': 9, '10': 'category'},
    {'1': 'reasoning_mode', '3': 5, '4': 1, '5': 9, '10': 'reasoningMode'},
    {
      '1': 'mutates_workspace',
      '3': 6,
      '4': 1,
      '5': 8,
      '10': 'mutatesWorkspace'
    },
    {'1': 'allowed_tools', '3': 7, '4': 3, '5': 9, '10': 'allowedTools'},
    {'1': 'instructions', '3': 8, '4': 1, '5': 9, '10': 'instructions'},
    {
      '1': 'references',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.andalus.SaveSkillRequest.ReferencesEntry',
      '10': 'references'
    },
    {
      '1': 'scripts',
      '3': 10,
      '4': 3,
      '5': 11,
      '6': '.andalus.SaveSkillRequest.ScriptsEntry',
      '10': 'scripts'
    },
  ],
  '3': [
    SaveSkillRequest_ReferencesEntry$json,
    SaveSkillRequest_ScriptsEntry$json
  ],
};

@$core.Deprecated('Use saveSkillRequestDescriptor instead')
const SaveSkillRequest_ReferencesEntry$json = {
  '1': 'ReferencesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use saveSkillRequestDescriptor instead')
const SaveSkillRequest_ScriptsEntry$json = {
  '1': 'ScriptsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `SaveSkillRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List saveSkillRequestDescriptor = $convert.base64Decode(
    'ChBTYXZlU2tpbGxSZXF1ZXN0Eg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1lEi'
    'AKC2Rlc2NyaXB0aW9uGAMgASgJUgtkZXNjcmlwdGlvbhIaCghjYXRlZ29yeRgEIAEoCVIIY2F0'
    'ZWdvcnkSJQoOcmVhc29uaW5nX21vZGUYBSABKAlSDXJlYXNvbmluZ01vZGUSKwoRbXV0YXRlc1'
    '93b3Jrc3BhY2UYBiABKAhSEG11dGF0ZXNXb3Jrc3BhY2USIwoNYWxsb3dlZF90b29scxgHIAMo'
    'CVIMYWxsb3dlZFRvb2xzEiIKDGluc3RydWN0aW9ucxgIIAEoCVIMaW5zdHJ1Y3Rpb25zEkkKCn'
    'JlZmVyZW5jZXMYCSADKAsyKS5hbmRhbHVzLlNhdmVTa2lsbFJlcXVlc3QuUmVmZXJlbmNlc0Vu'
    'dHJ5UgpyZWZlcmVuY2VzEkAKB3NjcmlwdHMYCiADKAsyJi5hbmRhbHVzLlNhdmVTa2lsbFJlcX'
    'Vlc3QuU2NyaXB0c0VudHJ5UgdzY3JpcHRzGj0KD1JlZmVyZW5jZXNFbnRyeRIQCgNrZXkYASAB'
    'KAlSA2tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgBGjoKDFNjcmlwdHNFbnRyeRIQCgNrZX'
    'kYASABKAlSA2tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgB');

@$core.Deprecated('Use saveSkillResponseDescriptor instead')
const SaveSkillResponse$json = {
  '1': 'SaveSkillResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'skill_id', '3': 2, '4': 1, '5': 9, '10': 'skillId'},
    {'1': 'message', '3': 3, '4': 1, '5': 9, '10': 'message'},
    {'1': 'source_path', '3': 4, '4': 1, '5': 9, '10': 'sourcePath'},
  ],
};

/// Descriptor for `SaveSkillResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List saveSkillResponseDescriptor = $convert.base64Decode(
    'ChFTYXZlU2tpbGxSZXNwb25zZRIYCgdzdWNjZXNzGAEgASgIUgdzdWNjZXNzEhkKCHNraWxsX2'
    'lkGAIgASgJUgdza2lsbElkEhgKB21lc3NhZ2UYAyABKAlSB21lc3NhZ2USHwoLc291cmNlX3Bh'
    'dGgYBCABKAlSCnNvdXJjZVBhdGg=');

@$core.Deprecated('Use deleteSkillRequestDescriptor instead')
const DeleteSkillRequest$json = {
  '1': 'DeleteSkillRequest',
  '2': [
    {'1': 'skill_id', '3': 1, '4': 1, '5': 9, '10': 'skillId'},
    {'1': 'hard_delete', '3': 2, '4': 1, '5': 8, '10': 'hardDelete'},
  ],
};

/// Descriptor for `DeleteSkillRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteSkillRequestDescriptor = $convert.base64Decode(
    'ChJEZWxldGVTa2lsbFJlcXVlc3QSGQoIc2tpbGxfaWQYASABKAlSB3NraWxsSWQSHwoLaGFyZF'
    '9kZWxldGUYAiABKAhSCmhhcmREZWxldGU=');

@$core.Deprecated('Use deleteSkillResponseDescriptor instead')
const DeleteSkillResponse$json = {
  '1': 'DeleteSkillResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'skill_id', '3': 2, '4': 1, '5': 9, '10': 'skillId'},
    {'1': 'moved_to_trash', '3': 3, '4': 1, '5': 8, '10': 'movedToTrash'},
    {'1': 'trash_path', '3': 4, '4': 1, '5': 9, '10': 'trashPath'},
    {'1': 'message', '3': 5, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `DeleteSkillResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteSkillResponseDescriptor = $convert.base64Decode(
    'ChNEZWxldGVTa2lsbFJlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3MSGQoIc2tpbG'
    'xfaWQYAiABKAlSB3NraWxsSWQSJAoObW92ZWRfdG9fdHJhc2gYAyABKAhSDG1vdmVkVG9UcmFz'
    'aBIdCgp0cmFzaF9wYXRoGAQgASgJUgl0cmFzaFBhdGgSGAoHbWVzc2FnZRgFIAEoCVIHbWVzc2'
    'FnZQ==');

@$core.Deprecated('Use restoreSkillRequestDescriptor instead')
const RestoreSkillRequest$json = {
  '1': 'RestoreSkillRequest',
  '2': [
    {'1': 'skill_id', '3': 1, '4': 1, '5': 9, '10': 'skillId'},
  ],
};

/// Descriptor for `RestoreSkillRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List restoreSkillRequestDescriptor =
    $convert.base64Decode(
        'ChNSZXN0b3JlU2tpbGxSZXF1ZXN0EhkKCHNraWxsX2lkGAEgASgJUgdza2lsbElk');

@$core.Deprecated('Use restoreSkillResponseDescriptor instead')
const RestoreSkillResponse$json = {
  '1': 'RestoreSkillResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'skill_id', '3': 2, '4': 1, '5': 9, '10': 'skillId'},
    {'1': 'restored_path', '3': 3, '4': 1, '5': 9, '10': 'restoredPath'},
    {'1': 'message', '3': 4, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `RestoreSkillResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List restoreSkillResponseDescriptor = $convert.base64Decode(
    'ChRSZXN0b3JlU2tpbGxSZXNwb25zZRIYCgdzdWNjZXNzGAEgASgIUgdzdWNjZXNzEhkKCHNraW'
    'xsX2lkGAIgASgJUgdza2lsbElkEiMKDXJlc3RvcmVkX3BhdGgYAyABKAlSDHJlc3RvcmVkUGF0'
    'aBIYCgdtZXNzYWdlGAQgASgJUgdtZXNzYWdl');

@$core.Deprecated('Use reloadSkillsResponseDescriptor instead')
const ReloadSkillsResponse$json = {
  '1': 'ReloadSkillsResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'reloaded_count', '3': 2, '4': 1, '5': 5, '10': 'reloadedCount'},
    {'1': 'message', '3': 3, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `ReloadSkillsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reloadSkillsResponseDescriptor = $convert.base64Decode(
    'ChRSZWxvYWRTa2lsbHNSZXNwb25zZRIYCgdzdWNjZXNzGAEgASgIUgdzdWNjZXNzEiUKDnJlbG'
    '9hZGVkX2NvdW50GAIgASgFUg1yZWxvYWRlZENvdW50EhgKB21lc3NhZ2UYAyABKAlSB21lc3Nh'
    'Z2U=');
