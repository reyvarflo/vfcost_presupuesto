import 'partida.dart';

class Subpresupuesto {
  final String id;
  final String code; // ej. "001"
  final String name; // ej. "ESTRUCTURAS"
  final List<Partida> partidas;
  final double costoDirecto;

  const Subpresupuesto({
    required this.id,
    required this.code,
    required this.name,
    this.partidas = const [],
    this.costoDirecto = 0.0,
  });

  /// Recalcula los costos parciales de las partidas y el costo directo total del subpresupuesto
  Subpresupuesto processSubpresupuesto(double jornada) {
    if (partidas.isEmpty) {
      return copyWith(costoDirecto: 0.0);
    }

    // Paso 1: Recalcular precios unitarios y parciales de partidas hoja
    final updatedList = partidas.map((p) {
      if (!p.isTitle) {
        return p.recalculateWithJornada(jornada);
      }
      return p;
    }).toList();

    // Paso 2: Calcular el subtotal para cada título jerárquico (hacia arriba)
    final finalList = <Partida>[];
    for (int i = 0; i < updatedList.length; i++) {
      final current = updatedList[i];
      if (current.isTitle) {
        // Sumar todos los hijos no-título bajo este nivel hasta el siguiente elemento de nivel <= actual
        double titleSum = 0.0;
        for (int j = i + 1; j < updatedList.length; j++) {
          final next = updatedList[j];
          if (next.level <= current.level) {
            break; // Salió de la rama
          }
          if (!next.isTitle) {
            titleSum += next.costoParcial;
          }
        }
        finalList.add(current.copyWith(costoParcial: titleSum));
      } else {
        finalList.add(current);
      }
    }

    // Paso 3: Calcular Costo Directo Total (suma de todas las partidas hoja)
    final totalCD = finalList
        .where((p) => !p.isTitle)
        .fold(0.0, (sum, p) => sum + p.costoParcial);

    return copyWith(
      partidas: finalList,
      costoDirecto: totalCD,
    );
  }

  Subpresupuesto copyWith({
    String? id,
    String? code,
    String? name,
    List<Partida>? partidas,
    double? costoDirecto,
  }) {
    return Subpresupuesto(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      partidas: partidas ?? this.partidas,
      costoDirecto: costoDirecto ?? this.costoDirecto,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'partidas': partidas.map((e) => e.toJson()).toList(),
      'costoDirecto': costoDirecto,
    };
  }

  factory Subpresupuesto.fromJson(Map<String, dynamic> json) {
    return Subpresupuesto(
      id: json['id'] as String,
      code: json['code'] as String? ?? '001',
      name: json['name'] as String,
      partidas: (json['partidas'] as List<dynamic>?)
              ?.map((e) => Partida.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      costoDirecto: (json['costoDirecto'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
