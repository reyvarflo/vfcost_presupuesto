import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/presupuesto.dart';
import 'delphin_json_service.dart';
import 's2k_service.dart';

class DelphinSqliteService {
  /// Obtiene la lista de los 126 proyectos de SQLDelphin_maestro.sqlite desde el backend
  static Future<List<Map<String, dynamic>>> fetchLocalProjects() async {
    try {
      final baseUrl = await S2kService.getServerUrl();
      final uri = Uri.parse('$baseUrl/api/delphin/local-projects');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = data['projects'] as List<dynamic>? ?? [];
        return list.map((e) => e as Map<String, dynamic>).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Extrae un presupuesto seleccionado desde la base de datos de Delphin Express
  static Future<Presupuesto?> extractProject(String projectId) async {
    try {
      final baseUrl = await S2kService.getServerUrl();
      final uri = Uri.parse('$baseUrl/api/delphin/extract-project/$projectId');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return DelphinJsonService.importDelphinJson(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
