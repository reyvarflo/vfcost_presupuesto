import '../models/partida.dart';
import '../models/presupuesto.dart';
import '../models/valorizacion.dart';
import 'formula_service.dart';

class LineaValorizacion {
  final Partida partida;
  final String subNombre;
  final double contratado;
  final double anterior;
  final double actual;

  LineaValorizacion({
    required this.partida,
    required this.subNombre,
    required this.contratado,
    required this.anterior,
    required this.actual,
  });

  double get acumulado => anterior + actual;
  double get saldo => contratado - acumulado;
  double get pctAcumulado => contratado > 0 ? acumulado / contratado * 100 : 0;
  double get pu => partida.precioUnitario;
  double get montoContratado => contratado * pu;
  double get montoAnterior => anterior * pu;
  double get montoActual => actual * pu;
  double get montoAcumulado => acumulado * pu;
  double get montoSaldo => saldo * pu;
}

class ResumenValorizacion {
  final List<LineaValorizacion> lineas;
  final double cdContratado;
  final double cdAnterior;
  final double cdActual;
  final double ggActual;
  final double utilidadActual;
  final double k;
  final double reajuste;
  final double igvActual;
  final bool aplicaIGV;

  ResumenValorizacion({
    required this.lineas,
    required this.cdContratado,
    required this.cdAnterior,
    required this.cdActual,
    required this.ggActual,
    required this.utilidadActual,
    required this.k,
    required this.reajuste,
    required this.igvActual,
    required this.aplicaIGV,
  });

  double get cdAcumulado => cdAnterior + cdActual;
  double get subtotalActual => cdActual + ggActual + utilidadActual;
  double get totalActual => subtotalActual + reajuste + igvActual;
  double get pctActual => cdContratado > 0 ? cdActual / cdContratado * 100 : 0;
  double get pctAcumulado => cdContratado > 0 ? cdAcumulado / cdContratado * 100 : 0;
}

class ValorizacionService {
  static ResumenValorizacion calcular(Presupuesto p, Valorizacion v) {
    final anteriores = p.valorizaciones.where((x) => x.numero < v.numero).toList();
    final lineas = <LineaValorizacion>[];
    for (final sub in p.subpresupuestos) {
      for (final pa in sub.partidas) {
        if (pa.isTitle) continue;
        final ant = anteriores.fold(0.0, (s, x) => s + (x.avances[pa.id] ?? 0));
        lineas.add(LineaValorizacion(
          partida: pa,
          subNombre: '${sub.code} ${sub.name}',
          contratado: pa.metrado,
          anterior: ant,
          actual: v.avances[pa.id] ?? 0,
        ));
      }
    }
    final pie = p.piePresupuesto;
    final cdAct = lineas.fold(0.0, (s, l) => s + l.montoActual);
    final gg = pie.calcularGGTotal(cdAct);
    final ut = pie.calcularUtilidad(cdAct);
    final k = FormulaService.calcularK(p.formulaPolinomica, p.indicesBase, v.indicesActuales);
    final reajuste = (cdAct + gg + ut) * (k - 1.0);
    final igv = pie.aplicarIGV ? (cdAct + gg + ut + reajuste) * pie.porcentajeIGV / 100 : 0.0;

    return ResumenValorizacion(
      lineas: lineas,
      cdContratado: lineas.fold(0.0, (s, l) => s + l.montoContratado),
      cdAnterior: lineas.fold(0.0, (s, l) => s + l.montoAnterior),
      cdActual: cdAct,
      ggActual: gg,
      utilidadActual: ut,
      k: k,
      reajuste: reajuste,
      igvActual: igv,
      aplicaIGV: pie.aplicarIGV,
    );
  }
}
