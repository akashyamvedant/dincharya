// Media Cache Service - Automatic Background Caching
// Senior developer implementation for seamless offline experience
// 
// How it works:
// 1. When user plays video/audio, check if cached locally
// 2. If cached → play from local file (no internet needed)
// 3. If not cached → stream from URL + download in background
// 4. Auto-cleanup old files to manage storage

import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

/// Singleton service for managing media cache
class MediaCacheService {
  static final MediaCacheService _instance = MediaCacheService._internal();
  factory MediaCacheService() => _instance;
  MediaCacheService._internal();

  // Configuration
  static const int maxCacheSizeBytes = 500 * 1024 * 1024; // 500 MB
  static const int maxCacheAgeDays = 30; // Auto-delete after 30 days
  static const String _cacheMetadataKey = 'media_cache_metadata';
  
  final Dio _dio = Dio();
  
  // Active downloads tracking
  final Map<String, CancelToken> _activeDownloads = {};
  final Map<String, double> _downloadProgress = {};

  /// Get the cache directory path
  Future<Directory> get _cacheDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/media_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Generate unique cache key from URL
  String _generateCacheKey(String url) {
    final bytes = utf8.encode(url);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Get file extension from URL
  String _getExtension(String url, String mediaType) {
    // Try to extract from URL
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final path = uri.path.toLowerCase();
      if (path.endsWith('.mp4')) return '.mp4';
      if (path.endsWith('.webm')) return '.webm';
      if (path.endsWith('.mov')) return '.mov';
      if (path.endsWith('.mp3')) return '.mp3';
      if (path.endsWith('.wav')) return '.wav';
      if (path.endsWith('.aac')) return '.aac';
      if (path.endsWith('.m4a')) return '.m4a';
      if (path.endsWith('.ogg')) return '.ogg';
    }
    // Default based on media type
    return mediaType == 'audio' ? '.mp3' : '.mp4';
  }

