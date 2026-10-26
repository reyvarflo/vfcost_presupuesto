enum TipoGasto {
  fijo,
  variable;

  String get displayName => this == TipoGasto.fijo ? 'Gastos Generales Fijos' : 'Gastos Generales Variables';
}

/// Ítem del desagregado de Gastos Generales.
/// Parcial = Cantidad × Tiempo × Precio × (% Participación / 100)
class GastoGeneralItem {
  final String id;
  final TipoGasto tipo;
  final String descripcion;
  final String unidad;
  final double cantidad;
  final double tiempo;
  final double precio;
  final double participacion;

  const GastoGeneralItem({
    required this.id,
    required this.tipo,
    required this.descripcion,
    this.unidad = 'mes',
    this.cantidad = 1.0,
    this.tiempo = 1.0,
    this.precio = 0.0,
    this.participacion = 100.0,
  });

  double get parcial => cantidad * tiempo * precio * (participacion / 100.0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo': tipo.name,
        'descripcion': descripcion,
        'unidad': unidad,
        'cantidad': cantidad,
        'tiempo': tiempo,
        'precio': precio,
        'participacion': participacion,
      };

  factory GastoGeneralItem.fromJson(Map<String, dynamic> json) => GastoGeneralItem(
        id: json['id'] as String,
        tipo: json['tipo'] == 'fijo' ? TipoGasto.fijo : TipoGasto.variable,
        descripcion: json['descripcion'] as String? ?? '',
        unidad: json['unidad'] as String? ?? 'mes',
        cantidad: (json['cantidad'] as num?)?.toDouble() ?? 1.0,
        tiempo: (json['tiempo'] as num?)?.toDouble() ?? 1.0,
        precio: (json['precio'] as num?)?.toDouble() ?? 0.0,
        participacion: (json['participacion'] as num?)?.toDouble() ?? 100.0,
      );

  /// Plantilla típica de obra de edificación (precios referenciales, editar según la obra).
  static List<GastoGeneralItem> plantilla(double meses, String Function() newId) => [
        GastoGeneralItem(id: newId(), tipo: TipoGasto.fijo, descripcion: 'ELABORACIÓN DE PROPUESTA / EXPEDIENTE', unidad: 'glb', precio: 1500),
        GastoGeneralItem(id: newId(), tipo: TipoGasto.fijo, descripcion: 'CARTA FIANZA DE FIEL CUMPLIMIENTO', unidad: 'glb', precio: 2500),
        GastoGeneralItem(id: newId(), tipo: TipoGasto.fijo, descripcion: 'PÓLIZAS DE SEGURO (SCTR, CAR)', unidad: 'glb', precio: 1800),
        GastoGeneralItem(id: newId(), tipo: TipoGasto.fijo, descripcion: 'MOVILIZACIÓN Y DESMOVILIZACIÓN', unidad: 'glb', precio: 2000),
        GastoGeneralItem(id: newId(), tipo: TipoGasto.fijo, descripcion: 'LIQUIDACIÓN DE OBRA', unidad: 'glb', precio: 1200),
        GastoGeneralItem(id: newId(), tipo: TipoGasto.variable, descripcion: 'INGENIERO RESIDENTE', tiempo: meses, precio: 9000),
        GastoGeneralItem(id: newId(), tipo: TipoGasto.variable, descripcion: 'MAESTRO DE OBRA', tiempo: meses, precio: 4500),
        GastoGeneralItem(id: newId(), tipo: TipoGasto.variable, descripcion: 'ALMACENERO', tiempo: meses, precio: 2200),
        GastoGeneralItem(id: newId(), tipo: TipoGasto.variable, descripcion: 'GUARDIÁN', tiempo: meses, precio: 1800),
        GastoGeneralItem(id: newId(), tipo: TipoGasto.variable, descripcion: 'ENSAYOS DE LABORATORIO', unidad: 'glb', precio: 1500),
        GastoGeneralItem(id: newId(), tipo: TipoGasto.variable, descripcion: 'ÚTILES DE OFICINA Y COMUNICACIONES', tiempo: meses, precio: 300),
        GastoGeneralItem(id: newId(), tipo: TipoGasto.variable, descripcion: 'ALQUILER DE ALMACÉN / CASETA', tiempo: meses, precio: 800),
      ];
}
