import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/gasto_general.dart';
import '../providers/presupuesto_provider.dart';

class GastosGeneralesScreen extends StatefulWidget {
  const GastosGeneralesScreen({super.key});

  @override
  State<GastosGeneralesScreen> createState() => _GastosGeneralesScreenState();
}

class _GastosGeneralesScreenState extends State<GastosGeneralesScreen> {
  final _uuid = const Uuid();
  final _currencyFormat = NumberFormat('#,##0.00', 'es_PE');
  TipoGasto _selectedTab = TipoGasto.fijo;

  void _openGastoItemDialog({GastoGeneralItem? existingItem, TipoGasto? defaultTipo}) {
    final tipo = existingItem?.tipo ?? defaultTipo ?? _selectedTab;
    final descCtrl = TextEditingController(text: existingItem?.descripcion ?? '');
    final undCtrl = TextEditingController(text: existingItem?.unidad ?? (tipo == TipoGasto.fijo ? 'glb' : 'mes'));
    final cantCtrl = TextEditingController(text: (existingItem?.cantidad ?? 1.0).toString());
    final tiempoCtrl = TextEditingController(text: (existingItem?.tiempo ?? 1.0).toString());
    final precioCtrl = TextEditingController(text: (existingItem?.precio ?? 0.0).toString());
    final partCtrl = TextEditingController(text: (existingItem?.participacion ?? 100.0).toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          existingItem == null ? 'Nuevo Concepto de Gasto' : 'Editar Concepto de Gasto',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Descripción / Concepto',
                  hintText: 'ej. RESIDENTE DE OBRA (CIP)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: undCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Unidad',
                        hintText: 'mes / glb',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: cantCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Cantidad',
                        hintText: '1.0',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: tiempoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Tiempo (Meses)',
                        hintText: '1.0',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: precioCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Costo Unitario',
                        hintText: '0.00',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: partCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '% de Participación en Obra',
                  hintText: '100.0',
                  border: OutlineInputBorder(),
                  isDense: true,
                  helperText: '100% = dedicación exclusiva a la obra',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final desc = descCtrl.text.trim();
              if (desc.isEmpty) return;

              final und = undCtrl.text.trim().isEmpty ? 'mes' : undCtrl.text.trim();
              final cant = double.tryParse(cantCtrl.text) ?? 1.0;
              final tiempo = double.tryParse(tiempoCtrl.text) ?? 1.0;
              final precio = double.tryParse(precioCtrl.text) ?? 0.0;
              final part = double.tryParse(partCtrl.text) ?? 100.0;

              final item = GastoGeneralItem(
                id: existingItem?.id ?? _uuid.v4(),
                tipo: tipo,
                descripcion: desc.toUpperCase(),
                unidad: und,
                cantidad: cant,
                tiempo: tiempo,
                precio: precio,
                participacion: part,
              );

              final provider = context.read<PresupuestoProvider>();
              if (existingItem != null) {
                provider.updateGastoGeneralItem(item);
              } else {
                provider.addGastoGeneralItem(item);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
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
      return Scaffold(
        appBar: AppBar(title: const Text('Gastos Generales Desagregados')),
        body: const Center(child: Text('No hay presupuesto activo')),
      );
    }

    final currency = p.currencySymbol;
    final cd = p.totalCostoDirecto;
    final fijos = p.gastosGenerales.where((g) => g.tipo == TipoGasto.fijo).toList();
    final variables = p.gastosGenerales.where((g) => g.tipo == TipoGasto.variable).toList();

    final totalFijos = p.totalGGFijosDesagregado;
    final totalVar = p.totalGGVariablesDesagregado;
    final pctFijos = cd > 0 ? (totalFijos / cd) * 100 : 0.0;
    final pctVar = cd > 0 ? (totalVar / cd) * 100 : 0.0;

    final currentItems = _selectedTab == TipoGasto.fijo ? fijos : variables;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gastos Generales Analíticos (Delphin)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: 'Cargar Plantilla Estándar Delphin',
            onPressed: () {
              provider.cargarPlantillaGastosGenerales();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Plantilla de Gastos Generales cargada y sincronizada.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner de Vinculación y Resumen Porcentual
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GG Analítico Total:',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                        Text(
                          '$currency ${_currencyFormat.format(totalFijos + totalVar)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Fijos: ${pctFijos.toStringAsFixed(2)}% del CD',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Variables: ${pctVar.toStringAsFixed(2)}% del CD',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text(
                    'Vincular porcentajes calculados al Pie de Presupuesto',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  value: p.usarGGDesagregado,
                  onChanged: (val) => provider.toggleUsarGGDesagregado(val),
                ),
              ],
            ),
          ),

          // Selector de Tipo de Gasto (Fijo vs Variable)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: SegmentedButton<TipoGasto>(
              segments: [
                ButtonSegment(
                  value: TipoGasto.fijo,
                  label: Text('Fijos ($currency ${_currencyFormat.format(totalFijos)})', style: const TextStyle(fontSize: 11.5)),
                  icon: const Icon(Icons.lock_outline, size: 16),
                ),
                ButtonSegment(
                  value: TipoGasto.variable,
                  label: Text('Variables ($currency ${_currencyFormat.format(totalVar)})', style: const TextStyle(fontSize: 11.5)),
                  icon: const Icon(Icons.people_outline, size: 16),
                ),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (val) => setState(() => _selectedTab = val.first),
            ),
          ),
          const Divider(height: 1),

          // Lista de ítems
          Expanded(
            child: currentItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.request_quote_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No hay conceptos de gastos ${_selectedTab == TipoGasto.fijo ? 'fijos' : 'variables'}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar Concepto'),
                          onPressed: () => _openGastoItemDialog(defaultTipo: _selectedTab),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    itemCount: currentItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, idx) {
                      final item = currentItems[idx];
                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300, width: 0.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.descripcion,
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Editar',
                                    onPressed: () => _openGastoItemDialog(existingItem: item),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Eliminar',
                                    onPressed: () => provider.removeGastoGeneralItem(item.id),
                                  ),
                                ],
                              ),
                              const Divider(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${item.cantidad} ${item.unidad} × ${item.tiempo}m @ $currency ${_currencyFormat.format(item.precio)} (${item.participacion.toStringAsFixed(0)}%)',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                  ),
                                  Text(
                                    'Parcial: $currency ${_currencyFormat.format(item.parcial)}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Agregar Concepto de Gasto',
        onPressed: () => _openGastoItemDialog(defaultTipo: _selectedTab),
        child: const Icon(Icons.add),
      ),
    );
  }
}
