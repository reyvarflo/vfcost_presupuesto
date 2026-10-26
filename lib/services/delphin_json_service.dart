import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/apu_item.dart';
import '../models/partida.dart';
import '../models/presupuesto.dart';
import '../models/resource.dart';
import '../models/subpresupuesto.dart';

class DelphinJsonService {
  static const _uuid = Uuid();
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  /// Exporta el presupuesto al formato JSON estándar de Delphin Express
  static Future<File?> exportDelphinJson(Presupuesto p, {bool share = true}) async {
    final sub = p.activeSubpresupuesto ?? (p.subpresupuestos.isNotEmpty ? p.subpresupuestos.first : null);
    if (sub == null) return null;

    final data = {
      'proyecto': {
        'nombre': p.name,
        'codigo': p.code,
        'cliente': p.client,
        'ubicacion': p.location,
        'moneda': p.currencySymbol == 'S/.' ? 'PEN' : 'USD',
        'fecha': _dateFormat.format(p.date),
        'jornada': p.jornada,
        'costo_directo': sub.costoDirecto,
      },
      'partidas': sub.partidas.map((partida) {
        final isTitle = partida.isTitle;
        final map = <String, dynamic>{
          'item': partida.itemNumber,
          'descripcion': partida.description,
          'es_titulo': isTitle,
          'unidad': isTitle ? null : partida.unit,
          'metrado': isTitle ? null : partida.metrado,
          'precio_unitario': isTitle ? null : partida.precioUnitario,
          'parcial': partida.costoParcial,
        };

        if (!isTitle && partida.apuItems.isNotEmpty) {
          map['apu'] = {
            'rendimiento': partida.rendimiento,
            'unidad_tiempo': 'DIA',
            'costo_unitario_total': partida.precioUnitario,
            'recursos': partida.apuItems.map((apu) {
              String tipoStr;
              switch (apu.type) {
                case ResourceType.manoDeObra:
                  tipoStr = 'MANO_DE_OBRA';
                  break;
                case ResourceType.material:
                  tipoStr = 'MATERIAL';
                  break;
                case ResourceType.equipo:
                  tipoStr = 'EQUIPO';
                  break;
                case ResourceType.subcontrato:
                  tipoStr = 'SUBCONTRATO';
                  break;
              }

              return {
                'tipo': tipoStr,
                'codigo': apu.resourceCode,
                'descripcion': apu.resourceDescription,
                'unidad': apu.unit,
                'cuadrilla': apu.cuadrilla,
                'cantidad': apu.cantidad,
                'precio': apu.precioUnitario,
                'parcial': apu.calculateParcial(subtotalMO: partida.subtotalMO),
                'indice_unificado': apu.unifiedIndex,
              };
            }).toList(),
          };
        }

        return map;
      }).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(data);

    Directory tempDir;
    try {
      tempDir = await getTemporaryDirectory();
    } catch (_) {
      tempDir = Directory.systemTemp;
    }
    final sanitizedName = p.name.replaceAll(RegExp(r'[^\w\s-]'), '_').trim();
    final file = File('${tempDir.path}/${sanitizedName}_Delphin.json');
    await file.writeAsString(jsonString);

    if (share) {
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'Presupuesto Delphin Express JSON - ${p.name}',
      );
    }

    return file;
  }

