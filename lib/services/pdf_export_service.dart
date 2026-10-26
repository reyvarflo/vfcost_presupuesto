import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/apu_item.dart';
import '../models/partida.dart';
import '../models/presupuesto.dart';
import '../models/resource.dart';
import '../models/subpresupuesto.dart';
import '../utils/number_format_utils.dart';
import 'cronograma_service.dart';
import 'formula_service.dart';
import 'insumos_service.dart';

class PdfExportService {
  static final _currencyFormat = NumberFormat('#,##0.00', 'es_PE');
  static final _numberFormat = NumberFormat('#,##0.00##', 'es_PE');
  static final _qty4Format = NumberFormat('#,##0.0000', 'es_PE');
  static final _dateFormat = DateFormat('dd/MM/yyyy');

  /// 1. IMPRIMIR HOJA DE PRESUPUESTO Y PIE RESUMEN
  static Future<void> printHojaPresupuesto(
    Presupuesto presupuesto,
    Subpresupuesto subpresupuesto,
  ) async {
    final pdfBytes = await generateHojaPresupuestoPdf(presupuesto, subpresupuesto);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Presupuesto_${presupuesto.code}_${subpresupuesto.code}.pdf',
    );
  }

  static Future<Uint8List> generateHojaPresupuestoPdf(
    Presupuesto presupuesto,
    Subpresupuesto subpresupuesto,
  ) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _buildHeader(presupuesto, subpresupuesto),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.SizedBox(height: 10),
          _buildPartidasTable(presupuesto, subpresupuesto),
          pw.SizedBox(height: 14),
          _buildPiePresupuesto(presupuesto, subpresupuesto),
        ],
      ),
    );

    return doc.save();
  }

  /// 2. IMPRIMIR ANÁLISIS DE PRECIOS UNITARIOS (APUs)
  static Future<void> printApuReport(
    Presupuesto presupuesto,
    Subpresupuesto subpresupuesto,
  ) async {
    final pdfBytes = await generateApuReportPdf(presupuesto, subpresupuesto);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'APU_${presupuesto.code}_${subpresupuesto.code}.pdf',
    );
  }

  static Future<Uint8List> generateApuReportPdf(
    Presupuesto presupuesto,
    Subpresupuesto subpresupuesto,
  ) async {
    final doc = pw.Document();
    final nonTitlePartidas =
        subpresupuesto.partidas.where((p) => !p.isTitle).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildHeader(
          presupuesto,
          subpresupuesto,
          titleSuffix: 'ANÁLISIS DE COSTOS UNITARIOS (ACU / APU)',
        ),
        footer: (context) => _buildFooter(context),
        build: (context) {
          final widgets = <pw.Widget>[];
          for (final partida in nonTitlePartidas) {
            widgets.add(_buildApuBox(partida, presupuesto.currencySymbol));
            widgets.add(pw.SizedBox(height: 12));
          }
          return widgets;
        },
      ),
    );

    return doc.save();
  }

  /// 3. IMPRIMIR RELACIÓN CONSOLIDADA DE INSUMOS / RECURSOS DEL PRESUPUESTO
  static Future<void> printInsumosReport(
    Presupuesto presupuesto,
    Subpresupuesto subpresupuesto,
  ) async {
    final pdfBytes = await generateInsumosReportPdf(presupuesto, subpresupuesto);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Insumos_${presupuesto.code}.pdf',
    );
  }

  static Future<Uint8List> generateInsumosReportPdf(
    Presupuesto presupuesto,
    Subpresupuesto subpresupuesto,
  ) async {
    final doc = pw.Document();
    final insumos = InsumosService.consolidar(presupuesto.subpresupuestos);
    final sym = presupuesto.currencySymbol;

    final grupos = <ResourceType, String>{
      ResourceType.manoDeObra: 'MANO DE OBRA',
      ResourceType.material: 'MATERIALES',
      ResourceType.equipo: 'EQUIPOS Y HERRAMIENTAS',
      ResourceType.subcontrato: 'SUBCONTRATOS',
    };

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildHeader(
          presupuesto,
          subpresupuesto,
          titleSuffix: 'RELACIÓN DE INSUMOS Y RECURSOS DEL PROYECTO',
        ),
        footer: (context) => _buildFooter(context),
        build: (context) {
          final widgets = <pw.Widget>[];
          double totalGeneral = 0.0;

          for (final entry in grupos.entries) {
            final items = insumos.where((i) => i.tipo == entry.key).toList();
            if (items.isEmpty) continue;
            final subtotalGrupo = items.fold(0.0, (s, i) => s + i.parcial);
            totalGeneral += subtotalGrupo;

            widgets.add(
              pw.Container(
                color: PdfColors.blueGrey800,
                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '${entry.value} (${items.length} recursos)',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.Text(
                      'Subtotal: $sym ${_currencyFormat.format(subtotalGrupo)}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.amberAccent,
                      ),
                    ),
                  ],
                ),
              ),
            );

            widgets.add(
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
                columnWidths: {
                  0: const pw.FixedColumnWidth(26), // IU
                  1: const pw.FixedColumnWidth(54), // Código
                  2: const pw.FlexColumnWidth(), // Descripción
                  3: const pw.FixedColumnWidth(32), // Und
                  4: const pw.FixedColumnWidth(62), // Cantidad (4 dec)
                  5: const pw.FixedColumnWidth(54), // Precio
                  6: const pw.FixedColumnWidth(66), // Parcial
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _apuHeaderCell('IU', align: pw.TextAlign.center),
                      _apuHeaderCell('Código'),
                      _apuHeaderCell('Descripción del Insumo'),
                      _apuHeaderCell('Und', align: pw.TextAlign.center),
                      _apuHeaderCell('Cantidad', align: pw.TextAlign.right),
                      _apuHeaderCell('Precio ($sym)', align: pw.TextAlign.right),
                      _apuHeaderCell('Parcial ($sym)', align: pw.TextAlign.right),
                    ],
                  ),
                  ...items.map((ins) {
                    return pw.TableRow(
                      children: [
                        _dataCell(ins.iu.toString().padLeft(2, '0'), align: pw.TextAlign.center),
                        _dataCell(ins.code),
                        _dataCell(ins.descripcion),
                        _dataCell(ins.unidad, align: pw.TextAlign.center),
                        _dataCell(_qty4Format.format(ins.cantidad), align: pw.TextAlign.right),
                        _dataCell(_currencyFormat.format(ins.precio), align: pw.TextAlign.right),
                        _dataCell(_currencyFormat.format(ins.parcial), align: pw.TextAlign.right, isBold: true),
                      ],
                    );
                  }),
                ],
              ),
            );
            widgets.add(pw.SizedBox(height: 10));
          }

          widgets.add(
            pw.Container(
              alignment: pw.Alignment.centerRight,
              padding: const pw.EdgeInsets.all(6),
              decoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
              child: pw.Text(
                'TOTAL COSTO DIRECTO INSUMOS: $sym ${_currencyFormat.format(totalGeneral)}',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
          );

          return widgets;
        },
      ),
    );

    return doc.save();
  }

  /// 4. IMPRIMIR FÓRMULA POLINÓMICA Y COEFICIENTES DE INCIDENCIA (10 DECIMALES)
  static Future<void> printFormulaPolinomicaReport(
    Presupuesto presupuesto,
    Subpresupuesto subpresupuesto,
  ) async {
    final pdfBytes = await generateFormulaPolinomicaPdf(presupuesto, subpresupuesto);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Formula_Polinomica_${presupuesto.code}.pdf',
    );
  }

  static Future<Uint8List> generateFormulaPolinomicaPdf(
    Presupuesto presupuesto,
    Subpresupuesto subpresupuesto,
  ) async {
    final doc = pw.Document();
    final formula = presupuesto.formulaPolinomica;
    final monomios = formula.monomios;
    final costosPorIU = FormulaService.obtenerCostosPorIU(presupuesto);
    final baseSubtotal = presupuesto.subtotal > 0 ? presupuesto.subtotal : 1.0;

    final exprParts = monomios
        .map((m) => '${m.coeficiente.toStringAsFixed(3)} (${m.symbol}r / ${m.symbol}o)')
        .join(' + ');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildHeader(
          presupuesto,
          subpresupuesto,
          titleSuffix: 'FÓRMULA POLINÓMICA Y COEFICIENTES DE INCIDENCIA (D.S. N° 011-79-VC)',
        ),
        footer: (context) => _buildFooter(context),
        build: (context) {
          final iusSorted = costosPorIU.keys.toList()..sort();

          return [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.blueGrey700, width: 0.8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'EXPRESIÓN MATEMÁTICA DE REAJUSTE AUTOMÁTICO (K1):',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'K1 = ${exprParts.isEmpty ? "1.000" : exprParts}',
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              '1. ÁRBOL DE AGRUPAMIENTO Y CONFORMACIÓN DE MONOMIOS',
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(),
                1: const pw.FixedColumnWidth(50),
                2: const pw.FixedColumnWidth(78),
                3: const pw.FixedColumnWidth(65),
                4: const pw.FixedColumnWidth(55),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                  children: [
                    _tableHeaderCell('Descripción (Monomio / Índice Unificado)'),
                    _tableHeaderCell('Nomencl.', align: pw.TextAlign.center),
                    _tableHeaderCell('Coef. Calculado', align: pw.TextAlign.right),
                    _tableHeaderCell('Coef. Definido', align: pw.TextAlign.right),
                    _tableHeaderCell('Porcentaje', align: pw.TextAlign.right),
                  ],
                ),
                ...monomios.expand((m) {
                  double costoM = 0.0;
                  for (final s in m.submonomios) {
                    costoM += costosPorIU[s.unifiedIndex] ?? 0.0;
                  }
                  final coefCalcM = costoM / baseSubtotal;
                  final rows = <pw.TableRow>[
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _dataCell(
                          'MONOMIO ${m.monomioNumber}: ${m.submonomios.isNotEmpty ? m.submonomios.first.description.toUpperCase() : m.symbol}',
                          isBold: true,
                        ),
                        _dataCell(m.symbol, align: pw.TextAlign.center, isBold: true),
                        _dataCell(coefCalcM.toStringAsFixed(10), align: pw.TextAlign.right, isBold: true),
                        _dataCell(m.coeficiente.toStringAsFixed(3), align: pw.TextAlign.right, isBold: true),
                        _dataCell('', align: pw.TextAlign.right),
                      ],
                    ),
                  ];
                  for (final sub in m.submonomios) {
                    final cSub = costosPorIU[sub.unifiedIndex] ?? 0.0;
                    final coefSub = cSub / baseSubtotal;
                    final pct = costoM > 0 ? (cSub / costoM) * 100.0 : (sub.factor * 100.0);
                    rows.add(
                      pw.TableRow(
                        children: [
                          _dataCell('   [IU ${sub.unifiedIndex.toString().padLeft(2, '0')}] ${sub.description.toUpperCase()}'),
                          _dataCell(''),
                          _dataCell(coefSub.toStringAsFixed(10), align: pw.TextAlign.right),
                          _dataCell(''),
                          _dataCell('${pct.toStringAsFixed(2)}%', align: pw.TextAlign.right),
                        ],
                      ),
                    );
                  }
                  return rows;
                }),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
                  children: [
                    _dataCell('TOTAL COEFICIENTES', isBold: true),
                    _dataCell(''),
                    _dataCell('1.0000000000', align: pw.TextAlign.right, isBold: true),
                    _dataCell(formula.sumaCoeficientes.toStringAsFixed(3), align: pw.TextAlign.right, isBold: true),
                    _dataCell('100.00%', align: pw.TextAlign.right, isBold: true),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              '2. RESUMEN DE COEFICIENTES DE INCIDENCIA POR ÍNDICE UNIFICADO (INEI)',
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(35),
                1: const pw.FlexColumnWidth(),
                2: const pw.FixedColumnWidth(80),
                3: const pw.FixedColumnWidth(85),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                  children: [
                    _tableHeaderCell('IU', align: pw.TextAlign.center),
                    _tableHeaderCell('Descripción del Índice Unificado'),
                    _tableHeaderCell('Monto (${presupuesto.currencySymbol})', align: pw.TextAlign.right),
                    _tableHeaderCell('Coeficiente (10 dec.)', align: pw.TextAlign.right),
                  ],
                ),
                ...iusSorted.map((iu) {
                  final monto = costosPorIU[iu] ?? 0.0;
                  final coef = monto / baseSubtotal;
                  return pw.TableRow(
                    children: [
                      _dataCell(iu.toString().padLeft(2, '0'), align: pw.TextAlign.center, isBold: true),
                      _dataCell(FormulaService.nombreIU(iu)),
                      _dataCell(_currencyFormat.format(monto), align: pw.TextAlign.right),
                      _dataCell(coef.toStringAsFixed(10), align: pw.TextAlign.right, isBold: true),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  /// 5. IMPRIMIR CRONOGRAMA VALORIZADO MENSUAL Y RESUMEN DE COSTOS POR RUBRO
  static Future<void> printCronogramaReport(
    Presupuesto presupuesto,
    Subpresupuesto subpresupuesto,
  ) async {
    final pdfBytes = await generateCronogramaPdf(presupuesto, subpresupuesto);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Cronograma_Valorizado_${presupuesto.code}.pdf',
    );
  }

  static Future<Uint8List> generateCronogramaPdf(
    Presupuesto presupuesto,
    Subpresupuesto subpresupuesto,
  ) async {
    final doc = pw.Document();
    final tareas = CronogramaService.programar(presupuesto);
    final periodos = CronogramaService.valorizar(
      tareas,
      30,
      presupuesto.date,
    );
    final sym = presupuesto.currencySymbol;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildHeader(
          presupuesto,
          subpresupuesto,
          titleSuffix: 'CALENDARIO VALORIZADO DE AVANCE DE OBRA Y RESUMEN DE COSTOS',
        ),
        footer: (context) => _buildFooter(context),
        build: (context) {
          return [
            pw.Text(
              '1. PROGRAMACIÓN CPM Y RESUMEN DE COSTOS POR PARTIDA (MO | MAT | EQ | SC)',
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
              columnWidths: {
                0: const pw.FixedColumnWidth(42),
                1: const pw.FlexColumnWidth(),
                2: const pw.FixedColumnWidth(28),
                3: const pw.FixedColumnWidth(38),
                4: const pw.FixedColumnWidth(62),
                5: const pw.FixedColumnWidth(62),
                6: const pw.FixedColumnWidth(62),
                7: const pw.FixedColumnWidth(68),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                  children: [
                    _tableHeaderCell('Ítem'),
                    _tableHeaderCell('Descripción de la Partida'),
                    _tableHeaderCell('Und', align: pw.TextAlign.center),
                    _tableHeaderCell('Días', align: pw.TextAlign.right),
                    _tableHeaderCell('Mano Obra', align: pw.TextAlign.right),
                    _tableHeaderCell('Materiales', align: pw.TextAlign.right),
                    _tableHeaderCell('Equipos', align: pw.TextAlign.right),
                    _tableHeaderCell('Parcial ($sym)', align: pw.TextAlign.right),
                  ],
                ),
                ...tareas.map((t) {
                  final p = t.partida;
                  return pw.TableRow(
                    children: [
                      _dataCell(p.itemNumber),
                      _dataCell(p.description),
                      _dataCell(p.unit, align: pw.TextAlign.center),
                      _dataCell('${t.duracion}', align: pw.TextAlign.right),
                      _dataCell(_currencyFormat.format(p.costoManoObraTotal), align: pw.TextAlign.right),
                      _dataCell(_currencyFormat.format(p.costoMaterialesTotal), align: pw.TextAlign.right),
                      _dataCell(_currencyFormat.format(p.costoEquiposTotal), align: pw.TextAlign.right),
                      _dataCell(_currencyFormat.format(p.costoParcial), align: pw.TextAlign.right, isBold: true),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              '2. RESUMEN MENSUAL DEL CALENDARIO VALORIZADO DE OBRA',
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                  children: [
                    _tableHeaderCell('Periodo / Mes'),
                    _tableHeaderCell('Costo Directo ($sym)', align: pw.TextAlign.right),
                    _tableHeaderCell('Acumulado CD ($sym)', align: pw.TextAlign.right),
                    _tableHeaderCell('% Avance Mes', align: pw.TextAlign.right),
                    _tableHeaderCell('% Avance Acum.', align: pw.TextAlign.right),
                  ],
                ),
                ...periodos.map((per) {
                  return pw.TableRow(
                    children: [
                      _dataCell(per.etiqueta, isBold: true),
                      _dataCell(_currencyFormat.format(per.monto), align: pw.TextAlign.right),
                      _dataCell(_currencyFormat.format(per.acumulado), align: pw.TextAlign.right),
                      _dataCell('${per.pct.toStringAsFixed(2)}%', align: pw.TextAlign.right),
                      _dataCell('${per.pctAcum.toStringAsFixed(2)}%', align: pw.TextAlign.right, isBold: true),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  /// 6. IMPRIMIR PLANILLA DE SUSTENTO DE METRADOS Y ESPECIFICACIONES TÉCNICAS
  static Future<void> printMetradosYEspecificacionesReport(
    Presupuesto presupuesto,
    Subpresupuesto subpresupuesto,
  ) async {
    final pdfBytes = await generateMetradosYEspecificacionesPdf(presupuesto, subpresupuesto);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Metrados_Especificaciones_${presupuesto.code}.pdf',
    );
  }

  static Future<Uint8List> generateMetradosYEspecificacionesPdf(
    Presupuesto presupuesto,
    Subpresupuesto subpresupuesto,
  ) async {
    final doc = pw.Document();
    final partidas = subpresupuesto.partidas.where((p) => !p.isTitle).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildHeader(
          presupuesto,
          subpresupuesto,
          titleSuffix: 'PLANILLA DE METRADOS Y ESPECIFICACIONES TÉCNICAS',
        ),
        footer: (context) => _buildFooter(context),
        build: (context) {
          final widgets = <pw.Widget>[];
          for (final p in partidas) {
            widgets.add(
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      color: PdfColors.blueGrey800,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              '${p.itemNumber} - ${p.description}',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                          ),
                          pw.Text(
                            'Metrado Total: ${_currencyFormat.format(p.metradoEfectivo)} ${p.unit}',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.amberAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (p.metradoLines.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                            children: [
                              _apuHeaderCell('Elemento / Descripción'),
                              _apuHeaderCell('N° Veces', align: pw.TextAlign.right),
                              _apuHeaderCell('Largo', align: pw.TextAlign.right),
                              _apuHeaderCell('Ancho', align: pw.TextAlign.right),
                              _apuHeaderCell('Alto', align: pw.TextAlign.right),
                              _apuHeaderCell('Parcial', align: pw.TextAlign.right),
                            ],
                          ),
                          ...p.metradoLines.map((l) {
                            return pw.TableRow(
                              children: [
                                _dataCell(l.descripcion),
                                _dataCell(_numberFormat.format(l.veces), align: pw.TextAlign.right),
                                _dataCell(_numberFormat.format(l.largo ?? 0.0), align: pw.TextAlign.right),
                                _dataCell(_numberFormat.format(l.ancho ?? 0.0), align: pw.TextAlign.right),
                                _dataCell(_numberFormat.format(l.alto ?? 0.0), align: pw.TextAlign.right),
                                _dataCell(_numberFormat.format(l.parcial), align: pw.TextAlign.right, isBold: true),
                              ],
                            );
                          }),
                        ],
                      ),
                    ],
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '- Descripción y Método Constructivo: ${p.effectiveEspecificacionDescripcion}',
                      style: const pw.TextStyle(fontSize: 6.8),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '- Método de Medición: ${p.effectiveEspecificacionMedicion}',
                      style: const pw.TextStyle(fontSize: 6.8),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '- Bases de Pago: ${p.effectiveEspecificacionPago}',
                      style: const pw.TextStyle(fontSize: 6.8),
                    ),
                  ],
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 8));
          }
          return widgets;
        },
      ),
    );

    return doc.save();
  }

  /// 7. IMPRIMIR EXPEDIENTE TÉCNICO INTEGRAL EN UN SOLO PDF (TODOS LOS RESULTADOS)
  static Future<void> printExpedienteCompletoPdf(
    Presupuesto presupuesto,
    Subpresupuesto subpresupuesto,
  ) async {
    final doc = pw.Document();
    final nonTitlePartidas = subpresupuesto.partidas.where((p) => !p.isTitle).toList();
    final insumos = InsumosService.consolidar(presupuesto.subpresupuestos);
    final sym = presupuesto.currencySymbol;

    // Sección 1: Hoja de Presupuesto y Pie
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(26),
        header: (context) => _buildHeader(presupuesto, subpresupuesto, titleSuffix: '1. HOJA DE PRESUPUESTO Y PIE RESUMEN'),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildPartidasTable(presupuesto, subpresupuesto),
          pw.SizedBox(height: 12),
          _buildPiePresupuesto(presupuesto, subpresupuesto),
        ],
      ),
    );

    // Sección 2: Análisis de Costos Unitarios
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildHeader(presupuesto, subpresupuesto, titleSuffix: '2. ANÁLISIS DE COSTOS UNITARIOS (APUs)'),
        footer: (context) => _buildFooter(context),
        build: (context) => nonTitlePartidas
            .expand((p) => [_buildApuBox(p, sym), pw.SizedBox(height: 10)])
            .toList(),
      ),
    );

    // Sección 3: Relación de Insumos y Fórmula Polinómica
    final costosPorIU = FormulaService.obtenerCostosPorIU(presupuesto);
    final baseSubtotal = presupuesto.subtotal > 0 ? presupuesto.subtotal : 1.0;
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildHeader(presupuesto, subpresupuesto, titleSuffix: '3. INSUMOS Y FÓRMULA POLINÓMICA'),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.Text('RELACIÓN GENERAL DE RECURSOS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                children: [
                  _tableHeaderCell('IU', align: pw.TextAlign.center),
                  _tableHeaderCell('Código'),
                  _tableHeaderCell('Descripción'),
                  _tableHeaderCell('Und', align: pw.TextAlign.center),
                  _tableHeaderCell('Cantidad', align: pw.TextAlign.right),
                  _tableHeaderCell('Precio', align: pw.TextAlign.right),
                  _tableHeaderCell('Parcial ($sym)', align: pw.TextAlign.right),
                ],
              ),
              ...insumos.map((ins) => pw.TableRow(
                    children: [
                      _dataCell(ins.iu.toString().padLeft(2, '0'), align: pw.TextAlign.center),
                      _dataCell(ins.code),
                      _dataCell(ins.descripcion),
                      _dataCell(ins.unidad, align: pw.TextAlign.center),
                      _dataCell(_qty4Format.format(ins.cantidad), align: pw.TextAlign.right),
                      _dataCell(_currencyFormat.format(ins.precio), align: pw.TextAlign.right),
                      _dataCell(_currencyFormat.format(ins.parcial), align: pw.TextAlign.right, isBold: true),
                    ],
                  )),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Text('FÓRMULA POLINÓMICA (D.S. N° 011-79-VC)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                children: [
                  _tableHeaderCell('Monomio'),
                  _tableHeaderCell('Símbolo', align: pw.TextAlign.center),
                  _tableHeaderCell('Coef. Calculado (10 dec.)', align: pw.TextAlign.right),
                  _tableHeaderCell('Coef. Definido (3 dec.)', align: pw.TextAlign.right),
                ],
              ),
              ...presupuesto.formulaPolinomica.monomios.map((m) {
                double cM = 0.0;
                for (final s in m.submonomios) {
                  cM += costosPorIU[s.unifiedIndex] ?? 0.0;
                }
                return pw.TableRow(
                  children: [
                    _dataCell('Monomio ${m.monomioNumber}: ${m.submonomios.map((s) => "IU ${s.unifiedIndex}").join(" + ")}'),
                    _dataCell(m.symbol, align: pw.TextAlign.center, isBold: true),
                    _dataCell((cM / baseSubtotal).toStringAsFixed(10), align: pw.TextAlign.right),
                    _dataCell(m.coeficiente.toStringAsFixed(3), align: pw.TextAlign.right, isBold: true),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Expediente_Tecnico_${presupuesto.code}.pdf',
    );
  }

  /// 8. IMPRIMIR CATÁLOGO MAESTRO DE COSTOS UNITARIOS (DELPHIN IMAGEN 1)
  static Future<void> printCatalogoCostosUnitariosPdf(List<Partida> catalogoPartidas) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.Text(
            'CATÁLOGO MAESTRO DE COSTOS UNITARIOS (DELPHIN EXPRESS BIM 360)',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...catalogoPartidas.expand((p) => [_buildApuBox(p, 'S/.'), pw.SizedBox(height: 10)]),
        ],
      ),
    );
    final bytes = await doc.save();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Catalogo_Costos_Unitarios_Delphin.pdf',
    );
  }

  static pw.Widget _dataCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.2, horizontal: 3),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _buildHeader(
    Presupuesto presupuesto,
    Subpresupuesto subpresupuesto, {
    String titleSuffix = 'HOJA DE PRESUPUESTO',
  }) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey700, width: 1.5)),
      ),
      padding: const pw.EdgeInsets.only(bottom: 8),
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'VFCOST PRO - DELPHIN EXPRESS BIM 360 & S10',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey800,
                ),
              ),
              pw.Text(
                'Fecha: ${_dateFormat.format(presupuesto.date)}  |  Modalidad: ${presupuesto.modalidadEjecucion}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              titleSuffix,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            columnWidths: {
              0: const pw.FixedColumnWidth(85),
              1: const pw.FlexColumnWidth(),
            },
            children: [
              pw.TableRow(children: [
                pw.Text('Presupuesto:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text('${presupuesto.code}  ${presupuesto.name}', style: const pw.TextStyle(fontSize: 8)),
              ]),
              pw.TableRow(children: [
                pw.Text('Subpresupuesto:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text('${subpresupuesto.code}  ${subpresupuesto.name}', style: const pw.TextStyle(fontSize: 8)),
              ]),
              pw.TableRow(children: [
                pw.Text('Cliente:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text(presupuesto.client, style: const pw.TextStyle(fontSize: 8)),
              ]),
              pw.TableRow(children: [
                pw.Text('Lugar / Ubigeo:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text(presupuesto.location, style: const pw.TextStyle(fontSize: 8)),
              ]),
              pw.TableRow(children: [
                pw.Text('Plazo / Jornada:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text('${presupuesto.plazoDias} Días Calendario  |  Jornada: ${presupuesto.jornada.toStringAsFixed(1)} h/día', style: const pw.TextStyle(fontSize: 8)),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
      ),
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generado por VFCOST Pro (Delphin Express BIM 360 / S10)', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  static pw.Widget _buildPartidasTable(
    Presupuesto presupuesto,
    Subpresupuesto subpresupuesto,
  ) {
    final currency = presupuesto.currencySymbol;

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(46), // Ítem
        1: const pw.FlexColumnWidth(), // Descripción
        2: const pw.FixedColumnWidth(32), // Und
        3: const pw.FixedColumnWidth(54), // Metrado
        4: const pw.FixedColumnWidth(58), // Precio
        5: const pw.FixedColumnWidth(68), // Parcial
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          children: [
            _tableHeaderCell('Ítem', align: pw.TextAlign.center),
            _tableHeaderCell('Descripción'),
            _tableHeaderCell('Und', align: pw.TextAlign.center),
            _tableHeaderCell('Metrado', align: pw.TextAlign.right),
            _tableHeaderCell('Precio ($currency)', align: pw.TextAlign.right),
            _tableHeaderCell('Parcial ($currency)', align: pw.TextAlign.right),
          ],
        ),
        ...subpresupuesto.partidas.map((partida) {
          final isTitle = partida.isTitle;
          final indent = (partida.level - 1) * 8.0;

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isTitle
                  ? (partida.level == 1 ? PdfColors.grey200 : PdfColors.grey100)
                  : PdfColors.white,
            ),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 3),
                child: pw.Text(
                  partida.itemNumber,
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: isTitle ? pw.FontWeight.bold : pw.FontWeight.normal,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.only(top: 2.5, bottom: 2.5, left: 3 + indent, right: 3),
                child: pw.Text(
                  partida.description,
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: isTitle ? pw.FontWeight.bold : pw.FontWeight.normal,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 3),
                child: pw.Text(
                  isTitle ? '' : partida.unit,
                  style: const pw.TextStyle(fontSize: 7),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 3),
                child: pw.Text(
                  isTitle ? '' : NumberFormatUtils.formatNumber(partida.metrado),
                  style: const pw.TextStyle(fontSize: 7),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 3),
                child: pw.Text(
                  isTitle ? '' : NumberFormatUtils.formatNumber(partida.precioUnitario),
                  style: const pw.TextStyle(fontSize: 7),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 3),
                child: pw.Text(
                  NumberFormatUtils.formatNumber(partida.costoParcial),
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: isTitle ? pw.FontWeight.bold : pw.FontWeight.normal,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _tableHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _buildPiePresupuesto(
    Presupuesto presupuesto,
    Subpresupuesto subpresupuesto,
  ) {
    final pie = presupuesto.piePresupuesto;
    final cd = subpresupuesto.costoDirecto;
    final ggFijos = pie.calcularGGFijos(cd);
    final ggVar = pie.calcularGGVariables(cd);
    final util = pie.calcularUtilidad(cd);
    final subtotal = pie.calcularSubtotal(cd);
    final igv = pie.calcularIGV(cd);
    final total = pie.calcularTotalPresupuesto(cd);
    final sym = presupuesto.currencySymbol;

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 260,
        decoration: pw.BoxDecoration(
          border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.8),
          color: PdfColors.grey50,
        ),
        child: pw.Column(
          children: [
            _pieRow('COSTO DIRECTO (CD)', NumberFormatUtils.formatCurrency(cd, symbol: sym), isBold: true),
            _pieRow('Gastos Generales Fijos (${pie.porcentajeGGFijos}%)', NumberFormatUtils.formatCurrency(ggFijos, symbol: sym)),
            _pieRow('Gastos Generales Variables (${pie.porcentajeGGVariables}%)', NumberFormatUtils.formatCurrency(ggVar, symbol: sym)),
            _pieRow('Utilidad (${pie.porcentajeUtilidad}%)', NumberFormatUtils.formatCurrency(util, symbol: sym)),
            pw.Divider(height: 1, thickness: 0.5, color: PdfColors.grey500),
            _pieRow('SUBTOTAL', NumberFormatUtils.formatCurrency(subtotal, symbol: sym), isBold: true),
            if (pie.aplicarIGV)
              _pieRow('I.G.V. (${pie.porcentajeIGV}%)', NumberFormatUtils.formatCurrency(igv, symbol: sym)),
            pw.Container(
              color: PdfColors.blueGrey800,
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL PRESUPUESTO', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  pw.Text(NumberFormatUtils.formatCurrency(total, symbol: sym), style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                ],
              ),
            ),
            pw.Container(
              width: double.infinity,
              color: PdfColors.grey200,
              padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
              child: pw.Text(
                NumberFormatUtils.numberToWords(total, currency: presupuesto.currencyName.isNotEmpty ? presupuesto.currencyName : 'SOLES'),
                style: pw.TextStyle(fontSize: 6.2, fontWeight: pw.FontWeight.bold, fontStyle: pw.FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _pieRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildApuBox(Partida partida, String currency) {
    final moItems = partida.apuItems.where((i) => i.type == ResourceType.manoDeObra).toList();
    final matItems = partida.apuItems.where((i) => i.type == ResourceType.material).toList();
    final eqItems = partida.apuItems.where((i) => i.type == ResourceType.equipo).toList();
    final scItems = partida.apuItems.where((i) => i.type == ResourceType.subcontrato).toList();

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            color: PdfColors.blueGrey800,
            padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'Partida: ${partida.itemNumber} ${partida.description}',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  ),
                ),
                pw.Text(
                  'Rendimiento: ${_currencyFormat.format(partida.rendimiento)} ${partida.unit}/DÍA  |  Duración: ${partida.duracionExactaDias.toStringAsFixed(3)} días',
                  style: const pw.TextStyle(fontSize: 7.2, color: PdfColors.white),
                ),
                pw.SizedBox(width: 8),
                pw.Text(
                  'Costo Unit: $currency ${_currencyFormat.format(partida.calculateUnitPrice())}',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.amberAccent),
                ),
              ],
            ),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
            columnWidths: {
              0: const pw.FixedColumnWidth(45), // Código
              1: const pw.FlexColumnWidth(), // Descripción Insumo
              2: const pw.FixedColumnWidth(28), // Und
              3: const pw.FixedColumnWidth(36), // Cuadrilla
              4: const pw.FixedColumnWidth(44), // Cantidad
              5: const pw.FixedColumnWidth(34), // % Desp.
              6: const pw.FixedColumnWidth(44), // Precio
              7: const pw.FixedColumnWidth(50), // Parcial
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _apuHeaderCell('Código'),
                  _apuHeaderCell('Descripción Recurso'),
                  _apuHeaderCell('Und', align: pw.TextAlign.center),
                  _apuHeaderCell('Cuad.', align: pw.TextAlign.right),
                  _apuHeaderCell('Cantidad', align: pw.TextAlign.right),
                  _apuHeaderCell('% Desp', align: pw.TextAlign.right),
                  _apuHeaderCell('Precio', align: pw.TextAlign.right),
                  _apuHeaderCell('Parcial', align: pw.TextAlign.right),
                ],
              ),
              if (moItems.isNotEmpty) ...[
                _apuCategoryHeaderRow('MANO DE OBRA'),
                ...moItems.map((i) => _apuResourceRow(i, currency)),
                _apuSubtotalRow('Total Mano de Obra', partida.subtotalMO, currency),
              ],
              if (matItems.isNotEmpty) ...[
                _apuCategoryHeaderRow('MATERIALES'),
                ...matItems.map((i) => _apuResourceRow(i, currency)),
                _apuSubtotalRow('Total Materiales', partida.subtotalMateriales, currency),
              ],
              if (eqItems.isNotEmpty) ...[
                _apuCategoryHeaderRow('EQUIPOS Y HERRAMIENTAS'),
                ...eqItems.map((i) => _apuResourceRow(i, currency, subtotalMO: partida.subtotalMO)),
                _apuSubtotalRow('Total Equipos', partida.subtotalEquipos, currency),
              ],
              if (scItems.isNotEmpty) ...[
                _apuCategoryHeaderRow('SUBCONTRATOS'),
                ...scItems.map((i) => _apuResourceRow(i, currency)),
                _apuSubtotalRow('Total Subcontratos', partida.subtotalSubcontratos, currency),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static pw.TableRow _apuCategoryHeaderRow(String title) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: pw.Text(title, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
        ),
        pw.Container(), pw.Container(), pw.Container(), pw.Container(), pw.Container(), pw.Container(), pw.Container(),
      ],
    );
  }

  static pw.TableRow _apuResourceRow(ApuItem item, String currency, {double subtotalMO = 0.0}) {
    final parcial = item.calculateParcial(subtotalMO: subtotalMO);

    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
          child: pw.Text(item.resourceCode, style: const pw.TextStyle(fontSize: 6.5)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
          child: pw.Text(
            item.isPercentageOfMO
                ? '${item.resourceDescription} (${item.percentageValue.toStringAsFixed(1)}% MO)'
                : item.resourceDescription,
            style: const pw.TextStyle(fontSize: 6.5),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
          child: pw.Text(item.unit, style: const pw.TextStyle(fontSize: 6.5), textAlign: pw.TextAlign.center),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
          child: pw.Text(
            item.cuadrilla > 0 ? item.cuadrilla.toStringAsFixed(2) : '',
            style: const pw.TextStyle(fontSize: 6.5),
            textAlign: pw.TextAlign.right,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
          child: pw.Text(
            item.isPercentageOfMO ? '${item.percentageValue}%' : _numberFormat.format(item.cantidadConDesperdicio),
            style: const pw.TextStyle(fontSize: 6.5),
            textAlign: pw.TextAlign.right,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
          child: pw.Text(
            item.desperdicio > 0 ? '${item.desperdicio.toStringAsFixed(1)}%' : '',
            style: const pw.TextStyle(fontSize: 6.5),
            textAlign: pw.TextAlign.right,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
          child: pw.Text(
            item.isPercentageOfMO ? '' : _currencyFormat.format(item.precioUnitario),
            style: const pw.TextStyle(fontSize: 6.5),
            textAlign: pw.TextAlign.right,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
          child: pw.Text(
            _currencyFormat.format(parcial),
            style: const pw.TextStyle(fontSize: 6.5),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  static pw.TableRow _apuSubtotalRow(String label, double value, String currency) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
      children: [
        pw.Container(),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
          child: pw.Text(label, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
        ),
        pw.Container(), pw.Container(), pw.Container(), pw.Container(), pw.Container(),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 3),
          child: pw.Text(_currencyFormat.format(value), style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
        ),
      ],
    );
  }

  static pw.Widget _apuHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
        textAlign: align,
      ),
    );
  }
}
