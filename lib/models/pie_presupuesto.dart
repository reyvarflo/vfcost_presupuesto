class PiePresupuesto {
  final double porcentajeGGFijos; // ej: 3.0 (%)
  final double porcentajeGGVariables; // ej: 7.0 (%)
  final double porcentajeUtilidad; // ej: 8.0 (%)
  final double porcentajeIGV; // ej: 18.0 (%)
  final bool aplicarIGV;

  const PiePresupuesto({
    this.porcentajeGGFijos = 3.0,
    this.porcentajeGGVariables = 7.0,
    this.porcentajeUtilidad = 8.0,
    this.porcentajeIGV = 18.0,
    this.aplicarIGV = true,
  });

  double get porcentajeGGTotal => porcentajeGGFijos + porcentajeGGVariables;

  double calcularGGFijos(double costoDirecto) =>
      costoDirecto * (porcentajeGGFijos / 100.0);

  double calcularGGVariables(double costoDirecto) =>
      costoDirecto * (porcentajeGGVariables / 100.0);

  double calcularGGTotal(double costoDirecto) =>
      costoDirecto * (porcentajeGGTotal / 100.0);

  double calcularUtilidad(double costoDirecto) =>
      costoDirecto * (porcentajeUtilidad / 100.0);

  double calcularSubtotal(double costoDirecto) =>
      costoDirecto + calcularGGTotal(costoDirecto) + calcularUtilidad(costoDirecto);

  double calcularIGV(double costoDirecto) {
    if (!aplicarIGV) return 0.0;
    return calcularSubtotal(costoDirecto) * (porcentajeIGV / 100.0);
  }

  double calcularTotalPresupuesto(double costoDirecto) {
    return calcularSubtotal(costoDirecto) + calcularIGV(costoDirecto);
  }

  PiePresupuesto copyWith({
    double? porcentajeGGFijos,
    double? porcentajeGGVariables,
    double? porcentajeUtilidad,
    double? porcentajeIGV,
    bool? aplicarIGV,
  }) {
    return PiePresupuesto(
      porcentajeGGFijos: porcentajeGGFijos ?? this.porcentajeGGFijos,
      porcentajeGGVariables: porcentajeGGVariables ?? this.porcentajeGGVariables,
      porcentajeUtilidad: porcentajeUtilidad ?? this.porcentajeUtilidad,
      porcentajeIGV: porcentajeIGV ?? this.porcentajeIGV,
      aplicarIGV: aplicarIGV ?? this.aplicarIGV,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'porcentajeGGFijos': porcentajeGGFijos,
      'porcentajeGGVariables': porcentajeGGVariables,
      'porcentajeUtilidad': porcentajeUtilidad,
      'porcentajeIGV': porcentajeIGV,
      'aplicarIGV': aplicarIGV,
    };
  }

  factory PiePresupuesto.fromJson(Map<String, dynamic> json) {
    return PiePresupuesto(
      porcentajeGGFijos: (json['porcentajeGGFijos'] as num?)?.toDouble() ?? 3.0,
      porcentajeGGVariables: (json['porcentajeGGVariables'] as num?)?.toDouble() ?? 7.0,
      porcentajeUtilidad: (json['porcentajeUtilidad'] as num?)?.toDouble() ?? 8.0,
      porcentajeIGV: (json['porcentajeIGV'] as num?)?.toDouble() ?? 18.0,
      aplicarIGV: json['aplicarIGV'] as bool? ?? true,
    );
  }
}
