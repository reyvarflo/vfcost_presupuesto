class Submonomio {
  final int unifiedIndex; // Código IU (ej: 47, 21, 02)
  final String description; // ej. "Mano de Obra inc. Leyes Sociales"
  final double factor; // Porcentaje dentro del monomio (0.0 a 1.0)

  const Submonomio({
    required this.unifiedIndex,
    required this.description,
    required this.factor,
  });

  Map<String, dynamic> toJson() => {
        'unifiedIndex': unifiedIndex,
        'description': description,
        'factor': factor,
      };

  factory Submonomio.fromJson(Map<String, dynamic> json) => Submonomio(
        unifiedIndex: (json['unifiedIndex'] as num).toInt(),
        description: json['description'] as String,
        factor: (json['factor'] as num).toDouble(),
      );
}

class Monomio {
  final int monomioNumber; // 1, 2, 3... hasta 8
  final String symbol; // ej. "MO", "MAT", "EQ", "GG"
  final double coeficiente; // Factor de ponderación k (ej: 0.285)
  final List<Submonomio> submonomios;

  const Monomio({
    required this.monomioNumber,
    required this.symbol,
    required this.coeficiente,
    required this.submonomios,
  });

  Monomio copyWith({
    int? monomioNumber,
    String? symbol,
    double? coeficiente,
    List<Submonomio>? submonomios,
  }) {
    return Monomio(
      monomioNumber: monomioNumber ?? this.monomioNumber,
      symbol: symbol ?? this.symbol,
      coeficiente: coeficiente ?? this.coeficiente,
      submonomios: submonomios ?? this.submonomios,
    );
  }

  Map<String, dynamic> toJson() => {
        'monomioNumber': monomioNumber,
        'symbol': symbol,
        'coeficiente': coeficiente,
        'submonomios': submonomios.map((e) => e.toJson()).toList(),
      };

  factory Monomio.fromJson(Map<String, dynamic> json) => Monomio(
        monomioNumber: (json['monomioNumber'] as num).toInt(),
        symbol: json['symbol'] as String,
        coeficiente: (json['coeficiente'] as num).toDouble(),
        submonomios: (json['submonomios'] as List<dynamic>?)
                ?.map((e) => Submonomio.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class FormulaPolinomica {
  final List<Monomio> monomios;

  const FormulaPolinomica({
    this.monomios = const [],
  });

  double get sumaCoeficientes =>
      monomios.fold(0.0, (sum, m) => sum + m.coeficiente);

  bool get isValid => (sumaCoeficientes - 1.0).abs() < 0.005;

  Map<String, dynamic> toJson() => {
        'monomios': monomios.map((e) => e.toJson()).toList(),
      };

  factory FormulaPolinomica.fromJson(Map<String, dynamic> json) =>
      FormulaPolinomica(
        monomios: (json['monomios'] as List<dynamic>?)
                ?.map((e) => Monomio.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
