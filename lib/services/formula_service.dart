import '../models/formula_polinomica.dart';
import '../models/presupuesto.dart';
import '../models/resource.dart';
import 'insumos_service.dart';

/// Representa el resumen de un Índice Unificado (IU) presente en el presupuesto
class IuResumen {
  final int iu;
  final String descripcion;
  final double costo;
  final double incidencia; // costo / subtotal (0.0 a 1.0)
  final int monomioAsignado; // 1 a 8
  final String simboloMonomio;

  const IuResumen({
    required this.iu,
    required this.descripcion,
    required this.costo,
    required this.incidencia,
    this.monomioAsignado = 1,
    this.simboloMonomio = '',
  });

  IuResumen copyWith({
    int? iu,
    String? descripcion,
    double? costo,
    double? incidencia,
    int? monomioAsignado,
    String? simboloMonomio,
  }) {
    return IuResumen(
      iu: iu ?? this.iu,
      descripcion: descripcion ?? this.descripcion,
      costo: costo ?? this.costo,
      incidencia: incidencia ?? this.incidencia,
      monomioAsignado: monomioAsignado ?? this.monomioAsignado,
      simboloMonomio: simboloMonomio ?? this.simboloMonomio,
    );
  }
}

/// Generación y Agrupamiento de la Fórmula Polinómica (D.S. N° 011-79-VC) y cálculo del coeficiente K.
class FormulaService {
  /// Catálogo oficial de Índices Unificados INEI (01 al 80)
  static const Map<int, String> nombresIUTotales = {
    1: 'Aceite',
    2: 'Acero de construcción liso',
    3: 'Acero de construcción corrugado',
    4: 'Agregado fino',
    5: 'Agregado grueso',
    6: 'Alambre y cable de cobre desnudo',
    7: 'Alambre y cable TW y THW',
    8: 'Alcantarilla metálica',
    9: 'Arena',
    10: 'Asfalto',
    11: 'Baldosa acústica',
    12: 'Baldosa asfáltica',
    13: 'Baldosa vinílica',
    14: 'Batería',
    15: 'Bloque de vidrio',
    16: 'Bloqueta de concreto',
    17: 'Bloque y ladrillo',
    18: 'Cable NYY / N2XY',
    19: 'Cable telefónico',
    20: 'Cemento asfáltico',
    21: 'Cemento Portland tipo I',
    22: 'Cemento Portland tipo II',
    23: 'Cemento Portland tipo V',
    24: 'Cerámica esmaltada y vitrificada',
    25: 'Cerrajería nacional',
    26: 'Cerrajería importada',
    27: 'Combustible (Petróleo D-2)',
    28: 'Concreto premezclado',
    29: 'Cordel y driza',
    30: 'Dinamita',
    31: 'Dúcto de concreto',
    32: 'Dúcto de PVC',
    33: 'Electrobomba',
    34: 'Elemento de fijación',
    35: 'Estructura metálica',
    36: 'Gasolina',
    37: 'Herramienta manual',
    38: 'Hormigón',
    39: 'Índice general de precios al consumidor (GG + Utilidad)',
    40: 'Losa de concreto prefabricada',
    41: 'Madera en troza',
    42: 'Madera importada',
    43: 'Madera nacional para encofrado y carpintería',
    44: 'Madera terciada',
    45: 'Manifold de bronce',
    46: 'Malla de alambre de acero',
    47: 'Mano de obra inc. leyes sociales',
    48: 'Maquinaria y equipo nacional',
    49: 'Maquinaria y equipo importado',
    50: 'Marco y tapa de fierro fundido',
    51: 'Pintura látex',
    52: 'Pintura óleo y esmalte',
    53: 'Pintura anticorrosiva',
    54: 'Plancha de acero LAC',
    55: 'Plancha de acero LAF',
    56: 'Plancha de fibrocemento',
    57: 'Plancha de poliuretano',
    58: 'Plancha de yeso-cartón',
    59: 'Poste de concreto',
    60: 'Tubería de acero',
    61: 'Tubería de cobre',
    62: 'Tubería de fierro dúctil',
    63: 'Tubería de fierro fundido',
    64: 'Tubería de asbesto-cemento',
    65: 'Tubería de concreto simple',
    66: 'Tubería de concreto reforzado',
    67: 'Tubería de polietileno (HDPE)',
    68: 'Tubería de polipropileno (PP)',
    69: 'Tubería de PVC para agua',
    70: 'Tubería de PVC para desagüe',
    71: 'Tubería de PVC para electricidad',
    72: 'Válvula de bronce nacional',
    73: 'Válvula de bronce importada',
    74: 'Válvula de fierro fundido',
    75: 'Vidrio templado y de seguridad',
    76: 'Vidrio plano e impreso',
    77: 'Válvula compuerta',
    78: 'Yeso',
    79: 'Zinc',
    80: 'Transformador eléctrico',
  };

