import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/pie_presupuesto.dart';
import '../../providers/presupuesto_provider.dart';
import '../../theme/varflo_theme.dart';
import '../../utils/number_format_utils.dart';
import '../../widgets/delphin_incidencia_panel.dart';
import '../gastos_generales_screen.dart';

class PiePresupuestoTab extends StatefulWidget {
  const PiePresupuestoTab({super.key});

  @override
  State<PiePresupuestoTab> createState() => _PiePresupuestoTabState();
}

class _PiePresupuestoTabState extends State<PiePresupuestoTab> {
  final _currencyFormat = NumberFormat('#,##0.00', 'es_PE');

  late double _ggFijos;
  late double _ggVariables;
  late double _utilidad;
  late double _igv;
  late bool _aplicarIGV;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    final pie = context.read<PresupuestoProvider>().activePresupuesto?.piePresupuesto ?? const PiePresupuesto();
    _ggFijos = pie.porcentajeGGFijos;
    _ggVariables = pie.porcentajeGGVariables;
    _utilidad = pie.porcentajeUtilidad;
    _igv = pie.porcentajeIGV;
    _aplicarIGV = pie.aplicarIGV;
  }

  void _saveChanges() {
    final updated = PiePresupuesto(
      porcentajeGGFijos: _ggFijos,
      porcentajeGGVariables: _ggVariables,
      porcentajeUtilidad: _utilidad,
      porcentajeIGV: _igv,
      aplicarIGV: _aplicarIGV,
    );
    context.read<PresupuestoProvider>().updatePiePresupuesto(updated);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PresupuestoProvider>();
    final presupuesto = provider.activePresupuesto;

    if (presupuesto == null) {
      return const Center(child: Text('No hay presupuesto seleccionado'));
    }

    final currency = presupuesto.currencySymbol;
    final cd = presupuesto.totalCostoDirecto;
    final ggFijosMonto = cd * (_ggFijos / 100.0);
    final ggVarMonto = cd * (_ggVariables / 100.0);
    final utilMonto = cd * (_utilidad / 100.0);
    final subtotal = cd + ggFijosMonto + ggVarMonto + utilMonto;
    final igvMonto = _aplicarIGV ? subtotal * (_igv / 100.0) : 0.0;
    final totalPresupuesto = subtotal + igvMonto;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel Delphin Express BIM 360: Incidencia de Costos + Pie Resumen Único con Factores + T.C.
          DelphinIncidenciaPanel(presupuesto: presupuesto),
          const SizedBox(height: 16),

          // Tarjeta Principal de Liquidación del Presupuesto
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Liquidación del Presupuesto (S10)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${presupuesto.subpresupuestos.length} Subpresupuestos',
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade900, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  _buildCostRow('Costo Directo Total (CD)', NumberFormatUtils.formatCurrency(cd, symbol: currency), isBold: true),
                  _buildCostRow('Gastos Generales Fijos (${_ggFijos.toStringAsFixed(1)}%)', NumberFormatUtils.formatCurrency(ggFijosMonto, symbol: currency)),
                  _buildCostRow('Gastos Generales Variables (${_ggVariables.toStringAsFixed(1)}%)', NumberFormatUtils.formatCurrency(ggVarMonto, symbol: currency)),
                  _buildCostRow('Utilidad (${_utilidad.toStringAsFixed(1)}%)', NumberFormatUtils.formatCurrency(utilMonto, symbol: currency)),
                  const Divider(height: 14),
                  _buildCostRow('SUBTOTAL', NumberFormatUtils.formatCurrency(subtotal, symbol: currency), isBold: true),
                  if (_aplicarIGV)
                    _buildCostRow('I.G.V. (${_igv.toStringAsFixed(1)}%)', NumberFormatUtils.formatCurrency(igvMonto, symbol: currency)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: VarfloTheme.gradienteAzul,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: VarfloTheme.sombraBotonAzul,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'PRESUPUESTO TOTAL',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          NumberFormatUtils.formatCurrency(totalPresupuesto, symbol: currency),
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // COSTO EN LETRAS (Estándar Legal Peruano / Contraloría / Delphin)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: VarfloTheme.grisFondo,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: VarfloTheme.grisBordeSuave),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2, right: 6),
                          child: Icon(
                            Icons.spellcheck_rounded,
                            size: 15,
                            color: VarfloTheme.naranjaPrincipal,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            NumberFormatUtils.numberToWords(
                              totalPresupuesto,
                              currency: presupuesto.currencyName.isNotEmpty ? presupuesto.currencyName : 'SOLES',
                            ),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                              color: VarfloTheme.grisTextoOscuro,
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
          const SizedBox(height: 16),

          // Gráfico de Distribución de Costos (fl_chart)
          if (totalPresupuesto > 0) ...[
            const Text(
              'Distribución Porcentual del Presupuesto',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                _touchedIndex = -1;
                                return;
                              }
                              _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                        sections: _buildChartSections(cd, ggFijosMonto + ggVarMonto, utilMonto, igvMonto, totalPresupuesto),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _chartLegend(Colors.blue.shade700, 'Costo Directo', cd / totalPresupuesto * 100),
                        const SizedBox(height: 6),
                        _chartLegend(Colors.amber.shade700, 'Gastos Grales', (ggFijosMonto + ggVarMonto) / totalPresupuesto * 100),
                        const SizedBox(height: 6),
                        _chartLegend(Colors.green.shade700, 'Utilidad', utilMonto / totalPresupuesto * 100),
                        if (_aplicarIGV) ...[
                          const SizedBox(height: 6),
                          _chartLegend(Colors.purple.shade700, 'I.G.V.', igvMonto / totalPresupuesto * 100),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Tarjeta de Gastos Generales Analíticos (Desagregados Delphin)
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.blue.shade200, width: 0.8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.analytics_outlined, color: Colors.blue.shade800, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Gastos Generales Desagregados (Delphin)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (presupuesto.usarGGDesagregado)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'VINCULADO',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${presupuesto.gastosGenerales.length} conceptos analíticos (personal técnico, alquileres, cartas fianza, almacén).',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Total Analítico: $currency ${_currencyFormat.format(presupuesto.totalGGFijosDesagregado + presupuesto.totalGGVariablesDesagregado)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.edit_note, size: 16),
                        label: const Text('Ver / Editar GG', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const GastosGeneralesScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Parámetros Configurables del Pie de Presupuesto
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configurar Parámetros del Pie',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // Gastos Generales Fijos Slider
                  _buildSlider(
                    label: 'Gastos Generales Fijos',
                    value: _ggFijos,
                    min: 0.0,
                    max: 20.0,
                    onChanged: (val) {
                      setState(() => _ggFijos = val);
                      _saveChanges();
                    },
                  ),

                  // Gastos Generales Variables Slider
                  _buildSlider(
                    label: 'Gastos Generales Variables',
                    value: _ggVariables,
                    min: 0.0,
                    max: 25.0,
                    onChanged: (val) {
                      setState(() => _ggVariables = val);
                      _saveChanges();
                    },
                  ),

                  // Utilidad Slider
                  _buildSlider(
                    label: 'Utilidad',
                    value: _utilidad,
                    min: 0.0,
                    max: 30.0,
                    onChanged: (val) {
                      setState(() => _utilidad = val);
                      _saveChanges();
                    },
                  ),

                  // IGV Switch y Slider
                  SwitchListTile(
                    dense: true,
                    title: const Text('Aplicar I.G.V. / Impuesto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    value: _aplicarIGV,
                    onChanged: (val) {
                      setState(() => _aplicarIGV = val);
                      _saveChanges();
                    },
                  ),
                  if (_aplicarIGV)
                    _buildSlider(
                      label: 'Tasa I.G.V.',
                      value: _igv,
                      min: 0.0,
                      max: 25.0,
                      onChanged: (val) {
                        setState(() => _igv = val);
                        _saveChanges();
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 70),
        ],
      ),
    );
  }

  Widget _buildCostRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12.5, fontWeight: isBold ? FontWeight.bold : FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text('${value.toStringAsFixed(1)} %', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) * 2).toInt(),
          label: '${value.toStringAsFixed(1)}%',
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _chartLegend(Color color, String text, double pct) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$text (${pct.toStringAsFixed(1)}%)',
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildChartSections(
    double cd,
    double gg,
    double util,
    double igv,
    double total,
  ) {
    return [
      PieChartSectionData(
        color: Colors.blue.shade700,
        value: cd,
        title: '${(cd / total * 100).toStringAsFixed(0)}%',
        radius: _touchedIndex == 0 ? 55 : 45,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: Colors.amber.shade700,
        value: gg,
        title: '${(gg / total * 100).toStringAsFixed(0)}%',
        radius: _touchedIndex == 1 ? 55 : 45,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: Colors.green.shade700,
        value: util,
        title: '${(util / total * 100).toStringAsFixed(0)}%',
        radius: _touchedIndex == 2 ? 55 : 45,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      if (_aplicarIGV && igv > 0)
        PieChartSectionData(
          color: Colors.purple.shade700,
          value: igv,
          title: '${(igv / total * 100).toStringAsFixed(0)}%',
          radius: _touchedIndex == 3 ? 55 : 45,
          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        ),
    ];
  }
}
