import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/apu_item.dart';
import '../models/partida.dart';
import '../models/presupuesto.dart';
import '../models/resource.dart';
import '../models/subpresupuesto.dart';

class DelphinSqliteDirectService {
  static const _uuid = Uuid();

  /// Abre un archivo .sqlite de Delphin Express y lista todos sus proyectos
  static Future<List<Map<String, dynamic>>> listProjects(String sqlitePath) async {
    Database? db;
    try {
      db = await openDatabase(sqlitePath, readOnly: true);
      final rows = await db.rawQuery('''
        SELECT p.id_proyecto, p.nombre_proyecto, p.fecha_proyecto, p.total_proyecto,
               COALESCE(i.nombre_infraestructura, 'Edificaciones') as tipo_obra,
               COALESCE(prop.nombre_propietario, 'MUNICIPALIDAD') as cliente,
               COALESCE(dep.nombre_departamento, 'LORETO') as departamento
        FROM proyecto p
        LEFT JOIN infraestructura i ON p.id_infraestructura = i.id_infraestructura
        LEFT JOIN propietario prop ON p.id_propietario = prop.id_propietario
        LEFT JOIN departamento dep ON p.id_departamento = dep.id_departamento
        ORDER BY p.id_proyecto DESC;
      ''');
      return rows;
    } finally {
      await db?.close();
    }
  }

