import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/partida.dart';
import '../models/presupuesto.dart';
import '../models/subpresupuesto.dart';
import 'insumos_service.dart';

class DelphinExcelService {
  static const _uuid = Uuid();

  /// Exporta el presupuesto completo en formato binario .xlsx compatible con Delphin Express BIM 360
  static Future<File?> exportDelphinXlsx(Presupuesto p, {bool share = true}) async {
    final excel = Excel.createExcel();
    final sub = p.activeSubpresupuesto ?? (p.subpresupuestos.isNotEmpty ? p.subpresupuestos.first : null);
    if (sub == null) return null;

    // Eliminar la hoja por defecto creada por Excel library si existe
    if (excel.tables.keys.contains('Sheet1')) {
      excel.rename('Sheet1', 'Presupuesto General');
    }

    // 1. HOJA: Presupuesto General
    _buildPresupuestoGeneralSheet(excel, p, sub);

    // 2. HOJA: Análisis de Precios Unitarios (APU)
    _buildApuSheet(excel, p, sub);

    // 3. HOJA: Relación Consolidada de Insumos y Recursos
    _buildInsumosSheet(excel, p, sub);

    // 4. HOJA: Fórmula Polinómica
    _buildFormulaPolinomicaSheet(excel, p);

    final bytes = excel.encode();
    if (bytes == null) return null;

    Directory tempDir;
    try {
      tempDir = await getTemporaryDirectory();
    } catch (_) {
      tempDir = Directory.systemTemp;
    }
    final sanitizedName = p.name.replaceAll(RegExp(r'[^\w\s-]'), '_').trim();
    final filePath = '${tempDir.path}/${sanitizedName}_DelphinExpress.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    if (share) {
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        subject: 'Presupuesto Delphin Express - ${p.name}',
      );
    }

    return file;
  }

  static void _buildPresupuestoGeneralSheet(Excel excel, Presupuesto p, Subpresupuesto sub) {
    final sheet = excel['Presupuesto General'];

    // Cabecera del Proyecto
    sheet.appendRow([TextCellValue('DELPHIN EXPRESS BIM 360 / VFCOST - HOJA DEL PRESUPUESTO')]);
    sheet.appendRow([TextCellValue('Presupuesto:'), TextCellValue('${p.code} ${p.name}')]);
    sheet.appendRow([TextCellValue('Subpresupuesto:'), TextCellValue('${sub.code} ${sub.name}')]);
    sheet.appendRow([TextCellValue('Cliente:'), TextCellValue(p.client)]);
    sheet.appendRow([TextCellValue('Lugar:'), TextCellValue(p.location)]);
    sheet.appendRow([TextCellValue('Fecha:'), TextCellValue(DateFormat('dd/MM/yyyy').format(p.date))]);
    sheet.appendRow([TextCellValue('Moneda:'), TextCellValue('${p.currencySymbol} (${p.currencyName})')]);
    sheet.appendRow([TextCellValue('Jornada:'), TextCellValue('${p.jornada} horas/día')]);
    sheet.appendRow([]);

    // Encabezados de Columnas
    sheet.appendRow([
      TextCellValue('Item'),
      TextCellValue('Descripcion'),
      TextCellValue('Tipo'),
      TextCellValue('Nivel'),
      TextCellValue('Und'),
      TextCellValue('Metrado'),
      TextCellValue('Precio Unitario (${p.currencySymbol})'),
      TextCellValue('Parcial (${p.currencySymbol})'),
    ]);

    // Filas de Partidas y Títulos
    for (final partida in sub.partidas) {
      final isTitle = partida.isTitle;
      final nivel = partida.itemNumber.split('.').length;

      sheet.appendRow([
        TextCellValue(partida.itemNumber),
        TextCellValue(partida.description),
        TextCellValue(isTitle ? 'TITULO' : 'PARTIDA'),
        IntCellValue(nivel),
        isTitle ? TextCellValue('') : TextCellValue(partida.unit),
        isTitle ? TextCellValue('') : DoubleCellValue(partida.metrado),
        isTitle ? TextCellValue('') : DoubleCellValue(partida.precioUnitario),
        DoubleCellValue(partida.costoParcial),
      ]);
    }

    // Pie de Presupuesto
    sheet.appendRow([]);
    sheet.appendRow([TextCellValue('RESUMEN DEL PRESUPUESTO (PIE DE PRESUPUESTO)')]);
    final cd = sub.costoDirecto;
    final pie = p.piePresupuesto;

    sheet.appendRow([TextCellValue('COSTO DIRECTO (CD)'), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), DoubleCellValue(cd)]);
    sheet.appendRow([TextCellValue('Gastos Generales Fijos (${pie.porcentajeGGFijos}%)'), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), DoubleCellValue(pie.calcularGGFijos(cd))]);
    sheet.appendRow([TextCellValue('Gastos Generales Variables (${pie.porcentajeGGVariables}%)'), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), DoubleCellValue(pie.calcularGGVariables(cd))]);
    sheet.appendRow([TextCellValue('Utilidad (${pie.porcentajeUtilidad}%)'), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), DoubleCellValue(pie.calcularUtilidad(cd))]);
    sheet.appendRow([TextCellValue('SUBTOTAL'), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), DoubleCellValue(pie.calcularSubtotal(cd))]);
    if (pie.aplicarIGV) {
      sheet.appendRow([TextCellValue('IGV (${pie.porcentajeIGV}%)'), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), DoubleCellValue(pie.calcularIGV(cd))]);
    }
    sheet.appendRow([TextCellValue('TOTAL PRESUPUESTO'), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), DoubleCellValue(pie.calcularTotalPresupuesto(cd))]);
  }

  static void _buildApuSheet(Excel excel, Presupuesto p, Subpresupuesto sub) {
    final sheet = excel['Analisis de Precios Unitarios'];

    sheet.appendRow([TextCellValue('ANALISIS DE COSTOS UNITARIOS (ACU / APU) - DELPHIN EXPRESS')]);
    sheet.appendRow([]);

    for (final partida in sub.partidas) {
      if (partida.isTitle) continue;

      sheet.appendRow([
        TextCellValue('Partida:'),
        TextCellValue(partida.itemNumber),
        TextCellValue(partida.description),
        TextCellValue('Rendimiento:'),
        DoubleCellValue(partida.rendimiento),
        TextCellValue('${partida.unit}/DIA'),
        TextCellValue('Costo Unitario:'),
        DoubleCellValue(partida.precioUnitario),
      ]);

      sheet.appendRow([
        TextCellValue('Tipo Recurso'),
        TextCellValue('Codigo Insumo'),
        TextCellValue('Descripcion Recurso'),
        TextCellValue('Und'),
        TextCellValue('Cuadrilla'),
        TextCellValue('Cantidad / Aporte'),
        TextCellValue('Precio (${p.currencySymbol})'),
        TextCellValue('Parcial (${p.currencySymbol})'),
      ]);

      for (final apu in partida.apuItems) {
        sheet.appendRow([
          TextCellValue(apu.type.displayName.toUpperCase()),
          TextCellValue(apu.resourceCode),
          TextCellValue(apu.resourceDescription),
          TextCellValue(apu.unit),
          DoubleCellValue(apu.cuadrilla),
          DoubleCellValue(apu.cantidad),
          DoubleCellValue(apu.precioUnitario),
          DoubleCellValue(apu.calculateParcial(subtotalMO: partida.subtotalMO)),
        ]);
      }
      sheet.appendRow([]);
    }
  }

  static void _buildInsumosSheet(Excel excel, Presupuesto p, Subpresupuesto sub) {
    final sheet = excel['Relacion de Insumos'];

    sheet.appendRow([TextCellValue('RELACION CONSOLIDADA DE INSUMOS Y RECURSOS (DELPHIN EXPRESS)')]);
    sheet.appendRow([TextCellValue('Presupuesto:'), TextCellValue(p.name)]);
    sheet.appendRow([]);

    sheet.appendRow([
      TextCellValue('Tipo'),
      TextCellValue('Codigo'),
      TextCellValue('Descripcion'),
      TextCellValue('Unidad'),
      TextCellValue('Indice Unificado (IU)'),
      TextCellValue('Cantidad Total'),
      TextCellValue('Precio Presupuestado'),
      TextCellValue('Parcial Total (${p.currencySymbol})'),
    ]);

    final insumos = InsumosService.consolidar([sub]);
    for (final i in insumos) {
      sheet.appendRow([
        TextCellValue(i.tipo.displayName),
        TextCellValue(i.code),
        TextCellValue(i.descripcion),
        TextCellValue(i.unidad),
        IntCellValue(i.iu),
        DoubleCellValue(i.cantidad),
        DoubleCellValue(i.precio),
        DoubleCellValue(i.parcial),
      ]);
    }
  }

  static void _buildFormulaPolinomicaSheet(Excel excel, Presupuesto p) {
    final sheet = excel['Formula Polinomica'];

    sheet.appendRow([TextCellValue('FORMULA POLINOMICA (D.S. N 011-79-VC) - DELPHIN EXPRESS')]);
    sheet.appendRow([TextCellValue('Presupuesto:'), TextCellValue(p.name)]);
    sheet.appendRow([TextCellValue('Suma de coeficientes:'), DoubleCellValue(p.formulaPolinomica.sumaCoeficientes)]);
    sheet.appendRow([]);

    sheet.appendRow([
      TextCellValue('Monomio'),
      TextCellValue('Simbolo'),
      TextCellValue('Coeficiente (k)'),
      TextCellValue('IU INEI'),
      TextCellValue('Descripcion Indice Unificado'),
      TextCellValue('Factor Submonomio'),
      TextCellValue('Participacion %'),
    ]);

    for (final m in p.formulaPolinomica.monomios) {
      for (final sub in m.submonomios) {
        sheet.appendRow([
          IntCellValue(m.monomioNumber),
          TextCellValue(m.symbol),
          DoubleCellValue(m.coeficiente),
          IntCellValue(sub.unifiedIndex),
          TextCellValue(sub.description),
          DoubleCellValue(sub.factor),
          DoubleCellValue(sub.factor * 100),
        ]);
      }
    }
  }

  /// Importa un archivo Excel (.xlsx / .xls) de Delphin Express y construye un Presupuesto
  static Presupuesto? importDelphinXlsx(List<int> bytes, {String? defaultName}) {
    try {
      final excel = Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) return null;

      // Buscar la hoja de presupuesto: 'Presupuesto General', 'Hoja del Presupuesto', o la primera disponible
      Sheet? targetSheet;
      for (final key in excel.tables.keys) {
        final lower = key.toLowerCase();
        if (lower.contains('presupuesto') || lower.contains('hoja') || lower.contains('partida')) {
          targetSheet = excel.tables[key];
          break;
        }
      }
      targetSheet ??= excel.tables.values.first;

      final rows = targetSheet.rows;
      if (rows.isEmpty) return null;

      // Detectar fila de cabecera de columnas
      int headerRowIndex = -1;
      int itemCol = -1;
      int descCol = -1;
      int undCol = -1;
      int metradoCol = -1;
      int precioCol = -1;

      for (var r = 0; r < rows.length && r < 20; r++) {
        final row = rows[r];
        for (var c = 0; c < row.length; c++) {
          final cellText = row[c]?.value?.toString().trim().toLowerCase() ?? '';
          if (cellText == 'item' || cellText == 'ítem') itemCol = c;
          if (cellText.contains('descrip') || cellText == 'partida') descCol = c;
          if (cellText == 'und' || cellText == 'unidad') undCol = c;
          if (cellText.contains('metrado') || cellText == 'cantidad') metradoCol = c;
          if (cellText.contains('precio') || cellText.contains('unitario') || cellText == 'p.u.') precioCol = c;
        }
        if (itemCol != -1 && descCol != -1) {
          headerRowIndex = r;
          break;
        }
      }

      // Si no encontró cabecera con nombres exactos, asumir columnas estándar de Delphin:
      // Col 0: Item, Col 1: Descripción, Col 2: Und, Col 3: Metrado, Col 4: Precio
      if (headerRowIndex == -1) {
        headerRowIndex = 0;
        itemCol = 0;
        descCol = 1;
        undCol = 2;
        metradoCol = 3;
        precioCol = 4;
      }

      final partidas = <Partida>[];
      int partidaOrder = 1;

      for (var r = headerRowIndex + 1; r < rows.length; r++) {
        final row = rows[r];
        if (row.isEmpty) continue;

        final itemVal = itemCol < row.length ? row[itemCol]?.value?.toString().trim() ?? '' : '';
        final descVal = descCol < row.length ? row[descCol]?.value?.toString().trim() ?? '' : '';
        if (itemVal.isEmpty && descVal.isEmpty) continue;

        // Omitir filas de resumen o notas
        final descLower = descVal.toLowerCase();
        if (descLower.contains('costo directo') ||
            descLower.contains('gastos generales') ||
            descLower.contains('utilidad') ||
            descLower.contains('total presupuesto') ||
            descLower.contains('igv')) {
          continue;
        }

        final undVal = undCol != -1 && undCol < row.length ? row[undCol]?.value?.toString().trim() ?? '' : '';
        final metradoStr = metradoCol != -1 && metradoCol < row.length ? row[metradoCol]?.value?.toString().replaceAll(',', '') ?? '0' : '0';
        final precioStr = precioCol != -1 && precioCol < row.length ? row[precioCol]?.value?.toString().replaceAll(',', '') ?? '0' : '0';

        final metradoNum = double.tryParse(metradoStr) ?? 0.0;
        final precioNum = double.tryParse(precioStr) ?? 0.0;

        // Regla Delphin: Si Unidad y Metrado están vacíos o cero -> es TÍTULO
        final isTitle = undVal.isEmpty || (metradoNum == 0 && precioNum == 0);
        final nivel = itemVal.split('.').length;

        partidas.add(Partida(
          id: _uuid.v4(),
          itemNumber: itemVal.isNotEmpty ? itemVal : partidaOrder.toString().padLeft(2, '0'),
          description: descVal.isNotEmpty ? descVal : 'Partida $partidaOrder',
          unit: isTitle ? '' : undVal,
          metrado: isTitle ? 0.0 : metradoNum,
          precioUnitario: isTitle ? 0.0 : precioNum,
          isTitle: isTitle,
          level: nivel,
          apuItems: [],
        ));
        partidaOrder++;
      }

      if (partidas.isEmpty) return null;

      final projectName = defaultName ?? 'Proyecto Importado Delphin';
      final subpresupuesto = Subpresupuesto(
        id: _uuid.v4(),
        code: '001',
        name: 'PRESUPUESTO GENERAL',
        partidas: partidas,
      );

      final now = DateTime.now();
      final nuevoPresupuesto = Presupuesto(
        id: _uuid.v4(),
        code: 'DELPHIN-01',
        name: projectName,
        client: 'CLIENTE DELPHIN',
        location: 'OBRA',
        date: now,
        currencySymbol: 'S/.',
        currencyName: 'Soles',
        jornada: 8.0,
        subpresupuestos: [subpresupuesto],
        activeSubpresupuestoId: subpresupuesto.id,
        createdAt: now,
        updatedAt: now,
      );

      return nuevoPresupuesto;
    } catch (_) {
      return null;
    }
  }
}
