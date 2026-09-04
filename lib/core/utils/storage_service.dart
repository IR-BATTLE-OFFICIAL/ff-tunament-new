import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  // Free API Key for ImgBB
  static const String _imgbbApiKey = 'a10cdd528385c7b1164cc8ace1d56e5e'; 
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Uploads an image to ImgBB and returns the URL.
  Future<String?> uploadImage(String folder, File file) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.imgbb.com/1/upload?key=$_imgbbApiKey'),
      );
      
      request.files.add(await http.MultipartFile.fromPath('image', file.path));
      
      debugPrint("Starting upload to ImgBB...");
      final response = await request.send();
      
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final json = jsonDecode(respStr);
        final url = json['data']['url'];
        debugPrint("Upload successful: $url");
        return url;
      } else {
        debugPrint("ImgBB Upload failed with status: ${response.statusCode}");
        throw Exception("Upload failed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error in StorageService.uploadImage: $e");
      rethrow;
    }
  }

  /// Uploads any file to Supabase Storage and returns the public URL.
  Future<String> uploadFile(String folder, File file, String fileName) async {
    try {
      final path = '$folder/$fileName';
      
      debugPrint("Starting Supabase upload: $path");
      
      // Upload to 'uploads' bucket (user needs to create this bucket in Supabase)
      await _supabase.storage.from('uploads').upload(path, file);
      
      final String publicUrl = _supabase.storage.from('uploads').getPublicUrl(path);
      debugPrint("File uploaded successfully: $publicUrl");
      return publicUrl;
    } catch (e) {
      debugPrint("Error in StorageService.uploadFile: $e");
      rethrow;
    }
  }
}
