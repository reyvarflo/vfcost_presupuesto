import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/formula_polinomica.dart';
import '../../models/partida.dart';
import '../../models/presupuesto.dart';
import '../../providers/presupuesto_provider.dart';
import '../../services/formula_service.dart';
import '../../services/pdf_export_service.dart';
import '../formula_grouping_screen.dart';

class FormulaPolinomicaTab extends StatefulWidget {
  const FormulaPolinomicaTab({super.key});

  @override
  State<FormulaPolinomicaTab> createState() => _FormulaPolinomicaTabState();
}

class _FormulaPolinomicaTabState extends State<FormulaPolinomicaTab> {
  // 0 = Fórmula Polinómica y Árbol de Monomios (Imágenes 3 y 5 de Delphin)
  // 1 = Matriz "Cálculo de Coeficientes de Incidencia" (Imagen 4 de Delphin)
  int _selectedView = 0;
  final Set<int> _collapsedMonomios = {};

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PresupuestoProvider>();
    final presupuesto = provider.activePresupuesto;

    if (presupuesto == null) {
      return const Center(child: Text('No hay presupuesto activo'));
    }

    final formula = presupuesto.formulaPolinomica;
    final monomios = formula.monomios;
    final sumaK = formula.sumaCoeficientes;
    final isValid = formula.isValid && monomios.length <= 8 && monomios.isNotEmpty;

    return Column(
      children: [
        // Barra Superior Estilo Cinta Delphin Express
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFECEFF1),
            border: Border(bottom: BorderSide(color: Colors.blueGrey.shade200)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Selector de Vista Delphin
              SegmentedButton<int>(
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStateProperty.all(
                    const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.functions, size: 16),
                    label: Text('Fórmula y Monomios (K₁)'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.grid_on, size: 16),
                    label: Text('Matriz de Incidencia (Partidas × IU)'),
                  ),
                ],
                selected: {_selectedView},
                onSelectionChanged: (s) => setState(() => _selectedView = s.first),
              ),

