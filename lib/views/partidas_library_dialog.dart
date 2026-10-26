import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../data/partidas_library.dart';
import '../models/partida.dart';
import '../providers/presupuesto_provider.dart';

class PartidasLibraryDialog extends StatefulWidget {
  const PartidasLibraryDialog({super.key});

  @override
  State<PartidasLibraryDialog> createState() => _PartidasLibraryDialogState();
}

class _PartidasLibraryDialogState extends State<PartidasLibraryDialog> {
  final _currencyFormat = NumberFormat('#,##0.00', 'es_PE');
  String _searchQuery = '';
  String? _selectedCategory;

  late final List<Partida> _templates;

  @override
  void initState() {
    super.initState();
    _templates = PartidasLibrary.getTemplates();
  }

  final _categories = const [
    'Todos',
    'Preliminares',
    'Mov. Tierras',
    'Concreto Simple',
    'Concreto Armado',
    'Muros y Tabiques',
    'Revoques y Enlucidos',
    'Pisos y Pavimentos',
    'Pintura',
    'Inst. Sanitarias',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<PresupuestoProvider>();
    final currency = provider.activePresupuesto?.currencySymbol ?? 'S/.';

    var filtered = _templates.where((p) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!p.description.toLowerCase().contains(q) &&
            !p.unit.toLowerCase().contains(q)) {
          return false;
        }
      }
      if (_selectedCategory != null && _selectedCategory != 'Todos') {
        final cat = _selectedCategory!.toLowerCase();
        final desc = p.description.toLowerCase();
        if (cat == 'preliminares' &&
            !desc.contains('trazo') &&
            !desc.contains('limpieza') &&
            !desc.contains('cartel')) {
          return false;
        }
        if (cat == 'mov. tierras' &&
            !desc.contains('excavacion') &&
            !desc.contains('excavación') &&
            !desc.contains('relleno') &&
            !desc.contains('eliminacion') &&
            !desc.contains('eliminación')) {
          return false;
        }
        if (cat == 'concreto simple' &&
            !desc.contains('solado') &&
            !desc.contains('cimiento corrido') &&
            !desc.contains('sobrecimiento') &&
            !desc.contains('falsopiso')) {
          return false;
        }
        if (cat == 'concreto armado' &&
            !desc.contains('f\'c') &&
            !desc.contains('acero') &&
            !desc.contains('encofrado') &&
            !desc.contains('zapata') &&
            !desc.contains('columna') &&
            !desc.contains('viga') &&
            !desc.contains('losa')) {
          return false;
        }
        if (cat == 'muros y tabiques' &&
            !desc.contains('ladrillo') &&
            !desc.contains('muro') &&
            !desc.contains('tabique') &&
            !desc.contains('king kong')) {
          return false;
        }
        if (cat == 'revoques y enlucidos' &&
            !desc.contains('tarrajeo') &&
            !desc.contains('vestidura') &&
            !desc.contains('cielo raso')) {
          return false;
        }
        if (cat == 'pisos y pavimentos' &&
            !desc.contains('contrapiso') &&
            !desc.contains('ceramico') &&
            !desc.contains('porcelanato') &&
            !desc.contains('piso')) {
          return false;
        }
        if (cat == 'pintura' && !desc.contains('pintura') && !desc.contains('latex')) {
          return false;
        }
        if (cat == 'inst. sanitarias' &&
            !desc.contains('tuberia') &&
            !desc.contains('tubería') &&
            !desc.contains('pvc') &&
            !desc.contains('sanitario')) {
          return false;
        }
      }
      return true;
    }).toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Column(
          children: [
            // Cabecera Delphin
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.library_books, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Banco de Partidas (Delphin / S10)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Selecciona una partida estándar con APU completo',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Barra de búsqueda
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar en el catálogo de partidas...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),

            // Filtro horizontal de categorías
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = (_selectedCategory == null && cat == 'Todos') ||
                      _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(cat, style: const TextStyle(fontSize: 11)),
                      selected: isSelected,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) {
                        setState(() => _selectedCategory = cat == 'Todos' ? null : cat);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 12),

            // Lista de partidas encontradas
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No se encontraron partidas para el filtro aplicado',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final tpl = filtered[index];
                        final puCalculado = tpl.calculateUnitPrice();

                        return Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.grey.shade300, width: 0.6),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        tpl.description,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        tpl.unit,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      'Rdto: ${_currencyFormat.format(tpl.rendimiento)} ${tpl.unit}/día',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '${tpl.apuItems.length} insumos',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'P.U.: $currency ${_currencyFormat.format(puCalculado)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.tonalIcon(
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    ),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Insertar en Presupuesto', style: TextStyle(fontSize: 11.5)),
                                    onPressed: () {
                                      provider.importPartidaFromLibrary(tpl);
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Partida agregada: "${tpl.description}"'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    },
                                  ),
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
      ),
    );
  }
}
