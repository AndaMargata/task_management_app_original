import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// Handles uploading files to Backblaze B2 and returning public download URLs.
///
/// The B2 bucket **must be public** so that [CachedNetworkImage] and other
/// widgets can fetch media with a plain GET (no auth header).
class StorageService {
  static const _uuid = Uuid();

  static String? _apiUrl;
  static String? _authToken;
  static String? _downloadUrl;
  static String? _bucketId;
  static String? _bucketName;
  static DateTime? _tokenExpiry;

  /// Returns `true` when a valid auth token is available (cached or fresh).
  static Future<bool> _ensureAuthorized() async {
    if (_authToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return true;
    }
    return _authorize();
  }

  /// Calls `b2_authorize_account` and caches the result for ~23 h.
  static Future<bool> _authorize() async {
    try {
      final keyId = dotenv.env['B2_KEY_ID'] ?? '';
      final appKey = dotenv.env['B2_APP_KEY'] ?? '';
      if (keyId.isEmpty || appKey.isEmpty) {
        debugPrint('StorageService: B2_KEY_ID / B2_APP_KEY missing from .env');
        return false;
      }

      final creds = base64Encode(utf8.encode('$keyId:$appKey'));
      final resp = await http.get(
        Uri.parse('https://api.backblazeb2.com/b2api/v2/b2_authorize_account'),
        headers: {'Authorization': 'Basic $creds'},
      );

      if (resp.statusCode != 200) {
        debugPrint('B2 authorize failed [${resp.statusCode}]: ${resp.body}');
        return false;
      }

      final body = json.decode(resp.body) as Map<String, dynamic>;
      _apiUrl = body['apiUrl'] as String;
      _authToken = body['authorizationToken'] as String;
      _downloadUrl = body['downloadUrl'] as String;
      _tokenExpiry = DateTime.now().add(const Duration(hours: 23));

      final allowed = body['allowed'] as Map<String, dynamic>;
      _bucketId = allowed['bucketId'] as String?;
      _bucketName = allowed['bucketName'] as String?;

      if (_bucketId == null || _bucketName == null) {
        final accountId = body['accountId'] as String;
        final listResp = await http.post(
          Uri.parse('$_apiUrl/b2api/v2/b2_list_buckets'),
          headers: {
            'Authorization': _authToken!,
            'Content-Type': 'application/json',
          },
          body: json.encode({'accountId': accountId}),
        );
        if (listResp.statusCode == 200) {
          final buckets = (json.decode(listResp.body)['buckets'] as List)
              .cast<Map<String, dynamic>>();
          if (buckets.isNotEmpty) {
            _bucketId = buckets.first['bucketId'] as String;
            _bucketName = buckets.first['bucketName'] as String;
          }
        }
      }

      debugPrint('B2 authorized – bucket: $_bucketName ($_bucketId)');
      return _bucketId != null;
    } catch (e) {
      debugPrint('B2 authorize error: $e');
      return false;
    }
  }

  static Future<String?> uploadFile({
    required File file,
    required String folder,
    required String userId,
    required String ext,
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (!await _ensureAuthorized()) return null;
      onProgress?.call(0.05);

      final urlResp = await http.post(
        Uri.parse('$_apiUrl/b2api/v2/b2_get_upload_url'),
        headers: {
          'Authorization': _authToken!,
          'Content-Type': 'application/json',
        },
        body: json.encode({'bucketId': _bucketId}),
      );

      if (urlResp.statusCode != 200) {
        debugPrint('B2 getUploadUrl failed [${urlResp.statusCode}]: ${urlResp.body}');
        _authToken = null;
        _tokenExpiry = null;
        if (!await _authorize()) return null;
        return uploadFile(
          file: file,
          folder: folder,
          userId: userId,
          ext: ext,
          onProgress: onProgress,
        );
      }

      final urlData = json.decode(urlResp.body) as Map<String, dynamic>;
      final uploadUrl = urlData['uploadUrl'] as String;
      final uploadToken = urlData['authorizationToken'] as String;
      onProgress?.call(0.10);

      final bytes = await file.readAsBytes();
      final fileName = '$folder/$userId/${_uuid.v4()}$ext';
      onProgress?.call(0.20);

      final encodedName =
          fileName.split('/').map(Uri.encodeComponent).join('/');

      final uploadResp = await http.post(
        Uri.parse(uploadUrl),
        headers: {
          'Authorization': uploadToken,
          'X-Bz-File-Name': encodedName,
          'Content-Type': _mimeType(ext),
          'Content-Length': bytes.length.toString(),
          'X-Bz-Content-Sha1': 'do_not_verify',
        },
        body: bytes,
      );

      if (uploadResp.statusCode != 200) {
        debugPrint(
            'B2 upload failed [${uploadResp.statusCode}]: ${uploadResp.body}');
        return null;
      }

      onProgress?.call(1.0);

      final url = '$_downloadUrl/file/$_bucketName/$fileName';
      debugPrint('StorageService: uploaded to $url');
      return url;
    } catch (e) {
      debugPrint('StorageService upload error: $e');
      return null;
    }
  }

  static Future<void> deleteFile(String downloadUrl) async {
    try {
      if (!await _ensureAuthorized()) return;

      final prefix = '$_downloadUrl/file/$_bucketName/';
      if (!downloadUrl.startsWith(prefix)) {
        debugPrint('StorageService: URL does not match bucket – skipping delete');
        return;
      }
      final fileName = downloadUrl.substring(prefix.length);

      final listResp = await http.post(
        Uri.parse('$_apiUrl/b2api/v2/b2_list_file_names'),
        headers: {
          'Authorization': _authToken!,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'bucketId': _bucketId,
          'prefix': fileName,
          'maxFileCount': 1,
        }),
      );

      if (listResp.statusCode == 200) {
        final files = (json.decode(listResp.body)['files'] as List)
            .cast<Map<String, dynamic>>();
        if (files.isNotEmpty) {
          await http.post(
            Uri.parse('$_apiUrl/b2api/v2/b2_delete_file_version'),
            headers: {
              'Authorization': _authToken!,
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'fileId': files.first['fileId'],
              'fileName': files.first['fileName'],
            }),
          );
        }
      }
    } catch (e) {
      debugPrint('StorageService delete error: $e');
    }
  }

  static String _mimeType(String ext) {
    switch (ext.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.m4a':
        return 'audio/m4a';
      case '.aac':
        return 'audio/aac';
      case '.wav':
        return 'audio/wav';
      default:
        return 'application/octet-stream';
    }
  }
}
