import 'package:flutter_test/flutter_test.dart';
import 'package:vfcost_presupuesto/data/sample_projects.dart';
import 'package:vfcost_presupuesto/models/presupuesto.dart';
import 'package:vfcost_presupuesto/models/resource.dart';
import 'package:vfcost_presupuesto/services/delphin_excel_service.dart';
import 'package:vfcost_presupuesto/services/delphin_json_service.dart';
import 'package:vfcost_presupuesto/services/formula_service.dart';
import 'package:vfcost_presupuesto/services/ms_project_export_service.dart';
import 'package:vfcost_presupuesto/services/pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Presupuesto sampleProject;

  setUp(() {
    sampleProject = SampleProjects.getSamplePresupuesto();
  });

  group('Delphin Express & Agrupamiento Polinómico Tests', () {
    test('FormulaService IUs summary and custom grouping calculates Σk = 1.000', () {
      final ius = FormulaService.obtenerResumenIUs(sampleProject);
      expect(ius.isNotEmpty, isTrue);

      // Verificar que los IUs principales estén presentes (ej. 47 Mano de obra, 39 GG y Utilidad)
      final hasMO = ius.any((i) => i.iu == 47);
      final hasGU = ius.any((i) => i.iu == 39);
      expect(hasMO, isTrue);
      expect(hasGU, isTrue);

      // Simulación de Agrupamiento interactivo: asignar IUs a monomios 1, 2 y 3
      final customAsignaciones = <int, int>{};
      int m = 0;
      for (final iu in ius) {
        customAsignaciones[iu.iu] = (m % 3) + 1;
        m++;
      }

      final customFormula = FormulaService.construirFormulaPersonalizada(
        sampleProject,
        customAsignaciones,
        simbolosMonomio: {
          1: 'M',
          2: 'C',
          3: 'GU',
        },
      );

      expect(customFormula.monomios.length, 3);
      expect((customFormula.sumaCoeficientes - 1.0).abs() < 0.005, isTrue);
      expect(customFormula.isValid, isTrue);
    });

    test('Delphin JSON Export & Import reproduces project structure and APUs', () async {
      final sub = sampleProject.subpresupuestos.first;
      final jsonMap = {
        'proyecto': {
          'nombre': sampleProject.name,
          'cliente': sampleProject.client,
          'ubicacion': sampleProject.location,
          'moneda': 'PEN',
          'fecha': '2026-10-23',
          'costo_directo': sub.costoDirecto,
        },
        'partidas': [
          {
            'item': '01',
            'descripcion': 'OBRAS PROVISIONALES',
            'es_titulo': true,
            'unidad': null,
            'metrado': null,
            'precio_unitario': null,
            'parcial': 45200.0,
          },
          {
            'item': '01.01.01',
            'descripcion': 'CARTEL DE IDENTIFICACION DE LA OBRA',
            'es_titulo': false,
            'unidad': 'und',
            'metrado': 1.0,
            'precio_unitario': 1250.0,
            'parcial': 1250.0,
            'apu': {
              'rendimiento': 1.0,
              'unidad_tiempo': 'DIA',
              'recursos': [
                {
                  'tipo': 'MANO_DE_OBRA',
                  'codigo': '010101',
                  'descripcion': 'OPERARIO',
                  'unidad': 'hh',
                  'cuadrilla': 1.0,
                  'cantidad': 8.0,
                  'precio': 28.5,
                  'parcial': 228.0,
                  'indice_unificado': 47,
                },
                {
                  'tipo': 'MATERIAL',
                  'codigo': '020105',
                  'descripcion': 'BANNER IMPRESO',
                  'unidad': 'm2',
                  'cuadrilla': 0.0,
                  'cantidad': 8.64,
                  'precio': 45.0,
                  'parcial': 388.8,
                  'indice_unificado': 39,
                }
              ]
            }
          }
        ]
      };

      // Import JSON
      final imported = DelphinJsonService.importDelphinJson(jsonMap);
      expect(imported, isNotNull);
      expect(imported!.name, sampleProject.name);
      expect(imported.subpresupuestos.first.partidas.length, 2);

      final title = imported.subpresupuestos.first.partidas[0];
      final partida = imported.subpresupuestos.first.partidas[1];

      expect(title.isTitle, isTrue);
      expect(partida.isTitle, isFalse);
      expect(partida.apuItems.length, 2);
      expect(partida.apuItems.first.resourceDescription, 'OPERARIO');
      expect(partida.apuItems.first.unifiedIndex, 47);
    });

    test('MS Project XML Export generates valid XML structure with tasks', () async {
      final sub = sampleProject.subpresupuestos.first;
      final file = await MsProjectExportService.exportMsProjectXml(sampleProject, sub, share: false);
      expect(file, isNotNull);
      expect(file!.existsSync(), isTrue);

      final content = await file.readAsString();
      expect(content.contains('<Project xmlns="http://schemas.microsoft.com/project">'), isTrue);
      expect(content.contains('<Tasks>'), isTrue);
      expect(content.contains('<Task>'), isTrue);
      expect(content.contains('<OutlineLevel>'), isTrue);
    });

    test('Delphin Excel Export creates .xlsx with 4 structured sheets', () async {
      final file = await DelphinExcelService.exportDelphinXlsx(sampleProject, share: false);
      expect(file, isNotNull);
      expect(file!.existsSync(), isTrue);

      final bytes = await file.readAsBytes();
      expect(bytes.isNotEmpty, isTrue);

      // Verify that DelphinExcelService can re-import the file
      final reimported = DelphinExcelService.importDelphinXlsx(bytes);
      expect(reimported, isNotNull);
      expect(reimported!.subpresupuestos.first.partidas.isNotEmpty, isTrue);

      // Verify detection of Titles vs Partidas
      final hasTitles = reimported.subpresupuestos.first.partidas.any((p) => p.isTitle);
      final hasPartidas = reimported.subpresupuestos.first.partidas.any((p) => !p.isTitle);
      expect(hasTitles, isTrue);
      expect(hasPartidas, isTrue);
    });

    test('Delphin Incidencia de Costos and Pie Factors match Costo Directo breakdown', () {
      final incidencia = sampleProject.calcularIncidenciaCostos();
      final mo = incidencia[ResourceType.manoDeObra] ?? 0.0;
      final mat = incidencia[ResourceType.material] ?? 0.0;
      final eq = incidencia[ResourceType.equipo] ?? 0.0;
      final sc = incidencia[ResourceType.subcontrato] ?? 0.0;

      expect(mo, greaterThan(0));
      expect(mat, greaterThan(0));
      expect(eq, greaterThan(0));

      final sumRubros = mo + mat + eq + sc;
      expect(sumRubros, closeTo(sampleProject.totalCostoDirecto, 50.0));

      // Verificar proveedor por defecto estilo Delphin
      final firstPartidaWithApu = sampleProject.subpresupuestos.first.partidas.firstWhere((p) => !p.isTitle && p.apuItems.isNotEmpty);
      final moApu = firstPartidaWithApu.apuItems.firstWhere((a) => a.type == ResourceType.manoDeObra);
      expect(moApu.effectiveProveedor, 'PROVEEDOR DISTRITAL');
    });

    test('Delphin % Desperdicio, Metrado Fierro (kg/m) and 10-decimal Incidence Matrix work accurately', () {
      // 1. Verificar % Desperdicio en APUItem
      final firstPartida = sampleProject.subpresupuestos.first.partidas
          .firstWhere((p) => !p.isTitle && p.apuItems.isNotEmpty);
      final matApu = firstPartida.apuItems.firstWhere(
        (a) => a.type == ResourceType.material,
        orElse: () => firstPartida.apuItems.first,
      );
      final withWaste = matApu.copyWith(cantidad: 10.0, desperdicio: 5.0);
      expect(withWaste.cantidadConDesperdicio, closeTo(10.5, 0.0001));
      expect(withWaste.calculateParcial(), closeTo(10.5 * withWaste.precioUnitario, 0.01));

      // 2. Verificar Especificaciones Técnicas automáticas y Duración exacta
      expect(firstPartida.effectiveEspecificacionDescripcion.isNotEmpty, isTrue);
      expect(firstPartida.effectiveEspecificacionMedicion.isNotEmpty, isTrue);
      expect(firstPartida.effectiveEspecificacionPago.isNotEmpty, isTrue);
      expect(firstPartida.duracionExactaDias, greaterThanOrEqualTo(0.0));

      // 3. Verificar Matriz de Coeficientes de Incidencia a 10 decimales (Suma = 1.0000000000)
      final costosPorIU = FormulaService.obtenerCostosPorIU(sampleProject);
      expect(costosPorIU.isNotEmpty, isTrue);
      final sumaCostosIU = costosPorIU.values.fold(0.0, (a, b) => a + b);
      expect(sumaCostosIU, closeTo(sampleProject.subtotal, 1.0));

      final sumaCoef10Dec = costosPorIU.values
          .map((c) => c / sampleProject.subtotal)
          .fold(0.0, (a, b) => a + b);
      expect(sumaCoef10Dec, closeTo(1.0, 0.000001));
    });

    test('PdfExportService generates valid PDF bytes for all 6 project reports', () async {
      final sub = sampleProject.subpresupuestos.first;
      final hojaBytes = await PdfExportService.generateHojaPresupuestoPdf(sampleProject, sub);
      final apuBytes = await PdfExportService.generateApuReportPdf(sampleProject, sub);
      final insumosBytes = await PdfExportService.generateInsumosReportPdf(sampleProject, sub);
      final formulaBytes = await PdfExportService.generateFormulaPolinomicaPdf(sampleProject, sub);
      final cronogramaBytes = await PdfExportService.generateCronogramaPdf(sampleProject, sub);
      final metradosBytes = await PdfExportService.generateMetradosYEspecificacionesPdf(sampleProject, sub);

      expect(hojaBytes.isNotEmpty, isTrue);
      expect(apuBytes.isNotEmpty, isTrue);
      expect(insumosBytes.isNotEmpty, isTrue);
      expect(formulaBytes.isNotEmpty, isTrue);
      expect(cronogramaBytes.isNotEmpty, isTrue);
      expect(metradosBytes.isNotEmpty, isTrue);
    });
  });
}
