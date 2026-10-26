import 'formula_polinomica.dart';
import 'gasto_general.dart';
import 'pie_presupuesto.dart';
import 'resource.dart';
import 'subpresupuesto.dart';
import 'valorizacion.dart';

class Presupuesto {
  final String id;
  final String code;
  final String name;
  final String client;
  final String location;
  final DateTime date; // Fecha base / inicio de obra (Costos al: ...)
  final String currencySymbol;
  final String currencyName;
  final double tipoCambio; // Tipo de cambio (ej. 1.0000 o 3.7500 S/. por USD)
  final double jornada; // Horas de trabajo al día (default 8)
  final int plazoDias; // Plazo contractual en días
  final String tipoObra; // "Edificaciones", "Agua potable y alcantarillado", "Obras Viales", "Infraestructura Educativa", "Obras Hidráulicas", etc.
  final String naturaleza; // "Construcción", "Mejoramiento", "Ampliación", "Rehabilitación", "Mantenimiento", "OxI", "APP"
  final String departamento;
  final String provincia;
  final String distrito;
  final String localidad;
  final String modalidadEjecucion; // "Por contrata" | "Por administración directa"
  final String metodoCalculoAcu; // "Por Rendimiento de Cuadrilla" | "Por Asignación de Recursos"
  final String hechoPor;
  final bool isLocked; // Candado Delphin: true = protegido / solo lectura, false = en elaboración
  final List<Subpresupuesto> subpresupuestos;
  final PiePresupuesto piePresupuesto;
  final FormulaPolinomica formulaPolinomica;
  final bool formulaManual; // true = el usuario editó la fórmula, no se regenera al procesar
  final Map<int, double> indicesBase; // IU -> índice a la fecha del presupuesto (Io)
  final List<GastoGeneralItem> gastosGenerales;
  final bool usarGGDesagregado;
  final List<Valorizacion> valorizaciones;
  final String activeSubpresupuestoId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Presupuesto({
    required this.id,
    required this.code,
    required this.name,
    required this.client,
    required this.location,
    required this.date,
    this.currencySymbol = 'S/.',
    this.currencyName = 'Soles',
    this.tipoCambio = 3.75,
    this.jornada = 8.0,
    this.plazoDias = 120,
    this.tipoObra = 'Edificaciones',
    this.naturaleza = 'Construcción',
    this.departamento = 'LIMA',
    this.provincia = 'LIMA',
    this.distrito = 'LIMA',
    this.localidad = '',
    this.modalidadEjecucion = 'Por contrata',
    this.metodoCalculoAcu = 'Por Rendimiento de Cuadrilla',
    this.hechoPor = 'Administrador',
    this.isLocked = false,
    this.subpresupuestos = const [],
    this.piePresupuesto = const PiePresupuesto(),
    this.formulaPolinomica = const FormulaPolinomica(),
    this.formulaManual = false,
    this.indicesBase = const {},
    this.gastosGenerales = const [],
    this.usarGGDesagregado = false,
    this.valorizaciones = const [],
    this.activeSubpresupuestoId = '',
    required this.createdAt,
    required this.updatedAt,
  });

  Subpresupuesto? get activeSubpresupuesto {
    if (subpresupuestos.isEmpty) return null;
    return subpresupuestos.firstWhere(
      (s) => s.id == activeSubpresupuestoId,
      orElse: () => subpresupuestos.first,
    );
  }

  double get totalCostoDirecto =>
      subpresupuestos.fold(0.0, (sum, sub) => sum + sub.costoDirecto);

  double get totalGastosGenerales => piePresupuesto.calcularGGTotal(totalCostoDirecto);

  double get totalUtilidad => piePresupuesto.calcularUtilidad(totalCostoDirecto);

  double get totalGGFijosDesagregado {
    if (!usarGGDesagregado) return piePresupuesto.calcularGGFijos(totalCostoDirecto);
    return gastosGenerales
        .where((g) => g.tipo == TipoGasto.fijo)
        .fold(0.0, (s, g) => s + g.parcial);
  }

  double get totalGGVariablesDesagregado {
    if (!usarGGDesagregado) return piePresupuesto.calcularGGVariables(totalCostoDirecto);
    return gastosGenerales
        .where((g) => g.tipo == TipoGasto.variable)
        .fold(0.0, (s, g) => s + g.parcial);
  }

