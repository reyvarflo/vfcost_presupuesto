enum ResourceType {
  manoDeObra,
  material,
  equipo,
  subcontrato;

  String get displayName {
    switch (this) {
      case ResourceType.manoDeObra:
        return 'Mano de Obra';
      case ResourceType.material:
        return 'Material';
      case ResourceType.equipo:
        return 'Equipo y Maquinaria';
      case ResourceType.subcontrato:
        return 'Subcontrato';
    }
  }

  String get shortCode {
    switch (this) {
      case ResourceType.manoDeObra:
        return 'MO';
      case ResourceType.material:
        return 'MAT';
      case ResourceType.equipo:
        return 'EQ';
      case ResourceType.subcontrato:
        return 'SC';
    }
  }
}

class Resource {
  final String id;
  final String code;
  final String description;
  final String unit;
  final double unitPrice;
  final ResourceType type;
  final int unifiedIndex; // Código de Índice Unificado INEI (ej: 47 Mano de obra, 21 Cemento)
  final String proveedor; // Ej: "PROVEEDOR DISTRITAL", "S10", "PROVIAS"
  final String marca;

  const Resource({
    required this.id,
    required this.code,
    required this.description,
    required this.unit,
    required this.unitPrice,
    required this.type,
    this.unifiedIndex = 0,
    this.proveedor = 'S10',
    this.marca = '',
  });

  Resource copyWith({
    String? id,
    String? code,
    String? description,
    String? unit,
    double? unitPrice,
    ResourceType? type,
    int? unifiedIndex,
    String? proveedor,
    String? marca,
  }) {
    return Resource(
      id: id ?? this.id,
      code: code ?? this.code,
      description: description ?? this.description,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      type: type ?? this.type,
      unifiedIndex: unifiedIndex ?? this.unifiedIndex,
      proveedor: proveedor ?? this.proveedor,
      marca: marca ?? this.marca,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'description': description,
      'unit': unit,
      'unitPrice': unitPrice,
      'type': type.name,
      'unifiedIndex': unifiedIndex,
      'proveedor': proveedor,
      'marca': marca,
    };
  }

  factory Resource.fromJson(Map<String, dynamic> json) {
    return Resource(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      description: json['description'] as String,
      unit: json['unit'] as String,
      unitPrice: (json['unitPrice'] as num).toDouble(),
      type: ResourceType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ResourceType.material,
      ),
      unifiedIndex: (json['unifiedIndex'] as num?)?.toInt() ?? 0,
      proveedor: json['proveedor'] as String? ?? 'S10',
      marca: json['marca'] as String? ?? '',
    );
  }
}
