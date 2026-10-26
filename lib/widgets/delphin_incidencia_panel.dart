import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/presupuesto.dart';
import '../models/resource.dart';
import '../providers/presupuesto_provider.dart';
import '../utils/number_format_utils.dart';

/// Panel inferior estilo Delphin Express BIM 360:
/// - Barra de Moneda activa + Tipo de Cambio (T.C.) + Conversión en vivo S/. <-> USD ($)
/// - Gráfico de barras verticales "Incidencia de Costos" (Mano de Obra, Materiales, Equipo, Sub-contratos)
///   con etiquetas flotantes de porcentaje sobre cada barra.
/// - Tabla "PIE RESUMEN ÚNICO POR PROYECTO" con columna de Factores Multiplicadores acumulados (1.00, 0.10, 1.30...).
class DelphinIncidenciaPanel extends StatefulWidget {
  final Presupuesto presupuesto;
  final bool compact;

  const DelphinIncidenciaPanel({
    super.key,
    required this.presupuesto,
    this.compact = false,
  });

  @override
  State<DelphinIncidenciaPanel> createState() => _DelphinIncidenciaPanelState();
}

class _DelphinIncidenciaPanelState extends State<DelphinIncidenciaPanel> {
  final _numFormat = NumberFormat('#,##0.00', 'es_PE');
  final _tcFormat = NumberFormat('0.0000', 'es_PE');
  bool _verEnDolares = false;