  double get subtotal => piePresupuesto.calcularSubtotal(totalCostoDirecto);

  double get igv => piePresupuesto.calcularIGV(totalCostoDirecto);

  double get totalPresupuesto => piePresupuesto.calcularTotalPresupuesto(totalCostoDirecto);

  /// Calcula la incidencia de costos directos desglosada por Mano de Obra, Materiales, Equipos y Subcontratos.
  /// Si [subpresupuestoId] es nulo, suma todo el proyecto.
  Map<ResourceType, double> calcularIncidenciaCostos({String? subpresupuestoId}) {
    final result = <ResourceType, double>{
      ResourceType.manoDeObra: 0.0,
      ResourceType.material: 0.0,
      ResourceType.equipo: 0.0,
      ResourceType.subcontrato: 0.0,
    };

    final subs = subpresupuestoId == null
        ? subpresupuestos
        : subpresupuestos.where((s) => s.id == subpresupuestoId);

    for (final sub in subs) {
      for (final partida in sub.partidas) {
        if (partida.isTitle || partida.metrado <= 0) continue;
        // Subtotal de mano de obra unitario para calcular herramientas (%MO)
        double unitMO = 0.0;
        for (final apu in partida.apuItems) {
          if (apu.type == ResourceType.manoDeObra && !apu.isPercentageOfMO) {
            unitMO += apu.cantidad * apu.precioUnitario;
          }
        }
        for (final apu in partida.apuItems) {
          final double unitParcial = apu.isPercentageOfMO
              ? unitMO * (apu.percentageValue / 100.0)
              : apu.cantidad * apu.precioUnitario;
          final double totalInsumo = unitParcial * partida.metrado;
          result[apu.type] = (result[apu.type] ?? 0.0) + totalInsumo;
        }
      }
    }
    return result;
  }

  /// Procesa todo el presupuesto recalculando partidas, rollups y subpresupuestos
  Presupuesto processAll() {
    final updatedSubs = subpresupuestos.map((sub) => sub.processSubpresupuesto(jornada)).toList();
    return copyWith(
      subpresupuestos: updatedSubs,
      updatedAt: DateTime.now(),
    );
  }

