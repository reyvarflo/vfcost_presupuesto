import 'apu_item.dart';
import 'metrado_line.dart';
import 'resource.dart';

class Partida {
  final String id;
  final String itemNumber; // ej: "01", "01.01", "01.01.01"
  final String description;
  final bool isTitle; // True si es Título (Estructura jerárquica), False si es Partida
  final int level; // 1..5 (nivel de indentación en el árbol de partidas)
  final String unit; // m3, m2, kg, und, etc. (vacío si es título)
  final double metrado; // Cantidad a ejecutar
  final double rendimiento; // Rendimiento por día (ej. 25.00 m3/día)
  final double precioUnitario; // Calculado desde el APU (o manual si no tiene APU)
  final double costoParcial; // metrado * precioUnitario (o suma de hijos si es título)
  final List<ApuItem> apuItems;
  final String notes;

  // Especificaciones Técnicas (Delphin Express BIM 360)
  final String especificacionDescripcion; // "Descripción y Método de construcción"
  final String especificacionMedicion; // "Método de medición"
  final String especificacionPago; // "Bases de pago"

  // Hoja de metrados
  final List<MetradoLine> metradoLines;

  // Programación de obra (cronograma)
  final int inicioDia; // Día de inicio si no tiene predecesora
  final int? duracionDias; // null => calculada como metrado / rendimiento
  final String? predecesoraId; // Relación Fin-Inicio
  final int desfaseDias; // Desfase (lag) respecto a la predecesora

  const Partida({
    required this.id,
    required this.itemNumber,
    required this.description,
    this.isTitle = false,
    this.level = 1,
    this.unit = '',
    this.metrado = 0.0,
    this.rendimiento = 1.0,
    this.precioUnitario = 0.0,
    this.costoParcial = 0.0,
    this.apuItems = const [],
    this.notes = '',
    this.especificacionDescripcion = '',
    this.especificacionMedicion = '',
    this.especificacionPago = '',
    this.metradoLines = const [],
    this.inicioDia = 0,
    this.duracionDias,
    this.predecesoraId,
    this.desfaseDias = 0,
  });

  /// Descripción y método constructivo (usa plantilla técnica estándar si está vacío)
  String get effectiveEspecificacionDescripcion {
    if (especificacionDescripcion.trim().isNotEmpty) return especificacionDescripcion;
    final insumosStr = apuItems.isNotEmpty
        ? apuItems.map((e) => e.resourceDescription).take(5).join(', ')
        : 'mano de obra calificada, materiales certificados y herramientas adecuadas';
    return 'Comprende el suministro de la mano de obra, materiales, equipo y la ejecución de las operaciones necesarias '
        'para realizar la partida "${description.toUpperCase()}", empleando principalmente: $insumosStr, de acuerdo con '
        'los planos del expediente técnico, las normas vigentes del Reglamento Nacional de Edificaciones (RNE) y las '
        'indicaciones del Ingeniero Supervisor.';
  }

  /// Método de medición (usa plantilla estándar según unidad si está vacío)
  String get effectiveEspecificacionMedicion {
    if (especificacionMedicion.trim().isNotEmpty) return especificacionMedicion;
    final u = unit.isNotEmpty ? unit : 'und';
    return 'El trabajo ejecutado se medirá en la unidad especificada ($u), verificando en campo las dimensiones y cantidades '
        'realmente ejecutadas de conformidad con los planos del proyecto y contando con la aprobación del Ingeniero Supervisor de Obra.';
  }

  /// Bases de pago (usa plantilla estándar según unidad si está vacío)
  String get effectiveEspecificacionPago {
    if (especificacionPago.trim().isNotEmpty) return especificacionPago;
    final u = unit.isNotEmpty ? unit : 'und';
    return 'El pago se efectuará por la unidad de medida ($u) al precio unitario del contrato para la partida "${description.toUpperCase()}". '
        'Dicho precio y pago constituirá compensación total por la mano de obra (incluyendo leyes sociales), materiales, equipos, '
        'herramientas e imprevistos necesarios para culminar satisfactoriamente la partida.';
  }

  /// Metrado total de la hoja de metrados
  double get metradoDeHoja => metradoLines.fold(0.0, (s, l) => s + l.parcial);

