//
//  Generated code. Do not modify.
//  source: proto/img_syncer.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use directoryTypeDescriptor instead')
const DirectoryType$json = {
  '1': 'DirectoryType',
  '2': [
    {'1': 'DIRECTORY_TYPE_01', '2': 0},
    {'1': 'DIRECTORY_TYPE_02', '2': 1},
  ],
};

/// Descriptor for `DirectoryType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List directoryTypeDescriptor = $convert.base64Decode(
    'Cg1EaXJlY3RvcnlUeXBlEhUKEURJUkVDVE9SWV9UWVBFXzAxEAASFQoRRElSRUNUT1JZX1RZUE'
    'VfMDIQAQ==');

@$core.Deprecated('Use setDirectoryTypeRequestDescriptor instead')
const SetDirectoryTypeRequest$json = {
  '1': 'SetDirectoryTypeRequest',
  '2': [
    {'1': 'directoryType', '3': 1, '4': 1, '5': 14, '6': '.img_syncer.DirectoryType', '10': 'directoryType'},
  ],
};

/// Descriptor for `SetDirectoryTypeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setDirectoryTypeRequestDescriptor = $convert.base64Decode(
    'ChdTZXREaXJlY3RvcnlUeXBlUmVxdWVzdBI/Cg1kaXJlY3RvcnlUeXBlGAEgASgOMhkuaW1nX3'
    'N5bmNlci5EaXJlY3RvcnlUeXBlUg1kaXJlY3RvcnlUeXBl');

@$core.Deprecated('Use setDirectoryTypeResponseDescriptor instead')
const SetDirectoryTypeResponse$json = {
  '1': 'SetDirectoryTypeResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `SetDirectoryTypeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setDirectoryTypeResponseDescriptor = $convert.base64Decode(
    'ChhTZXREaXJlY3RvcnlUeXBlUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxIYCg'
    'dtZXNzYWdlGAIgASgJUgdtZXNzYWdl');

@$core.Deprecated('Use fileInfoDescriptor instead')
const FileInfo$json = {
  '1': 'FileInfo',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'size', '3': 2, '4': 1, '5': 3, '10': 'size'},
    {'1': 'isLivePhoto', '3': 3, '4': 1, '5': 8, '10': 'isLivePhoto'},
  ],
};

/// Descriptor for `FileInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fileInfoDescriptor = $convert.base64Decode(
    'CghGaWxlSW5mbxISCgRwYXRoGAEgASgJUgRwYXRoEhIKBHNpemUYAiABKANSBHNpemUSIAoLaX'
    'NMaXZlUGhvdG8YAyABKAhSC2lzTGl2ZVBob3Rv');

@$core.Deprecated('Use listByDateRequestDescriptor instead')
const ListByDateRequest$json = {
  '1': 'ListByDateRequest',
  '2': [
    {'1': 'date', '3': 1, '4': 1, '5': 9, '10': 'date'},
    {'1': 'offset', '3': 2, '4': 1, '5': 5, '10': 'offset'},
    {'1': 'maxReturn', '3': 3, '4': 1, '5': 5, '10': 'maxReturn'},
    {'1': 'album', '3': 4, '4': 1, '5': 9, '10': 'album'},
  ],
};

/// Descriptor for `ListByDateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listByDateRequestDescriptor = $convert.base64Decode(
    'ChFMaXN0QnlEYXRlUmVxdWVzdBISCgRkYXRlGAEgASgJUgRkYXRlEhYKBm9mZnNldBgCIAEoBV'
    'IGb2Zmc2V0EhwKCW1heFJldHVybhgDIAEoBVIJbWF4UmV0dXJuEhQKBWFsYnVtGAQgASgJUgVh'
    'bGJ1bQ==');

@$core.Deprecated('Use listByDateResponseDescriptor instead')
const ListByDateResponse$json = {
  '1': 'ListByDateResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'infos', '3': 3, '4': 3, '5': 11, '6': '.img_syncer.FileInfo', '10': 'infos'},
  ],
};

/// Descriptor for `ListByDateResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listByDateResponseDescriptor = $convert.base64Decode(
    'ChJMaXN0QnlEYXRlUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxIYCgdtZXNzYW'
    'dlGAIgASgJUgdtZXNzYWdlEioKBWluZm9zGAMgAygLMhQuaW1nX3N5bmNlci5GaWxlSW5mb1IF'
    'aW5mb3M=');

