import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class DownloadService {
  DownloadService._();

  static final DownloadService instance = DownloadService._();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://ezisaver.ezitech.org/api',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  /// Separate client for fetching the actual video file.
  ///
  /// The API client sends JSON headers and uses a short receive timeout, both
  /// of which break large binary downloads: `Accept: application/json` can make
  /// the server answer with JSON instead of the file, and a 30s receive timeout
  /// aborts slow transfers.
  final Dio _fileDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      headers: {'Accept': '*/*'},
      followRedirects: true,
      responseType: ResponseType.stream,
    ),
  );

  static const String _cacheKey = 'recent_downloads';

  // ============================================================
  // CREATE DOWNLOAD
  // ============================================================

  Future<Map<String, dynamic>> createDownload({
    required String url,
    required String platform,
    required String quality,
  }) async {
    try {
      debugPrint('==========================================');
      debugPrint('📤 CREATE DOWNLOAD REQUEST');
      debugPrint('🌐 API: ${_dio.options.baseUrl}/downloads');
      debugPrint('🔗 URL: $url');
      debugPrint('📱 Platform: $platform');
      debugPrint('🎞️ Quality: $quality');
      debugPrint('==========================================');

      final response = await _dio.post(
        '/downloads',
        data: {'url': url, 'platform': platform, 'quality': quality},
      );

      debugPrint('✅ API REQUEST SUCCESS');
      debugPrint('📡 Status Code: ${response.statusCode}');
      debugPrint('📦 Response: ${response.data}');

      final data = Map<String, dynamic>.from(response.data['data']);

      debugPrint('🆔 Created Download ID: ${data['id']}');
      debugPrint('📊 Initial Status: ${data['status']}');

      await _addToCache(data);

      return data;
    } on DioException catch (e) {
      debugPrint('==========================================');
      debugPrint('❌ CREATE DOWNLOAD API ERROR');
      debugPrint('❌ Type: ${e.type}');
      debugPrint('❌ Message: ${e.message}');
      debugPrint('❌ Status Code: ${e.response?.statusCode}');
      debugPrint('❌ Response: ${e.response?.data}');
      debugPrint('==========================================');

      throw Exception(
        e.response?.data?['message'] ??
            'Unable to create the download request.',
      );
    } catch (e) {
      debugPrint('❌ CREATE DOWNLOAD UNKNOWN ERROR: $e');
      throw Exception('Something went wrong while creating the download.');
    }
  }

  // ============================================================
  // GET ALL DOWNLOADS
  // ============================================================

  Future<List<Map<String, dynamic>>> getDownloads({
    bool refresh = false,
  }) async {
    try {
      if (!refresh) {
        final cachedDownloads = await _getCache();

        if (cachedDownloads.isNotEmpty) {
          debugPrint(
            '📦 Returning ${cachedDownloads.length} downloads from local cache.',
          );
          return cachedDownloads;
        }
      }

      debugPrint('📡 Fetching downloads from server...');

      final response = await _dio.get('/downloads');

      debugPrint('✅ GET DOWNLOADS SUCCESS');
      debugPrint('📡 Status Code: ${response.statusCode}');

      final List<dynamic> list = response.data['data'];

      final downloads = list
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      debugPrint('📦 Server returned ${downloads.length} downloads.');

      await _saveCache(downloads);

      return downloads;
    } on DioException catch (e) {
      debugPrint('❌ GET DOWNLOADS ERROR: ${e.message}');
      debugPrint('❌ Response: ${e.response?.data}');

      final cachedDownloads = await _getCache();

      if (cachedDownloads.isNotEmpty) {
        debugPrint('📦 Using cached downloads because API failed.');
        return cachedDownloads;
      }

      throw Exception(
        e.response?.data?['message'] ?? 'Unable to load downloads.',
      );
    }
  }

  // ============================================================
  // GET SINGLE DOWNLOAD
  // ============================================================

  Future<Map<String, dynamic>> getDownload(int id) async {
    try {
      final url = '/downloads/$id';

      debugPrint('🔎 Checking download status...');
      debugPrint('🆔 Download ID: $id');
      debugPrint('🌐 API: ${_dio.options.baseUrl}$url');

      final response = await _dio.get(url);

      final data = Map<String, dynamic>.from(response.data['data']);

      debugPrint(
        '📊 Download #$id status: ${data['status']} '
        '| progress: ${data['progress']}',
      );

      if (data['video_url'] != null) {
        debugPrint('🎬 Video URL received: ${data['video_url']}');
      }

      if (data['error_message'] != null) {
        debugPrint('⚠️ Server error message: ${data['error_message']}');
      }

      await _updateCacheItem(data);

      return data;
    } on DioException catch (e) {
      debugPrint('❌ GET DOWNLOAD #$id ERROR');
      debugPrint('❌ Message: ${e.message}');
      debugPrint('❌ Status Code: ${e.response?.statusCode}');
      debugPrint('❌ Response: ${e.response?.data}');

      throw Exception(
        e.response?.data?['message'] ?? 'Unable to load download details.',
      );
    }
  }

  // ============================================================
  // WAIT FOR DOWNLOAD TO COMPLETE
  // ============================================================

  Future<Map<String, dynamic>> waitForCompletion(
    int id, {
    Duration interval = const Duration(seconds: 2),
    int maxAttempts = 150,
  }) async {
    debugPrint('==========================================');
    debugPrint('⏳ WAITING FOR SERVER DOWNLOAD');
    debugPrint('🆔 Download ID: $id');
    debugPrint('⏱️ Checking every ${interval.inSeconds} seconds');
    debugPrint('==========================================');

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final download = await getDownload(id);

      final status = download['status']?.toString();

      debugPrint(
        '🔄 Attempt ${attempt + 1}/$maxAttempts '
        '| Status: $status '
        '| Progress: ${download['progress'] ?? 0}%',
      );

      if (status == 'completed') {
        debugPrint('==========================================');
        debugPrint('🎉 SERVER DOWNLOAD COMPLETED');
        debugPrint('🆔 Download ID: $id');
        debugPrint('🎬 Video URL: ${download['video_url']}');
        debugPrint('==========================================');

        return download;
      }

      if (status == 'failed') {
        debugPrint('==========================================');
        debugPrint('❌ SERVER DOWNLOAD FAILED');
        debugPrint('🆔 Download ID: $id');
        debugPrint('❌ Error: ${download['error_message']}');
        debugPrint('==========================================');

        throw Exception(
          download['error_message']?.toString() ??
              'The server could not download the video.',
        );
      }

      await Future.delayed(interval);
    }

    throw Exception('The server is taking too long to process the video.');
  }

  // ============================================================
  // DOWNLOAD VIDEO TO PHONE + SAVE TO GALLERY
  // ============================================================

  Future<void> downloadToGallery({
    required String videoUrl,
    required int downloadId,
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      debugPrint('==========================================');
      debugPrint('📱 STARTING PHONE DOWNLOAD');
      debugPrint('🆔 Download ID: $downloadId');
      debugPrint('🌐 Video URL: $videoUrl');
      debugPrint('==========================================');

      // ----------------------------------------------------------
      // 1. Gallery permission
      // ----------------------------------------------------------

      debugPrint('🔐 Checking Gallery permission...');

      final hasAccess = await Gal.hasAccess(toAlbum: true);

      debugPrint('🔐 Gallery access: $hasAccess');

      if (!hasAccess) {
        debugPrint('🔐 Requesting Gallery permission...');

        final granted = await Gal.requestAccess(toAlbum: true);

        debugPrint('🔐 Permission result: $granted');

        if (!granted) {
          throw Exception('Gallery permission was not granted.');
        }
      }

      // ----------------------------------------------------------
      // 2. Temporary phone directory
      // ----------------------------------------------------------

      final directory = await getTemporaryDirectory();

      debugPrint('📂 Temporary directory: ${directory.path}');

      final filePath = '${directory.path}/ezidownload_$downloadId.mp4';

      debugPrint('📄 Temporary video path: $filePath');

      final file = File(filePath);

      if (await file.exists()) {
        debugPrint('🗑️ Old temporary file found. Deleting...');
        await file.delete();
      }

      // ----------------------------------------------------------
      // 3. Download video from Laravel server
      // ----------------------------------------------------------

      debugPrint('⬇️ Starting video download from server...');

      await _fileDio.download(
        videoUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final percent = (received / total * 100).toStringAsFixed(0);

            debugPrint(
              '📱 Phone download progress: $percent% '
              '($received / $total bytes)',
            );
          }

          onProgress?.call(received, total);
        },
      );

      debugPrint('✅ Video downloaded to temporary file.');

      // ----------------------------------------------------------
      // 4. Verify file
      // ----------------------------------------------------------

      final fileExists = await file.exists();

      debugPrint('📄 Temporary file exists: $fileExists');

      if (!fileExists) {
        throw Exception('Video file was not created on the phone.');
      }

      final fileSize = await file.length();

      debugPrint(
        '📦 Temporary file size: '
        '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB',
      );

      if (fileSize == 0) {
        throw Exception('Downloaded video file is empty.');
      }

      // ----------------------------------------------------------
      // 5. Save to Gallery
      // ----------------------------------------------------------

      debugPrint('🖼️ Saving video to Gallery...');
      debugPrint('📁 Album: EziDownload');

      await Gal.putVideo(filePath, album: 'EziDownload');

      debugPrint('==========================================');
      debugPrint('🎉 VIDEO SUCCESSFULLY SAVED TO GALLERY');
      debugPrint('📁 Album: EziDownload');
      debugPrint('🆔 Download ID: $downloadId');
      debugPrint('==========================================');

      // ----------------------------------------------------------
      // 6. Delete temporary file
      // ----------------------------------------------------------

      if (await file.exists()) {
        debugPrint('🗑️ Removing temporary file...');
        await file.delete();
        debugPrint('✅ Temporary file removed.');
      }
    } on GalException catch (e) {
      debugPrint('==========================================');
      debugPrint('❌ GALLERY ERROR');
      debugPrint('❌ Type: ${e.type}');
      debugPrint('❌ Message: ${e.type.message}');
      debugPrint('==========================================');

      throw Exception(e.type.message);
    } on DioException catch (e) {
      debugPrint('==========================================');
      debugPrint('❌ PHONE VIDEO DOWNLOAD ERROR');
      debugPrint('❌ Type: ${e.type}');
      debugPrint('❌ Message: ${e.message}');
      debugPrint('❌ Status Code: ${e.response?.statusCode}');
      debugPrint('❌ Response: ${e.response?.data}');
      debugPrint('❌ Request URL: ${e.requestOptions.uri}');
      debugPrint('==========================================');

      throw Exception(
        e.message ?? 'Unable to download the video to the phone.',
      );
    } catch (e) {
      debugPrint('==========================================');
      debugPrint('❌ PHONE/GALLERY UNKNOWN ERROR');
      debugPrint('❌ $e');
      debugPrint('==========================================');

      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ============================================================
  // COMPLETE DOWNLOAD FLOW
  // ============================================================

  Future<Map<String, dynamic>> processAndSaveToGallery({
    required int downloadId,
    void Function(int received, int total)? onProgress,
  }) async {
    debugPrint('==========================================');
    debugPrint('🚀 STARTING COMPLETE DOWNLOAD FLOW');
    debugPrint('🆔 Download ID: $downloadId');
    debugPrint('==========================================');

    // ----------------------------------------------------------
    // 1. Wait for Laravel + yt-dlp
    // ----------------------------------------------------------

    final download = await waitForCompletion(downloadId);

    // ----------------------------------------------------------
    // 2. Get video URL
    // ----------------------------------------------------------

    final videoUrl = download['video_url']?.toString();

    debugPrint('🎬 Server video_url: $videoUrl');

    if (videoUrl == null || videoUrl.isEmpty) {
      throw Exception(
        'The server completed the download but did not return a video URL.',
      );
    }

    // ----------------------------------------------------------
    // 3. Convert local server URL for phone
    // ----------------------------------------------------------

    final accessibleVideoUrl = _makeAccessibleUrl(videoUrl);

    debugPrint('==========================================');
    debugPrint('🌐 ORIGINAL SERVER URL');
    debugPrint(videoUrl);
    debugPrint('');
    debugPrint('📱 PHONE ACCESSIBLE URL');
    debugPrint(accessibleVideoUrl);
    debugPrint('==========================================');

    // ----------------------------------------------------------
    // 4. Download to phone + Gallery
    // ----------------------------------------------------------

    await downloadToGallery(
      videoUrl: accessibleVideoUrl,
      downloadId: downloadId,
      onProgress: onProgress,
    );

    debugPrint('==========================================');
    debugPrint('🏁 COMPLETE DOWNLOAD FLOW FINISHED');
    debugPrint('🆔 Download ID: $downloadId');
    debugPrint('==========================================');

    return download;
  }

  // ============================================================
  // MAKE LOCAL SERVER URL ACCESSIBLE TO PHONE
  // ============================================================

  String _makeAccessibleUrl(String url) {
    debugPrint('🔧 Converting server URL for phone...');
    debugPrint('🔧 Input URL: $url');

    final convertedUrl = url
        .replaceFirst('http://127.0.0.1:8000', 'https://ezisaver.ezitech.org')
        .replaceFirst('http://localhost:8000', 'https://ezisaver.ezitech.org')
        .replaceFirst(
          'http://192.168.100.173:8000',
          'https://ezisaver.ezitech.org',
        );

    debugPrint('🔧 Converted URL: $convertedUrl');

    return convertedUrl;
  }

  // ============================================================
  // LOCAL CACHE
  // ============================================================

  Future<List<Map<String, dynamic>>> _getCache() async {
    final prefs = await SharedPreferences.getInstance();

    final String? cachedData = prefs.getString(_cacheKey);

    if (cachedData == null || cachedData.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(cachedData);

      return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      debugPrint('⚠️ Cache decode error: $e');
      return [];
    }
  }

  Future<void> _saveCache(List<Map<String, dynamic>> downloads) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_cacheKey, jsonEncode(downloads));
  }

  Future<void> _addToCache(Map<String, dynamic> download) async {
    final downloads = await _getCache();

    downloads.removeWhere((item) => item['id'] == download['id']);

    downloads.insert(0, download);

    if (downloads.length > 20) {
      downloads.removeRange(20, downloads.length);
    }

    await _saveCache(downloads);
  }

  Future<void> _updateCacheItem(Map<String, dynamic> download) async {
    final downloads = await _getCache();

    final index = downloads.indexWhere((item) => item['id'] == download['id']);

    if (index != -1) {
      downloads[index] = download;
    } else {
      downloads.insert(0, download);
    }

    await _saveCache(downloads);
  }

  // ============================================================
  // LOCAL HISTORY
  // ============================================================

  /// Downloads started on this device, newest first.
  ///
  /// Deliberately local. `GET /downloads` is unauthenticated and answers with
  /// every download the server has ever run, for every user, so it cannot back
  /// a "my downloads" screen without showing strangers' links.
  Future<List<Map<String, dynamic>>> localDownloads() => _getCache();

  /// Re-checks anything that had not finished when we last saw it, so the
  /// history screen does not show a download as stuck forever.
  Future<List<Map<String, dynamic>>> refreshLocalDownloads() async {
    final downloads = await _getCache();

    for (final download in downloads) {
      final status = download['status']?.toString();

      if (status == 'completed' || status == 'failed') continue;

      final id = int.tryParse(download['id']?.toString() ?? '');

      if (id == null) continue;

      try {
        await getDownload(id);
      } catch (e) {
        debugPrint('⚠️ Could not refresh download #$id: $e');
      }
    }

    return _getCache();
  }

  /// Drops one download from the history. The saved video is untouched.
  Future<void> forget(dynamic id) async {
    final downloads = await _getCache();

    downloads.removeWhere((item) => item['id'].toString() == id.toString());

    await _saveCache(downloads);
  }

  // ============================================================
  // CLEAR CACHE
  // ============================================================

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_cacheKey);

    debugPrint('🗑️ Local download cache cleared.');
  }
}
