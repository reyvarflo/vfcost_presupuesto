/// Valorización mensual de obra: metrados ejecutados en el periodo por partida
/// e índices unificados del mes para el reajuste por fórmula polinómica.
class Valorizacion {
  final String id;
  final int numero;
  final String periodo;
  final DateTime fechaCorte;
  final Map<String, double> avances; // partidaId -> metrado ejecutado en el periodo
  final Map<int, double> indicesActuales; // IU -> índice del mes (Ir)

  const Valorizacion({
    required this.id,
    required this.numero,
    required this.periodo,
    required this.fechaCorte,
    this.avances = const {},
    this.indicesActuales = const {},
  });

  Valorizacion copyWith({
    String? periodo,
    DateTime? fechaCorte,
    Map<String, double>? avances,
    Map<int, double>? indicesActuales,
  }) {
    return Valorizacion(
      id: id,
      numero: numero,
      periodo: periodo ?? this.periodo,
      fechaCorte: fechaCorte ?? this.fechaCorte,
      avances: avances ?? this.avances,
      indicesActuales: indicesActuales ?? this.indicesActuales,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'numero': numero,
        'periodo': periodo,
        'fechaCorte': fechaCorte.toIso8601String(),
        'avances': avances,
        'indicesActuales': indicesActuales.map((k, v) => MapEntry(k.toString(), v)),
      };

  factory Valorizacion.fromJson(Map<String, dynamic> json) => Valorizacion(
        id: json['id'] as String,
        numero: (json['numero'] as num).toInt(),
        periodo: json['periodo'] as String? ?? '',
        fechaCorte: DateTime.tryParse(json['fechaCorte'] as String? ?? '') ?? DateTime.now(),
        avances: (json['avances'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
            {},
        indicesActuales: (json['indicesActuales'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(int.parse(k), (v as num).toDouble())) ??
            {},
      );
}