              // Acciones rápidas
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FormulaGroupingScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Agrupar IUs', style: TextStyle(fontSize: 11.5)),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: () {
                      final activeSub = provider.activeSubpresupuesto;
                      if (activeSub != null) {
                        PdfExportService.printFormulaPolinomicaReport(presupuesto, activeSub);
                      }
                    },
                    icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.red),
                    label: const Text('Imprimir PDF', style: TextStyle(fontSize: 11.5)),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: 'Recalcular Fórmula Polinómica',
                    onPressed: () {
                      provider.procesarPresupuesto();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Fórmula Polinómica recalculada con los insumos actuales'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // Contenido según la vista seleccionada
        Expanded(
          child: _selectedView == 0
              ? _buildFormulaAndTreeView(context, provider, presupuesto, formula, sumaK, isValid)
              : _buildIncidenceMatrixView(context, provider, presupuesto),
        ),
      ],
    );
  }

  /// VISTA 1: ECUACIÓN ALGEBRAICA FRACCIONARIA + ÁRBOL DE COEFICIENTES (10 DECIMALES VS 3 DECIMALES)
  Widget _buildFormulaAndTreeView(
    BuildContext context,
    PresupuestoProvider provider,
    Presupuesto presupuesto,
    FormulaPolinomica formula,
    double sumaK,
    bool isValid,
  ) {
    final monomios = formula.monomios;
    final costosPorIU = FormulaService.obtenerCostosPorIU(presupuesto);
    final baseSubtotal = presupuesto.subtotal > 0 ? presupuesto.subtotal : 1.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Banner de Validación D.S. N° 011-79-VC
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isValid ? Colors.green.shade50 : Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isValid ? Colors.green.shade400 : Colors.amber.shade400,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isValid ? Icons.verified : Icons.warning_amber_rounded,
                  color: isValid ? Colors.green.shade800 : Colors.amber.shade900,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isValid
                            ? 'Fórmula Polinómica Conforme (D.S. N° 011-79-VC)'
                            : 'Fórmula Polinómica requiere revisión de coeficientes',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isValid ? Colors.green.shade900 : Colors.amber.shade900,
                        ),
                      ),
                      Text(
                        'Monomios: ${monomios.length} (máx. 8)  |  Σ Coef. Definido = ${sumaK.toStringAsFixed(3)}  |  Moneda: ${presupuesto.currencySymbol}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isValid ? Colors.green.shade800 : Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Recuadro de Expresión Algebraica Fraccionaria (Estilo Delphin Imagen 5)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blueGrey.shade300, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.functions, size: 16, color: Colors.blueGrey.shade800),
                    const SizedBox(width: 6),
                    Text(
                      'EXPRESIÓN MATEMÁTICA DE REAJUSTE AUTOMÁTICO (K₁)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey.shade800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 14),
                if (monomios.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('K₁ = 1.000 (Sin monomios generados)'),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // K1 =
                          const Text(
                            'K₁ = ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'serif',
                              color: Color(0xFF1A237E),
                            ),
                          ),
                          ...List.generate(monomios.length, (index) {
                            final m = monomios[index];
                            final isLast = index == monomios.length - 1;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Coeficiente k (ej. 0.093)
                                Text(
                                  m.coeficiente.toStringAsFixed(3),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // Fracción (Sym_r / Sym_o)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${m.symbol}r',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0D47A1),
                                        ),
                                      ),
                                      Container(
                                        width: (m.symbol.length * 9.0).clamp(22.0, 48.0),
                                        height: 1.5,
                                        color: const Color(0xFF0D47A1),
                                        margin: const EdgeInsets.symmetric(vertical: 1.5),
                                      ),
                                      Text(
                                        '${m.symbol}o',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0D47A1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isLast)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      '+',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Tabla Jerárquica de Agrupamiento y Coeficientes (Estilo Delphin Imagen 3 y 5)
          if (monomios.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: FilledButton.icon(
                  onPressed: () => provider.procesarPresupuesto(),
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Generar Fórmula Polinómica Automáticamente'),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blueGrey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabecera azul acero estilo Delphin Express
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF263238),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(
                            'Descripción (Monomio / Índice Unificado)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 58,
                          child: Text(
                            'Nomencl.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 98,
                          child: Text(
                            'Coef. Calculado',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 78,
                          child: Text(
                            'Coef. Definido',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: Colors.lightGreenAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 68,
                          child: Text(
                            'Porcentaje',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Filas del Árbol de Monomios y Submonomios
                  ...monomios.map((m) {
                    // Calcular el coeficiente exacto (10 decimales) del monomio sumando sus IUs
                    double costoMonomio = 0.0;
                    for (final sub in m.submonomios) {
                      costoMonomio += costosPorIU[sub.unifiedIndex] ?? 0.0;
                    }
                    final coefCalculadoMonomio = costoMonomio / baseSubtotal;
                    final nombrePrincipal = m.submonomios.isNotEmpty
                        ? m.submonomios.first.description.toUpperCase()
                        : 'MONOMIO ${m.monomioNumber}';

                    final isCollapsed = _collapsedMonomios.contains(m.monomioNumber);

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Fila Padre: Monomio (Clic en la flecha expande/retrae IUs; clic en el coeficiente edita)
                        InkWell(
                          onTap: () {
                            setState(() {
                              if (isCollapsed) {
                                _collapsedMonomios.remove(m.monomioNumber);
                              } else {
                                _collapsedMonomios.add(m.monomioNumber);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFCFD8DC).withOpacity(0.55),
                              border: Border(
                                bottom: BorderSide(color: Colors.blueGrey.shade200),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Row(
                                    children: [
                                      Icon(
                                        isCollapsed
                                            ? Icons.keyboard_arrow_right
                                            : Icons.keyboard_arrow_down,
                                        size: 18,
                                        color: const Color(0xFF0D47A1),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.folder_open,
                                        size: 15,
                                        color: Color(0xFF1565C0),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          nombrePrincipal,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0D47A1),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 58,
                                  child: InkWell(
                                    onTap: () => _editarMonomioDialog(context, provider, formula, m),
                                    child: Container(
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade900,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        m.symbol,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 98,
                                  child: Text(
                                    coefCalculadoMonomio.toStringAsFixed(10),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 78,
                                  child: InkWell(
                                    onTap: () => _editarMonomioDialog(context, provider, formula, m),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          m.coeficiente.toStringAsFixed(3),
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF1B5E20),
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        const Icon(Icons.edit, size: 11, color: Colors.black45),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: 68,
                                  child: Text(
                                    '',
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Filas Hijas: Índices Unificados que integran el Monomio
                        if (!isCollapsed)
                          ...m.submonomios.map((sub) {
                          final costoSub = costosPorIU[sub.unifiedIndex] ?? 0.0;
                          final coefCalcSub = costoSub / baseSubtotal;
                          final pctDentroMonomio = costoMonomio > 0
                              ? (costoSub / costoMonomio) * 100.0
                              : (sub.factor * 100.0);

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 16),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.subdirectory_arrow_right,
                                          size: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blueGrey.shade100,
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: Text(
                                            sub.unifiedIndex.toString().padLeft(2, '0'),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            sub.description.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              color: Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 58),
                                SizedBox(
                                  width: 98,
                                  child: Text(
                                    coefCalcSub.toStringAsFixed(10),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 78),
                                SizedBox(
                                  width: 68,
                                  child: Text(
                                    '${pctDentroMonomio.toStringAsFixed(2)}%',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  }),

                  // Fila Final TOTAL (Cierre a 10 decimales y 3 decimales como en Imagen 3 de Delphin)
                  Builder(
                    builder: (context) {
                      final totalCalculado =
                          costosPorIU.values.fold(0.0, (a, b) => a + b) / baseSubtotal;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        decoration: const BoxDecoration(
                          color: Color(0xFFECEFF1),
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(5)),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              flex: 5,
                              child: Text(
                                'TOTAL COEFICIENTES DE INCIDENCIA',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF263238),
                                ),
                              ),
                            ),
                            const SizedBox(width: 58),
                            SizedBox(
                              width: 98,
                              child: Text(
                                totalCalculado.toStringAsFixed(10),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 78,
                              child: Text(
                                sumaK.toStringAsFixed(3),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: (sumaK - 1.0).abs() < 0.001
                                      ? Colors.green.shade800
                                      : Colors.red.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: 68,
                              child: Text(
                                '100.00%',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  /// Permite editar directamente la Nomenclatura o el Coeficiente Definido (3 decimales) de un Monomio
  void _editarMonomioDialog(
    BuildContext context,
    PresupuestoProvider provider,
    FormulaPolinomica formula,
    Monomio monomio,
  ) {
    final symbolCtrl = TextEditingController(text: monomio.symbol);
    final coefCtrl = TextEditingController(text: monomio.coeficiente.toStringAsFixed(3));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Editar Monomio ${monomio.monomioNumber}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: symbolCtrl,
              decoration: const InputDecoration(
                labelText: 'Nomenclatura / Símbolo (ej. M, CE, A, GU)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: coefCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Coeficiente Definido (3 decimales)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final newSym = symbolCtrl.text.trim().isNotEmpty
                  ? symbolCtrl.text.trim().toUpperCase()
                  : monomio.symbol;
              final newCoef = double.tryParse(coefCtrl.text.replaceAll(',', '.')) ??
                  monomio.coeficiente;

              final nuevosMonomios = formula.monomios.map((m) {
                if (m.monomioNumber == monomio.monomioNumber) {
                  return m.copyWith(symbol: newSym, coeficiente: newCoef);
                }
                return m;
              }).toList();

              provider.updateFormulaPolinomica(FormulaPolinomica(monomios: nuevosMonomios));
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  /// VISTA 2: MATRIZ "CÁLCULO DE COEFICIENTES DE INCIDENCIA" (Partidas × Índices Unificados - Imagen 4 de Delphin)
  Widget _buildIncidenceMatrixView(
    BuildContext context,
    PresupuestoProvider provider,
    Presupuesto presupuesto,
  ) {
    final partidas = provider.activeSubpresupuesto?.partidas ?? <Partida>[];
    final costosPorIU = FormulaService.obtenerCostosPorIU(presupuesto);

    // Lista ordenada de todos los IUs activos (incluyendo el 39 para GG + Utilidad)
    final iusSet = <int>{...costosPorIU.keys, 39};
    final iusOrdenados = iusSet.toList()..sort();

    // Calcular subtotales de Costo Directo por cada columna de IU
    final subTotalDirectoPorIU = <int, double>{};
    for (final sub in presupuesto.subpresupuestos) {
      for (final p in sub.partidas) {
        if (!p.isTitle) {
          final mapaP = FormulaService.calcularMontosIUPorPartida(p, sub.partidas);
          for (final entry in mapaP.entries) {
            subTotalDirectoPorIU[entry.key] =
                (subTotalDirectoPorIU[entry.key] ?? 0.0) + entry.value;
          }
        }
      }
    }

    final cdTotal = presupuesto.totalCostoDirecto;
    final ggUtilidadMonto = (presupuesto.subtotal - cdTotal).clamp(0.0, double.infinity);
    final totalPresupuestoSinIgv = presupuesto.subtotal > 0 ? presupuesto.subtotal : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Encabezado informativo de la Matriz
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: const Color(0xFF1A237E),
          child: Row(
            children: [
              const Icon(Icons.grid_on, color: Colors.amberAccent, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'CÁLCULO DE COEFICIENTES DE INCIDENCIA (MATRIZ PARTIDAS × ÍNDICES UNIFICADOS INEI)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Text(
                '${iusOrdenados.length} Índices Activos',
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // Tabla Matricial Bidireccional
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 530.0 + (iusOrdenados.length * 96.0),
              child: Column(
                children: [
                  // Cabecera de Columnas
                  Container(
                    color: const Color(0xFF37474F),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    child: Row(
                      children: [
                        _matrixHeaderCell('Item', 65, align: TextAlign.left),
                        _matrixHeaderCell('Descripción', 210, align: TextAlign.left),
                        _matrixHeaderCell('Und.', 45, align: TextAlign.center),
                        _matrixHeaderCell('Cantidad', 68),
                        _matrixHeaderCell('Precio', 68),
                        _matrixHeaderCell('Parcial', 74),
                        ...iusOrdenados.map((iu) {
                          final code = iu.toString().padLeft(2, '0');
                          final desc = FormulaService.nombreIU(iu);
                          return Tooltip(
                            message: 'IU $code: $desc',
                            child: SizedBox(
                              width: 96,
                              child: Text(
                                code,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: Colors.amberAccent,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  // Cuerpo de Partidas y Títulos
                  Expanded(
                    child: ListView.builder(
                      itemCount: partidas.length,
                      itemBuilder: (context, idx) {
                        final p = partidas[idx];
                        final esTit = p.isTitle;
                        final montosIU =
                            FormulaService.calcularMontosIUPorPartida(p, partidas);
                        final parcialFila = p.costoParcial;

                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                          decoration: BoxDecoration(
                            color: esTit
                                ? const Color(0xFFECEFF1)
                                : (idx.isEven ? Colors.white : const Color(0xFFFAFAFA)),
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade300, width: 0.6),
                            ),
                          ),
                          child: Row(
                            children: [
                              _matrixDataCell(
                                p.itemNumber,
                                65,
                                align: TextAlign.left,
                                isBold: esTit,
                                color: esTit ? const Color(0xFF0D47A1) : Colors.black87,
                              ),
                              _matrixDataCell(
                                p.description,
                                210,
                                align: TextAlign.left,
                                isBold: esTit,
                                color: esTit ? const Color(0xFF0D47A1) : Colors.black87,
                              ),
                              _matrixDataCell(
                                esTit ? '' : p.unit,
                                45,
                                align: TextAlign.center,
                              ),
                              _matrixDataCell(
                                esTit ? '' : p.metradoEfectivo.toStringAsFixed(2),
                                68,
                              ),
                              _matrixDataCell(
                                esTit ? '' : p.precioUnitario.toStringAsFixed(2),
                                68,
                              ),
                              _matrixDataCell(
                                parcialFila.toStringAsFixed(2),
                                74,
                                isBold: true,
                              ),
                              ...iusOrdenados.map((iu) {
                                final val = montosIU[iu] ?? 0.0;
                                return _matrixDataCell(
                                  val > 0.004 ? val.toStringAsFixed(2) : '',
                                  96,
                                  isBold: esTit,
                                  color: esTit
                                      ? Colors.blueGrey.shade900
                                      : const Color(0xFF1B5E20),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // PIE DE MATRIZ DELPHIN (4 Filas Resumen: Sub Total, GG y Utilidad, TOTAL, Coeficientes de Incidencia)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFCFD8DC),
                      border: Border(
                        top: BorderSide(color: Colors.blueGrey.shade700, width: 1.5),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. Sub Total (Costo Directo)
                        _buildSummaryMatrixRow(
                          label: 'Sub Total (Costo Directo)',
                          totalBase: cdTotal.toStringAsFixed(2),
                          iusOrdenados: iusOrdenados,
                          cellBuilder: (iu) {
                            final v = subTotalDirectoPorIU[iu] ?? 0.0;
                            return v > 0 ? v.toStringAsFixed(2) : '0.00';
                          },
                          bgColor: const Color(0xFFECEFF1),
                        ),
                        // 2. Gastos Generales y Utilidad (en IU 39)
                        _buildSummaryMatrixRow(
                          label: 'Gastos Generales y Utilidad (IU 39)',
                          totalBase: ggUtilidadMonto.toStringAsFixed(2),
                          iusOrdenados: iusOrdenados,
                          cellBuilder: (iu) {
                            if (iu == 39) return ggUtilidadMonto.toStringAsFixed(2);
                            return '';
                          },
                          bgColor: Colors.white,
                        ),
                        // 3. TOTAL PRESUPUESTO BASE
                        _buildSummaryMatrixRow(
                          label: 'TOTAL PRESUPUESTO BASE (${presupuesto.currencySymbol})',
                          totalBase: presupuesto.subtotal.toStringAsFixed(2),
                          iusOrdenados: iusOrdenados,
                          cellBuilder: (iu) {
                            final v = (subTotalDirectoPorIU[iu] ?? 0.0) +
                                (iu == 39 ? ggUtilidadMonto : 0.0);
                            return v.toStringAsFixed(2);
                          },
                          bgColor: const Color(0xFFFFF8E1),
                          textColor: const Color(0xFF0D47A1),
                        ),
                        // 4. Coeficientes de Incidencia (10 decimales)
                        _buildSummaryMatrixRow(
                          label: 'Coeficientes de Incidencia (10 dec.)',
                          totalBase: '1.0000000000',
                          iusOrdenados: iusOrdenados,
                          cellBuilder: (iu) {
                            final v = (subTotalDirectoPorIU[iu] ?? 0.0) +
                                (iu == 39 ? ggUtilidadMonto : 0.0);
                            final coef = v / totalPresupuestoSinIgv;
                            return coef.toStringAsFixed(10);
                          },
                          bgColor: const Color(0xFF263238),
                          textColor: Colors.amberAccent,
                          fontSize: 9.5,
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
    );
  }

  Widget _matrixHeaderCell(
    String text,
    double width, {
    TextAlign align = TextAlign.right,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _matrixDataCell(
    String text,
    double width, {
    TextAlign align = TextAlign.right,
    bool isBold = false,
    Color color = Colors.black87,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Text(
          text,
          textAlign: align,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            fontFamily: align == TextAlign.right ? 'monospace' : null,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryMatrixRow({
    required String label,
    required String totalBase,
    required List<int> iusOrdenados,
    required String Function(int iu) cellBuilder,
    required Color bgColor,
    Color textColor = Colors.black87,
    double fontSize = 10.5,
  }) {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      child: Row(
        children: [
          SizedBox(
            width: 456, // 65 + 210 + 45 + 68 + 68
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
          ),
          SizedBox(
            width: 74,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                totalBase,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: fontSize,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
            ),
          ),
          ...iusOrdenados.map((iu) {
            return SizedBox(
              width: 96,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  cellBuilder(iu),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
