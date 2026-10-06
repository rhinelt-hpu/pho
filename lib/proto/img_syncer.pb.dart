//
//  Generated code. Do not modify.
//  source: proto/img_syncer.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'img_syncer.pbenum.dart';

export 'img_syncer.pbenum.dart';

class SetDirectoryTypeRequest extends $pb.GeneratedMessage {
  factory SetDirectoryTypeRequest({
    DirectoryType? directoryType,
  }) {
    final $result = create();
    if (directoryType != null) {
      $result.directoryType = directoryType;
    }
    return $result;
  }
  SetDirectoryTypeRequest._() : super();
  factory SetDirectoryTypeRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SetDirectoryTypeRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SetDirectoryTypeRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..e<DirectoryType>(1, _omitFieldNames ? '' : 'directoryType', $pb.PbFieldType.OE, protoName: 'directoryType', defaultOrMaker: DirectoryType.DIRECTORY_TYPE_01, valueOf: DirectoryType.valueOf, enumValues: DirectoryType.values)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SetDirectoryTypeRequest clone() => SetDirectoryTypeRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SetDirectoryTypeRequest copyWith(void Function(SetDirectoryTypeRequest) updates) => super.copyWith((message) => updates(message as SetDirectoryTypeRequest)) as SetDirectoryTypeRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetDirectoryTypeRequest create() => SetDirectoryTypeRequest._();
  SetDirectoryTypeRequest createEmptyInstance() => create();
  static $pb.PbList<SetDirectoryTypeRequest> createRepeated() => $pb.PbList<SetDirectoryTypeRequest>();
  @$core.pragma('dart2js:noInline')
  static SetDirectoryTypeRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetDirectoryTypeRequest>(create);
  static SetDirectoryTypeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  DirectoryType get directoryType => $_getN(0);
  @$pb.TagNumber(1)
  set directoryType(DirectoryType v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasDirectoryType() => $_has(0);
  @$pb.TagNumber(1)
  void clearDirectoryType() => clearField(1);
}

class SetDirectoryTypeResponse extends $pb.GeneratedMessage {
  factory SetDirectoryTypeResponse({
    $core.bool? success,
    $core.String? message,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (message != null) {
      $result.message = message;
    }
    return $result;
  }
  SetDirectoryTypeResponse._() : super();
  factory SetDirectoryTypeResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SetDirectoryTypeResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SetDirectoryTypeResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SetDirectoryTypeResponse clone() => SetDirectoryTypeResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SetDirectoryTypeResponse copyWith(void Function(SetDirectoryTypeResponse) updates) => super.copyWith((message) => updates(message as SetDirectoryTypeResponse)) as SetDirectoryTypeResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetDirectoryTypeResponse create() => SetDirectoryTypeResponse._();
  SetDirectoryTypeResponse createEmptyInstance() => create();
  static $pb.PbList<SetDirectoryTypeResponse> createRepeated() => $pb.PbList<SetDirectoryTypeResponse>();
  @$core.pragma('dart2js:noInline')
  static SetDirectoryTypeResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetDirectoryTypeResponse>(create);
  static SetDirectoryTypeResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);
}

class FileInfo extends $pb.GeneratedMessage {
  factory FileInfo({
    $core.String? path,
    $fixnum.Int64? size,
    $core.bool? isLivePhoto,
  }) {
    final $result = create();
    if (path != null) {
      $result.path = path;
    }
    if (size != null) {
      $result.size = size;
    }
    if (isLivePhoto != null) {
      $result.isLivePhoto = isLivePhoto;
    }
    return $result;
  }
  FileInfo._() : super();
  factory FileInfo.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory FileInfo.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'FileInfo', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..aInt64(2, _omitFieldNames ? '' : 'size')
    ..aOB(3, _omitFieldNames ? '' : 'isLivePhoto', protoName: 'isLivePhoto')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  FileInfo clone() => FileInfo()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  FileInfo copyWith(void Function(FileInfo) updates) => super.copyWith((message) => updates(message as FileInfo)) as FileInfo;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FileInfo create() => FileInfo._();
  FileInfo createEmptyInstance() => create();
  static $pb.PbList<FileInfo> createRepeated() => $pb.PbList<FileInfo>();
  @$core.pragma('dart2js:noInline')
  static FileInfo getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FileInfo>(create);
  static FileInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get size => $_getI64(1);
  @$pb.TagNumber(2)
  set size($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearSize() => clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isLivePhoto => $_getBF(2);
  @$pb.TagNumber(3)
  set isLivePhoto($core.bool v) { $_setBool(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasIsLivePhoto() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsLivePhoto() => clearField(3);
}

class ListByDateRequest extends $pb.GeneratedMessage {
  factory ListByDateRequest({
    $core.String? date,
    $core.int? offset,
    $core.int? maxReturn,
    $core.String? album,
  }) {
    final $result = create();
    if (date != null) {
      $result.date = date;
    }
    if (offset != null) {
      $result.offset = offset;
    }
    if (maxReturn != null) {
      $result.maxReturn = maxReturn;
    }
    if (album != null) {
      $result.album = album;
    }
    return $result;
  }
  ListByDateRequest._() : super();
  factory ListByDateRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListByDateRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListByDateRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'date')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'offset', $pb.PbFieldType.O3)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'maxReturn', $pb.PbFieldType.O3, protoName: 'maxReturn')
    ..aOS(4, _omitFieldNames ? '' : 'album')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListByDateRequest clone() => ListByDateRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListByDateRequest copyWith(void Function(ListByDateRequest) updates) => super.copyWith((message) => updates(message as ListByDateRequest)) as ListByDateRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListByDateRequest create() => ListByDateRequest._();
  ListByDateRequest createEmptyInstance() => create();
  static $pb.PbList<ListByDateRequest> createRepeated() => $pb.PbList<ListByDateRequest>();
  @$core.pragma('dart2js:noInline')
  static ListByDateRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListByDateRequest>(create);
  static ListByDateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get date => $_getSZ(0);
  @$pb.TagNumber(1)
  set date($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasDate() => $_has(0);
  @$pb.TagNumber(1)
  void clearDate() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get offset => $_getIZ(1);
  @$pb.TagNumber(2)
  set offset($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasOffset() => $_has(1);
  @$pb.TagNumber(2)
  void clearOffset() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get maxReturn => $_getIZ(2);
  @$pb.TagNumber(3)
  set maxReturn($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasMaxReturn() => $_has(2);
  @$pb.TagNumber(3)
  void clearMaxReturn() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get album => $_getSZ(3);
  @$pb.TagNumber(4)
  set album($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasAlbum() => $_has(3);
  @$pb.TagNumber(4)
  void clearAlbum() => clearField(4);
}

class ListByDateResponse extends $pb.GeneratedMessage {
  factory ListByDateResponse({
    $core.bool? success,
    $core.String? message,
    $core.Iterable<FileInfo>? infos,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (message != null) {
      $result.message = message;
    }
    if (infos != null) {
      $result.infos.addAll(infos);
    }
    return $result;
  }
  ListByDateResponse._() : super();
  factory ListByDateResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListByDateResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListByDateResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..pc<FileInfo>(3, _omitFieldNames ? '' : 'infos', $pb.PbFieldType.PM, subBuilder: FileInfo.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListByDateResponse clone() => ListByDateResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListByDateResponse copyWith(void Function(ListByDateResponse) updates) => super.copyWith((message) => updates(message as ListByDateResponse)) as ListByDateResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListByDateResponse create() => ListByDateResponse._();
  ListByDateResponse createEmptyInstance() => create();
  static $pb.PbList<ListByDateResponse> createRepeated() => $pb.PbList<ListByDateResponse>();
  @$core.pragma('dart2js:noInline')
  static ListByDateResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListByDateResponse>(create);
  static ListByDateResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<FileInfo> get infos => $_getList(2);
}

class DeleteRequest extends $pb.GeneratedMessage {
  factory DeleteRequest({
    $core.Iterable<$core.String>? paths,
  }) {
    final $result = create();
    if (paths != null) {
      $result.paths.addAll(paths);
    }
    return $result;
  }
  DeleteRequest._() : super();
  factory DeleteRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DeleteRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DeleteRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'paths')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DeleteRequest clone() => DeleteRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DeleteRequest copyWith(void Function(DeleteRequest) updates) => super.copyWith((message) => updates(message as DeleteRequest)) as DeleteRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteRequest create() => DeleteRequest._();
  DeleteRequest createEmptyInstance() => create();
  static $pb.PbList<DeleteRequest> createRepeated() => $pb.PbList<DeleteRequest>();
  @$core.pragma('dart2js:noInline')
  static DeleteRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DeleteRequest>(create);
  static DeleteRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.String> get paths => $_getList(0);
}

class DeleteResponse extends $pb.GeneratedMessage {
  factory DeleteResponse({
    $core.bool? success,
    $core.String? message,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (message != null) {
      $result.message = message;
    }
    return $result;
  }
  DeleteResponse._() : super();
  factory DeleteResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DeleteResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DeleteResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DeleteResponse clone() => DeleteResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DeleteResponse copyWith(void Function(DeleteResponse) updates) => super.copyWith((message) => updates(message as DeleteResponse)) as DeleteResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteResponse create() => DeleteResponse._();
  DeleteResponse createEmptyInstance() => create();
  static $pb.PbList<DeleteResponse> createRepeated() => $pb.PbList<DeleteResponse>();
  @$core.pragma('dart2js:noInline')
  static DeleteResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DeleteResponse>(create);
  static DeleteResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);
}

class AlbumInfo extends $pb.GeneratedMessage {
  factory AlbumInfo({
    $core.String? name,
    $fixnum.Int64? count,
    $core.String? coverPath,
    $core.bool? isDefault,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (count != null) {
      $result.count = count;
    }
    if (coverPath != null) {
      $result.coverPath = coverPath;
    }
    if (isDefault != null) {
      $result.isDefault = isDefault;
    }
    return $result;
  }
  AlbumInfo._() : super();
  factory AlbumInfo.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory AlbumInfo.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'AlbumInfo', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aInt64(2, _omitFieldNames ? '' : 'count')
    ..aOS(3, _omitFieldNames ? '' : 'coverPath', protoName: 'coverPath')
    ..aOB(4, _omitFieldNames ? '' : 'isDefault', protoName: 'isDefault')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  AlbumInfo clone() => AlbumInfo()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  AlbumInfo copyWith(void Function(AlbumInfo) updates) => super.copyWith((message) => updates(message as AlbumInfo)) as AlbumInfo;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AlbumInfo create() => AlbumInfo._();
  AlbumInfo createEmptyInstance() => create();
  static $pb.PbList<AlbumInfo> createRepeated() => $pb.PbList<AlbumInfo>();
  @$core.pragma('dart2js:noInline')
  static AlbumInfo getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AlbumInfo>(create);
  static AlbumInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get count => $_getI64(1);
  @$pb.TagNumber(2)
  set count($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearCount() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get coverPath => $_getSZ(2);
  @$pb.TagNumber(3)
  set coverPath($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasCoverPath() => $_has(2);
  @$pb.TagNumber(3)
  void clearCoverPath() => clearField(3);

  @$pb.TagNumber(4)
  $core.bool get isDefault => $_getBF(3);
  @$pb.TagNumber(4)
  set isDefault($core.bool v) { $_setBool(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasIsDefault() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsDefault() => clearField(4);
}

class ListAlbumsRequest extends $pb.GeneratedMessage {
  factory ListAlbumsRequest() => create();
  ListAlbumsRequest._() : super();
  factory ListAlbumsRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListAlbumsRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListAlbumsRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListAlbumsRequest clone() => ListAlbumsRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListAlbumsRequest copyWith(void Function(ListAlbumsRequest) updates) => super.copyWith((message) => updates(message as ListAlbumsRequest)) as ListAlbumsRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListAlbumsRequest create() => ListAlbumsRequest._();
  ListAlbumsRequest createEmptyInstance() => create();
  static $pb.PbList<ListAlbumsRequest> createRepeated() => $pb.PbList<ListAlbumsRequest>();
  @$core.pragma('dart2js:noInline')
  static ListAlbumsRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListAlbumsRequest>(create);
  static ListAlbumsRequest? _defaultInstance;
}

class ListAlbumsResponse extends $pb.GeneratedMessage {
  factory ListAlbumsResponse({
    $core.bool? success,
    $core.String? message,
    $core.Iterable<AlbumInfo>? albums,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (message != null) {
      $result.message = message;
    }
    if (albums != null) {
      $result.albums.addAll(albums);
    }
    return $result;
  }
  ListAlbumsResponse._() : super();
  factory ListAlbumsResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListAlbumsResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListAlbumsResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..pc<AlbumInfo>(3, _omitFieldNames ? '' : 'albums', $pb.PbFieldType.PM, subBuilder: AlbumInfo.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListAlbumsResponse clone() => ListAlbumsResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListAlbumsResponse copyWith(void Function(ListAlbumsResponse) updates) => super.copyWith((message) => updates(message as ListAlbumsResponse)) as ListAlbumsResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListAlbumsResponse create() => ListAlbumsResponse._();
  ListAlbumsResponse createEmptyInstance() => create();
  static $pb.PbList<ListAlbumsResponse> createRepeated() => $pb.PbList<ListAlbumsResponse>();
  @$core.pragma('dart2js:noInline')
  static ListAlbumsResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListAlbumsResponse>(create);
  static ListAlbumsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<AlbumInfo> get albums => $_getList(2);
}

class CreateAlbumRequest extends $pb.GeneratedMessage {
  factory CreateAlbumRequest({
    $core.String? name,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    return $result;
  }
  CreateAlbumRequest._() : super();
  factory CreateAlbumRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CreateAlbumRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CreateAlbumRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CreateAlbumRequest clone() => CreateAlbumRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CreateAlbumRequest copyWith(void Function(CreateAlbumRequest) updates) => super.copyWith((message) => updates(message as CreateAlbumRequest)) as CreateAlbumRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateAlbumRequest create() => CreateAlbumRequest._();
  CreateAlbumRequest createEmptyInstance() => create();
  static $pb.PbList<CreateAlbumRequest> createRepeated() => $pb.PbList<CreateAlbumRequest>();
  @$core.pragma('dart2js:noInline')
  static CreateAlbumRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CreateAlbumRequest>(create);
  static CreateAlbumRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);
}

class CreateAlbumResponse extends $pb.GeneratedMessage {
  factory CreateAlbumResponse({
    $core.bool? success,
    $core.String? message,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (message != null) {
      $result.message = message;
    }
    return $result;
  }
  CreateAlbumResponse._() : super();
  factory CreateAlbumResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CreateAlbumResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CreateAlbumResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CreateAlbumResponse clone() => CreateAlbumResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CreateAlbumResponse copyWith(void Function(CreateAlbumResponse) updates) => super.copyWith((message) => updates(message as CreateAlbumResponse)) as CreateAlbumResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateAlbumResponse create() => CreateAlbumResponse._();
  CreateAlbumResponse createEmptyInstance() => create();
  static $pb.PbList<CreateAlbumResponse> createRepeated() => $pb.PbList<CreateAlbumResponse>();
  @$core.pragma('dart2js:noInline')
  static CreateAlbumResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CreateAlbumResponse>(create);
  static CreateAlbumResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);
}

class DeleteAlbumRequest extends $pb.GeneratedMessage {
  factory DeleteAlbumRequest({
    $core.String? name,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    return $result;
  }
  DeleteAlbumRequest._() : super();
  factory DeleteAlbumRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DeleteAlbumRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DeleteAlbumRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DeleteAlbumRequest clone() => DeleteAlbumRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DeleteAlbumRequest copyWith(void Function(DeleteAlbumRequest) updates) => super.copyWith((message) => updates(message as DeleteAlbumRequest)) as DeleteAlbumRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteAlbumRequest create() => DeleteAlbumRequest._();
  DeleteAlbumRequest createEmptyInstance() => create();
  static $pb.PbList<DeleteAlbumRequest> createRepeated() => $pb.PbList<DeleteAlbumRequest>();
  @$core.pragma('dart2js:noInline')
  static DeleteAlbumRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DeleteAlbumRequest>(create);
  static DeleteAlbumRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);
}

class DeleteAlbumResponse extends $pb.GeneratedMessage {
  factory DeleteAlbumResponse({
    $core.bool? success,
    $core.String? message,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (message != null) {
      $result.message = message;
    }
    return $result;
  }
  DeleteAlbumResponse._() : super();
  factory DeleteAlbumResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DeleteAlbumResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DeleteAlbumResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DeleteAlbumResponse clone() => DeleteAlbumResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DeleteAlbumResponse copyWith(void Function(DeleteAlbumResponse) updates) => super.copyWith((message) => updates(message as DeleteAlbumResponse)) as DeleteAlbumResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteAlbumResponse create() => DeleteAlbumResponse._();
  DeleteAlbumResponse createEmptyInstance() => create();
  static $pb.PbList<DeleteAlbumResponse> createRepeated() => $pb.PbList<DeleteAlbumResponse>();
  @$core.pragma('dart2js:noInline')
  static DeleteAlbumResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DeleteAlbumResponse>(create);
  static DeleteAlbumResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);
}

class RenameAlbumRequest extends $pb.GeneratedMessage {
  factory RenameAlbumRequest({
    $core.String? oldName,
    $core.String? newName,
  }) {
    final $result = create();
    if (oldName != null) {
      $result.oldName = oldName;
    }
    if (newName != null) {
      $result.newName = newName;
    }
    return $result;
  }
  RenameAlbumRequest._() : super();
  factory RenameAlbumRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RenameAlbumRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RenameAlbumRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'oldName', protoName: 'oldName')
    ..aOS(2, _omitFieldNames ? '' : 'newName', protoName: 'newName')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RenameAlbumRequest clone() => RenameAlbumRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RenameAlbumRequest copyWith(void Function(RenameAlbumRequest) updates) => super.copyWith((message) => updates(message as RenameAlbumRequest)) as RenameAlbumRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RenameAlbumRequest create() => RenameAlbumRequest._();
  RenameAlbumRequest createEmptyInstance() => create();
  static $pb.PbList<RenameAlbumRequest> createRepeated() => $pb.PbList<RenameAlbumRequest>();
  @$core.pragma('dart2js:noInline')
  static RenameAlbumRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RenameAlbumRequest>(create);
  static RenameAlbumRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get oldName => $_getSZ(0);
  @$pb.TagNumber(1)
  set oldName($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasOldName() => $_has(0);
  @$pb.TagNumber(1)
  void clearOldName() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get newName => $_getSZ(1);
  @$pb.TagNumber(2)
  set newName($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasNewName() => $_has(1);
  @$pb.TagNumber(2)
  void clearNewName() => clearField(2);
}

class RenameAlbumResponse extends $pb.GeneratedMessage {
  factory RenameAlbumResponse({
    $core.bool? success,
    $core.String? message,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (message != null) {
      $result.message = message;
    }
    return $result;
  }
  RenameAlbumResponse._() : super();
  factory RenameAlbumResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RenameAlbumResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RenameAlbumResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RenameAlbumResponse clone() => RenameAlbumResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RenameAlbumResponse copyWith(void Function(RenameAlbumResponse) updates) => super.copyWith((message) => updates(message as RenameAlbumResponse)) as RenameAlbumResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RenameAlbumResponse create() => RenameAlbumResponse._();
  RenameAlbumResponse createEmptyInstance() => create();
  static $pb.PbList<RenameAlbumResponse> createRepeated() => $pb.PbList<RenameAlbumResponse>();
  @$core.pragma('dart2js:noInline')
  static RenameAlbumResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RenameAlbumResponse>(create);
  static RenameAlbumResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);
}

class MoveAssetsRequest extends $pb.GeneratedMessage {
  factory MoveAssetsRequest({
    $core.Iterable<$core.String>? paths,
    $core.String? targetAlbum,
  }) {
    final $result = create();
    if (paths != null) {
      $result.paths.addAll(paths);
    }
    if (targetAlbum != null) {
      $result.targetAlbum = targetAlbum;
    }
    return $result;
  }
  MoveAssetsRequest._() : super();
  factory MoveAssetsRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MoveAssetsRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MoveAssetsRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'paths')
    ..aOS(2, _omitFieldNames ? '' : 'targetAlbum', protoName: 'targetAlbum')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MoveAssetsRequest clone() => MoveAssetsRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MoveAssetsRequest copyWith(void Function(MoveAssetsRequest) updates) => super.copyWith((message) => updates(message as MoveAssetsRequest)) as MoveAssetsRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MoveAssetsRequest create() => MoveAssetsRequest._();
  MoveAssetsRequest createEmptyInstance() => create();
  static $pb.PbList<MoveAssetsRequest> createRepeated() => $pb.PbList<MoveAssetsRequest>();
  @$core.pragma('dart2js:noInline')
  static MoveAssetsRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MoveAssetsRequest>(create);
  static MoveAssetsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.String> get paths => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get targetAlbum => $_getSZ(1);
  @$pb.TagNumber(2)
  set targetAlbum($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasTargetAlbum() => $_has(1);
  @$pb.TagNumber(2)
  void clearTargetAlbum() => clearField(2);
}

class MoveAssetsResponse extends $pb.GeneratedMessage {
  factory MoveAssetsResponse({
    $core.bool? success,
    $core.String? message,
    $core.Iterable<$core.String>? newPaths,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (message != null) {
      $result.message = message;
    }
    if (newPaths != null) {
      $result.newPaths.addAll(newPaths);
    }
    return $result;
  }
  MoveAssetsResponse._() : super();
  factory MoveAssetsResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MoveAssetsResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MoveAssetsResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..pPS(3, _omitFieldNames ? '' : 'newPaths', protoName: 'newPaths')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MoveAssetsResponse clone() => MoveAssetsResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MoveAssetsResponse copyWith(void Function(MoveAssetsResponse) updates) => super.copyWith((message) => updates(message as MoveAssetsResponse)) as MoveAssetsResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MoveAssetsResponse create() => MoveAssetsResponse._();
  MoveAssetsResponse createEmptyInstance() => create();
  static $pb.PbList<MoveAssetsResponse> createRepeated() => $pb.PbList<MoveAssetsResponse>();
  @$core.pragma('dart2js:noInline')
  static MoveAssetsResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MoveAssetsResponse>(create);
  static MoveAssetsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.String> get newPaths => $_getList(2);
}

class FilterNotUploadedRequestInfo extends $pb.GeneratedMessage {
  factory FilterNotUploadedRequestInfo({
    $core.String? name,
    $core.String? date,
    $core.String? id,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (date != null) {
      $result.date = date;
    }
    if (id != null) {
      $result.id = id;
    }
    return $result;
  }
  FilterNotUploadedRequestInfo._() : super();
  factory FilterNotUploadedRequestInfo.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory FilterNotUploadedRequestInfo.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'FilterNotUploadedRequestInfo', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'date')
    ..aOS(3, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  FilterNotUploadedRequestInfo clone() => FilterNotUploadedRequestInfo()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  FilterNotUploadedRequestInfo copyWith(void Function(FilterNotUploadedRequestInfo) updates) => super.copyWith((message) => updates(message as FilterNotUploadedRequestInfo)) as FilterNotUploadedRequestInfo;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FilterNotUploadedRequestInfo create() => FilterNotUploadedRequestInfo._();
  FilterNotUploadedRequestInfo createEmptyInstance() => create();
  static $pb.PbList<FilterNotUploadedRequestInfo> createRepeated() => $pb.PbList<FilterNotUploadedRequestInfo>();
  @$core.pragma('dart2js:noInline')
  static FilterNotUploadedRequestInfo getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FilterNotUploadedRequestInfo>(create);
  static FilterNotUploadedRequestInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get date => $_getSZ(1);
  @$pb.TagNumber(2)
  set date($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasDate() => $_has(1);
  @$pb.TagNumber(2)
  void clearDate() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get id => $_getSZ(2);
  @$pb.TagNumber(3)
  set id($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasId() => $_has(2);
  @$pb.TagNumber(3)
  void clearId() => clearField(3);
}

class FilterNotUploadedRequest extends $pb.GeneratedMessage {
  factory FilterNotUploadedRequest({
    $core.Iterable<FilterNotUploadedRequestInfo>? photos,
    $core.bool? isFinished,
  }) {
    final $result = create();
    if (photos != null) {
      $result.photos.addAll(photos);
    }
    if (isFinished != null) {
      $result.isFinished = isFinished;
    }
    return $result;
  }
  FilterNotUploadedRequest._() : super();
  factory FilterNotUploadedRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory FilterNotUploadedRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'FilterNotUploadedRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..pc<FilterNotUploadedRequestInfo>(1, _omitFieldNames ? '' : 'photos', $pb.PbFieldType.PM, subBuilder: FilterNotUploadedRequestInfo.create)
    ..aOB(2, _omitFieldNames ? '' : 'isFinished', protoName: 'isFinished')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  FilterNotUploadedRequest clone() => FilterNotUploadedRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  FilterNotUploadedRequest copyWith(void Function(FilterNotUploadedRequest) updates) => super.copyWith((message) => updates(message as FilterNotUploadedRequest)) as FilterNotUploadedRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FilterNotUploadedRequest create() => FilterNotUploadedRequest._();
  FilterNotUploadedRequest createEmptyInstance() => create();
  static $pb.PbList<FilterNotUploadedRequest> createRepeated() => $pb.PbList<FilterNotUploadedRequest>();
  @$core.pragma('dart2js:noInline')
  static FilterNotUploadedRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FilterNotUploadedRequest>(create);
  static FilterNotUploadedRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<FilterNotUploadedRequestInfo> get photos => $_getList(0);

  @$pb.TagNumber(2)
  $core.bool get isFinished => $_getBF(1);
  @$pb.TagNumber(2)
  set isFinished($core.bool v) { $_setBool(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasIsFinished() => $_has(1);
  @$pb.TagNumber(2)
  void clearIsFinished() => clearField(2);
}

class FilterNotUploadedResponse extends $pb.GeneratedMessage {
  factory FilterNotUploadedResponse({
    $core.bool? success,
    $core.String? message,
    $core.Iterable<$core.String>? notUploaedIDs,
    $core.Iterable<$core.String>? uploadedIDs,
    $core.bool? isFinished,
    $core.Iterable<$core.String>? invalidIds,
    $core.Iterable<$core.String>? notUploadedIDs,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (message != null) {
      $result.message = message;
    }
    if (notUploaedIDs != null) {
      $result.notUploaedIDs.addAll(notUploaedIDs);
    }
    if (uploadedIDs != null) {
      $result.uploadedIDs.addAll(uploadedIDs);
    }
    if (isFinished != null) {
      $result.isFinished = isFinished;
    }
    if (invalidIds != null) {
      $result.invalidIds.addAll(invalidIds);
    }
    if (notUploadedIDs != null) {
      $result.notUploadedIDs.addAll(notUploadedIDs);
    }
    return $result;
  }
  FilterNotUploadedResponse._() : super();
  factory FilterNotUploadedResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory FilterNotUploadedResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'FilterNotUploadedResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..pPS(3, _omitFieldNames ? '' : 'notUploaedIDs', protoName: 'notUploaedIDs')
    ..pPS(4, _omitFieldNames ? '' : 'uploadedIDs', protoName: 'uploadedIDs')
    ..aOB(5, _omitFieldNames ? '' : 'isFinished', protoName: 'isFinished')
    ..pPS(6, _omitFieldNames ? '' : 'invalidIds')
    ..pPS(7, _omitFieldNames ? '' : 'notUploadedIDs', protoName: 'notUploadedIDs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  FilterNotUploadedResponse clone() => FilterNotUploadedResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  FilterNotUploadedResponse copyWith(void Function(FilterNotUploadedResponse) updates) => super.copyWith((message) => updates(message as FilterNotUploadedResponse)) as FilterNotUploadedResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FilterNotUploadedResponse create() => FilterNotUploadedResponse._();
  FilterNotUploadedResponse createEmptyInstance() => create();
  static $pb.PbList<FilterNotUploadedResponse> createRepeated() => $pb.PbList<FilterNotUploadedResponse>();
  @$core.pragma('dart2js:noInline')
  static FilterNotUploadedResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FilterNotUploadedResponse>(create);
  static FilterNotUploadedResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.String> get notUploaedIDs => $_getList(2);

  @$pb.TagNumber(4)
  $core.List<$core.String> get uploadedIDs => $_getList(3);

  @$pb.TagNumber(5)
  $core.bool get isFinished => $_getBF(4);
  @$pb.TagNumber(5)
  set isFinished($core.bool v) { $_setBool(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasIsFinished() => $_has(4);
  @$pb.TagNumber(5)
  void clearIsFinished() => clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.String> get invalidIds => $_getList(5);

  @$pb.TagNumber(7)
  $core.List<$core.String> get notUploadedIDs => $_getList(6);
}

class SetDriveSMBRequest extends $pb.GeneratedMessage {
  factory SetDriveSMBRequest({
    $core.String? addr,
    $core.String? username,
    $core.String? password,
    $core.String? share,
    $core.String? root,
    $core.bool? isMetaDrive,
  }) {
    final $result = create();
    if (addr != null) {
      $result.addr = addr;
    }
    if (username != null) {
      $result.username = username;
    }
    if (password != null) {
      $result.password = password;
    }
    if (share != null) {
      $result.share = share;
    }
    if (root != null) {
      $result.root = root;
    }
    if (isMetaDrive != null) {
      $result.isMetaDrive = isMetaDrive;
    }
    return $result;
  }
  SetDriveSMBRequest._() : super();
  factory SetDriveSMBRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SetDriveSMBRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SetDriveSMBRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'addr')
    ..aOS(2, _omitFieldNames ? '' : 'username')
    ..aOS(3, _omitFieldNames ? '' : 'password')
    ..aOS(4, _omitFieldNames ? '' : 'share')
    ..aOS(5, _omitFieldNames ? '' : 'root')
    ..aOB(6, _omitFieldNames ? '' : 'isMetaDrive', protoName: 'isMetaDrive')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SetDriveSMBRequest clone() => SetDriveSMBRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SetDriveSMBRequest copyWith(void Function(SetDriveSMBRequest) updates) => super.copyWith((message) => updates(message as SetDriveSMBRequest)) as SetDriveSMBRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetDriveSMBRequest create() => SetDriveSMBRequest._();
  SetDriveSMBRequest createEmptyInstance() => create();
  static $pb.PbList<SetDriveSMBRequest> createRepeated() => $pb.PbList<SetDriveSMBRequest>();
  @$core.pragma('dart2js:noInline')
  static SetDriveSMBRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetDriveSMBRequest>(create);
  static SetDriveSMBRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get addr => $_getSZ(0);
  @$pb.TagNumber(1)
  set addr($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasAddr() => $_has(0);
  @$pb.TagNumber(1)
  void clearAddr() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get username => $_getSZ(1);
  @$pb.TagNumber(2)
  set username($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasUsername() => $_has(1);
  @$pb.TagNumber(2)
  void clearUsername() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get password => $_getSZ(2);
  @$pb.TagNumber(3)
  set password($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPassword() => $_has(2);
  @$pb.TagNumber(3)
  void clearPassword() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get share => $_getSZ(3);
  @$pb.TagNumber(4)
  set share($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasShare() => $_has(3);
  @$pb.TagNumber(4)
  void clearShare() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get root => $_getSZ(4);
  @$pb.TagNumber(5)
  set root($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasRoot() => $_has(4);
  @$pb.TagNumber(5)
  void clearRoot() => clearField(5);

  @$pb.TagNumber(6)
  $core.bool get isMetaDrive => $_getBF(5);
  @$pb.TagNumber(6)
  set isMetaDrive($core.bool v) { $_setBool(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasIsMetaDrive() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsMetaDrive() => clearField(6);
}

class SetDriveSMBResponse extends $pb.GeneratedMessage {
  factory SetDriveSMBResponse({
    $core.bool? success,
    $core.String? message,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (message != null) {
      $result.message = message;
    }
    return $result;
  }
  SetDriveSMBResponse._() : super();
  factory SetDriveSMBResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SetDriveSMBResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SetDriveSMBResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SetDriveSMBResponse clone() => SetDriveSMBResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SetDriveSMBResponse copyWith(void Function(SetDriveSMBResponse) updates) => super.copyWith((message) => updates(message as SetDriveSMBResponse)) as SetDriveSMBResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetDriveSMBResponse create() => SetDriveSMBResponse._();
  SetDriveSMBResponse createEmptyInstance() => create();
  static $pb.PbList<SetDriveSMBResponse> createRepeated() => $pb.PbList<SetDriveSMBResponse>();
  @$core.pragma('dart2js:noInline')
  static SetDriveSMBResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetDriveSMBResponse>(create);
  static SetDriveSMBResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);
}

class ListDriveSMBSharesRequest extends $pb.GeneratedMessage {
  factory ListDriveSMBSharesRequest({
    $core.bool? isMetaDrive,
  }) {
    final $result = create();
    if (isMetaDrive != null) {
      $result.isMetaDrive = isMetaDrive;
    }
    return $result;
  }
  ListDriveSMBSharesRequest._() : super();
  factory ListDriveSMBSharesRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListDriveSMBSharesRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListDriveSMBSharesRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'isMetaDrive', protoName: 'isMetaDrive')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListDriveSMBSharesRequest clone() => ListDriveSMBSharesRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListDriveSMBSharesRequest copyWith(void Function(ListDriveSMBSharesRequest) updates) => super.copyWith((message) => updates(message as ListDriveSMBSharesRequest)) as ListDriveSMBSharesRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListDriveSMBSharesRequest create() => ListDriveSMBSharesRequest._();
  ListDriveSMBSharesRequest createEmptyInstance() => create();
  static $pb.PbList<ListDriveSMBSharesRequest> createRepeated() => $pb.PbList<ListDriveSMBSharesRequest>();
  @$core.pragma('dart2js:noInline')
  static ListDriveSMBSharesRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListDriveSMBSharesRequest>(create);
  static ListDriveSMBSharesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get isMetaDrive => $_getBF(0);
  @$pb.TagNumber(1)
  set isMetaDrive($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasIsMetaDrive() => $_has(0);
  @$pb.TagNumber(1)
  void clearIsMetaDrive() => clearField(1);
}

class ListDriveSMBSharesResponse extends $pb.GeneratedMessage {
  factory ListDriveSMBSharesResponse({
    $core.bool? success,
    $core.String? message,
    $core.Iterable<$core.String>? shares,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (message != null) {
      $result.message = message;
    }
    if (shares != null) {
      $result.shares.addAll(shares);
    }
    return $result;
  }
  ListDriveSMBSharesResponse._() : super();
  factory ListDriveSMBSharesResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListDriveSMBSharesResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListDriveSMBSharesResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..pPS(3, _omitFieldNames ? '' : 'shares')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListDriveSMBSharesResponse clone() => ListDriveSMBSharesResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListDriveSMBSharesResponse copyWith(void Function(ListDriveSMBSharesResponse) updates) => super.copyWith((message) => updates(message as ListDriveSMBSharesResponse)) as ListDriveSMBSharesResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListDriveSMBSharesResponse create() => ListDriveSMBSharesResponse._();
  ListDriveSMBSharesResponse createEmptyInstance() => create();
  static $pb.PbList<ListDriveSMBSharesResponse> createRepeated() => $pb.PbList<ListDriveSMBSharesResponse>();
  @$core.pragma('dart2js:noInline')
  static ListDriveSMBSharesResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListDriveSMBSharesResponse>(create);
  static ListDriveSMBSharesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.String> get shares => $_getList(2);
}

class ListDriveSMBDirRequest extends $pb.GeneratedMessage {
  factory ListDriveSMBDirRequest({
    $core.String? share,
    $core.String? dir,
    $core.bool? isMetaDrive,
  }) {
    final $result = create();
    if (share != null) {
      $result.share = share;
    }
    if (dir != null) {
      $result.dir = dir;
    }
    if (isMetaDrive != null) {
      $result.isMetaDrive = isMetaDrive;
    }
    return $result;
  }
  ListDriveSMBDirRequest._() : super();
  factory ListDriveSMBDirRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListDriveSMBDirRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListDriveSMBDirRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'share')
    ..aOS(2, _omitFieldNames ? '' : 'dir')
    ..aOB(3, _omitFieldNames ? '' : 'isMetaDrive', protoName: 'isMetaDrive')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListDriveSMBDirRequest clone() => ListDriveSMBDirRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListDriveSMBDirRequest copyWith(void Function(ListDriveSMBDirRequest) updates) => super.copyWith((message) => updates(message as ListDriveSMBDirRequest)) as ListDriveSMBDirRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListDriveSMBDirRequest create() => ListDriveSMBDirRequest._();
  ListDriveSMBDirRequest createEmptyInstance() => create();
  static $pb.PbList<ListDriveSMBDirRequest> createRepeated() => $pb.PbList<ListDriveSMBDirRequest>();
  @$core.pragma('dart2js:noInline')
  static ListDriveSMBDirRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListDriveSMBDirRequest>(create);
  static ListDriveSMBDirRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get share => $_getSZ(0);
  @$pb.TagNumber(1)
  set share($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasShare() => $_has(0);
  @$pb.TagNumber(1)
  void clearShare() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get dir => $_getSZ(1);
  @$pb.TagNumber(2)
  set dir($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasDir() => $_has(1);
  @$pb.TagNumber(2)
  void clearDir() => clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isMetaDrive => $_getBF(2);
  @$pb.TagNumber(3)
  set isMetaDrive($core.bool v) { $_setBool(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasIsMetaDrive() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsMetaDrive() => clearField(3);
}

class ListDriveSMBDirResponse extends $pb.GeneratedMessage {
  factory ListDriveSMBDirResponse({
    $core.bool? success,
    $core.String? message,
    $core.Iterable<$core.String>? dirs,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (message != null) {
      $result.message = message;
    }
    if (dirs != null) {
      $result.dirs.addAll(dirs);
    }
    return $result;
  }
  ListDriveSMBDirResponse._() : super();
  factory ListDriveSMBDirResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListDriveSMBDirResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListDriveSMBDirResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..pPS(3, _omitFieldNames ? '' : 'dirs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListDriveSMBDirResponse clone() => ListDriveSMBDirResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListDriveSMBDirResponse copyWith(void Function(ListDriveSMBDirResponse) updates) => super.copyWith((message) => updates(message as ListDriveSMBDirResponse)) as ListDriveSMBDirResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListDriveSMBDirResponse create() => ListDriveSMBDirResponse._();
  ListDriveSMBDirResponse createEmptyInstance() => create();
  static $pb.PbList<ListDriveSMBDirResponse> createRepeated() => $pb.PbList<ListDriveSMBDirResponse>();
  @$core.pragma('dart2js:noInline')
  static ListDriveSMBDirResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListDriveSMBDirResponse>(create);
  static ListDriveSMBDirResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.String> get dirs => $_getList(2);
}

class SetDriveSMBShareRequest extends $pb.GeneratedMessage {
  factory SetDriveSMBShareRequest({
    $core.String? share,
    $core.String? root,
    $core.bool? isMetaDrive,
  }) {
    final $result = create();
    if (share != null) {
      $result.share = share;
    }
    if (root != null) {
      $result.root = root;
    }
    if (isMetaDrive != null) {
      $result.isMetaDrive = isMetaDrive;
    }
    return $result;
  }
  SetDriveSMBShareRequest._() : super();
  factory SetDriveSMBShareRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SetDriveSMBShareRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SetDriveSMBShareRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'share')
    ..aOS(2, _omitFieldNames ? '' : 'root')
    ..aOB(3, _omitFieldNames ? '' : 'isMetaDrive', protoName: 'isMetaDrive')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SetDriveSMBShareRequest clone() => SetDriveSMBShareRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SetDriveSMBShareRequest copyWith(void Function(SetDriveSMBShareRequest) updates) => super.copyWith((message) => updates(message as SetDriveSMBShareRequest)) as SetDriveSMBShareRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetDriveSMBShareRequest create() => SetDriveSMBShareRequest._();
  SetDriveSMBShareRequest createEmptyInstance() => create();
  static $pb.PbList<SetDriveSMBShareRequest> createRepeated() => $pb.PbList<SetDriveSMBShareRequest>();
  @$core.pragma('dart2js:noInline')
  static SetDriveSMBShareRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetDriveSMBShareRequest>(create);
  static SetDriveSMBShareRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get share => $_getSZ(0);
  @$pb.TagNumber(1)
  set share($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasShare() => $_has(0);
  @$pb.TagNumber(1)
  void clearShare() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get root => $_getSZ(1);
  @$pb.TagNumber(2)
  set root($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasRoot() => $_has(1);
  @$pb.TagNumber(2)
  void clearRoot() => clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isMetaDrive => $_getBF(2);
  @$pb.TagNumber(3)
  set isMetaDrive($core.bool v) { $_setBool(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasIsMetaDrive() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsMetaDrive() => clearField(3);
}

class SetDriveSMBShareResponse extends $pb.GeneratedMessage {
  factory SetDriveSMBShareResponse({
    $core.bool? success,
    $core.String? message,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (message != null) {
      $result.message = message;
    }
    return $result;
  }
  SetDriveSMBShareResponse._() : super();
  factory SetDriveSMBShareResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SetDriveSMBShareResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SetDriveSMBShareResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SetDriveSMBShareResponse clone() => SetDriveSMBShareResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SetDriveSMBShareResponse copyWith(void Function(SetDriveSMBShareResponse) updates) => super.copyWith((message) => updates(message as SetDriveSMBShareResponse)) as SetDriveSMBShareResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetDriveSMBShareResponse create() => SetDriveSMBShareResponse._();
  SetDriveSMBShareResponse createEmptyInstance() => create();
  static $pb.PbList<SetDriveSMBShareResponse> createRepeated() => $pb.PbList<SetDriveSMBShareResponse>();
  @$core.pragma('dart2js:noInline')
  static SetDriveSMBShareResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetDriveSMBShareResponse>(create);
  static SetDriveSMBShareResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);
}

class SetDriveWebdavRequest extends $pb.GeneratedMessage {
  factory SetDriveWebdavRequest({
    $core.String? addr,
    $core.String? username,
    $core.String? password,
    $core.String? root,
    $core.bool? insecure,
    $core.bool? isMetaDrive,
  }) {
    final $result = create();
    if (addr != null) {
      $result.addr = addr;
    }
    if (username != null) {
      $result.username = username;
    }
    if (password != null) {
      $result.password = password;
    }
    if (root != null) {
      $result.root = root;
    }
    if (insecure != null) {
      $result.insecure = insecure;
    }
    if (isMetaDrive != null) {
      $result.isMetaDrive = isMetaDrive;
    }
    return $result;
  }
  SetDriveWebdavRequest._() : super();
  factory SetDriveWebdavRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SetDriveWebdavRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SetDriveWebdavRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'addr')
    ..aOS(2, _omitFieldNames ? '' : 'username')
    ..aOS(3, _omitFieldNames ? '' : 'password')
    ..aOS(4, _omitFieldNames ? '' : 'root')
    ..aOB(5, _omitFieldNames ? '' : 'insecure')
    ..aOB(6, _omitFieldNames ? '' : 'isMetaDrive', protoName: 'isMetaDrive')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SetDriveWebdavRequest clone() => SetDriveWebdavRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SetDriveWebdavRequest copyWith(void Function(SetDriveWebdavRequest) updates) => super.copyWith((message) => updates(message as SetDriveWebdavRequest)) as SetDriveWebdavRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetDriveWebdavRequest create() => SetDriveWebdavRequest._();
  SetDriveWebdavRequest createEmptyInstance() => create();
  static $pb.PbList<SetDriveWebdavRequest> createRepeated() => $pb.PbList<SetDriveWebdavRequest>();
  @$core.pragma('dart2js:noInline')
  static SetDriveWebdavRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetDriveWebdavRequest>(create);
  static SetDriveWebdavRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get addr => $_getSZ(0);
  @$pb.TagNumber(1)
  set addr($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasAddr() => $_has(0);
  @$pb.TagNumber(1)
  void clearAddr() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get username => $_getSZ(1);
  @$pb.TagNumber(2)
  set username($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasUsername() => $_has(1);
  @$pb.TagNumber(2)
  void clearUsername() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get password => $_getSZ(2);
  @$pb.TagNumber(3)
  set password($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPassword() => $_has(2);
  @$pb.TagNumber(3)
  void clearPassword() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get root => $_getSZ(3);
  @$pb.TagNumber(4)
  set root($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasRoot() => $_has(3);
  @$pb.TagNumber(4)
  void clearRoot() => clearField(4);

  @$pb.TagNumber(5)
  $core.bool get insecure => $_getBF(4);
  @$pb.TagNumber(5)
  set insecure($core.bool v) { $_setBool(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasInsecure() => $_has(4);
  @$pb.TagNumber(5)
  void clearInsecure() => clearField(5);

  @$pb.TagNumber(6)
  $core.bool get isMetaDrive => $_getBF(5);
  @$pb.TagNumber(6)
  set isMetaDrive($core.bool v) { $_setBool(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasIsMetaDrive() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsMetaDrive() => clearField(6);
}

class SetDriveWebdavResponse extends $pb.GeneratedMessage {
  factory SetDriveWebdavResponse({
    $core.bool? success,
    $core.String? message,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (message != null) {
      $result.message = message;
    }
    return $result;
  }
  SetDriveWebdavResponse._() : super();
  factory SetDriveWebdavResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SetDriveWebdavResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SetDriveWebdavResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SetDriveWebdavResponse clone() => SetDriveWebdavResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SetDriveWebdavResponse copyWith(void Function(SetDriveWebdavResponse) updates) => super.copyWith((message) => updates(message as SetDriveWebdavResponse)) as SetDriveWebdavResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetDriveWebdavResponse create() => SetDriveWebdavResponse._();
  SetDriveWebdavResponse createEmptyInstance() => create();
  static $pb.PbList<SetDriveWebdavResponse> createRepeated() => $pb.PbList<SetDriveWebdavResponse>();
  @$core.pragma('dart2js:noInline')
  static SetDriveWebdavResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetDriveWebdavResponse>(create);
  static SetDriveWebdavResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);
}

class ListDriveWebdavDirRequest extends $pb.GeneratedMessage {
  factory ListDriveWebdavDirRequest({
    $core.String? dir,
    $core.bool? isMetaDrive,
  }) {
    final $result = create();
    if (dir != null) {
      $result.dir = dir;
    }
    if (isMetaDrive != null) {
      $result.isMetaDrive = isMetaDrive;
    }
    return $result;
  }
  ListDriveWebdavDirRequest._() : super();
  factory ListDriveWebdavDirRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListDriveWebdavDirRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListDriveWebdavDirRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'dir')
    ..aOB(2, _omitFieldNames ? '' : 'isMetaDrive', protoName: 'isMetaDrive')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListDriveWebdavDirRequest clone() => ListDriveWebdavDirRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListDriveWebdavDirRequest copyWith(void Function(ListDriveWebdavDirRequest) updates) => super.copyWith((message) => updates(message as ListDriveWebdavDirRequest)) as ListDriveWebdavDirRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListDriveWebdavDirRequest create() => ListDriveWebdavDirRequest._();
  ListDriveWebdavDirRequest createEmptyInstance() => create();
  static $pb.PbList<ListDriveWebdavDirRequest> createRepeated() => $pb.PbList<ListDriveWebdavDirRequest>();
  @$core.pragma('dart2js:noInline')
  static ListDriveWebdavDirRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListDriveWebdavDirRequest>(create);
  static ListDriveWebdavDirRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get dir => $_getSZ(0);
  @$pb.TagNumber(1)
  set dir($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasDir() => $_has(0);
  @$pb.TagNumber(1)
  void clearDir() => clearField(1);

  @$pb.TagNumber(2)
  $core.bool get isMetaDrive => $_getBF(1);
  @$pb.TagNumber(2)
  set isMetaDrive($core.bool v) { $_setBool(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasIsMetaDrive() => $_has(1);
  @$pb.TagNumber(2)
  void clearIsMetaDrive() => clearField(2);
}

class ListDriveWebdavDirResponse extends $pb.GeneratedMessage {
  factory ListDriveWebdavDirResponse({
    $core.bool? success,
    $core.String? message,
    $core.Iterable<$core.String>? dirs,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (message != null) {
      $result.message = message;
    }
    if (dirs != null) {
      $result.dirs.addAll(dirs);
    }
    return $result;
  }
  ListDriveWebdavDirResponse._() : super();
  factory ListDriveWebdavDirResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListDriveWebdavDirResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListDriveWebdavDirResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..pPS(3, _omitFieldNames ? '' : 'dirs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListDriveWebdavDirResponse clone() => ListDriveWebdavDirResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListDriveWebdavDirResponse copyWith(void Function(ListDriveWebdavDirResponse) updates) => super.copyWith((message) => updates(message as ListDriveWebdavDirResponse)) as ListDriveWebdavDirResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListDriveWebdavDirResponse create() => ListDriveWebdavDirResponse._();
  ListDriveWebdavDirResponse createEmptyInstance() => create();
  static $pb.PbList<ListDriveWebdavDirResponse> createRepeated() => $pb.PbList<ListDriveWebdavDirResponse>();
  @$core.pragma('dart2js:noInline')
  static ListDriveWebdavDirResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListDriveWebdavDirResponse>(create);
  static ListDriveWebdavDirResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.String> get dirs => $_getList(2);
}

class SetDriveNFSRequest extends $pb.GeneratedMessage {
  factory SetDriveNFSRequest({
    $core.String? addr,
    $core.String? root,
    $core.bool? isMetaDrive,
  }) {
    final $result = create();
    if (addr != null) {
      $result.addr = addr;
    }
    if (root != null) {
      $result.root = root;
    }
    if (isMetaDrive != null) {
      $result.isMetaDrive = isMetaDrive;
    }
    return $result;
  }
  SetDriveNFSRequest._() : super();
  factory SetDriveNFSRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SetDriveNFSRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SetDriveNFSRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'addr')
    ..aOS(2, _omitFieldNames ? '' : 'root')
    ..aOB(3, _omitFieldNames ? '' : 'isMetaDrive', protoName: 'isMetaDrive')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SetDriveNFSRequest clone() => SetDriveNFSRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SetDriveNFSRequest copyWith(void Function(SetDriveNFSRequest) updates) => super.copyWith((message) => updates(message as SetDriveNFSRequest)) as SetDriveNFSRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetDriveNFSRequest create() => SetDriveNFSRequest._();
  SetDriveNFSRequest createEmptyInstance() => create();
  static $pb.PbList<SetDriveNFSRequest> createRepeated() => $pb.PbList<SetDriveNFSRequest>();
  @$core.pragma('dart2js:noInline')
  static SetDriveNFSRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetDriveNFSRequest>(create);
  static SetDriveNFSRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get addr => $_getSZ(0);
  @$pb.TagNumber(1)
  set addr($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasAddr() => $_has(0);
  @$pb.TagNumber(1)
  void clearAddr() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get root => $_getSZ(1);
  @$pb.TagNumber(2)
  set root($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasRoot() => $_has(1);
  @$pb.TagNumber(2)
  void clearRoot() => clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isMetaDrive => $_getBF(2);
  @$pb.TagNumber(3)
  set isMetaDrive($core.bool v) { $_setBool(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasIsMetaDrive() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsMetaDrive() => clearField(3);
}

class SetDriveNFSResponse extends $pb.GeneratedMessage {
  factory SetDriveNFSResponse({
    $core.bool? success,
    $core.String? message,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (message != null) {
      $result.message = message;
    }
    return $result;
  }
  SetDriveNFSResponse._() : super();
  factory SetDriveNFSResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SetDriveNFSResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SetDriveNFSResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SetDriveNFSResponse clone() => SetDriveNFSResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SetDriveNFSResponse copyWith(void Function(SetDriveNFSResponse) updates) => super.copyWith((message) => updates(message as SetDriveNFSResponse)) as SetDriveNFSResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetDriveNFSResponse create() => SetDriveNFSResponse._();
  SetDriveNFSResponse createEmptyInstance() => create();
  static $pb.PbList<SetDriveNFSResponse> createRepeated() => $pb.PbList<SetDriveNFSResponse>();
  @$core.pragma('dart2js:noInline')
  static SetDriveNFSResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetDriveNFSResponse>(create);
  static SetDriveNFSResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);
}

class ListDriveNFSDirRequest extends $pb.GeneratedMessage {
  factory ListDriveNFSDirRequest({
    $core.String? dir,
    $core.bool? isMetaDrive,
  }) {
    final $result = create();
    if (dir != null) {
      $result.dir = dir;
    }
    if (isMetaDrive != null) {
      $result.isMetaDrive = isMetaDrive;
    }
    return $result;
  }
  ListDriveNFSDirRequest._() : super();
  factory ListDriveNFSDirRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListDriveNFSDirRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListDriveNFSDirRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'dir')
    ..aOB(2, _omitFieldNames ? '' : 'isMetaDrive', protoName: 'isMetaDrive')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListDriveNFSDirRequest clone() => ListDriveNFSDirRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListDriveNFSDirRequest copyWith(void Function(ListDriveNFSDirRequest) updates) => super.copyWith((message) => updates(message as ListDriveNFSDirRequest)) as ListDriveNFSDirRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListDriveNFSDirRequest create() => ListDriveNFSDirRequest._();
  ListDriveNFSDirRequest createEmptyInstance() => create();
  static $pb.PbList<ListDriveNFSDirRequest> createRepeated() => $pb.PbList<ListDriveNFSDirRequest>();
  @$core.pragma('dart2js:noInline')
  static ListDriveNFSDirRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListDriveNFSDirRequest>(create);
  static ListDriveNFSDirRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get dir => $_getSZ(0);
  @$pb.TagNumber(1)
  set dir($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasDir() => $_has(0);
  @$pb.TagNumber(1)
  void clearDir() => clearField(1);

  @$pb.TagNumber(2)
  $core.bool get isMetaDrive => $_getBF(1);
  @$pb.TagNumber(2)
  set isMetaDrive($core.bool v) { $_setBool(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasIsMetaDrive() => $_has(1);
  @$pb.TagNumber(2)
  void clearIsMetaDrive() => clearField(2);
}

class ListDriveNFSDirResponse extends $pb.GeneratedMessage {
  factory ListDriveNFSDirResponse({
    $core.bool? success,
    $core.String? message,
    $core.Iterable<$core.String>? dirs,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (message != null) {
      $result.message = message;
    }
    if (dirs != null) {
      $result.dirs.addAll(dirs);
    }
    return $result;
  }
  ListDriveNFSDirResponse._() : super();
  factory ListDriveNFSDirResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ListDriveNFSDirResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ListDriveNFSDirResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..pPS(3, _omitFieldNames ? '' : 'dirs')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ListDriveNFSDirResponse clone() => ListDriveNFSDirResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ListDriveNFSDirResponse copyWith(void Function(ListDriveNFSDirResponse) updates) => super.copyWith((message) => updates(message as ListDriveNFSDirResponse)) as ListDriveNFSDirResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListDriveNFSDirResponse create() => ListDriveNFSDirResponse._();
  ListDriveNFSDirResponse createEmptyInstance() => create();
  static $pb.PbList<ListDriveNFSDirResponse> createRepeated() => $pb.PbList<ListDriveNFSDirResponse>();
  @$core.pragma('dart2js:noInline')
  static ListDriveNFSDirResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListDriveNFSDirResponse>(create);
  static ListDriveNFSDirResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.String> get dirs => $_getList(2);
}

class SetLocalCacheDirRequest extends $pb.GeneratedMessage {
  factory SetLocalCacheDirRequest({
    $core.String? path,
  }) {
    final $result = create();
    if (path != null) {
      $result.path = path;
    }
    return $result;
  }
  SetLocalCacheDirRequest._() : super();
  factory SetLocalCacheDirRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SetLocalCacheDirRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SetLocalCacheDirRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SetLocalCacheDirRequest clone() => SetLocalCacheDirRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SetLocalCacheDirRequest copyWith(void Function(SetLocalCacheDirRequest) updates) => super.copyWith((message) => updates(message as SetLocalCacheDirRequest)) as SetLocalCacheDirRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetLocalCacheDirRequest create() => SetLocalCacheDirRequest._();
  SetLocalCacheDirRequest createEmptyInstance() => create();
  static $pb.PbList<SetLocalCacheDirRequest> createRepeated() => $pb.PbList<SetLocalCacheDirRequest>();
  @$core.pragma('dart2js:noInline')
  static SetLocalCacheDirRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetLocalCacheDirRequest>(create);
  static SetLocalCacheDirRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => clearField(1);
}

class SetLocalCacheDirResponse extends $pb.GeneratedMessage {
  factory SetLocalCacheDirResponse({
    $core.bool? success,
    $core.String? message,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (message != null) {
      $result.message = message;
    }
    return $result;
  }
  SetLocalCacheDirResponse._() : super();
  factory SetLocalCacheDirResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SetLocalCacheDirResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SetLocalCacheDirResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SetLocalCacheDirResponse clone() => SetLocalCacheDirResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SetLocalCacheDirResponse copyWith(void Function(SetLocalCacheDirResponse) updates) => super.copyWith((message) => updates(message as SetLocalCacheDirResponse)) as SetLocalCacheDirResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SetLocalCacheDirResponse create() => SetLocalCacheDirResponse._();
  SetLocalCacheDirResponse createEmptyInstance() => create();
  static $pb.PbList<SetLocalCacheDirResponse> createRepeated() => $pb.PbList<SetLocalCacheDirResponse>();
  @$core.pragma('dart2js:noInline')
  static SetLocalCacheDirResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetLocalCacheDirResponse>(create);
  static SetLocalCacheDirResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);
}

class SyncManifestRequest extends $pb.GeneratedMessage {
  factory SyncManifestRequest() => create();
  SyncManifestRequest._() : super();
  factory SyncManifestRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SyncManifestRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SyncManifestRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SyncManifestRequest clone() => SyncManifestRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SyncManifestRequest copyWith(void Function(SyncManifestRequest) updates) => super.copyWith((message) => updates(message as SyncManifestRequest)) as SyncManifestRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncManifestRequest create() => SyncManifestRequest._();
  SyncManifestRequest createEmptyInstance() => create();
  static $pb.PbList<SyncManifestRequest> createRepeated() => $pb.PbList<SyncManifestRequest>();
  @$core.pragma('dart2js:noInline')
  static SyncManifestRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SyncManifestRequest>(create);
  static SyncManifestRequest? _defaultInstance;
}

class SyncManifestResponse extends $pb.GeneratedMessage {
  factory SyncManifestResponse({
    $core.bool? success,
    $core.String? message,
    $fixnum.Int64? watermark,
    $core.int? recordCount,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (message != null) {
      $result.message = message;
    }
    if (watermark != null) {
      $result.watermark = watermark;
    }
    if (recordCount != null) {
      $result.recordCount = recordCount;
    }
    return $result;
  }
  SyncManifestResponse._() : super();
  factory SyncManifestResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory SyncManifestResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'SyncManifestResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..aInt64(3, _omitFieldNames ? '' : 'watermark')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'recordCount', $pb.PbFieldType.O3, protoName: 'recordCount')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  SyncManifestResponse clone() => SyncManifestResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  SyncManifestResponse copyWith(void Function(SyncManifestResponse) updates) => super.copyWith((message) => updates(message as SyncManifestResponse)) as SyncManifestResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncManifestResponse create() => SyncManifestResponse._();
  SyncManifestResponse createEmptyInstance() => create();
  static $pb.PbList<SyncManifestResponse> createRepeated() => $pb.PbList<SyncManifestResponse>();
  @$core.pragma('dart2js:noInline')
  static SyncManifestResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SyncManifestResponse>(create);
  static SyncManifestResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get watermark => $_getI64(2);
  @$pb.TagNumber(3)
  set watermark($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasWatermark() => $_has(2);
  @$pb.TagNumber(3)
  void clearWatermark() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get recordCount => $_getIZ(3);
  @$pb.TagNumber(4)
  set recordCount($core.int v) { $_setSignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasRecordCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearRecordCount() => clearField(4);
}

class ClearMetaDriveRequest extends $pb.GeneratedMessage {
  factory ClearMetaDriveRequest() => create();
  ClearMetaDriveRequest._() : super();
  factory ClearMetaDriveRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ClearMetaDriveRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ClearMetaDriveRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ClearMetaDriveRequest clone() => ClearMetaDriveRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ClearMetaDriveRequest copyWith(void Function(ClearMetaDriveRequest) updates) => super.copyWith((message) => updates(message as ClearMetaDriveRequest)) as ClearMetaDriveRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClearMetaDriveRequest create() => ClearMetaDriveRequest._();
  ClearMetaDriveRequest createEmptyInstance() => create();
  static $pb.PbList<ClearMetaDriveRequest> createRepeated() => $pb.PbList<ClearMetaDriveRequest>();
  @$core.pragma('dart2js:noInline')
  static ClearMetaDriveRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ClearMetaDriveRequest>(create);
  static ClearMetaDriveRequest? _defaultInstance;
}

class ClearMetaDriveResponse extends $pb.GeneratedMessage {
  factory ClearMetaDriveResponse({
    $core.bool? success,
    $core.String? message,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (message != null) {
      $result.message = message;
    }
    return $result;
  }
  ClearMetaDriveResponse._() : super();
  factory ClearMetaDriveResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ClearMetaDriveResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ClearMetaDriveResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ClearMetaDriveResponse clone() => ClearMetaDriveResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ClearMetaDriveResponse copyWith(void Function(ClearMetaDriveResponse) updates) => super.copyWith((message) => updates(message as ClearMetaDriveResponse)) as ClearMetaDriveResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClearMetaDriveResponse create() => ClearMetaDriveResponse._();
  ClearMetaDriveResponse createEmptyInstance() => create();
  static $pb.PbList<ClearMetaDriveResponse> createRepeated() => $pb.PbList<ClearMetaDriveResponse>();
  @$core.pragma('dart2js:noInline')
  static ClearMetaDriveResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ClearMetaDriveResponse>(create);
  static ClearMetaDriveResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);
}

class RebuildManifestRequest extends $pb.GeneratedMessage {
  factory RebuildManifestRequest() => create();
  RebuildManifestRequest._() : super();
  factory RebuildManifestRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RebuildManifestRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RebuildManifestRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RebuildManifestRequest clone() => RebuildManifestRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RebuildManifestRequest copyWith(void Function(RebuildManifestRequest) updates) => super.copyWith((message) => updates(message as RebuildManifestRequest)) as RebuildManifestRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RebuildManifestRequest create() => RebuildManifestRequest._();
  RebuildManifestRequest createEmptyInstance() => create();
  static $pb.PbList<RebuildManifestRequest> createRepeated() => $pb.PbList<RebuildManifestRequest>();
  @$core.pragma('dart2js:noInline')
  static RebuildManifestRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RebuildManifestRequest>(create);
  static RebuildManifestRequest? _defaultInstance;
}

class RebuildManifestResponse extends $pb.GeneratedMessage {
  factory RebuildManifestResponse({
    $core.bool? success,
    $core.String? message,
    $fixnum.Int64? watermark,
    $core.int? recordCount,
  }) {
    final $result = create();
    if (success != null) {
      $result.success = success;
    }
    if (message != null) {
      $result.message = message;
    }
    if (watermark != null) {
      $result.watermark = watermark;
    }
    if (recordCount != null) {
      $result.recordCount = recordCount;
    }
    return $result;
  }
  RebuildManifestResponse._() : super();
  factory RebuildManifestResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory RebuildManifestResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'RebuildManifestResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..aInt64(3, _omitFieldNames ? '' : 'watermark')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'recordCount', $pb.PbFieldType.O3, protoName: 'recordCount')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  RebuildManifestResponse clone() => RebuildManifestResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  RebuildManifestResponse copyWith(void Function(RebuildManifestResponse) updates) => super.copyWith((message) => updates(message as RebuildManifestResponse)) as RebuildManifestResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RebuildManifestResponse create() => RebuildManifestResponse._();
  RebuildManifestResponse createEmptyInstance() => create();
  static $pb.PbList<RebuildManifestResponse> createRepeated() => $pb.PbList<RebuildManifestResponse>();
  @$core.pragma('dart2js:noInline')
  static RebuildManifestResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RebuildManifestResponse>(create);
  static RebuildManifestResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get watermark => $_getI64(2);
  @$pb.TagNumber(3)
  set watermark($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasWatermark() => $_has(2);
  @$pb.TagNumber(3)
  void clearWatermark() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get recordCount => $_getIZ(3);
  @$pb.TagNumber(4)
  set recordCount($core.int v) { $_setSignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasRecordCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearRecordCount() => clearField(4);
}

class PingRequest extends $pb.GeneratedMessage {
  factory PingRequest() => create();
  PingRequest._() : super();
  factory PingRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PingRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PingRequest', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PingRequest clone() => PingRequest()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PingRequest copyWith(void Function(PingRequest) updates) => super.copyWith((message) => updates(message as PingRequest)) as PingRequest;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PingRequest create() => PingRequest._();
  PingRequest createEmptyInstance() => create();
  static $pb.PbList<PingRequest> createRepeated() => $pb.PbList<PingRequest>();
  @$core.pragma('dart2js:noInline')
  static PingRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PingRequest>(create);
  static PingRequest? _defaultInstance;
}

class PingResponse extends $pb.GeneratedMessage {
  factory PingResponse({
    $fixnum.Int64? serverStartTime,
    $fixnum.Int64? uptimeSeconds,
  }) {
    final $result = create();
    if (serverStartTime != null) {
      $result.serverStartTime = serverStartTime;
    }
    if (uptimeSeconds != null) {
      $result.uptimeSeconds = uptimeSeconds;
    }
    return $result;
  }
  PingResponse._() : super();
  factory PingResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory PingResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'PingResponse', package: const $pb.PackageName(_omitMessageNames ? '' : 'img_syncer'), createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'serverStartTime')
    ..aInt64(2, _omitFieldNames ? '' : 'uptimeSeconds')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  PingResponse clone() => PingResponse()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  PingResponse copyWith(void Function(PingResponse) updates) => super.copyWith((message) => updates(message as PingResponse)) as PingResponse;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PingResponse create() => PingResponse._();
  PingResponse createEmptyInstance() => create();
  static $pb.PbList<PingResponse> createRepeated() => $pb.PbList<PingResponse>();
  @$core.pragma('dart2js:noInline')
  static PingResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PingResponse>(create);
  static PingResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get serverStartTime => $_getI64(0);
  @$pb.TagNumber(1)
  set serverStartTime($fixnum.Int64 v) { $_setInt64(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasServerStartTime() => $_has(0);
  @$pb.TagNumber(1)
  void clearServerStartTime() => clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get uptimeSeconds => $_getI64(1);
  @$pb.TagNumber(2)
  set uptimeSeconds($fixnum.Int64 v) { $_setInt64(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasUptimeSeconds() => $_has(1);
  @$pb.TagNumber(2)
  void clearUptimeSeconds() => clearField(2);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
