import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/catalog_data.dart';
import '../data/sample_projects.dart';
import '../models/presupuesto.dart';
import '../models/resource.dart';

class StorageService {
  static const String _keyPresupuestos = 'vfcost_presupuestos_v1';
  static const String _keyActivePresupuestoId = 'vfcost_active_presupuesto_id';
  static const String _keyCustomResources = 'vfcost_custom_resources_v1';

  /// Carga todos los presupuestos guardados, o inicializa con el proyecto de muestra de S10
  static Future<List<Presupuesto>> loadPresupuestos() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyPresupuestos);

    if (data == null || data.isEmpty) {
      final sample = SampleProjects.getSamplePresupuesto();
      await savePresupuestos([sample]);
      await saveActivePresupuestoId(sample.id);
      return [sample];
    }

    try {
      final List<dynamic> decoded = jsonDecode(data);
      final list = decoded.map((e) => Presupuesto.fromJson(e as Map<String, dynamic>)).toList();
      if (list.isEmpty) {
        final sample = SampleProjects.getSamplePresupuesto();
        await savePresupuestos([sample]);
        return [sample];
      }
      return list;
    } catch (e) {
      final sample = SampleProjects.getSamplePresupuesto();
      return [sample];
    }
  }

  /// Guarda la lista completa de presupuestos
  static Future<void> savePresupuestos(List<Presupuesto> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_keyPresupuestos, encoded);
  }

  /// Guarda el ID del presupuesto activo
  static Future<void> saveActivePresupuestoId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActivePresupuestoId, id);
  }

  /// Obtiene el ID del presupuesto activo
  static Future<String?> getActivePresupuestoId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyActivePresupuestoId);
  }

  /// Carga el catálogo de insumos (combina los predeterminados con los personalizados del usuario)
  static Future<List<Resource>> loadResources() async {
    final prefs = await SharedPreferences.getInstance();
    final customData = prefs.getString(_keyCustomResources);
    final list = List<Resource>.from(CatalogData.defaultResources);

    if (customData != null && customData.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(customData);
        final customList = decoded.map((e) => Resource.fromJson(e as Map<String, dynamic>)).toList();
        for (final res in customList) {
          final index = list.indexWhere((r) => r.id == res.id);
          if (index != -1) {
            list[index] = res;
          } else {
            list.add(res);
          }
        }
      } catch (_) {}
    }
    return list;
  }

  /// Guarda un nuevo recurso o actualiza uno existente en el catálogo
  static Future<void> saveCustomResource(Resource res) async {
    final prefs = await SharedPreferences.getInstance();
    final customData = prefs.getString(_keyCustomResources);
    final customList = <Resource>[];

    if (customData != null && customData.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(customData);
        customList.addAll(decoded.map((e) => Resource.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }

    final existingIndex = customList.indexWhere((r) => r.id == res.id);
    if (existingIndex != -1) {
      customList[existingIndex] = res;
    } else {
      customList.add(res);
    }

    await prefs.setString(
      _keyCustomResources,
      jsonEncode(customList.map((e) => e.toJson()).toList()),
    );
  }

  /// Exporta un presupuesto a cadena JSON
  static String exportPresupuestoToJson(Presupuesto p) {
    return const JsonEncoder.withIndent('  ').convert(p.toJson());
  }

  /// Importa un presupuesto desde cadena JSON
  static Presupuesto? importPresupuestoFromJson(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      return Presupuesto.fromJson(decoded as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
