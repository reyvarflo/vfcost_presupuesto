import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/resource.dart';
import '../providers/presupuesto_provider.dart';

class ResourceCatalogScreen extends StatefulWidget {
  const ResourceCatalogScreen({super.key});

  @override
  State<ResourceCatalogScreen> createState() => _ResourceCatalogScreenState();
}

class _ResourceCatalogScreenState extends State<ResourceCatalogScreen> {
  final _currencyFormat = NumberFormat('#,##0.00', 'es_PE');
  String _search = '';
  ResourceType? _selectedType;

  void _openAddResourceDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'und');
    final iuCtrl = TextEditingController(text: '0');
    final priceCtrl = TextEditingController(text: '0.00');
    ResourceType type = ResourceType.material;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Nuevo Insumo Maestro S10'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<ResourceType>(
                      value: type,
                      decoration: const InputDecoration(labelText: 'Tipo de Recurso', border: OutlineInputBorder()),
                      items: ResourceType.values.map((t) {
                        return DropdownMenuItem(value: t, child: Text(t.displayName));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => type = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(labelText: 'Código S10', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Descripción del Insumo', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: unitCtrl,
                            decoration: const InputDecoration(labelText: 'Unidad (hh, m3, kg)', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: iuCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Índice Unificado (IU)', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Precio Base Unitario (S/.)', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    final newRes = Resource(
                      id: 'res_custom_${const Uuid().v4().substring(0, 8)}',
                      code: codeCtrl.text.trim().isNotEmpty
                          ? codeCtrl.text.trim()
                          : '99${DateTime.now().millisecondsSinceEpoch % 100000}',
                      description: descCtrl.text.trim().toUpperCase(),
                      unit: unitCtrl.text.trim().toLowerCase(),
                      unitPrice: double.tryParse(priceCtrl.text) ?? 0.0,
                      type: type,
                      unifiedIndex: int.tryParse(iuCtrl.text) ?? 0,
                    );
                    context.read<PresupuestoProvider>().addCustomResource(newRes);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PresupuestoProvider>();
    final resources = provider.masterResources;

    var filtered = resources.where((r) {
      if (_selectedType != null && r.type != _selectedType) return false;
      if (_search.isNotEmpty) {
        return r.description.toLowerCase().contains(_search.toLowerCase()) ||
            r.code.toLowerCase().contains(_search.toLowerCase()) ||
            r.unifiedIndex.toString().contains(_search);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo Maestro de Recursos S10'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Crear Insumo',
            onPressed: () => _openAddResourceDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros y búsqueda
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar en catálogo (descripción, código o IU)...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onChanged: (val) => setState(() => _search = val),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Todos'),
                        selected: _selectedType == null,
                        onSelected: (_) => setState(() => _selectedType = null),
                      ),
                      const SizedBox(width: 6),
                      ...ResourceType.values.map((t) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(t.displayName),
                            selected: _selectedType == t,
                            onSelected: (_) => setState(() => _selectedType = t),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${filtered.length} recursos disponibles', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                const Text('Valores base CAPECO / Mercado', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final r = filtered[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    child: Text(r.type.shortCode, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(r.description, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  subtitle: Text('Código: ${r.code}  |  IU: ${r.unifiedIndex}  |  Unidad: ${r.unit}', style: const TextStyle(fontSize: 11)),
                  trailing: Text(
                    'S/. ${_currencyFormat.format(r.unitPrice)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddResourceDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