@$core.Deprecated('Use deleteRequestDescriptor instead')
const DeleteRequest$json = {
  '1': 'DeleteRequest',
  '2': [
    {'1': 'paths', '3': 1, '4': 3, '5': 9, '10': 'paths'},
  ],
};

/// Descriptor for `DeleteRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteRequestDescriptor = $convert.base64Decode(
    'Cg1EZWxldGVSZXF1ZXN0EhQKBXBhdGhzGAEgAygJUgVwYXRocw==');

@$core.Deprecated('Use deleteResponseDescriptor instead')
const DeleteResponse$json = {
  '1': 'DeleteResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `DeleteResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteResponseDescriptor = $convert.base64Decode(
    'Cg5EZWxldGVSZXNwb25zZRIYCgdzdWNjZXNzGAEgASgIUgdzdWNjZXNzEhgKB21lc3NhZ2UYAi'
    'ABKAlSB21lc3NhZ2U=');

@$core.Deprecated('Use albumInfoDescriptor instead')
const AlbumInfo$json = {
  '1': 'AlbumInfo',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'count', '3': 2, '4': 1, '5': 3, '10': 'count'},
    {'1': 'coverPath', '3': 3, '4': 1, '5': 9, '10': 'coverPath'},
    {'1': 'isDefault', '3': 4, '4': 1, '5': 8, '10': 'isDefault'},
  ],
};

/// Descriptor for `AlbumInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List albumInfoDescriptor = $convert.base64Decode(
    'CglBbGJ1bUluZm8SEgoEbmFtZRgBIAEoCVIEbmFtZRIUCgVjb3VudBgCIAEoA1IFY291bnQSHA'
    'oJY292ZXJQYXRoGAMgASgJUgljb3ZlclBhdGgSHAoJaXNEZWZhdWx0GAQgASgIUglpc0RlZmF1'
    'bHQ=');

@$core.Deprecated('Use listAlbumsRequestDescriptor instead')
const ListAlbumsRequest$json = {
  '1': 'ListAlbumsRequest',
};

/// Descriptor for `ListAlbumsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listAlbumsRequestDescriptor = $convert.base64Decode(
    'ChFMaXN0QWxidW1zUmVxdWVzdA==');

@$core.Deprecated('Use listAlbumsResponseDescriptor instead')
const ListAlbumsResponse$json = {
  '1': 'ListAlbumsResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'albums', '3': 3, '4': 3, '5': 11, '6': '.img_syncer.AlbumInfo', '10': 'albums'},
  ],
};

/// Descriptor for `ListAlbumsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listAlbumsResponseDescriptor = $convert.base64Decode(
    'ChJMaXN0QWxidW1zUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxIYCgdtZXNzYW'
    'dlGAIgASgJUgdtZXNzYWdlEi0KBmFsYnVtcxgDIAMoCzIVLmltZ19zeW5jZXIuQWxidW1JbmZv'
    'UgZhbGJ1bXM=');

@$core.Deprecated('Use createAlbumRequestDescriptor instead')
const CreateAlbumRequest$json = {
  '1': 'CreateAlbumRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `CreateAlbumRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createAlbumRequestDescriptor = $convert.base64Decode(
    'ChJDcmVhdGVBbGJ1bVJlcXVlc3QSEgoEbmFtZRgBIAEoCVIEbmFtZQ==');

@$core.Deprecated('Use createAlbumResponseDescriptor instead')
const CreateAlbumResponse$json = {
  '1': 'CreateAlbumResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `CreateAlbumResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createAlbumResponseDescriptor = $convert.base64Decode(
    'ChNDcmVhdGVBbGJ1bVJlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3MSGAoHbWVzc2'
    'FnZRgCIAEoCVIHbWVzc2FnZQ==');

@$core.Deprecated('Use deleteAlbumRequestDescriptor instead')
const DeleteAlbumRequest$json = {
  '1': 'DeleteAlbumRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `DeleteAlbumRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteAlbumRequestDescriptor = $convert.base64Decode(
    'ChJEZWxldGVBbGJ1bVJlcXVlc3QSEgoEbmFtZRgBIAEoCVIEbmFtZQ==');

