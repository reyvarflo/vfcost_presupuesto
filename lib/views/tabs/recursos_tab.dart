import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/resource.dart';
import '../../providers/presupuesto_provider.dart';
import '../../services/delphin_excel_service.dart';
import '../../services/excel_export_service.dart';
import '../../services/formula_service.dart';

class RecursosTab extends StatefulWidget {
  const RecursosTab({super.key});

  @override
  State<RecursosTab> createState() => _RecursosTabState();
}

class _RecursosTabState extends State<RecursosTab> {
  final _currencyFormat = NumberFormat('#,##0.00', 'es_PE');
  final _qtyFormat = NumberFormat('#,##0.0000', 'es_PE');

  /// false = "Lista de insumos del presupuesto" (solo subpresupuesto activo)
  /// true  = "Lista de insumos del proyecto" (todos los subpresupuestos consolidados)
  bool _consolidarTodoElProyecto = false;

  ResourceType? _selectedTypeFilter;
  String _searchQuery = '';

  final Map<ResourceType, bool> _expandedGroups = {
    ResourceType.manoDeObra: true,
    ResourceType.material: true,
    ResourceType.equipo: true,
    ResourceType.subcontrato: true,
  };

  void _openEditGlobalInsumoDialog(
    BuildContext context,
    Map<String, dynamic> item,
    String currency,
  ) {
    final desc = item['descripcion'] as String;
    final type = item['tipo'] as ResourceType;
    final currentPrice = item['precio'] as double;
    final unit = item['und'] as String;
    final currentProveedor = item['proveedor'] as String;
    final currentMarca = item['marca'] as String;
    final currentIu = item['iu'] as int;

    final priceCtrl = TextEditingController(text: currentPrice.toStringAsFixed(2));
    final provCtrl = TextEditingController(text: currentProveedor);
    final marcaCtrl = TextEditingController(text: currentMarca);
    int selectedIu = currentIu > 0 ? currentIu : 39;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit_note, color: Color(0xFF1E3A8A)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Editar Datos de Insumo (Delphin / S10)',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(desc, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Rubro: ${type.displayName}  •  Unidad: $unit',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Precio Unitario ($currency / $unit)',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: provCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Proveedor (ej. PROVEEDOR DISTRITAL, S10, PROVIAS)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: marcaCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Marca / Cantera (Opcional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: FormulaService.nombresIUTotales.containsKey(selectedIu) ? selectedIu : 39,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Índice Unificado INEI (Ind.)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: FormulaService.nombresIUTotales.entries.map((e) {
                    final codeStr = e.key.toString().padLeft(2, '0');
                    return DropdownMenuItem<int>(
                      value: e.key,
                      child: Text(
                        '$codeStr - ${e.value}',
                        style: const TextStyle(fontSize: 11.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedIu = val);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                final newP = double.tryParse(priceCtrl.text.replaceAll(',', '.'));
                if (newP != null && newP >= 0) {
                  final count = await context.read<PresupuestoProvider>().updatePrecioGlobalInsumo(
                        resourceDescription: desc,
                        type: type,
                        nuevoPrecio: newP,
                        nuevoProveedor: provCtrl.text.trim(),
                        nuevaMarca: marcaCtrl.text.trim(),
                        nuevoIndiceUnificado: selectedIu,
                      );
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Insumo actualizado en $count APUs del proyecto.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: const Text('Actualizar en Proyecto'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PresupuestoProvider>();
    final presupuesto = provider.activePresupuesto;
    final activeSub = provider.activeSubpresupuesto;

    if (presupuesto == null || activeSub == null) {
      return const Center(child: Text('No hay presupuesto activo'));
    }

    final currency = presupuesto.currencySymbol;

    // Mapa del catálogo maestro para detectar diferencias de precio (alerta '!')
    final catalogPriceByDesc = <String, double>{};
    for (final r in provider.masterResources) {
      catalogPriceByDesc[r.description.trim().toUpperCase()] = r.unitPrice;
    }

    // Subpresupuestos a consolidar según la pestaña activa
    final targetSubs = _consolidarTodoElProyecto
        ? presupuesto.subpresupuestos
        : [activeSub];

    final resourceMap = <String, Map<String, dynamic>>{};
    String? firstDiffResourceName;
    int diffCount = 0;

    for (final sub in targetSubs) {
      for (final partida in sub.partidas) {
        if (partida.isTitle || partida.metrado <= 0) continue;
        for (final apu in partida.apuItems) {
          if (apu.isPercentageOfMO) continue;
          final key = '${apu.type.name}_${apu.resourceDescription.trim().toUpperCase()}';
          final totalCant = apu.cantidad * partida.metrado;
          final totalCost = totalCant * apu.precioUnitario;

          if (resourceMap.containsKey(key)) {
            resourceMap[key]!['cantidad'] = (resourceMap[key]!['cantidad'] as double) + totalCant;
            resourceMap[key]!['costoTotal'] = (resourceMap[key]!['costoTotal'] as double) + totalCost;
          } else {
            final upperDesc = apu.resourceDescription.trim().toUpperCase();
            final basePrice = catalogPriceByDesc[upperDesc];
            final hasDiff = basePrice != null && (basePrice - apu.precioUnitario).abs() > 0.005;
            if (hasDiff) {
              diffCount++;
              firstDiffResourceName ??= apu.resourceDescription;
            }

            resourceMap[key] = {
              'tipo': apu.type,
              'codigo': apu.resourceCode,
              'descripcion': apu.resourceDescription,
              'proveedor': apu.effectiveProveedor,
              'marca': apu.marca,
              'und': apu.unit,
              'iu': apu.unifiedIndex > 0 ? apu.unifiedIndex : _defaultIuForType(apu.type),
              'cantidad': totalCant,
              'precio': apu.precioUnitario,
              'costoTotal': totalCost,
              'hasDiff': hasDiff,
              'basePrice': basePrice,
            };
          }
        }
      }
    }

    var list = resourceMap.values.toList();

    // Filtros
    if (_selectedTypeFilter != null) {
      list = list.where((r) => r['tipo'] == _selectedTypeFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((r) {
        final desc = (r['descripcion'] as String).toLowerCase();
        final code = (r['codigo'] as String).toLowerCase();
        final prov = (r['proveedor'] as String).toLowerCase();
        final iu = r['iu'].toString().padLeft(2, '0');
        return desc.contains(q) || code.contains(q) || prov.contains(q) || iu.contains(q);
      }).toList();
    }

    final grandTotal = list.fold(0.0, (sum, r) => sum + (r['costoTotal'] as double));

    // Agrupar por ResourceType en el orden de Delphin: Mano de Obra, Materiales, Equipo, Subcontratos
    final grouped = <ResourceType, List<Map<String, dynamic>>>{
      ResourceType.manoDeObra: [],
      ResourceType.material: [],
      ResourceType.equipo: [],
      ResourceType.subcontrato: [],
    };
    for (final item in list) {
      final t = item['tipo'] as ResourceType;
      grouped[t]!.add(item);
    }
    for (final t in grouped.keys) {
      grouped[t]!.sort((a, b) => (b['costoTotal'] as double).compareTo(a['costoTotal'] as double));
    }

    return Column(
      children: [
        // 1. Pestañas Superiores estilo Delphin:
        //    [Lista de insumos del presupuesto] | [Lista de insumos del proyecto]
        Container(
          color: const Color(0xFFDCE6F2),
          padding: const EdgeInsets.fromLTRB(8, 6, 6, 0),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDelphinSubTab(
                        title: 'Lista de insumos del presupuesto',
                        selected: !_consolidarTodoElProyecto,
                        onTap: () => setState(() => _consolidarTodoElProyecto = false),
                      ),
                      const SizedBox(width: 4),
                      _buildDelphinSubTab(
                        title: 'Lista de insumos del proyecto',
                        selected: _consolidarTodoElProyecto,
                        onTap: () => setState(() => _consolidarTodoElProyecto = true),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Botones rápidos de exportación Excel / CSV como en la esquina derecha de Delphin
              IconButton(
                icon: const Icon(Icons.table_view, size: 18, color: Color(0xFF1E7145)),
                tooltip: 'Exportar a Excel (.xlsx)',
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                onPressed: () => DelphinExcelService.exportDelphinXlsx(presupuesto),
              ),
              IconButton(
                icon: const Icon(Icons.share, size: 17, color: Color(0xFF1E3A8A)),
                tooltip: 'Compartir CSV de Insumos',
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                onPressed: () {
                  final csv = ExcelExportService.generateResourcesCsv(presupuesto, activeSub);
                  ExcelExportService.shareCsvFile(csv, 'Insumos_${presupuesto.code}.csv');
                },
              ),
            ],
          ),
        ),

        // 2. Cabecera "Presupuesto: ESTRUCTURA" y Búsqueda / Filtro rápido
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: const BoxDecoration(
            color: Color(0xFFEDF2F8),
            border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'Presupuesto: ',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _consolidarTodoElProyecto
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blueGrey.shade200),
                            ),
                            child: Text(
                              'TODOS LOS SUBPRESUPUESTOS (${presupuesto.subpresupuestos.length})',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blueGrey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: activeSub.id,
                                isExpanded: true,
                                isDense: true,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A8A),
                                ),
                                items: presupuesto.subpresupuestos.map((s) {
                                  return DropdownMenuItem<String>(
                                    value: s.id,
                                    child: Text('${s.name.toUpperCase()} (${s.code})'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    provider.selectSubpresupuesto(val);
                                  }
                                },
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 170,
                    height: 28,
                    child: TextField(
                      style: const TextStyle(fontSize: 11.5),
                      decoration: InputDecoration(
                        hintText: 'Filtrar Ind., descripción o proveedor...',
                        hintStyle: const TextStyle(fontSize: 10.5),
                        prefixIcon: const Icon(Icons.filter_alt_outlined, size: 15),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: Colors.blueGrey.shade300),
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 3. Encabezados de Columna de la Cuadrícula Delphin:
        //    Ind. | Descripción | Proveedor | Cantidad | ! | Precio Unit. | Total
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const BoxDecoration(
            color: Color(0xFFE2E8F0),
            border: Border(bottom: BorderSide(color: Color(0xFF94A3B8))),
          ),
          child: const Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  'Ind.',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
              ),
              Expanded(
                flex: 5,
                child: Text(
                  'Descripción',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Proveedor',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Cantidad',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
              ),
              SizedBox(width: 16), // Columna '!'
              SizedBox(
                width: 62,
                child: Text(
                  'Precio Unit.',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
              ),
              SizedBox(
                width: 78,
                child: Text(
                  'Total',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
              ),
            ],
          ),
        ),

        // 4. Cuerpo de la Cuadrícula Agrupada por Categorías Colapsables (MANO DE OBRA, MATERIALES, EQUIPO, SUBCONTRATOS)
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Text(
                    'No hay insumos requeridos con los filtros actuales',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : ListView(
                  children: [
                    for (final type in [
                      ResourceType.manoDeObra,
                      ResourceType.material,
                      ResourceType.equipo,
                      ResourceType.subcontrato,
                    ])
                      if (grouped[type]!.isNotEmpty)
                        _buildGroupSection(
                          context: context,
                          type: type,
                          items: grouped[type]!,
                          currency: currency,
                        ),
                  ],
                ),
        ),

        // 5. Pie de Total Acumulado y Alerta de Sincronización con Base Maestra (Estilo Delphin)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: const BoxDecoration(
            color: Color(0xFFDCE6F2),
            border: Border(top: BorderSide(color: Color(0xFF94A3B8))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${list.length} insumos listados',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
              Row(
                children: [
                  const Text(
                    'Total:   ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                  ),
                  Text(
                    _currencyFormat.format(grandTotal),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 6. Barra de advertencia si existen precios que difieren del catálogo maestro (Idéntico a Delphin)
        if (diffCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            color: const Color(0xFFFFFBEB),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Existen datos que difieren de la base para el insumo $firstDiffResourceName${diffCount > 1 ? " (+${diffCount - 1} más)" : ""}. '
                    'Para corregir pulse en Actualizar datos de insumos.',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF92400E)),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                  icon: const Icon(Icons.sync, size: 14),
                  label: const Text('Actualizar insumos', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final synced = await provider.sincronizarInsumosConCatalogo();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Se sincronizaron $synced precios con el catálogo maestro S10.'),
                          backgroundColor: Colors.teal,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDelphinSubTab({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEDF2F8) : const Color(0xFFCBD5E1),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          border: Border(
            top: BorderSide(
              color: selected ? const Color(0xFF1E3A8A) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? const Color(0xFF0F172A) : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupSection({
    required BuildContext context,
    required ResourceType type,
    required List<Map<String, dynamic>> items,
    required String currency,
  }) {
    final isExpanded = _expandedGroups[type] ?? true;
    final groupTotal = items.fold(0.0, (sum, r) => sum + (r['costoTotal'] as double));

    String groupHeaderName;
    switch (type) {
      case ResourceType.manoDeObra:
        groupHeaderName = 'MANO DE OBRA';
        break;
      case ResourceType.material:
        groupHeaderName = 'MATERIALES';
        break;
      case ResourceType.equipo:
        groupHeaderName = 'EQUIPOS';
        break;
      case ResourceType.subcontrato:
        groupHeaderName = 'SUBCONTRATOS';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabecera colapsable del grupo (Estilo Delphin: ▼ MANO DE OBRA ........ 1,695,978.39)
        InkWell(
          onTap: () {
            setState(() {
              _expandedGroups[type] = !isExpanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFFEAF1F8),
              border: Border(
                bottom: BorderSide(color: Color(0xFFCBD5E1)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  size: 16,
                  color: const Color(0xFF1E3A8A),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    groupHeaderName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                Text(
                  _currencyFormat.format(groupTotal),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Filas de insumos del grupo
        if (isExpanded)
          ...List.generate(items.length, (idx) {
            final item = items[idx];
            final iu = (item['iu'] as int).toString().padLeft(2, '0');
            final desc = item['descripcion'] as String;
            final prov = item['proveedor'] as String;
            final cant = item['cantidad'] as double;
            final und = item['und'] as String;
            final precio = item['precio'] as double;
            final total = item['costoTotal'] as double;
            final hasDiff = item['hasDiff'] as bool? ?? false;

            return InkWell(
              onTap: () => _openEditGlobalInsumoDialog(context, item, currency),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5.5),
                decoration: BoxDecoration(
                  color: idx.isEven ? Colors.white : const Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.7)),
                ),
                child: Row(
                  children: [
                    // Ind. (Índice Unificado INEI)
                    SizedBox(
                      width: 32,
                      child: Text(
                        iu,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    // Descripción
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          desc,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                    // Proveedor
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          prov,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                    // Cantidad + Unidad en azul
                    Expanded(
                      flex: 3,
                      child: RichText(
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF0F172A)),
                          children: [
                            TextSpan(text: '${_qtyFormat.format(cant)} '),
                            TextSpan(
                              text: und,
                              style: const TextStyle(
                                color: Color(0xFF0284C7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Indicador '!' de variación respecto a la base maestra
                    SizedBox(
                      width: 16,
                      child: hasDiff
                          ? const Tooltip(
                              message: 'El precio difiere del catálogo maestro S10',
                              child: Text(
                                '!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0284C7),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    // Precio Unit.
                    SizedBox(
                      width: 62,
                      child: Text(
                        _currencyFormat.format(precio),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF1E293B)),
                      ),
                    ),
                    // Total
                    SizedBox(
                      width: 78,
                      child: Text(
                        _currencyFormat.format(total),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  int _defaultIuForType(ResourceType type) {
    switch (type) {
      case ResourceType.manoDeObra:
        return 47;
      case ResourceType.material:
        return 21;
      case ResourceType.equipo:
        return 49;
      case ResourceType.subcontrato:
        return 39;
    }
  }
}
