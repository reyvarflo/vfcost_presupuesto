import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/partida.dart';
import '../../providers/presupuesto_provider.dart';
import '../../services/pdf_export_service.dart';
import '../../theme/varflo_theme.dart';
import '../../utils/number_format_utils.dart';
import '../../widgets/partida_form_dialog.dart';
import '../../widgets/partida_item_tile.dart';
import '../apu_editor_screen.dart';
import '../delphin_costos_unitarios_screen.dart';
import '../partidas_library_dialog.dart';

class HojaPresupuestoTab extends StatefulWidget {
  const HojaPresupuestoTab({super.key});

  @override
  State<HojaPresupuestoTab> createState() => _HojaPresupuestoTabState();
}

class _HojaPresupuestoTabState extends State<HojaPresupuestoTab> {
  final _currencyFormat = NumberFormat('#,##0.00', 'es_PE');
  String _search = '';
  final Set<String> _collapsedTitleIds = {};

  void _openAddPartidaDialog(BuildContext context, bool defaultIsTitle) {
    final provider = context.read<PresupuestoProvider>();
    final activeSub = provider.activeSubpresupuesto;
    if (activeSub == null) return;

    String suggested = '01';
    if (activeSub.partidas.isNotEmpty) {
      final last = activeSub.partidas.last;
      suggested = _suggestNextItem(last.itemNumber, defaultIsTitle);
    }

    showDialog(
      context: context,
      builder: (ctx) => PartidaFormDialog(
        suggestedItemNumber: suggested,
        onSave: (newPartida) {
          provider.addPartida(
            itemNumber: newPartida.itemNumber,
            description: newPartida.description,
            isTitle: newPartida.isTitle,
            level: newPartida.level,
            unit: newPartida.unit,
            metrado: newPartida.metrado,
            rendimiento: newPartida.rendimiento,
          );
        },
      ),
    );
  }

  String _suggestNextItem(String lastItem, bool isTitle) {
    final parts = lastItem.split('.');
    if (parts.isNotEmpty) {
      final lastNum = int.tryParse(parts.last) ?? 1;
      parts[parts.length - 1] = (lastNum + 1).toString().padLeft(2, '0');
      return parts.join('.');
    }
    return '01';
  }

  void _openEditPartidaDialog(BuildContext context, Partida partida) {
    final provider = context.read<PresupuestoProvider>();
    showDialog(
      context: context,
      builder: (ctx) => PartidaFormDialog(
        existingPartida: partida,
        onSave: (updated) {
          provider.updatePartida(updated);
        },
      ),
    );
  }