@$core.Deprecated('Use deleteAlbumResponseDescriptor instead')
const DeleteAlbumResponse$json = {
  '1': 'DeleteAlbumResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `DeleteAlbumResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteAlbumResponseDescriptor = $convert.base64Decode(
    'ChNEZWxldGVBbGJ1bVJlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3MSGAoHbWVzc2'
    'FnZRgCIAEoCVIHbWVzc2FnZQ==');

@$core.Deprecated('Use renameAlbumRequestDescriptor instead')
const RenameAlbumRequest$json = {
  '1': 'RenameAlbumRequest',
  '2': [
    {'1': 'oldName', '3': 1, '4': 1, '5': 9, '10': 'oldName'},
    {'1': 'newName', '3': 2, '4': 1, '5': 9, '10': 'newName'},
  ],
};

/// Descriptor for `RenameAlbumRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List renameAlbumRequestDescriptor = $convert.base64Decode(
    'ChJSZW5hbWVBbGJ1bVJlcXVlc3QSGAoHb2xkTmFtZRgBIAEoCVIHb2xkTmFtZRIYCgduZXdOYW'
    '1lGAIgASgJUgduZXdOYW1l');

@$core.Deprecated('Use renameAlbumResponseDescriptor instead')
const RenameAlbumResponse$json = {
  '1': 'RenameAlbumResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `RenameAlbumResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List renameAlbumResponseDescriptor = $convert.base64Decode(
    'ChNSZW5hbWVBbGJ1bVJlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3MSGAoHbWVzc2'
    'FnZRgCIAEoCVIHbWVzc2FnZQ==');

@$core.Deprecated('Use moveAssetsRequestDescriptor instead')
const MoveAssetsRequest$json = {
  '1': 'MoveAssetsRequest',
  '2': [
    {'1': 'paths', '3': 1, '4': 3, '5': 9, '10': 'paths'},
    {'1': 'targetAlbum', '3': 2, '4': 1, '5': 9, '10': 'targetAlbum'},
  ],
};

/// Descriptor for `MoveAssetsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List moveAssetsRequestDescriptor = $convert.base64Decode(
    'ChFNb3ZlQXNzZXRzUmVxdWVzdBIUCgVwYXRocxgBIAMoCVIFcGF0aHMSIAoLdGFyZ2V0QWxidW'
    '0YAiABKAlSC3RhcmdldEFsYnVt');

@$core.Deprecated('Use moveAssetsResponseDescriptor instead')
const MoveAssetsResponse$json = {
  '1': 'MoveAssetsResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'newPaths', '3': 3, '4': 3, '5': 9, '10': 'newPaths'},
  ],
};

/// Descriptor for `MoveAssetsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List moveAssetsResponseDescriptor = $convert.base64Decode(
    'ChJNb3ZlQXNzZXRzUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxIYCgdtZXNzYW'
    'dlGAIgASgJUgdtZXNzYWdlEhoKCG5ld1BhdGhzGAMgAygJUghuZXdQYXRocw==');