  static const Map<int, String> simbolosPorDefecto = {
    47: 'M',
    21: 'C',
    3: 'A',
    2: 'AL',
    4: 'AF',
    5: 'AG',
    17: 'L',
    43: 'MD',
    37: 'E',
    48: 'EN',
    49: 'E',
    39: 'GU',
  };

  static String nombreIU(int iu) =>
      nombresIUTotales[iu] ?? 'Índice unificado ${iu.toString().padLeft(2, '0')}';

  static double _r3(double v) => (v * 1000).roundToDouble() / 1000;

  static int _iuPorDefecto(ResourceType t) {
    switch (t) {
      case ResourceType.manoDeObra:
        return 47;
      case ResourceType.equipo:
        return 49;
      default:
        return 39;
    }
  }

  /// Obtiene la relación de IUs activos en el presupuesto con su costo e incidencia
  static List<IuResumen> obtenerResumenIUs(
    Presupuesto p, {
    Map<int, int>? asignaciones,
    Map<int, String>? simbolos,
  }) {
    final cd = p.totalCostoDirecto;
    final base = p.subtotal;
    if (base <= 0) return [];

    final iuCost = <int, double>{};
    for (final i in InsumosService.consolidar(p.subpresupuestos)) {
      final iu = i.iu > 0 ? i.iu : _iuPorDefecto(i.tipo);
      iuCost[iu] = (iuCost[iu] ?? 0) + i.parcial;
    }

    // El monto de Gastos Generales y Utilidad corresponde a IU 39 por norma
    final ggUtilidad = base - cd;
    if (ggUtilidad > 0) {
      iuCost[39] = (iuCost[39] ?? 0) + ggUtilidad;
    }

    final sugeridos = sugerirAgrupamiento(p);

    final lista = <IuResumen>[];
    for (final entry in iuCost.entries) {
      final iu = entry.key;
      final costo = entry.value;
      if (costo <= 0) continue;

      final monomio = asignaciones?[iu] ?? sugeridos[iu] ?? 1;
      final simbolo = simbolos?[monomio] ?? simbolosPorDefecto[iu] ?? 'M$monomio';

      lista.add(IuResumen(
        iu: iu,
        descripcion: nombreIU(iu),
        costo: costo,
        incidencia: costo / base,
        monomioAsignado: monomio,
        simboloMonomio: simbolo,
      ));
    }

    lista.sort((a, b) => b.costo.compareTo(a.costo));
    return lista;
  }

  /// Sugiere un agrupamiento normativo inicial cumpliendo el D.S. N° 011-79-VC
  static Map<int, int> sugerirAgrupamiento(Presupuesto p) {
    final base = p.subtotal;
    final map = <int, int>{};
    if (base <= 0) return map;

    final cd = p.totalCostoDirecto;
    final iuCost = <int, double>{};
    for (final i in InsumosService.consolidar(p.subpresupuestos)) {
      final iu = i.iu > 0 ? i.iu : _iuPorDefecto(i.tipo);
      iuCost[iu] = (iuCost[iu] ?? 0) + i.parcial;
    }
    final ggUtilidad = base - cd;
    if (ggUtilidad > 0) {
      iuCost[39] = (iuCost[39] ?? 0) + ggUtilidad;
    }

    var monomioNum = 1;

    // 1. Mano de Obra (IU 47) siempre es un monomio independiente
    if (iuCost.containsKey(47) && (iuCost[47]! / base) >= 0.05) {
      map[47] = monomioNum++;
    }

    // 2. Equipos y herramientas (IUs 37, 48, 49) agrupados si no alcanzan el 5% individual
    final equipIus = [37, 48, 49].where((iu) => iuCost.containsKey(iu)).toList();
    final totalEq = equipIus.fold(0.0, (sum, iu) => sum + (iuCost[iu] ?? 0));
    if (totalEq / base >= 0.05 && monomioNum <= 7) {
      final eqMonomio = monomioNum++;
      for (final iu in equipIus) {
        map[iu] = eqMonomio;
      }
    }

    // 3. Materiales principales que superen 5% (Cemento, Acero, etc.)
    final mats = iuCost.entries
        .where((e) => e.key != 47 && !equipIus.contains(e.key) && e.key != 39)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final menorCinco = <int>[];
    for (final e in mats) {
      if ((e.value / base) >= 0.05 && monomioNum < 8) {
        map[e.key] = monomioNum++;
      } else {
        menorCinco.add(e.key);
      }
    }

    // 4. Gastos Generales y Utilidad (IU 39)
    final guMonomio = monomioNum <= 8 ? monomioNum : 8;
    map[39] = guMonomio;

    // 5. Todos los insumos menores al 5% se integran al monomio de GU o al último monomio
    for (final iu in menorCinco) {
      map[iu] = guMonomio;
    }

    // Garantizar que todos los IUs tengan asignación
    for (final iu in iuCost.keys) {
      map.putIfAbsent(iu, () => guMonomio);
    }

    return map;
  }