  /// Metrado vigente: el de la hoja si existe, si no el ingresado directamente
  double get metradoEfectivo => metradoLines.isNotEmpty ? metradoDeHoja : metrado;

  /// Duración exacta en días con decimales (ej. 1.000 días en Delphin)
  double get duracionExactaDias {
    if (duracionDias != null && duracionDias! > 0) return duracionDias!.toDouble();
    if (isTitle || rendimiento <= 0 || metradoEfectivo <= 0) return 1.0;
    return metradoEfectivo / rendimiento;
  }

  /// Duración entera en días para diagrama Gantt
  int get duracionCalculada {
    if (duracionDias != null && duracionDias! > 0) return duracionDias!;
    if (isTitle || rendimiento <= 0 || metradoEfectivo <= 0) return 1;
    final d = (metradoEfectivo / rendimiento).ceil();
    return d < 1 ? 1 : d;
  }

  /// Subtotal de Mano de Obra en el APU (unitario)
  double get subtotalMO {
    if (isTitle) return 0.0;
    return apuItems
        .where((item) => item.type == ResourceType.manoDeObra)
        .fold(0.0, (sum, item) => sum + item.calculateParcial());
  }

  /// Subtotal de Materiales en el APU (unitario)
  double get subtotalMateriales {
    if (isTitle) return 0.0;
    return apuItems
        .where((item) => item.type == ResourceType.material)
        .fold(0.0, (sum, item) => sum + item.calculateParcial());
  }

  /// Subtotal de Equipos y Herramientas en el APU (unitario)
  double get subtotalEquipos {
    if (isTitle) return 0.0;
    final moTotal = subtotalMO;
    return apuItems
        .where((item) => item.type == ResourceType.equipo)
        .fold(0.0, (sum, item) => sum + item.calculateParcial(subtotalMO: moTotal));
  }

  /// Subtotal de Subcontratos en el APU (unitario)
  double get subtotalSubcontratos {
    if (isTitle) return 0.0;
    return apuItems
        .where((item) => item.type == ResourceType.subcontrato)
        .fold(0.0, (sum, item) => sum + item.calculateParcial());
  }

  /// Costo total de Mano de Obra de la partida (unitario * metrado)
  double get costoManoObraTotal => isTitle ? 0.0 : subtotalMO * metradoEfectivo;

  /// Costo total de Materiales de la partida (unitario * metrado)
  double get costoMaterialesTotal => isTitle ? 0.0 : subtotalMateriales * metradoEfectivo;

  /// Costo total de Equipos de la partida (unitario * metrado)
  double get costoEquiposTotal => isTitle ? 0.0 : subtotalEquipos * metradoEfectivo;

  /// Costo total de Subcontratos de la partida (unitario * metrado)
  double get costoSubcontratosTotal => isTitle ? 0.0 : subtotalSubcontratos * metradoEfectivo;

  /// Costo Directo Unitario. Si la partida no tiene APU se usa el precio ingresado manualmente.
  double calculateUnitPrice() {
    if (isTitle) return 0.0;
    if (apuItems.isEmpty) return precioUnitario;
    return subtotalMO + subtotalMateriales + subtotalEquipos + subtotalSubcontratos;
  }

  /// Costo parcial de la partida = metrado * precioUnitario
  double calculateParcial() {
    if (isTitle) return costoParcial;
    return metradoEfectivo * calculateUnitPrice();
  }

  /// Recalcula aportes de MO y equipos (Cuadrilla × Jornada / Rendimiento),
  /// el metrado desde la hoja de metrados, el precio unitario y el parcial.
  Partida recalculateWithJornada(double jornada) {
    if (isTitle) return this;
    final m = metradoEfectivo;
    if (apuItems.isEmpty) {
      return copyWith(metrado: m, costoParcial: m * precioUnitario);
    }

    final updatedItems = rendimiento > 0
        ? apuItems.map((item) {
            if ((item.type == ResourceType.manoDeObra || item.type == ResourceType.equipo) &&
                !item.isPercentageOfMO &&
                item.cuadrilla > 0) {
              return item.copyWith(cantidad: (item.cuadrilla * jornada) / rendimiento);
            }
            return item;
          }).toList()
        : apuItems;

    final temp = copyWith(apuItems: updatedItems, metrado: m);
    final pu = temp.calculateUnitPrice();
    return temp.copyWith(precioUnitario: pu, costoParcial: m * pu);
  }

