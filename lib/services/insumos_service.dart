import '../models/apu_item.dart';
import '../models/resource.dart';
import '../models/subpresupuesto.dart';

class InsumoConsolidado {
  final String key;
  final String code;
  final String descripcion;
  final String unidad;
  final ResourceType tipo;
  final int iu;
  final bool esPorcentajeMO;
  double cantidad;
  double parcial;

  InsumoConsolidado({
    required this.key,
    required this.code,
    required this.descripcion,
    required this.unidad,
    required this.tipo,
    required this.iu,
    required this.esPorcentajeMO,
    this.cantidad = 0.0,
    this.parcial = 0.0,
  });

  /// Precio promedio ponderado del insumo en el presupuesto
  double get precio => cantidad > 0 ? parcial / cantidad : 0.0;
}

class InsumosService {
  /// Llave única de un insumo dentro del presupuesto
  static String keyOf(ApuItem a) =>
      a.resourceId.isNotEmpty ? a.resourceId : '${a.resourceCode}|${a.resourceDescription}';

  /// Relación de insumos: Σ (metrado de partida × aporte unitario del APU).
  /// La suma de parciales coincide con el Costo Directo.
  static List<InsumoConsolidado> consolidar(Iterable<Subpresupuesto> subs) {
    final map = <String, InsumoConsolidado>{};
    for (final sub in subs) {
      for (final partida in sub.partidas) {
        if (partida.isTitle) continue;
        final m = partida.metradoEfectivo;
        final subMO = partida.subtotalMO;
        for (final apu in partida.apuItems) {
          final key = keyOf(apu);
          final entry = map.putIfAbsent(
            key,
            () => InsumoConsolidado(
              key: key,
              code: apu.resourceCode,
              descripcion: apu.resourceDescription,
              unidad: apu.unit,
              tipo: apu.type,
              iu: apu.unifiedIndex,
              esPorcentajeMO: apu.isPercentageOfMO,
            ),
          );
          entry.parcial += apu.calculateParcial(subtotalMO: subMO) * m;
          if (!apu.isPercentageOfMO) entry.cantidad += apu.cantidad * m;
        }
      }
    }
    final list = map.values.toList()
      ..sort((a, b) {
        final t = a.tipo.index.compareTo(b.tipo.index);
        return t != 0 ? t : a.descripcion.compareTo(b.descripcion);
      });
    return list;
  }
}
