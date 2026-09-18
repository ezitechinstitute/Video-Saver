import 'dart:io';

import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

/// Which messaging app's statuses to show.
enum StatusSource {
  whatsapp('whatsapp', 'WhatsApp'),
  business('business', 'WhatsApp Business');

  final String key;
  final String label;

  const StatusSource(this.key, this.label);
}

/// One status the user has already viewed, kept on the phone by the app.
class StatusItem {
  final String uri;
  final String name;
  final bool isVideo;
  final DateTime modified;

  const StatusItem({
    required this.uri,
    required this.name,
    required this.isVideo,
    required this.modified,
  });

  factory StatusItem.fromMap(Map<dynamic, dynamic> map) {
    return StatusItem(
      uri: map['uri'] as String,
      name: map['name'] as String,
      isVideo: map['video'] as bool,
      modified: DateTime.fromMillisecondsSinceEpoch(map['modified'] as int),
    );
  }
}

/// Why access to the statuses folder was not granted.
enum StatusAccessProblem { cancelled, wrongFolder, noPicker }

/// Bridge to the Android side that reads the statuses folder.
///
/// Access is granted by the user through the system folder picker, for that
/// one folder only. Nothing is requested beyond it and nothing is uploaded.
class StatusService {
  StatusService._();

  static final StatusService instance = StatusService._();

  static const MethodChannel _channel = MethodChannel(
    'com.ezitech.ezisaver/status',
  );

  final Map<String, Uint8List?> _thumbnails = {};

  Future<bool> hasAccess(StatusSource source) async {
    return await _channel.invokeMethod<bool>('hasAccess', {
          'app': source.key,
        }) ??
        false;
  }

  /// Opens the folder picker on the statuses folder. Returns null when
  /// access was granted, or the reason it was not.
  Future<StatusAccessProblem?> requestAccess(StatusSource source) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'requestAccess',
      {'app': source.key},
    );

    if (result?['granted'] == true) return null;

    switch (result?['reason']) {
      case 'wrong_folder':
        return StatusAccessProblem.wrongFolder;
      case 'no_picker':
        return StatusAccessProblem.noPicker;
      default:
        return StatusAccessProblem.cancelled;
    }
  }

  /// Statuses in the granted folder, newest first.
  Future<List<StatusItem>> list(StatusSource source) async {
    final raw = await _channel.invokeListMethod<Map<dynamic, dynamic>>('list', {
      'app': source.key,
    });

    return (raw ?? const []).map(StatusItem.fromMap).toList();
  }

  /// A small JPEG preview, cached for the session.
  Future<Uint8List?> thumbnail(StatusItem item) async {
    if (_thumbnails.containsKey(item.uri)) return _thumbnails[item.uri];

    Uint8List? bytes;
    try {
      bytes = await _channel.invokeMethod<Uint8List>('thumbnail', {
        'uri': item.uri,
        'video': item.isVideo,
      });
    } on PlatformException {
      bytes = null;
    }

    _thumbnails[item.uri] = bytes;
    return bytes;
  }

  /// Saves the status to the gallery, in the same album as downloads.
  Future<void> saveToGallery(StatusItem item) async {
    if (!await Gal.hasAccess(toAlbum: true)) {
      if (!await Gal.requestAccess(toAlbum: true)) {
        throw Exception('Gallery permission was not granted.');
      }
    }

    final path = await _channel.invokeMethod<String>('copyToCache', {
      'uri': item.uri,
      'name': item.name,
    });
    if (path == null) throw Exception('The status could not be opened.');

    try {
      if (item.isVideo) {
        await Gal.putVideo(path, album: 'EziDownload');
      } else {
        await Gal.putImage(path, album: 'EziDownload');
      }
    } finally {
      final copy = File(path);
      if (await copy.exists()) await copy.delete();
    }
  }
}
