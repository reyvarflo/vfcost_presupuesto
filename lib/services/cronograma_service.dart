import 'package:intl/intl.dart';
import '../models/partida.dart';
import '../models/presupuesto.dart';
import '../models/subpresupuesto.dart';

class TareaProgramada {
  final Partida partida;
  final String subNombre;
  final int subIndex;
  final int inicio;
  final int duracion;

  TareaProgramada({
    required this.partida,
    required this.subNombre,
    required this.subIndex,
    required this.inicio,
    required this.duracion,
  });

  int get fin => inicio + duracion;
  double get costo => partida.costoParcial;
}

class PeriodoValorizado {
  final int numero;
  final int diaInicio;
  final int diaFin;
  final String etiqueta;
  final double monto;
  final Map<String, double> porPartida;
  double acumulado = 0;
  double pct = 0;
  double pctAcum = 0;

  PeriodoValorizado({
    required this.numero,
    required this.diaInicio,
    required this.diaFin,
    required this.etiqueta,
    required this.monto,
    required this.porPartida,
  });
}

class CronogramaService {
  /// Programa todas las partidas con relaciones Fin-Inicio y desfases.
  static List<TareaProgramada> programar(Presupuesto p) {
    final hojas = <Partida>[];
    final subDe = <String, int>{};
    for (var s = 0; s < p.subpresupuestos.length; s++) {
      for (final pa in p.subpresupuestos[s].partidas) {
        if (!pa.isTitle) {
          hojas.add(pa);
          subDe[pa.id] = s;
        }
      }
    }
    final porId = {for (final h in hojas) h.id: h};
    final memo = <String, int>{};

    int inicioDe(Partida pa, Set<String> visitando) {
      final cached = memo[pa.id];
      if (cached != null) return cached;
      int inicio = pa.inicioDia;
      final pred = pa.predecesoraId != null ? porId[pa.predecesoraId] : null;
      if (pred != null && !visitando.contains(pred.id)) {
        visitando.add(pa.id);
        inicio = inicioDe(pred, visitando) + pred.duracionCalculada + pa.desfaseDias;
        visitando.remove(pa.id);
      }
      if (inicio < 0) inicio = 0;
      memo[pa.id] = inicio;
      return inicio;
    }

    return hojas
        .map((h) => TareaProgramada(
              partida: h,
              subNombre: p.subpresupuestos[subDe[h.id]!].name,
              subIndex: subDe[h.id]!,
              inicio: inicioDe(h, <String>{}),
              duracion: h.duracionCalculada,
            ))
        .toList();
  }

  static int plazo(List<TareaProgramada> tareas) =>
      tareas.fold(0, (m, t) => t.fin > m ? t.fin : m);

  /// Cronograma valorizado: distribuye el costo de cada partida uniformemente en su duración.
  static List<PeriodoValorizado> valorizar(
    List<TareaProgramada> tareas,
    int diasPeriodo,
    DateTime inicioObra, {
    double factor = 1.0,
  }) {
    final total = plazo(tareas);
    final n = total <= 0 ? 1 : (total / diasPeriodo).ceil();
    final df = DateFormat('dd/MM/yy');
    final periodos = <PeriodoValorizado>[];
    for (var i = 0; i < n; i++) {
      final pIni = i * diasPeriodo;
      final pFin = pIni + diasPeriodo;
      final porPartida = <String, double>{};
      double monto = 0;
      for (final t in tareas) {
        final ini = t.inicio > pIni ? t.inicio : pIni;
        final fin = t.fin < pFin ? t.fin : pFin;
        final overlap = fin - ini;
        if (overlap > 0 && t.duracion > 0) {
          final v = t.costo * factor * overlap / t.duracion;
          porPartida[t.partida.id] = v;
          monto += v;
        }
      }
      final nombre = diasPeriodo == 30 ? 'Mes' : (diasPeriodo == 15 ? 'Quincena' : 'Semana');
      periodos.add(PeriodoValorizado(
        numero: i + 1,
        diaInicio: pIni,
        diaFin: pFin,
        etiqueta:
            '$nombre ${i + 1} (${df.format(inicioObra.add(Duration(days: pIni)))} - ${df.format(inicioObra.add(Duration(days: pFin - 1)))})',
        monto: monto,
        porPartida: porPartida,
      ));
    }
    final suma = periodos.fold(0.0, (s, p) => s + p.monto);
    double acc = 0;
    for (final p in periodos) {
      acc += p.monto;
      p.acumulado = acc;
      p.pct = suma > 0 ? p.monto / suma * 100 : 0;
      p.pctAcum = suma > 0 ? acc / suma * 100 : 0;
    }
    return periodos;
  }

  /// Encadena todas las partidas en secuencia (Fin-Inicio) en el orden del presupuesto.
  static List<Subpresupuesto> encadenar(List<Subpresupuesto> subs) {
    String? prev;
    return subs.map((s) {
      final nuevas = s.partidas.map((pa) {
        if (pa.isTitle) return pa;
        final r = prev == null
            ? pa.copyWith(clearPredecesora: true, inicioDia: 0, desfaseDias: 0)
            : pa.copyWith(predecesoraId: prev, desfaseDias: 0);
        prev = pa.id;
        return r;
      }).toList();
      return s.copyWith(partidas: nuevas);
    }).toList();
  }
}