@$core.Deprecated('Use filterNotUploadedRequestInfoDescriptor instead')
const FilterNotUploadedRequestInfo$json = {
  '1': 'FilterNotUploadedRequestInfo',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'date', '3': 2, '4': 1, '5': 9, '10': 'date'},
    {'1': 'id', '3': 3, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `FilterNotUploadedRequestInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List filterNotUploadedRequestInfoDescriptor = $convert.base64Decode(
    'ChxGaWx0ZXJOb3RVcGxvYWRlZFJlcXVlc3RJbmZvEhIKBG5hbWUYASABKAlSBG5hbWUSEgoEZG'
    'F0ZRgCIAEoCVIEZGF0ZRIOCgJpZBgDIAEoCVICaWQ=');

@$core.Deprecated('Use filterNotUploadedRequestDescriptor instead')
const FilterNotUploadedRequest$json = {
  '1': 'FilterNotUploadedRequest',
  '2': [
    {'1': 'photos', '3': 1, '4': 3, '5': 11, '6': '.img_syncer.FilterNotUploadedRequestInfo', '10': 'photos'},
    {'1': 'isFinished', '3': 2, '4': 1, '5': 8, '10': 'isFinished'},
  ],
};

/// Descriptor for `FilterNotUploadedRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List filterNotUploadedRequestDescriptor = $convert.base64Decode(
    'ChhGaWx0ZXJOb3RVcGxvYWRlZFJlcXVlc3QSQAoGcGhvdG9zGAEgAygLMiguaW1nX3N5bmNlci'
    '5GaWx0ZXJOb3RVcGxvYWRlZFJlcXVlc3RJbmZvUgZwaG90b3MSHgoKaXNGaW5pc2hlZBgCIAEo'
    'CFIKaXNGaW5pc2hlZA==');

@$core.Deprecated('Use filterNotUploadedResponseDescriptor instead')
const FilterNotUploadedResponse$json = {
  '1': 'FilterNotUploadedResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'notUploaedIDs', '3': 3, '4': 3, '5': 9, '10': 'notUploaedIDs'},
    {'1': 'uploadedIDs', '3': 4, '4': 3, '5': 9, '10': 'uploadedIDs'},
    {'1': 'isFinished', '3': 5, '4': 1, '5': 8, '10': 'isFinished'},
    {'1': 'invalid_ids', '3': 6, '4': 3, '5': 9, '10': 'invalidIds'},
    {'1': 'notUploadedIDs', '3': 7, '4': 3, '5': 9, '10': 'notUploadedIDs'},
  ],
};

/// Descriptor for `FilterNotUploadedResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List filterNotUploadedResponseDescriptor = $convert.base64Decode(
    'ChlGaWx0ZXJOb3RVcGxvYWRlZFJlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3MSGA'
    'oHbWVzc2FnZRgCIAEoCVIHbWVzc2FnZRIkCg1ub3RVcGxvYWVkSURzGAMgAygJUg1ub3RVcGxv'
    'YWVkSURzEiAKC3VwbG9hZGVkSURzGAQgAygJUgt1cGxvYWRlZElEcxIeCgppc0ZpbmlzaGVkGA'
    'UgASgIUgppc0ZpbmlzaGVkEh8KC2ludmFsaWRfaWRzGAYgAygJUgppbnZhbGlkSWRzEiYKDm5v'
    'dFVwbG9hZGVkSURzGAcgAygJUg5ub3RVcGxvYWRlZElEcw==');

@$core.Deprecated('Use setDriveSMBRequestDescriptor instead')
const SetDriveSMBRequest$json = {
  '1': 'SetDriveSMBRequest',
  '2': [
    {'1': 'addr', '3': 1, '4': 1, '5': 9, '10': 'addr'},
    {'1': 'username', '3': 2, '4': 1, '5': 9, '10': 'username'},
    {'1': 'password', '3': 3, '4': 1, '5': 9, '10': 'password'},
    {'1': 'share', '3': 4, '4': 1, '5': 9, '10': 'share'},
    {'1': 'root', '3': 5, '4': 1, '5': 9, '10': 'root'},
    {'1': 'isMetaDrive', '3': 6, '4': 1, '5': 8, '10': 'isMetaDrive'},
  ],
};

/// Descriptor for `SetDriveSMBRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setDriveSMBRequestDescriptor = $convert.base64Decode(
    'ChJTZXREcml2ZVNNQlJlcXVlc3QSEgoEYWRkchgBIAEoCVIEYWRkchIaCgh1c2VybmFtZRgCIA'
    'EoCVIIdXNlcm5hbWUSGgoIcGFzc3dvcmQYAyABKAlSCHBhc3N3b3JkEhQKBXNoYXJlGAQgASgJ'
    'UgVzaGFyZRISCgRyb290GAUgASgJUgRyb290EiAKC2lzTWV0YURyaXZlGAYgASgIUgtpc01ldG'
    'FEcml2ZQ==');

@$core.Deprecated('Use setDriveSMBResponseDescriptor instead')
const SetDriveSMBResponse$json = {
  '1': 'SetDriveSMBResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `SetDriveSMBResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setDriveSMBResponseDescriptor = $convert.base64Decode(
    'ChNTZXREcml2ZVNNQlJlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3MSGAoHbWVzc2'
    'FnZRgCIAEoCVIHbWVzc2FnZQ==');

