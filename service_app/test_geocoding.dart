import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final query = 'Tanger, Maroc';
  final encoded = Uri.encodeComponent(query);
  final url = Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=$encoded&limit=1');
  
  final response = await http.get(url, headers: {'User-Agent': 'service_app_amine/1.0'});
  if (response.statusCode == 200) {
    if (response.body.isNotEmpty) {
      final data = jsonDecode(response.body);
      print('Response: $data');
    } else {
      print('Empty body');
    }
  } else {
    print('Error: ${response.statusCode}');
  }
}