  Presupuesto copyWith({
    String? id,
    String? code,
    String? name,
    String? client,
    String? location,
    DateTime? date,
    String? currencySymbol,
    String? currencyName,
    double? tipoCambio,
    double? jornada,
    int? plazoDias,
    String? tipoObra,
    String? naturaleza,
    String? departamento,
    String? provincia,
    String? distrito,
    String? localidad,
    String? modalidadEjecucion,
    String? metodoCalculoAcu,
    String? hechoPor,
    bool? isLocked,
    List<Subpresupuesto>? subpresupuestos,
    PiePresupuesto? piePresupuesto,
    FormulaPolinomica? formulaPolinomica,
    bool? formulaManual,
    Map<int, double>? indicesBase,
    List<GastoGeneralItem>? gastosGenerales,
    bool? usarGGDesagregado,
    List<Valorizacion>? valorizaciones,
    String? activeSubpresupuestoId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Presupuesto(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      client: client ?? this.client,
      location: location ?? this.location,
      date: date ?? this.date,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      currencyName: currencyName ?? this.currencyName,
      tipoCambio: tipoCambio ?? this.tipoCambio,
      jornada: jornada ?? this.jornada,
      plazoDias: plazoDias ?? this.plazoDias,
      tipoObra: tipoObra ?? this.tipoObra,
      naturaleza: naturaleza ?? this.naturaleza,
      departamento: departamento ?? this.departamento,
      provincia: provincia ?? this.provincia,
      distrito: distrito ?? this.distrito,
      localidad: localidad ?? this.localidad,
      modalidadEjecucion: modalidadEjecucion ?? this.modalidadEjecucion,
      metodoCalculoAcu: metodoCalculoAcu ?? this.metodoCalculoAcu,
      hechoPor: hechoPor ?? this.hechoPor,
      isLocked: isLocked ?? this.isLocked,
      subpresupuestos: subpresupuestos ?? this.subpresupuestos,
      piePresupuesto: piePresupuesto ?? this.piePresupuesto,
      formulaPolinomica: formulaPolinomica ?? this.formulaPolinomica,
      formulaManual: formulaManual ?? this.formulaManual,
      indicesBase: indicesBase ?? this.indicesBase,
      gastosGenerales: gastosGenerales ?? this.gastosGenerales,
      usarGGDesagregado: usarGGDesagregado ?? this.usarGGDesagregado,
      valorizaciones: valorizaciones ?? this.valorizaciones,
      activeSubpresupuestoId: activeSubpresupuestoId ?? this.activeSubpresupuestoId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'client': client,
      'location': location,
      'date': date.toIso8601String(),
      'currencySymbol': currencySymbol,
      'currencyName': currencyName,
      'tipoCambio': tipoCambio,
      'jornada': jornada,
      'plazoDias': plazoDias,
      'tipoObra': tipoObra,
      'naturaleza': naturaleza,
      'departamento': departamento,
      'provincia': provincia,
      'distrito': distrito,
      'localidad': localidad,
      'modalidadEjecucion': modalidadEjecucion,
      'metodoCalculoAcu': metodoCalculoAcu,
      'hechoPor': hechoPor,
      'isLocked': isLocked,
      'subpresupuestos': subpresupuestos.map((e) => e.toJson()).toList(),
      'piePresupuesto': piePresupuesto.toJson(),
      'formulaPolinomica': formulaPolinomica.toJson(),
      'formulaManual': formulaManual,
      'indicesBase': indicesBase.map((k, v) => MapEntry(k.toString(), v)),
      'gastosGenerales': gastosGenerales.map((e) => e.toJson()).toList(),
      'usarGGDesagregado': usarGGDesagregado,
      'valorizaciones': valorizaciones.map((e) => e.toJson()).toList(),
      'activeSubpresupuestoId': activeSubpresupuestoId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Presupuesto.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(String key) =>
        DateTime.tryParse(json[key] as String? ?? '') ?? DateTime.now();

    return Presupuesto(
      id: json['id'] as String,
      code: json['code'] as String? ?? '0101001',
      name: json['name'] as String,
      client: json['client'] as String? ?? '',
      location: json['location'] as String? ?? '',
      date: parseDate('date'),
      currencySymbol: json['currencySymbol'] as String? ?? 'S/.',
      currencyName: json['currencyName'] as String? ?? 'Soles',
      tipoCambio: (json['tipoCambio'] as num?)?.toDouble() ?? 3.75,
      jornada: (json['jornada'] as num?)?.toDouble() ?? 8.0,
      plazoDias: (json['plazoDias'] as num?)?.toInt() ?? 120,
      tipoObra: json['tipoObra'] as String? ?? 'Edificaciones',
      naturaleza: json['naturaleza'] as String? ?? 'Construcción',
      departamento: json['departamento'] as String? ?? 'LIMA',
      provincia: json['provincia'] as String? ?? 'LIMA',
      distrito: json['distrito'] as String? ?? 'LIMA',
      localidad: json['localidad'] as String? ?? '',
      modalidadEjecucion: json['modalidadEjecucion'] as String? ?? 'Por contrata',
      metodoCalculoAcu: json['metodoCalculoAcu'] as String? ?? 'Por Rendimiento de Cuadrilla',
      hechoPor: json['hechoPor'] as String? ?? 'Administrador',
      isLocked: json['isLocked'] as bool? ?? false,
      subpresupuestos: (json['subpresupuestos'] as List<dynamic>?)
              ?.map((e) => Subpresupuesto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      piePresupuesto: json['piePresupuesto'] != null
          ? PiePresupuesto.fromJson(json['piePresupuesto'] as Map<String, dynamic>)
          : const PiePresupuesto(),
      formulaPolinomica: json['formulaPolinomica'] != null
          ? FormulaPolinomica.fromJson(json['formulaPolinomica'] as Map<String, dynamic>)
          : const FormulaPolinomica(),
      formulaManual: json['formulaManual'] as bool? ?? false,
      indicesBase: (json['indicesBase'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(int.parse(k), (v as num).toDouble())) ??
          {},
      gastosGenerales: (json['gastosGenerales'] as List<dynamic>?)
              ?.map((e) => GastoGeneralItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      usarGGDesagregado: json['usarGGDesagregado'] as bool? ?? false,
      valorizaciones: (json['valorizaciones'] as List<dynamic>?)
              ?.map((e) => Valorizacion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      activeSubpresupuestoId: json['activeSubpresupuestoId'] as String? ?? '',
      createdAt: parseDate('createdAt'),
      updatedAt: parseDate('updatedAt'),
    );
  }
}