@$core.Deprecated('Use listDriveSMBSharesRequestDescriptor instead')
const ListDriveSMBSharesRequest$json = {
  '1': 'ListDriveSMBSharesRequest',
  '2': [
    {'1': 'isMetaDrive', '3': 1, '4': 1, '5': 8, '10': 'isMetaDrive'},
  ],
};

/// Descriptor for `ListDriveSMBSharesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listDriveSMBSharesRequestDescriptor = $convert.base64Decode(
    'ChlMaXN0RHJpdmVTTUJTaGFyZXNSZXF1ZXN0EiAKC2lzTWV0YURyaXZlGAEgASgIUgtpc01ldG'
    'FEcml2ZQ==');

@$core.Deprecated('Use listDriveSMBSharesResponseDescriptor instead')
const ListDriveSMBSharesResponse$json = {
  '1': 'ListDriveSMBSharesResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'shares', '3': 3, '4': 3, '5': 9, '10': 'shares'},
  ],
};

/// Descriptor for `ListDriveSMBSharesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listDriveSMBSharesResponseDescriptor = $convert.base64Decode(
    'ChpMaXN0RHJpdmVTTUJTaGFyZXNSZXNwb25zZRIYCgdzdWNjZXNzGAEgASgIUgdzdWNjZXNzEh'
    'gKB21lc3NhZ2UYAiABKAlSB21lc3NhZ2USFgoGc2hhcmVzGAMgAygJUgZzaGFyZXM=');

@$core.Deprecated('Use listDriveSMBDirRequestDescriptor instead')
const ListDriveSMBDirRequest$json = {
  '1': 'ListDriveSMBDirRequest',
  '2': [
    {'1': 'share', '3': 1, '4': 1, '5': 9, '10': 'share'},
    {'1': 'dir', '3': 2, '4': 1, '5': 9, '10': 'dir'},
    {'1': 'isMetaDrive', '3': 3, '4': 1, '5': 8, '10': 'isMetaDrive'},
  ],
};

/// Descriptor for `ListDriveSMBDirRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listDriveSMBDirRequestDescriptor = $convert.base64Decode(
    'ChZMaXN0RHJpdmVTTUJEaXJSZXF1ZXN0EhQKBXNoYXJlGAEgASgJUgVzaGFyZRIQCgNkaXIYAi'
    'ABKAlSA2RpchIgCgtpc01ldGFEcml2ZRgDIAEoCFILaXNNZXRhRHJpdmU=');

@$core.Deprecated('Use listDriveSMBDirResponseDescriptor instead')
const ListDriveSMBDirResponse$json = {
  '1': 'ListDriveSMBDirResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'dirs', '3': 3, '4': 3, '5': 9, '10': 'dirs'},
  ],
};

/// Descriptor for `ListDriveSMBDirResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listDriveSMBDirResponseDescriptor = $convert.base64Decode(
    'ChdMaXN0RHJpdmVTTUJEaXJSZXNwb25zZRIYCgdzdWNjZXNzGAEgASgIUgdzdWNjZXNzEhgKB2'
    '1lc3NhZ2UYAiABKAlSB21lc3NhZ2USEgoEZGlycxgDIAMoCVIEZGlycw==');

@$core.Deprecated('Use setDriveSMBShareRequestDescriptor instead')
const SetDriveSMBShareRequest$json = {
  '1': 'SetDriveSMBShareRequest',
  '2': [
    {'1': 'share', '3': 1, '4': 1, '5': 9, '10': 'share'},
    {'1': 'root', '3': 2, '4': 1, '5': 9, '10': 'root'},
    {'1': 'isMetaDrive', '3': 3, '4': 1, '5': 8, '10': 'isMetaDrive'},
  ],
};

/// Descriptor for `SetDriveSMBShareRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setDriveSMBShareRequestDescriptor = $convert.base64Decode(
    'ChdTZXREcml2ZVNNQlNoYXJlUmVxdWVzdBIUCgVzaGFyZRgBIAEoCVIFc2hhcmUSEgoEcm9vdB'
    'gCIAEoCVIEcm9vdBIgCgtpc01ldGFEcml2ZRgDIAEoCFILaXNNZXRhRHJpdmU=');

