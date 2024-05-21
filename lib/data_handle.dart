import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

class DataHandler {
  // Method to unzip the file and process its contents
  static Future<Map<String, dynamic>> analyzeZipFile(String zipFilePath) async {
    try {
      // Read the ZIP file
      final bytes = File(zipFilePath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      List<String> messages = [];
      List<String> imagePaths = [];

      // Get the directory to store the extracted images
      final tempDir = await getTemporaryDirectory();
      final imagesDir = Directory('${tempDir.path}/extracted_images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // Iterate through the files in the ZIP archive
      for (var file in archive) {
        if (file.isFile) {
          final filename = file.name;
          final data = file.content as List<int>;

          if (filename.endsWith('.txt')) {
            // Process the text file
            messages = await _processTextFile(data);
          } else if (filename.endsWith('.jpg') || filename.endsWith('.png')) {
            // Write image to the directory and add the path to the list
            final imagePath = '${imagesDir.path}/$filename';
            await File(imagePath).writeAsBytes(data);
            imagePaths.add(imagePath);
          }
        }
      }

      return {'messages': messages, 'images': imagePaths};
    } catch (e) {
      print('Error analyzing ZIP file: $e');
      return {'messages': [], 'images': []};
    }
  }

  // Helper method to process the text file from the ZIP archive
  static Future<List<String>> _processTextFile(List<int> data) async {
    try {
      List<String> lines = utf8.decode(data).split('\n');
      return lines;
    } catch (e) {
      print('Error processing text file: $e');
      return [];
    }
  }

  static Future<void> cleanUpTemporaryFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final imagesDir = Directory('${tempDir.path}/extracted_images');

      if (await imagesDir.exists()) {
        await imagesDir.delete(recursive: true);
        print('Temporary files cleaned up.');
      }
    } catch (e) {
      print('Error cleaning up temporary files: $e');
    }
  }
}