  /// Construye la Fórmula Polinómica a partir del agrupamiento seleccionado por el usuario
  static FormulaPolinomica construirFormulaPersonalizada(
    Presupuesto p,
    Map<int, int> asignaciones, {
    Map<int, String>? simbolosMonomio,
  }) {
    final cd = p.totalCostoDirecto;
    final base = p.subtotal;
    if (cd <= 0 || base <= 0) return const FormulaPolinomica();

    final iuCost = <int, double>{};
    for (final i in InsumosService.consolidar(p.subpresupuestos)) {
      final iu = i.iu > 0 ? i.iu : _iuPorDefecto(i.tipo);
      iuCost[iu] = (iuCost[iu] ?? 0) + i.parcial;
    }
    final ggUtilidad = base - cd;
    if (ggUtilidad > 0) {
      iuCost[39] = (iuCost[39] ?? 0) + ggUtilidad;
    }

    // Agrupar costos por número de monomio asignado (1 a 8)
    final gruposPorMonomio = <int, Map<int, double>>{};
    for (final entry in iuCost.entries) {
      final iu = entry.key;
      final costo = entry.value;
      if (costo <= 0) continue;

      final mNum = (asignaciones[iu] ?? 1).clamp(1, 8);
      gruposPorMonomio.putIfAbsent(mNum, () => {})[iu] = costo;
    }

    if (gruposPorMonomio.isEmpty) return const FormulaPolinomica();

    // Ordenar los números de monomio 1, 2, 3...
    final sortedKeys = gruposPorMonomio.keys.toList()..sort();

    // Calcular coeficiente k para cada monomio
    final ks = <double>[];
    for (final k in sortedKeys) {
      final totalGrupo = gruposPorMonomio[k]!.values.fold(0.0, (a, b) => a + b);
      ks.add(_r3(totalGrupo / base));
    }

    // Cuadrar la suma a exactamente 1.000 ajustando en el monomio con mayor coeficiente
    final sumaKs = ks.fold(0.0, (a, b) => a + b);
    final diff = _r3(1.0 - sumaKs);
    if (diff != 0 && ks.isNotEmpty) {
      var idxMax = 0;
      for (var i = 1; i < ks.length; i++) {
        if (ks[i] > ks[idxMax]) idxMax = i;
      }
      ks[idxMax] = _r3(ks[idxMax] + diff);
    }

    final monomiosFinales = <Monomio>[];
    for (var i = 0; i < sortedKeys.length; i++) {
      final mKey = sortedKeys[i];
      final mapaIUs = gruposPorMonomio[mKey]!;
      final totalMonomio = mapaIUs.values.fold(0.0, (a, b) => a + b);

      // Ordenar submonomios por costo descendente
      final entries = mapaIUs.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

      // Factores dentro del monomio (suman 1.000)
      final factores = entries
          .map((e) => totalMonomio > 0 ? _r3(e.value / totalMonomio) : 0.0)
          .toList();
      if (factores.isNotEmpty) {
        final sumaFactores = factores.fold(0.0, (a, b) => a + b);
        final diffF = _r3(1.0 - sumaFactores);
        factores[0] = _r3(factores[0] + diffF);
      }

      // Símbolo del monomio
      String simbolo = simbolosMonomio?[mKey] ?? '';
      if (simbolo.isEmpty) {
        // Asignar símbolo del IU principal
        final iuPrincipal = entries.first.key;
        simbolo = simbolosPorDefecto[iuPrincipal] ?? 'M$mKey';
      }

      final submonomios = <Submonomio>[];
      for (var j = 0; j < entries.length; j++) {
        submonomios.add(Submonomio(
          unifiedIndex: entries[j].key,
          description: nombreIU(entries[j].key),
          factor: factores[j],
        ));
      }

      monomiosFinales.add(Monomio(
        monomioNumber: i + 1,
        symbol: simbolo,
        coeficiente: ks[i],
        submonomios: submonomios,
      ));
    }

    return FormulaPolinomica(monomios: monomiosFinales);
  }

