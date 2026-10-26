import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/presupuesto.dart';

class S2kService {
  static const String _keyServerUrl = 's10_converter_server_url';

  static String get defaultServerUrl {
    if (kIsWeb) return 'http://localhost:8000';
    // 10.0.2.2 es la IP del host de desarrollo en el emulador de Android
    return 'http://10.0.2.2:8000';
  }

  static Future<String> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyServerUrl) ?? defaultServerUrl;
  }

  static Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    var clean = url.trim();
    if (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    await prefs.setString(_keyServerUrl, clean);
  }

  /// Verifica si el microservicio en la nube está online y responde
  static Future<Map<String, dynamic>> checkServerHealth([String? overrideUrl]) async {
    try {
      final baseUrl = overrideUrl ?? await getServerUrl();
      final uri = Uri.parse('$baseUrl/api/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return {
          'online': true,
          'mssql_connected': data['mssql_connected'] == true,
          'message': data['mssql_connected'] == true
              ? 'Servidor y SQL Server listos'
              : 'Servidor online (SQL Server en espera)',
        };
      }
      return {
        'online': false,
        'mssql_connected': false,
        'message': 'Error HTTP ${res.statusCode}',
      };
    } catch (e) {
      return {
        'online': false,
        'mssql_connected': false,
        'message': 'No se pudo conectar al servidor ($e)',
      };
    }
  }

  /// Sube el archivo .S2K / .BAK al backend mediante Multipart,
  /// donde se restaura en SQL Server y retorna el Presupuesto JSON.
  static Future<Presupuesto> uploadAndConvert({
    required List<int> fileBytes,
    required String fileName,
    void Function(String step)? onStatusUpdate,
  }) async {
    final baseUrl = await getServerUrl();
    final uri = Uri.parse('$baseUrl/api/s2k/convert');

    onStatusUpdate?.call('Conectando con el servidor backend...');

    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
      ),
    );

    onStatusUpdate?.call('Subiendo archivo .S2K / .BAK al servidor...');

    final streamedResponse = await request.send().timeout(
      const Duration(minutes: 3),
      onTimeout: () {
        throw Exception('Tiempo de espera agotado al subir el archivo (timeout 3m).');
      },
    );

    onStatusUpdate?.call('Restaurando base de datos y extrayendo partidas...');

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      String detail = 'Error del servidor (${response.statusCode})';
      try {
        final errJson = jsonDecode(response.body);
        if (errJson['detail'] != null) {
          detail = errJson['detail'].toString();
        }
      } catch (_) {}
      throw Exception(detail);
    }

    onStatusUpdate?.call('Decodificando estructura del presupuesto...');
    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    if (data['success'] != true || data['presupuesto'] == null) {
      throw Exception('La respuesta del servidor no contiene un presupuesto válido.');
    }

    onStatusUpdate?.call('Guardando presupuesto en la base de datos local...');
    final presupuestoMap = data['presupuesto'] as Map<String, dynamic>;
    final presupuesto = Presupuesto.fromJson(presupuestoMap);

    return presupuesto;
  }
}