@$core.Deprecated('Use setDriveSMBShareResponseDescriptor instead')
const SetDriveSMBShareResponse$json = {
  '1': 'SetDriveSMBShareResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `SetDriveSMBShareResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setDriveSMBShareResponseDescriptor = $convert.base64Decode(
    'ChhTZXREcml2ZVNNQlNoYXJlUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxIYCg'
    'dtZXNzYWdlGAIgASgJUgdtZXNzYWdl');

@$core.Deprecated('Use setDriveWebdavRequestDescriptor instead')
const SetDriveWebdavRequest$json = {
  '1': 'SetDriveWebdavRequest',
  '2': [
    {'1': 'addr', '3': 1, '4': 1, '5': 9, '10': 'addr'},
    {'1': 'username', '3': 2, '4': 1, '5': 9, '10': 'username'},
    {'1': 'password', '3': 3, '4': 1, '5': 9, '10': 'password'},
    {'1': 'root', '3': 4, '4': 1, '5': 9, '10': 'root'},
    {'1': 'insecure', '3': 5, '4': 1, '5': 8, '10': 'insecure'},
    {'1': 'isMetaDrive', '3': 6, '4': 1, '5': 8, '10': 'isMetaDrive'},
  ],
};

/// Descriptor for `SetDriveWebdavRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setDriveWebdavRequestDescriptor = $convert.base64Decode(
    'ChVTZXREcml2ZVdlYmRhdlJlcXVlc3QSEgoEYWRkchgBIAEoCVIEYWRkchIaCgh1c2VybmFtZR'
    'gCIAEoCVIIdXNlcm5hbWUSGgoIcGFzc3dvcmQYAyABKAlSCHBhc3N3b3JkEhIKBHJvb3QYBCAB'
    'KAlSBHJvb3QSGgoIaW5zZWN1cmUYBSABKAhSCGluc2VjdXJlEiAKC2lzTWV0YURyaXZlGAYgAS'
    'gIUgtpc01ldGFEcml2ZQ==');

@$core.Deprecated('Use setDriveWebdavResponseDescriptor instead')
const SetDriveWebdavResponse$json = {
  '1': 'SetDriveWebdavResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `SetDriveWebdavResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setDriveWebdavResponseDescriptor = $convert.base64Decode(
    'ChZTZXREcml2ZVdlYmRhdlJlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3MSGAoHbW'
    'Vzc2FnZRgCIAEoCVIHbWVzc2FnZQ==');

@$core.Deprecated('Use listDriveWebdavDirRequestDescriptor instead')
const ListDriveWebdavDirRequest$json = {
  '1': 'ListDriveWebdavDirRequest',
  '2': [
    {'1': 'dir', '3': 1, '4': 1, '5': 9, '10': 'dir'},
    {'1': 'isMetaDrive', '3': 2, '4': 1, '5': 8, '10': 'isMetaDrive'},
  ],
};

/// Descriptor for `ListDriveWebdavDirRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listDriveWebdavDirRequestDescriptor = $convert.base64Decode(
    'ChlMaXN0RHJpdmVXZWJkYXZEaXJSZXF1ZXN0EhAKA2RpchgBIAEoCVIDZGlyEiAKC2lzTWV0YU'
    'RyaXZlGAIgASgIUgtpc01ldGFEcml2ZQ==');

@$core.Deprecated('Use listDriveWebdavDirResponseDescriptor instead')
const ListDriveWebdavDirResponse$json = {
  '1': 'ListDriveWebdavDirResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'dirs', '3': 3, '4': 3, '5': 9, '10': 'dirs'},
  ],
};

/// Descriptor for `ListDriveWebdavDirResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listDriveWebdavDirResponseDescriptor = $convert.base64Decode(
    'ChpMaXN0RHJpdmVXZWJkYXZEaXJSZXNwb25zZRIYCgdzdWNjZXNzGAEgASgIUgdzdWNjZXNzEh'
    'gKB21lc3NhZ2UYAiABKAlSB21lc3NhZ2USEgoEZGlycxgDIAMoCVIEZGlycw==');

