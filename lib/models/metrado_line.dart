/// Línea de la Hoja de Metrados (estilo Delphin Express BIM 360 / S10):
/// Columnas: Descripción | Elementos (veces) | Cant. x Elem. | Largo | Ancho | Alto | Parcial | Plano - Referencia
/// En modo Fierro/Acero: Parcial (kg) = Elementos × Cant. x Elem. × Largo × PesoNominal(kg/m)
class MetradoLine {
  final String id;
  final String descripcion;
  final double veces; // "Elementos"
  final double cantidadPorElemento; // "Cant. x Elem." (default 1.0)
  final double? largo;
  final double? ancho;
  final double? alto;
  final String planoReferencia; // "Plano - Referencia" (ej. "E-01", "Eje A-A")
  final String? diametroAcero; // Si no es nulo, calcula peso en kg según diámetro (ej. '3/8"', '1/2"', '5/8"')

  /// Pesos nominales oficiales del acero corrugado ASTM A615 Grado 60 (kg/m)
  static const Map<String, double> pesosAceroKgPorMetro = {
    '6mm': 0.222,
    '8mm': 0.395,
    '3/8"': 0.560,
    '12mm': 0.888,
    '1/2"': 0.994,
    '5/8"': 1.552,
    '3/4"': 2.235,
    '1"': 3.973,
    '1 3/8"': 7.907,
  };

  const MetradoLine({
    required this.id,
    this.descripcion = '',
    this.veces = 1.0,
    this.cantidadPorElemento = 1.0,
    this.largo,
    this.ancho,
    this.alto,
    this.planoReferencia = '',
    this.diametroAcero,
  });

  double get parcial {
    double r = veces * cantidadPorElemento;
    if (diametroAcero != null && pesosAceroKgPorMetro.containsKey(diametroAcero)) {
      final pesoUnit = pesosAceroKgPorMetro[diametroAcero]!;
      return r * (largo ?? 1.0) * pesoUnit;
    }
    if (largo != null) r *= largo!;
    if (ancho != null) r *= ancho!;
    if (alto != null) r *= alto!;
    return r;
  }

  MetradoLine copyWith({
    String? id,
    String? descripcion,
    double? veces,
    double? cantidadPorElemento,
    double? largo,
    double? ancho,
    double? alto,
    String? planoReferencia,
    String? diametroAcero,
  }) {
    return MetradoLine(
      id: id ?? this.id,
      descripcion: descripcion ?? this.descripcion,
      veces: veces ?? this.veces,
      cantidadPorElemento: cantidadPorElemento ?? this.cantidadPorElemento,
      largo: largo,
      ancho: ancho,
      alto: alto,
      planoReferencia: planoReferencia ?? this.planoReferencia,
      diametroAcero: diametroAcero,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'descripcion': descripcion,
        'veces': veces,
        'cantidadPorElemento': cantidadPorElemento,
        'largo': largo,
        'ancho': ancho,
        'alto': alto,
        'planoReferencia': planoReferencia,
        'diametroAcero': diametroAcero,
      };

  factory MetradoLine.fromJson(Map<String, dynamic> json) => MetradoLine(
        id: json['id'] as String,
        descripcion: json['descripcion'] as String? ?? '',
        veces: (json['veces'] as num?)?.toDouble() ?? 1.0,
        cantidadPorElemento: (json['cantidadPorElemento'] as num?)?.toDouble() ?? 1.0,
        largo: (json['largo'] as num?)?.toDouble(),
        ancho: (json['ancho'] as num?)?.toDouble(),
        alto: (json['alto'] as num?)?.toDouble(),
        planoReferencia: json['planoReferencia'] as String? ?? '',
        diametroAcero: json['diametroAcero'] as String?,
      );
}
