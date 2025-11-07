import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = 'http://192.168.201.98:8000/api/v1'; // change to your Flask host IP

  Future<Map<String, dynamic>> uploadCsv(File file) async {
    var uri = Uri.parse('$baseUrl/predict');
    var request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    var response = await request.send();
    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      return json.decode(respStr);
    } else {
      throw Exception('Failed to upload CSV: ${response.statusCode}');
    }
  }
}