@$core.Deprecated('Use setDriveNFSRequestDescriptor instead')
const SetDriveNFSRequest$json = {
  '1': 'SetDriveNFSRequest',
  '2': [
    {'1': 'addr', '3': 1, '4': 1, '5': 9, '10': 'addr'},
    {'1': 'root', '3': 2, '4': 1, '5': 9, '10': 'root'},
    {'1': 'isMetaDrive', '3': 3, '4': 1, '5': 8, '10': 'isMetaDrive'},
  ],
};

/// Descriptor for `SetDriveNFSRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setDriveNFSRequestDescriptor = $convert.base64Decode(
    'ChJTZXREcml2ZU5GU1JlcXVlc3QSEgoEYWRkchgBIAEoCVIEYWRkchISCgRyb290GAIgASgJUg'
    'Ryb290EiAKC2lzTWV0YURyaXZlGAMgASgIUgtpc01ldGFEcml2ZQ==');

@$core.Deprecated('Use setDriveNFSResponseDescriptor instead')
const SetDriveNFSResponse$json = {
  '1': 'SetDriveNFSResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `SetDriveNFSResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setDriveNFSResponseDescriptor = $convert.base64Decode(
    'ChNTZXREcml2ZU5GU1Jlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3MSGAoHbWVzc2'
    'FnZRgCIAEoCVIHbWVzc2FnZQ==');

@$core.Deprecated('Use listDriveNFSDirRequestDescriptor instead')
const ListDriveNFSDirRequest$json = {
  '1': 'ListDriveNFSDirRequest',
  '2': [
    {'1': 'dir', '3': 1, '4': 1, '5': 9, '10': 'dir'},
    {'1': 'isMetaDrive', '3': 2, '4': 1, '5': 8, '10': 'isMetaDrive'},
  ],
};

/// Descriptor for `ListDriveNFSDirRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listDriveNFSDirRequestDescriptor = $convert.base64Decode(
    'ChZMaXN0RHJpdmVORlNEaXJSZXF1ZXN0EhAKA2RpchgBIAEoCVIDZGlyEiAKC2lzTWV0YURyaX'
    'ZlGAIgASgIUgtpc01ldGFEcml2ZQ==');

@$core.Deprecated('Use listDriveNFSDirResponseDescriptor instead')
const ListDriveNFSDirResponse$json = {
  '1': 'ListDriveNFSDirResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'dirs', '3': 3, '4': 3, '5': 9, '10': 'dirs'},
  ],
};

/// Descriptor for `ListDriveNFSDirResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listDriveNFSDirResponseDescriptor = $convert.base64Decode(
    'ChdMaXN0RHJpdmVORlNEaXJSZXNwb25zZRIYCgdzdWNjZXNzGAEgASgIUgdzdWNjZXNzEhgKB2'
    '1lc3NhZ2UYAiABKAlSB21lc3NhZ2USEgoEZGlycxgDIAMoCVIEZGlycw==');

@$core.Deprecated('Use setLocalCacheDirRequestDescriptor instead')
const SetLocalCacheDirRequest$json = {
  '1': 'SetLocalCacheDirRequest',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
  ],
};

/// Descriptor for `SetLocalCacheDirRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setLocalCacheDirRequestDescriptor = $convert.base64Decode(
    'ChdTZXRMb2NhbENhY2hlRGlyUmVxdWVzdBISCgRwYXRoGAEgASgJUgRwYXRo');

@$core.Deprecated('Use setLocalCacheDirResponseDescriptor instead')
const SetLocalCacheDirResponse$json = {
  '1': 'SetLocalCacheDirResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `SetLocalCacheDirResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setLocalCacheDirResponseDescriptor = $convert.base64Decode(
    'ChhTZXRMb2NhbENhY2hlRGlyUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxIYCg'
    'dtZXNzYWdlGAIgASgJUgdtZXNzYWdl');

@$core.Deprecated('Use syncManifestRequestDescriptor instead')
const SyncManifestRequest$json = {
  '1': 'SyncManifestRequest',
};

/// Descriptor for `SyncManifestRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncManifestRequestDescriptor = $convert.base64Decode(
    'ChNTeW5jTWFuaWZlc3RSZXF1ZXN0');

