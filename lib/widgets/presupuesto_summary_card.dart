import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/presupuesto.dart';
import '../theme/varflo_theme.dart';
import '../utils/number_format_utils.dart';

class PresupuestoSummaryCard extends StatelessWidget {
  final Presupuesto presupuesto;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback? onSaveToDrive;
  final VoidCallback? onToggleLock;

  static final _dateFormat = DateFormat('dd MMM yyyy', 'es_PE');

  const PresupuestoSummaryCard({
    super.key,
    required this.presupuesto,
    required this.onTap,
    required this.onDuplicate,
    required this.onDelete,
    required this.onShare,
    this.onSaveToDrive,
    this.onToggleLock,
  });

  @override
  Widget build(BuildContext context) {
    final currency = presupuesto.currencySymbol;
    final totalCD = presupuesto.totalCostoDirecto;
    final totalObra = presupuesto.totalPresupuesto;
    final isLocked = presupuesto.isLocked;

    final tipoColor = _getColorForTipo(presupuesto.tipoObra);
    final costoEnLetras = NumberFormatUtils.numberToWords(
      totalObra,
      currency: presupuesto.currencyName.isNotEmpty ? presupuesto.currencyName : 'SOLES',
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: VarfloTheme.grisSuperficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLocked ? VarfloTheme.naranjaPrincipal : VarfloTheme.grisBordeSuave,
          width: isLocked ? 1.5 : 1.0,
        ),
        boxShadow: VarfloTheme.sombraTarjeta,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra vertical lateral de acento Varflo (Naranja si está bloqueado, Azul corporativo si es editable)
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: isLocked ? VarfloTheme.naranjaPrincipal : VarfloTheme.azulPrincipal,
                ),
              ),
              // Contenido principal de la tarjeta
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Fila superior: Candado Delphin, Badge Tipo Obra, Fecha y Menú contextual
                        Row(
                          children: [
                            // Candado Delphin Express
                            InkWell(
                              onTap: onToggleLock,
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Icon(
                                  isLocked ? Icons.lock : Icons.lock_open_outlined,
                                  size: 18,
                                  color: isLocked ? VarfloTheme.naranjaPrincipal : VarfloTheme.grisDesactivado,
                                ),
                              ),
                            ),

                            // Badge Tipo de Obra (Estilo moderno Varflo)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: tipoColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: tipoColor.withOpacity(0.3), width: 0.8),
                              ),
                              child: Text(
                                presupuesto.tipoObra.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: tipoColor,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Costos al : Fecha (Formato Delphin)
                            Expanded(
                              child: Text(
                                'Costos al: ${_dateFormat.format(presupuesto.date)}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: VarfloTheme.grisTextoSecundario,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            // Menú contextual moderno
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 20, color: VarfloTheme.grisTextoSecundario),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 240),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: 'lock',
                                  child: Row(
                                    children: [
                                      Icon(
                                        isLocked ? Icons.lock_open : Icons.lock,
                                        size: 18,
                                        color: VarfloTheme.azulPrincipal,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(isLocked ? 'Desbloquear edición' : 'Bloquear (Solo Lectura)'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'dup',
                                  child: Row(
                                    children: [
                                      Icon(Icons.copy, size: 18, color: VarfloTheme.azulAcento),
                                      SizedBox(width: 8),
                                      Text('Duplicar Presupuesto'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'drive',
                                  child: Row(
                                    children: [
                                      Icon(Icons.cloud_upload_outlined, size: 18, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text('Guardar en Google Drive / Red'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'share',
                                  child: Row(
                                    children: [
                                      Icon(Icons.share_outlined, size: 18, color: Colors.teal),
                                      SizedBox(width: 8),
                                      Text('Exportar Respaldo JSON'),
                                    ],
                                  ),
                                ),
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                  value: 'del',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Eliminar Presupuesto', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (val) {
                                if (val == 'lock' && onToggleLock != null) onToggleLock!();
                                if (val == 'dup') onDuplicate();
                                if (val == 'drive' && onSaveToDrive != null) onSaveToDrive!();
                                if (val == 'share') onShare();
                                if (val == 'del') onDelete();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Nombre de la Obra / Proyecto (Azul Varflo Oscuro)
                        Text(
                          presupuesto.name,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: VarfloTheme.grisTextoOscuro,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),

                        // Cliente y Ubicación (Gris técnico Varflo)
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 13, color: VarfloTheme.grisTextoSecundario),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${presupuesto.client} • ${presupuesto.location}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: VarfloTheme.grisTextoSecundario,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Totales: Costo Directo y Total Presupuesto con formato peruano (ej. S/ 1'325,125.25)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: VarfloTheme.grisFondo,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: VarfloTheme.grisBordeSuave, width: 0.8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'COSTO DIRECTO (C.D.)',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: VarfloTheme.grisTextoSecundario,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    NumberFormatUtils.formatCurrency(totalCD, symbol: currency),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: VarfloTheme.azulPrincipal,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'TOTAL PRESUPUESTO (CON IGV)',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: VarfloTheme.naranjaOscuro,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    NumberFormatUtils.formatCurrency(totalObra, symbol: currency),
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: VarfloTheme.naranjaOscuro,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 7),

                        // COSTO EN LETRAS (Estándar Legal Peruano / Contraloría / Delphin)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: VarfloTheme.grisBordeSuave, width: 0.6),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 1, right: 5),
                                child: Icon(
                                  Icons.spellcheck_rounded,
                                  size: 13,
                                  color: VarfloTheme.azulPrincipal,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  costoEnLetras,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: VarfloTheme.grisTextoOscuro,
                                    fontStyle: FontStyle.italic,
                                    height: 1.25,
                                  ),
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
          ),
        ),
      ),
    );
  }

  Color _getColorForTipo(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('edif')) return VarfloTheme.azulPrincipal; // Azul corporativo
    if (t.contains('agua') || t.contains('saneam')) return VarfloTheme.azulAcento; // Cyan / Celeste técnico
    if (t.contains('vial') || t.contains('carret')) return VarfloTheme.naranjaPrincipal; // Naranja vial
    if (t.contains('educat') || t.contains('coleg')) return const Color(0xFF2E7D32); // Verde institucional
    if (t.contains('hidr') || t.contains('riego')) return const Color(0xFF0284C7); // Azul agua
    if (t.contains('urban') || t.contains('pluvial')) return VarfloTheme.naranjaOscuro; // Terracota / Naranja
    return VarfloTheme.azulMedio;
  }
}
