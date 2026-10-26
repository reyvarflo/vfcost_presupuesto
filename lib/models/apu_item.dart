import 'resource.dart';

class ApuItem {
  final String id;
  final String resourceId;
  final String resourceCode;
  final String resourceDescription;
  final String unit;
  final ResourceType type;
  final int unifiedIndex;
  final double cuadrilla; // Solo aplica para Mano de Obra y Equipos
  final double cantidad; // Aporte unitario (MO/EQ: Cuadrilla*Jornada/Rdto; Mat: aporte directo)
  final double precioUnitario; // Precio del insumo
  final bool isPercentageOfMO; // Caso especial: Herramientas manuales (% de MO)
  final double percentageValue; // ej. 3.0 para 3% o 5.0 para 5%
  final double desperdicio; // % Desperdicio en materiales (ej. 5.0 para 5%)
  final String proveedor; // Ej: "PROVEEDOR DISTRITAL", "S10", "PROVIAS"
  final String marca;

  const ApuItem({
    required this.id,
    required this.resourceId,
    required this.resourceCode,
    required this.resourceDescription,
    required this.unit,
    required this.type,
    this.unifiedIndex = 0,
    this.cuadrilla = 0.0,
    this.cantidad = 0.0,
    required this.precioUnitario,
    this.isPercentageOfMO = false,
    this.percentageValue = 0.0,
    this.desperdicio = 0.0,
    this.proveedor = '',
    this.marca = '',
  });

  /// Proveedor efectivo para mostrar en reportes e interfaz tipo Delphin
  String get effectiveProveedor {
    if (proveedor.isNotEmpty) return proveedor;
    if (type == ResourceType.manoDeObra) return 'PROVEEDOR DISTRITAL';
    return 'S10';
  }

  /// Cantidad efectiva incluyendo desperdicio si aplica
  double get cantidadConDesperdicio => cantidad * (1.0 + (desperdicio / 100.0));

  /// Calcula el costo parcial del insumo en el APU.
  /// Si es porcentaje de MO (ej. Herramientas manuales), depende del subtotal de Mano de Obra.
  double calculateParcial({double subtotalMO = 0.0}) {
    if (isPercentageOfMO) {
      return subtotalMO * (percentageValue / 100.0);
    }
    return cantidadConDesperdicio * precioUnitario;
  }

  ApuItem copyWith({
    String? id,
    String? resourceId,
    String? resourceCode,
    String? resourceDescription,
    String? unit,
    ResourceType? type,
    int? unifiedIndex,
    double? cuadrilla,
    double? cantidad,
    double? precioUnitario,
    bool? isPercentageOfMO,
    double? percentageValue,
    double? desperdicio,
    String? proveedor,
    String? marca,
  }) {
    return ApuItem(
      id: id ?? this.id,
      resourceId: resourceId ?? this.resourceId,
      resourceCode: resourceCode ?? this.resourceCode,
      resourceDescription: resourceDescription ?? this.resourceDescription,
      unit: unit ?? this.unit,
      type: type ?? this.type,
      unifiedIndex: unifiedIndex ?? this.unifiedIndex,
      cuadrilla: cuadrilla ?? this.cuadrilla,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      isPercentageOfMO: isPercentageOfMO ?? this.isPercentageOfMO,
      percentageValue: percentageValue ?? this.percentageValue,
      desperdicio: desperdicio ?? this.desperdicio,
      proveedor: proveedor ?? this.proveedor,
      marca: marca ?? this.marca,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'resourceId': resourceId,
      'resourceCode': resourceCode,
      'resourceDescription': resourceDescription,
      'unit': unit,
      'type': type.name,
      'unifiedIndex': unifiedIndex,
      'cuadrilla': cuadrilla,
      'cantidad': cantidad,
      'precioUnitario': precioUnitario,
      'isPercentageOfMO': isPercentageOfMO,
      'percentageValue': percentageValue,
      'desperdicio': desperdicio,
      'proveedor': proveedor,
      'marca': marca,
    };
  }

  factory ApuItem.fromJson(Map<String, dynamic> json) {
    return ApuItem(
      id: json['id'] as String,
      resourceId: json['resourceId'] as String? ?? '',
      resourceCode: json['resourceCode'] as String? ?? '',
      resourceDescription: json['resourceDescription'] as String,
      unit: json['unit'] as String,
      type: ResourceType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ResourceType.material,
      ),
      unifiedIndex: (json['unifiedIndex'] as num?)?.toInt() ?? 0,
      cuadrilla: (json['cuadrilla'] as num?)?.toDouble() ?? 0.0,
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0.0,
      precioUnitario: (json['precioUnitario'] as num).toDouble(),
      isPercentageOfMO: json['isPercentageOfMO'] as bool? ?? false,
      percentageValue: (json['percentageValue'] as num?)?.toDouble() ?? 0.0,
      desperdicio: (json['desperdicio'] as num?)?.toDouble() ?? 0.0,
      proveedor: json['proveedor'] as String? ?? '',
      marca: json['marca'] as String? ?? '',
    );
  }
}