  void _openEditTipoCambioDialog(BuildContext context, double currentTC) {
    final ctrl = TextEditingController(text: currentTC.toStringAsFixed(4));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.currency_exchange, color: Color(0xFF1E3A8A), size: 20),
            SizedBox(width: 8),
            Text('Tipo de Cambio (T.C. Delphin)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configure el Tipo de Cambio (Soles por Dólar Estadounidense USD) para conversión multimoneda del presupuesto:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'T.C. (S/. por \$ 1.00)',
                prefixText: 'S/. ',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (val != null && val > 0) {
                context.read<PresupuestoProvider>().updateTipoCambio(val);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Aplicar T.C.'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.presupuesto;
    final tc = p.tipoCambio > 0 ? p.tipoCambio : 3.75;
    final divisor = _verEnDolares ? tc : 1.0;
    final symbol = _verEnDolares ? 'US\$' : p.currencySymbol;

    // Incidencia de costos directos (MO, MAT, EQ, SC)
    final incidencia = p.calcularIncidenciaCostos();
    final mo = (incidencia[ResourceType.manoDeObra] ?? 0.0) / divisor;
    final mat = (incidencia[ResourceType.material] ?? 0.0) / divisor;
    final eq = (incidencia[ResourceType.equipo] ?? 0.0) / divisor;
    final sc = (incidencia[ResourceType.subcontrato] ?? 0.0) / divisor;
    final sumIncidencia = mo + mat + eq + sc;
    final baseCD = (p.totalCostoDirecto / divisor) > 0
        ? (p.totalCostoDirecto / divisor)
        : (sumIncidencia > 0 ? sumIncidencia : 1.0);

    final pctMO = sumIncidencia > 0 ? (mo / sumIncidencia * 100.0) : 0.0;
    final pctMAT = sumIncidencia > 0 ? (mat / sumIncidencia * 100.0) : 0.0;
    final pctEQ = sumIncidencia > 0 ? (eq / sumIncidencia * 100.0) : 0.0;
    final pctSC = sumIncidencia > 0 ? (sc / sumIncidencia * 100.0) : 0.0;

    // Cálculos del Pie Resumen Único con Factores
    final cd = p.totalCostoDirecto / divisor;
    final ggPct = p.piePresupuesto.porcentajeGGFijos + p.piePresupuesto.porcentajeGGVariables;
    final ggMonto = p.totalGastosGenerales / divisor;
    final utilPct = p.piePresupuesto.porcentajeUtilidad;
    final utilMonto = p.totalUtilidad / divisor;
    final parcial = p.subtotal / divisor;
    final igvPct = p.piePresupuesto.aplicarIGV ? p.piePresupuesto.porcentajeIGV : 0.0;
    final igvMonto = p.igv / divisor;
    final total = p.totalPresupuesto / divisor;

    final factorCD = cd > 0 ? 1.00 : 0.00;
    final factorGG = cd > 0 ? (ggMonto / cd) : 0.00;
    final factorUtil = cd > 0 ? (utilMonto / cd) : 0.00;
    final factorParcial = cd > 0 ? (parcial / cd) : 0.00;
    final factorIGV = cd > 0 ? (igvMonto / cd) : 0.00;
    final factorTotal = cd > 0 ? (total / cd) : 0.00;

    final dateStr = DateFormat('dd/MM/yyyy').format(p.date);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Barra de País, Moneda Activa y Tipo de Cambio (Estilo Delphin)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFFEDF2F8),
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
              border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1))),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'País : Perú - Moneda activa: ',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      _verEnDolares ? 'dólar estadounidense (US\$)' : 'sol peruano (S/.)',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      p.isLocked ? Icons.lock : Icons.lock_open,
                      size: 14,
                      color: Colors.blueGrey.shade600,
                    ),
                    const SizedBox(width: 6),
                    // Conmutador Soles / Dólares
                    InkWell(
                      onTap: () => setState(() => _verEnDolares = !_verEnDolares),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _verEnDolares ? Colors.amber.shade100 : Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blueGrey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _verEnDolares
                                  ? 'Ver en Soles (S/.)'
                                  : 'Estados Unidos - dólar (\$)',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: _verEnDolares ? FontWeight.bold : FontWeight.normal,
                                color: Colors.blueGrey.shade800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.swap_horiz, size: 13, color: Color(0xFF1E3A8A)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('T.C. :', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _openEditTipoCambioDialog(context, tc),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.blueGrey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _tcFormat.format(tc),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        dateStr,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Cuerpo: Gráfico "Incidencia de Costos" + Tabla "PIE RESUMEN ÚNICO POR PROYECTO"
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              final chartWidget = _buildIncidenciaChart(
                mo: mo,
                mat: mat,
                eq: eq,
                sc: sc,
                pctMO: pctMO,
                pctMAT: pctMAT,
                pctEQ: pctEQ,
                pctSC: pctSC,
                baseCD: baseCD,
                symbol: symbol,
              );
              final tableWidget = _buildPieResumenTable(
                symbol: symbol,
                cd: cd,
                ggPct: ggPct,
                ggMonto: ggMonto,
                utilPct: utilPct,
                utilMonto: utilMonto,
                parcial: parcial,
                igvPct: igvPct,
                igvMonto: igvMonto,
                total: total,
                factorCD: factorCD,
                factorGG: factorGG,
                factorUtil: factorUtil,
                factorParcial: factorParcial,
                factorIGV: factorIGV,
                factorTotal: factorTotal,
              );

              if (isWide) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 5, child: chartWidget),
                      Container(width: 1, color: Colors.blueGrey.shade200),
                      Expanded(flex: 6, child: tableWidget),
                    ],
                  ),
                );
              } else {
                return Column(
                  children: [
                    chartWidget,
                    Divider(height: 1, color: Colors.blueGrey.shade200),
                    tableWidget,
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIncidenciaChart({
    required double mo,
    required double mat,
    required double eq,
    required double sc,
    required double pctMO,
    required double pctMAT,
    required double pctEQ,
    required double pctSC,
    required double baseCD,
    required String symbol,
  }) {
    final maxVal = [mo, mat, eq, sc, 1.0].reduce((a, b) => a > b ? a : b);
    final barAreaHeight = widget.compact ? 115.0 : 140.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Incidencia de Costos',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: barAreaHeight + 48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Eje Y con escalas numéricas
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_formatCompactAxis(maxVal), style: const TextStyle(fontSize: 9, color: Colors.black54)),
                    Text(_formatCompactAxis(maxVal * 0.75), style: const TextStyle(fontSize: 9, color: Colors.black54)),
                    Text(_formatCompactAxis(maxVal * 0.50), style: const TextStyle(fontSize: 9, color: Colors.black54)),
                    Text(_formatCompactAxis(maxVal * 0.25), style: const TextStyle(fontSize: 9, color: Colors.black54)),
                    const Text('0.00', style: TextStyle(fontSize: 9, color: Colors.black54)),
                    const SizedBox(height: 22),
                  ],
                ),
                const SizedBox(width: 6),
                // Área de Barras con líneas guía horizontales
                Expanded(
                  child: Stack(
                    children: [
                      // Líneas guía
                      Positioned.fill(
                        bottom: 22,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            5,
                            (_) => Container(height: 1, color: Colors.grey.shade200),
                          ),
                        ),
                      ),
                      // Las 4 barras estilo Delphin
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildDelphinBar(
                            label: 'MANO DE OBRA',
                            amount: mo,
                            pct: pctMO,
                            maxAmount: maxVal,
                            maxBarHeight: barAreaHeight,
                            barColor: const Color(0xFF0088FF),
                            badgeColor: const Color(0xFF0D47A1),
                            symbol: symbol,
                          ),
                          _buildDelphinBar(
                            label: 'MATERIALES',
                            amount: mat,
                            pct: pctMAT,
                            maxAmount: maxVal,
                            maxBarHeight: barAreaHeight,
                            barColor: const Color(0xFFFF0000),
                            badgeColor: const Color(0xFFB71C1C),
                            symbol: symbol,
                          ),
                          _buildDelphinBar(
                            label: 'EQUIPO',
                            amount: eq,
                            pct: pctEQ,
                            maxAmount: maxVal,
                            maxBarHeight: barAreaHeight,
                            barColor: const Color(0xFF2E7D32),
                            badgeColor: const Color(0xFF1B5E20),
                            symbol: symbol,
                          ),
                          _buildDelphinBar(
                            label: 'SUB-CONTRATOS',
                            amount: sc,
                            pct: pctSC,
                            maxAmount: maxVal,
                            maxBarHeight: barAreaHeight,
                            barColor: const Color(0xFF00838F),
                            badgeColor: const Color(0xFF006064),
                            symbol: symbol,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDelphinBar({
    required String label,
    required double amount,
    required double pct,
    required double maxAmount,
    required double maxBarHeight,
    required Color barColor,
    required Color badgeColor,
    required String symbol,
  }) {
    final ratio = maxAmount > 0 ? (amount / maxAmount).clamp(0.0, 1.0) : 0.0;
    final barHeight = (ratio * (maxBarHeight - 28)).clamp(4.0, maxBarHeight - 28);

    return Expanded(
      child: Tooltip(
        message: '$label: $symbol ${_numFormat.format(amount)} (${pct.toStringAsFixed(2)}%)',
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Etiqueta flotante con borde como en Delphin: [57.46 %]
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: badgeColor.withValues(alpha: 0.6), width: 1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '${pct.toStringAsFixed(2)} %',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ),
            const SizedBox(height: 3),
            // Barra vertical sólida
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: barHeight,
              width: 34,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
              ),
            ),
            Container(height: 1, color: Colors.blueGrey.shade400),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieResumenTable({
    required String symbol,
    required double cd,
    required double ggPct,
    required double ggMonto,
    required double utilPct,
    required double utilMonto,
    required double parcial,
    required double igvPct,
    required double igvMonto,
    required double total,
    required double factorCD,
    required double factorGG,
    required double factorUtil,
    required double factorParcial,
    required double factorIGV,
    required double factorTotal,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabecera estilo Delphin: [Resumen] PIE RESUMEN ÚNICO POR PROYECTO
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: const Color(0xFFE2E8F0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Colors.blueGrey.shade300),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.settings_outlined, size: 12, color: Color(0xFF1E3A8A)),
                    SizedBox(width: 4),
                    Text('Resumen', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_drop_down, size: 14),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'PIE RESUMEN ÚNICO POR PROYECTO',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Filas de la tabla con Factores Acumulados
        _buildResumenRow(
          label: 'Costo Directo',
          pctText: '',
          amountText: NumberFormatUtils.formatCurrency(cd, symbol: symbol),
          factorText: factorCD.toStringAsFixed(2),
          isBold: true,
          bgColor: const Color(0xFFF8FAFC),
        ),
        _buildResumenRow(
          label: 'Gastos Generales',
          pctText: '${ggPct.toStringAsFixed(2)}%',
          amountText: ggMonto > 0 ? NumberFormatUtils.formatCurrency(ggMonto, symbol: symbol) : '$symbol 0.00',
          factorText: factorGG.toStringAsFixed(2),
        ),
        _buildResumenRow(
          label: 'Utilidad',
          pctText: '${utilPct.toStringAsFixed(2)}%',
          amountText: NumberFormatUtils.formatCurrency(utilMonto, symbol: symbol),
          factorText: factorUtil.toStringAsFixed(2),
        ),
        _buildResumenRow(
          label: 'Parcial',
          pctText: '',
          amountText: NumberFormatUtils.formatCurrency(parcial, symbol: symbol),
          factorText: factorParcial.toStringAsFixed(2),
          bgColor: const Color(0xFFF8FAFC),
        ),
        _buildResumenRow(
          label: 'I.G.V.',
          pctText: '${igvPct.toStringAsFixed(2)}%',
          amountText: NumberFormatUtils.formatCurrency(igvMonto, symbol: symbol),
          factorText: factorIGV.toStringAsFixed(2),
        ),
        _buildResumenRow(
          label: 'Otros impuestos',
          pctText: '0.00%',
          amountText: '$symbol 0.00',
          factorText: '0.00',
        ),
        _buildResumenRow(
          label: 'Total',
          pctText: '',
          amountText: NumberFormatUtils.formatCurrency(total, symbol: symbol),
          factorText: factorTotal.toStringAsFixed(2),
          isBold: true,
          isTotal: true,
          bgColor: const Color(0xFFEFF6FF),
        ),
      ],
    );
  }

  Widget _buildResumenRow({
    required String label,
    required String pctText,
    required String amountText,
    required String factorText,
    bool isBold = false,
    bool isTotal = false,
    Color? bgColor,
  }) {
    final style = TextStyle(
      fontSize: isTotal ? 12 : 11,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      color: isTotal ? const Color(0xFF0F172A) : const Color(0xFF334155),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.8)),
      ),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text(label, style: style)),
          SizedBox(
            width: 52,
            child: Text(
              pctText,
              textAlign: TextAlign.right,
              style: style.copyWith(fontSize: 10.5, color: Colors.blueGrey.shade700),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              amountText,
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              factorText,
              textAlign: TextAlign.right,
              style: style.copyWith(
                fontFamily: 'monospace',
                fontSize: 10.5,
                color: Colors.blueGrey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCompactAxis(double value) {
    if (value >= 1000000) {
      return _numFormat.format(value);
    }
    return _numFormat.format(value);
  }
}
