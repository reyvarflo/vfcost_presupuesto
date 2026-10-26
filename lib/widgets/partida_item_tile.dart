import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/partida.dart';
import '../utils/number_format_utils.dart';

class PartidaItemTile extends StatelessWidget {
  final Partida partida;
  final String currencySymbol;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onIndentRight;
  final VoidCallback onIndentLeft;
  final VoidCallback? onOpenMetrados;
  final VoidCallback? onOpenSpecs;
  final VoidCallback? onOpenConsolidado;
  final bool isCollapsed;
  final int childCount;
  final VoidCallback? onToggleCollapse;

  static final _currencyFormat = NumberFormat('#,##0.00', 'es_PE');

  const PartidaItemTile({
    super.key,
    required this.partida,
    required this.currencySymbol,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onIndentRight,
    required this.onIndentLeft,
    this.onOpenMetrados,
    this.onOpenSpecs,
    this.onOpenConsolidado,
    this.isCollapsed = false,
    this.childCount = 0,
    this.onToggleCollapse,
  });

  Color _getTitleColor(int level) {
    if (level <= 1) return const Color(0xFF0F172A); // Nivel 1: Negro / Azul profundo
    if (level == 2) return const Color(0xFF0277BD); // Nivel 2: Azul acero Delphin
    return const Color(0xFF2E7D32); // Nivel 3+: Verde bosque Delphin
  }

  Color _getTitleBgColor(int level) {
    if (level <= 1) return const Color(0xFFE2E8F0);
    if (level == 2) return const Color(0xFFE0F2FE);
    return const Color(0xFFECFDF5);
  }

  @override
  Widget build(BuildContext context) {
    final isTitle = partida.isTitle;
    final indentPadding = (partida.level - 1) * 14.0;
    final titleColor = _getTitleColor(partida.level);
    final hasApu = !isTitle && partida.apuItems.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
      decoration: BoxDecoration(
        color: isTitle ? _getTitleBgColor(partida.level) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isTitle
              ? titleColor.withValues(alpha: 0.35)
              : Colors.blueGrey.shade200,
          width: isTitle && partida.level == 1 ? 1.3 : 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          // En Títulos, hacer clic en la fila o en la flecha expande/retrae las partidas hijas
          onTap: isTitle ? (onToggleCollapse ?? onEdit) : onTap,
          child: Padding(
            padding: EdgeInsets.only(
              left: 8 + indentPadding,
              right: 8,
              top: 6,
              bottom: 6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila 1: Flecha Expandir/Retraer, Ítem, Indicador APU ↑, [A] y controles
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isTitle) ...[
                              InkWell(
                                onTap: onToggleCollapse,
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: titleColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Icon(
                                    isCollapsed ? Icons.keyboard_arrow_right : Icons.keyboard_arrow_down,
                                    size: 18,
                                    color: titleColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isTitle ? titleColor : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                                border: isTitle ? null : Border.all(color: Colors.blueGrey.shade300),
                              ),
                              child: Text(
                                partida.itemNumber,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: isTitle ? Colors.white : const Color(0xFF334155),
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            if (isTitle) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'N${partida.level}',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: titleColor,
                                  ),
                                ),
                              ),
                              if (childCount > 0) ...[
                                const SizedBox(width: 5),
                                InkWell(
                                  onTap: onToggleCollapse,
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isCollapsed
                                          ? Colors.amber.shade200
                                          : Colors.white.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isCollapsed
                                            ? Colors.amber.shade800
                                            : titleColor.withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Text(
                                      isCollapsed
                                          ? '▸ $childCount ocultas'
                                          : '▾ $childCount ítems',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: isCollapsed ? Colors.brown.shade900 : titleColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ] else ...[
                              // Flecha verde hacia arriba (↑) estilo Delphin indicando APU activo (Clic abre Análisis de C.U)
                              InkWell(
                                onTap: onTap,
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: hasApu ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        hasApu ? Icons.north : Icons.priority_high,
                                        size: 11,
                                        color: hasApu ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        hasApu
                                            ? 'APU (${partida.apuItems.length} ins.)'
                                            : 'Sin APU',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: hasApu ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Icono [A] de Especificación Técnica (Clic abre directamente la pestaña Especificaciones Técnicas)
                              InkWell(
                                onTap: onOpenSpecs ?? onTap,
                                borderRadius: BorderRadius.circular(3),
                                child: Tooltip(
                                  message: 'Abrir Especificaciones Técnicas de la partida',
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      border: Border.all(color: const Color(0xFF93C5FD)),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: const Text(
                                      'A',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF1D4ED8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Botón de edición directa visible con un clic
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      tooltip: 'Editar nombre / ítem',
                      onPressed: onEdit,
                    ),
                    // Botones de indentación rápida
                    IconButton(
                      icon: const Icon(Icons.format_indent_decrease, size: 15),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      tooltip: 'Reducir nivel',
                      onPressed: onIndentLeft,
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_indent_increase, size: 15),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      tooltip: 'Aumentar nivel',
                      onPressed: onIndentRight,
                    ),
                    SizedBox(
                      width: 26,
                      height: 28,
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 17),
                        padding: EdgeInsets.zero,
                        itemBuilder: (context) => [
                        if (isTitle)
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(isCollapsed ? 'Expandir partidas' : 'Contraer partidas'),
                          ),
                        const PopupMenuItem(value: 'edit', child: Text('Editar datos')),
                        if (!isTitle) ...[
                          const PopupMenuItem(value: 'apu', child: Text('Abrir Análisis de C.U.')),
                          const PopupMenuItem(value: 'specs', child: Text('Especificaciones Técnicas')),
                          const PopupMenuItem(value: 'metrados', child: Text('Hoja de Metrados')),
                        ],
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Eliminar', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                      onSelected: (val) {
                        if (val == 'toggle') onToggleCollapse?.call();
                        if (val == 'edit') onEdit();
                        if (val == 'apu') onTap();
                        if (val == 'specs') (onOpenSpecs ?? onTap).call();
                        if (val == 'metrados') onOpenMetrados?.call();
                        if (val == 'delete') onDelete();
                      },
                    ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                // Fila 2: Descripción con color jerárquico Delphin
                Text(
                  partida.description,
                  style: TextStyle(
                    fontSize: isTitle ? 13 : 12,
                    fontWeight: isTitle ? FontWeight.bold : FontWeight.w500,
                    color: isTitle ? titleColor : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 5),
                // Fila 3: Cantidad + Unidad en azul, Precio en terracota/azul, y Total Parcial (todos clicables)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (!isTitle) ...[
                      InkWell(
                        onTap: onOpenMetrados,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                          child: Row(
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                                  children: [
                                    const TextSpan(text: 'Cant: '),
                                    TextSpan(
                                      text: '${NumberFormatUtils.formatNumber(partida.metrado)} ',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    TextSpan(
                                      text: partida.unit,
                                      style: const TextStyle(
                                        color: Color(0xFF0284C7),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (partida.metradoLines.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${partida.metradoLines.length} desg.',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                          child: Text(
                            'Precio: ${NumberFormatUtils.formatNumber(partida.precioUnitario)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD84315),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Subtotal acumulado:',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontStyle: FontStyle.italic,
                          color: titleColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                    InkWell(
                      onTap: isTitle ? onToggleCollapse : (onOpenConsolidado ?? onTap),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isTitle
                              ? Colors.white.withValues(alpha: 0.8)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          NumberFormatUtils.formatCurrency(partida.costoParcial, symbol: currencySymbol),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isTitle ? titleColor : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