  /// Importa un proyecto en formato JSON estándar de Delphin Express
  static Presupuesto? importDelphinJson(Map<String, dynamic> json) {
    try {
      final proy = json['proyecto'] as Map<String, dynamic>? ?? {};
      final nombre = proy['nombre'] as String? ?? 'Presupuesto Delphin Express';
      final codigo = proy['codigo'] as String? ?? 'DELPHIN-01';
      final cliente = proy['cliente'] as String? ?? 'CLIENTE';
      final ubicacion = proy['ubicacion'] as String? ?? 'OBRA';
      final monedaStr = proy['moneda'] as String? ?? 'PEN';
      final jornadaNum = (proy['jornada'] as num?)?.toDouble() ?? 8.0;

      DateTime fecha = DateTime.now();
      if (proy['fecha'] != null) {
        try {
          fecha = DateTime.parse(proy['fecha'].toString());
        } catch (_) {}
      }

      final rawPartidas = json['partidas'] as List<dynamic>? ?? [];
      final partidas = <Partida>[];
      int order = 1;

      for (final pItem in rawPartidas) {
        final pMap = pItem as Map<String, dynamic>;
        final item = pMap['item']?.toString() ?? order.toString().padLeft(2, '0');
        final descripcion = pMap['descripcion']?.toString() ?? 'Partida $order';
        final esTitulo = pMap['es_titulo'] as bool? ?? (pMap['unidad'] == null);
        final unidad = esTitulo ? '' : (pMap['unidad']?.toString() ?? 'und');
        final metrado = esTitulo ? 0.0 : ((pMap['metrado'] as num?)?.toDouble() ?? 0.0);
        final precioUnitario = esTitulo ? 0.0 : ((pMap['precio_unitario'] as num?)?.toDouble() ?? 0.0);

        final apuMap = pMap['apu'] as Map<String, dynamic>?;
        final apuItems = <ApuItem>[];
        double rendimiento = 1.0;

        if (apuMap != null) {
          rendimiento = (apuMap['rendimiento'] as num?)?.toDouble() ?? 1.0;
          final recursos = apuMap['recursos'] as List<dynamic>? ?? [];
          for (final r in recursos) {
            final rMap = r as Map<String, dynamic>;
            final tipoStr = rMap['tipo']?.toString().toUpperCase() ?? 'MATERIAL';
            ResourceType rType;
            if (tipoStr.contains('MANO') || tipoStr.contains('MO')) {
              rType = ResourceType.manoDeObra;
            } else if (tipoStr.contains('EQUIP')) {
              rType = ResourceType.equipo;
            } else if (tipoStr.contains('SUBCONTRAT')) {
              rType = ResourceType.subcontrato;
            } else {
              rType = ResourceType.material;
            }

            apuItems.add(ApuItem(
              id: _uuid.v4(),
              resourceId: _uuid.v4(),
              resourceCode: rMap['codigo']?.toString() ?? '0101',
              resourceDescription: rMap['descripcion']?.toString() ?? 'Insumo',
              type: rType,
              unit: rMap['unidad']?.toString() ?? 'und',
              cuadrilla: (rMap['cuadrilla'] as num?)?.toDouble() ?? 0.0,
              cantidad: (rMap['cantidad'] as num?)?.toDouble() ?? 1.0,
              precioUnitario: (rMap['precio'] as num?)?.toDouble() ?? 0.0,
              unifiedIndex: (rMap['indice_unificado'] as num?)?.toInt() ?? 39,
            ));
          }
        }

        final nivel = item.split('.').length;

        partidas.add(Partida(
          id: _uuid.v4(),
          itemNumber: item,
          description: descripcion,
          unit: unidad,
          metrado: metrado,
          precioUnitario: precioUnitario,
          isTitle: esTitulo,
          level: nivel,
          rendimiento: rendimiento,
          apuItems: apuItems,
        ));
        order++;
      }

      if (partidas.isEmpty) return null;

      final sub = Subpresupuesto(
        id: _uuid.v4(),
        code: '001',
        name: 'PRESUPUESTO GENERAL',
        partidas: partidas,
      );

      final now = DateTime.now();
      final nuevoPresupuesto = Presupuesto(
        id: _uuid.v4(),
        code: codigo,
        name: nombre,
        client: cliente,
        location: ubicacion,
        date: fecha,
        currencySymbol: monedaStr == 'USD' ? '\$' : 'S/.',
        currencyName: monedaStr == 'USD' ? 'Dólares' : 'Soles',
        jornada: jornadaNum,
        subpresupuestos: [sub],
        activeSubpresupuestoId: sub.id,
        createdAt: now,
        updatedAt: now,
      );

      return nuevoPresupuesto;
    } catch (_) {
      return null;
    }
  }
}