  /// Extrae un presupuesto completo desde el archivo .sqlite de Delphin Express
  static Future<Presupuesto?> extractProject(String sqlitePath, String projectId) async {
    Database? db;
    try {
      db = await openDatabase(sqlitePath, readOnly: true);

      // Cabecera del proyecto
      final pRows = await db.rawQuery('''
        SELECT p.id_proyecto, p.nombre_proyecto, p.fecha_proyecto, p.total_proyecto,
               COALESCE(i.nombre_infraestructura, 'Edificaciones') as tipo_obra,
               COALESCE(prop.nombre_propietario, 'MUNICIPALIDAD') as cliente,
               COALESCE(dep.nombre_departamento, 'LORETO') as departamento
        FROM proyecto p
        LEFT JOIN infraestructura i ON p.id_infraestructura = i.id_infraestructura
        LEFT JOIN propietario prop ON p.id_propietario = prop.id_propietario
        LEFT JOIN departamento dep ON p.id_departamento = dep.id_departamento
        WHERE p.id_proyecto = ?;
      ''', [projectId]);

      if (pRows.isEmpty) return null;
      final pRow = pRows.first;

      // Subpresupuestos
      final subRows = await db.rawQuery('''
        SELECT id_presupuesto, nombre_presupuesto, costo_directo,
               porcentaje_gasto, porcentaje_utilidad, porcentaje_igv
        FROM presupuesto
        WHERE id_proyecto = ?
        ORDER BY id_presupuesto ASC;
      ''', [projectId]);

      final subpresupuestos = <Subpresupuesto>[];

      for (final subRow in subRows) {
        final subId = subRow['id_presupuesto'] as String;
        final subName = subRow['nombre_presupuesto'] as String? ?? 'Subpresupuesto';

        // Títulos
        final titulosRows = await db.rawQuery('''
          SELECT id_titulo, numeracion_titulo, descripcion_titulo, costo_titulo, id_titulopadre
          FROM titulo
          WHERE id_presupuesto = ?
          ORDER BY numeracion_titulo ASC;
        ''', [subId]);

        final titulosMap = <String, Map<String, dynamic>>{};
        for (final t in titulosRows) {
          titulosMap[t['id_titulo'] as String] = t;
        }

        // Costos unitarios (partidas)
        final cuRows = await db.rawQuery('''
          SELECT c.id_costounitario, c.numeracion_costo, c.descripcion_costo,
                 COALESCE(u.abreviatura_unidad, 'und') as und,
                 c.cantidad, c.costo_unitario, c.parcial_costo, c.id_titulo, c.productividad
          FROM costo_unitario c
          LEFT JOIN unidad u ON c.id_unidad = u.id_unidad
          WHERE c.id_presupuesto = ?
          ORDER BY c.posicion_costo ASC;
        ''', [subId]);

        final partidas = <Partida>[];
        final titulosAdded = <String>{};

        for (final cu in cuRows) {
          final tId = cu['id_titulo'] as String?;
          if (tId != null && titulosMap.containsKey(tId) && !titulosAdded.contains(tId)) {
            final t = titulosMap[tId]!;
            final tItem = (t['numeracion_titulo'] as String?) ?? '';
            partidas.add(Partida(
              id: _uuid.v4(),
              itemNumber: tItem,
              description: (t['descripcion_titulo'] as String?) ?? '',
              unit: '',
              metrado: 0.0,
              precioUnitario: 0.0,
              isTitle: true,
              level: tItem.split('.').length,
            ));
            titulosAdded.add(tId);
          }

          final cuId = cu['id_costounitario'] as String;
          final itemNum = (cu['numeracion_costo'] as String?) ?? '';

          // Recursos del APU
          final subtotals = await db.rawQuery('''
            SELECT id_subtotal, id_tipocosto
            FROM subtotal_costounitario
            WHERE id_costounitario = ?;
          ''', [cuId]);

          final apuItems = <ApuItem>[];
          for (final st in subtotals) {
            final sId = st['id_subtotal'] as String;
            final tcId = st['id_tipocosto'] as String?;

            ResourceType rType = ResourceType.material;
            if (tcId == 'TC0000000001') {
              rType = ResourceType.manoDeObra;
            } else if (tcId == 'TC0000000003') {
              rType = ResourceType.equipo;
            } else if (tcId == 'TC0000000004') {
              rType = ResourceType.subcontrato;
            }

            final recursosRows = await db.rawQuery('''
              SELECT c.descripcion_composicion, COALESCE(u.abreviatura_unidad, 'und') as und,
                     c.personal_base, c.cantidad_composicion, c.costo_composicion
              FROM composicion_costounitario c
              LEFT JOIN unidad u ON c.id_unidad = u.id_unidad
              WHERE c.id_subtotal = ?;
            ''', [sId]);

            for (final r in recursosRows) {
              apuItems.add(ApuItem(
                id: _uuid.v4(),
                resourceId: _uuid.v4(),
                resourceCode: '0101',
                resourceDescription: (r['descripcion_composicion'] as String?) ?? 'Insumo',
                type: rType,
                unit: (r['und'] as String?) ?? 'und',
                cuadrilla: (r['personal_base'] as num?)?.toDouble() ?? 0.0,
                cantidad: (r['cantidad_composicion'] as num?)?.toDouble() ?? 1.0,
                precioUnitario: (r['costo_composicion'] as num?)?.toDouble() ?? 0.0,
                unifiedIndex: 39,
              ));
            }
          }

          final metradoNum = (cu['cantidad'] as num?)?.toDouble() ?? 0.0;
          final precioNum = (cu['costo_unitario'] as num?)?.toDouble() ?? 0.0;
          final rendimientoNum = (cu['productividad'] as num?)?.toDouble() ?? 1.0;

          partidas.add(Partida(
            id: _uuid.v4(),
            itemNumber: itemNum,
            description: (cu['descripcion_costo'] as String?) ?? '',
            unit: (cu['und'] as String?) ?? 'und',
            metrado: metradoNum,
            precioUnitario: precioNum,
            rendimiento: rendimientoNum,
            isTitle: false,
            level: itemNum.split('.').length,
            apuItems: apuItems,
          ));
        }

        subpresupuestos.add(Subpresupuesto(
          id: _uuid.v4(),
          code: (subRow['id_presupuesto'] as String?) ?? '01',
          name: subName,
          partidas: partidas,
        ));
      }

      final dateStr = pRow['fecha_proyecto'] as String? ?? '01/01/2026';
      DateTime fecha = DateTime.now();
      try {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          fecha = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      } catch (_) {}

      final presupuesto = Presupuesto(
        id: _uuid.v4(),
        code: (pRow['id_proyecto'] as String?) ?? 'DELPHIN-01',
        name: (pRow['nombre_proyecto'] as String?) ?? 'Presupuesto Delphin Express',
        client: (pRow['cliente'] as String?) ?? 'CLIENTE',
        location: (pRow['departamento'] as String?) ?? 'LORETO',
        currencySymbol: 'S/.',
        currencyName: 'Soles',
        tipoObra: (pRow['tipo_obra'] as String?) ?? 'Edificaciones',
        date: fecha,
        subpresupuestos: subpresupuestos,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      return presupuesto.processAll();
    } finally {
      await db?.close();
    }
  }
}