  /// Genera la fórmula agrupando insumos por defecto (norma D.S. N° 011-79-VC)
  static FormulaPolinomica generar(Presupuesto p) {
    final sugerido = sugerirAgrupamiento(p);
    return construirFormulaPersonalizada(p, sugerido);
  }

  /// K = Σ k_i × Σ f_ij × (Ir / Io), redondeado a 3 decimales.
  static double calcularK(
    FormulaPolinomica f,
    Map<int, double> indicesBase,
    Map<int, double> indicesActuales,
  ) {
    if (f.monomios.isEmpty) return 1.0;
    double k = 0;
    for (final m in f.monomios) {
      double s = 0;
      for (final sub in m.submonomios) {
        final io = indicesBase[sub.unifiedIndex];
        final ir = indicesActuales[sub.unifiedIndex];
        final ratio = (io != null && io > 0 && ir != null && ir > 0) ? ir / io : 1.0;
        s += sub.factor * ratio;
      }
      k += m.coeficiente * s;
    }
    return _r3(k);
  }

  /// IUs que intervienen en la fórmula
  static List<int> indicesDeFormula(FormulaPolinomica f) {
    final set = <int>{};
    for (final m in f.monomios) {
      for (final s in m.submonomios) {
        set.add(s.unifiedIndex);
      }
    }
    return set.toList()..sort();
  }

  /// Calcula el mapa de costos exactos por IU (incluyendo IU 39 para GG + Utilidad)
  static Map<int, double> obtenerCostosPorIU(Presupuesto p) {
    final cd = p.totalCostoDirecto;
    final base = p.subtotal;
    final iuCost = <int, double>{};
    if (base <= 0) return iuCost;

    for (final i in InsumosService.consolidar(p.subpresupuestos)) {
      final iu = i.iu > 0 ? i.iu : _iuPorDefecto(i.tipo);
      iuCost[iu] = (iuCost[iu] ?? 0) + i.parcial;
    }
    final ggUtilidad = base - cd;
    if (ggUtilidad > 0) {
      iuCost[39] = (iuCost[39] ?? 0) + ggUtilidad;
    }
    return iuCost;
  }

  /// Calcula los montos por Índice Unificado que aporta una partida o título (en S/)
  static Map<int, double> calcularMontosIUPorPartida(
    dynamic partida,
    List<dynamic> allPartidas,
  ) {
    final result = <int, double>{};
    if (partida.isTitle as bool) {
      final prefix = '${partida.itemNumber}.';
      for (final child in allPartidas) {
        if (!(child.isTitle as bool) &&
            (child.itemNumber as String).startsWith(prefix)) {
          final childMap = calcularMontosIUPorPartida(child, allPartidas);
          for (final entry in childMap.entries) {
            result[entry.key] = (result[entry.key] ?? 0.0) + entry.value;
          }
        }
      }
      return result;
    }

    final metrado = partida.metradoEfectivo as double;
    if (metrado <= 0) return result;
    final moSubtotal = partida.subtotalMO as double;

    for (final item in (partida.apuItems as List<dynamic>)) {
      final iu = (item.unifiedIndex as int) > 0
          ? (item.unifiedIndex as int)
          : _iuPorDefecto(item.type as ResourceType);
      final parcialUnitario = item.calculateParcial(subtotalMO: moSubtotal) as double;
      final monto = parcialUnitario * metrado;
      if (monto > 0) {
        result[iu] = (result[iu] ?? 0.0) + monto;
      }
    }
    return result;
  }
}