  /// Load cache metadata from SharedPreferences
  Future<Map<String, dynamic>> _loadMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_cacheMetadataKey);
      if (jsonStr != null) {
        final decoded = json.decode(jsonStr);
        if (decoded is Map) {
          // Convert to proper type
          return Map<String, dynamic>.from(decoded);
        }
      }
    } catch (e) {
      debugPrint('MediaCacheService: Error loading metadata: $e');
    }
    return {'files': <String, dynamic>{}, 'totalSize': 0};
  }

  /// Save cache metadata to SharedPreferences
  Future<void> _saveMetadata(Map<String, dynamic> metadata) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheMetadataKey, json.encode(metadata));
    } catch (e) {
      debugPrint('MediaCacheService: Error saving metadata: $e');
    }
  }

  /// Check if a URL is already cached
  Future<bool> isCached(String url) async {
    if (url.isEmpty) return false;
    
    try {
      final cacheKey = _generateCacheKey(url);
      final metadata = await _loadMetadata();
      final filesRaw = metadata['files'];
      if (filesRaw == null || filesRaw is! Map) return false;
      
      final files = Map<String, dynamic>.from(filesRaw);
      if (!files.containsKey(cacheKey)) return false;
      
      // Verify file actually exists
      final fileInfoRaw = files[cacheKey];
      if (fileInfoRaw == null || fileInfoRaw is! Map) return false;
      
      final fileInfo = Map<String, dynamic>.from(fileInfoRaw);
      final filePath = fileInfo['path'] as String?;
      if (filePath == null) return false;
      
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      debugPrint('MediaCacheService: Error checking cache: $e');
      return false;
    }
  }

  /// Get cached file path (returns null if not cached)
  Future<String?> getCachedPath(String url) async {
    if (url.isEmpty) return null;
    
    try {
      final cacheKey = _generateCacheKey(url);
      final metadata = await _loadMetadata();
      final filesRaw = metadata['files'];
      if (filesRaw == null || filesRaw is! Map) return null;
      
      final files = Map<String, dynamic>.from(filesRaw);
      if (!files.containsKey(cacheKey)) return null;
      
      final fileInfoRaw = files[cacheKey];
      if (fileInfoRaw == null || fileInfoRaw is! Map) return null;
      
      final fileInfo = Map<String, dynamic>.from(fileInfoRaw);
      final filePath = fileInfo['path'] as String?;
      if (filePath == null) return null;
      
      final file = File(filePath);
      if (await file.exists()) {
        // Update last accessed time
        fileInfo['lastAccessed'] = DateTime.now().toIso8601String();
        files[cacheKey] = fileInfo;
        metadata['files'] = files;
        await _saveMetadata(metadata);
        
        return filePath;
      }
    } catch (e) {
      debugPrint('MediaCacheService: Error getting cached path: $e');
    }
    
    return null;
  }

  /// Download and cache media file in background
  /// Returns immediately, download happens asynchronously
  Future<void> cacheInBackground({
    required String url,
    required String mediaType,
    String? sessionId,
    void Function(double progress)? onProgress,
  }) async {
    if (url.isEmpty) return;
    
    final cacheKey = _generateCacheKey(url);
    
    // Already cached?
    if (await isCached(url)) {
      debugPrint('MediaCacheService: Already cached: $cacheKey');
      return;
    }
    
    // Already downloading?
    if (_activeDownloads.containsKey(cacheKey)) {
      debugPrint('MediaCacheService: Already downloading: $cacheKey');
      return;
    }
    
    // Start background download
    _downloadInBackground(
      url: url,
      cacheKey: cacheKey,
      mediaType: mediaType,
      sessionId: sessionId,
      onProgress: onProgress,
    );
  }

  /// Internal: Perform the actual download
  Future<void> _downloadInBackground({
    required String url,
    required String cacheKey,
    required String mediaType,
    String? sessionId,
    void Function(double progress)? onProgress,
  }) async {
    final cancelToken = CancelToken();
    _activeDownloads[cacheKey] = cancelToken;
    _downloadProgress[cacheKey] = 0;

    try {
      // Cleanup old files if needed
      await _cleanupIfNeeded();

      final cacheDir = await _cacheDir;
      final extension = _getExtension(url, mediaType);
      final filePath = '${cacheDir.path}/$cacheKey$extension';

      debugPrint('MediaCacheService: Starting download: $url');
      debugPrint('MediaCacheService: Saving to: $filePath');

      final response = await _dio.download(
        url,
        filePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            _downloadProgress[cacheKey] = progress;
            onProgress?.call(progress);
          }
        },
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
          },
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(minutes: 2),
        ),
      );

      if (response.statusCode == 200) {
        // Get file size
        final file = File(filePath);
        final fileSize = await file.length();

        // Save metadata
        final metadata = await _loadMetadata();
        final filesRaw = metadata['files'];
        final files = filesRaw is Map 
            ? Map<String, dynamic>.from(filesRaw) 
            : <String, dynamic>{};
        
        files[cacheKey] = {
          'path': filePath,
          'url': url,
          'mediaType': mediaType,
          'sessionId': sessionId,
          'sizeBytes': fileSize,
          'downloadedAt': DateTime.now().toIso8601String(),
          'lastAccessed': DateTime.now().toIso8601String(),
        };

        // Update total size
        int totalSize = 0;
        for (var f in files.values) {
          if (f is Map) {
            totalSize += (f['sizeBytes'] as int? ?? 0);
          }
        }
        
        metadata['files'] = files;
        metadata['totalSize'] = totalSize;
        await _saveMetadata(metadata);

        debugPrint('MediaCacheService: ✅ Downloaded successfully: $cacheKey (${_formatBytes(fileSize)})');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        debugPrint('MediaCacheService: Download cancelled: $cacheKey');
      } else {
        debugPrint('MediaCacheService: Download error: $e');
      }
    } catch (e) {
      debugPrint('MediaCacheService: Error downloading: $e');
    } finally {
      _activeDownloads.remove(cacheKey);
      _downloadProgress.remove(cacheKey);
    }
  }

  /// Cancel active download
  void cancelDownload(String url) {
    final cacheKey = _generateCacheKey(url);
    _activeDownloads[cacheKey]?.cancel();
  }

  /// Check if download is in progress
  bool isDownloading(String url) {
    final cacheKey = _generateCacheKey(url);
    return _activeDownloads.containsKey(cacheKey);
  }

  /// Get download progress (0.0 to 1.0)
  double getDownloadProgress(String url) {
    final cacheKey = _generateCacheKey(url);
    return _downloadProgress[cacheKey] ?? 0;
  }

  /// Delete cached file
  Future<void> deleteCache(String url) async {
    try {
      final cacheKey = _generateCacheKey(url);
      
      // Cancel if downloading
      cancelDownload(url);
      
      final metadata = await _loadMetadata();
      final filesRaw = metadata['files'];
      if (filesRaw == null || filesRaw is! Map) return;
      
      final files = Map<String, dynamic>.from(filesRaw);
      
      if (files.containsKey(cacheKey)) {
        final fileInfoRaw = files[cacheKey];
        if (fileInfoRaw is Map) {
          final fileInfo = Map<String, dynamic>.from(fileInfoRaw);
          final filePath = fileInfo['path'] as String?;
          
          if (filePath != null) {
            final file = File(filePath);
            if (await file.exists()) {
              await file.delete();
            }
          }
        }
        
        files.remove(cacheKey);
        
        // Recalculate total size
        int totalSize = 0;
        for (var f in files.values) {
          if (f is Map) {
            totalSize += (f['sizeBytes'] as int? ?? 0);
          }
        }
        
        metadata['files'] = files;
        metadata['totalSize'] = totalSize;
        await _saveMetadata(metadata);
      }
    } catch (e) {
      debugPrint('MediaCacheService: Error deleting cache: $e');
    }
  }

  /// Get total cache size
  Future<int> getTotalCacheSize() async {
    final metadata = await _loadMetadata();
    return metadata['totalSize'] as int? ?? 0;
  }

  /// Get formatted cache size string
  Future<String> getFormattedCacheSize() async {
    final size = await getTotalCacheSize();
    return _formatBytes(size);
  }

  /// Get number of cached files
  Future<int> getCachedFileCount() async {
    final metadata = await _loadMetadata();
    final filesRaw = metadata['files'];
    if (filesRaw == null || filesRaw is! Map) return 0;
    return filesRaw.length;
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    // Cancel all active downloads
    for (var token in _activeDownloads.values) {
      token.cancel();
    }
    _activeDownloads.clear();
    _downloadProgress.clear();

    // Delete all cached files
    final cacheDir = await _cacheDir;
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
      await cacheDir.create();
    }

    // Clear metadata
    await _saveMetadata({'files': {}, 'totalSize': 0});
    
    debugPrint('MediaCacheService: All cache cleared');
  }

  /// Cleanup old files and enforce size limit
  Future<void> _cleanupIfNeeded() async {
    try {
      final metadata = await _loadMetadata();
      final filesRaw = metadata['files'];
      if (filesRaw == null || filesRaw is! Map) return;
      
      final files = Map<String, dynamic>.from(filesRaw);
      if (files.isEmpty) return;

    final now = DateTime.now();
    final filesToDelete = <String>[];
    
    // Find old files (not accessed in maxCacheAgeDays)
    for (var entry in files.entries) {
      final entryValue = entry.value;
      if (entryValue is! Map) continue;
      
      final fileInfo = Map<String, dynamic>.from(entryValue);
      final lastAccessedStr = fileInfo['lastAccessed'] as String?;
      
      if (lastAccessedStr != null) {
        final lastAccessed = DateTime.tryParse(lastAccessedStr);
        if (lastAccessed != null) {
          final daysSinceAccess = now.difference(lastAccessed).inDays;
          if (daysSinceAccess > maxCacheAgeDays) {
            filesToDelete.add(entry.key);
          }
        }
      }
    }

    // Delete old files
    for (var key in filesToDelete) {
      final fileInfoRaw = files[key];
      if (fileInfoRaw is Map) {
        final fileInfo = Map<String, dynamic>.from(fileInfoRaw);
        final filePath = fileInfo['path'] as String?;
        if (filePath != null) {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
            debugPrint('MediaCacheService: Deleted old file: $key');
          }
        }
      }
      files.remove(key);
    }

    // Check size limit - delete LRU (Least Recently Used) if over limit
    int totalSize = 0;
    for (var f in files.values) {
      if (f is Map) {
        totalSize += (f['sizeBytes'] as int? ?? 0);
      }
    }

    if (totalSize > maxCacheSizeBytes) {
      // Sort by last accessed (oldest first)
      final sortedEntries = files.entries.toList()
        ..sort((a, b) {
          String? aAccessedStr;
          String? bAccessedStr;
          if (a.value is Map) {
            aAccessedStr = Map<String, dynamic>.from(a.value)['lastAccessed'] as String?;
          }
          if (b.value is Map) {
            bAccessedStr = Map<String, dynamic>.from(b.value)['lastAccessed'] as String?;
          }
          final aTime = DateTime.tryParse(aAccessedStr ?? '') ?? DateTime(2000);
          final bTime = DateTime.tryParse(bAccessedStr ?? '') ?? DateTime(2000);
          return aTime.compareTo(bTime);
        });

      // Delete until under limit
      for (var entry in sortedEntries) {
        if (totalSize <= maxCacheSizeBytes) break;
        
        final entryValue = entry.value;
        if (entryValue is! Map) continue;
        
        final fileInfo = Map<String, dynamic>.from(entryValue);
        final fileSize = fileInfo['sizeBytes'] as int? ?? 0;
        final filePath = fileInfo['path'] as String?;
        
        if (filePath != null) {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
          }
        }
        
        files.remove(entry.key);
        totalSize -= fileSize;
        debugPrint('MediaCacheService: Deleted LRU file: ${entry.key}');
      }
    }

    // Save updated metadata
    metadata['files'] = files;
    metadata['totalSize'] = totalSize;
    await _saveMetadata(metadata);
    } catch (e) {
      debugPrint('MediaCacheService: Error in cleanup: $e');
    }
  }

  /// Format bytes to human readable string
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get cache stats for debugging/display
  Future<Map<String, dynamic>> getCacheStats() async {
    final metadata = await _loadMetadata();
    final filesRaw = metadata['files'];
    final filesCount = (filesRaw is Map) ? filesRaw.length : 0;
    final totalSize = metadata['totalSize'] as int? ?? 0;
    
    return {
      'fileCount': filesCount,
      'totalSizeBytes': totalSize,
      'totalSizeFormatted': _formatBytes(totalSize),
      'maxSizeBytes': maxCacheSizeBytes,
      'maxSizeFormatted': _formatBytes(maxCacheSizeBytes),
      'usagePercent': totalSize / maxCacheSizeBytes * 100,
      'activeDownloads': _activeDownloads.length,
    };
  }
}
