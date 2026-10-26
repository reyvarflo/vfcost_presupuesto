import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/presupuesto.dart';
import '../models/subpresupuesto.dart';

class ExcelExportService {
  static final _currencyFormat = NumberFormat('0.00', 'en_US');

  /// Genera una cadena CSV formateada para Excel con la Hoja del Presupuesto
  static String generateBudgetCsv(Presupuesto p, Subpresupuesto sub) {
    final buffer = StringBuffer();
    // BOM UTF-8 para que Excel en Windows reconozca tildes y caracteres especiales
    buffer.write('\uFEFF');

    buffer.writeln('VFCOST - SISTEMA DE PRESUPUESTOS (TIPO S10)');
    buffer.writeln('Presupuesto,"${p.code} ${p.name}"');
    buffer.writeln('Subpresupuesto,"${sub.code} ${sub.name}"');
    buffer.writeln('Cliente,"${p.client}"');
    buffer.writeln('Lugar,"${p.location}"');
    buffer.writeln('Fecha,"${DateFormat('dd/MM/yyyy').format(p.date)}"');
    buffer.writeln('Moneda,"${p.currencySymbol} (${p.currencyName})"');
    buffer.writeln('Jornada,"${p.jornada} horas/dia"');
    buffer.writeln('');

    buffer.writeln('Item,Descripcion,Und,Metrado,Precio Unitario (${p.currencySymbol}),Parcial (${p.currencySymbol})');

    for (final partida in sub.partidas) {
      final item = partida.itemNumber;
      final desc = partida.description.replaceAll('"', '""');
      final und = partida.isTitle ? '' : partida.unit;
      final metrado = partida.isTitle ? '' : _currencyFormat.format(partida.metrado);
      final precio = partida.isTitle ? '' : _currencyFormat.format(partida.precioUnitario);
      final parcial = _currencyFormat.format(partida.costoParcial);

      buffer.writeln('"$item","$desc","$und","$metrado","$precio","$parcial"');
    }

    buffer.writeln('');
    buffer.writeln('RESUMEN DEL PRESUPUESTO');
    final pie = p.piePresupuesto;
    final cd = sub.costoDirecto;
    buffer.writeln('"COSTO DIRECTO (CD)","","","","","${_currencyFormat.format(cd)}"');
    buffer.writeln('"Gastos Generales Fijos (${pie.porcentajeGGFijos}%)","","","","","${_currencyFormat.format(pie.calcularGGFijos(cd))}"');
    buffer.writeln('"Gastos Generales Variables (${pie.porcentajeGGVariables}%)","","","","","${_currencyFormat.format(pie.calcularGGVariables(cd))}"');
    buffer.writeln('"Utilidad (${pie.porcentajeUtilidad}%)","","","","","${_currencyFormat.format(pie.calcularUtilidad(cd))}"');
    buffer.writeln('"SUBTOTAL","","","","","${_currencyFormat.format(pie.calcularSubtotal(cd))}"');
    if (pie.aplicarIGV) {
      buffer.writeln('"IGV (${pie.porcentajeIGV}%)","","","","","${_currencyFormat.format(pie.calcularIGV(cd))}"');
    }
    buffer.writeln('"TOTAL PRESUPUESTO","","","","","${_currencyFormat.format(pie.calcularTotalPresupuesto(cd))}"');

    return buffer.toString();
  }

  /// Genera un CSV con el listado consolidado de recursos e insumos
  static String generateResourcesCsv(Presupuesto p, Subpresupuesto sub) {
    final buffer = StringBuffer();
    buffer.write('\uFEFF');

    buffer.writeln('VFCOST - LISTADO CONSOLIDADO DE INSUMOS Y RECURSOS');
    buffer.writeln('Presupuesto,"${p.code} ${p.name}"');
    buffer.writeln('Subpresupuesto,"${sub.code} ${sub.name}"');
    buffer.writeln('');

    buffer.writeln('Tipo,Codigo,Descripcion,Und,Indice Unificado,Cantidad Total,Precio Unitario (${p.currencySymbol}),Costo Total (${p.currencySymbol})');

    final resourceMap = <String, Map<String, dynamic>>{};

    for (final partida in sub.partidas) {
      if (partida.isTitle) continue;
      for (final apu in partida.apuItems) {
        if (apu.isPercentageOfMO) continue;
        final key = apu.resourceId.isNotEmpty ? apu.resourceId : apu.resourceCode;
        final totalCant = apu.cantidad * partida.metrado;
        final totalCost = totalCant * apu.precioUnitario;

        if (resourceMap.containsKey(key)) {
          resourceMap[key]!['cantidad'] = (resourceMap[key]!['cantidad'] as double) + totalCant;
          resourceMap[key]!['costoTotal'] = (resourceMap[key]!['costoTotal'] as double) + totalCost;
        } else {
          resourceMap[key] = {
            'tipo': apu.type.displayName,
            'codigo': apu.resourceCode,
            'descripcion': apu.resourceDescription,
            'und': apu.unit,
            'iu': apu.unifiedIndex,
            'cantidad': totalCant,
            'precio': apu.precioUnitario,
            'costoTotal': totalCost,
          };
        }
      }
    }

    final sorted = resourceMap.values.toList()
      ..sort((a, b) => (a['tipo'] as String).compareTo(b['tipo'] as String));

    for (final row in sorted) {
      buffer.writeln(
        '"${row['tipo']}","${row['codigo']}","${row['descripcion']}","${row['und']}","${row['iu']}","${_currencyFormat.format(row['cantidad'])}","${_currencyFormat.format(row['precio'])}","${_currencyFormat.format(row['costoTotal'])}"',
      );
    }

    return buffer.toString();
  }

  /// Guarda y comparte el archivo CSV a través de share_plus
  static Future<void> shareCsvFile(String csvContent, String filename) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsString(csvContent);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Exportación de Presupuesto VFCOST',
      ),
    );
  }
}
