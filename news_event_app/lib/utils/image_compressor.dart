import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageCompressor {
  // Compress image to optimize for upload
  // Default quality is 85% and max width is 1920px
  static Future<File?> compressImage(
    File file, {
    int quality = 85,
    int maxWidth = 1920,
  }) async {
    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final targetPath = path.join(
        tempDir.path,
        '${DateTime.now().millisecondsSinceEpoch}_compressed${path.extension(file.path)}',
      );

      // Compress the image
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: maxWidth,
      );

      if (result == null) {
        return null;
      }

      return File(result.path);
    } catch (e) {
      // If compression fails, return original file
      return file;
    }
  }

  // Get file size in MB
  static Future<double> getFileSizeInMB(File file) async {
    final bytes = await file.length();
    return bytes / (1024 * 1024);
  }

  // Check if file needs compression (larger than 1MB)
  static Future<bool> needsCompression(File file) async {
    final sizeInMB = await getFileSizeInMB(file);
    return sizeInMB > 1.0;
  }

  // Compress image if needed, otherwise return original
  static Future<File> compressIfNeeded(File file) async {
    final needsComp = await needsCompression(file);
    
    if (needsComp) {
      final compressed = await compressImage(file);
      return compressed ?? file;
    }
    
    return file;
  }
}
