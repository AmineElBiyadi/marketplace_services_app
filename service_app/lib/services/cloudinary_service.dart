import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


class CloudinaryService {
  static String get cloudName => dotenv.get('CLOUDINARY_CLOUD_NAME', fallback: 'dt0swlkte');
  static String get uploadPreset => dotenv.get('CLOUDINARY_UPLOAD_PRESET', fallback: 'services_app_preset');

  /// EXEMPLE D'UTILISATION POUR L'ÉQUIPE :
  /// 
  /// 1. Importez : `import 'package:service_app/services/cloudinary_service.dart';`
  /// 
  /// 2. Téléchargez une image (Base64 ou Octets) :
  ///    String? url = await CloudinaryService.uploadImage(maSourceBase64);
  /// 
  /// 3. Sauvegardez l'URL dans Firestore au lieu du Base64 encombrant.
  /// 
  /// 4. Affichez-la simplement avec le widget SmartImage existant :
  ///    SmartImage(source: url)
  
  static Future<String?> uploadImage(dynamic imageSource) async {
    try {
      final uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");
      
      var request = http.MultipartRequest("POST", uri);
      request.fields['upload_preset'] = uploadPreset;

      if (imageSource is String) {
        // If it's a base64 string
        String b64 = imageSource;
        if (b64.contains(',')) {
          b64 = b64.split(',').last;
        }
        request.fields['file'] = "data:image/jpeg;base64,$b64";
      } else if (imageSource is Uint8List) {
        // If it's raw bytes
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          imageSource,
          filename: 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));
      } else {
        debugPrint("[CloudinaryService] Unsupported image source type");
        return null;
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['secure_url'] as String?;
      } else {
        debugPrint("[CloudinaryService] Upload failed: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("[CloudinaryService] Error: $e");
      return null;
    }
  }
}
