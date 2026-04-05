import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;

class FCMV1Service {
  static const String _projectId = "presto-daaed";
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/firebase.messaging'
  ];

  // LE SERVICE ACCOUNT JSON (Updated for Presto project)
  static final Map<String, dynamic> _serviceAccountJson = {
    "type": "service_account",
    "project_id": "presto-daaed",
    "private_key_id": "fbe431c9f49690b530eff3935a5eb92f770c5ba5",
    "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCqfPqIJ+jnoX3f\nUY+2TK4sk0TsSd2g7eTlIe50OulcXvKCrf1DSL4p/wJ5//rYln8NLWRD+X+fPrTx\nCSnmoKdNy7MVxslooGYN3PxiWF9VHobKSoj4qPPU57TAc4LkaXS5cLzsjJa4l9Qi\nMuDT7hourllZI2ipefd5jXsqnLem7PRQ50vVjTU1+HpRFa/UHEhVqLssKotTMRrd\neqIyjgj45QjXavVuVuXvJir427DbRwyNFRKRl4Zt59PCQdp9CfIrjKV8w19UN76Q\nIk9ulVPipswcgzgTQ9abapFGjMc7NAWmgIOrCB/Mrl/NJXJAt5dRoc1lUk9G8HVj\n+/J8gBYlAgMBAAECggEACgxEnbqwbNplN0Cw1h8t0r25Pa3azI3IxEJcMeh48XM9\nGruTZiBG6OW5KSSPja1M/qNSufjd7y48bspJ+Gg2hAzB2MI3A54UdbO1AjzQHY2n\nhwueh/05Ja6kRgVozPp0ISvGTrC4f1efboaOHp91VpP6+xhtpjNkhPr0K95BqqpK\nxu79E+eDxw7opBq2aFFdYa1xp1qwiK5cQ7hSGJ/76qBlphRfChzOvBziiW94K2kE\nUVpXFWK5BRyLQYk1/UXyeEevMaZ/ghZ3zfpuG3qn8fYCiXuwWSbsyDaRZp7Mx98O\nTnxI86hdJTq7CEBQtcAGDa+kpwciIdjhv9KsCJB0vwKBgQDhtNulvkI52uNYohud\nrwMerNaCehigR+JnlTGJMGedb5kGkHFT5Nvwg2RfOl/CDuv9/RcEI85hlVxVnZvJ\nAT1sJaJKK7gX8Qi8KiY360k4Rdyoo57ZvnNiSo6x2c9+hvphYyH+Pk0pUDgwuUVa\nQGRCvKiHPy2+tI10xRLrZ8hqFwKBgQDBXtpev92cTs8Hb7lQ8Q1Ap7048OELmGvE\nV/zjyl8eUJM06lmPjB1ZxYXnS2yujKZd+Pd/v/NWGgYM1ceae19QWxKn2ImPynJj\nbvMr9zvXb/0KWmwVonDzoJoEhzRLFCQF6+iuuEzBSqlmUmLMEzuEMGIjE5Di0xLM\nnKD+HiEzIwKBgHfG/cVQWV7QjVOs+5DLnpE50cB+QPFWFI05vIb8XBBNd9zm7G1E\nB3/0imCK3uRh/NTV6c/1nIFmvRBmSpT6BnmM4zoPR2vVKviIOa31O+8UDAymgBc3\nnY3s2RsC5r1Tri3eaNy+fT5OZvNcbrR9dXeBHMJhQcpxkJwGNYsdkVrTAoGBAKNn\nmVbaAdZ1jmN1WP96Q72wQamdfD8FNYQ86lpACDMg2dSseLRiLedPkEENLrEt7+SX\nX+aXeXT4Fsa/3KXBvaC05UXrKQvWguVdu6YajXoXi5g1IwMBOzvVKnHLIziSs4JB\ngWYsHch1ZEMwOYbEddXV4QhNH3Fd9pPrg+xZ36pLAoGBAMNXE+metWMLH+5KbxLg\n9TzZm7jE8NA8nov0AXf9H/gQsVrJSA8jXMk9rBcAiUcvDxOYvhW0N4Lhz4+JvMph\nJPQOx5fqN4jVl47feJlbgN11RQI2O516qxH2PDBAVpZ0AT3iumFy4l4eq1zzYf3Y\n1GYT+x67lnX9kqT23hzA47S0\n-----END PRIVATE KEY-----\n",
    "client_email": "firebase-adminsdk-fbsvc@presto-daaed.iam.gserviceaccount.com",
    "client_id": "102240948003151455052",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40presto-daaed.iam.gserviceaccount.com",
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
