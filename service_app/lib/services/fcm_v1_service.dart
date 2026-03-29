import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;

class FCMV1Service {
  static const String _projectId = "services-app-70555";
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/firebase.messaging'
  ];

  // LE SERVICE ACCOUNT JSON (Utiliser avec précaution)
  static final Map<String, dynamic> _serviceAccountJson = {
    "type": "service_account",
    "project_id": "services-app-70555",
    "private_key_id": "4179c45351feb253b18e529bee4aa4ad1efb4d8b",
    "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEuwIBADANBgkqhkiG9w0BAQEFAASCBKUwggShAgEAAoIBAQDB7KSXxqiIY9Af\nmeXKF09JI7+qUBsqwDpiAeYtKC90IdZJUzUAd+DUMOCRhXBaPalPyn/5YxrXmb8g\nA4DHmKgtpUEFYWy3ZvjIC/gNxzAGl1v875h1DAdcC5cJUqocMtxf+QfGOsKm7yIS\n8EU2lELkw++vgn6lYfIvFJogrQ2eWcb/Z0hDngrHwyOWMGLQWjo2N8blIJUVTJJX\nrtY6t5jyCxCOB3pYYSAuNXZeM5VPQbto0vPU6no4pFYKrHogXu2zMlr9xEQw9VvI\nBpQRQ4Mn4QoXbua+1CkQ/xiMa2EhR0oD0AHa3j1SamRcPEhT9eJ4TjJb6M3FN7py\nHyuV1bElAgMBAAECgf8WrSG7U28XWoQUiMEs0ACWfF3ctdPiyMk0ORUk+NhRo2E5\n1vSdvpAos33yK3bW1IAQs3wy96XZTjGwY12jdT6o3fRp5nZs60sCzymuUb19e29W\nyZTYwCw9K9N1Q6CxN9X4jE+WOVlP2VxkuYJWKdbR8aPj6lY/tjybp92X04vUpbA2\nm91/YCREpe507PomZ8x+hbvWnAzo6kFF/QpbsAwlzt/WBegW7ZsVTtE7SvlWEWSJ\nZQMm0guuPvUyW9bNcCwYMSjECFIdfIx7pL3rXVf6zeTqkp1aREkdidP1c+o+u5+f\nuOIBpJuld/8RnhXSxoKIMnYnbwgJx5e2rVFymAECgYEA+skKPP/JdOvXa0PfURb2\nDcX3Qu2tZR+XP+2+LymvZfIDaMQuulgI2EjwbWB3VJih4rnhtt1TS5rRqmWDvyEp\nAn4OeAKA0M/IfsMleBLxKlicfbvxf2AhQmUgXcT0GLqhvpnW1FytPLyJa08lVkQh\nn5H1NFor1gPjS2MnpfJdDxUCgYEAxfTs7I/XHmxWs9aSmaDgv8dvq11Xcvdh+0j2\nPpXW7/6BrHynpADuMkfwXk8AAw7RVkVzcJJmUptUYhESoZ44ENv0wE7deC+DUswQ\nA5fkyXOFEykm7qEXpnAiP6F6kZsJbVP7dvx0BhxlIbIL+Qzh9p2K+nO8wuRTLVK6\n1jpLHdECgYA/Re/eWg7jAAn210YFuIxWB0eOTFc+N0065OniDlthlkED8tNzUnjQ\n0P5QKlGRN31Iretj7s1wOtyBaGFoHJ6zMUjHQKJtjK8iRGw0slrEe1zoYD3bDE73\n6HnVDrcjchsS8s9//u36b/sf5vUdocz17KZ4EfQTaCG1yIudU9vkzQKBgEPRKOnS\TWxKyVlLBWZESzroZEVc8Pyd659e252NT9lgY6RoADabav8mzh5BCkwB442etXG3\ndf6O4FXIa42a2rJL6ImJey4VePQAnOveOa8aOFjcHE5cOfH3MISEGa2QY6Zkwx18\nV3NQfwUQLjHgS/lk95vd0qkh96zrTr7dsaZBAoGBAOikhoZF4EXrn2o3DTjyfIBU\nqIv3RUaszo3N17J28nIaRr1w6lz/S8JiifxN5gZfmiKpCyfbx7mZCa36J94DQ8pC\nkcxedHytuPuuUSQdzVjel1luNCjaAFM+deEzxSb36GhGTTSVk92JroKmAs5/LX31\nc/hH/7NuTfVCK5KoXUli\n-----END PRIVATE KEY-----\n",
    "client_email": "firebase-adminsdk-fbsvc@services-app-70555.iam.gserviceaccount.com",
    "client_id": "103064347807195355931",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40services-app-70555.iam.gserviceaccount.com",
    "universe_domain": "googleapis.com"
  };

  static Future<String> getAccessToken() async {
    final credentials = auth.ServiceAccountCredentials.fromJson(_serviceAccountJson);
    final client = await auth.clientViaServiceAccount(credentials, _scopes);
    final accessToken = client.credentials.accessToken.data;
    client.close();
    return accessToken;
  }

  static Future<void> sendPushNotification({
    required String deviceToken,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      final String accessToken = await getAccessToken();
      final String endpoint =
          "https://fcm.googleapis.com/v1/projects/$_projectId/messages:send";

      final Map<String, dynamic> fcmRequest = {
        "message": {
          "token": deviceToken,
          "notification": {
            "title": title,
            "body": body,
          },
          if (data != null) "data": data,
          "android": {
            "priority": "high",
            "notification": {
              "channel_id": "high_importance_channel",
              "sound": "default",
              "click_action": "FLUTTER_NOTIFICATION_CLICK"
            }
          }
        }
      };

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(fcmRequest),
      );

      if (response.statusCode == 200) {
        print("Push Notification FCM V1 envoyée avec succès !");
      } else {
        print("Erreur envoi FCM V1: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Erreur FCM V1 Service: $e");
    }
  }
}
