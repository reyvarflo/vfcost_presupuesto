import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vfcost_presupuesto/data/sample_projects.dart';
import 'package:vfcost_presupuesto/models/apu_item.dart';
import 'package:vfcost_presupuesto/models/gasto_general.dart';
import 'package:vfcost_presupuesto/models/metrado_line.dart';
import 'package:vfcost_presupuesto/models/partida.dart';
import 'package:vfcost_presupuesto/models/pie_presupuesto.dart';
import 'package:vfcost_presupuesto/models/presupuesto.dart';
import 'package:vfcost_presupuesto/models/resource.dart';
import 'package:vfcost_presupuesto/models/subpresupuesto.dart';
import 'package:vfcost_presupuesto/services/s2k_service.dart';

void main() {
  group('S10 Civil Engineering Budget Engine Tests', () {
    test('APU Unit Price Calculation matches S10 Standard', () {
      // Caso estándar S10:
      // Partida: CONCRETO EN ZAPATAS F'C=210 KG/CM2
      // Rendimiento: 25.00 m3/día, Jornada: 8.0 horas
      // Capataz: Cuadrilla 0.20 -> Cantidad = (0.2 * 8) / 25 = 0.064 hh @ 32.50 = 2.08
      // Operario: Cuadrilla 2.00 -> Cantidad = (2.0 * 8) / 25 = 0.640 hh @ 27.80 = 17.792
      // Peón: Cuadrilla 8.00 -> Cantidad = (8.0 * 8) / 25 = 2.560 hh @ 20.20 = 51.712
      // Subtotal MO = 2.08 + 17.792 + 51.712 = 71.584

      final moCapataz = const ApuItem(
        id: 'mo1',
        resourceId: 'res1',
        resourceCode: '0101',
        resourceDescription: 'CAPATAZ',
        unit: 'hh',
        type: ResourceType.manoDeObra,
        cuadrilla: 0.2,
        cantidad: 0.064,
        precioUnitario: 32.50,
      );

      final moOperario = const ApuItem(
        id: 'mo2',
        resourceId: 'res2',
        resourceCode: '0102',
        resourceDescription: 'OPERARIO',
        unit: 'hh',
        type: ResourceType.manoDeObra,
        cuadrilla: 2.0,
        cantidad: 0.640,
        precioUnitario: 27.80,
      );

      final moPeon = const ApuItem(
        id: 'mo3',
        resourceId: 'res3',
        resourceCode: '0104',
        resourceDescription: 'PEON',
        unit: 'hh',
        type: ResourceType.manoDeObra,
        cuadrilla: 8.0,
        cantidad: 2.560,
        precioUnitario: 20.20,
      );

      // Material: Cemento 9.73 bolsas @ 29.50 = 287.035
      final matCemento = const ApuItem(
        id: 'mat1',
        resourceId: 'res_cem',
        resourceCode: '0201',
        resourceDescription: 'CEMENTO PORTLAND TIPO I',
        unit: 'bol',
        type: ResourceType.material,
        cantidad: 9.73,
        precioUnitario: 29.50,
      );

      // Equipo: Herramientas manuales 3% de Mano de Obra
      final eqHerramientas = const ApuItem(
        id: 'eq1',
        resourceId: 'res_herr',
        resourceCode: '0301',
        resourceDescription: 'HERRAMIENTAS MANUALES',
        unit: '%mo',
        type: ResourceType.equipo,
        isPercentageOfMO: true,
        percentageValue: 3.0,
        precioUnitario: 0.0,
      );

      final partida = Partida(
        id: 'p1',
        itemNumber: '01.01',
        description: 'CONCRETO EN ZAPATAS',
        unit: 'm3',
        metrado: 10.0,
        rendimiento: 25.0,
        apuItems: [moCapataz, moOperario, moPeon, matCemento, eqHerramientas],
      );

      final subMO = partida.subtotalMO;
      expect(subMO, closeTo(71.584, 0.01));

      final subMat = partida.subtotalMateriales;
      expect(subMat, closeTo(287.035, 0.01));

      final subEq = partida.subtotalEquipos;
      // 3% de 71.584 = 2.14752
      expect(subEq, closeTo(2.1475, 0.01));

      final unitPrice = partida.calculateUnitPrice();
      expect(unitPrice, closeTo(71.584 + 287.035 + 2.1475, 0.01));

      // Costo Parcial para 10 m3
      final parcial = partida.calculateParcial();
      expect(parcial, closeTo(unitPrice * 10.0, 0.05));
    });

    test('Automatic Recalculation on Rendimiento change', () {
      final mo = const ApuItem(
        id: 'mo1',
        resourceId: 'res1',
        resourceCode: '0101',
        resourceDescription: 'OPERARIO',
        unit: 'hh',
        type: ResourceType.manoDeObra,
        cuadrilla: 1.0,
        cantidad: 0.8, // 1 * 8 / 10 = 0.8
        precioUnitario: 20.0,
      );

      var partida = Partida(
        id: 'p1',
        itemNumber: '01.01',
        description: 'EXCAVACION',
        unit: 'm3',
        metrado: 5.0,
        rendimiento: 10.0,
        apuItems: [mo],
      );

      expect(partida.calculateUnitPrice(), equals(16.0)); // 0.8 * 20

      // Duplicamos el rendimiento a 20.0 m3/día -> la cantidad debe reducirse a la mitad (0.4)
      partida = partida.copyWith(rendimiento: 20.0).recalculateWithJornada(8.0);
      expect(partida.apuItems.first.cantidad, equals(0.4));
      expect(partida.calculateUnitPrice(), equals(8.0)); // 0.4 * 20 = 8.0
      expect(partida.costoParcial, equals(40.0)); // 5 * 8.0 = 40.0
    });

    test('Hierarchical Title Rollup in Subpresupuesto', () {
      final p1 = Partida(
        id: '1',
        itemNumber: '01',
        description: 'OBRAS PRELIMINARES',
        isTitle: true,
        level: 1,
      );

      final p2 = Partida(
        id: '2',
        itemNumber: '01.01',
        description: 'LIMPIEZA DE TERRENO',
        isTitle: false,
        level: 2,
        unit: 'm2',
        metrado: 100.0,
        precioUnitario: 10.0,
        costoParcial: 1000.0,
      );

      final p3 = Partida(
        id: '3',
        itemNumber: '01.02',
        description: 'TRAZO Y REPLANTEO',
        isTitle: false,
        level: 2,
        unit: 'm2',
        metrado: 100.0,
        precioUnitario: 5.0,
        costoParcial: 500.0,
      );

      var sub = Subpresupuesto(
        id: 's1',
        code: '001',
        name: 'ESTRUCTURAS',
        partidas: [p1, p2, p3],
      );

      sub = sub.processSubpresupuesto(8.0);

      // El título debe acumular 1000 + 500 = 1500
      expect(sub.partidas.first.costoParcial, equals(1500.0));
      // El costo directo total del subpresupuesto debe ser 1500
      expect(sub.costoDirecto, equals(1500.0));
    });

    test('Pie de Presupuesto calculations (Gastos Generales, Utilidad, IGV)', () {
      const pie = PiePresupuesto(
        porcentajeGGFijos: 3.0,
        porcentajeGGVariables: 7.0,
        porcentajeUtilidad: 10.0,
        porcentajeIGV: 18.0,
        aplicarIGV: true,
      );

      const costoDirecto = 100000.0; // S/. 100,000

      expect(pie.calcularGGFijos(costoDirecto), closeTo(3000.0, 0.01));
      expect(pie.calcularGGVariables(costoDirecto), closeTo(7000.0, 0.01));
      expect(pie.calcularGGTotal(costoDirecto), closeTo(10000.0, 0.01)); // 10%
      expect(pie.calcularUtilidad(costoDirecto), closeTo(10000.0, 0.01)); // 10%

      // Subtotal = 100,000 + 10,000 + 10,000 = 120,000
      final subtotal = pie.calcularSubtotal(costoDirecto);
      expect(subtotal, closeTo(120000.0, 0.01));

      // IGV = 18% de 120,000 = 21,600
      final igv = pie.calcularIGV(costoDirecto);
      expect(igv, closeTo(21600.0, 0.01));

      // Total = 120,000 + 21,600 = 141,600
      final total = pie.calcularTotalPresupuesto(costoDirecto);
      expect(total, closeTo(141600.0, 0.01));
    });

    test('Sample Project loads and validates Formula Polinomica', () {
      final sample = SampleProjects.getSamplePresupuesto();
      expect(sample.subpresupuestos.length, equals(2));
      expect(sample.totalCostoDirecto, greaterThan(0.0));
      expect(sample.totalPresupuesto, greaterThan(sample.totalCostoDirecto));

      // Verificar que la fórmula polinómica oficial sume 1.000 (DS 011-79-VC)
      expect(sample.formulaPolinomica.isValid, isTrue);
      expect(sample.formulaPolinomica.sumaCoeficientes, closeTo(1.000, 0.005));
    });

    test('Delphin Hoja de Metrados calculates partials and transfers to partida', () {
      const line1 = MetradoLine(
        id: 'l1',
        descripcion: 'Zapata Z-1 Eje A (4 unidades)',
        veces: 4.0,
        largo: 1.20,
        ancho: 1.20,
        alto: 0.60,
      );
      // 4 * 1.20 * 1.20 * 0.60 = 3.456 m3
      expect(line1.parcial, closeTo(3.456, 0.001));

      const line2 = MetradoLine(
        id: 'l2',
        descripcion: 'Zapata Z-2 Eje B (2 unidades)',
        veces: 2.0,
        largo: 1.50,
        ancho: 1.50,
        alto: 0.80,
      );
      // 2 * 1.50 * 1.50 * 0.80 = 3.600 m3
      expect(line2.parcial, closeTo(3.600, 0.001));

      final partida = Partida(
        id: 'p_met',
        itemNumber: '02.01',
        description: 'CONCRETO EN ZAPATAS',
        unit: 'm3',
        metrado: 10.0,
        metradoLines: [line1, line2],
      );

      // metradoEfectivo debe ser 3.456 + 3.600 = 7.056
      expect(partida.metradoDeHoja, closeTo(7.056, 0.001));
      expect(partida.metradoEfectivo, closeTo(7.056, 0.001));
    });

    test('Delphin Programacion computes duration from Rendimiento and lag', () {
      final p1 = Partida(
        id: 'p1',
        itemNumber: '01.01',
        description: 'EXCAVACION',
        unit: 'm3',
        metrado: 100.0,
        rendimiento: 25.0, // 100 / 25 = 4 dias
      );

      expect(p1.duracionCalculada, equals(4));

      final p2 = Partida(
        id: 'p2',
        itemNumber: '01.02',
        description: 'SOLADO',
        unit: 'm2',
        metrado: 80.0,
        rendimiento: 80.0, // 80 / 80 = 1 dia
        predecesoraId: 'p1',
        desfaseDias: 1, // lag de 1 dia
      );

      expect(p2.duracionCalculada, equals(1));
      expect(p2.predecesoraId, equals('p1'));
      expect(p2.desfaseDias, equals(1));
    });

    test('Delphin Gastos Generales Desagregados computes fijos and variables correctly', () {
      const gFijo = GastoGeneralItem(
        id: 'g1',
        tipo: TipoGasto.fijo,
        descripcion: 'GASTOS DE LICITACION',
        cantidad: 1.0,
        tiempo: 1.0,
        precio: 3000.0,
        participacion: 100.0,
      );
      expect(gFijo.parcial, closeTo(3000.0, 0.01));

      const gVar = GastoGeneralItem(
        id: 'g2',
        tipo: TipoGasto.variable,
        descripcion: 'RESIDENTE DE OBRA',
        unidad: 'mes',
        cantidad: 1.0,
        tiempo: 4.0, // 4 meses
        precio: 7000.0, // S/. 7,000 / mes
        participacion: 100.0,
      );
      // 1 * 4 * 7000 * 1.0 = 28,000
      expect(gVar.parcial, closeTo(28000.0, 0.01));
    });

    test('S2K Service URL configuration and JSON parsing', () async {
      SharedPreferences.setMockInitialValues({});

      // Probar URL por defecto y modificación
      final initialUrl = await S2kService.getServerUrl();
      expect(initialUrl, isNotEmpty);

      await S2kService.setServerUrl('https://api.s10converter.pe/');
      final updatedUrl = await S2kService.getServerUrl();
      expect(updatedUrl, equals('https://api.s10converter.pe'));

      // Verificar que el JSON devuelto por el backend S2K se deserializa en Presupuesto
      final sampleJson = SampleProjects.getSamplePresupuesto().toJson();
      final parsed = Presupuesto.fromJson(sampleJson);
      expect(parsed.code, isNotEmpty);
      expect(parsed.subpresupuestos.length, greaterThan(0));
    });
  });
}
