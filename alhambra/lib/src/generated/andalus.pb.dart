// This is a generated file - do not edit.
//
// Generated from andalus.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class Project extends $pb.GeneratedMessage {
  factory Project({
    $core.String? id,
    $core.String? tenantId,
    $core.String? name,
    $core.String? description,
    $core.String? basePath,
    $core.String? metadata,
    $core.bool? archived,
  }) {
    final result = Project._();
    if (id != null) result.id = id;
    if (tenantId != null) result.tenantId = tenantId;
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (basePath != null) result.basePath = basePath;
    if (metadata != null) result.metadata = metadata;
    if (archived != null) result.archived = archived;
    return result;
  }

  Project._();

  factory Project.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Project()..mergeFromBuffer(data, registry);
  factory Project.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Project()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Project',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: Project.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'tenantId')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aOS(4, _omitFieldNames ? '' : 'description')
    ..aOS(5, _omitFieldNames ? '' : 'basePath')
    ..aOS(6, _omitFieldNames ? '' : 'metadata')
    ..aOB(7, _omitFieldNames ? '' : 'archived')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Project clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Project copyWith(void Function(Project) updates) =>
      super.copyWith((message) => updates(message as Project)) as Project;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Project() / Project.new instead')
  static Project create() => Project._();
  static $pb.GeneratedMessage $_createMessage() => Project._();
  @$core.override
  Project createEmptyInstance() => Project._();
  @$core.pragma('dart2js:noInline')
  static Project getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Project>(Project.$_createMessage);
  static Project? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get tenantId => $_getSZ(1);
  @$pb.TagNumber(2)
  set tenantId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTenantId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTenantId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get description => $_getSZ(3);
  @$pb.TagNumber(4)
  set description($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDescription() => $_has(3);
  @$pb.TagNumber(4)
  void clearDescription() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get basePath => $_getSZ(4);
  @$pb.TagNumber(5)
  set basePath($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBasePath() => $_has(4);
  @$pb.TagNumber(5)
  void clearBasePath() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get metadata => $_getSZ(5);
  @$pb.TagNumber(6)
  set metadata($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMetadata() => $_has(5);
  @$pb.TagNumber(6)
  void clearMetadata() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get archived => $_getBF(6);
  @$pb.TagNumber(7)
  set archived($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasArchived() => $_has(6);
  @$pb.TagNumber(7)
  void clearArchived() => $_clearField(7);
}

class Session extends $pb.GeneratedMessage {
  factory Session({
    $core.String? id,
    $core.String? projectId,
    $core.String? tenantId,
    $core.String? name,
    $core.String? status,
    $core.String? metadata,
  }) {
    final result = Session._();
    if (id != null) result.id = id;
    if (projectId != null) result.projectId = projectId;
    if (tenantId != null) result.tenantId = tenantId;
    if (name != null) result.name = name;
    if (status != null) result.status = status;
    if (metadata != null) result.metadata = metadata;
    return result;
  }

  Session._();

  factory Session.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Session()..mergeFromBuffer(data, registry);
  factory Session.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Session()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Session',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: Session.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'projectId')
    ..aOS(3, _omitFieldNames ? '' : 'tenantId')
    ..aOS(4, _omitFieldNames ? '' : 'name')
    ..aOS(5, _omitFieldNames ? '' : 'status')
    ..aOS(6, _omitFieldNames ? '' : 'metadata')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Session clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Session copyWith(void Function(Session) updates) =>
      super.copyWith((message) => updates(message as Session)) as Session;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Session() / Session.new instead')
  static Session create() => Session._();
  static $pb.GeneratedMessage $_createMessage() => Session._();
  @$core.override
  Session createEmptyInstance() => Session._();
  @$core.pragma('dart2js:noInline')
  static Session getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Session>(Session.$_createMessage);
  static Session? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get projectId => $_getSZ(1);
  @$pb.TagNumber(2)
  set projectId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProjectId() => $_has(1);
  @$pb.TagNumber(2)
  void clearProjectId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get tenantId => $_getSZ(2);
  @$pb.TagNumber(3)
  set tenantId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTenantId() => $_has(2);
  @$pb.TagNumber(3)
  void clearTenantId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get name => $_getSZ(3);
  @$pb.TagNumber(4)
  set name($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasName() => $_has(3);
  @$pb.TagNumber(4)
  void clearName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get status => $_getSZ(4);
  @$pb.TagNumber(5)
  set status($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasStatus() => $_has(4);
  @$pb.TagNumber(5)
  void clearStatus() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get metadata => $_getSZ(5);
  @$pb.TagNumber(6)
  set metadata($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMetadata() => $_has(5);
  @$pb.TagNumber(6)
  void clearMetadata() => $_clearField(6);
}

class ApiKey extends $pb.GeneratedMessage {
  factory ApiKey({
    $core.String? id,
    $core.String? tenantId,
    $core.String? name,
    $core.String? keyPrefix,
    $core.bool? enabled,
  }) {
    final result = ApiKey._();
    if (id != null) result.id = id;
    if (tenantId != null) result.tenantId = tenantId;
    if (name != null) result.name = name;
    if (keyPrefix != null) result.keyPrefix = keyPrefix;
    if (enabled != null) result.enabled = enabled;
    return result;
  }

  ApiKey._();

  factory ApiKey.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ApiKey()..mergeFromBuffer(data, registry);
  factory ApiKey.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ApiKey()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ApiKey',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ApiKey.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'tenantId')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aOS(4, _omitFieldNames ? '' : 'keyPrefix')
    ..aOB(5, _omitFieldNames ? '' : 'enabled')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ApiKey clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ApiKey copyWith(void Function(ApiKey) updates) =>
      super.copyWith((message) => updates(message as ApiKey)) as ApiKey;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ApiKey() / ApiKey.new instead')
  static ApiKey create() => ApiKey._();
  static $pb.GeneratedMessage $_createMessage() => ApiKey._();
  @$core.override
  ApiKey createEmptyInstance() => ApiKey._();
  @$core.pragma('dart2js:noInline')
  static ApiKey getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ApiKey>(ApiKey.$_createMessage);
  static ApiKey? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get tenantId => $_getSZ(1);
  @$pb.TagNumber(2)
  set tenantId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTenantId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTenantId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get keyPrefix => $_getSZ(3);
  @$pb.TagNumber(4)
  set keyPrefix($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasKeyPrefix() => $_has(3);
  @$pb.TagNumber(4)
  void clearKeyPrefix() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get enabled => $_getBF(4);
  @$pb.TagNumber(5)
  set enabled($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEnabled() => $_has(4);
  @$pb.TagNumber(5)
  void clearEnabled() => $_clearField(5);
}

class Empty extends $pb.GeneratedMessage {
  factory Empty() => Empty._();

  Empty._();

  factory Empty.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Empty()..mergeFromBuffer(data, registry);
  factory Empty.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Empty()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Empty',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: Empty.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Empty clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Empty copyWith(void Function(Empty) updates) =>
      super.copyWith((message) => updates(message as Empty)) as Empty;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Empty() / Empty.new instead')
  static Empty create() => Empty._();
  static $pb.GeneratedMessage $_createMessage() => Empty._();
  @$core.override
  Empty createEmptyInstance() => Empty._();
  @$core.pragma('dart2js:noInline')
  static Empty getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Empty>(Empty.$_createMessage);
  static Empty? _defaultInstance;
}

class CreateProjectRequest extends $pb.GeneratedMessage {
  factory CreateProjectRequest({
    $core.String? name,
    $core.String? description,
    $core.String? basePath,
  }) {
    final result = CreateProjectRequest._();
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (basePath != null) result.basePath = basePath;
    return result;
  }

  CreateProjectRequest._();

  factory CreateProjectRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateProjectRequest()..mergeFromBuffer(data, registry);
  factory CreateProjectRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateProjectRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateProjectRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: CreateProjectRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'description')
    ..aOS(3, _omitFieldNames ? '' : 'basePath')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateProjectRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateProjectRequest copyWith(void Function(CreateProjectRequest) updates) =>
      super.copyWith((message) => updates(message as CreateProjectRequest))
          as CreateProjectRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use CreateProjectRequest() / CreateProjectRequest.new instead')
  static CreateProjectRequest create() => CreateProjectRequest._();
  static $pb.GeneratedMessage $_createMessage() => CreateProjectRequest._();
  @$core.override
  CreateProjectRequest createEmptyInstance() => CreateProjectRequest._();
  @$core.pragma('dart2js:noInline')
  static CreateProjectRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateProjectRequest>(
          CreateProjectRequest.$_createMessage);
  static CreateProjectRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get description => $_getSZ(1);
  @$pb.TagNumber(2)
  set description($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDescription() => $_has(1);
  @$pb.TagNumber(2)
  void clearDescription() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get basePath => $_getSZ(2);
  @$pb.TagNumber(3)
  set basePath($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBasePath() => $_has(2);
  @$pb.TagNumber(3)
  void clearBasePath() => $_clearField(3);
}

class ListProjectsRequest extends $pb.GeneratedMessage {
  factory ListProjectsRequest({
    $core.bool? includeArchived,
  }) {
    final result = ListProjectsRequest._();
    if (includeArchived != null) result.includeArchived = includeArchived;
    return result;
  }

  ListProjectsRequest._();

  factory ListProjectsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListProjectsRequest()..mergeFromBuffer(data, registry);
  factory ListProjectsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListProjectsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListProjectsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ListProjectsRequest.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'includeArchived')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListProjectsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListProjectsRequest copyWith(void Function(ListProjectsRequest) updates) =>
      super.copyWith((message) => updates(message as ListProjectsRequest))
          as ListProjectsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use ListProjectsRequest() / ListProjectsRequest.new instead')
  static ListProjectsRequest create() => ListProjectsRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListProjectsRequest._();
  @$core.override
  ListProjectsRequest createEmptyInstance() => ListProjectsRequest._();
  @$core.pragma('dart2js:noInline')
  static ListProjectsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListProjectsRequest>(
          ListProjectsRequest.$_createMessage);
  static ListProjectsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get includeArchived => $_getBF(0);
  @$pb.TagNumber(1)
  set includeArchived($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIncludeArchived() => $_has(0);
  @$pb.TagNumber(1)
  void clearIncludeArchived() => $_clearField(1);
}

class ListProjectsResponse extends $pb.GeneratedMessage {
  factory ListProjectsResponse({
    $core.Iterable<Project>? projects,
  }) {
    final result = ListProjectsResponse._();
    if (projects != null) result.projects.addAll(projects);
    return result;
  }

  ListProjectsResponse._();

  factory ListProjectsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListProjectsResponse()..mergeFromBuffer(data, registry);
  factory ListProjectsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListProjectsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListProjectsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ListProjectsResponse.$_createMessage)
    ..pPM<Project>(1, _omitFieldNames ? '' : 'projects',
        subBuilder: Project.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListProjectsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListProjectsResponse copyWith(void Function(ListProjectsResponse) updates) =>
      super.copyWith((message) => updates(message as ListProjectsResponse))
          as ListProjectsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListProjectsResponse() / ListProjectsResponse.new instead')
  static ListProjectsResponse create() => ListProjectsResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListProjectsResponse._();
  @$core.override
  ListProjectsResponse createEmptyInstance() => ListProjectsResponse._();
  @$core.pragma('dart2js:noInline')
  static ListProjectsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListProjectsResponse>(
          ListProjectsResponse.$_createMessage);
  static ListProjectsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Project> get projects => $_getList(0);
}

class CreateSessionRequest extends $pb.GeneratedMessage {
  factory CreateSessionRequest({
    $core.String? projectId,
    $core.String? name,
  }) {
    final result = CreateSessionRequest._();
    if (projectId != null) result.projectId = projectId;
    if (name != null) result.name = name;
    return result;
  }

  CreateSessionRequest._();

  factory CreateSessionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateSessionRequest()..mergeFromBuffer(data, registry);
  factory CreateSessionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateSessionRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateSessionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: CreateSessionRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'projectId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateSessionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateSessionRequest copyWith(void Function(CreateSessionRequest) updates) =>
      super.copyWith((message) => updates(message as CreateSessionRequest))
          as CreateSessionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use CreateSessionRequest() / CreateSessionRequest.new instead')
  static CreateSessionRequest create() => CreateSessionRequest._();
  static $pb.GeneratedMessage $_createMessage() => CreateSessionRequest._();
  @$core.override
  CreateSessionRequest createEmptyInstance() => CreateSessionRequest._();
  @$core.pragma('dart2js:noInline')
  static CreateSessionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateSessionRequest>(
          CreateSessionRequest.$_createMessage);
  static CreateSessionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get projectId => $_getSZ(0);
  @$pb.TagNumber(1)
  set projectId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProjectId() => $_has(0);
  @$pb.TagNumber(1)
  void clearProjectId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);
}

class ListSessionsRequest extends $pb.GeneratedMessage {
  factory ListSessionsRequest({
    $core.String? projectId,
  }) {
    final result = ListSessionsRequest._();
    if (projectId != null) result.projectId = projectId;
    return result;
  }

  ListSessionsRequest._();

  factory ListSessionsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListSessionsRequest()..mergeFromBuffer(data, registry);
  factory ListSessionsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListSessionsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListSessionsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ListSessionsRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'projectId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSessionsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSessionsRequest copyWith(void Function(ListSessionsRequest) updates) =>
      super.copyWith((message) => updates(message as ListSessionsRequest))
          as ListSessionsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use ListSessionsRequest() / ListSessionsRequest.new instead')
  static ListSessionsRequest create() => ListSessionsRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListSessionsRequest._();
  @$core.override
  ListSessionsRequest createEmptyInstance() => ListSessionsRequest._();
  @$core.pragma('dart2js:noInline')
  static ListSessionsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListSessionsRequest>(
          ListSessionsRequest.$_createMessage);
  static ListSessionsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get projectId => $_getSZ(0);
  @$pb.TagNumber(1)
  set projectId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProjectId() => $_has(0);
  @$pb.TagNumber(1)
  void clearProjectId() => $_clearField(1);
}

class ListSessionsResponse extends $pb.GeneratedMessage {
  factory ListSessionsResponse({
    $core.Iterable<Session>? sessions,
  }) {
    final result = ListSessionsResponse._();
    if (sessions != null) result.sessions.addAll(sessions);
    return result;
  }

  ListSessionsResponse._();

  factory ListSessionsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListSessionsResponse()..mergeFromBuffer(data, registry);
  factory ListSessionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListSessionsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListSessionsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ListSessionsResponse.$_createMessage)
    ..pPM<Session>(1, _omitFieldNames ? '' : 'sessions',
        subBuilder: Session.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSessionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSessionsResponse copyWith(void Function(ListSessionsResponse) updates) =>
      super.copyWith((message) => updates(message as ListSessionsResponse))
          as ListSessionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListSessionsResponse() / ListSessionsResponse.new instead')
  static ListSessionsResponse create() => ListSessionsResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListSessionsResponse._();
  @$core.override
  ListSessionsResponse createEmptyInstance() => ListSessionsResponse._();
  @$core.pragma('dart2js:noInline')
  static ListSessionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListSessionsResponse>(
          ListSessionsResponse.$_createMessage);
  static ListSessionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Session> get sessions => $_getList(0);
}

class ForkSessionRequest extends $pb.GeneratedMessage {
  factory ForkSessionRequest({
    $core.String? sessionId,
    $core.String? messageId,
  }) {
    final result = ForkSessionRequest._();
    if (sessionId != null) result.sessionId = sessionId;
    if (messageId != null) result.messageId = messageId;
    return result;
  }

  ForkSessionRequest._();

  factory ForkSessionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ForkSessionRequest()..mergeFromBuffer(data, registry);
  factory ForkSessionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ForkSessionRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ForkSessionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ForkSessionRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOS(2, _omitFieldNames ? '' : 'messageId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ForkSessionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ForkSessionRequest copyWith(void Function(ForkSessionRequest) updates) =>
      super.copyWith((message) => updates(message as ForkSessionRequest))
          as ForkSessionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ForkSessionRequest() / ForkSessionRequest.new instead')
  static ForkSessionRequest create() => ForkSessionRequest._();
  static $pb.GeneratedMessage $_createMessage() => ForkSessionRequest._();
  @$core.override
  ForkSessionRequest createEmptyInstance() => ForkSessionRequest._();
  @$core.pragma('dart2js:noInline')
  static ForkSessionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ForkSessionRequest>(
          ForkSessionRequest.$_createMessage);
  static ForkSessionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get messageId => $_getSZ(1);
  @$pb.TagNumber(2)
  set messageId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessageId() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessageId() => $_clearField(2);
}

class DeleteSessionRequest extends $pb.GeneratedMessage {
  factory DeleteSessionRequest({
    $core.String? sessionId,
  }) {
    final result = DeleteSessionRequest._();
    if (sessionId != null) result.sessionId = sessionId;
    return result;
  }

  DeleteSessionRequest._();

  factory DeleteSessionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteSessionRequest()..mergeFromBuffer(data, registry);
  factory DeleteSessionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteSessionRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteSessionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: DeleteSessionRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteSessionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteSessionRequest copyWith(void Function(DeleteSessionRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteSessionRequest))
          as DeleteSessionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use DeleteSessionRequest() / DeleteSessionRequest.new instead')
  static DeleteSessionRequest create() => DeleteSessionRequest._();
  static $pb.GeneratedMessage $_createMessage() => DeleteSessionRequest._();
  @$core.override
  DeleteSessionRequest createEmptyInstance() => DeleteSessionRequest._();
  @$core.pragma('dart2js:noInline')
  static DeleteSessionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteSessionRequest>(
          DeleteSessionRequest.$_createMessage);
  static DeleteSessionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);
}

class DeleteSessionResponse extends $pb.GeneratedMessage {
  factory DeleteSessionResponse({
    $core.bool? success,
  }) {
    final result = DeleteSessionResponse._();
    if (success != null) result.success = success;
    return result;
  }

  DeleteSessionResponse._();

  factory DeleteSessionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteSessionResponse()..mergeFromBuffer(data, registry);
  factory DeleteSessionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteSessionResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteSessionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: DeleteSessionResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteSessionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteSessionResponse copyWith(
          void Function(DeleteSessionResponse) updates) =>
      super.copyWith((message) => updates(message as DeleteSessionResponse))
          as DeleteSessionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use DeleteSessionResponse() / DeleteSessionResponse.new instead')
  static DeleteSessionResponse create() => DeleteSessionResponse._();
  static $pb.GeneratedMessage $_createMessage() => DeleteSessionResponse._();
  @$core.override
  DeleteSessionResponse createEmptyInstance() => DeleteSessionResponse._();
  @$core.pragma('dart2js:noInline')
  static DeleteSessionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteSessionResponse>(
          DeleteSessionResponse.$_createMessage);
  static DeleteSessionResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);
}

class IndexWorkspaceRequest extends $pb.GeneratedMessage {
  factory IndexWorkspaceRequest({
    $core.String? projectId,
    $core.String? workspacePath,
  }) {
    final result = IndexWorkspaceRequest._();
    if (projectId != null) result.projectId = projectId;
    if (workspacePath != null) result.workspacePath = workspacePath;
    return result;
  }

  IndexWorkspaceRequest._();

  factory IndexWorkspaceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      IndexWorkspaceRequest()..mergeFromBuffer(data, registry);
  factory IndexWorkspaceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      IndexWorkspaceRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IndexWorkspaceRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: IndexWorkspaceRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'projectId')
    ..aOS(2, _omitFieldNames ? '' : 'workspacePath')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IndexWorkspaceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IndexWorkspaceRequest copyWith(
          void Function(IndexWorkspaceRequest) updates) =>
      super.copyWith((message) => updates(message as IndexWorkspaceRequest))
          as IndexWorkspaceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use IndexWorkspaceRequest() / IndexWorkspaceRequest.new instead')
  static IndexWorkspaceRequest create() => IndexWorkspaceRequest._();
  static $pb.GeneratedMessage $_createMessage() => IndexWorkspaceRequest._();
  @$core.override
  IndexWorkspaceRequest createEmptyInstance() => IndexWorkspaceRequest._();
  @$core.pragma('dart2js:noInline')
  static IndexWorkspaceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<IndexWorkspaceRequest>(
          IndexWorkspaceRequest.$_createMessage);
  static IndexWorkspaceRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get projectId => $_getSZ(0);
  @$pb.TagNumber(1)
  set projectId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProjectId() => $_has(0);
  @$pb.TagNumber(1)
  void clearProjectId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get workspacePath => $_getSZ(1);
  @$pb.TagNumber(2)
  set workspacePath($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWorkspacePath() => $_has(1);
  @$pb.TagNumber(2)
  void clearWorkspacePath() => $_clearField(2);
}

class IndexWorkspaceResponse extends $pb.GeneratedMessage {
  factory IndexWorkspaceResponse({
    $core.bool? success,
    $core.int? filesIndexed,
    $core.int? symbolsIndexed,
    $core.int? dependenciesIndexed,
    $fixnum.Int64? durationMs,
    $core.String? repositoryHash,
    $core.String? error,
  }) {
    final result = IndexWorkspaceResponse._();
    if (success != null) result.success = success;
    if (filesIndexed != null) result.filesIndexed = filesIndexed;
    if (symbolsIndexed != null) result.symbolsIndexed = symbolsIndexed;
    if (dependenciesIndexed != null)
      result.dependenciesIndexed = dependenciesIndexed;
    if (durationMs != null) result.durationMs = durationMs;
    if (repositoryHash != null) result.repositoryHash = repositoryHash;
    if (error != null) result.error = error;
    return result;
  }

  IndexWorkspaceResponse._();

  factory IndexWorkspaceResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      IndexWorkspaceResponse()..mergeFromBuffer(data, registry);
  factory IndexWorkspaceResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      IndexWorkspaceResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IndexWorkspaceResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: IndexWorkspaceResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aI(2, _omitFieldNames ? '' : 'filesIndexed')
    ..aI(3, _omitFieldNames ? '' : 'symbolsIndexed')
    ..aI(4, _omitFieldNames ? '' : 'dependenciesIndexed')
    ..aInt64(5, _omitFieldNames ? '' : 'durationMs')
    ..aOS(6, _omitFieldNames ? '' : 'repositoryHash')
    ..aOS(7, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IndexWorkspaceResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IndexWorkspaceResponse copyWith(
          void Function(IndexWorkspaceResponse) updates) =>
      super.copyWith((message) => updates(message as IndexWorkspaceResponse))
          as IndexWorkspaceResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use IndexWorkspaceResponse() / IndexWorkspaceResponse.new instead')
  static IndexWorkspaceResponse create() => IndexWorkspaceResponse._();
  static $pb.GeneratedMessage $_createMessage() => IndexWorkspaceResponse._();
  @$core.override
  IndexWorkspaceResponse createEmptyInstance() => IndexWorkspaceResponse._();
  @$core.pragma('dart2js:noInline')
  static IndexWorkspaceResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<IndexWorkspaceResponse>(
          IndexWorkspaceResponse.$_createMessage);
  static IndexWorkspaceResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get filesIndexed => $_getIZ(1);
  @$pb.TagNumber(2)
  set filesIndexed($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFilesIndexed() => $_has(1);
  @$pb.TagNumber(2)
  void clearFilesIndexed() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get symbolsIndexed => $_getIZ(2);
  @$pb.TagNumber(3)
  set symbolsIndexed($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSymbolsIndexed() => $_has(2);
  @$pb.TagNumber(3)
  void clearSymbolsIndexed() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get dependenciesIndexed => $_getIZ(3);
  @$pb.TagNumber(4)
  set dependenciesIndexed($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDependenciesIndexed() => $_has(3);
  @$pb.TagNumber(4)
  void clearDependenciesIndexed() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get durationMs => $_getI64(4);
  @$pb.TagNumber(5)
  set durationMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDurationMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearDurationMs() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get repositoryHash => $_getSZ(5);
  @$pb.TagNumber(6)
  set repositoryHash($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasRepositoryHash() => $_has(5);
  @$pb.TagNumber(6)
  void clearRepositoryHash() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get error => $_getSZ(6);
  @$pb.TagNumber(7)
  set error($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasError() => $_has(6);
  @$pb.TagNumber(7)
  void clearError() => $_clearField(7);
}

class UpdateSessionStatusRequest extends $pb.GeneratedMessage {
  factory UpdateSessionStatusRequest({
    $core.String? sessionId,
    $core.String? status,
  }) {
    final result = UpdateSessionStatusRequest._();
    if (sessionId != null) result.sessionId = sessionId;
    if (status != null) result.status = status;
    return result;
  }

  UpdateSessionStatusRequest._();

  factory UpdateSessionStatusRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpdateSessionStatusRequest()..mergeFromBuffer(data, registry);
  factory UpdateSessionStatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpdateSessionStatusRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateSessionStatusRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: UpdateSessionStatusRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOS(2, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateSessionStatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateSessionStatusRequest copyWith(
          void Function(UpdateSessionStatusRequest) updates) =>
      super.copyWith(
              (message) => updates(message as UpdateSessionStatusRequest))
          as UpdateSessionStatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use UpdateSessionStatusRequest() / UpdateSessionStatusRequest.new instead')
  static UpdateSessionStatusRequest create() => UpdateSessionStatusRequest._();
  static $pb.GeneratedMessage $_createMessage() =>
      UpdateSessionStatusRequest._();
  @$core.override
  UpdateSessionStatusRequest createEmptyInstance() =>
      UpdateSessionStatusRequest._();
  @$core.pragma('dart2js:noInline')
  static UpdateSessionStatusRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateSessionStatusRequest>(
          UpdateSessionStatusRequest.$_createMessage);
  static UpdateSessionStatusRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get status => $_getSZ(1);
  @$pb.TagNumber(2)
  set status($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);
}

class Task extends $pb.GeneratedMessage {
  factory Task({
    $core.String? id,
    $core.String? sessionId,
    $core.String? tenantId,
    $core.String? taskType,
    $core.String? payload,
    $core.String? status,
    $core.int? priority,
    $core.int? attempts,
    $core.int? maxAttempts,
    $core.String? error,
    $core.String? scheduledAt,
    $core.String? startedAt,
    $core.String? completedAt,
    $core.String? createdAt,
  }) {
    final result = Task._();
    if (id != null) result.id = id;
    if (sessionId != null) result.sessionId = sessionId;
    if (tenantId != null) result.tenantId = tenantId;
    if (taskType != null) result.taskType = taskType;
    if (payload != null) result.payload = payload;
    if (status != null) result.status = status;
    if (priority != null) result.priority = priority;
    if (attempts != null) result.attempts = attempts;
    if (maxAttempts != null) result.maxAttempts = maxAttempts;
    if (error != null) result.error = error;
    if (scheduledAt != null) result.scheduledAt = scheduledAt;
    if (startedAt != null) result.startedAt = startedAt;
    if (completedAt != null) result.completedAt = completedAt;
    if (createdAt != null) result.createdAt = createdAt;
    return result;
  }

  Task._();

  factory Task.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Task()..mergeFromBuffer(data, registry);
  factory Task.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Task()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Task',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: Task.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..aOS(3, _omitFieldNames ? '' : 'tenantId')
    ..aOS(4, _omitFieldNames ? '' : 'taskType')
    ..aOS(5, _omitFieldNames ? '' : 'payload')
    ..aOS(6, _omitFieldNames ? '' : 'status')
    ..aI(7, _omitFieldNames ? '' : 'priority')
    ..aI(8, _omitFieldNames ? '' : 'attempts')
    ..aI(9, _omitFieldNames ? '' : 'maxAttempts')
    ..aOS(10, _omitFieldNames ? '' : 'error')
    ..aOS(11, _omitFieldNames ? '' : 'scheduledAt')
    ..aOS(12, _omitFieldNames ? '' : 'startedAt')
    ..aOS(13, _omitFieldNames ? '' : 'completedAt')
    ..aOS(14, _omitFieldNames ? '' : 'createdAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Task clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Task copyWith(void Function(Task) updates) =>
      super.copyWith((message) => updates(message as Task)) as Task;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Task() / Task.new instead')
  static Task create() => Task._();
  static $pb.GeneratedMessage $_createMessage() => Task._();
  @$core.override
  Task createEmptyInstance() => Task._();
  @$core.pragma('dart2js:noInline')
  static Task getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Task>(Task.$_createMessage);
  static Task? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get tenantId => $_getSZ(2);
  @$pb.TagNumber(3)
  set tenantId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTenantId() => $_has(2);
  @$pb.TagNumber(3)
  void clearTenantId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get taskType => $_getSZ(3);
  @$pb.TagNumber(4)
  set taskType($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTaskType() => $_has(3);
  @$pb.TagNumber(4)
  void clearTaskType() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get payload => $_getSZ(4);
  @$pb.TagNumber(5)
  set payload($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPayload() => $_has(4);
  @$pb.TagNumber(5)
  void clearPayload() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get status => $_getSZ(5);
  @$pb.TagNumber(6)
  set status($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStatus() => $_has(5);
  @$pb.TagNumber(6)
  void clearStatus() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get priority => $_getIZ(6);
  @$pb.TagNumber(7)
  set priority($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPriority() => $_has(6);
  @$pb.TagNumber(7)
  void clearPriority() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get attempts => $_getIZ(7);
  @$pb.TagNumber(8)
  set attempts($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasAttempts() => $_has(7);
  @$pb.TagNumber(8)
  void clearAttempts() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get maxAttempts => $_getIZ(8);
  @$pb.TagNumber(9)
  set maxAttempts($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasMaxAttempts() => $_has(8);
  @$pb.TagNumber(9)
  void clearMaxAttempts() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get error => $_getSZ(9);
  @$pb.TagNumber(10)
  set error($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasError() => $_has(9);
  @$pb.TagNumber(10)
  void clearError() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get scheduledAt => $_getSZ(10);
  @$pb.TagNumber(11)
  set scheduledAt($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasScheduledAt() => $_has(10);
  @$pb.TagNumber(11)
  void clearScheduledAt() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get startedAt => $_getSZ(11);
  @$pb.TagNumber(12)
  set startedAt($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasStartedAt() => $_has(11);
  @$pb.TagNumber(12)
  void clearStartedAt() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get completedAt => $_getSZ(12);
  @$pb.TagNumber(13)
  set completedAt($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasCompletedAt() => $_has(12);
  @$pb.TagNumber(13)
  void clearCompletedAt() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.String get createdAt => $_getSZ(13);
  @$pb.TagNumber(14)
  set createdAt($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasCreatedAt() => $_has(13);
  @$pb.TagNumber(14)
  void clearCreatedAt() => $_clearField(14);
}

class CreateTaskRequest extends $pb.GeneratedMessage {
  factory CreateTaskRequest({
    $core.String? sessionId,
    $core.String? taskType,
    $core.String? payload,
    $core.int? priority,
  }) {
    final result = CreateTaskRequest._();
    if (sessionId != null) result.sessionId = sessionId;
    if (taskType != null) result.taskType = taskType;
    if (payload != null) result.payload = payload;
    if (priority != null) result.priority = priority;
    return result;
  }

  CreateTaskRequest._();

  factory CreateTaskRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateTaskRequest()..mergeFromBuffer(data, registry);
  factory CreateTaskRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateTaskRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateTaskRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: CreateTaskRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOS(2, _omitFieldNames ? '' : 'taskType')
    ..aOS(3, _omitFieldNames ? '' : 'payload')
    ..aI(4, _omitFieldNames ? '' : 'priority')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateTaskRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateTaskRequest copyWith(void Function(CreateTaskRequest) updates) =>
      super.copyWith((message) => updates(message as CreateTaskRequest))
          as CreateTaskRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CreateTaskRequest() / CreateTaskRequest.new instead')
  static CreateTaskRequest create() => CreateTaskRequest._();
  static $pb.GeneratedMessage $_createMessage() => CreateTaskRequest._();
  @$core.override
  CreateTaskRequest createEmptyInstance() => CreateTaskRequest._();
  @$core.pragma('dart2js:noInline')
  static CreateTaskRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CreateTaskRequest>(
          CreateTaskRequest.$_createMessage);
  static CreateTaskRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get taskType => $_getSZ(1);
  @$pb.TagNumber(2)
  set taskType($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTaskType() => $_has(1);
  @$pb.TagNumber(2)
  void clearTaskType() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get payload => $_getSZ(2);
  @$pb.TagNumber(3)
  set payload($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPayload() => $_has(2);
  @$pb.TagNumber(3)
  void clearPayload() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get priority => $_getIZ(3);
  @$pb.TagNumber(4)
  set priority($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPriority() => $_has(3);
  @$pb.TagNumber(4)
  void clearPriority() => $_clearField(4);
}

class ListTasksRequest extends $pb.GeneratedMessage {
  factory ListTasksRequest({
    $core.String? sessionId,
  }) {
    final result = ListTasksRequest._();
    if (sessionId != null) result.sessionId = sessionId;
    return result;
  }

  ListTasksRequest._();

  factory ListTasksRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListTasksRequest()..mergeFromBuffer(data, registry);
  factory ListTasksRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListTasksRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListTasksRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ListTasksRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTasksRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTasksRequest copyWith(void Function(ListTasksRequest) updates) =>
      super.copyWith((message) => updates(message as ListTasksRequest))
          as ListTasksRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListTasksRequest() / ListTasksRequest.new instead')
  static ListTasksRequest create() => ListTasksRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListTasksRequest._();
  @$core.override
  ListTasksRequest createEmptyInstance() => ListTasksRequest._();
  @$core.pragma('dart2js:noInline')
  static ListTasksRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListTasksRequest>(
          ListTasksRequest.$_createMessage);
  static ListTasksRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);
}

class ListTasksResponse extends $pb.GeneratedMessage {
  factory ListTasksResponse({
    $core.Iterable<Task>? tasks,
  }) {
    final result = ListTasksResponse._();
    if (tasks != null) result.tasks.addAll(tasks);
    return result;
  }

  ListTasksResponse._();

  factory ListTasksResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListTasksResponse()..mergeFromBuffer(data, registry);
  factory ListTasksResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListTasksResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListTasksResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ListTasksResponse.$_createMessage)
    ..pPM<Task>(1, _omitFieldNames ? '' : 'tasks',
        subBuilder: Task.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTasksResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTasksResponse copyWith(void Function(ListTasksResponse) updates) =>
      super.copyWith((message) => updates(message as ListTasksResponse))
          as ListTasksResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListTasksResponse() / ListTasksResponse.new instead')
  static ListTasksResponse create() => ListTasksResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListTasksResponse._();
  @$core.override
  ListTasksResponse createEmptyInstance() => ListTasksResponse._();
  @$core.pragma('dart2js:noInline')
  static ListTasksResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListTasksResponse>(
          ListTasksResponse.$_createMessage);
  static ListTasksResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Task> get tasks => $_getList(0);
}

class UpdateTaskStatusRequest extends $pb.GeneratedMessage {
  factory UpdateTaskStatusRequest({
    $core.String? taskId,
    $core.String? status,
    $core.String? error,
  }) {
    final result = UpdateTaskStatusRequest._();
    if (taskId != null) result.taskId = taskId;
    if (status != null) result.status = status;
    if (error != null) result.error = error;
    return result;
  }

  UpdateTaskStatusRequest._();

  factory UpdateTaskStatusRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpdateTaskStatusRequest()..mergeFromBuffer(data, registry);
  factory UpdateTaskStatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpdateTaskStatusRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateTaskStatusRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: UpdateTaskStatusRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'taskId')
    ..aOS(2, _omitFieldNames ? '' : 'status')
    ..aOS(3, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateTaskStatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateTaskStatusRequest copyWith(
          void Function(UpdateTaskStatusRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateTaskStatusRequest))
          as UpdateTaskStatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use UpdateTaskStatusRequest() / UpdateTaskStatusRequest.new instead')
  static UpdateTaskStatusRequest create() => UpdateTaskStatusRequest._();
  static $pb.GeneratedMessage $_createMessage() => UpdateTaskStatusRequest._();
  @$core.override
  UpdateTaskStatusRequest createEmptyInstance() => UpdateTaskStatusRequest._();
  @$core.pragma('dart2js:noInline')
  static UpdateTaskStatusRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateTaskStatusRequest>(
          UpdateTaskStatusRequest.$_createMessage);
  static UpdateTaskStatusRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get taskId => $_getSZ(0);
  @$pb.TagNumber(1)
  set taskId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTaskId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTaskId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get status => $_getSZ(1);
  @$pb.TagNumber(2)
  set status($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get error => $_getSZ(2);
  @$pb.TagNumber(3)
  set error($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasError() => $_has(2);
  @$pb.TagNumber(3)
  void clearError() => $_clearField(3);
}

class ChatMessage extends $pb.GeneratedMessage {
  factory ChatMessage({
    $core.String? id,
    $core.String? sessionId,
    $core.String? tenantId,
    $core.String? role,
    $core.String? content,
    $core.String? toolCalls,
    $core.int? tokens,
    $core.String? model,
    $core.String? createdAt,
  }) {
    final result = ChatMessage._();
    if (id != null) result.id = id;
    if (sessionId != null) result.sessionId = sessionId;
    if (tenantId != null) result.tenantId = tenantId;
    if (role != null) result.role = role;
    if (content != null) result.content = content;
    if (toolCalls != null) result.toolCalls = toolCalls;
    if (tokens != null) result.tokens = tokens;
    if (model != null) result.model = model;
    if (createdAt != null) result.createdAt = createdAt;
    return result;
  }

  ChatMessage._();

  factory ChatMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ChatMessage()..mergeFromBuffer(data, registry);
  factory ChatMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ChatMessage()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChatMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ChatMessage.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..aOS(3, _omitFieldNames ? '' : 'tenantId')
    ..aOS(4, _omitFieldNames ? '' : 'role')
    ..aOS(5, _omitFieldNames ? '' : 'content')
    ..aOS(6, _omitFieldNames ? '' : 'toolCalls')
    ..aI(7, _omitFieldNames ? '' : 'tokens')
    ..aOS(8, _omitFieldNames ? '' : 'model')
    ..aOS(9, _omitFieldNames ? '' : 'createdAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatMessage copyWith(void Function(ChatMessage) updates) =>
      super.copyWith((message) => updates(message as ChatMessage))
          as ChatMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ChatMessage() / ChatMessage.new instead')
  static ChatMessage create() => ChatMessage._();
  static $pb.GeneratedMessage $_createMessage() => ChatMessage._();
  @$core.override
  ChatMessage createEmptyInstance() => ChatMessage._();
  @$core.pragma('dart2js:noInline')
  static ChatMessage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ChatMessage>(
          ChatMessage.$_createMessage);
  static ChatMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get tenantId => $_getSZ(2);
  @$pb.TagNumber(3)
  set tenantId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTenantId() => $_has(2);
  @$pb.TagNumber(3)
  void clearTenantId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get role => $_getSZ(3);
  @$pb.TagNumber(4)
  set role($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRole() => $_has(3);
  @$pb.TagNumber(4)
  void clearRole() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get content => $_getSZ(4);
  @$pb.TagNumber(5)
  set content($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasContent() => $_has(4);
  @$pb.TagNumber(5)
  void clearContent() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get toolCalls => $_getSZ(5);
  @$pb.TagNumber(6)
  set toolCalls($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasToolCalls() => $_has(5);
  @$pb.TagNumber(6)
  void clearToolCalls() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get tokens => $_getIZ(6);
  @$pb.TagNumber(7)
  set tokens($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTokens() => $_has(6);
  @$pb.TagNumber(7)
  void clearTokens() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get model => $_getSZ(7);
  @$pb.TagNumber(8)
  set model($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasModel() => $_has(7);
  @$pb.TagNumber(8)
  void clearModel() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get createdAt => $_getSZ(8);
  @$pb.TagNumber(9)
  set createdAt($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasCreatedAt() => $_has(8);
  @$pb.TagNumber(9)
  void clearCreatedAt() => $_clearField(9);
}

class ListChatMessagesRequest extends $pb.GeneratedMessage {
  factory ListChatMessagesRequest({
    $core.String? sessionId,
    $core.int? limit,
    $core.int? offset,
  }) {
    final result = ListChatMessagesRequest._();
    if (sessionId != null) result.sessionId = sessionId;
    if (limit != null) result.limit = limit;
    if (offset != null) result.offset = offset;
    return result;
  }

  ListChatMessagesRequest._();

  factory ListChatMessagesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListChatMessagesRequest()..mergeFromBuffer(data, registry);
  factory ListChatMessagesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListChatMessagesRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListChatMessagesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ListChatMessagesRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aI(2, _omitFieldNames ? '' : 'limit')
    ..aI(3, _omitFieldNames ? '' : 'offset')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListChatMessagesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListChatMessagesRequest copyWith(
          void Function(ListChatMessagesRequest) updates) =>
      super.copyWith((message) => updates(message as ListChatMessagesRequest))
          as ListChatMessagesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListChatMessagesRequest() / ListChatMessagesRequest.new instead')
  static ListChatMessagesRequest create() => ListChatMessagesRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListChatMessagesRequest._();
  @$core.override
  ListChatMessagesRequest createEmptyInstance() => ListChatMessagesRequest._();
  @$core.pragma('dart2js:noInline')
  static ListChatMessagesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListChatMessagesRequest>(
          ListChatMessagesRequest.$_createMessage);
  static ListChatMessagesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get limit => $_getIZ(1);
  @$pb.TagNumber(2)
  set limit($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLimit() => $_has(1);
  @$pb.TagNumber(2)
  void clearLimit() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get offset => $_getIZ(2);
  @$pb.TagNumber(3)
  set offset($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOffset() => $_has(2);
  @$pb.TagNumber(3)
  void clearOffset() => $_clearField(3);
}

class ListChatMessagesResponse extends $pb.GeneratedMessage {
  factory ListChatMessagesResponse({
    $core.Iterable<ChatMessage>? messages,
  }) {
    final result = ListChatMessagesResponse._();
    if (messages != null) result.messages.addAll(messages);
    return result;
  }

  ListChatMessagesResponse._();

  factory ListChatMessagesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListChatMessagesResponse()..mergeFromBuffer(data, registry);
  factory ListChatMessagesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListChatMessagesResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListChatMessagesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ListChatMessagesResponse.$_createMessage)
    ..pPM<ChatMessage>(1, _omitFieldNames ? '' : 'messages',
        subBuilder: ChatMessage.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListChatMessagesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListChatMessagesResponse copyWith(
          void Function(ListChatMessagesResponse) updates) =>
      super.copyWith((message) => updates(message as ListChatMessagesResponse))
          as ListChatMessagesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListChatMessagesResponse() / ListChatMessagesResponse.new instead')
  static ListChatMessagesResponse create() => ListChatMessagesResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListChatMessagesResponse._();
  @$core.override
  ListChatMessagesResponse createEmptyInstance() =>
      ListChatMessagesResponse._();
  @$core.pragma('dart2js:noInline')
  static ListChatMessagesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListChatMessagesResponse>(
          ListChatMessagesResponse.$_createMessage);
  static ListChatMessagesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ChatMessage> get messages => $_getList(0);
}

class AddChatMessageRequest extends $pb.GeneratedMessage {
  factory AddChatMessageRequest({
    $core.String? sessionId,
    $core.String? role,
    $core.String? content,
    $core.String? toolCalls,
    $core.int? tokens,
    $core.String? model,
  }) {
    final result = AddChatMessageRequest._();
    if (sessionId != null) result.sessionId = sessionId;
    if (role != null) result.role = role;
    if (content != null) result.content = content;
    if (toolCalls != null) result.toolCalls = toolCalls;
    if (tokens != null) result.tokens = tokens;
    if (model != null) result.model = model;
    return result;
  }

  AddChatMessageRequest._();

  factory AddChatMessageRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddChatMessageRequest()..mergeFromBuffer(data, registry);
  factory AddChatMessageRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddChatMessageRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddChatMessageRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: AddChatMessageRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOS(2, _omitFieldNames ? '' : 'role')
    ..aOS(3, _omitFieldNames ? '' : 'content')
    ..aOS(4, _omitFieldNames ? '' : 'toolCalls')
    ..aI(5, _omitFieldNames ? '' : 'tokens')
    ..aOS(6, _omitFieldNames ? '' : 'model')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddChatMessageRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddChatMessageRequest copyWith(
          void Function(AddChatMessageRequest) updates) =>
      super.copyWith((message) => updates(message as AddChatMessageRequest))
          as AddChatMessageRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AddChatMessageRequest() / AddChatMessageRequest.new instead')
  static AddChatMessageRequest create() => AddChatMessageRequest._();
  static $pb.GeneratedMessage $_createMessage() => AddChatMessageRequest._();
  @$core.override
  AddChatMessageRequest createEmptyInstance() => AddChatMessageRequest._();
  @$core.pragma('dart2js:noInline')
  static AddChatMessageRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddChatMessageRequest>(
          AddChatMessageRequest.$_createMessage);
  static AddChatMessageRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get role => $_getSZ(1);
  @$pb.TagNumber(2)
  set role($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRole() => $_has(1);
  @$pb.TagNumber(2)
  void clearRole() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get content => $_getSZ(2);
  @$pb.TagNumber(3)
  set content($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasContent() => $_has(2);
  @$pb.TagNumber(3)
  void clearContent() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get toolCalls => $_getSZ(3);
  @$pb.TagNumber(4)
  set toolCalls($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasToolCalls() => $_has(3);
  @$pb.TagNumber(4)
  void clearToolCalls() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get tokens => $_getIZ(4);
  @$pb.TagNumber(5)
  set tokens($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTokens() => $_has(4);
  @$pb.TagNumber(5)
  void clearTokens() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get model => $_getSZ(5);
  @$pb.TagNumber(6)
  set model($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasModel() => $_has(5);
  @$pb.TagNumber(6)
  void clearModel() => $_clearField(6);
}

class ObserveSessionRequest extends $pb.GeneratedMessage {
  factory ObserveSessionRequest({
    $core.String? sessionId,
  }) {
    final result = ObserveSessionRequest._();
    if (sessionId != null) result.sessionId = sessionId;
    return result;
  }

  ObserveSessionRequest._();

  factory ObserveSessionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ObserveSessionRequest()..mergeFromBuffer(data, registry);
  factory ObserveSessionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ObserveSessionRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ObserveSessionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ObserveSessionRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ObserveSessionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ObserveSessionRequest copyWith(
          void Function(ObserveSessionRequest) updates) =>
      super.copyWith((message) => updates(message as ObserveSessionRequest))
          as ObserveSessionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ObserveSessionRequest() / ObserveSessionRequest.new instead')
  static ObserveSessionRequest create() => ObserveSessionRequest._();
  static $pb.GeneratedMessage $_createMessage() => ObserveSessionRequest._();
  @$core.override
  ObserveSessionRequest createEmptyInstance() => ObserveSessionRequest._();
  @$core.pragma('dart2js:noInline')
  static ObserveSessionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ObserveSessionRequest>(
          ObserveSessionRequest.$_createMessage);
  static ObserveSessionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);
}

class CreateApiKeyRequest extends $pb.GeneratedMessage {
  factory CreateApiKeyRequest({
    $core.String? name,
  }) {
    final result = CreateApiKeyRequest._();
    if (name != null) result.name = name;
    return result;
  }

  CreateApiKeyRequest._();

  factory CreateApiKeyRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateApiKeyRequest()..mergeFromBuffer(data, registry);
  factory CreateApiKeyRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateApiKeyRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateApiKeyRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: CreateApiKeyRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateApiKeyRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateApiKeyRequest copyWith(void Function(CreateApiKeyRequest) updates) =>
      super.copyWith((message) => updates(message as CreateApiKeyRequest))
          as CreateApiKeyRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use CreateApiKeyRequest() / CreateApiKeyRequest.new instead')
  static CreateApiKeyRequest create() => CreateApiKeyRequest._();
  static $pb.GeneratedMessage $_createMessage() => CreateApiKeyRequest._();
  @$core.override
  CreateApiKeyRequest createEmptyInstance() => CreateApiKeyRequest._();
  @$core.pragma('dart2js:noInline')
  static CreateApiKeyRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateApiKeyRequest>(
          CreateApiKeyRequest.$_createMessage);
  static CreateApiKeyRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);
}

class CreateApiKeyResponse extends $pb.GeneratedMessage {
  factory CreateApiKeyResponse({
    ApiKey? apiKey,
    $core.String? plainTextKey,
  }) {
    final result = CreateApiKeyResponse._();
    if (apiKey != null) result.apiKey = apiKey;
    if (plainTextKey != null) result.plainTextKey = plainTextKey;
    return result;
  }

  CreateApiKeyResponse._();

  factory CreateApiKeyResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateApiKeyResponse()..mergeFromBuffer(data, registry);
  factory CreateApiKeyResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateApiKeyResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateApiKeyResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: CreateApiKeyResponse.$_createMessage)
    ..aOM<ApiKey>(1, _omitFieldNames ? '' : 'apiKey',
        subBuilder: ApiKey.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'plainTextKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateApiKeyResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateApiKeyResponse copyWith(void Function(CreateApiKeyResponse) updates) =>
      super.copyWith((message) => updates(message as CreateApiKeyResponse))
          as CreateApiKeyResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use CreateApiKeyResponse() / CreateApiKeyResponse.new instead')
  static CreateApiKeyResponse create() => CreateApiKeyResponse._();
  static $pb.GeneratedMessage $_createMessage() => CreateApiKeyResponse._();
  @$core.override
  CreateApiKeyResponse createEmptyInstance() => CreateApiKeyResponse._();
  @$core.pragma('dart2js:noInline')
  static CreateApiKeyResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateApiKeyResponse>(
          CreateApiKeyResponse.$_createMessage);
  static CreateApiKeyResponse? _defaultInstance;

  @$pb.TagNumber(1)
  ApiKey get apiKey => $_getN(0);
  @$pb.TagNumber(1)
  set apiKey(ApiKey value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasApiKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearApiKey() => $_clearField(1);
  @$pb.TagNumber(1)
  ApiKey ensureApiKey() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get plainTextKey => $_getSZ(1);
  @$pb.TagNumber(2)
  set plainTextKey($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPlainTextKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearPlainTextKey() => $_clearField(2);
}

class ListApiKeysResponse extends $pb.GeneratedMessage {
  factory ListApiKeysResponse({
    $core.Iterable<ApiKey>? apiKeys,
  }) {
    final result = ListApiKeysResponse._();
    if (apiKeys != null) result.apiKeys.addAll(apiKeys);
    return result;
  }

  ListApiKeysResponse._();

  factory ListApiKeysResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListApiKeysResponse()..mergeFromBuffer(data, registry);
  factory ListApiKeysResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListApiKeysResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListApiKeysResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ListApiKeysResponse.$_createMessage)
    ..pPM<ApiKey>(1, _omitFieldNames ? '' : 'apiKeys',
        subBuilder: ApiKey.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListApiKeysResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListApiKeysResponse copyWith(void Function(ListApiKeysResponse) updates) =>
      super.copyWith((message) => updates(message as ListApiKeysResponse))
          as ListApiKeysResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use ListApiKeysResponse() / ListApiKeysResponse.new instead')
  static ListApiKeysResponse create() => ListApiKeysResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListApiKeysResponse._();
  @$core.override
  ListApiKeysResponse createEmptyInstance() => ListApiKeysResponse._();
  @$core.pragma('dart2js:noInline')
  static ListApiKeysResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListApiKeysResponse>(
          ListApiKeysResponse.$_createMessage);
  static ListApiKeysResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ApiKey> get apiKeys => $_getList(0);
}

class RunAgentRequest extends $pb.GeneratedMessage {
  factory RunAgentRequest({
    $core.String? sessionId,
    $core.String? prompt,
    $core.String? providerId,
    $core.String? modelId,
    $core.String? workspacePath,
    $core.String? agentProfile,
  }) {
    final result = RunAgentRequest._();
    if (sessionId != null) result.sessionId = sessionId;
    if (prompt != null) result.prompt = prompt;
    if (providerId != null) result.providerId = providerId;
    if (modelId != null) result.modelId = modelId;
    if (workspacePath != null) result.workspacePath = workspacePath;
    if (agentProfile != null) result.agentProfile = agentProfile;
    return result;
  }

  RunAgentRequest._();

  factory RunAgentRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RunAgentRequest()..mergeFromBuffer(data, registry);
  factory RunAgentRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RunAgentRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RunAgentRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: RunAgentRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOS(2, _omitFieldNames ? '' : 'prompt')
    ..aOS(3, _omitFieldNames ? '' : 'providerId')
    ..aOS(4, _omitFieldNames ? '' : 'modelId')
    ..aOS(5, _omitFieldNames ? '' : 'workspacePath')
    ..aOS(6, _omitFieldNames ? '' : 'agentProfile')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RunAgentRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RunAgentRequest copyWith(void Function(RunAgentRequest) updates) =>
      super.copyWith((message) => updates(message as RunAgentRequest))
          as RunAgentRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RunAgentRequest() / RunAgentRequest.new instead')
  static RunAgentRequest create() => RunAgentRequest._();
  static $pb.GeneratedMessage $_createMessage() => RunAgentRequest._();
  @$core.override
  RunAgentRequest createEmptyInstance() => RunAgentRequest._();
  @$core.pragma('dart2js:noInline')
  static RunAgentRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RunAgentRequest>(
          RunAgentRequest.$_createMessage);
  static RunAgentRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get prompt => $_getSZ(1);
  @$pb.TagNumber(2)
  set prompt($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPrompt() => $_has(1);
  @$pb.TagNumber(2)
  void clearPrompt() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get providerId => $_getSZ(2);
  @$pb.TagNumber(3)
  set providerId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasProviderId() => $_has(2);
  @$pb.TagNumber(3)
  void clearProviderId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get modelId => $_getSZ(3);
  @$pb.TagNumber(4)
  set modelId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasModelId() => $_has(3);
  @$pb.TagNumber(4)
  void clearModelId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get workspacePath => $_getSZ(4);
  @$pb.TagNumber(5)
  set workspacePath($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasWorkspacePath() => $_has(4);
  @$pb.TagNumber(5)
  void clearWorkspacePath() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get agentProfile => $_getSZ(5);
  @$pb.TagNumber(6)
  set agentProfile($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAgentProfile() => $_has(5);
  @$pb.TagNumber(6)
  void clearAgentProfile() => $_clearField(6);
}

class RunAgentEvent extends $pb.GeneratedMessage {
  factory RunAgentEvent({
    $core.String? type,
    $core.String? content,
    $core.String? payload,
  }) {
    final result = RunAgentEvent._();
    if (type != null) result.type = type;
    if (content != null) result.content = content;
    if (payload != null) result.payload = payload;
    return result;
  }

  RunAgentEvent._();

  factory RunAgentEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RunAgentEvent()..mergeFromBuffer(data, registry);
  factory RunAgentEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RunAgentEvent()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RunAgentEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: RunAgentEvent.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'type')
    ..aOS(2, _omitFieldNames ? '' : 'content')
    ..aOS(3, _omitFieldNames ? '' : 'payload')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RunAgentEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RunAgentEvent copyWith(void Function(RunAgentEvent) updates) =>
      super.copyWith((message) => updates(message as RunAgentEvent))
          as RunAgentEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RunAgentEvent() / RunAgentEvent.new instead')
  static RunAgentEvent create() => RunAgentEvent._();
  static $pb.GeneratedMessage $_createMessage() => RunAgentEvent._();
  @$core.override
  RunAgentEvent createEmptyInstance() => RunAgentEvent._();
  @$core.pragma('dart2js:noInline')
  static RunAgentEvent getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RunAgentEvent>(
          RunAgentEvent.$_createMessage);
  static RunAgentEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get type => $_getSZ(0);
  @$pb.TagNumber(1)
  set type($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get content => $_getSZ(1);
  @$pb.TagNumber(2)
  set content($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasContent() => $_has(1);
  @$pb.TagNumber(2)
  void clearContent() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get payload => $_getSZ(2);
  @$pb.TagNumber(3)
  set payload($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPayload() => $_has(2);
  @$pb.TagNumber(3)
  void clearPayload() => $_clearField(3);
}

class ProviderInfo extends $pb.GeneratedMessage {
  factory ProviderInfo({
    $core.String? id,
    $core.String? name,
    $core.String? description,
    $core.Iterable<$core.String>? capabilities,
  }) {
    final result = ProviderInfo._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (capabilities != null) result.capabilities.addAll(capabilities);
    return result;
  }

  ProviderInfo._();

  factory ProviderInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ProviderInfo()..mergeFromBuffer(data, registry);
  factory ProviderInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ProviderInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProviderInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ProviderInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..pPS(4, _omitFieldNames ? '' : 'capabilities')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProviderInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProviderInfo copyWith(void Function(ProviderInfo) updates) =>
      super.copyWith((message) => updates(message as ProviderInfo))
          as ProviderInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ProviderInfo() / ProviderInfo.new instead')
  static ProviderInfo create() => ProviderInfo._();
  static $pb.GeneratedMessage $_createMessage() => ProviderInfo._();
  @$core.override
  ProviderInfo createEmptyInstance() => ProviderInfo._();
  @$core.pragma('dart2js:noInline')
  static ProviderInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ProviderInfo>(
          ProviderInfo.$_createMessage);
  static ProviderInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get capabilities => $_getList(3);
}

class ListProvidersResponse extends $pb.GeneratedMessage {
  factory ListProvidersResponse({
    $core.Iterable<ProviderInfo>? providers,
  }) {
    final result = ListProvidersResponse._();
    if (providers != null) result.providers.addAll(providers);
    return result;
  }

  ListProvidersResponse._();

  factory ListProvidersResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListProvidersResponse()..mergeFromBuffer(data, registry);
  factory ListProvidersResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListProvidersResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListProvidersResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ListProvidersResponse.$_createMessage)
    ..pPM<ProviderInfo>(1, _omitFieldNames ? '' : 'providers',
        subBuilder: ProviderInfo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListProvidersResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListProvidersResponse copyWith(
          void Function(ListProvidersResponse) updates) =>
      super.copyWith((message) => updates(message as ListProvidersResponse))
          as ListProvidersResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListProvidersResponse() / ListProvidersResponse.new instead')
  static ListProvidersResponse create() => ListProvidersResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListProvidersResponse._();
  @$core.override
  ListProvidersResponse createEmptyInstance() => ListProvidersResponse._();
  @$core.pragma('dart2js:noInline')
  static ListProvidersResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListProvidersResponse>(
          ListProvidersResponse.$_createMessage);
  static ListProvidersResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ProviderInfo> get providers => $_getList(0);
}

class ModelInfo extends $pb.GeneratedMessage {
  factory ModelInfo({
    $core.String? id,
    $core.String? name,
    $core.String? description,
    $core.String? format,
    $fixnum.Int64? sizeBytes,
  }) {
    final result = ModelInfo._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (format != null) result.format = format;
    if (sizeBytes != null) result.sizeBytes = sizeBytes;
    return result;
  }

  ModelInfo._();

  factory ModelInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ModelInfo()..mergeFromBuffer(data, registry);
  factory ModelInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ModelInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ModelInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ModelInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..aOS(4, _omitFieldNames ? '' : 'format')
    ..aInt64(5, _omitFieldNames ? '' : 'sizeBytes')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModelInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ModelInfo copyWith(void Function(ModelInfo) updates) =>
      super.copyWith((message) => updates(message as ModelInfo)) as ModelInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ModelInfo() / ModelInfo.new instead')
  static ModelInfo create() => ModelInfo._();
  static $pb.GeneratedMessage $_createMessage() => ModelInfo._();
  @$core.override
  ModelInfo createEmptyInstance() => ModelInfo._();
  @$core.pragma('dart2js:noInline')
  static ModelInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ModelInfo>(ModelInfo.$_createMessage);
  static ModelInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get format => $_getSZ(3);
  @$pb.TagNumber(4)
  set format($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFormat() => $_has(3);
  @$pb.TagNumber(4)
  void clearFormat() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get sizeBytes => $_getI64(4);
  @$pb.TagNumber(5)
  set sizeBytes($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSizeBytes() => $_has(4);
  @$pb.TagNumber(5)
  void clearSizeBytes() => $_clearField(5);
}

class ListModelsRequest extends $pb.GeneratedMessage {
  factory ListModelsRequest({
    $core.String? providerId,
  }) {
    final result = ListModelsRequest._();
    if (providerId != null) result.providerId = providerId;
    return result;
  }

  ListModelsRequest._();

  factory ListModelsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListModelsRequest()..mergeFromBuffer(data, registry);
  factory ListModelsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListModelsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListModelsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ListModelsRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'providerId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListModelsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListModelsRequest copyWith(void Function(ListModelsRequest) updates) =>
      super.copyWith((message) => updates(message as ListModelsRequest))
          as ListModelsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListModelsRequest() / ListModelsRequest.new instead')
  static ListModelsRequest create() => ListModelsRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListModelsRequest._();
  @$core.override
  ListModelsRequest createEmptyInstance() => ListModelsRequest._();
  @$core.pragma('dart2js:noInline')
  static ListModelsRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListModelsRequest>(
          ListModelsRequest.$_createMessage);
  static ListModelsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get providerId => $_getSZ(0);
  @$pb.TagNumber(1)
  set providerId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProviderId() => $_has(0);
  @$pb.TagNumber(1)
  void clearProviderId() => $_clearField(1);
}

class ListModelsResponse extends $pb.GeneratedMessage {
  factory ListModelsResponse({
    $core.Iterable<ModelInfo>? models,
  }) {
    final result = ListModelsResponse._();
    if (models != null) result.models.addAll(models);
    return result;
  }

  ListModelsResponse._();

  factory ListModelsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListModelsResponse()..mergeFromBuffer(data, registry);
  factory ListModelsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListModelsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListModelsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ListModelsResponse.$_createMessage)
    ..pPM<ModelInfo>(1, _omitFieldNames ? '' : 'models',
        subBuilder: ModelInfo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListModelsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListModelsResponse copyWith(void Function(ListModelsResponse) updates) =>
      super.copyWith((message) => updates(message as ListModelsResponse))
          as ListModelsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListModelsResponse() / ListModelsResponse.new instead')
  static ListModelsResponse create() => ListModelsResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListModelsResponse._();
  @$core.override
  ListModelsResponse createEmptyInstance() => ListModelsResponse._();
  @$core.pragma('dart2js:noInline')
  static ListModelsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListModelsResponse>(
          ListModelsResponse.$_createMessage);
  static ListModelsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ModelInfo> get models => $_getList(0);
}

class McpServerInfo extends $pb.GeneratedMessage {
  factory McpServerInfo({
    $core.String? id,
    $core.String? url,
    $core.String? command,
    $core.Iterable<$core.String>? args,
    $core.String? transport,
    $core.bool? enabled,
  }) {
    final result = McpServerInfo._();
    if (id != null) result.id = id;
    if (url != null) result.url = url;
    if (command != null) result.command = command;
    if (args != null) result.args.addAll(args);
    if (transport != null) result.transport = transport;
    if (enabled != null) result.enabled = enabled;
    return result;
  }

  McpServerInfo._();

  factory McpServerInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      McpServerInfo()..mergeFromBuffer(data, registry);
  factory McpServerInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      McpServerInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'McpServerInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: McpServerInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'url')
    ..aOS(3, _omitFieldNames ? '' : 'command')
    ..pPS(4, _omitFieldNames ? '' : 'args')
    ..aOS(5, _omitFieldNames ? '' : 'transport')
    ..aOB(6, _omitFieldNames ? '' : 'enabled')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  McpServerInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  McpServerInfo copyWith(void Function(McpServerInfo) updates) =>
      super.copyWith((message) => updates(message as McpServerInfo))
          as McpServerInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use McpServerInfo() / McpServerInfo.new instead')
  static McpServerInfo create() => McpServerInfo._();
  static $pb.GeneratedMessage $_createMessage() => McpServerInfo._();
  @$core.override
  McpServerInfo createEmptyInstance() => McpServerInfo._();
  @$core.pragma('dart2js:noInline')
  static McpServerInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<McpServerInfo>(
          McpServerInfo.$_createMessage);
  static McpServerInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get url => $_getSZ(1);
  @$pb.TagNumber(2)
  set url($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearUrl() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get command => $_getSZ(2);
  @$pb.TagNumber(3)
  set command($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCommand() => $_has(2);
  @$pb.TagNumber(3)
  void clearCommand() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get args => $_getList(3);

  @$pb.TagNumber(5)
  $core.String get transport => $_getSZ(4);
  @$pb.TagNumber(5)
  set transport($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTransport() => $_has(4);
  @$pb.TagNumber(5)
  void clearTransport() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get enabled => $_getBF(5);
  @$pb.TagNumber(6)
  set enabled($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasEnabled() => $_has(5);
  @$pb.TagNumber(6)
  void clearEnabled() => $_clearField(6);
}

class ListMcpServersResponse extends $pb.GeneratedMessage {
  factory ListMcpServersResponse({
    $core.Iterable<McpServerInfo>? servers,
  }) {
    final result = ListMcpServersResponse._();
    if (servers != null) result.servers.addAll(servers);
    return result;
  }

  ListMcpServersResponse._();

  factory ListMcpServersResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListMcpServersResponse()..mergeFromBuffer(data, registry);
  factory ListMcpServersResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListMcpServersResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListMcpServersResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ListMcpServersResponse.$_createMessage)
    ..pPM<McpServerInfo>(1, _omitFieldNames ? '' : 'servers',
        subBuilder: McpServerInfo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListMcpServersResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListMcpServersResponse copyWith(
          void Function(ListMcpServersResponse) updates) =>
      super.copyWith((message) => updates(message as ListMcpServersResponse))
          as ListMcpServersResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListMcpServersResponse() / ListMcpServersResponse.new instead')
  static ListMcpServersResponse create() => ListMcpServersResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListMcpServersResponse._();
  @$core.override
  ListMcpServersResponse createEmptyInstance() => ListMcpServersResponse._();
  @$core.pragma('dart2js:noInline')
  static ListMcpServersResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListMcpServersResponse>(
          ListMcpServersResponse.$_createMessage);
  static ListMcpServersResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<McpServerInfo> get servers => $_getList(0);
}

class RegisterMcpServerRequest extends $pb.GeneratedMessage {
  factory RegisterMcpServerRequest({
    $core.String? id,
    $core.String? url,
    $core.String? command,
    $core.Iterable<$core.String>? args,
    $core.String? transport,
    $core.bool? enabled,
  }) {
    final result = RegisterMcpServerRequest._();
    if (id != null) result.id = id;
    if (url != null) result.url = url;
    if (command != null) result.command = command;
    if (args != null) result.args.addAll(args);
    if (transport != null) result.transport = transport;
    if (enabled != null) result.enabled = enabled;
    return result;
  }

  RegisterMcpServerRequest._();

  factory RegisterMcpServerRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RegisterMcpServerRequest()..mergeFromBuffer(data, registry);
  factory RegisterMcpServerRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RegisterMcpServerRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegisterMcpServerRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: RegisterMcpServerRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'url')
    ..aOS(3, _omitFieldNames ? '' : 'command')
    ..pPS(4, _omitFieldNames ? '' : 'args')
    ..aOS(5, _omitFieldNames ? '' : 'transport')
    ..aOB(6, _omitFieldNames ? '' : 'enabled')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterMcpServerRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterMcpServerRequest copyWith(
          void Function(RegisterMcpServerRequest) updates) =>
      super.copyWith((message) => updates(message as RegisterMcpServerRequest))
          as RegisterMcpServerRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RegisterMcpServerRequest() / RegisterMcpServerRequest.new instead')
  static RegisterMcpServerRequest create() => RegisterMcpServerRequest._();
  static $pb.GeneratedMessage $_createMessage() => RegisterMcpServerRequest._();
  @$core.override
  RegisterMcpServerRequest createEmptyInstance() =>
      RegisterMcpServerRequest._();
  @$core.pragma('dart2js:noInline')
  static RegisterMcpServerRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegisterMcpServerRequest>(
          RegisterMcpServerRequest.$_createMessage);
  static RegisterMcpServerRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get url => $_getSZ(1);
  @$pb.TagNumber(2)
  set url($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearUrl() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get command => $_getSZ(2);
  @$pb.TagNumber(3)
  set command($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCommand() => $_has(2);
  @$pb.TagNumber(3)
  void clearCommand() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get args => $_getList(3);

  @$pb.TagNumber(5)
  $core.String get transport => $_getSZ(4);
  @$pb.TagNumber(5)
  set transport($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTransport() => $_has(4);
  @$pb.TagNumber(5)
  void clearTransport() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get enabled => $_getBF(5);
  @$pb.TagNumber(6)
  set enabled($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasEnabled() => $_has(5);
  @$pb.TagNumber(6)
  void clearEnabled() => $_clearField(6);
}

class RemoveMcpServerRequest extends $pb.GeneratedMessage {
  factory RemoveMcpServerRequest({
    $core.String? id,
  }) {
    final result = RemoveMcpServerRequest._();
    if (id != null) result.id = id;
    return result;
  }

  RemoveMcpServerRequest._();

  factory RemoveMcpServerRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveMcpServerRequest()..mergeFromBuffer(data, registry);
  factory RemoveMcpServerRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveMcpServerRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveMcpServerRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: RemoveMcpServerRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveMcpServerRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveMcpServerRequest copyWith(
          void Function(RemoveMcpServerRequest) updates) =>
      super.copyWith((message) => updates(message as RemoveMcpServerRequest))
          as RemoveMcpServerRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RemoveMcpServerRequest() / RemoveMcpServerRequest.new instead')
  static RemoveMcpServerRequest create() => RemoveMcpServerRequest._();
  static $pb.GeneratedMessage $_createMessage() => RemoveMcpServerRequest._();
  @$core.override
  RemoveMcpServerRequest createEmptyInstance() => RemoveMcpServerRequest._();
  @$core.pragma('dart2js:noInline')
  static RemoveMcpServerRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveMcpServerRequest>(
          RemoveMcpServerRequest.$_createMessage);
  static RemoveMcpServerRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class RemoveMcpServerResponse extends $pb.GeneratedMessage {
  factory RemoveMcpServerResponse({
    $core.bool? success,
    $core.String? message,
  }) {
    final result = RemoveMcpServerResponse._();
    if (success != null) result.success = success;
    if (message != null) result.message = message;
    return result;
  }

  RemoveMcpServerResponse._();

  factory RemoveMcpServerResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveMcpServerResponse()..mergeFromBuffer(data, registry);
  factory RemoveMcpServerResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveMcpServerResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveMcpServerResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: RemoveMcpServerResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveMcpServerResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveMcpServerResponse copyWith(
          void Function(RemoveMcpServerResponse) updates) =>
      super.copyWith((message) => updates(message as RemoveMcpServerResponse))
          as RemoveMcpServerResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RemoveMcpServerResponse() / RemoveMcpServerResponse.new instead')
  static RemoveMcpServerResponse create() => RemoveMcpServerResponse._();
  static $pb.GeneratedMessage $_createMessage() => RemoveMcpServerResponse._();
  @$core.override
  RemoveMcpServerResponse createEmptyInstance() => RemoveMcpServerResponse._();
  @$core.pragma('dart2js:noInline')
  static RemoveMcpServerResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveMcpServerResponse>(
          RemoveMcpServerResponse.$_createMessage);
  static RemoveMcpServerResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

class ReloadMcpResponse extends $pb.GeneratedMessage {
  factory ReloadMcpResponse({
    $core.bool? success,
    $core.int? serverCount,
    $core.int? toolCount,
  }) {
    final result = ReloadMcpResponse._();
    if (success != null) result.success = success;
    if (serverCount != null) result.serverCount = serverCount;
    if (toolCount != null) result.toolCount = toolCount;
    return result;
  }

  ReloadMcpResponse._();

  factory ReloadMcpResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReloadMcpResponse()..mergeFromBuffer(data, registry);
  factory ReloadMcpResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReloadMcpResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReloadMcpResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ReloadMcpResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aI(2, _omitFieldNames ? '' : 'serverCount')
    ..aI(3, _omitFieldNames ? '' : 'toolCount')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReloadMcpResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReloadMcpResponse copyWith(void Function(ReloadMcpResponse) updates) =>
      super.copyWith((message) => updates(message as ReloadMcpResponse))
          as ReloadMcpResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ReloadMcpResponse() / ReloadMcpResponse.new instead')
  static ReloadMcpResponse create() => ReloadMcpResponse._();
  static $pb.GeneratedMessage $_createMessage() => ReloadMcpResponse._();
  @$core.override
  ReloadMcpResponse createEmptyInstance() => ReloadMcpResponse._();
  @$core.pragma('dart2js:noInline')
  static ReloadMcpResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ReloadMcpResponse>(
          ReloadMcpResponse.$_createMessage);
  static ReloadMcpResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get serverCount => $_getIZ(1);
  @$pb.TagNumber(2)
  set serverCount($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasServerCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearServerCount() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get toolCount => $_getIZ(2);
  @$pb.TagNumber(3)
  set toolCount($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasToolCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearToolCount() => $_clearField(3);
}

class McpToolInfo extends $pb.GeneratedMessage {
  factory McpToolInfo({
    $core.String? serverId,
    $core.String? name,
    $core.String? description,
    $core.String? inputSchemaJson,
  }) {
    final result = McpToolInfo._();
    if (serverId != null) result.serverId = serverId;
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (inputSchemaJson != null) result.inputSchemaJson = inputSchemaJson;
    return result;
  }

  McpToolInfo._();

  factory McpToolInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      McpToolInfo()..mergeFromBuffer(data, registry);
  factory McpToolInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      McpToolInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'McpToolInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: McpToolInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'serverId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..aOS(4, _omitFieldNames ? '' : 'inputSchemaJson')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  McpToolInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  McpToolInfo copyWith(void Function(McpToolInfo) updates) =>
      super.copyWith((message) => updates(message as McpToolInfo))
          as McpToolInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use McpToolInfo() / McpToolInfo.new instead')
  static McpToolInfo create() => McpToolInfo._();
  static $pb.GeneratedMessage $_createMessage() => McpToolInfo._();
  @$core.override
  McpToolInfo createEmptyInstance() => McpToolInfo._();
  @$core.pragma('dart2js:noInline')
  static McpToolInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<McpToolInfo>(
          McpToolInfo.$_createMessage);
  static McpToolInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get serverId => $_getSZ(0);
  @$pb.TagNumber(1)
  set serverId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasServerId() => $_has(0);
  @$pb.TagNumber(1)
  void clearServerId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get inputSchemaJson => $_getSZ(3);
  @$pb.TagNumber(4)
  set inputSchemaJson($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasInputSchemaJson() => $_has(3);
  @$pb.TagNumber(4)
  void clearInputSchemaJson() => $_clearField(4);
}

class ListMcpToolsResponse extends $pb.GeneratedMessage {
  factory ListMcpToolsResponse({
    $core.Iterable<McpToolInfo>? tools,
  }) {
    final result = ListMcpToolsResponse._();
    if (tools != null) result.tools.addAll(tools);
    return result;
  }

  ListMcpToolsResponse._();

  factory ListMcpToolsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListMcpToolsResponse()..mergeFromBuffer(data, registry);
  factory ListMcpToolsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListMcpToolsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListMcpToolsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ListMcpToolsResponse.$_createMessage)
    ..pPM<McpToolInfo>(1, _omitFieldNames ? '' : 'tools',
        subBuilder: McpToolInfo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListMcpToolsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListMcpToolsResponse copyWith(void Function(ListMcpToolsResponse) updates) =>
      super.copyWith((message) => updates(message as ListMcpToolsResponse))
          as ListMcpToolsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListMcpToolsResponse() / ListMcpToolsResponse.new instead')
  static ListMcpToolsResponse create() => ListMcpToolsResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListMcpToolsResponse._();
  @$core.override
  ListMcpToolsResponse createEmptyInstance() => ListMcpToolsResponse._();
  @$core.pragma('dart2js:noInline')
  static ListMcpToolsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListMcpToolsResponse>(
          ListMcpToolsResponse.$_createMessage);
  static ListMcpToolsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<McpToolInfo> get tools => $_getList(0);
}

class ExportMemoryRequest extends $pb.GeneratedMessage {
  factory ExportMemoryRequest({
    $core.String? agentId,
    $core.String? userId,
    $core.String? tenantId,
  }) {
    final result = ExportMemoryRequest._();
    if (agentId != null) result.agentId = agentId;
    if (userId != null) result.userId = userId;
    if (tenantId != null) result.tenantId = tenantId;
    return result;
  }

  ExportMemoryRequest._();

  factory ExportMemoryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ExportMemoryRequest()..mergeFromBuffer(data, registry);
  factory ExportMemoryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ExportMemoryRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExportMemoryRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ExportMemoryRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'agentId')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aOS(3, _omitFieldNames ? '' : 'tenantId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportMemoryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportMemoryRequest copyWith(void Function(ExportMemoryRequest) updates) =>
      super.copyWith((message) => updates(message as ExportMemoryRequest))
          as ExportMemoryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use ExportMemoryRequest() / ExportMemoryRequest.new instead')
  static ExportMemoryRequest create() => ExportMemoryRequest._();
  static $pb.GeneratedMessage $_createMessage() => ExportMemoryRequest._();
  @$core.override
  ExportMemoryRequest createEmptyInstance() => ExportMemoryRequest._();
  @$core.pragma('dart2js:noInline')
  static ExportMemoryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExportMemoryRequest>(
          ExportMemoryRequest.$_createMessage);
  static ExportMemoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get agentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set agentId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAgentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAgentId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get tenantId => $_getSZ(2);
  @$pb.TagNumber(3)
  set tenantId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTenantId() => $_has(2);
  @$pb.TagNumber(3)
  void clearTenantId() => $_clearField(3);
}

class ExportMemoryResponse extends $pb.GeneratedMessage {
  factory ExportMemoryResponse({
    $core.String? snapshotId,
    $core.String? agentId,
    $core.int? recordCount,
    $core.Iterable<$core.String>? tiers,
    $core.String? snapshotJson,
    $core.String? capturedAt,
  }) {
    final result = ExportMemoryResponse._();
    if (snapshotId != null) result.snapshotId = snapshotId;
    if (agentId != null) result.agentId = agentId;
    if (recordCount != null) result.recordCount = recordCount;
    if (tiers != null) result.tiers.addAll(tiers);
    if (snapshotJson != null) result.snapshotJson = snapshotJson;
    if (capturedAt != null) result.capturedAt = capturedAt;
    return result;
  }

  ExportMemoryResponse._();

  factory ExportMemoryResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ExportMemoryResponse()..mergeFromBuffer(data, registry);
  factory ExportMemoryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ExportMemoryResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExportMemoryResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ExportMemoryResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'snapshotId')
    ..aOS(2, _omitFieldNames ? '' : 'agentId')
    ..aI(3, _omitFieldNames ? '' : 'recordCount')
    ..pPS(4, _omitFieldNames ? '' : 'tiers')
    ..aOS(5, _omitFieldNames ? '' : 'snapshotJson')
    ..aOS(6, _omitFieldNames ? '' : 'capturedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportMemoryResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExportMemoryResponse copyWith(void Function(ExportMemoryResponse) updates) =>
      super.copyWith((message) => updates(message as ExportMemoryResponse))
          as ExportMemoryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ExportMemoryResponse() / ExportMemoryResponse.new instead')
  static ExportMemoryResponse create() => ExportMemoryResponse._();
  static $pb.GeneratedMessage $_createMessage() => ExportMemoryResponse._();
  @$core.override
  ExportMemoryResponse createEmptyInstance() => ExportMemoryResponse._();
  @$core.pragma('dart2js:noInline')
  static ExportMemoryResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExportMemoryResponse>(
          ExportMemoryResponse.$_createMessage);
  static ExportMemoryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get snapshotId => $_getSZ(0);
  @$pb.TagNumber(1)
  set snapshotId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSnapshotId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSnapshotId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get agentId => $_getSZ(1);
  @$pb.TagNumber(2)
  set agentId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAgentId() => $_has(1);
  @$pb.TagNumber(2)
  void clearAgentId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get recordCount => $_getIZ(2);
  @$pb.TagNumber(3)
  set recordCount($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRecordCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearRecordCount() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get tiers => $_getList(3);

  @$pb.TagNumber(5)
  $core.String get snapshotJson => $_getSZ(4);
  @$pb.TagNumber(5)
  set snapshotJson($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSnapshotJson() => $_has(4);
  @$pb.TagNumber(5)
  void clearSnapshotJson() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get capturedAt => $_getSZ(5);
  @$pb.TagNumber(6)
  set capturedAt($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCapturedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearCapturedAt() => $_clearField(6);
}

class ImportMemoryRequest extends $pb.GeneratedMessage {
  factory ImportMemoryRequest({
    $core.String? agentId,
    $core.String? snapshotJson,
    $core.bool? overwrite,
  }) {
    final result = ImportMemoryRequest._();
    if (agentId != null) result.agentId = agentId;
    if (snapshotJson != null) result.snapshotJson = snapshotJson;
    if (overwrite != null) result.overwrite = overwrite;
    return result;
  }

  ImportMemoryRequest._();

  factory ImportMemoryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ImportMemoryRequest()..mergeFromBuffer(data, registry);
  factory ImportMemoryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ImportMemoryRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ImportMemoryRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ImportMemoryRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'agentId')
    ..aOS(2, _omitFieldNames ? '' : 'snapshotJson')
    ..aOB(3, _omitFieldNames ? '' : 'overwrite')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImportMemoryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImportMemoryRequest copyWith(void Function(ImportMemoryRequest) updates) =>
      super.copyWith((message) => updates(message as ImportMemoryRequest))
          as ImportMemoryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use ImportMemoryRequest() / ImportMemoryRequest.new instead')
  static ImportMemoryRequest create() => ImportMemoryRequest._();
  static $pb.GeneratedMessage $_createMessage() => ImportMemoryRequest._();
  @$core.override
  ImportMemoryRequest createEmptyInstance() => ImportMemoryRequest._();
  @$core.pragma('dart2js:noInline')
  static ImportMemoryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ImportMemoryRequest>(
          ImportMemoryRequest.$_createMessage);
  static ImportMemoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get agentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set agentId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAgentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAgentId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get snapshotJson => $_getSZ(1);
  @$pb.TagNumber(2)
  set snapshotJson($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSnapshotJson() => $_has(1);
  @$pb.TagNumber(2)
  void clearSnapshotJson() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get overwrite => $_getBF(2);
  @$pb.TagNumber(3)
  set overwrite($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOverwrite() => $_has(2);
  @$pb.TagNumber(3)
  void clearOverwrite() => $_clearField(3);
}

class ImportMemoryResponse extends $pb.GeneratedMessage {
  factory ImportMemoryResponse({
    $core.bool? success,
    $core.String? snapshotId,
    $core.String? agentId,
    $core.int? totalRecords,
    $core.int? writtenRecords,
    $core.int? skippedRecords,
    $core.String? importedAt,
  }) {
    final result = ImportMemoryResponse._();
    if (success != null) result.success = success;
    if (snapshotId != null) result.snapshotId = snapshotId;
    if (agentId != null) result.agentId = agentId;
    if (totalRecords != null) result.totalRecords = totalRecords;
    if (writtenRecords != null) result.writtenRecords = writtenRecords;
    if (skippedRecords != null) result.skippedRecords = skippedRecords;
    if (importedAt != null) result.importedAt = importedAt;
    return result;
  }

  ImportMemoryResponse._();

  factory ImportMemoryResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ImportMemoryResponse()..mergeFromBuffer(data, registry);
  factory ImportMemoryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ImportMemoryResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ImportMemoryResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ImportMemoryResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'snapshotId')
    ..aOS(3, _omitFieldNames ? '' : 'agentId')
    ..aI(4, _omitFieldNames ? '' : 'totalRecords')
    ..aI(5, _omitFieldNames ? '' : 'writtenRecords')
    ..aI(6, _omitFieldNames ? '' : 'skippedRecords')
    ..aOS(7, _omitFieldNames ? '' : 'importedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImportMemoryResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImportMemoryResponse copyWith(void Function(ImportMemoryResponse) updates) =>
      super.copyWith((message) => updates(message as ImportMemoryResponse))
          as ImportMemoryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ImportMemoryResponse() / ImportMemoryResponse.new instead')
  static ImportMemoryResponse create() => ImportMemoryResponse._();
  static $pb.GeneratedMessage $_createMessage() => ImportMemoryResponse._();
  @$core.override
  ImportMemoryResponse createEmptyInstance() => ImportMemoryResponse._();
  @$core.pragma('dart2js:noInline')
  static ImportMemoryResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ImportMemoryResponse>(
          ImportMemoryResponse.$_createMessage);
  static ImportMemoryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get snapshotId => $_getSZ(1);
  @$pb.TagNumber(2)
  set snapshotId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSnapshotId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSnapshotId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get agentId => $_getSZ(2);
  @$pb.TagNumber(3)
  set agentId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAgentId() => $_has(2);
  @$pb.TagNumber(3)
  void clearAgentId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get totalRecords => $_getIZ(3);
  @$pb.TagNumber(4)
  set totalRecords($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTotalRecords() => $_has(3);
  @$pb.TagNumber(4)
  void clearTotalRecords() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get writtenRecords => $_getIZ(4);
  @$pb.TagNumber(5)
  set writtenRecords($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasWrittenRecords() => $_has(4);
  @$pb.TagNumber(5)
  void clearWrittenRecords() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get skippedRecords => $_getIZ(5);
  @$pb.TagNumber(6)
  set skippedRecords($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSkippedRecords() => $_has(5);
  @$pb.TagNumber(6)
  void clearSkippedRecords() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get importedAt => $_getSZ(6);
  @$pb.TagNumber(7)
  set importedAt($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasImportedAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearImportedAt() => $_clearField(7);
}

class BackupMemoryRequest extends $pb.GeneratedMessage {
  factory BackupMemoryRequest({
    $core.String? agentId,
    $core.String? userId,
    $core.String? tenantId,
    $core.String? destinationPath,
  }) {
    final result = BackupMemoryRequest._();
    if (agentId != null) result.agentId = agentId;
    if (userId != null) result.userId = userId;
    if (tenantId != null) result.tenantId = tenantId;
    if (destinationPath != null) result.destinationPath = destinationPath;
    return result;
  }

  BackupMemoryRequest._();

  factory BackupMemoryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BackupMemoryRequest()..mergeFromBuffer(data, registry);
  factory BackupMemoryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BackupMemoryRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BackupMemoryRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: BackupMemoryRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'agentId')
    ..aOS(2, _omitFieldNames ? '' : 'userId')
    ..aOS(3, _omitFieldNames ? '' : 'tenantId')
    ..aOS(4, _omitFieldNames ? '' : 'destinationPath')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupMemoryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupMemoryRequest copyWith(void Function(BackupMemoryRequest) updates) =>
      super.copyWith((message) => updates(message as BackupMemoryRequest))
          as BackupMemoryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use BackupMemoryRequest() / BackupMemoryRequest.new instead')
  static BackupMemoryRequest create() => BackupMemoryRequest._();
  static $pb.GeneratedMessage $_createMessage() => BackupMemoryRequest._();
  @$core.override
  BackupMemoryRequest createEmptyInstance() => BackupMemoryRequest._();
  @$core.pragma('dart2js:noInline')
  static BackupMemoryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BackupMemoryRequest>(
          BackupMemoryRequest.$_createMessage);
  static BackupMemoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get agentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set agentId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAgentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAgentId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUserId() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get tenantId => $_getSZ(2);
  @$pb.TagNumber(3)
  set tenantId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTenantId() => $_has(2);
  @$pb.TagNumber(3)
  void clearTenantId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get destinationPath => $_getSZ(3);
  @$pb.TagNumber(4)
  set destinationPath($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDestinationPath() => $_has(3);
  @$pb.TagNumber(4)
  void clearDestinationPath() => $_clearField(4);
}

class BackupMemoryResponse extends $pb.GeneratedMessage {
  factory BackupMemoryResponse({
    $core.bool? success,
    $core.String? snapshotId,
    $core.String? agentId,
    $core.int? recordCount,
    $core.String? filePath,
    $core.String? capturedAt,
  }) {
    final result = BackupMemoryResponse._();
    if (success != null) result.success = success;
    if (snapshotId != null) result.snapshotId = snapshotId;
    if (agentId != null) result.agentId = agentId;
    if (recordCount != null) result.recordCount = recordCount;
    if (filePath != null) result.filePath = filePath;
    if (capturedAt != null) result.capturedAt = capturedAt;
    return result;
  }

  BackupMemoryResponse._();

  factory BackupMemoryResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BackupMemoryResponse()..mergeFromBuffer(data, registry);
  factory BackupMemoryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BackupMemoryResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BackupMemoryResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: BackupMemoryResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'snapshotId')
    ..aOS(3, _omitFieldNames ? '' : 'agentId')
    ..aI(4, _omitFieldNames ? '' : 'recordCount')
    ..aOS(5, _omitFieldNames ? '' : 'filePath')
    ..aOS(6, _omitFieldNames ? '' : 'capturedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupMemoryResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupMemoryResponse copyWith(void Function(BackupMemoryResponse) updates) =>
      super.copyWith((message) => updates(message as BackupMemoryResponse))
          as BackupMemoryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use BackupMemoryResponse() / BackupMemoryResponse.new instead')
  static BackupMemoryResponse create() => BackupMemoryResponse._();
  static $pb.GeneratedMessage $_createMessage() => BackupMemoryResponse._();
  @$core.override
  BackupMemoryResponse createEmptyInstance() => BackupMemoryResponse._();
  @$core.pragma('dart2js:noInline')
  static BackupMemoryResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BackupMemoryResponse>(
          BackupMemoryResponse.$_createMessage);
  static BackupMemoryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get snapshotId => $_getSZ(1);
  @$pb.TagNumber(2)
  set snapshotId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSnapshotId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSnapshotId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get agentId => $_getSZ(2);
  @$pb.TagNumber(3)
  set agentId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAgentId() => $_has(2);
  @$pb.TagNumber(3)
  void clearAgentId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get recordCount => $_getIZ(3);
  @$pb.TagNumber(4)
  set recordCount($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRecordCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearRecordCount() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get filePath => $_getSZ(4);
  @$pb.TagNumber(5)
  set filePath($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFilePath() => $_has(4);
  @$pb.TagNumber(5)
  void clearFilePath() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get capturedAt => $_getSZ(5);
  @$pb.TagNumber(6)
  set capturedAt($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCapturedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearCapturedAt() => $_clearField(6);
}

class SkillInfo extends $pb.GeneratedMessage {
  factory SkillInfo({
    $core.String? id,
    $core.String? name,
    $core.String? description,
    $core.String? category,
    $core.String? reasoningMode,
    $core.bool? mutatesWorkspace,
    $core.Iterable<$core.String>? allowedTools,
    $core.String? sourcePath,
    $core.bool? inTrash,
  }) {
    final result = SkillInfo._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (category != null) result.category = category;
    if (reasoningMode != null) result.reasoningMode = reasoningMode;
    if (mutatesWorkspace != null) result.mutatesWorkspace = mutatesWorkspace;
    if (allowedTools != null) result.allowedTools.addAll(allowedTools);
    if (sourcePath != null) result.sourcePath = sourcePath;
    if (inTrash != null) result.inTrash = inTrash;
    return result;
  }

  SkillInfo._();

  factory SkillInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SkillInfo()..mergeFromBuffer(data, registry);
  factory SkillInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SkillInfo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SkillInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: SkillInfo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..aOS(4, _omitFieldNames ? '' : 'category')
    ..aOS(5, _omitFieldNames ? '' : 'reasoningMode')
    ..aOB(6, _omitFieldNames ? '' : 'mutatesWorkspace')
    ..pPS(7, _omitFieldNames ? '' : 'allowedTools')
    ..aOS(8, _omitFieldNames ? '' : 'sourcePath')
    ..aOB(9, _omitFieldNames ? '' : 'inTrash')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SkillInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SkillInfo copyWith(void Function(SkillInfo) updates) =>
      super.copyWith((message) => updates(message as SkillInfo)) as SkillInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SkillInfo() / SkillInfo.new instead')
  static SkillInfo create() => SkillInfo._();
  static $pb.GeneratedMessage $_createMessage() => SkillInfo._();
  @$core.override
  SkillInfo createEmptyInstance() => SkillInfo._();
  @$core.pragma('dart2js:noInline')
  static SkillInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SkillInfo>(SkillInfo.$_createMessage);
  static SkillInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get category => $_getSZ(3);
  @$pb.TagNumber(4)
  set category($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCategory() => $_has(3);
  @$pb.TagNumber(4)
  void clearCategory() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get reasoningMode => $_getSZ(4);
  @$pb.TagNumber(5)
  set reasoningMode($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasReasoningMode() => $_has(4);
  @$pb.TagNumber(5)
  void clearReasoningMode() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get mutatesWorkspace => $_getBF(5);
  @$pb.TagNumber(6)
  set mutatesWorkspace($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMutatesWorkspace() => $_has(5);
  @$pb.TagNumber(6)
  void clearMutatesWorkspace() => $_clearField(6);

  @$pb.TagNumber(7)
  $pb.PbList<$core.String> get allowedTools => $_getList(6);

  @$pb.TagNumber(8)
  $core.String get sourcePath => $_getSZ(7);
  @$pb.TagNumber(8)
  set sourcePath($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSourcePath() => $_has(7);
  @$pb.TagNumber(8)
  void clearSourcePath() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get inTrash => $_getBF(8);
  @$pb.TagNumber(9)
  set inTrash($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasInTrash() => $_has(8);
  @$pb.TagNumber(9)
  void clearInTrash() => $_clearField(9);
}

class SkillDetail extends $pb.GeneratedMessage {
  factory SkillDetail({
    SkillInfo? info,
    $core.String? instructions,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? references,
    $core.Iterable<$core.String>? scripts,
    $core.String? rawMarkdown,
  }) {
    final result = SkillDetail._();
    if (info != null) result.info = info;
    if (instructions != null) result.instructions = instructions;
    if (references != null) result.references.addEntries(references);
    if (scripts != null) result.scripts.addAll(scripts);
    if (rawMarkdown != null) result.rawMarkdown = rawMarkdown;
    return result;
  }

  SkillDetail._();

  factory SkillDetail.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SkillDetail()..mergeFromBuffer(data, registry);
  factory SkillDetail.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SkillDetail()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SkillDetail',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: SkillDetail.$_createMessage)
    ..aOM<SkillInfo>(1, _omitFieldNames ? '' : 'info',
        subBuilder: SkillInfo.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'instructions')
    ..m<$core.String, $core.String>(3, _omitFieldNames ? '' : 'references',
        entryClassName: 'SkillDetail.ReferencesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('andalus'))
    ..pPS(4, _omitFieldNames ? '' : 'scripts')
    ..aOS(5, _omitFieldNames ? '' : 'rawMarkdown')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SkillDetail clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SkillDetail copyWith(void Function(SkillDetail) updates) =>
      super.copyWith((message) => updates(message as SkillDetail))
          as SkillDetail;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SkillDetail() / SkillDetail.new instead')
  static SkillDetail create() => SkillDetail._();
  static $pb.GeneratedMessage $_createMessage() => SkillDetail._();
  @$core.override
  SkillDetail createEmptyInstance() => SkillDetail._();
  @$core.pragma('dart2js:noInline')
  static SkillDetail getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SkillDetail>(
          SkillDetail.$_createMessage);
  static SkillDetail? _defaultInstance;

  @$pb.TagNumber(1)
  SkillInfo get info => $_getN(0);
  @$pb.TagNumber(1)
  set info(SkillInfo value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasInfo() => $_has(0);
  @$pb.TagNumber(1)
  void clearInfo() => $_clearField(1);
  @$pb.TagNumber(1)
  SkillInfo ensureInfo() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get instructions => $_getSZ(1);
  @$pb.TagNumber(2)
  set instructions($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasInstructions() => $_has(1);
  @$pb.TagNumber(2)
  void clearInstructions() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbMap<$core.String, $core.String> get references => $_getMap(2);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get scripts => $_getList(3);

  @$pb.TagNumber(5)
  $core.String get rawMarkdown => $_getSZ(4);
  @$pb.TagNumber(5)
  set rawMarkdown($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRawMarkdown() => $_has(4);
  @$pb.TagNumber(5)
  void clearRawMarkdown() => $_clearField(5);
}

class ListSkillsRequest extends $pb.GeneratedMessage {
  factory ListSkillsRequest({
    $core.String? category,
    $core.String? query,
    $core.bool? includeTrash,
  }) {
    final result = ListSkillsRequest._();
    if (category != null) result.category = category;
    if (query != null) result.query = query;
    if (includeTrash != null) result.includeTrash = includeTrash;
    return result;
  }

  ListSkillsRequest._();

  factory ListSkillsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListSkillsRequest()..mergeFromBuffer(data, registry);
  factory ListSkillsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListSkillsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListSkillsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ListSkillsRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'category')
    ..aOS(2, _omitFieldNames ? '' : 'query')
    ..aOB(3, _omitFieldNames ? '' : 'includeTrash')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSkillsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSkillsRequest copyWith(void Function(ListSkillsRequest) updates) =>
      super.copyWith((message) => updates(message as ListSkillsRequest))
          as ListSkillsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListSkillsRequest() / ListSkillsRequest.new instead')
  static ListSkillsRequest create() => ListSkillsRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListSkillsRequest._();
  @$core.override
  ListSkillsRequest createEmptyInstance() => ListSkillsRequest._();
  @$core.pragma('dart2js:noInline')
  static ListSkillsRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListSkillsRequest>(
          ListSkillsRequest.$_createMessage);
  static ListSkillsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get category => $_getSZ(0);
  @$pb.TagNumber(1)
  set category($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCategory() => $_has(0);
  @$pb.TagNumber(1)
  void clearCategory() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get query => $_getSZ(1);
  @$pb.TagNumber(2)
  set query($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasQuery() => $_has(1);
  @$pb.TagNumber(2)
  void clearQuery() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get includeTrash => $_getBF(2);
  @$pb.TagNumber(3)
  set includeTrash($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIncludeTrash() => $_has(2);
  @$pb.TagNumber(3)
  void clearIncludeTrash() => $_clearField(3);
}

class ListSkillsResponse extends $pb.GeneratedMessage {
  factory ListSkillsResponse({
    $core.Iterable<SkillInfo>? skills,
    $core.int? totalCount,
  }) {
    final result = ListSkillsResponse._();
    if (skills != null) result.skills.addAll(skills);
    if (totalCount != null) result.totalCount = totalCount;
    return result;
  }

  ListSkillsResponse._();

  factory ListSkillsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListSkillsResponse()..mergeFromBuffer(data, registry);
  factory ListSkillsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListSkillsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListSkillsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ListSkillsResponse.$_createMessage)
    ..pPM<SkillInfo>(1, _omitFieldNames ? '' : 'skills',
        subBuilder: SkillInfo.$_createMessage)
    ..aI(2, _omitFieldNames ? '' : 'totalCount')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSkillsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSkillsResponse copyWith(void Function(ListSkillsResponse) updates) =>
      super.copyWith((message) => updates(message as ListSkillsResponse))
          as ListSkillsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListSkillsResponse() / ListSkillsResponse.new instead')
  static ListSkillsResponse create() => ListSkillsResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListSkillsResponse._();
  @$core.override
  ListSkillsResponse createEmptyInstance() => ListSkillsResponse._();
  @$core.pragma('dart2js:noInline')
  static ListSkillsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListSkillsResponse>(
          ListSkillsResponse.$_createMessage);
  static ListSkillsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<SkillInfo> get skills => $_getList(0);

  @$pb.TagNumber(2)
  $core.int get totalCount => $_getIZ(1);
  @$pb.TagNumber(2)
  set totalCount($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotalCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalCount() => $_clearField(2);
}

class GetSkillRequest extends $pb.GeneratedMessage {
  factory GetSkillRequest({
    $core.String? skillId,
  }) {
    final result = GetSkillRequest._();
    if (skillId != null) result.skillId = skillId;
    return result;
  }

  GetSkillRequest._();

  factory GetSkillRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetSkillRequest()..mergeFromBuffer(data, registry);
  factory GetSkillRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetSkillRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetSkillRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: GetSkillRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'skillId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSkillRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSkillRequest copyWith(void Function(GetSkillRequest) updates) =>
      super.copyWith((message) => updates(message as GetSkillRequest))
          as GetSkillRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetSkillRequest() / GetSkillRequest.new instead')
  static GetSkillRequest create() => GetSkillRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetSkillRequest._();
  @$core.override
  GetSkillRequest createEmptyInstance() => GetSkillRequest._();
  @$core.pragma('dart2js:noInline')
  static GetSkillRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetSkillRequest>(
          GetSkillRequest.$_createMessage);
  static GetSkillRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get skillId => $_getSZ(0);
  @$pb.TagNumber(1)
  set skillId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSkillId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSkillId() => $_clearField(1);
}

class GetSkillResponse extends $pb.GeneratedMessage {
  factory GetSkillResponse({
    $core.bool? found,
    SkillDetail? skill,
    $core.String? message,
  }) {
    final result = GetSkillResponse._();
    if (found != null) result.found = found;
    if (skill != null) result.skill = skill;
    if (message != null) result.message = message;
    return result;
  }

  GetSkillResponse._();

  factory GetSkillResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetSkillResponse()..mergeFromBuffer(data, registry);
  factory GetSkillResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetSkillResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetSkillResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: GetSkillResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'found')
    ..aOM<SkillDetail>(2, _omitFieldNames ? '' : 'skill',
        subBuilder: SkillDetail.$_createMessage)
    ..aOS(3, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSkillResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSkillResponse copyWith(void Function(GetSkillResponse) updates) =>
      super.copyWith((message) => updates(message as GetSkillResponse))
          as GetSkillResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetSkillResponse() / GetSkillResponse.new instead')
  static GetSkillResponse create() => GetSkillResponse._();
  static $pb.GeneratedMessage $_createMessage() => GetSkillResponse._();
  @$core.override
  GetSkillResponse createEmptyInstance() => GetSkillResponse._();
  @$core.pragma('dart2js:noInline')
  static GetSkillResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetSkillResponse>(
          GetSkillResponse.$_createMessage);
  static GetSkillResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get found => $_getBF(0);
  @$pb.TagNumber(1)
  set found($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFound() => $_has(0);
  @$pb.TagNumber(1)
  void clearFound() => $_clearField(1);

  @$pb.TagNumber(2)
  SkillDetail get skill => $_getN(1);
  @$pb.TagNumber(2)
  set skill(SkillDetail value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSkill() => $_has(1);
  @$pb.TagNumber(2)
  void clearSkill() => $_clearField(2);
  @$pb.TagNumber(2)
  SkillDetail ensureSkill() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get message => $_getSZ(2);
  @$pb.TagNumber(3)
  set message($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMessage() => $_has(2);
  @$pb.TagNumber(3)
  void clearMessage() => $_clearField(3);
}

class SaveSkillRequest extends $pb.GeneratedMessage {
  factory SaveSkillRequest({
    $core.String? id,
    $core.String? name,
    $core.String? description,
    $core.String? category,
    $core.String? reasoningMode,
    $core.bool? mutatesWorkspace,
    $core.Iterable<$core.String>? allowedTools,
    $core.String? instructions,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? references,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? scripts,
  }) {
    final result = SaveSkillRequest._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (category != null) result.category = category;
    if (reasoningMode != null) result.reasoningMode = reasoningMode;
    if (mutatesWorkspace != null) result.mutatesWorkspace = mutatesWorkspace;
    if (allowedTools != null) result.allowedTools.addAll(allowedTools);
    if (instructions != null) result.instructions = instructions;
    if (references != null) result.references.addEntries(references);
    if (scripts != null) result.scripts.addEntries(scripts);
    return result;
  }

  SaveSkillRequest._();

  factory SaveSkillRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SaveSkillRequest()..mergeFromBuffer(data, registry);
  factory SaveSkillRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SaveSkillRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SaveSkillRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: SaveSkillRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..aOS(4, _omitFieldNames ? '' : 'category')
    ..aOS(5, _omitFieldNames ? '' : 'reasoningMode')
    ..aOB(6, _omitFieldNames ? '' : 'mutatesWorkspace')
    ..pPS(7, _omitFieldNames ? '' : 'allowedTools')
    ..aOS(8, _omitFieldNames ? '' : 'instructions')
    ..m<$core.String, $core.String>(9, _omitFieldNames ? '' : 'references',
        entryClassName: 'SaveSkillRequest.ReferencesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('andalus'))
    ..m<$core.String, $core.String>(10, _omitFieldNames ? '' : 'scripts',
        entryClassName: 'SaveSkillRequest.ScriptsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('andalus'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveSkillRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveSkillRequest copyWith(void Function(SaveSkillRequest) updates) =>
      super.copyWith((message) => updates(message as SaveSkillRequest))
          as SaveSkillRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SaveSkillRequest() / SaveSkillRequest.new instead')
  static SaveSkillRequest create() => SaveSkillRequest._();
  static $pb.GeneratedMessage $_createMessage() => SaveSkillRequest._();
  @$core.override
  SaveSkillRequest createEmptyInstance() => SaveSkillRequest._();
  @$core.pragma('dart2js:noInline')
  static SaveSkillRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SaveSkillRequest>(
          SaveSkillRequest.$_createMessage);
  static SaveSkillRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get category => $_getSZ(3);
  @$pb.TagNumber(4)
  set category($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCategory() => $_has(3);
  @$pb.TagNumber(4)
  void clearCategory() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get reasoningMode => $_getSZ(4);
  @$pb.TagNumber(5)
  set reasoningMode($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasReasoningMode() => $_has(4);
  @$pb.TagNumber(5)
  void clearReasoningMode() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get mutatesWorkspace => $_getBF(5);
  @$pb.TagNumber(6)
  set mutatesWorkspace($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMutatesWorkspace() => $_has(5);
  @$pb.TagNumber(6)
  void clearMutatesWorkspace() => $_clearField(6);

  @$pb.TagNumber(7)
  $pb.PbList<$core.String> get allowedTools => $_getList(6);

  @$pb.TagNumber(8)
  $core.String get instructions => $_getSZ(7);
  @$pb.TagNumber(8)
  set instructions($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasInstructions() => $_has(7);
  @$pb.TagNumber(8)
  void clearInstructions() => $_clearField(8);

  @$pb.TagNumber(9)
  $pb.PbMap<$core.String, $core.String> get references => $_getMap(8);

  @$pb.TagNumber(10)
  $pb.PbMap<$core.String, $core.String> get scripts => $_getMap(9);
}

class SaveSkillResponse extends $pb.GeneratedMessage {
  factory SaveSkillResponse({
    $core.bool? success,
    $core.String? skillId,
    $core.String? message,
    $core.String? sourcePath,
  }) {
    final result = SaveSkillResponse._();
    if (success != null) result.success = success;
    if (skillId != null) result.skillId = skillId;
    if (message != null) result.message = message;
    if (sourcePath != null) result.sourcePath = sourcePath;
    return result;
  }

  SaveSkillResponse._();

  factory SaveSkillResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SaveSkillResponse()..mergeFromBuffer(data, registry);
  factory SaveSkillResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SaveSkillResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SaveSkillResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: SaveSkillResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'skillId')
    ..aOS(3, _omitFieldNames ? '' : 'message')
    ..aOS(4, _omitFieldNames ? '' : 'sourcePath')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveSkillResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveSkillResponse copyWith(void Function(SaveSkillResponse) updates) =>
      super.copyWith((message) => updates(message as SaveSkillResponse))
          as SaveSkillResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SaveSkillResponse() / SaveSkillResponse.new instead')
  static SaveSkillResponse create() => SaveSkillResponse._();
  static $pb.GeneratedMessage $_createMessage() => SaveSkillResponse._();
  @$core.override
  SaveSkillResponse createEmptyInstance() => SaveSkillResponse._();
  @$core.pragma('dart2js:noInline')
  static SaveSkillResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SaveSkillResponse>(
          SaveSkillResponse.$_createMessage);
  static SaveSkillResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get skillId => $_getSZ(1);
  @$pb.TagNumber(2)
  set skillId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSkillId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSkillId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get message => $_getSZ(2);
  @$pb.TagNumber(3)
  set message($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMessage() => $_has(2);
  @$pb.TagNumber(3)
  void clearMessage() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get sourcePath => $_getSZ(3);
  @$pb.TagNumber(4)
  set sourcePath($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSourcePath() => $_has(3);
  @$pb.TagNumber(4)
  void clearSourcePath() => $_clearField(4);
}

class DeleteSkillRequest extends $pb.GeneratedMessage {
  factory DeleteSkillRequest({
    $core.String? skillId,
    $core.bool? hardDelete,
  }) {
    final result = DeleteSkillRequest._();
    if (skillId != null) result.skillId = skillId;
    if (hardDelete != null) result.hardDelete = hardDelete;
    return result;
  }

  DeleteSkillRequest._();

  factory DeleteSkillRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteSkillRequest()..mergeFromBuffer(data, registry);
  factory DeleteSkillRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteSkillRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteSkillRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: DeleteSkillRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'skillId')
    ..aOB(2, _omitFieldNames ? '' : 'hardDelete')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteSkillRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteSkillRequest copyWith(void Function(DeleteSkillRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteSkillRequest))
          as DeleteSkillRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DeleteSkillRequest() / DeleteSkillRequest.new instead')
  static DeleteSkillRequest create() => DeleteSkillRequest._();
  static $pb.GeneratedMessage $_createMessage() => DeleteSkillRequest._();
  @$core.override
  DeleteSkillRequest createEmptyInstance() => DeleteSkillRequest._();
  @$core.pragma('dart2js:noInline')
  static DeleteSkillRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteSkillRequest>(
          DeleteSkillRequest.$_createMessage);
  static DeleteSkillRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get skillId => $_getSZ(0);
  @$pb.TagNumber(1)
  set skillId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSkillId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSkillId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get hardDelete => $_getBF(1);
  @$pb.TagNumber(2)
  set hardDelete($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHardDelete() => $_has(1);
  @$pb.TagNumber(2)
  void clearHardDelete() => $_clearField(2);
}

class DeleteSkillResponse extends $pb.GeneratedMessage {
  factory DeleteSkillResponse({
    $core.bool? success,
    $core.String? skillId,
    $core.bool? movedToTrash,
    $core.String? trashPath,
    $core.String? message,
  }) {
    final result = DeleteSkillResponse._();
    if (success != null) result.success = success;
    if (skillId != null) result.skillId = skillId;
    if (movedToTrash != null) result.movedToTrash = movedToTrash;
    if (trashPath != null) result.trashPath = trashPath;
    if (message != null) result.message = message;
    return result;
  }

  DeleteSkillResponse._();

  factory DeleteSkillResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteSkillResponse()..mergeFromBuffer(data, registry);
  factory DeleteSkillResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteSkillResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteSkillResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: DeleteSkillResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'skillId')
    ..aOB(3, _omitFieldNames ? '' : 'movedToTrash')
    ..aOS(4, _omitFieldNames ? '' : 'trashPath')
    ..aOS(5, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteSkillResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteSkillResponse copyWith(void Function(DeleteSkillResponse) updates) =>
      super.copyWith((message) => updates(message as DeleteSkillResponse))
          as DeleteSkillResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use DeleteSkillResponse() / DeleteSkillResponse.new instead')
  static DeleteSkillResponse create() => DeleteSkillResponse._();
  static $pb.GeneratedMessage $_createMessage() => DeleteSkillResponse._();
  @$core.override
  DeleteSkillResponse createEmptyInstance() => DeleteSkillResponse._();
  @$core.pragma('dart2js:noInline')
  static DeleteSkillResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteSkillResponse>(
          DeleteSkillResponse.$_createMessage);
  static DeleteSkillResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get skillId => $_getSZ(1);
  @$pb.TagNumber(2)
  set skillId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSkillId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSkillId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get movedToTrash => $_getBF(2);
  @$pb.TagNumber(3)
  set movedToTrash($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMovedToTrash() => $_has(2);
  @$pb.TagNumber(3)
  void clearMovedToTrash() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get trashPath => $_getSZ(3);
  @$pb.TagNumber(4)
  set trashPath($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTrashPath() => $_has(3);
  @$pb.TagNumber(4)
  void clearTrashPath() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get message => $_getSZ(4);
  @$pb.TagNumber(5)
  set message($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMessage() => $_has(4);
  @$pb.TagNumber(5)
  void clearMessage() => $_clearField(5);
}

class RestoreSkillRequest extends $pb.GeneratedMessage {
  factory RestoreSkillRequest({
    $core.String? skillId,
  }) {
    final result = RestoreSkillRequest._();
    if (skillId != null) result.skillId = skillId;
    return result;
  }

  RestoreSkillRequest._();

  factory RestoreSkillRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RestoreSkillRequest()..mergeFromBuffer(data, registry);
  factory RestoreSkillRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RestoreSkillRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RestoreSkillRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: RestoreSkillRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'skillId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestoreSkillRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestoreSkillRequest copyWith(void Function(RestoreSkillRequest) updates) =>
      super.copyWith((message) => updates(message as RestoreSkillRequest))
          as RestoreSkillRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use RestoreSkillRequest() / RestoreSkillRequest.new instead')
  static RestoreSkillRequest create() => RestoreSkillRequest._();
  static $pb.GeneratedMessage $_createMessage() => RestoreSkillRequest._();
  @$core.override
  RestoreSkillRequest createEmptyInstance() => RestoreSkillRequest._();
  @$core.pragma('dart2js:noInline')
  static RestoreSkillRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RestoreSkillRequest>(
          RestoreSkillRequest.$_createMessage);
  static RestoreSkillRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get skillId => $_getSZ(0);
  @$pb.TagNumber(1)
  set skillId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSkillId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSkillId() => $_clearField(1);
}

class RestoreSkillResponse extends $pb.GeneratedMessage {
  factory RestoreSkillResponse({
    $core.bool? success,
    $core.String? skillId,
    $core.String? restoredPath,
    $core.String? message,
  }) {
    final result = RestoreSkillResponse._();
    if (success != null) result.success = success;
    if (skillId != null) result.skillId = skillId;
    if (restoredPath != null) result.restoredPath = restoredPath;
    if (message != null) result.message = message;
    return result;
  }

  RestoreSkillResponse._();

  factory RestoreSkillResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RestoreSkillResponse()..mergeFromBuffer(data, registry);
  factory RestoreSkillResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RestoreSkillResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RestoreSkillResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: RestoreSkillResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'skillId')
    ..aOS(3, _omitFieldNames ? '' : 'restoredPath')
    ..aOS(4, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestoreSkillResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestoreSkillResponse copyWith(void Function(RestoreSkillResponse) updates) =>
      super.copyWith((message) => updates(message as RestoreSkillResponse))
          as RestoreSkillResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RestoreSkillResponse() / RestoreSkillResponse.new instead')
  static RestoreSkillResponse create() => RestoreSkillResponse._();
  static $pb.GeneratedMessage $_createMessage() => RestoreSkillResponse._();
  @$core.override
  RestoreSkillResponse createEmptyInstance() => RestoreSkillResponse._();
  @$core.pragma('dart2js:noInline')
  static RestoreSkillResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RestoreSkillResponse>(
          RestoreSkillResponse.$_createMessage);
  static RestoreSkillResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get skillId => $_getSZ(1);
  @$pb.TagNumber(2)
  set skillId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSkillId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSkillId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get restoredPath => $_getSZ(2);
  @$pb.TagNumber(3)
  set restoredPath($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRestoredPath() => $_has(2);
  @$pb.TagNumber(3)
  void clearRestoredPath() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get message => $_getSZ(3);
  @$pb.TagNumber(4)
  set message($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMessage() => $_has(3);
  @$pb.TagNumber(4)
  void clearMessage() => $_clearField(4);
}

class ReloadSkillsResponse extends $pb.GeneratedMessage {
  factory ReloadSkillsResponse({
    $core.bool? success,
    $core.int? reloadedCount,
    $core.String? message,
  }) {
    final result = ReloadSkillsResponse._();
    if (success != null) result.success = success;
    if (reloadedCount != null) result.reloadedCount = reloadedCount;
    if (message != null) result.message = message;
    return result;
  }

  ReloadSkillsResponse._();

  factory ReloadSkillsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReloadSkillsResponse()..mergeFromBuffer(data, registry);
  factory ReloadSkillsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReloadSkillsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReloadSkillsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'andalus'),
      createEmptyInstance: ReloadSkillsResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aI(2, _omitFieldNames ? '' : 'reloadedCount')
    ..aOS(3, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReloadSkillsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReloadSkillsResponse copyWith(void Function(ReloadSkillsResponse) updates) =>
      super.copyWith((message) => updates(message as ReloadSkillsResponse))
          as ReloadSkillsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ReloadSkillsResponse() / ReloadSkillsResponse.new instead')
  static ReloadSkillsResponse create() => ReloadSkillsResponse._();
  static $pb.GeneratedMessage $_createMessage() => ReloadSkillsResponse._();
  @$core.override
  ReloadSkillsResponse createEmptyInstance() => ReloadSkillsResponse._();
  @$core.pragma('dart2js:noInline')
  static ReloadSkillsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReloadSkillsResponse>(
          ReloadSkillsResponse.$_createMessage);
  static ReloadSkillsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get reloadedCount => $_getIZ(1);
  @$pb.TagNumber(2)
  set reloadedCount($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReloadedCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearReloadedCount() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get message => $_getSZ(2);
  @$pb.TagNumber(3)
  set message($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMessage() => $_has(2);
  @$pb.TagNumber(3)
  void clearMessage() => $_clearField(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
