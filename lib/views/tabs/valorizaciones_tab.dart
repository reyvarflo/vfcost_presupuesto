import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/partida.dart';
import '../../models/valorizacion.dart';
import '../../providers/presupuesto_provider.dart';
import '../../services/valorizacion_service.dart';

class ValorizacionesTab extends StatefulWidget {
  const ValorizacionesTab({super.key});

  @override
  State<ValorizacionesTab> createState() => _ValorizacionesTabState();
}

class _ValorizacionesTabState extends State<ValorizacionesTab> {
  final _uuid = const Uuid();
  final _currencyFormat = NumberFormat('#,##0.00', 'es_PE');
  final _numFormat = NumberFormat('#,##0.00', 'es_PE');

  String? _selectedValId;

  void _openCreateValorizacionDialog(BuildContext context) {
    final provider = context.read<PresupuestoProvider>();
    final p = provider.activePresupuesto;
    if (p == null) return;

    final nextNum = p.valorizaciones.length + 1;
    final nameCtrl = TextEditingController(text: 'VALORIZACIÓN N° 0$nextNum');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva Valorización de Obra'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Descripción de la Valorización',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                final newVal = Valorizacion(
                  id: _uuid.v4(),
                  numero: nextNum,
                  periodo: nameCtrl.text.trim().toUpperCase(),
                  fechaCorte: DateTime.now(),
                  avances: {},
                  indicesActuales: Map<int, double>.from(p.indicesBase),
                );
                provider.addValorizacion(newVal);
                setState(() => _selectedValId = newVal.id);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Crear Periodo'),
          ),
        ],
      ),
    );
  }

  void _openAvanceDialog(BuildContext context, Partida partida, double avanceActual, double contratado, double anterior) {
    final provider = context.read<PresupuestoProvider>();
    final ctrl = TextEditingController(text: avanceActual > 0 ? avanceActual.toString() : '');
    final saldo = contratado - anterior;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Avance: ${partida.itemNumber}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(partida.description, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Metrado Contractual: ${_numFormat.format(contratado)} ${partida.unit}',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
            ),
            Text(
              'Acumulado Anterior: ${_numFormat.format(anterior)} ${partida.unit}',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
            ),
            Text(
              'Saldo por Valorizar: ${_numFormat.format(saldo)} ${partida.unit}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: saldo >= 0 ? Colors.blue.shade900 : Colors.red,
              ),
            ),
            const Divider(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Metrado Ejecutado en este Periodo (${partida.unit})',
                hintText: '0.00',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text) ?? 0.0;
              final p = provider.activePresupuesto;
              if (p != null && _selectedValId != null) {
                final currentVal = p.valorizaciones.firstWhere((v) => v.id == _selectedValId);
                final updatedAvances = Map<String, double>.from(currentVal.avances);
                updatedAvances[partida.id] = val;
                provider.updateValorizacion(currentVal.copyWith(avances: updatedAvances));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }

  void _openIndicesIrDialog(BuildContext context, Valorizacion val) {
    final provider = context.read<PresupuestoProvider>();
    final p = provider.activePresupuesto;
    if (p == null) return;

    // Obtener los IU que intervienen en la fórmula polinómica
    final iuSet = <int>{};
    for (final m in p.formulaPolinomica.monomios) {
      for (final sm in m.submonomios) {
        iuSet.add(sm.unifiedIndex);
      }
    }
    final iuList = iuSet.toList()..sort();

    final controllers = <int, TextEditingController>{};
    for (final iu in iuList) {
      final baseVal = p.indicesBase[iu] ?? 100.0;
      final currentIr = val.indicesActuales[iu] ?? baseVal;
      controllers[iu] = TextEditingController(text: currentIr.toString());
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Índices Unificados del Periodo (Ir)'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ingrese los índices de precios (INEI) vigentes al mes de valorización para calcular el coeficiente de reajuste K.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ...iuList.map((iu) {
                  final base = p.indicesBase[iu] ?? 100.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            'IU $iu (Io=$base):',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: controllers[iu],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Ir',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final newIr = Map<int, double>.from(val.indicesActuales);
              controllers.forEach((iu, ctrl) {
                final v = double.tryParse(ctrl.text);
                if (v != null) newIr[iu] = v;
              });
              provider.updateValorizacion(val.copyWith(indicesActuales: newIr));
              Navigator.pop(ctx);
            },
            child: const Text('Calcular K'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<PresupuestoProvider>();
    final p = provider.activePresupuesto;

    if (p == null) {
      return const Center(child: Text('No hay presupuesto activo'));
    }

    final currency = p.currencySymbol;
    final valorizaciones = p.valorizaciones;

    if (valorizaciones.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No hay valorizaciones de obra registradas',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Genera la Valorización N° 01 con metrados ejecutados y reajuste K',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Crear Primera Valorización'),
              onPressed: () => _openCreateValorizacionDialog(context),
            ),
          ],
        ),
      );
    }

    // Seleccionar valorización activa
    final activeVal = valorizaciones.firstWhere(
      (v) => v.id == _selectedValId,
      orElse: () => valorizaciones.last,
    );

    final resumen = ValorizacionService.calcular(p, activeVal);

    return Column(
      children: [
        // Selector de Periodos de Valorización
        Container(
          height: 48,
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            children: [
              ...valorizaciones.map((v) {
                final isSelected = v.id == activeVal.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(v.periodo),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedValId = v.id),
                    selectedColor: theme.colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('Nueva Val.', style: TextStyle(fontSize: 11)),
                onPressed: () => _openCreateValorizacionDialog(context),
              ),
            ],
          ),
        ),

        // Resumen Financiero & Reajuste Polinómico
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 0.5)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total a Pagar (Val. N° 0${activeVal.numero}):',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                      Text(
                        '$currency ${_currencyFormat.format(resumen.totalActual)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.calculate, size: 16),
                    label: Text('K = ${resumen.k.toStringAsFixed(4)} (Ir)', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    onPressed: () => _openIndicesIrDialog(context, activeVal),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CD: $currency ${_currencyFormat.format(resumen.cdActual)}  |  Reajuste: $currency ${_currencyFormat.format(resumen.reajuste)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                  ),
                  Text(
                    'Avance: ${resumen.pctActual.toStringAsFixed(2)}% (Acum: ${resumen.pctAcumulado.toStringAsFixed(2)}%)',
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

        // Lista de Partidas para ingreso de metrados ejecutados
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(top: 6, bottom: 80, left: 10, right: 10),
            itemCount: resumen.lineas.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, idx) {
              final line = resumen.lineas[idx];
              final partida = line.partida;

              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300, width: 0.5),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _openAvanceDialog(
                    context,
                    partida,
                    line.actual,
                    line.contratado,
                    line.anterior,
                  ),
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
                                color: theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                partida.itemNumber,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSecondaryContainer,
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
                            IconButton(
                              icon: const Icon(Icons.edit_note, size: 20),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Ingresar metrado ejecutado',
                              onPressed: () => _openAvanceDialog(
                                context,
                                partida,
                                line.actual,
                                line.contratado,
                                line.anterior,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ejecutado: ${_numFormat.format(line.actual)} ${partida.unit}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: line.actual > 0 ? theme.colorScheme.primary : Colors.grey,
                              ),
                            ),
                            Text(
                              'Parcial: $currency ${_currencyFormat.format(line.montoActual)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: line.montoActual > 0 ? Colors.green.shade900 : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Contractual: ${_numFormat.format(line.contratado)}  •  Acum: ${_numFormat.format(line.acumulado)}',
                              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                            ),
                            Text(
                              'Saldo: ${_numFormat.format(line.saldo)} ${partida.unit}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: line.saldo >= 0 ? Colors.grey.shade700 : Colors.red,
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
          ),
        ),
      ],
    );
  }
}