  void _openAddSubpresupuestoDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo Subpresupuesto'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Nombre del Subpresupuesto',
            hintText: 'ej: INSTALACIONES SANITARIAS',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<PresupuestoProvider>().addSubpresupuesto(controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  /// Calcula cuántas partidas/subtítulos hijos tiene un Título en la lista ordenada WBS
  int _countChildrenOfTitle(List<Partida> allPartidas, int titleIndex) {
    final title = allPartidas[titleIndex];
    if (!title.isTitle) return 0;
    final prefix = '${title.itemNumber}.';
    int count = 0;
    for (int i = titleIndex + 1; i < allPartidas.length; i++) {
      final current = allPartidas[i];
      final byPrefix = current.itemNumber.startsWith(prefix);
      final byLevel = current.level > title.level && !current.isTitle;
      final isSubTitleHigher = current.isTitle && current.level <= title.level && !byPrefix;
      if (isSubTitleHigher) break;
      if (byPrefix || current.level > title.level) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  /// Filtra la lista de partidas respetando los Títulos contraídos con las flechas (⌄ / ›)
  List<Partida> _buildVisiblePartidas(List<Partida> allPartidas) {
    if (_search.isNotEmpty) {
      return allPartidas.where((p) {
        return p.description.toLowerCase().contains(_search.toLowerCase()) ||
            p.itemNumber.contains(_search);
      }).toList();
    }

    final visible = <Partida>[];
    int i = 0;
    while (i < allPartidas.length) {
      final p = allPartidas[i];
      visible.add(p);

      if (p.isTitle && _collapsedTitleIds.contains(p.id)) {
        final childCount = _countChildrenOfTitle(allPartidas, i);
        i += 1 + childCount;
      } else {
        i++;
      }
    }
    return visible;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PresupuestoProvider>();
    final presupuesto = provider.activePresupuesto;
    final activeSub = provider.activeSubpresupuesto;

    if (presupuesto == null || activeSub == null) {
      return const Center(child: Text('No hay presupuesto seleccionado'));
    }

    final currency = presupuesto.currencySymbol;
    final allPartidas = activeSub.partidas;
    final visiblePartidas = _buildVisiblePartidas(allPartidas);

    // Mapa rápido de cantidad de hijos por cada Título
    final childCounts = <String, int>{};
    for (int i = 0; i < allPartidas.length; i++) {
      if (allPartidas[i].isTitle) {
        childCounts[allPartidas[i].id] = _countChildrenOfTitle(allPartidas, i);
      }
    }

    return Column(
      children: [
        // 1. Barra horizontal de Subpresupuestos
        Container(
          height: 44,
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            children: [
              ...presupuesto.subpresupuestos.map((sub) {
                final isSelected = sub.id == activeSub.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text('${sub.code} ${sub.name}'),
                    selected: isSelected,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => provider.selectSubpresupuesto(sub.id),
                    selectedColor: Theme.of(context).colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                );
              }),
              ActionChip(
                avatar: const Icon(Icons.add, size: 15),
                visualDensity: VisualDensity.compact,
                label: const Text('Subpresupuesto', style: TextStyle(fontSize: 11)),
                onPressed: () => _openAddSubpresupuestoDialog(context),
              ),
            ],
          ),
        ),

        // 2. Cinta de Botones Funcionales Delphin (Costos Unitarios | Unidades | Actualizar | Imprimir PDF | Expandir/Contraer)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFECEFF1),
            border: Border(bottom: BorderSide(color: Colors.blueGrey.shade200)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Botón Costos Unitarios (Imagen 1 de Delphin)
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: const Color(0xFF5B3C88),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.monetization_on_outlined, size: 16),
                  label: const Text('Costos Unitarios', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DelphinCostosUnitariosScreen(initialDialog: 0),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),

                // Botón Unidades (Imagen 3 de Delphin)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.straighten, size: 15, color: Color(0xFF1E3A8A)),
                  label: const Text('Unidades', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DelphinCostosUnitariosScreen(initialDialog: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),

                // Botón Actualizar Costos Unitarios
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.sync, size: 15, color: Color(0xFF0277BD)),
                  label: const Text('Actualizar C.U.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    await provider.procesarPresupuesto();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Costos unitarios, metrados y subtotales actualizados.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(width: 6),

                // Botón Imprimir PDF
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.picture_as_pdf, size: 15, color: Colors.red),
                  label: const Text('Imprimir PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    PdfExportService.printHojaPresupuesto(presupuesto, activeSub);
                  },
                ),
                const SizedBox(width: 6),

                // Botones Expandir Todo (⌄) y Contraer Todo (›)
                IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.unfold_more, size: 17),
                  tooltip: 'Expandir todos los Títulos y Partidas',
                  onPressed: () {
                    setState(() => _collapsedTitleIds.clear());
                  },
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.unfold_less, size: 17),
                  tooltip: 'Contraer todos los Títulos',
                  onPressed: () {
                    setState(() {
                      for (final p in allPartidas) {
                        if (p.isTitle) _collapsedTitleIds.add(p.id);
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        ),

        // 3. Cinta de Resumen de Costo Directo y búsqueda
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Costo Directo del Subpresupuesto:',
                      style: TextStyle(fontSize: 10.5, color: VarfloTheme.grisTextoSecundario, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      NumberFormatUtils.formatCurrency(activeSub.costoDirecto, symbol: currency),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: VarfloTheme.naranjaOscuro,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.library_books, size: 18),
                tooltip: 'Insertar rápida desde Banco de Partidas',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const PartidasLibraryDialog(),
                  );
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar partida...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onChanged: (val) => setState(() => _search = val),
                ),
              ),
            ],
          ),
        ),

        // 4. Lista Jerárquica de Partidas y Títulos (Expandible/Colapsable con clic en las flechas)
        Expanded(
          child: visiblePartidas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.format_list_bulleted, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        _search.isEmpty
                            ? 'No hay partidas en este subpresupuesto'
                            : 'No se encontraron partidas con "$_search"',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar Primera Partida'),
                        onPressed: () => _openAddPartidaDialog(context, false),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 6, bottom: 85),
                  itemCount: visiblePartidas.length,
                  itemBuilder: (context, index) {
                    final partida = visiblePartidas[index];
                    final isCollapsed = _collapsedTitleIds.contains(partida.id);
                    final childCount = childCounts[partida.id] ?? 0;

                    return PartidaItemTile(
                      partida: partida,
                      currencySymbol: currency,
                      isCollapsed: isCollapsed,
                      childCount: childCount,
                      onToggleCollapse: partida.isTitle
                          ? () {
                              setState(() {
                                if (isCollapsed) {
                                  _collapsedTitleIds.remove(partida.id);
                                } else {
                                  _collapsedTitleIds.add(partida.id);
                                }
                              });
                            }
                          : null,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ApuEditorScreen(
                              partida: partida,
                              initialBottomTab: 0,
                            ),
                          ),
                        );
                      },
                      onOpenSpecs: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ApuEditorScreen(
                              partida: partida,
                              initialBottomTab: 1,
                            ),
                          ),
                        );
                      },
                      onOpenMetrados: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ApuEditorScreen(
                              partida: partida,
                              initialBottomTab: 2,
                            ),
                          ),
                        );
                      },
                      onOpenConsolidado: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ApuEditorScreen(
                              partida: partida,
                              initialBottomTab: 4,
                            ),
                          ),
                        );
                      },
                      onEdit: () => _openEditPartidaDialog(context, partida),
                      onDelete: () => provider.deletePartida(partida.id),
                      onIndentRight: () => provider.changePartidaIndent(partida.id, true),
                      onIndentLeft: () => provider.changePartidaIndent(partida.id, false),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