@$core.Deprecated('Use syncManifestResponseDescriptor instead')
const SyncManifestResponse$json = {
  '1': 'SyncManifestResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'watermark', '3': 3, '4': 1, '5': 3, '10': 'watermark'},
    {'1': 'recordCount', '3': 4, '4': 1, '5': 5, '10': 'recordCount'},
  ],
};

/// Descriptor for `SyncManifestResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncManifestResponseDescriptor = $convert.base64Decode(
    'ChRTeW5jTWFuaWZlc3RSZXNwb25zZRIYCgdzdWNjZXNzGAEgASgIUgdzdWNjZXNzEhgKB21lc3'
    'NhZ2UYAiABKAlSB21lc3NhZ2USHAoJd2F0ZXJtYXJrGAMgASgDUgl3YXRlcm1hcmsSIAoLcmVj'
    'b3JkQ291bnQYBCABKAVSC3JlY29yZENvdW50');

@$core.Deprecated('Use clearMetaDriveRequestDescriptor instead')
const ClearMetaDriveRequest$json = {
  '1': 'ClearMetaDriveRequest',
};

/// Descriptor for `ClearMetaDriveRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clearMetaDriveRequestDescriptor = $convert.base64Decode(
    'ChVDbGVhck1ldGFEcml2ZVJlcXVlc3Q=');

@$core.Deprecated('Use clearMetaDriveResponseDescriptor instead')
const ClearMetaDriveResponse$json = {
  '1': 'ClearMetaDriveResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `ClearMetaDriveResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clearMetaDriveResponseDescriptor = $convert.base64Decode(
    'ChZDbGVhck1ldGFEcml2ZVJlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3MSGAoHbW'
    'Vzc2FnZRgCIAEoCVIHbWVzc2FnZQ==');

@$core.Deprecated('Use rebuildManifestRequestDescriptor instead')
const RebuildManifestRequest$json = {
  '1': 'RebuildManifestRequest',
};

/// Descriptor for `RebuildManifestRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rebuildManifestRequestDescriptor = $convert.base64Decode(
    'ChZSZWJ1aWxkTWFuaWZlc3RSZXF1ZXN0');

@$core.Deprecated('Use rebuildManifestResponseDescriptor instead')
const RebuildManifestResponse$json = {
  '1': 'RebuildManifestResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'watermark', '3': 3, '4': 1, '5': 3, '10': 'watermark'},
    {'1': 'recordCount', '3': 4, '4': 1, '5': 5, '10': 'recordCount'},
  ],
};

/// Descriptor for `RebuildManifestResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rebuildManifestResponseDescriptor = $convert.base64Decode(
    'ChdSZWJ1aWxkTWFuaWZlc3RSZXNwb25zZRIYCgdzdWNjZXNzGAEgASgIUgdzdWNjZXNzEhgKB2'
    '1lc3NhZ2UYAiABKAlSB21lc3NhZ2USHAoJd2F0ZXJtYXJrGAMgASgDUgl3YXRlcm1hcmsSIAoL'
    'cmVjb3JkQ291bnQYBCABKAVSC3JlY29yZENvdW50');

@$core.Deprecated('Use pingRequestDescriptor instead')
const PingRequest$json = {
  '1': 'PingRequest',
};

/// Descriptor for `PingRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pingRequestDescriptor = $convert.base64Decode(
    'CgtQaW5nUmVxdWVzdA==');

@$core.Deprecated('Use pingResponseDescriptor instead')
const PingResponse$json = {
  '1': 'PingResponse',
  '2': [
    {'1': 'server_start_time', '3': 1, '4': 1, '5': 3, '10': 'serverStartTime'},
    {'1': 'uptime_seconds', '3': 2, '4': 1, '5': 3, '10': 'uptimeSeconds'},
  ],
};

/// Descriptor for `PingResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pingResponseDescriptor = $convert.base64Decode(
    'CgxQaW5nUmVzcG9uc2USKgoRc2VydmVyX3N0YXJ0X3RpbWUYASABKANSD3NlcnZlclN0YXJ0VG'
    'ltZRIlCg51cHRpbWVfc2Vjb25kcxgCIAEoA1INdXB0aW1lU2Vjb25kcw==');