  Partida copyWith({
    String? id,
    String? itemNumber,
    String? description,
    bool? isTitle,
    int? level,
    String? unit,
    double? metrado,
    double? rendimiento,
    double? precioUnitario,
    double? costoParcial,
    List<ApuItem>? apuItems,
    String? notes,
    String? especificacionDescripcion,
    String? especificacionMedicion,
    String? especificacionPago,
    List<MetradoLine>? metradoLines,
    int? inicioDia,
    int? duracionDias,
    bool clearDuracion = false,
    String? predecesoraId,
    bool clearPredecesora = false,
    int? desfaseDias,
  }) {
    return Partida(
      id: id ?? this.id,
      itemNumber: itemNumber ?? this.itemNumber,
      description: description ?? this.description,
      isTitle: isTitle ?? this.isTitle,
      level: level ?? this.level,
      unit: unit ?? this.unit,
      metrado: metrado ?? this.metrado,
      rendimiento: rendimiento ?? this.rendimiento,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      costoParcial: costoParcial ?? this.costoParcial,
      apuItems: apuItems ?? this.apuItems,
      notes: notes ?? this.notes,
      especificacionDescripcion: especificacionDescripcion ?? this.especificacionDescripcion,
      especificacionMedicion: especificacionMedicion ?? this.especificacionMedicion,
      especificacionPago: especificacionPago ?? this.especificacionPago,
      metradoLines: metradoLines ?? this.metradoLines,
      inicioDia: inicioDia ?? this.inicioDia,
      duracionDias: clearDuracion ? null : (duracionDias ?? this.duracionDias),
      predecesoraId: clearPredecesora ? null : (predecesoraId ?? this.predecesoraId),
      desfaseDias: desfaseDias ?? this.desfaseDias,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'itemNumber': itemNumber,
      'description': description,
      'isTitle': isTitle,
      'level': level,
      'unit': unit,
      'metrado': metrado,
      'rendimiento': rendimiento,
      'precioUnitario': precioUnitario,
      'costoParcial': costoParcial,
      'apuItems': apuItems.map((e) => e.toJson()).toList(),
      'notes': notes,
      'especificacionDescripcion': especificacionDescripcion,
      'especificacionMedicion': especificacionMedicion,
      'especificacionPago': especificacionPago,
      'metradoLines': metradoLines.map((e) => e.toJson()).toList(),
      'inicioDia': inicioDia,
      'duracionDias': duracionDias,
      'predecesoraId': predecesoraId,
      'desfaseDias': desfaseDias,
    };
  }

  factory Partida.fromJson(Map<String, dynamic> json) {
    return Partida(
      id: json['id'] as String,
      itemNumber: json['itemNumber'] as String? ?? '',
      description: json['description'] as String,
      isTitle: json['isTitle'] as bool? ?? false,
      level: (json['level'] as num?)?.toInt() ?? 1,
      unit: json['unit'] as String? ?? '',
      metrado: (json['metrado'] as num?)?.toDouble() ?? 0.0,
      rendimiento: (json['rendimiento'] as num?)?.toDouble() ?? 1.0,
      precioUnitario: (json['precioUnitario'] as num?)?.toDouble() ?? 0.0,
      costoParcial: (json['costoParcial'] as num?)?.toDouble() ?? 0.0,
      apuItems: (json['apuItems'] as List<dynamic>?)
              ?.map((e) => ApuItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      notes: json['notes'] as String? ?? '',
      especificacionDescripcion: json['especificacionDescripcion'] as String? ?? '',
      especificacionMedicion: json['especificacionMedicion'] as String? ?? '',
      especificacionPago: json['especificacionPago'] as String? ?? '',
      metradoLines: (json['metradoLines'] as List<dynamic>?)
              ?.map((e) => MetradoLine.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      inicioDia: (json['inicioDia'] as num?)?.toInt() ?? 0,
      duracionDias: (json['duracionDias'] as num?)?.toInt(),
      predecesoraId: json['predecesoraId'] as String?,
      desfaseDias: (json['desfaseDias'] as num?)?.toInt() ?? 0,
    );
  }
}
