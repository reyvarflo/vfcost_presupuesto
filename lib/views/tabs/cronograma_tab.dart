import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/partida.dart';
import '../../models/resource.dart';
import '../../models/subpresupuesto.dart';
import '../../providers/presupuesto_provider.dart';
import '../../services/cronograma_service.dart';

class CronogramaTab extends StatefulWidget {
  const CronogramaTab({super.key});

  @override
  State<CronogramaTab> createState() => _CronogramaTabState();
}

class _CronogramaTabState extends State<CronogramaTab> {
  final _currencyFormat = NumberFormat('#,##0.00', 'es_PE');
  final _qtyFormat = NumberFormat('#,##0.0000', 'es_PE');

  /// 0 = Diagrama Gantt
  /// 1 = Calendario Valorizado (Imagen 7 Delphin)
  /// 2 = Calendario de Adquisiciones de Insumos (Imagen 6 Delphin)
  /// 3 = Resumen de Costos por Rubro MO/MAT/EQ (Imagen 8 Delphin)
  /// 4 = Curva S
  int _viewMode = 1;
  final int _diasPorPeriodo = 30;
  String _selectedProveedor = 'TODOS';

  void _openTaskEditDialog(BuildContext context, Partida partida, List<Partida> todasPartidas) {
    final provider = context.read<PresupuestoProvider>();
    final duracionCtrl = TextEditingController(text: partida.duracionCalculada.toString());
    final desfaseCtrl = TextEditingController(text: partida.desfaseDias.toString());
    String? selectedPredecesora = partida.predecesoraId;

    final candidatas = todasPartidas.where((p) => !p.isTitle && p.id != partida.id).toList();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              title: Text(
                'Programación: ${partida.itemNumber}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partida.description,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rendimiento: ${partida.rendimiento} ${partida.unit}/día  •  Metrado: ${partida.metradoEfectivo} ${partida.unit}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                    const Divider(height: 16),
                    TextField(
                      controller: duracionCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duración (días hábiles)',
                        hintText: 'ej. 5',
                        border: OutlineInputBorder(),
                        isDense: true,
                        helperText: 'Por defecto: Metrado / Rendimiento',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: selectedPredecesora,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Partida Predecesora (Fin-Inicio)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Ninguna (Inicio de Obra)', style: TextStyle(fontSize: 12)),
                        ),
                        ...candidatas.map((p) => DropdownMenuItem<String?>(
                              value: p.id,
                              child: Text(
                                '${p.itemNumber} ${p.description}',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                      ],
                      onChanged: (val) {
                        setDlgState(() => selectedPredecesora = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: desfaseCtrl,
                      keyboardType: const TextInputType.numberWithOptions(signed: true),
                      decoration: const InputDecoration(
                        labelText: 'Desfase / Lag (días)',
                        hintText: '0',
                        border: OutlineInputBorder(),
                        isDense: true,
                        helperText: '0 = inicio inmediato al terminar la anterior',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final d = int.tryParse(duracionCtrl.text);
                    final lag = int.tryParse(desfaseCtrl.text) ?? 0;
                    provider.updatePartidaProgramacion(
                      partidaId: partida.id,
                      duracionDiasManual: d,
                      predecesoraId: selectedPredecesora,
                      clearPredecesora: selectedPredecesora == null,
                      desfaseDias: lag,
                    );
                    Navigator.pop(ctx);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<PresupuestoProvider>();
    final presupuesto = provider.activePresupuesto;
    final activeSub = provider.activeSubpresupuesto;

    if (presupuesto == null || activeSub == null) {
      return const Center(child: Text('No hay presupuesto activo'));
    }

    final currency = presupuesto.currencySymbol;
    final tareas = CronogramaService.programar(presupuesto);
    final plazoTotal = CronogramaService.plazo(tareas);
    final periodos = CronogramaService.valorizar(
      tareas,
      _diasPorPeriodo,
      presupuesto.date,
    );

    final todasPartidas = <Partida>[];
    for (final s in presupuesto.subpresupuestos) {
      todasPartidas.addAll(s.partidas);
    }

    return Column(
      children: [
        // Barra Superior Estilo Ribbon de Delphin Express:
        // Selector de las 5 vistas de Planificación y Costos
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFDCE6F2),
            border: Border(bottom: BorderSide(color: Color(0xFF94A3B8))),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, size: 17, color: Color(0xFF1E3A8A)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Plazo Programado: $plazoTotal días (${(plazoTotal / 30).ceil()} mes(es))',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                    icon: const Icon(Icons.auto_mode, size: 15),
                    label: const Text('Secuenciar Fin-Inicio', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      provider.autoSecuenciarPartidas();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Partidas encadenadas automáticamente en secuencia Fin-Inicio.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildDelphinRibbonButton(
                      index: 1,
                      icon: Icons.event_note_outlined,
                      label: 'Calendario Valorizado',
                    ),
                    const SizedBox(width: 6),
                    _buildDelphinRibbonButton(
                      index: 2,
                      icon: Icons.shopping_cart_checkout_outlined,
                      label: 'Calendario de Adquisiciones',
                    ),
                    const SizedBox(width: 6),
                    _buildDelphinRibbonButton(
                      index: 3,
                      icon: Icons.summarize_outlined,
                      label: 'Resumen de Costos (MO/MAT/EQ)',
                    ),
                    const SizedBox(width: 6),
                    _buildDelphinRibbonButton(
                      index: 0,
                      icon: Icons.view_timeline_outlined,
                      label: 'Diagrama Gantt (CPM)',
                    ),
                    const SizedBox(width: 6),
                    _buildDelphinRibbonButton(
                      index: 4,
                      icon: Icons.show_chart,
                      label: 'Curva S',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Cuerpo según la vista seleccionada
        Expanded(
          child: switch (_viewMode) {
            1 => _buildCalendarioValorizadoDelphin(activeSub, periodos, presupuesto.date, currency),
            2 => _buildCalendarioAdquisicionesDelphin(activeSub, periodos, presupuesto.date, currency),
            3 => _buildResumenCostosPorRubroDelphin(activeSub, currency),
            4 => _buildCurvaSView(theme, periodos, currency),
            _ => _buildGanttView(theme, tareas, plazoTotal, todasPartidas, currency),
          },
        ),
      ],
    );
  }

  Widget _buildDelphinRibbonButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = _viewMode == index;
    return InkWell(
      onTap: () => setState(() => _viewMode = index),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1E3A8A) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? const Color(0xFF1E3A8A) : const Color(0xFF94A3B8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: selected ? Colors.amber.shade300 : const Color(0xFF1E3A8A)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // VISTA 1: CALENDARIO VALORIZADO DE OBRA (Imagen 7 de Delphin)
  // ===========================================================================
  Widget _buildCalendarioValorizadoDelphin(
    Subpresupuesto sub,
    List<PeriodoValorizado> periodos,
    DateTime inicioObra,
    String currency,
  ) {
    final df = DateFormat('dd/MM/yyyy');
    final partidas = sub.partidas;

    // Función que devuelve el monto valorizado de una partida o título en el periodo p
    double montoEnPeriodo(Partida row, PeriodoValorizado p) {
      if (!row.isTitle) {
        return p.porPartida[row.id] ?? 0.0;
      }
      final prefix = '${row.itemNumber}.';
      double sum = 0.0;
      for (final child in partidas) {
        if (!child.isTitle && child.itemNumber.startsWith(prefix)) {
          sum += p.porPartida[child.id] ?? 0.0;
        }
      }
      return sum;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 556.0 + (periodos.length * 130.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera de columnas estilo Delphin (Imagen 7)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFFE2E8F0),
                border: Border(bottom: BorderSide(color: Color(0xFF94A3B8))),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 280,
                    child: Text('Descripción', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(
                    width: 85,
                    child: Text('Metrado', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(
                    width: 75,
                    child: Text('Precio U...', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(
                    width: 90,
                    child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  ...periodos.map((p) {
                    final fIni = df.format(inicioObra.add(Duration(days: p.diaInicio)));
                    final fFin = df.format(inicioObra.add(Duration(days: p.diaFin - 1)));
                    return SizedBox(
                      width: 130,
                      child: Column(
                        children: [
                          Text('Mes ${p.numero}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          Text('Del $fIni', style: const TextStyle(fontSize: 9, color: Color(0xFF475569))),
                          Text('Al  $fFin', style: const TextStyle(fontSize: 9, color: Color(0xFF475569))),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Fila Raíz del Subpresupuesto (En rojo intenso como en Imagen 7: "01 CERCO PERIMETRICO 603,629.15 | 536,637.13 | 66,992.02")
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFFEDF2F8),
                border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 280,
                    child: Text(
                      '▼ ${sub.code}  ${sub.name.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                    ),
                  ),
                  const SizedBox(width: 85),
                  const SizedBox(width: 75),
                  SizedBox(
                    width: 90,
                    child: Text(
                      _currencyFormat.format(sub.costoDirecto),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                    ),
                  ),
                  ...periodos.map((p) {
                    final totalMesSub = partidas
                        .where((pa) => !pa.isTitle)
                        .fold(0.0, (s, pa) => s + (p.porPartida[pa.id] ?? 0.0));
                    return SizedBox(
                      width: 130,
                      child: Text(
                        totalMesSub > 0 ? _currencyFormat.format(totalMesSub) : '',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Filas de Títulos (en azul) y Partidas (en negro)
            Expanded(
              child: ListView.builder(
                itemCount: partidas.length,
                itemBuilder: (context, idx) {
                  final row = partidas[idx];
                  final isTitle = row.isTitle;
                  final rowColor = isTitle ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A);
                  final indent = (row.level - 1) * 10.0;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
                    decoration: BoxDecoration(
                      color: isTitle
                          ? const Color(0xFFF8FAFC)
                          : (idx.isEven ? Colors.white : const Color(0xFFFCFDFF)),
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.7)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 280,
                          child: Padding(
                            padding: EdgeInsets.only(left: indent),
                            child: Text(
                              '${isTitle ? "▼ " : ""}${row.itemNumber}  ${row.description}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: isTitle ? FontWeight.bold : FontWeight.w500,
                                color: rowColor,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 85,
                          child: isTitle
                              ? const SizedBox.shrink()
                              : RichText(
                                  textAlign: TextAlign.right,
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF0F172A)),
                                    children: [
                                      TextSpan(text: '${_currencyFormat.format(row.metradoEfectivo)} '),
                                      TextSpan(
                                        text: row.unit,
                                        style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        SizedBox(
                          width: 75,
                          child: Text(
                            isTitle ? '' : _currencyFormat.format(row.precioUnitario),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 10.5),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text(
                            _currencyFormat.format(row.costoParcial),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: isTitle ? FontWeight.bold : FontWeight.w600,
                              color: rowColor,
                            ),
                          ),
                        ),
                        ...periodos.map((p) {
                          final v = montoEnPeriodo(row, p);
                          return SizedBox(
                            width: 130,
                            child: Text(
                              v > 0.005 ? _currencyFormat.format(v) : '',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: isTitle ? FontWeight.bold : FontWeight.normal,
                                color: rowColor,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // VISTA 2: CALENDARIO DE ADQUISICIONES DE INSUMOS POR MES (Imagen 6 de Delphin)
  // ===========================================================================
  Widget _buildCalendarioAdquisicionesDelphin(
    Subpresupuesto sub,
    List<PeriodoValorizado> periodos,
    DateTime inicioObra,
    String currency,
  ) {
    final df = DateFormat('dd/MM/yyyy');

    // Construir lista de proveedores disponibles para el filtro superior
    final proveedoresSet = <String>{'TODOS'};
    for (final pa in sub.partidas) {
      if (pa.isTitle) continue;
      for (final apu in pa.apuItems) {
        proveedoresSet.add(apu.effectiveProveedor);
      }
    }
    if (!proveedoresSet.contains(_selectedProveedor)) {
      _selectedProveedor = 'TODOS';
    }

    // Consolidar cada insumo con sus cantidades y montos en cada periodo (Mes 1..N)
    final insumoMap = <String, Map<String, dynamic>>{};

    for (final pa in sub.partidas) {
      if (pa.isTitle || pa.metradoEfectivo <= 0 || pa.costoParcial <= 0) continue;

      final moUnit = pa.subtotalMO;
      for (final apu in pa.apuItems) {
        if (_selectedProveedor != 'TODOS' && apu.effectiveProveedor != _selectedProveedor) {
          continue;
        }
        final key = '${apu.type.name}_${apu.resourceDescription.trim().toUpperCase()}';
        final double cantTotalPartida = apu.isPercentageOfMO
            ? (apu.percentageValue / 100.0) * pa.metradoEfectivo
            : apu.cantidadConDesperdicio * pa.metradoEfectivo;
        final double precioEfectivo = apu.isPercentageOfMO ? moUnit : apu.precioUnitario;
        final double costoTotalPartida = cantTotalPartida * precioEfectivo;

        if (!insumoMap.containsKey(key)) {
          insumoMap[key] = {
            'tipo': apu.type,
            'descripcion': apu.resourceDescription,
            'unidad': apu.isPercentageOfMO ? '%mo' : apu.unit,
            'precio': precioEfectivo,
            'cantTotal': 0.0,
            'parcialTotal': 0.0,
            'cantPorMes': <int, double>{},
            'parcialPorMes': <int, double>{},
          };
        }

        final entry = insumoMap[key]!;
        entry['cantTotal'] = (entry['cantTotal'] as double) + cantTotalPartida;
        entry['parcialTotal'] = (entry['parcialTotal'] as double) + costoTotalPartida;

        final cantPorMes = entry['cantPorMes'] as Map<int, double>;
        final parcialPorMes = entry['parcialPorMes'] as Map<int, double>;

        for (final per in periodos) {
          final montoPartidaMes = per.porPartida[pa.id] ?? 0.0;
          if (montoPartidaMes > 0) {
            final ratioMes = (montoPartidaMes / pa.costoParcial).clamp(0.0, 1.0);
            cantPorMes[per.numero] = (cantPorMes[per.numero] ?? 0.0) + (cantTotalPartida * ratioMes);
            parcialPorMes[per.numero] = (parcialPorMes[per.numero] ?? 0.0) + (costoTotalPartida * ratioMes);
          }
        }
      }
    }

    // Agrupar por ResourceType: MANO DE OBRA, MATERIALES, EQUIPO, SUBCONTRATOS
    final grouped = <ResourceType, List<Map<String, dynamic>>>{
      ResourceType.manoDeObra: [],
      ResourceType.material: [],
      ResourceType.equipo: [],
      ResourceType.subcontrato: [],
    };
    for (final item in insumoMap.values) {
      grouped[item['tipo'] as ResourceType]!.add(item);
    }
    for (final k in grouped.keys) {
      grouped[k]!.sort((a, b) => (a['descripcion'] as String).compareTo(b['descripcion'] as String));
    }

    final grandTotal = insumoMap.values.fold(0.0, (s, e) => s + (e['parcialTotal'] as double));

    return Column(
      children: [
        // Barra de filtro "Proveedor: (Todos)" estilo Imagen 6
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: const BoxDecoration(
            color: Color(0xFFEDF2F8),
            border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
          ),
          child: Row(
            children: [
              const Text('Proveedor: ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blueGrey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedProveedor,
                    isDense: true,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A)),
                    items: proveedoresSet
                        .map((prov) => DropdownMenuItem(
                              value: prov,
                              child: Text(prov == 'TODOS' ? '(Todos)' : prov),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedProveedor = v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Total Adquisiciones: $currency ${_currencyFormat.format(grandTotal)}',
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                ),
              ),
            ],
          ),
        ),

        // Tabla desplazable horizontalmente con columnas por Mes (Cantidad | Parcial S/) y Total (Cantidad | Parcial S/)
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 404.0 + (periodos.length * 165.0) + 165.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabecera de 2 niveles (Imagen 6)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE2E8F0),
                      border: Border(bottom: BorderSide(color: Color(0xFF94A3B8))),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 260,
                          child: Text('Tipo / Descripción', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(
                          width: 48,
                          child: Text('Unidad', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(
                          width: 72,
                          child: Text('Precio Unit.', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                        ),
                        ...periodos.map((p) {
                          final fIni = df.format(inicioObra.add(Duration(days: p.diaInicio)));
                          final fFin = df.format(inicioObra.add(Duration(days: p.diaFin - 1)));
                          return SizedBox(
                            width: 165,
                            child: Column(
                              children: [
                                Text('Mes ${p.numero}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                Text('$fIni - $fFin', style: const TextStyle(fontSize: 8.5, color: Color(0xFF475569))),
                                const Divider(height: 6),
                                const Row(
                                  children: [
                                    Expanded(child: Text('Cantidad', textAlign: TextAlign.right, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600))),
                                    Expanded(child: Text('Parcial S/', textAlign: TextAlign.right, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600))),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(
                          width: 165,
                          child: Column(
                            children: [
                              Text('Total', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                              Text('Acumulado Obra', style: TextStyle(fontSize: 8.5, color: Color(0xFF475569))),
                              Divider(height: 6),
                              Row(
                                children: [
                                  Expanded(child: Text('Cantidad', textAlign: TextAlign.right, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold))),
                                  Expanded(child: Text('Parcial S/', textAlign: TextAlign.right, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Filas agrupadas por MANO DE OBRA, MATERIALES, EQUIPO, SUBCONTRATOS
                  Expanded(
                    child: ListView(
                      children: [
                        for (final type in [
                          ResourceType.manoDeObra,
                          ResourceType.material,
                          ResourceType.equipo,
                          ResourceType.subcontrato,
                        ])
                          if (grouped[type]!.isNotEmpty)
                            _buildAdquisicionesGroup(type, grouped[type]!, periodos),
                      ],
                    ),
                  ),

                  // Fila Total General inferior (como en la Imagen 6)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCE6F2),
                      border: Border(top: BorderSide(color: Color(0xFF94A3B8))),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 260),
                        const SizedBox(width: 48),
                        const SizedBox(
                          width: 72,
                          child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        ...periodos.map((p) {
                          final sumMes = insumoMap.values.fold(
                            0.0,
                            (s, item) => s + ((item['parcialPorMes'] as Map<int, double>)[p.numero] ?? 0.0),
                          );
                          return SizedBox(
                            width: 165,
                            child: Text(
                              _currencyFormat.format(sumMes),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          );
                        }),
                        SizedBox(
                          width: 165,
                          child: Text(
                            _currencyFormat.format(grandTotal),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdquisicionesGroup(
    ResourceType type,
    List<Map<String, dynamic>> items,
    List<PeriodoValorizado> periodos,
  ) {
    final groupTitle = switch (type) {
      ResourceType.manoDeObra => 'MANO DE OBRA',
      ResourceType.material => 'MATERIALES',
      ResourceType.equipo => 'EQUIPO',
      ResourceType.subcontrato => 'SUBCONTRATOS',
    };

    final groupTotal = items.fold(0.0, (s, e) => s + (e['parcialTotal'] as double));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Encabezado del grupo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          color: const Color(0xFFEAF1F8),
          child: Text(
            '▼ $groupTitle',
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
          ),
        ),
        // Filas de insumos
        ...items.map((item) {
          final cantPorMes = item['cantPorMes'] as Map<int, double>;
          final parcialPorMes = item['parcialPorMes'] as Map<int, double>;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.7)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 260,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 6),
                    child: Text(
                      item['descripcion'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF0F172A)),
                    ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    item['unidad'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    _currencyFormat.format(item['precio'] as double),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                ...periodos.map((p) {
                  final c = cantPorMes[p.numero] ?? 0.0;
                  final m = parcialPorMes[p.numero] ?? 0.0;
                  return SizedBox(
                    width: 165,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            c > 0.0001 ? _qtyFormat.format(c) : '',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 9.5),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            m > 0.005 ? _currencyFormat.format(m) : '',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                SizedBox(
                  width: 165,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _qtyFormat.format(item['cantTotal'] as double),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _currencyFormat.format(item['parcialTotal'] as double),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        // Subtotal del grupo (Imagen 6)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
          ),
          child: Row(
            children: [
              const SizedBox(width: 260),
              const SizedBox(width: 48),
              const SizedBox(
                width: 72,
                child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
              ),
              ...periodos.map((p) {
                final sumGroupMes = items.fold(
                  0.0,
                  (s, e) => s + ((e['parcialPorMes'] as Map<int, double>)[p.numero] ?? 0.0),
                );
                return SizedBox(
                  width: 165,
                  child: Text(
                    _currencyFormat.format(sumGroupMes),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                );
              }),
              SizedBox(
                width: 165,
                child: Text(
                  _currencyFormat.format(groupTotal),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // VISTA 3: RESUMEN DE COSTOS POR PARTIDA Y RUBRO (Imagen 8 de Delphin)
  // ===========================================================================
  Widget _buildResumenCostosPorRubroDelphin(Subpresupuesto sub, String currency) {
    final partidas = sub.partidas;

    // Calcula el monto de un rubro (MO, MAT, EQ, SC) para una fila (partida o título)
    double rubroDeFila(Partida row, ResourceType type) {
      double montoPartida(Partida p) {
        return switch (type) {
          ResourceType.manoDeObra => p.costoManoObraTotal,
          ResourceType.material => p.costoMaterialesTotal,
          ResourceType.equipo => p.costoEquiposTotal,
          ResourceType.subcontrato => p.costoSubcontratosTotal,
        };
      }

      if (!row.isTitle) return montoPartida(row);
      final prefix = '${row.itemNumber}.';
      double sum = 0.0;
      for (final child in partidas) {
        if (!child.isTitle && child.itemNumber.startsWith(prefix)) {
          sum += montoPartida(child);
        }
      }
      return sum;
    }

    final rootMO = partidas.where((p) => !p.isTitle).fold(0.0, (s, p) => s + p.costoManoObraTotal);
    final rootMAT = partidas.where((p) => !p.isTitle).fold(0.0, (s, p) => s + p.costoMaterialesTotal);
    final rootEQ = partidas.where((p) => !p.isTitle).fold(0.0, (s, p) => s + p.costoEquiposTotal);
    final rootSC = partidas.where((p) => !p.isTitle).fold(0.0, (s, p) => s + p.costoSubcontratosTotal);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 930,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera de Columnas (Imagen 8):
            // Descripción | Und. | Metrado | Precio Unit. | Total | MANO DE OBRA | MATERIALES | EQUIPO | SUB-CONTRATOS
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: const BoxDecoration(
                color: Color(0xFFE2E8F0),
                border: Border(bottom: BorderSide(color: Color(0xFF94A3B8))),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 270, child: Text('Descripción', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                  SizedBox(width: 44, child: Text('Und.', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                  SizedBox(width: 75, child: Text('Metrado', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                  SizedBox(width: 75, child: Text('Precio Unit.', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                  SizedBox(width: 90, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
                  SizedBox(width: 90, child: Text('MANO DE OBRA', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                  SizedBox(width: 90, child: Text('MATERIALES', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                  SizedBox(width: 85, child: Text('EQUIPO', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                  SizedBox(width: 80, child: Text('SUB-CONTR.', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                ],
              ),
            ),

            // Fila Raíz en rojo (Imagen 8: "01 CERCO PERIMETRICO | 603,629.15 | 185,540.44 | 214,957.93 | 203,130.77")
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFFEDF2F8),
                border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 270,
                    child: Text(
                      '▼ ${sub.code}  ${sub.name.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                    ),
                  ),
                  const SizedBox(width: 44),
                  const SizedBox(width: 75),
                  const SizedBox(width: 75),
                  SizedBox(
                    width: 90,
                    child: Text(_currencyFormat.format(sub.costoDirecto), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(_currencyFormat.format(rootMO), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(_currencyFormat.format(rootMAT), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                  ),
                  SizedBox(
                    width: 85,
                    child: Text(_currencyFormat.format(rootEQ), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(rootSC > 0 ? _currencyFormat.format(rootSC) : '', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                  ),
                ],
              ),
            ),

            // Filas de Títulos (en azul) y Partidas (en negro)
            Expanded(
              child: ListView.builder(
                itemCount: partidas.length,
                itemBuilder: (context, idx) {
                  final row = partidas[idx];
                  final isTitle = row.isTitle;
                  final rowColor = isTitle ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A);
                  final indent = (row.level - 1) * 10.0;

                  final mo = rubroDeFila(row, ResourceType.manoDeObra);
                  final mat = rubroDeFila(row, ResourceType.material);
                  final eq = rubroDeFila(row, ResourceType.equipo);
                  final sc = rubroDeFila(row, ResourceType.subcontrato);

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
                    decoration: BoxDecoration(
                      color: isTitle ? const Color(0xFFF8FAFC) : Colors.white,
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.7)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 270,
                          child: Padding(
                            padding: EdgeInsets.only(left: indent),
                            child: Text(
                              '${isTitle ? "▼ " : ""}${row.itemNumber}  ${row.description}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: isTitle ? FontWeight.bold : FontWeight.w500,
                                color: rowColor,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          child: Text(isTitle ? '' : row.unit, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10)),
                        ),
                        SizedBox(
                          width: 75,
                          child: Text(isTitle ? '' : _currencyFormat.format(row.metradoEfectivo), textAlign: TextAlign.right, style: const TextStyle(fontSize: 10.5)),
                        ),
                        SizedBox(
                          width: 75,
                          child: Text(isTitle ? '' : _currencyFormat.format(row.precioUnitario), textAlign: TextAlign.right, style: const TextStyle(fontSize: 10.5)),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text(
                            _currencyFormat.format(row.costoParcial),
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 10.5, fontWeight: isTitle ? FontWeight.bold : FontWeight.w600, color: rowColor),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text(
                            mo > 0.005 ? _currencyFormat.format(mo) : '',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 10.5, fontWeight: isTitle ? FontWeight.bold : FontWeight.normal, color: rowColor),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text(
                            mat > 0.005 ? _currencyFormat.format(mat) : '',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 10.5, fontWeight: isTitle ? FontWeight.bold : FontWeight.normal, color: rowColor),
                          ),
                        ),
                        SizedBox(
                          width: 85,
                          child: Text(
                            eq > 0.005 ? _currencyFormat.format(eq) : '',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 10.5, fontWeight: isTitle ? FontWeight.bold : FontWeight.normal, color: rowColor),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                            sc > 0.005 ? _currencyFormat.format(sc) : '',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 10.5, fontWeight: isTitle ? FontWeight.bold : FontWeight.normal, color: rowColor),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // VISTAS GANTT Y CURVA S EXISTENTES
  // ===========================================================================
  Widget _buildGanttView(
    ThemeData theme,
    List<TareaProgramada> tareas,
    int plazoTotal,
    List<Partida> todasPartidas,
    String currency,
  ) {
    if (tareas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No hay partidas calculables en el presupuesto'),
          ],
        ),
      );
    }

    final maxDays = plazoTotal > 0 ? plazoTotal : 1;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      itemCount: tareas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final t = tareas[index];
        final partida = t.partida;

        final startFraction = (t.inicio / maxDays).clamp(0.0, 1.0);
        final widthFraction = (t.duracion / maxDays).clamp(0.03, 1.0 - startFraction);

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade300, width: 0.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _openTaskEditDialog(context, partida, todasPartidas),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          partida.itemNumber,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          partida.description,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Día ${t.inicio} - ${t.fin} (${t.duracion}d)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: startFraction * 260,
                          width: (widthFraction * 260).clamp(24.0, 260.0),
                          top: 0,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade600,
                                  Colors.teal.shade500,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subpresupuesto: ${t.subNombre}',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700),
                      ),
                      Text(
                        '$currency ${_currencyFormat.format(t.costo)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurvaSView(
    ThemeData theme,
    List<PeriodoValorizado> periodos,
    String currency,
  ) {
    if (periodos.isEmpty) {
      return const Center(child: Text('No hay datos suficientes para generar la Curva S'));
    }

    final spots = <FlSpot>[
      const FlSpot(0, 0),
      ...periodos.map((p) => FlSpot(p.numero.toDouble(), p.pctAcum)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Curva S (Avance Físico Programado Acumulado)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '100% al Final',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 190,
                    child: LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: periodos.length.toDouble(),
                        minY: 0,
                        maxY: 105,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          horizontalInterval: 25,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: Colors.grey.shade300,
                            strokeWidth: 0.8,
                          ),
                          getDrawingVerticalLine: (_) => FlLine(
                            color: Colors.grey.shade200,
                            strokeWidth: 0.8,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              interval: 25,
                              getTitlesWidget: (val, _) => Text(
                                '${val.toInt()}%',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              interval: 1,
                              getTitlesWidget: (val, _) {
                                if (val == 0) return const Text('0', style: TextStyle(fontSize: 10));
                                return Text(
                                  'M${val.toInt()}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: Colors.grey.shade300, width: 0.8),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            curveSmoothness: 0.35,
                            color: theme.colorScheme.primary,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: theme.colorScheme.primary.withValues(alpha: 0.12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Cronograma Valorizado Mensual',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: periodos.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final p = periodos[idx];
                return ListTile(
                  dense: true,
                  title: Text(
                    p.etiqueta,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Parcial: $currency ${_currencyFormat.format(p.monto)} (${p.pct.toStringAsFixed(2)}%)',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${p.pctAcum.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        'Acum: $currency ${_currencyFormat.format(p.acumulado)}',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
